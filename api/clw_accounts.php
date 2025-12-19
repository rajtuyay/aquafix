<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include 'config.php';

// GET all accounts or accounts for a specific customer
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if (isset($_GET['customer_id'])) {
        $customer_id = intval($_GET['customer_id']);
        // Explicitly select account_class (enum) and all fields
        $stmt = $conn->prepare("SELECT clw_account_id, customer_id, label, street, barangay, municipality, province, account_number, account_name, meter_no, account_class, book_seq FROM tbl_clw_accounts WHERE customer_id=?");
        $stmt->bind_param("i", $customer_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $accounts = [];
        while ($row = $result->fetch_assoc()) {
            $accounts[] = $row;
        }
        echo json_encode($accounts);
        exit;
    } else {
        // Explicitly select account_class (enum) and all fields
        $result = $conn->query("SELECT clw_account_id, customer_id, label, street, barangay, municipality, province, account_number, account_name, meter_no, account_class, book_seq FROM tbl_clw_accounts");
        $accounts = [];
        while ($row = $result->fetch_assoc()) {
            $accounts[] = $row;
        }
        echo json_encode($accounts);
        exit;
    }
}

// POST: Add account 
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    $required = ['customer_id', 'label', 'street', 'barangay', 'municipality', 'province', 'account_number', 'account_name', 'meter_no', 'account_class', 'book_seq'];
    foreach ($required as $field) {
        if (!isset($data[$field]) || $data[$field] === '') {
            http_response_code(400);
            echo json_encode(["error" => "Missing field: $field"]);
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
        $data['book_seq']
    );
    if ($stmt->execute()) {
        echo json_encode(["success" => true, "clw_account_id" => $stmt->insert_id]);
    } else {
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
    }
    exit;
}

// PUT: Update account
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $data = json_decode(file_get_contents("php://input"), true);
    file_put_contents('php://stderr', "PUT received: " . print_r($data, true));

    // Accept both 'id' and 'clw_account_id'
    $id = null;
    if (isset($data['id'])) {
        $id = intval($data['id']);
    } elseif (isset($data['clw_account_id'])) {
        $id = intval($data['clw_account_id']);
    }
    if (!$id || $id <= 0) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Missing or invalid account id"]);
        exit;
    }
    $required = ['label', 'street', 'barangay', 'municipality', 'province', 'account_number', 'account_name', 'meter_no', 'account_class', 'book_seq', 'updated_at'];
    foreach ($required as $field) {
        if (!isset($data[$field])) {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "Missing field: $field", "data" => $data]);
            exit;
        }
    }
    $stmt = $conn->prepare("UPDATE tbl_clw_accounts SET label=?, street=?, barangay=?, municipality=?, province=?, account_number=?, account_name=?, meter_no=?, account_class=?, book_seq=?, updated_at=? WHERE clw_account_id=?");
    $stmt->bind_param(
        "sssssssssssi",
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
        $data['updated_at'],
        $id
    );
    file_put_contents('php://stderr', "SQL: UPDATE tbl_clw_accounts SET label=?, street=?, barangay=?, municipality=?, province=?, account_number=?, account_name=?, meter_no=?, account_class=?, updated_at=? WHERE clw_account_id=?\n");
    file_put_contents('php://stderr', "Values: " . implode(", ", [
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
        $data['updated_at'],
        $id
    ]) . "\n");
    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Update failed: " . $stmt->error,
            "data" => $data,
            "sql" => "UPDATE tbl_clw_accounts SET label=?, street=?, barangay=?, municipality=?, province=?, account_number=?, account_name=?, meter_no=?, account_class=?, book_seq=?, updated_at=? WHERE clw_account_id=?"
        ]);
        exit;
    }
    if ($stmt->affected_rows > 0) {
        echo json_encode(["success" => true, "message" => "Account updated successfully.", "updated" => $stmt->affected_rows]);
    } else {
        // No rows updated (maybe same data or id not found)
        echo json_encode(["success" => false, "message" => "No changes made or account not found.", "updated" => $stmt->affected_rows]);
    }
    exit;
}

// DELETE: Delete account
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data['id'])) {
        http_response_code(400);
        echo json_encode(["error" => "Missing account id"]);
        exit;
    }
    $id = intval($data['id']);
    if ($id <= 0) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid account id"]);
        exit;
    }
    $stmt = $conn->prepare("DELETE FROM tbl_clw_accounts WHERE clw_account_id=?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    echo json_encode(["deleted" => $stmt->affected_rows]);
    exit;
}

$conn->close();
?>