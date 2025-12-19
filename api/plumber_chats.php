<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['plumber_id'])) {
    $plumber_id = intval($_GET['plumber_id']);
    $sql = "
        SELECT
            c.chat_id,
            cu.customer_id,
            cu.first_name,
            CONCAT(cu.first_name, ' ', cu.last_name) AS customer_name,
            cu.profile_image,
            m.message AS last_message,
            m.sent_at AS last_time,
            m.media_path AS last_media_path,
            m.sender AS last_sender_type,
            m.is_read AS is_unread
        FROM tbl_chats c
        JOIN tbl_customers cu ON c.customer_id = cu.customer_id
        LEFT JOIN (
            SELECT m1.*
            FROM tbl_chat_messages m1
            INNER JOIN (
                SELECT chat_id, MAX(sent_at) AS latest
                FROM tbl_chat_messages
                GROUP BY chat_id
            ) m2 ON m1.chat_id = m2.chat_id AND m1.sent_at = m2.latest
        ) m ON m.chat_id = c.chat_id
        WHERE c.plumber_id = ?
        AND (
            (m.message IS NOT NULL AND TRIM(m.message) != '')
            OR (m.media_path IS NOT NULL AND TRIM(m.media_path) != '')
        )
        GROUP BY c.chat_id
        ORDER BY last_time DESC
    ";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        error_log("plumber_chats.php: Prepare failed: " . $conn->error);
        http_response_code(500);
        echo json_encode(["error" => $conn->error]);
        exit;
    }
    $stmt->bind_param("i", $plumber_id);
    if (!$stmt->execute()) {
        error_log("plumber_chats.php: Execute failed: " . $stmt->error);
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
        exit;
    }
    $result = $stmt->get_result();
    $chats = [];
    while ($row = $result->fetch_assoc()) {
        $chats[] = $row;
    }
    echo json_encode($chats);
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
