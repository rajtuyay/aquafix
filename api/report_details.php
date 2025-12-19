<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';
require_once __DIR__ . '/vendor/autoload.php'; // <-- Ensure Firebase SDK is always loaded

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['job_order_id'])) {
    $job_order_id = intval($_GET['job_order_id']);
    // Use plumber_id when provided so we fetch the correct report for that plumber
    $plumber_id = isset($_GET['plumber_id']) ? intval($_GET['plumber_id']) : null;

    // Fetch the report for this job order
    $stmt = $conn->prepare("SELECT * FROM tbl_report WHERE job_order_id=? LIMIT 1");
    $stmt->bind_param("i", $job_order_id);
    // Fetch the report for this job order; if plumber_id is given, include it in the WHERE clause
    if ($plumber_id) {
        // Only fetch non-draft report for this plumber and job order
        $stmt = $conn->prepare("SELECT * FROM tbl_report WHERE job_order_id=? AND plumber_id=? AND is_draft=0 LIMIT 1");
        $stmt->bind_param("ii", $job_order_id, $plumber_id);
    } else {
        $stmt = $conn->prepare("SELECT * FROM tbl_report WHERE job_order_id=? AND is_draft=0 LIMIT 1");
        $stmt->bind_param("i", $job_order_id);
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $report = $result->fetch_assoc();
    $stmt->close();
 
    if ($report) {
        // Fetch materials for this report
        $materials = [];
        $stmt2 = $conn->prepare("
            SELECT 
                rm.material_id,
                m.material_name,
                m.size,
                m.price AS unit_price,
                rm.qty,
                rm.total_price
            FROM tbl_report_materials rm
            LEFT JOIN tbl_materials m ON rm.material_id = m.material_id
            WHERE rm.report_id=?
        ");
        $stmt2->bind_param("i", $report['report_id']);
        $stmt2->execute();
        $result2 = $stmt2->get_result();
        while ($row = $result2->fetch_assoc()) {
            $materials[] = $row;
        }
        $stmt2->close();

        $report['materials'] = $materials;

        // Fetch attachments
        $attachments = [];
        $stmt = $conn->prepare("SELECT report_media_id, media_type, file_path, thumbnail_path FROM tbl_report_media WHERE report_id=? ORDER BY report_media_id ASC");
        $stmt->bind_param("i", $report['report_id']);
        $stmt->execute();
        $result = $stmt->get_result();
        while ($row = $result->fetch_assoc()) {
            $attachments[] = $row;
        }
        $stmt->close();

        $report['attachments'] = $attachments; // <-- Always set this

        echo json_encode($report);
        exit;
    } else {
        http_response_code(404);
        echo json_encode(["error" => "Report not found"]);
        exit;
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);

    // Validate and sanitize input data
    $job_order_id = intval($data['job_order_id']);
    $status = $conn->real_escape_string($data['status']);
    // ... other fields ...

    // If plumber submits report, status stays "Dispatched"
    if ($status === 'Dispatched') {
        // Update report status
        $stmt = $conn->prepare("UPDATE tbl_report SET status=? WHERE job_order_id=?");
        $stmt->bind_param("si", $status, $job_order_id);
        $stmt->execute();
        $stmt->close();

        // Fetch job order details for message (JOIN to get account_name)
        $stmt = $conn->prepare(
            "SELECT j.jo_number, j.category, a.account_name, j.plumber_id, j.customer_id
             FROM tbl_job_orders j
             LEFT JOIN tbl_clw_accounts a ON j.clw_account_id = a.clw_account_id
             WHERE j.job_order_id=?"
        );
        $stmt->bind_param("i", $job_order_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $job = $result->fetch_assoc();
        $stmt->close();

        if ($job) {
            $chatMsg = "Your request was accomplished!\n"
                . "Job Order #: " . ($job['jo_number'] ?? '') . "\n"
                . "Category: " . ($job['category'] ?? '') . "\n"
                . "Account Name: " . ($job['account_name'] ?? '');

            // Find chat_id for this customer/plumber
            $stmt = $conn->prepare("SELECT chat_id FROM tbl_chats WHERE customer_id=? AND plumber_id=? LIMIT 1");
            $stmt->bind_param("ii", $job['customer_id'], $job['plumber_id']);
            $stmt->execute();
            $result = $stmt->get_result();
            $chat = $result->fetch_assoc();
            $stmt->close();

            if ($chat && $chat['chat_id']) {
                $chatId = $chat['chat_id'];
                // Insert chat message
                file_put_contents(__DIR__ . '/report_debug.txt', date('c') . " - Preparing to insert chat message for chatId=$chatId job_order_id={$job_order_id}\n", FILE_APPEND);
                
                $stmt = $conn->prepare("INSERT INTO tbl_chat_messages (chat_id, customer_id, plumber_id, sender, message, media_path, thumbnail_path, sent_at) VALUES (?, ?, ?, 'plumber', ?, '', '', ?)");
                $manilaTz = new DateTimeZone('Asia/Manila');
                $manilaNow = new DateTime('now', $manilaTz);
                $sentAt = $manilaNow->format('Y-m-d H:i:s');
                $stmt->bind_param("iiiss", $chatId, $job['customer_id'], $job['plumber_id'], $chatMsg, $sentAt);
                if ($stmt->execute()) {
                    file_put_contents(__DIR__ . '/report_debug.txt', date('c') . " - MySQL insert succeeded for chat_id=$chatId\n", FILE_APPEND);
                    $messageId = $stmt->insert_id;
                } else {
                    file_put_contents(__DIR__ . '/report_debug.txt', date('c') . " - MySQL insert FAILED for chat_id=$chatId error=" . $stmt->error . "\n", FILE_APPEND);
                }
                $stmt->close();

                // Push to Firebase with isConfirmed = 0
                try {
                    // Debug payload
                    $payload = [
                        'chat_id' => $chatId,
                        'customer_id' => $job['customer_id'],
                        'plumber_id' => $job['plumber_id'],
                        'sender' => 'plumber',
                        'message' => $chatMsg,
                        'media_path' => '',
                        'thumbnail_path' => '',
                        'sent_at' => date('c'),
                        'message_id' => isset($messageId) ? $messageId : null,
                    ];
                    file_put_contents(__DIR__ . '/report_debug.txt', date('c') . " - Firebase payload: " . json_encode($payload) . "\n", FILE_APPEND);
                    $factory = (new Kreait\Firebase\Factory)
                        ->withServiceAccount(__DIR__ . '/service-account.json')
                        ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com');
                    $database = $factory->createDatabase();
                    $setResult = $database->getReference('chats/' . $chatId . '/messages/' . $messageId)
                        ->set($payload);
                    if (!$setResult) {
                        file_put_contents(__DIR__ . '/report_debug.txt', date('c') . " - Firebase set() FAILED for chat_id=$chatId message_id=$messageId\n", FILE_APPEND);
                    }
                } catch (Throwable $e) {
                    file_put_contents(__DIR__ . '/report_debug.txt', date('c') . " - Firebase exception: " . $e->getMessage() . "\n", FILE_APPEND);
                    error_log('Firebase accomplishment message error: ' . $e->getMessage());
                }
            }
        }
        echo json_encode(["success" => "Report submitted, status dispatched, accomplishment message sent"]);
        exit;
    }

    // Check if job is marked as accomplished
    if ($status === 'Accomplished') {
    $stmt = $conn->prepare(
        "SELECT j.jo_number, j.category, a.account_name, j.plumber_id, j.customer_id
         FROM tbl_job_orders j
         LEFT JOIN tbl_clw_accounts a ON j.clw_account_id = a.clw_account_id
         WHERE j.job_order_id=?"
    );
    $stmt->bind_param("i", $job_order_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $job = $result->fetch_assoc();
    $stmt->close();

    if ($job) {
        $customer_id = $job['customer_id'];
        $plumber_id  = $job['plumber_id'];

        $chatMsg = "Your request was accomplished!\n"
            . "Job Order #: " . ($job['jo_number'] ?? '') . "\n"
            . "Category: " . ($job['category'] ?? '') . "\n"
            . "Account Name: " . ($job['account_name'] ?? '');

        // Find or create chat
        $stmt = $conn->prepare("SELECT chat_id FROM tbl_chats WHERE customer_id=? AND plumber_id=? LIMIT 1");
        $stmt->bind_param("ii", $customer_id, $plumber_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $chat = $result->fetch_assoc();
        $stmt->close();

        if ($chat && $chat['chat_id']) {
            $chatId = $chat['chat_id'];
        } else {
            $stmt = $conn->prepare("INSERT INTO tbl_chats (customer_id, plumber_id, created_at, updated_at) VALUES (?, ?, NOW(), NOW())");
            $stmt->bind_param("ii", $customer_id, $plumber_id);
            $stmt->execute();
            $chatId = $stmt->insert_id;
            $stmt->close();
        }

        // Insert chat message
        $manilaTz = new DateTimeZone('Asia/Manila');
        $manilaNow = new DateTime('now', $manilaTz);
        $sentAt = $manilaNow->format('Y-m-d H:i:s');

        $stmt = $conn->prepare("INSERT INTO tbl_chat_messages 
            (chat_id, customer_id, plumber_id, sender, message, media_path, thumbnail_path, sent_at) 
            VALUES (?, ?, ?, 'plumber', ?, '', '', ?)");
        $stmt->bind_param("iisss", $chatId, $customer_id, $plumber_id, $chatMsg, $sentAt);
        $stmt->execute();
        $messageId = $stmt->insert_id;
        $stmt->close();

        // Push to Firebase
        try {
            $factory = (new Kreait\Firebase\Factory)
                ->withServiceAccount(__DIR__ . '/service-account.json')
                ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com');
            $database = $factory->createDatabase();
            $database->getReference("chats/$chatId/messages/$messageId")->set([
                'chat_id' => $chatId,
                'customer_id' => $customer_id,
                'plumber_id' => $plumber_id,
                'sender' => 'plumber',
                'message' => $chatMsg,
                'media_path' => '',
                'thumbnail_path' => '',
                'sent_at' => date('c'),
                'message_id' => $messageId,
            ]);
        } catch (Throwable $e) {
            error_log('Firebase accomplishment message error: ' . $e->getMessage());
        }
    }

    echo json_encode(["success" => "Report submitted and job status updated to accomplished"]);
    exit;
}

    

    // Add this block to handle confirmation by customer
    if (isset($data['action']) && $data['action'] === 'confirm' && isset($data['job_order_id'])) {
        $job_order_id = intval($data['job_order_id']);

        // Update isConfirmed in tbl_job_orders (MySQL)
        $stmt = $conn->prepare("UPDATE tbl_job_orders SET isConfirmed = 1 WHERE job_order_id = ?");
        $stmt->bind_param("i", $job_order_id);
        $stmt->execute();
        $stmt->close();

        // Find chat_id and last message_id for this job order
        $stmt = $conn->prepare("SELECT chat_id FROM tbl_chats WHERE job_order_id = ? LIMIT 1");
        $stmt->bind_param("i", $job_order_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $chatRow = $result->fetch_assoc();
        $stmt->close();

        if ($chatRow && $chatRow['chat_id']) {
            $chat_id = $chatRow['chat_id'];

            // Get customer_id and plumber_id for this job order
            $stmt = $conn->prepare("SELECT customer_id, plumber_id FROM tbl_job_orders WHERE job_order_id = ? LIMIT 1");
            $stmt->bind_param("i", $job_order_id);
            $stmt->execute();
            $result = $stmt->get_result();
            $jobRow = $result->fetch_assoc();
            $stmt->close();

            $customer_id = $jobRow ? $jobRow['customer_id'] : null;
            $plumber_id = $jobRow ? $jobRow['plumber_id'] : null;

            // Compose confirmation message
            $confirmationMsg = "Job order has been confirmed by customer.\nJob Order #: $job_order_id";

            // Insert confirmation message into tbl_chat_messages
            $sender = 'customer';
            $stmt = $conn->prepare("INSERT INTO tbl_chat_messages (chat_id, customer_id, plumber_id, sender, message, sent_at) VALUES (?, ?, ?, ?, ?, ?)");
            $stmt->bind_param("iiisss", $chat_id, $customer_id, $plumber_id, $sender, $confirmationMsg, $sentAt);
            $stmt->execute();
            $confirmation_message_id = $stmt->insert_id;
            $stmt->close();

            // Push confirmation message to Firebase
            try {
                $factory = (new Kreait\Firebase\Factory)
                    ->withServiceAccount(__DIR__ . '/service-account.json')
                    ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com');
                $database = $factory->createDatabase();
                $setResult = $database->getReference("chats/$chat_id/messages/$confirmation_message_id")->set([
                    'chat_id' => $chat_id,
                    'customer_id' => $customer_id,
                    'plumber_id' => $plumber_id,
                    'sender' => $sender,
                    'message' => $confirmationMsg,
                    'media_path' => '',
                    'thumbnail_path' => '',
                    'sent_at' => date('c'),
                    'message_id' => $confirmation_message_id,
                ]);
                if (!$setResult) {
                    file_put_contents(__DIR__ . '/report_debug.txt', date('c') . " - Firebase set() FAILED for chat_id=$chat_id message_id=$confirmation_message_id\n", FILE_APPEND);
                }
            } catch (Throwable $e) {
                file_put_contents(__DIR__ . '/report_debug.txt', date('c') . " - Firebase exception: " . $e->getMessage() . "\n", FILE_APPEND);
            }
        } else {
            // No chat exists, create one
            $stmt = $conn->prepare("SELECT customer_id, plumber_id FROM tbl_job_orders WHERE job_order_id = ? LIMIT 1");
            $stmt->bind_param("i", $job_order_id);
            $stmt->execute();
            $result = $stmt->get_result();
            $jobRow = $result->fetch_assoc();
            $stmt->close();

            $customer_id = $jobRow ? $jobRow['customer_id'] : null;
            $plumber_id = $jobRow ? $jobRow['plumber_id'] : null;

            $stmt = $conn->prepare("INSERT INTO tbl_chats (customer_id, plumber_id, created_at, updated_at) VALUES (?, ?, NOW(), NOW())");
            $stmt->bind_param("ii", $customer_id, $plumber_id);
            $stmt->execute();
            $chat_id = $stmt->insert_id;
            $stmt->close();
            // ...insert message using $chat_id...
        }

        echo json_encode(["success" => "Job order confirmed and confirmation message sent"]);
        exit;
    }
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
