<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if (!isset($_GET['job_order_id'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing job_order_id']);
    exit;
}

$job_order_id = intval($_GET['job_order_id']);
$stmt = $conn->prepare("SELECT jo_number, isConfirmed FROM tbl_job_orders WHERE job_order_id = ?");
$stmt->bind_param("i", $job_order_id);
$stmt->execute();
$stmt->bind_result($jo_number, $isConfirmed); // <-- bind both columns

if ($stmt->fetch()) {
    echo json_encode(['jo_number' => $jo_number, 'isConfirmed' => $isConfirmed]);
} else {
    http_response_code(404);
    echo json_encode(['error' => 'Job order not found']);
}

$stmt->close();
$conn->close();