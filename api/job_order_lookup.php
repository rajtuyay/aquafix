<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');

// Database connection
require_once 'config.php'; // <-- adjust path as needed

if (!isset($_GET['jo_number'])) {
    echo json_encode(['error' => 'Missing jo_number']);
    exit;
}

$jo_number = $_GET['jo_number'];

// Debug: print jo_number to error log
error_log("job_order_lookup.php jo_number received: $jo_number");

// Debug: check DB connection
if (!$conn) {
    echo json_encode(['error' => 'DB connection failed']);
    exit;
}

// Debug: check if jo_number is received
// file_put_contents('lookup_debug.txt', "jo_number: $jo_number\n", FILE_APPEND);
// Debug: write jo_number to a file in your public_html or aquafix folder
file_put_contents(__DIR__ . '/lookup_debug.txt', date('c') . " jo_number: $jo_number\n", FILE_APPEND);

// Prepare and execute query
$stmt = $conn->prepare("SELECT job_order_id, isConfirmed FROM tbl_job_orders WHERE jo_number = ?");
if (!$stmt) {
    echo json_encode(['error' => 'Prepare failed', 'details' => $conn->error]);
    exit;
}
$stmt->bind_param("s", $jo_number);
$stmt->execute();
$stmt->bind_result($job_order_id, $isConfirmed);

if ($stmt->fetch()) {
    echo json_encode([
        'job_order_id' => $job_order_id,
        'jo_number' => $jo_number,
        'isConfirmed' => $isConfirmed // <-- this was missing!
    ]);
} else {
    echo json_encode(['error' => 'Not found', 'jo_number' => $jo_number]);
}

$stmt->close();
$conn->close();
?>
