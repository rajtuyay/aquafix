<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// Include PHPMailer (adjust path if needed)
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;
require __DIR__ . '/PHPMailer/src/Exception.php';
require __DIR__ . '/PHPMailer/src/PHPMailer.php';
require __DIR__ . '/PHPMailer/src/SMTP.php';

// Helper: Send OTP email using PHPMailer
function sendOtpEmail($to, $otp) {
    $mail = new PHPMailer(true);
    try {
        // SMTP config
        $mail->isSMTP();
        $mail->Host = 'smtp.hostinger.com';
        $mail->SMTPAuth = true;
        $mail->Username = 'support@aquafixsansimon.com';
        $mail->Password = 'Aqfixssm@05';
        $mail->SMTPSecure = 'tls';
        $mail->Port = 587;

        $mail->setFrom('support@aquafixsansimon.com', 'AquaFix Support');
        $mail->addAddress($to);

        $mail->isHTML(true);
        $mail->Subject = 'Your AquaFix Password Reset OTP';
        $mail->Body = "Your OTP for AquaFix password reset is: <b>$otp</b><br>This code is valid for 10 minutes.<br>If you did not request this, please ignore this email.";

        $mail->send();
        return true;
    } catch (Exception $e) {
        return false;
    }
}

date_default_timezone_set('Asia/Manila');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);
    if (!isset($data['email']) || empty($data['email'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "message" => "Email is required."]);
        exit;
    }
    $email = trim($data['email']);

    // Get customer_id from email
    $stmt = $conn->prepare("SELECT customer_id FROM tbl_customers WHERE email=?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    if (!$user) {
        http_response_code(404);
        echo json_encode(["success" => false, "message" => "No account found with this email. Try again or sign up."]);
        exit;
    }
    $customer_id = $user['customer_id'];

    // Generate OTP (6 digits)
    $otp = str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
    $expires_at = date('Y-m-d H:i:s', strtotime('+10 minutes'));

    // Invalidate previous unused OTPs for this customer
    $stmt = $conn->prepare("UPDATE tbl_otps SET used=1 WHERE customer_id=? AND used=0");
    $stmt->bind_param("i", $customer_id);
    $stmt->execute();

    // Save new OTP to DB
    $stmt = $conn->prepare("INSERT INTO tbl_otps (customer_id, otp, expires_at, used) VALUES (?, ?, ?, 0)");
    $stmt->bind_param("iss", $customer_id, $otp, $expires_at);
    $stmt->execute();

    // Send OTP via PHPMailer
    $sent = sendOtpEmail($email, $otp);

    if ($sent) {
        echo json_encode(["success" => true, "message" => "OTP sent to your email."]);
    } else {
        http_response_code(500);
        echo json_encode(["success" => false, "message" => "Failed to send OTP email."]);
    }
    exit;
}

http_response_code(400);
echo json_encode(["success" => false, "message" => "Invalid request."]);
$conn->close();