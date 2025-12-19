<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['customer_id'])) {
    $customer_id = intval($_GET['customer_id']);
    $sql = "
        SELECT
            c.chat_id,
            p.plumber_id,
            p.first_name,
            CONCAT(p.first_name, ' ', p.last_name) AS plumber_name,
            p.profile_image,
            m.message AS last_message,
            m.sent_at AS last_time, -- return raw datetime string
            m.media_path AS last_media_path,
            m.sender AS last_sender_type, -- 'customer' or 'plumber'
            m.is_read AS is_unread -- <-- this line ensures is_read is returned as is_unread
        FROM tbl_chats c
        JOIN tbl_plumbers p ON c.plumber_id = p.plumber_id
        LEFT JOIN (
            SELECT m1.*
            FROM tbl_chat_messages m1
            INNER JOIN (
                SELECT chat_id, MAX(sent_at) AS latest
                FROM tbl_chat_messages
                GROUP BY chat_id
            ) m2 ON m1.chat_id = m2.chat_id AND m1.sent_at = m2.latest
        ) m ON m.chat_id = c.chat_id
        WHERE c.customer_id = ?
        AND (
            (m.message IS NOT NULL AND TRIM(m.message) != '')
            OR (m.media_path IS NOT NULL AND TRIM(m.media_path) != '')
        )
        GROUP BY c.chat_id
        ORDER BY last_time DESC
    ";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $customer_id);
    $stmt->execute();
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
