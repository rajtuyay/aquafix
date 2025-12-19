<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

$data = json_decode(file_get_contents("php://input"), true);

date_default_timezone_set('Asia/Manila'); // Set your timezone

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!isset($data['email']) || !isset($data['otp'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Missing email or OTP."]);
        exit;
    }

    $email = trim($data['email']);
    $otp = trim($data['otp']);

    // Get customer_id from email
    $stmt = $conn->prepare("SELECT customer_id FROM tbl_customers WHERE email=?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();

    if (!$user) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "Email not found."]);
        exit;
    }
    $customer_id = $user['customer_id'];

    // Check if OTP is valid and not expired (valid for 10 minutes)
    $stmt = $conn->prepare("SELECT * FROM tbl_otps WHERE customer_id=? AND otp=? AND expires_at > ? AND used=0 ORDER BY expires_at DESC LIMIT 1");
    $manilaTz = new DateTimeZone('Asia/Manila');
    $manilaNow = new DateTime('now', $manilaTz);
    $createdAt = $manilaNow->format('Y-m-d H:i:s');
    $stmt->bind_param("iss", $customer_id, $otp, $createdAt);
    $stmt->execute();
    $result = $stmt->get_result();
    $otp_row = $result->fetch_assoc();

    if (!$otp_row) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Invalid or expired OTP."]);
        exit;
    }

    // If new_password is provided, update password
    if (isset($data['new_password']) && strlen($data['new_password']) >= 6) {
        $new_password = password_hash($data['new_password'], PASSWORD_DEFAULT);

        // Update password for customer
        $update = $conn->prepare("UPDATE tbl_customers SET password=? WHERE customer_id=?");
        $update->bind_param("si", $new_password, $customer_id);
        if ($update->execute()) {
            // Mark OTP as used
            $mark = $conn->prepare("UPDATE tbl_otps SET used=1 WHERE otp_id=?");
            $mark->bind_param("i", $otp_row['otp_id']);
            $mark->execute();

            echo json_encode(["success" => true, "message" => "Password updated successfully."]);
        } else {
            http_response_code(500);
            echo json_encode(["success" => false, "message" => "Failed to update password."]);
        }
        exit;
    }

    // If only OTP is provided, just verify
    echo json_encode(["success" => true, "message" => "OTP verified."]);
    exit;
}

http_response_code(400);
echo json_encode(["success" => false, "message" => "Invalid request."]);
$conn->close();