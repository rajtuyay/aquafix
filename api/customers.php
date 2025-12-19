<?php
// Remove or comment out this line:
// echo "customers.php called\n"; // DEBUG: Remove this line
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';
// DEBUG: Confirm API is hit and DB connection is OK
file_put_contents('login_debug.txt', date('c') . " - customers.php called\n", FILE_APPEND);

// DEBUG: Output DB connection error if any
if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(["error" => "Database connection failed: " . $conn->connect_error]);
    exit;
}

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Helper function to generate aquafix_no
function generateAquaFixId() {
    $date = date('Ymd');
    $rand = strtoupper(substr(bin2hex(random_bytes(4)), 0, 5));
    return "AQUA-$date-$rand";
}

// GET all customers
if ($_SERVER['REQUEST_METHOD'] === 'GET' && !isset($_GET['customer_id'])) {
    $result = $conn->query("SELECT *, contact_no AS customer_phone FROM tbl_customers");
    $customers = [];
    while ($row = $result->fetch_assoc()) {
        $customers[] = $row;
    }
    echo json_encode($customers);
    exit;
}

// GET single customer by customer_id
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['customer_id'])) {
    $customer_id = intval($_GET['customer_id']);
    $stmt = $conn->prepare("SELECT *, contact_no AS customer_phone FROM tbl_customers WHERE customer_id=? LIMIT 1");
    $stmt->bind_param("i", $customer_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $customer = $result->fetch_assoc();
    $stmt->close();
    if ($customer) {
        echo json_encode($customer);
    } else {
        http_response_code(404);
        echo json_encode(["error" => "Customer not found"]);
    }
    exit;
}

// LOGIN: Authenticate user
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['action']) && $_GET['action'] === 'login') {
    file_put_contents('login_debug.txt', date('c') . " - customers.php login POST\n", FILE_APPEND);
    $data = json_decode(file_get_contents("php://input"), true);
    if (
        (!isset($data['username']) || $data['username'] === '') &&
        (!isset($data['email']) || $data['email'] === '') ||
        !isset($data['password'])
    ) {
        http_response_code(400);
        echo json_encode(["error" => "Missing username/email or password"]);
        exit;
    }
    $loginInput = $data['username'] ?? '';
    $emailInput = $data['email'] ?? '';
    $password = $data['password'];

    // Try to find user by username or email
    $stmt = $conn->prepare("SELECT * FROM tbl_customers WHERE username=? OR email=? LIMIT 1");
    file_put_contents('login_debug.txt', date('c') . " - customers.php DB query prepared\n", FILE_APPEND);
    $stmt->bind_param("ss", $loginInput, $emailInput);
    $stmt->execute();
    $result = $stmt->get_result();
    file_put_contents('login_debug.txt', date('c') . " - customers.php DB query executed\n", FILE_APPEND);
    $user = $result->fetch_assoc();
    $stmt->close(); // <-- Add this line
    if ($user && password_verify($password, $user['password'])) {
        unset($user['password']); // Don't return password hash
        echo json_encode(["success" => true, "user" => $user]);
        exit; // Only exit on success
    } else {
        http_response_code(401);
        echo json_encode(["success" => false, "error" => "Invalid credentials!"]);
        // Do NOT exit here, so the client can try plumber login if needed
    }
    exit;
}

// POST: Add customer (Registration)
// Only insert into tbl_customers when POST is called with valid registration data.
if ($_SERVER['REQUEST_METHOD'] === 'POST' && (!isset($_GET['action']) || $_GET['action'] !== 'login')) {
    sleep(1);
    $data = json_decode(file_get_contents("php://input"), true);
    // Hash the password before storing
    $hashedPassword = password_hash($data['password'], PASSWORD_DEFAULT);

    // Generate aquafix_no if not provided or empty
    $aquafix_no = isset($data['aquafix_no']) && !empty($data['aquafix_no'])
        ? $data['aquafix_no']
        : generateAquaFixId();

    // Optionally enforce "+63" format server-side
    if (isset($data['contact_no']) && !preg_match('/^\+63 \d{10}$/', $data['contact_no'])) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid phone number format."]);
        exit;
    }

    $stmt = $conn->prepare("INSERT INTO tbl_customers (username, password, email, first_name, last_name, aquafix_no, contact_no, birthday, gender, profile_image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param(
        "ssssssssss",
        $data['username'],
        $hashedPassword,
        $data['email'],
        $data['first_name'],
        $data['last_name'],
        $aquafix_no,
        $data['contact_no'],
        $data['birthday'], 
        $data['gender'],
        $data['profile_image']
    );
    $stmt->execute();
    $stmt->close();
    echo json_encode(["id" => $stmt->insert_id, "aquafix_no" => $aquafix_no]);
    exit;
}

