<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

$user_type = $_POST['user_type'] ?? '';
$user_id = $_POST['user_id'] ?? '';
$fcm_token = $_POST['fcm_token'] ?? '';

if (!$user_type || !$user_id || !$fcm_token) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing parameters']);
    exit;
}

$table = $user_type === 'plumber' ? 'tbl_plumbers' : 'tbl_customers';
$id_field = $user_type === 'plumber' ? 'plumber_id' : 'customer_id';

// Add a column `fcm_token` to your tbl_customers and tbl_plumbers tables if not present.

$stmt = $conn->prepare("UPDATE $table SET fcm_token=? WHERE $id_field=?");
$stmt->bind_param("si", $fcm_token, $user_id);
if ($stmt->execute()) {
    echo json_encode(['success' => true]);
} else {
    http_response_code(500);
    echo json_encode(['error' => $stmt->error]);
}
$conn->close();
