<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['job_order_id'])) {
    $job_order_id = intval($_GET['job_order_id']);
    // Use the correct column names from your table structure
    $stmt = $conn->prepare("SELECT jo_media_id, job_order_id, media_type, file_path, uploaded_at FROM tbl_jo_media WHERE job_order_id=? ORDER BY jo_media_id ASC");
    $stmt->bind_param("i", $job_order_id);
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
