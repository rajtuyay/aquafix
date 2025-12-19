<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['report_id'])) {
    $report_id = intval($_GET['report_id']);
    $stmt = $conn->prepare("SELECT report_media_id, report_id, media_type, file_path, uploaded_at FROM tbl_report_media WHERE report_id=? ORDER BY report_media_id ASC");
    $stmt->bind_param("i", $report_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $media = [];
    while ($row = $result->fetch_assoc()) {
        $media[] = $row;
    }
    echo json_encode($media);
    exit;
}
http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
