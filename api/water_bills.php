<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include 'config.php';

// GET: Fetch all water bills for a customer
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['customer_id'])) {
    $customer_id = intval($_GET['customer_id']);
    $clw_account_id = isset($_GET['clw_account_id']) ? $_GET['clw_account_id'] : null;
    if ($clw_account_id !== null) {
        $stmt = $conn->prepare("SELECT * FROM tbl_water_bills WHERE customer_id=? AND clw_account_id=? ORDER BY year, FIELD(month, 'January','February','March','April','May','June','July','August','September','October','November','December')");
        $stmt->bind_param("is", $customer_id, $clw_account_id);
    } else {
        $stmt = $conn->prepare("SELECT * FROM tbl_water_bills WHERE customer_id=? ORDER BY year, FIELD(month, 'January','February','March','April','May','June','July','August','September','October','November','December')");
        $stmt->bind_param("i", $customer_id);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $bills = [];
    while ($row = $result->fetch_assoc()) {
        $bills[] = $row;
    }
    echo json_encode($bills);
    exit;
}

// POST: Add a new water bill
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);
    $required = ['customer_id', 'year', 'month', 'consumption', 'price', 'amount', 'clw_account_id'];
    foreach ($required as $field) {
        if (!isset($data[$field]) || $data[$field] === '') {
            http_response_code(400);
            echo json_encode(["error" => "Missing field: $field"]);
            exit;
        }
    }
    $stmt = $conn->prepare("INSERT INTO tbl_water_bills (customer_id, year, month, consumption, price, amount, clw_account_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $manilaTz = new DateTimeZone('Asia/Manila');
    $manilaNow = new DateTime('now', $manilaTz);
    $createdAt = $manilaNow->format('Y-m-d H:i:s');
    $stmt->bind_param(
        "iisidsis",
        $data['customer_id'],
        $data['year'],
        $data['month'],
        $data['consumption'],
        $data['price'],
        $data['amount'],
        $data['clw_account_id'],
        $createdAt
    );
    if ($stmt->execute()) {
        echo json_encode(["success" => true, "bill_id" => $stmt->insert_id]);
    } else {
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
    }
    exit;
}

// DELETE: Remove a water bill by bill_id
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    // Parse bill_id from query string
    parse_str($_SERVER['QUERY_STRING'], $params);
    $bill_id = isset($params['bill_id']) ? intval($params['bill_id']) : null;
    if (!$bill_id) {
        http_response_code(400);
        echo json_encode(["error" => "Missing or invalid bill_id"]);
        exit;
    }
    $stmt = $conn->prepare("DELETE FROM tbl_water_bills WHERE bill_id=?");
    $stmt->bind_param("i", $bill_id);
    if ($stmt->execute()) {
        echo json_encode(["success" => true]);
    } else {
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
    }
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
