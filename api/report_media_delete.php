<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

$data = json_decode(file_get_contents("php://input"), true);
$report_media_id = intval($data['report_media_id'] ?? 0);

if ($report_media_id > 0) {
    // Get file and thumbnail names
    $stmt = $conn->prepare("SELECT file_path, thumbnail_path FROM tbl_report_media WHERE report_media_id=?");
    $stmt->bind_param("i", $report_media_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $stmt->close();

    $success = false;
    if ($row) {
        $media_dir = "../uploads/report_media/";
        $file_path = $row['file_path'];
        $thumb_path = $row['thumbnail_path'];

        // Delete files if exist
        if ($file_path && file_exists($media_dir . $file_path)) {
            @unlink($media_dir . $file_path);
        }
        if ($thumb_path && file_exists($media_dir . $thumb_path)) {
            @unlink($media_dir . $thumb_path);
        }

        // Delete DB record
        $stmt = $conn->prepare("DELETE FROM tbl_report_media WHERE report_media_id=?");
        $stmt->bind_param("i", $report_media_id);
        $success = $stmt->execute();
        $stmt->close();
    }

    echo json_encode(['success' => $success]);
    exit;
}

http_response_code(400);
echo json_encode(['error' => 'Invalid report_media_id']);
$conn->close();
