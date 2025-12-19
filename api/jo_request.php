<?php
ini_set('error_log', __DIR__ . '/php-error.log'); // Log errors to api/php-error.log
ob_start(); // Start output buffering to prevent accidental output
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'config.php';
require_once __DIR__ . '/vendor/autoload.php';
use Kreait\Firebase\Factory;

// GET: Fetch accounts for a customer
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['customer_id'])) {
    $customer_id = intval($_GET['customer_id']);
    $stmt = $conn->prepare("SELECT clw_account_id, label, street, barangay, municipality, province, account_number, account_name, meter_no, account_class, book_seq FROM tbl_clw_accounts WHERE customer_id=?");
    $stmt->bind_param("i", $customer_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $accounts = [];
    while ($row = $result->fetch_assoc()) {
        $accounts[] = $row;
    }
    ob_end_clean(); // Discard any previous output before sending JSON
    echo json_encode($accounts);
    $stmt->close();
    $conn->close();
    exit;
}   

// POST: Add a new job order
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($_GET['action'])) {
    $rawInput = file_get_contents("php://input");
    error_log('jo_request.php RAW POST: ' . $rawInput);

    $data = json_decode($rawInput, true);
    if ($data === null) {
        error_log('jo_request.php JSON decode error: ' . json_last_error_msg());
        http_response_code(400);
        ob_end_clean();
        echo json_encode(["error" => "Invalid JSON"]);
        exit;
    }

    // Required fields check
    $required = ['customer_id', 'clw_account_id', 'category'];
    foreach ($required as $field) {
        if (!isset($data[$field]) || $data[$field] === '') {
            http_response_code(400);
            ob_end_clean();
            echo json_encode(["error" => "Missing field: $field"]);
            $conn->close();
            exit;
        }
    }

    $notes        = $data['notes'] ?? null;
    $other_issue  = $data['other_issue'] ?? '';
    $isPredictive = $data['isPredictive'] ?? 0;

    // Philippine timestamp
    $manilaTz  = new DateTimeZone('Asia/Manila');
    $manilaNow = new DateTime('now', $manilaTz);
    $createdAt = $manilaNow->format('Y-m-d H:i:s');

    $stmt = $conn->prepare("
        INSERT INTO tbl_job_orders 
        (customer_id, clw_account_id, category, notes, other_issue, status, isPredictive, created_at)
        VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)
    ");
    $stmt->bind_param(
        "iisssis",
        $data['customer_id'],
        $data['clw_account_id'],
        $data['category'],
        $notes,
        $other_issue,
        $isPredictive,
        $createdAt
    );

    if ($stmt->execute()) {
        $job_order_id = $stmt->insert_id;

        // Generate jo_number
        $yy        = $manilaNow->format('y');
        $mmdd      = $manilaNow->format('md');
        $id_padded = str_pad($job_order_id, 4, '0', STR_PAD_LEFT);
        $jo_number = "JO$yy-$mmdd-$id_padded";

        $update = $conn->prepare("UPDATE tbl_job_orders SET jo_number=? WHERE job_order_id=?");
        $update->bind_param("si", $jo_number, $job_order_id);
        $update->execute();
        $update->close();

        // Predictive job order
        if (intval($isPredictive) === 1) {
            $bill_id     = $data['bill_id'] ?? null;
            $fluctuation = $data['fluctuation'] ?? null;

            $stmtPred = $conn->prepare("
                INSERT INTO tbl_predictive_jo (job_order_id, bill_id, fluctuation, created_at) 
                VALUES (?, ?, ?, ?)
            ");
            $stmtPred->bind_param("iids", $job_order_id, $bill_id, $fluctuation, $createdAt);
            $stmtPred->execute();
            $stmtPred->close();
        }

        // Fetch job order details
        $stmtDetails = $conn->prepare("
            SELECT jo.category AS reason, jo.status, 
                   CONCAT(p.first_name, ' ', p.last_name) AS plumber,
                   CONCAT(a.street, ', ', a.barangay, ', ', a.municipality, ', ', a.province) AS address
            FROM tbl_job_orders jo
            LEFT JOIN tbl_plumbers p ON jo.plumber_id = p.plumber_id
            INNER JOIN tbl_clw_accounts a ON jo.clw_account_id = a.clw_account_id
            WHERE jo.job_order_id = ?
        ");
        $stmtDetails->bind_param("i", $job_order_id);
        $stmtDetails->execute();
        $detailsResult = $stmtDetails->get_result();
        $detailsRow    = $detailsResult->fetch_assoc();
        $stmtDetails->close();

        // Save to Firebase
        try {
            $firebaseDb = (new Factory)
                ->withServiceAccount(__DIR__ . '/service-account.json')
                ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com')
                ->createDatabase();

            // Notifications node
            $firebaseDb->getReference('notifications/' . $data['customer_id'])->push([
                'title'     => 'Job Order Created',
                'body'      => "Your job order #$jo_number has been requested.",
                'timestamp' => $manilaNow->format('Y-m-d H:i:s'),
                'viewed'    => false,
                'adminViewed'    => false,
            ]);

            // Job orders node
            $result = $firebaseDb->getReference('job_orders/' . $job_order_id)->set([
                'reason'    => $detailsRow['reason'] ?? $data['category'],
                'status'    => $detailsRow['status'] ?? 'pending',
                'plumber'   => $detailsRow['plumber'] ?? '',
                'address'   => $detailsRow['address'] ?? '',
                'timestamp' => $manilaNow->format('Y-m-d H:i:s'),
            ]);

            error_log('Firebase job_orders saved: ' . print_r($result->getValue(), true));
        } catch (Throwable $e) {
            error_log('jo_request.php Firebase error: ' . $e->getMessage());
        }

        ob_end_clean();
        echo json_encode([
            "success"      => true,
            "job_order_id" => $job_order_id,
            "jo_number"    => $jo_number
        ]);
    } else {
        error_log('jo_request.php SQL error: ' . $stmt->error);
        http_response_code(500);
        ob_end_clean();
        echo json_encode(["error" => $stmt->error]);
    }

    $stmt->close();
    $conn->close();
    exit;
}

// POST: Add a new address (action=add_account or add_address)
if (
    $_SERVER['REQUEST_METHOD'] === 'POST'
    && isset($_GET['action'])
    && ($_GET['action'] === 'add_account' || $_GET['action'] === 'add_address')
) {
    $data = json_decode(file_get_contents("php://input"), true);

    $required = ['customer_id', 'label', 'street', 'barangay', 'municipality', 'province', 'account_number', 'account_name', 'meter_no', 'account_class', 'book_seq'];
    foreach ($required as $field) {
        if (!isset($data[$field]) || $data[$field] === '') {
            http_response_code(400);
            ob_end_clean(); // Discard any previous output before sending JSON
            echo json_encode(["error" => "Missing field: $field"]);
            $conn->close();
            exit;
        }
    }

    $stmt = $conn->prepare("INSERT INTO tbl_clw_accounts (customer_id, label, street, barangay, municipality, province, account_number, account_name, meter_no, account_class, book_seq) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param(
        "issssssssss",
        $data['customer_id'],
        $data['label'],
        $data['street'],
        $data['barangay'],
        $data['municipality'],
        $data['province'],
        $data['account_number'],
        $data['account_name'],
        $data['meter_no'],
        $data['account_class'],
        $data['book_seq'],
    );
    if ($stmt->execute()) {
        ob_end_clean(); // Discard any previous output before sending JSON
        echo json_encode(["success" => true, "clw_account_id" => $stmt->insert_id]);
    } else {
        http_response_code(409); // Conflict
        // Return a clean JSON error for duplicate entry or other SQL errors
        $errorMsg = $stmt->error;
        if (strpos($errorMsg, 'Duplicate entry') !== false) {
            ob_end_clean(); // Discard any previous output before sending JSON
            echo json_encode(["error" => "Account number already exists."]);
        } else {
            ob_end_clean(); // Discard any previous output before sending JSON
            echo json_encode(["error" => $errorMsg]);
        }
    }
    $stmt->close();
    $conn->close();
    exit;
}

// Only run PUT logic if the request method is PUT
// ...do not run any job order/account logic for PUT requests...

ob_end_clean(); // Discard any previous output before sending JSON
http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
