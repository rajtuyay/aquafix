<?php
// echo "plumbers.php called\n"; // DEBUG: Remove or comment out this line
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT, DELETE");
header("Content-Type: application/json; charset=UTF-8");

include 'config.php';
require_once __DIR__ . '/vendor/autoload.php';

use Kreait\Firebase\Factory;

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

// Helper function to generate plumber_no
function generateAquaFixId() {
    $date = date('Ymd');
    $rand = strtoupper(substr(bin2hex(random_bytes(4)), 0, 5));
    return "AQUA-$date-$rand";
}

// GET all plumbers
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $result = $conn->query("SELECT * FROM tbl_plumbers");
    $plumbers = [];
    while ($row = $result->fetch_assoc()) {
        $plumbers[] = $row;
    }
    echo json_encode($plumbers);
    exit;
}

// LOGIN: Authenticate plumber
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['action']) && $_GET['action'] === 'login') {
    file_put_contents('login_debug.txt', date('c') . " - plumbers.php login POST\n", FILE_APPEND);
    $data = json_decode(file_get_contents("php://input"), true);
    if (
        ((!isset($data['username']) || $data['username'] === '') &&
        (!isset($data['email']) || $data['email'] === '')) ||
        !isset($data['password'])
    ) {
        http_response_code(400);
        echo json_encode(["error" => "Missing username/email or password"]);
        exit;
    }
    $loginInput = $data['username'] ?? '';
    $emailInput = $data['email'] ?? '';
    $password = $data['password'];

    // Try to find plumber by username or email
    $stmt = $conn->prepare("SELECT * FROM tbl_plumbers WHERE username=? OR email=? LIMIT 1");
    file_put_contents('login_debug.txt', date('c') . " - plumbers.php DB query prepared\n", FILE_APPEND);
    $stmt->bind_param("ss", $loginInput, $emailInput);
    $stmt->execute();
    $result = $stmt->get_result();
    file_put_contents('login_debug.txt', date('c') . " - plumbers.php DB query executed\n", FILE_APPEND);
    $user = $result->fetch_assoc();
    $stmt->close();
    if ($user) {
        if ($user['account_status'] === 'Deactivated') {
            http_response_code(403);
            echo json_encode(["success" => false, "error" => "Your account is deactivated. Please contact support."]);
            exit;
        }
        $usernameRaw = $user['username'];
        // Debug: log values for troubleshooting
        file_put_contents('login_debug.txt', "LOGIN usernameRaw: $usernameRaw, password: $password, db_password: {$user['password']}\n", FILE_APPEND);

        // Case 1: User enters current (hashed) password
        if (password_verify($password, $user['password'])) {
            unset($user['password']);
            // If username == password and hash matches, force password change
            if ($usernameRaw === $password) {
                echo json_encode([
                    "success" => true,
                    "user" => $user,
                    "require_password_change" => true // force change
                ]);
            } else {
                echo json_encode([
                    "success" => true,
                    "user" => $user,
                    "require_password_change" => false
                ]);
            }
            exit;
        }

        // Otherwise invalid
        http_response_code(401);
        echo json_encode(["success" => false, "error" => "Invalid credentials"]);
    } else {
        http_response_code(401);
        echo json_encode(["success" => false, "error" => "Invalid credentials"]);
    }
    exit;
}

// Update availability status
if (isset($_GET['action']) && $_GET['action'] === 'update_availability') {
    $input = json_decode(file_get_contents('php://input'), true);
    $plumber_id = $input['plumber_id'] ?? '';
    $availability_status = $input['availability_status'] ?? '';
    if ($plumber_id && $availability_status) {
        $stmt = $conn->prepare("UPDATE tbl_plumbers SET availability_status=? WHERE plumber_id=?");
        $plumber_id_int = intval($plumber_id);
        $stmt->bind_param("si", $availability_status, $plumber_id_int);
        if ($stmt->execute()) {
            // Update Firebase as well
            try {
                $factory = (new Factory)
                    ->withServiceAccount(__DIR__ . '/service-account.json')
                    ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com');
                $database = $factory->createDatabase();
                $database->getReference('settings/' . '/plumbers/' . $plumber_id)
                    ->update(['availability_status' => $availability_status]);
            } catch (Throwable $e) {
                error_log('Firebase plumber availability update error: ' . $e->getMessage());
            }
            echo json_encode(['success' => true]);
        } else {
            http_response_code(500);
            echo json_encode(['success' => false, 'error' => $stmt->error]);
        }
        $stmt->close();
        exit;
    }
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Missing parameters']);
    exit;
}

