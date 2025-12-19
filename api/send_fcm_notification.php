<?php
require __DIR__ . '/vendor/autoload.php';

use Kreait\Firebase\Factory;
use Kreait\Firebase\Exception\MessagingException;
use Kreait\Firebase\Exception\FirebaseException;

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

header("Content-Type: application/json; charset=UTF-8");

// Get POST data
$token = $_POST['fcm_token'] ?? '';
$title = $_POST['title'] ?? '';
$body = $_POST['body'] ?? '';
$userId = $_POST['user_id'] ?? '';          // Add user ID in POST
$notificationId = $_POST['notification_id'] ?? ''; // Add notification ID in POST

if (!$token || !$title || !$body || !$userId || !$notificationId) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing parameters']);
    exit;
}

// Initialize Firebase
$factory = (new Factory)
    ->withServiceAccount(__DIR__ . '/service-account.json')
    ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com/');

$messaging = $factory->createMessaging();
$database = $factory->createDatabase();

// Reference to this notification in Realtime Database
$notificationRef = $database->getReference("notifications/$userId/$notificationId");

// Check if notification has already been viewed
$notification = $notificationRef->getValue();
if (isset($notification['viewed']) && $notification['viewed'] === true) {
    // Already viewed, do not send notification again
    echo json_encode(['status' => 'Notification already viewed']);
    exit;
}

// Save notification to database (viewed = false initially)
$notificationData = [
    'token' => $token,
    'title' => $title,
    'body' => $body,
    'timestamp' => date('c'),
    'viewed' => false,
];
$notificationRef->set($notificationData);

// Prepare FCM message
$message = [
    'token' => $token,
    'notification' => ['title' => $title, 'body' => $body],
    'android' => ['priority' => 'high'],
    'apns' => ['headers' => ['apns-priority' => '10']],
    'data' => ['click_action' => 'FLUTTER_NOTIFICATION_CLICK'], // optional extra data
];

// Send notification
try {
    $messaging->send($message);
    echo json_encode(['status' => 'Notification sent successfully']);
} catch (MessagingException | FirebaseException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'FCM error', 'message' => $e->getMessage()]);
}
