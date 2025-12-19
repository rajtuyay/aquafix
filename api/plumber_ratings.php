<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['plumber_id'])) {
    $plumber_id = intval($_GET['plumber_id']);
    $stmt = $conn->prepare(
        "SELECT ratings, comment, created_at, customer_id
         FROM tbl_ratings
         WHERE plumber_id = ?
         ORDER BY created_at DESC"
    );
    $stmt->bind_param("i", $plumber_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $ratings = [];
    while ($row = $result->fetch_assoc()) {
        $ratings[] = $row;
    }
    echo json_encode($ratings);
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
