<?php
header('Content-Type: application/json');
require_once 'config.php';

if (!isset($_GET['job_order_id'])) {
    echo json_encode(['error' => 'Missing job_order_id']);
    exit;
}

$job_order_id = intval($_GET['job_order_id']);
$stmt = $conn->prepare("SELECT status, isConfirmed FROM tbl_job_orders WHERE job_order_id = ? LIMIT 1");
$stmt->bind_param("i", $job_order_id);
$stmt->execute();
$stmt->bind_result($status, $isConfirmed);

if ($stmt->fetch()) {
    echo json_encode([
        'status' => $status,
        'isConfirmed' => $isConfirmed
    ]);
} else {
    echo json_encode(['error' => 'Not found']);
}

$stmt->close();
$conn->close();
?>