// PUT: Update customer
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data['customer_id'])) {
        http_response_code(400);
        echo json_encode(["error" => "Missing customer_id"]);
        exit;
    }
    $customer_id = intval($data['customer_id']);

    date_default_timezone_set('Asia/Manila');

    if (isset($data['username'])) {
        $fields[] = "username=?";
        $params[] = $data['username'];
        $types .= 's';
    }
    if (isset($data['first_name'])) {
        $fields[] = "first_name=?";
        $params[] = $data['first_name'];
        $types .= 's';
    }
    if (isset($data['last_name'])) {
        $fields[] = "last_name=?";
        $params[] = $data['last_name'];
        $types .= 's';
    }
    if (isset($data['contact_no'])) {
        $fields[] = "contact_no=?";
        $params[] = $data['contact_no'];
        $types .= 's';
    }
    if (isset($data['birthday'])) {
        $fields[] = "birthday=?";
        $params[] = $data['birthday']; 
        $types .= 's';
    }
    if (isset($data['gender'])) {
        $fields[] = "gender=?";
        $params[] = $data['gender'];
        $types .= 's';
    }
    if (isset($data['profile_image'])) {
        $fields[] = "profile_image=?";
        $params[] = $data['profile_image'];
        $types .= 's';
    }
    // Only allow aquafix_no update if you want, otherwise skip
    if (isset($data['aquafix_no'])) {
        $fields[] = "aquafix_no=?";
        $params[] = $data['aquafix_no'];
        $types .= 's';
    }
    // Only update email if provided (from security page)
    if (isset($data['email'])) {
        $fields[] = "email=?";
        $params[] = $data['email'];
        $types .= 's';
    }
    // Only update password if both current_password and new_password are provided and valid
    if (isset($data['current_password']) && isset($data['new_password'])) {
        // Fetch current hashed password from DB
        $stmt = $conn->prepare("SELECT password FROM tbl_customers WHERE customer_id=?");
        $stmt->bind_param("i", $customer_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        if (!$row || !password_verify($data['current_password'], $row['password'])) {
            $stmt->close(); // <-- Always close before exit
            http_response_code(400);
            echo json_encode(["error" => "Current password is incorrect"]);
            exit;
        }
        $stmt->close(); // <-- Close after use
        // If correct, update password
        $fields[] = "password=?";
        $params[] = password_hash($data['new_password'], PASSWORD_DEFAULT);
        $types .= 's';
    } elseif (isset($data['password']) && !empty($data['password'])) {
        // Legacy: only allow direct password update if no current_password logic is used
        $fields[] = "password=?";
        $params[] = password_hash($data['password'], PASSWORD_DEFAULT);
        $types .= 's';
    }

    // Build dynamic SQL for only provided fields
    $fields[] = "updated_at=?";
    $params[] = date('Y-m-d H:i:s');
    $types .= 's';

    if (empty($fields)) {
        http_response_code(400);
        echo json_encode(["error" => "No fields to update"]);
        exit;
    }

    $params[] = $customer_id;
    $types .= 'i';

    $sql = "UPDATE tbl_customers SET " . implode(', ', $fields) . " WHERE customer_id=?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $stmt->close(); // Close the statement

    if ($stmt->error) {
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
        exit;
    }

    echo json_encode(["updated" => $stmt->affected_rows]);
    exit;
}

// DELETE: Delete customer
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data['customer_id'])) {
        http_response_code(400);
        echo json_encode(["error" => "Missing customer_id"]);
        exit;
    }
    $customer_id = intval($data['customer_id']);
    $stmt = $conn->prepare("DELETE FROM tbl_customers WHERE customer_id=?");
    $stmt->bind_param("i", $customer_id);
    $stmt->execute();
    $stmt->close(); // Close the statement
    echo json_encode(["deleted" => $stmt->affected_rows]);
    exit;
}

$conn->close();
?>