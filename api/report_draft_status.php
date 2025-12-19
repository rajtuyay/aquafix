<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['job_order_id'])) {
    $job_order_id = intval($_GET['job_order_id']);
    $plumber_id = isset($_GET['plumber_id']) ? intval($_GET['plumber_id']) : null;

    // Fetch the latest report for this job order and plumber (if provided)
    if ($plumber_id) {
        $stmt = $conn->prepare("SELECT report_id, is_draft FROM tbl_report WHERE job_order_id=? AND plumber_id=? ORDER BY report_id DESC LIMIT 1");
        $stmt->bind_param("ii", $job_order_id, $plumber_id);
    } else {
        $stmt = $conn->prepare("SELECT report_id, is_draft FROM tbl_report WHERE job_order_id=? ORDER BY report_id DESC LIMIT 1");
        $stmt->bind_param("i", $job_order_id);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $report = $result->fetch_assoc();
    $stmt->close();

    if ($report) {
        echo json_encode($report);
        exit;
    } else {
        http_response_code(404);
        echo json_encode(["error" => "Report not found"]);
        exit;
    }
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();