<?php
ini_set('error_log', __DIR__ . '/php-error.log');
ini_set('display_errors', 0); 
error_reporting(E_ALL);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// GET: Fetch all messages for a chat
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['chat_id'])) {
    $chat_id = intval($_GET['chat_id']);
    $sql = "SELECT message_id, chat_id, customer_id, plumber_id, sender, message, media_path, thumbnail_path, sent_at
            FROM tbl_chat_messages
            WHERE chat_id = ?
            ORDER BY sent_at ASC";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $chat_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $messages = [];
    while ($row = $result->fetch_assoc()) {
        $messages[] = $row;
    }
    echo json_encode($messages);
    exit;
}

// POST: Save a new message
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    if (
        !isset($data['chat_id'], $data['sender'], $data['customer_id'], $data['plumber_id'])
        || (
            (!isset($data['message']) || trim((string)$data['message']) === '')
            && (!isset($data['media_path']) || trim((string)$data['media_path']) === '')
        )
    ) {
        http_response_code(400);
        echo json_encode(["error" => "Missing required fields or empty message and media_path"]);
        exit;
    }

    $chat_id = intval($data['chat_id']);
    $customer_id = intval($data['customer_id']);
    $plumber_id = intval($data['plumber_id']);
    $sender = $data['sender'];
    $message = isset($data['message']) ? $data['message'] : '';
    $media_path = !empty($data['media_path']) ? $data['media_path'] : '';
    $thumbnail_path = $data['thumbnail_path'] ?? null;
    $manilaTz = new DateTimeZone('Asia/Manila');
    $manilaNow = new DateTime('now', $manilaTz);

    $stmt = $conn->prepare("INSERT INTO tbl_chat_messages (chat_id, customer_id, plumber_id, sender, message, media_path, thumbnail_path, sent_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $sentAt = $manilaNow->format('Y-m-d H:i:s');
    $stmt->bind_param("iiisssss", $chat_id, $customer_id, $plumber_id, $sender, $message, $media_path, $thumbnail_path, $sentAt);

    
    if ($stmt->execute()) {
        $msg_id = $stmt->insert_id;

        // Fetch the inserted message
        $get = $conn->prepare("SELECT message_id, chat_id, customer_id, plumber_id, sender, message, media_path, thumbnail_path, sent_at 
                               FROM tbl_chat_messages WHERE message_id=?");
        $get->bind_param("i", $msg_id);
        $get->execute();
        $result = $get->get_result();
        $row = $result->fetch_assoc();

        // -------- FCM Notification Logic --------
        if (!function_exists('sendFCMNotificationV1')) {
            function sendFCMNotificationV1($fcmToken, $title, $body, $fields = null) {
                $serviceAccountPath = __DIR__ . '/service-account.json';
                $serviceAccount = json_decode(file_get_contents($serviceAccountPath), true);
                $projectId = $serviceAccount['project_id'];

                // JWT header + claim
                $jwtHeader = ['alg' => 'RS256', 'typ' => 'JWT'];
                $jwtClaim = [
                    'iss' => $serviceAccount['client_email'],
                    'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                    'aud' => $serviceAccount['token_uri'],
                    'exp' => time() + 3600,
                    'iat' => time()
                ];
                $base64UrlEncode = fn($data) => rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
                $header = $base64UrlEncode(json_encode($jwtHeader));
                $claim = $base64UrlEncode(json_encode($jwtClaim));
                $signatureInput = $header . '.' . $claim;
                $privateKey = openssl_pkey_get_private($serviceAccount['private_key']);
                openssl_sign($signatureInput, $signature, $privateKey, 'sha256');
                $jwt = $signatureInput . '.' . $base64UrlEncode($signature);

                // Request access token
                $ch = curl_init($serviceAccount['token_uri']);
                curl_setopt($ch, CURLOPT_POST, true);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => $jwt
                ]));
                curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
                $tokenResp = curl_exec($ch);
                curl_close($ch);
                $tokenData = json_decode($tokenResp, true);
                $accessToken = $tokenData['access_token'] ?? null;
                if (!$accessToken) return;

                // Send push
                $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";
                if ($fields === null) {
                    $fields = [
                        'message' => [
                            'token' => $fcmToken,
                            'notification' => [
                                'title' => $title,
                                'body' => $body,
                            ],
                            'android' => ['priority' => 'HIGH'],
                            'apns' => ['headers' => ['apns-priority' => '10']],
                        ]
                    ];
                }
                $ch = curl_init($url);
                curl_setopt($ch, CURLOPT_POST, true);
                curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($fields));
                curl_setopt($ch, CURLOPT_HTTPHEADER, [
                    'Authorization: Bearer ' . $accessToken,
                    'Content-Type: application/json'
                ]);
                curl_exec($ch);
                curl_close($ch);
            }
        }

        // Decide recipient and get sender profile image
        $profileImageUrl = '';
        $senderName = '';
        if ($sender === 'customer') {
            $stmtToken = $conn->prepare("SELECT fcm_token FROM tbl_plumbers WHERE plumber_id=?");
            $stmtToken->bind_param("i", $plumber_id);
            // Get customer profile image and name
            $stmtProfile = $conn->prepare("SELECT profile_image, CONCAT(first_name, ' ', last_name) AS name  FROM tbl_customers WHERE customer_id=?");
            $stmtProfile->bind_param("i", $customer_id);
            $stmtProfile->execute();
            $stmtProfile->bind_result($profileImage, $name);
            $stmtProfile->fetch();
            $stmtProfile->close();
            if (!empty($profileImage)) {
                $profileImageUrl = 'https://aquafixsansimon.com/uploads/profiles/customers/' . $profileImage;
            }
            $senderName = $name;
        } else {
            $stmtToken = $conn->prepare("SELECT fcm_token FROM tbl_customers WHERE customer_id=?");
            $stmtToken->bind_param("i", $customer_id);
            // Get plumber profile image and name
            $stmtProfile = $conn->prepare("SELECT profile_image, CONCAT(first_name, ' ', last_name) AS name  FROM tbl_plumbers WHERE plumber_id=?");
            $stmtProfile->bind_param("i", $plumber_id);
            $stmtProfile->execute();
            $stmtProfile->bind_result($profileImage, $name);
            $stmtProfile->fetch();
            $stmtProfile->close();
            if (!empty($profileImage)) {
                $profileImageUrl = 'https://aquafixsansimon.com/uploads/profiles/plumbers/' . $profileImage;
            }
            $senderName = $name;
        }
        $stmtToken->execute();
        $stmtToken->bind_result($fcmToken);
        $stmtToken->fetch();
        $stmtToken->close();
        error_log("chat_messages.php FCM token: " . $fcmToken);
        error_log("chat_messages.php profile image: " . $profileImageUrl);
        error_log("chat_messages.php sender name: " . $senderName);

        if (!empty($fcmToken)) {
            $title = ($sender === 'customer' ? 'Customer: ' : 'Plumber: ') . $senderName;
            $body = !empty($message) ? $message : '[Media message]';
            $fields = [
                'message' => [
                    'token' => $fcmToken,
                    'notification' => [
                        'title' => $title,
                        'body' => $body,
                        'image' => $profileImageUrl,
                    ],
                    'android' => ['priority' => 'HIGH'],
                    'apns' => ['headers' => ['apns-priority' => '10']],
                ]
            ];
            sendFCMNotificationV1($fcmToken, $title, $body, $fields);
        }

        // -------- Return response --------
        echo json_encode($row);
        exit;
    } else {
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
        exit;
    }
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
