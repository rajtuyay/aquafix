<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// GET: Find chat_id for customer/plumber
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['customer_id'], $_GET['plumber_id'])) {
    $customer_id = intval($_GET['customer_id']);
    $plumber_id = intval($_GET['plumber_id']);
    $sql = "SELECT chat_id FROM tbl_chats WHERE customer_id=? AND plumber_id=?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ii", $customer_id, $plumber_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    if ($row && isset($row['chat_id'])) {
        echo json_encode(['chat_id' => $row['chat_id']]);
    } else {
        echo json_encode(['chat_id' => null]);
    }
    exit;
}

// POST: Create chat if not exists
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data['customer_id'], $data['plumber_id'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing customer_id or plumber_id']);
        exit;
    }
    $customer_id = intval($data['customer_id']);
    $plumber_id = intval($data['plumber_id']);
    // Check if chat exists
    $sql = "SELECT chat_id FROM tbl_chats WHERE customer_id=? AND plumber_id=?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ii", $customer_id, $plumber_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    if ($row && isset($row['chat_id'])) {
        echo json_encode(['chat_id' => $row['chat_id']]);
        exit;
    }
    // Create new chat
    $insert = $conn->prepare("INSERT INTO tbl_chats (customer_id, plumber_id) VALUES (?, ?)");
    $insert->bind_param("ii", $customer_id, $plumber_id);
    if ($insert->execute()) {
        echo json_encode(['chat_id' => $insert->insert_id]);
    } else {
        http_response_code(500);
        echo json_encode(['error' => $insert->error]);
    }
    exit;
}

http_response_code(400);
echo json_encode(['error' => 'Invalid request']);
$conn->close();
