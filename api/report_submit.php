<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// Only allow POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["error" => "Method not allowed"]);
    exit;
}

// Parse form fields
$job_order_id = isset($_POST['job_order_id']) ? intval($_POST['job_order_id']) : null;
$plumber_id = isset($_POST['plumber_id']) ? intval($_POST['plumber_id']) : null;
$category = $_POST['category'] ?? '';
$root_cause = $_POST['root_cause'] ?? '';
$action_taken = $_POST['action_taken'] ?? '';
$date_time_started = $_POST['date_time_started'] ?? null;
$date_time_finished = $_POST['date_time_finished'] ?? null;
$status = $_POST['status'] ?? '';
$remarks = $_POST['remarks'] ?? '';
$accomplished_by = $_POST['accomplished_by'] ?? '';
$is_draft = isset($_POST['is_draft']) ? intval($_POST['is_draft']) : 0;
$materials_json = $_POST['materials'] ?? '[]';
$report_id = $_POST['report_id'] ?? null;
$update = isset($_POST['update']) ? $_POST['update'] : null;

if (!$job_order_id || !$plumber_id) {
    http_response_code(400);
    echo json_encode(["error" => "Missing job_order_id or plumber_id"]);
    exit;
}

if ($update && $report_id) {
    // Update existing report
    $stmt = $conn->prepare(
        "UPDATE tbl_report SET job_order_id=?, plumber_id=?, category=?, root_cause=?, action_taken=?, date_time_started=?, date_time_finished=?, status=?, remarks=?, accomplished_by=?, is_draft=?, created_at=? WHERE report_id=?"
    );
    $manilaTz = new DateTimeZone('Asia/Manila');
    $manilaNow = new DateTime('now', $manilaTz);
    $createdAt = $manilaNow->format('Y-m-d H:i:s');
    $stmt->bind_param(
        "iissssssssisi",
        $job_order_id,
        $plumber_id,
        $category,
        $root_cause,
        $action_taken,
        $date_time_started,
        $date_time_finished,
        $status,
        $remarks,
        $accomplished_by,
        $is_draft,
        $createdAt,
        $report_id
    );
    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
        exit;
    }
} else {
    // Insert into tbl_report
    $stmt = $conn->prepare(
        "INSERT INTO tbl_report (job_order_id, plumber_id, category, root_cause, action_taken, date_time_started, date_time_finished, status, remarks, accomplished_by, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    );
    $manilaTz = new DateTimeZone('Asia/Manila');
    $manilaNow = new DateTime('now', $manilaTz);
    $createdAt = $manilaNow->format('Y-m-d H:i:s');
    $stmt->bind_param(
        "iisssssssss",
        $job_order_id,
        $plumber_id,
        $category,
        $root_cause,
        $action_taken,
        $date_time_started,
        $date_time_finished,
        $status,
        $remarks,
        $accomplished_by,
        $createdAt
    );
    if (!$stmt->execute()) {
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
        exit;
    }
    $report_id = $stmt->insert_id;
}

$stmtDel = $conn->prepare("DELETE FROM tbl_report_materials WHERE report_id=?");
$stmtDel->bind_param("i", $report_id);
$stmtDel->execute();

// Insert materials
$materials = json_decode($materials_json, true);
if (is_array($materials)) {
    foreach ($materials as $mat) {
        $material_id = intval($mat['material_id'] ?? 0);
        $qty = intval($mat['qty'] ?? 0);
        $total_price = floatval($mat['total_price'] ?? 0);
        $stmt2 = $conn->prepare(
            "INSERT INTO tbl_report_materials (report_id, material_id, qty, total_price)
             VALUES (?, ?, ?, ?)"
        );
        $stmt2->bind_param("iiid", $report_id, $material_id, $qty, $total_price);
        $stmt2->execute();
    }
}

// Handle media uploads
$media_dir = "../uploads/report_media/";
if (!is_dir($media_dir)) {
    mkdir($media_dir, 0777, true);
}
$media_saved = [];
if (!empty($_FILES['media'])) {
    foreach ($_FILES['media']['name'] as $idx => $name) {
        $tmp_name = $_FILES['media']['tmp_name'][$idx];
        $type = $_FILES['media']['type'][$idx];
        $error = $_FILES['media']['error'][$idx];
        $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
        $media_type = in_array($ext, ['jpg', 'jpeg', 'png']) ? 'image' : (in_array($ext, ['mp4', 'mov']) ? 'video' : 'other');
        if ($error === UPLOAD_ERR_OK && ($media_type === 'image' || $media_type === 'video')) {
            $filename = uniqid("report{$report_id}_") . '.' . $ext;
            $target = $media_dir . $filename;
            if (move_uploaded_file($tmp_name, $target)) {
                $stmt3 = $conn->prepare(
                    "INSERT INTO tbl_report_media (report_id, media_type, file_path) VALUES (?, ?, ?)"
                );
                $stmt3->bind_param("iss", $report_id, $media_type, $filename);
                $stmt3->execute();
                $media_saved[] = $filename;
            }
        }
    }
}

echo json_encode([
    "success" => true,
    "report_id" => $report_id,
    "media" => $media_saved
]);