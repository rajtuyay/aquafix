<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// GET: Fetch rating by job_order_id
if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['job_order_id'])) {
    $job_order_id = intval($_GET['job_order_id']);
    $stmt = $conn->prepare(
        "SELECT ratings, comment, created_at FROM tbl_ratings WHERE job_order_id = ? ORDER BY created_at DESC LIMIT 1"
    );
    $stmt->bind_param("i", $job_order_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $ratings = [];
    while ($row = $result->fetch_assoc()) {
        $ratings[] = $row;
    }
    echo json_encode($ratings);
    exit;
}

// POST: Submit a rating
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    // Validate required fields
    $required = ['job_order_id', 'plumber_id', 'customer_id', 'ratings'];
    foreach ($required as $field) {
        if (!isset($data[$field]) || $data[$field] === '') {
            http_response_code(400);
            echo json_encode(["error" => "Missing field: $field", "data" => $data]);
            // Log to a file in your project for easier debugging
            file_put_contents(__DIR__ . '/error.log', date('Y-m-d H:i:s') . " - Missing field: $field - Data: " . json_encode($data) . "\n", FILE_APPEND);
            exit;
        }
    }

    $job_order_id = intval($data['job_order_id']);
    $plumber_id = intval($data['plumber_id']);
    $customer_id = intval($data['customer_id']);
    $ratings = intval($data['ratings']);
    $comment = isset($data['comment']) ? trim($data['comment']) : '';

    // Log all POST data for debugging
    file_put_contents(__DIR__ . '/error.log', date('Y-m-d H:i:s') . " - Insert rating: job_order_id=$job_order_id, plumber_id=$plumber_id, customer_id=$customer_id, ratings=$ratings, comment=$comment\n", FILE_APPEND);

    $stmt = $conn->prepare(
        "INSERT INTO tbl_ratings (job_order_id, plumber_id, customer_id, ratings, comment, created_at)
         VALUES (?, ?, ?, ?, ?, ?)"
    );

    $manilaTz = new DateTimeZone('Asia/Manila');
    $manilaNow = new DateTime('now', $manilaTz);
    $createdAt = $manilaNow->format('Y-m-d H:i:s');
    if (!$stmt) {
        http_response_code(500);
        echo json_encode(["error" => $conn->error]);
        file_put_contents(__DIR__ . '/error.log', date('Y-m-d H:i:s') . " - Prepare failed: " . $conn->error . "\n", FILE_APPEND);
        exit;
    }
    $stmt->bind_param("iiiiss", $job_order_id, $plumber_id, $customer_id, $ratings, $comment, $createdAt);

    if ($stmt->execute()) {
        echo json_encode(["success" => true, "rating_id" => $stmt->insert_id]);
    } else {
        http_response_code(500);
        echo json_encode(["error" => $stmt->error]);
        file_put_contents(__DIR__ . '/error.log', date('Y-m-d H:i:s') . " - Execute failed: " . $stmt->error . "\n", FILE_APPEND);
    }
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
