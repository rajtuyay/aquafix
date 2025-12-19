<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);
    $bill_ids = isset($data['bill_ids']) && is_array($data['bill_ids']) ? $data['bill_ids'] : [];
    if (empty($bill_ids)) {
        http_response_code(400);
        echo json_encode(["error" => "Missing bill_ids"]);
        exit;
    }
    $placeholders = implode(',', array_fill(0, count($bill_ids), '?'));
    $types = str_repeat('i', count($bill_ids));
    $sql = "
        SELECT
            p.bill_id,
            p.job_order_id,
            j.status AS job_order_status
        FROM tbl_predictive_jo p
        LEFT JOIN tbl_job_orders j ON p.job_order_id = j.job_order_id
        WHERE p.bill_id IN ($placeholders)
    ";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$bill_ids);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    while ($row = $result->fetch_assoc()) {
        $rows[] = $row;
    }
    echo json_encode($rows);
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
