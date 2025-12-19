<?php
// filepath: c:\xampp\htdocs\aquafix\api\report_save.php
header('Content-Type: application/json');
include 'config.php';

$data = json_decode(file_get_contents('php://input'), true);

$job_order_id = $data['job_order_id'] ?? '';
$plumber_id = $data['plumber_id'] ?? '';
$category = $data['category'] ?? '';
$action_taken = $data['action_taken'] ?? '';
$root_cause = $data['root_cause'] ?? '';
$date_time_started = $data['date_time_started'] ?? '';
$date_time_finished = $data['date_time_finished'] ?? '';
$status = $data['status'] ?? '';
$remarks = $data['remarks'] ?? '';
$materials = $data['materials'] ?? []; // now array, not JSON string
$accomplished_by = $data['accomplished_by'] ?? '';
$is_draft = isset($data['is_draft']) ? 1 : 0;
$report_id = $data['report_id'] ?? null;

if ($report_id) {
    // Update existing report
    $stmt = $conn->prepare("UPDATE tbl_report SET job_order_id=?, plumber_id=?, category=?, action_taken=?, root_cause=?, date_time_started=?, date_time_finished=?, status=?, remarks=?, accomplished_by=?, is_draft=? WHERE report_id=?");
    $stmt->bind_param("iissssssssii", $job_order_id, $plumber_id, $category, $action_taken, $root_cause, $date_time_started, $date_time_finished, $status, $remarks, $accomplished_by, $is_draft, $report_id);
    $success = $stmt->execute();

    // Delete old materials for this report
    $conn->query("DELETE FROM tbl_report_materials WHERE report_id = $report_id");
} else {
    // Insert new report (set created_at automatically)
    $stmt = $conn->prepare("INSERT INTO tbl_report (job_order_id, plumber_id, category, action_taken, root_cause, date_time_started, date_time_finished, status, remarks, accomplished_by, is_draft, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $manilaTz = new DateTimeZone('Asia/Manila');
    $manilaNow = new DateTime('now', $manilaTz);
    $createdAt = $manilaNow->format('Y-m-d H:i:s');
    $stmt->bind_param("iissssssssis", $job_order_id, $plumber_id, $category, $action_taken, $root_cause, $date_time_started, $date_time_finished, $status, $remarks, $accomplished_by, $is_draft, $createdAt);
    $success = $stmt->execute();
    $report_id = $conn->insert_id;
}

// Insert materials into tbl_report_materials
if (is_array($materials)) {
    foreach ($materials as $mat) {
        $material_id = intval($mat['material_id'] ?? 0);
        $qty = intval($mat['qty'] ?? 0);
        $total_price = number_format((float) ($mat['total_price'] ?? 0), 2, '.', '');
        $stmt2 = $conn->prepare(
            "INSERT INTO tbl_report_materials (report_id, material_id, qty, total_price)
             VALUES (?, ?, ?, ?)"
        );
        $stmt2->bind_param("iiid", $report_id, $material_id, $qty, $total_price);
        $stmt2->execute();
    }
}

echo json_encode([
    'success' => $success,
    'report_id' => $report_id,
]);
?>