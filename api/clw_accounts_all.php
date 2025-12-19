<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $conn->prepare("SELECT clw_account_id, label, street, barangay, municipality, province, account_number, account_name, meter_no, account_class, book_seq FROM tbl_clw_accounts");
    $stmt->execute();
    $result = $stmt->get_result();
    $accounts = [];
    while ($row = $result->fetch_assoc()) {
        $accounts[] = $row;
    }
    echo json_encode($accounts);
    $stmt->close();
    $conn->close();
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();