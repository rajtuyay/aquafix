<?php
// Disable error display and enable error logging
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log');

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// Add Firebase PHP SDK
require_once __DIR__ . '/vendor/autoload.php'; // Already correct

use Kreait\Firebase\Factory;
use Kreait\Firebase\ServiceAccount;

// Initialize Firebase (reuse for all requests)
function getFirebaseDatabase() {
    static $database = null;
    if ($database === null) {
        try {
            $factory = (new Factory)
                ->withServiceAccount(__DIR__ . '/service-account.json')
                ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com');
            $database = $factory->createDatabase();
        } catch (Throwable $e) {
            error_log('Firebase init error: ' . $e->getMessage());
            $database = null;
        }
    }
    return $database;
}

function sendFCMNotificationV1($fcmToken, $title, $body) {
    // Path to your service account JSON
    $serviceAccountPath = __DIR__ . '/service-account.json';
    $serviceAccount = json_decode(file_get_contents($serviceAccountPath), true);

    $projectId = $serviceAccount['project_id'];

    // 1. Get OAuth2 access token
    $jwtHeader = [
        'alg' => 'RS256',
        'typ' => 'JWT'
    ];
    $jwtClaim = [
        'iss' => $serviceAccount['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => $serviceAccount['token_uri'],
        'exp' => time() + 3600,
        'iat' => time()
    ];

    // Helper to base64url encode
    $base64UrlEncode = function ($data) {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    };

    $header = $base64UrlEncode(json_encode($jwtHeader));
    $claim = $base64UrlEncode(json_encode($jwtClaim));
    $signatureInput = $header . '.' . $claim;

    // Sign JWT with private key
    $privateKey = openssl_pkey_get_private($serviceAccount['private_key']);
    openssl_sign($signatureInput, $signature, $privateKey, 'sha256');
    $jwt = $signatureInput . '.' . $base64UrlEncode($signature);

    // Request access token
    $tokenReq = [
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt
    ];
    $ch = curl_init($serviceAccount['token_uri']);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($tokenReq));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/x-www-form-urlencoded'
    ]);
    $tokenResp = curl_exec($ch);
    curl_close($ch);
    $tokenData = json_decode($tokenResp, true);
    $accessToken = $tokenData['access_token'] ?? null;

    if (!$accessToken) {
        error_log('FCM v1: Failed to get access token');
        return;
    }

    // 2. Send notification
    $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";
    $fields = [
        'message' => [
            'token' => $fcmToken,
            'notification' => [
                'title' => $title,
                'body' => $body,
            ],
            'android' => [
                'priority' => 'HIGH',
            ],
            'apns' => [
                'headers' => [
                    'apns-priority' => '10',
                ],
            ],
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

    error_log('FCM v1 result: ' . $result);
}

// Handle job order cancellation (POST or PUT with action=cancel)
if ($_SERVER['REQUEST_METHOD'] === 'POST'){
    $data = json_decode(file_get_contents("php://input"), true);

    if (isset($data['action']) && $data['action'] === 'cancel') {
        if (!isset($data['job_order_id'])) {
        http_response_code(400);
        echo json_encode(["error" => "Missing job_order_id"]);
        exit;
    }
    $job_order_id = intval($data['job_order_id']);
    // Get PH time
    date_default_timezone_set('Asia/Manila');
    $phTime = date('Y-m-d H:i:s');
    $stmt = $conn->prepare("UPDATE tbl_job_orders SET status='Cancelled', cancelled_at=? WHERE job_order_id=?");
    $stmt->bind_param("si", $phTime, $job_order_id);
    if ($stmt->execute()) {
        // Update Firebase Realtime Database (safe)
        try {
            $firebaseDb = getFirebaseDatabase();
            if ($firebaseDb) {
                $firebaseDb->getReference('job_orders/' . $job_order_id)
                    ->update([
                        'status' => 'Cancelled',
                        'timestamp' => $phTime, // update timestamp to PH time
                        'cancelled_at' => $phTime, // add cancelled_at to Firebase
                        'updated_at' => date('c'),
                    ]);
                    // Fetch customer_id and jo_number for notification
                    $stmt2 = $conn->prepare("SELECT customer_id, jo_number FROM tbl_job_orders WHERE job_order_id=?");
                    $stmt2->bind_param("i", $job_order_id);
                    $stmt2->execute();
                    $stmt2->bind_result($customer_id, $jo_number);
                    $stmt2->fetch();
                    $stmt2->close();
                    if (!empty($customer_id)) {
                        // Push notification to Firebase
                        $notifRef = $firebaseDb->getReference('notifications/' . $customer_id);
                        $notifRef->push([
                            'title' => 'Job Order Cancelled',
                            'body' => "Your job order #$jo_number has been cancelled.",
                            'timestamp' => date('Y-m-d H:i:s'),
                            'viewed' => false,
                            'adminViewed' => false,
                        ]);
                        // Fetch FCM token (example: from tbl_customers)
                        $fcmToken = '';
                        $stmtToken = $conn->prepare("SELECT fcm_token FROM tbl_customers WHERE customer_id=?");
                        $stmtToken->bind_param("i", $customer_id);
                        $stmtToken->execute();
                        $stmtToken->bind_result($fcmToken);
                        $stmtToken->fetch();
                        $stmtToken->close();
                        if (!empty($fcmToken)) {
                            sendFCMNotificationV1($fcmToken, 'Job Order Cancelled', "Your job order #$jo_number has been cancelled.");
                        }
                    }
                }
            } catch (Throwable $e) {
                error_log('Firebase update error: ' . $e->getMessage());
            }
            echo json_encode(["success" => true, "job_order_id" => $job_order_id]);
        } else {
            http_response_code(500);
            echo json_encode(["error" => $stmt->error]);
        }
        exit;
    }
}

// GET: Fetch job orders for a customer or plumber
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $where = [];
    $params = [];
    $types = '';

    if (isset($_GET['customer_id'])) {
        $where[] = "jo.customer_id = ?";
        $params[] = intval($_GET['customer_id']);
        $types .= 'i';
    }
    if (isset($_GET['plumber_id'])) {
        $where[] = "jo.plumber_id = ?";
        $params[] = intval($_GET['plumber_id']);
        $types .= 'i';
    }

    $whereClause = '';
    if (!empty($where)) {
        $whereClause = 'WHERE ' . implode(' AND ', $where);
    }

    $sql = "
        SELECT
            jo.job_order_id,
            jo.jo_number,
            jo.customer_id,
            jo.clw_account_id,
            jo.plumber_id,
            jo.category,
            jo.other_issue,
            jo.notes,
            jo.priority,
            jo.status,
            jo.created_at,
            jo.dispatched_at,
            jo.accomplished_at,
            jo.cancelled_at,
            a.label AS account_label,
            a.street,
            a.barangay,
            a.municipality,
            a.province,
            a.account_number,
            a.account_name,
            a.meter_no,
            p.first_name AS plumber_first_name,
            p.last_name AS plumber_last_name,
            (
                SELECT c.first_name FROM tbl_customers c WHERE c.customer_id = jo.customer_id
            ) AS customer_first_name,
            (
                SELECT c.last_name FROM tbl_customers c WHERE c.customer_id = jo.customer_id
            ) AS customer_last_name,
            (
                SELECT CONCAT(c.first_name, ' ', c.last_name) FROM tbl_customers c WHERE c.customer_id = jo.customer_id
            ) AS customer_name,
            (
                SELECT COUNT(*) FROM tbl_ratings r WHERE r.job_order_id = jo.job_order_id
            ) > 0 AS is_rated
        FROM tbl_job_orders jo
        LEFT JOIN tbl_clw_accounts a ON jo.clw_account_id = a.clw_account_id
        LEFT JOIN tbl_plumbers p ON jo.plumber_id = p.plumber_id
        $whereClause
        ORDER BY jo.created_at DESC
    ";

    $stmt = $conn->prepare($sql);

    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    $stmt->execute();
    $result = $stmt->get_result();
    $orders = [];
    while ($row = $result->fetch_assoc()) {
        $orders[] = $row;
    }
    // Optionally, sync all job orders to Firebase (not required for every GET)
    // $firebaseDb = getFirebaseDatabase();
    // foreach ($orders as $order) {
    //     $firebaseDb->getReference('job_orders/' . $order['job_order_id'])->set($order);
    // }
    echo json_encode($orders);
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
