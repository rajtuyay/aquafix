<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: PUT, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

include 'config.php';

// Only allow PUT requests
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    // Parse bill_id from query string
    parse_str($_SERVER['QUERY_STRING'], $params);
    $bill_id = isset($params['bill_id']) ? intval($params['bill_id']) : null;
    if (!$bill_id) {
        http_response_code(400);
        echo json_encode(["error" => "Missing or invalid bill_id"]);
        exit;
    }

    // Get JSON body
    $data = json_decode(file_get_contents("php://input"), true);
    if (!$data) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid JSON body"]);
        exit;
    }

    // Only allow updating consumption, price, and amount
    $fields = [];
    $types = '';
    $values = [];

    if (isset($data['consumption'])) {
        $fields[] = 'consumption=?';
        $types .= 'i';
        $values[] = $data['consumption'];
    }
    if (isset($data['price'])) {
        $fields[] = 'price=?';
        $types .= 'd';
        $values[] = $data['price'];
    }
    if (isset($data['amount'])) {
        $fields[] = 'amount=?';
        $types .= 'd';
        $values[] = $data['amount'];
    }

    if (empty($fields)) {
        http_response_code(400);
        echo json_encode(["error" => "No fields to update"]);
        exit;
    }

    $sql = "UPDATE tbl_water_bills SET " . implode(', ', $fields) . " WHERE bill_id=?";
    $types .= 'i';
    $values[] = $bill_id;

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$values);

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