// POST: Add plumber (Registration)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && (!isset($_GET['action']) || $_GET['action'] !== 'login')) {
    $data = json_decode(file_get_contents("php://input"), true);

    // Validate required fields
    $required = ['username', 'password', 'email', 'first_name', 'last_name', 'contact_no', 'birthday', 'gender', 'profile_image'];
    foreach ($required as $field) {
        if (!isset($data[$field]) || $data[$field] === null || $data[$field] === '') {
            http_response_code(400);
            echo json_encode(["error" => "Missing or empty field: $field"]);
            exit;
        }
    }

    // Hash the password before storing
    $hashedPassword = password_hash($data['password'], PASSWORD_DEFAULT);

    // Generate plumber_no if not provided or empty
    $plumber_no = isset($data['plumber_no']) && !empty($data['plumber_no'])
        ? $data['plumber_no']
        : generateAquaFixId();

    $stmt = $conn->prepare("INSERT INTO tbl_plumbers (username, password, email, first_name, last_name, plumber_no, contact_no, birthday, gender, profile_image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->bind_param(
        "ssssssssss",
        $data['username'],
        $hashedPassword, // <-- make sure this is hashed!
        $data['email'],
        $data['first_name'],
        $data['last_name'],
        $plumber_no,
        $data['contact_no'],
        $data['birthday'],
        $data['gender'],
        $data['profile_image']
    );
    $stmt->execute();
    echo json_encode(["id" => $stmt->insert_id, "plumber_no" => $plumber_no]);
    $stmt->close();
    exit;
}

// PUT: Update plumber
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data['plumber_id'])) {
        http_response_code(400);
        echo json_encode(["error" => "Missing plumber_id"]);
        exit;
    }
    $plumber_id = intval($data['plumber_id']);

    // Build dynamic SQL for only provided fields
    $fields = [];
    $params = [];
    $types = '';

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
    if (isset($data['plumber_no'])) {
        $fields[] = "plumber_no=?";
        $params[] = $data['plumber_no'];
        $types .= 's';
    }
    if (isset($data['email'])) {
        $fields[] = "email=?";
        $params[] = $data['email'];
        $types .= 's';
    }
    // Add address field update
    if (isset($data['address'])) {
        $fields[] = "address=?";
        $params[] = $data['address'];
        $types .= 's';
    }
    if (isset($data['current_password']) && isset($data['new_password'])) {
        $stmt = $conn->prepare("SELECT password FROM tbl_plumbers WHERE plumber_id=?");
        $stmt->bind_param("i", $plumber_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        if (!$row || !password_verify($data['current_password'], $row['password'])) {
            $stmt->close();
            http_response_code(400);
            echo json_encode(["error" => "Current password is incorrect"]);
            exit;
        }
        $stmt->close();
        $fields[] = "password=?";
        $params[] = password_hash($data['new_password'], PASSWORD_DEFAULT);
        $types .= 's';
    } elseif (isset($data['password']) && !empty($data['password'])) {
        $fields[] = "password=?";
        $params[] = password_hash($data['password'], PASSWORD_DEFAULT);
        $types .= 's';
    }

    if (empty($fields)) {
        http_response_code(400);
        echo json_encode(["error" => "No fields to update"]);
        exit;
    }

    $params[] = $plumber_id;
    $types .= 'i';

    $sql = "UPDATE tbl_plumbers SET " . implode(', ', $fields) . " WHERE plumber_id=?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    echo json_encode(["updated" => $stmt->affected_rows]);
    $stmt->close();
    exit;
}

// DELETE: Delete plumber
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data['plumber_id'])) {
        http_response_code(400);
        echo json_encode(["error" => "Missing plumber_id"]);
        exit;
    }
    $plumber_id = intval($data['plumber_id']);
    $stmt = $conn->prepare("DELETE FROM tbl_plumbers WHERE plumber_id=?");
    $stmt->bind_param("i", $plumber_id);
    $stmt->execute();
    echo json_encode(["deleted" => $stmt->affected_rows]);
    $stmt->close();
    exit;
}

$conn->close();
?>
$conn->close();
?>
