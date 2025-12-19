<?php
header('Content-Type: application/json');
require_once '../db_connect.php'; // adjust path as needed

$job_order_id = isset($_GET['job_order_id']) ? intval($_GET['job_order_id']) : 0;

if ($job_order_id <= 0) {
    echo json_encode(['fcm_token' => '']);
    exit;
}

// Find customer_id from job_order_id
$stmt = $conn->prepare("SELECT customer_id FROM tbl_job_orders WHERE job_order_id = ?");
$stmt->bind_param("i", $job_order_id);
$stmt->execute();
$stmt->bind_result($customer_id);
if ($stmt->fetch() && $customer_id) {
    $stmt->close();
    // Get fcm_token from tbl_customers
    $stmt2 = $conn->prepare("SELECT fcm_token FROM tbl_customers WHERE customer_id = ?");
    $stmt2->bind_param("i", $customer_id);
    $stmt2->execute();
    $stmt2->bind_result($fcm_token);
    if ($stmt2->fetch() && $fcm_token) {
        echo json_encode(['fcm_token' => $fcm_token]);
    } else {
        echo json_encode(['fcm_token' => '']);
    }
    $stmt2->close();
} else {
    echo json_encode(['fcm_token' => '']);
    $stmt->close();
}

$conn->close();
?>
