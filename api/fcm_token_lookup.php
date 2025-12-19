<?php
header('Content-Type: application/json');
include 'config.php';

$customer_id = isset($_GET['customer_id']) ? intval($_GET['customer_id']) : 0;

if ($customer_id <= 0) {
    echo json_encode(['fcm_token' => '']);
    exit;
}

$stmt = $conn->prepare("SELECT fcm_token FROM tbl_customers WHERE customer_id = ?");
$stmt->bind_param("i", $customer_id);
$stmt->execute();
$stmt->bind_result($fcm_token);
if ($stmt->fetch() && $fcm_token) {
    echo json_encode(['fcm_token' => $fcm_token]);
} else {
    echo json_encode(['fcm_token' => '']);
}
$stmt->close();
$conn->close();
?>
