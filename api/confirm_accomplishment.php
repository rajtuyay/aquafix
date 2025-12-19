<?php
    header("Access-Control-Allow-Origin: *");
    header("Content-Type: application/json; charset=UTF-8");
    include 'config.php';
    require_once __DIR__ . '/vendor/autoload.php';
    use Kreait\Firebase\Factory;

    $data = json_decode(file_get_contents("php://input"), true);

    $job_order_id = isset($data['job_order_id']) ? intval($data['job_order_id']) : null;

    if (!$job_order_id) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing job_order_id']);
        exit;
    }

    // Get current isConfirmed value
    $stmt = $conn->prepare("SELECT isConfirmed FROM tbl_job_orders WHERE job_order_id=? LIMIT 1");
    $stmt->bind_param("i", $job_order_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $stmt->close();

    if (!$row) {
        http_response_code(404);
        echo json_encode(['error' => 'Job order not found']);
        exit;
    }

    $isConfirmed = intval($row['isConfirmed']);

    // Debug: Check if PHP can write to the directory
    $debug_path = __DIR__ . '/confirm_debug.txt';
    if (!is_writable(__DIR__)) {
        error_log("Directory not writable: " . __DIR__);
    }

    if ($isConfirmed === 1) {
        // Debug: Try to create the file explicitly if it doesn't exist
        if (!file_exists($debug_path)) {
            file_put_contents($debug_path, "Debug file created at " . date('c') . "\n");
        }
        file_put_contents($debug_path, date('c') . " - Already confirmed by customer for job_order_id=$job_order_id\n", FILE_APPEND);
        echo json_encode(['message' => 'Already confirmed by customer']);
        exit;
    }

    if ($isConfirmed === 2) {
        // Already approved by admin, update status to Accomplished
        $stmt = $conn->prepare("UPDATE tbl_job_orders SET status='Accomplished', accomplished_at=? WHERE job_order_id=?");
        $manilaTz = new DateTimeZone('Asia/Manila');
        $manilaNow = new DateTime('now', $manilaTz);
        $accomplishedAt = $manilaNow->format('Y-m-d H:i:s');
        $stmt->bind_param("si", $accomplishedAt, $job_order_id);
        if ($stmt->execute()) {
            // Save accomplishment notification to Firebase
            $chat_id = isset($data['chat_id']) ? $data['chat_id'] : null;
            $customer_id = null;
            $stmt2 = $conn->prepare("SELECT customer_id FROM tbl_job_orders WHERE job_order_id=? LIMIT 1");
            $stmt2->bind_param("i", $job_order_id);
            $stmt2->execute();
            $result2 = $stmt2->get_result();
            $row2 = $result2->fetch_assoc();
            if ($row2 && isset($row2['customer_id'])) {
                $customer_id = $row2['customer_id'];
            }
            $stmt2->close();
            if ($customer_id) {
                $firebaseDb = (new Factory)
                    ->withServiceAccount(__DIR__ . '/service-account.json')
                    ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com')
                    ->createDatabase();
                $notif = [
                    'title' => 'Job Order Accomplished',
                    'body' => 'Your job order has been completed and confirmed by you and the admin.',
                    'timestamp' => date('Y-m-d H:i:s'),
                    'viewed' => false,
                    
                ];
                $firebaseDb->getReference('notification_customer/' . $customer_id)->push($notif);
                // Send FCM notification instantly
                $fcmToken = '';
                $stmtToken = $conn->prepare("SELECT fcm_token FROM tbl_customers WHERE customer_id=?");
                $stmtToken->bind_param("i", $customer_id);
                $stmtToken->execute();
                $stmtToken->bind_result($fcmToken);
                $stmtToken->fetch();
                $stmtToken->close();
                if (!empty($fcmToken)) {
                    if (!function_exists('sendFCMNotificationV1')) {
                        function sendFCMNotificationV1($fcmToken, $title, $body) {
                            $serviceAccountPath = __DIR__ . '/service-account.json';
                            $serviceAccount = json_decode(file_get_contents($serviceAccountPath), true);
                            $projectId = $serviceAccount['project_id'];
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
                            $tokenReq = [
                                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                                'assertion' => $jwt
                            ];
                            $ch = curl_init($serviceAccount['token_uri']);
                            curl_setopt($ch, CURLOPT_POST, true);
                            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($tokenReq));
                            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
                            $tokenResp = curl_exec($ch);
                            curl_close($ch);
                            $tokenData = json_decode($tokenResp, true);
                            $accessToken = $tokenData['access_token'] ?? null;
                            if (!$accessToken) return;
                            $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";
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
                            $ch = curl_init($url);
                            curl_setopt($ch, CURLOPT_POST, true);
                            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
                            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($fields));
                            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                                'Authorization: Bearer ' . $accessToken,
                                'Content-Type: application/json'
                            ]);
                            $result = curl_exec($ch);
                            curl_close($ch);
                        }
                    }
                    sendFCMNotificationV1($fcmToken, 'Job Order Accomplished', 'Your job order has been completed and confirmed by you and the admin.');
                }
            }
            if (!file_exists($debug_path)) {
                file_put_contents($debug_path, "Debug file created at " . date('c') . "\n");
            }
            file_put_contents($debug_path, date('c') . " - Status updated to Accomplished for job_order_id=$job_order_id\n", FILE_APPEND);
            echo json_encode(['success' => 'Job order status updated to Accomplished']);
        } else {
            file_put_contents($debug_path, date('c') . " - Status update FAILED for job_order_id=$job_order_id\n", FILE_APPEND);
            echo json_encode(['error' => 'Update failed']);
        }
        $stmt->close();
        exit;
    } else {
        // Confirmed by customer, set isConfirmed = 1
        $stmt = $conn->prepare("UPDATE tbl_job_orders SET isConfirmed=1 WHERE job_order_id=?");
        $stmt->bind_param("i", $job_order_id);
        if ($stmt->execute()) {
            if (!file_exists($debug_path)) {
                file_put_contents($debug_path, "Debug file created at " . date('c') . "\n");
            }
            file_put_contents($debug_path, date('c') . " - isConfirmed updated to 1 for job_order_id=$job_order_id\n", FILE_APPEND);
            echo json_encode(['success' => 'Job order confirmed by customer']);
        } else {
            file_put_contents($debug_path, date('c') . " - isConfirmed update FAILED for job_order_id=$job_order_id\n", FILE_APPEND);
            echo json_encode(['error' => 'Update failed']);
        }
        $stmt->close();
        exit;
    }
    $conn->close();
?>
