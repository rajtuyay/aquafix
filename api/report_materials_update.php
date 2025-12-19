<?php
ini_set('display_errors', 0);
error_reporting(0);
ob_clean();
header('Content-Type: application/json');
include 'config.php';

function debug_log($msg) {
    $log_path = __DIR__ . '/lookup_debug.txt';
    $result = @file_put_contents($log_path, date('Y-m-d H:i:s') . " " . $msg . "\n", FILE_APPEND);
    if ($result === false) {
        // If writing fails, try to log to PHP error log
        error_log("Failed to write to debug log at $log_path");
    }
}

// Log the absolute path for troubleshooting
debug_log("Debug log path: " . __DIR__ . '/lookup_debug.txt');

$data_raw = file_get_contents('php://input');
debug_log("RAW INPUT: " . $data_raw);

$data = json_decode(file_get_contents('php://input'), true);

$report_id = $data['report_id'] ?? null;
$materials = $data['materials'] ?? [];

debug_log("Parsed report_id: " . var_export($report_id, true));
debug_log("Parsed materials: " . var_export($materials, true));

if (!$report_id) {
    debug_log("Missing report_id");
    echo json_encode(['success' => false, 'error' => 'Missing report_id']);
    exit;
}

// Delete old materials for this report
$conn->query("DELETE FROM tbl_report_materials WHERE report_id = $report_id");
debug_log("Deleted old materials for report_id $report_id");

// Insert new materials
$success = true;
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
        if (!$stmt2->execute()) {
            $success = false;
        }
    }
}

echo json_encode([
    'success' => $success,
    'report_id' => $report_id,
]);
?>
