<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['chat_id'], $_POST['user_type'], $_POST['user_id'])) {
    $chat_id = intval($_POST['chat_id']);
    $user_type = $_POST['user_type'];
    $user_id = intval($_POST['user_id']);

    // Mark the latest unread message from the opposite party as read
    $sender = $user_type === 'customer' ? 'plumber' : 'customer';
    $sql = "
        UPDATE tbl_chat_messages
        SET is_read = 1
        WHERE chat_id = ?
        AND sender = ?
        AND is_read = 0
        ORDER BY sent_at DESC
        LIMIT 1
    ";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("is", $chat_id, $sender);
    $success = $stmt->execute();
    echo json_encode(['success' => $success]);
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
