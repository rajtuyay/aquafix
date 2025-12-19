<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['job_order_id']) && isset($_GET['plumber_id'])) {
    $job_order_id = intval($_GET['job_order_id']);
    $plumber_id = intval($_GET['plumber_id']);

    // Fetch draft report for this job order and plumber
    $stmt = $conn->prepare("SELECT * FROM tbl_report WHERE job_order_id = ? AND plumber_id = ? AND is_draft = 1 LIMIT 1");
    $stmt->bind_param("ii", $job_order_id, $plumber_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $report = $result->fetch_assoc();
    $stmt->close();

    if ($report) {
        // Fetch materials for this report
        $materials = [];
        $stmt2 = $conn->prepare("
            SELECT 
                rm.material_id,
                m.material_name,
                m.size,
                m.price AS unit_price,
                rm.qty,
                rm.total_price
            FROM tbl_report_materials rm
            LEFT JOIN tbl_materials m ON rm.material_id = m.material_id
            WHERE rm.report_id=?
        ");
        $stmt2->bind_param("i", $report['report_id']);
        $stmt2->execute();
        $result2 = $stmt2->get_result();
        while ($row = $result2->fetch_assoc()) {
            $materials[] = $row;
        }
        $stmt2->close();

        $report['materials'] = $materials;

        // Fetch attachments
        $attachments = [];
        $stmt = $conn->prepare("SELECT report_media_id, media_type, file_path, thumbnail_path FROM tbl_report_media WHERE report_id=? ORDER BY report_media_id ASC");
        $stmt->bind_param("i", $report['report_id']);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $attachments[] = $row;
        }
        $stmt->close();

        $report['attachments'] = $attachments;

        echo json_encode($report);
        exit;
    } else {
        http_response_code(404);
        echo json_encode(["error" => "Draft report not found"]);
        exit;
    }
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();