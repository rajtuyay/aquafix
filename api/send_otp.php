<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// Enable error reporting for debugging
ini_set('display_errors', 1);
error_reporting(E_ALL);

// Include PHPMailer (adjust path if needed)
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;
require __DIR__ . '/PHPMailer/src/Exception.php';
require __DIR__ . '/PHPMailer/src/PHPMailer.php';
require __DIR__ . '/PHPMailer/src/SMTP.php';

// Include Firebase
require_once __DIR__ . '/vendor/autoload.php';
use Kreait\Firebase\Factory;

function sendOtpEmail($to, $otp) {
    $mail = new PHPMailer(true);
    try {
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
        $mail->Subject = 'Your AquaFix Registration OTP';
        $mail->Body = "Your OTP for AquaFix registration is: <b>$otp</b><br>This code is valid for 10 minutes.<br>If you did not request this, please ignore this email.";

        $mail->send();
        return true;
    } catch (Exception $e) {
        error_log('PHPMailer error: ' . $mail->ErrorInfo . ' Exception: ' . $e->getMessage());
        return $mail->ErrorInfo . ' | Exception: ' . $e->getMessage();
    }
}

date_default_timezone_set('Asia/Manila');

$data = json_decode(file_get_contents("php://input"), true);

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
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
    $stmt->close();

    // For registration, if not found, generate a temporary customer_id based on email hash
    if ($user) {
        $customer_id = $user['customer_id'];
    } else {
        // Use a hash of the email as customer_id for unregistered users
        $customer_id = substr(md5(strtolower($email)), 0, 16);
    }

    // Initialize Firebase
    $firebaseDb = (new Factory)
        ->withServiceAccount(__DIR__ . '/service-account.json')
        ->withDatabaseUri('https://graceful-fold-459906-k9-default-rtdb.firebaseio.com')
        ->createDatabase();

    // If OTP is provided, verify
    if (isset($data['otp'])) {
        $otp = trim($data['otp']);
        $otpRef = $firebaseDb->getReference('otps/' . $customer_id);
        $otpData = $otpRef->getValue();

        if ($otpData && isset($otpData['otp'], $otpData['expires_at'], $otpData['used'])) {
            $now = time();
            if (
                $otpData['otp'] === $otp &&
                $otpData['used'] == false &&
                $now < strtotime($otpData['expires_at'])
            ) {
                // Mark as used
                $otpRef->update(['used' => true]);
                echo json_encode(["success" => true, "message" => "OTP verified."]);
            } else {
                http_response_code(400);
                echo json_encode(["success" => false, "message" => "Invalid or expired OTP."]);
            }
        } else {
            http_response_code(400);
            echo json_encode(["success" => false, "message" => "OTP not found."]);
        }
        exit;
    }

    // Generate OTP (6 digits)
    $otp = str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
    $expires_at = date('Y-m-d H:i:s', strtotime('+10 minutes'));

    // Save OTP to Firebase
    $otpRef = $firebaseDb->getReference('otps/' . $customer_id);
    $otpRef->set([
        'otp' => $otp,
        'expires_at' => $expires_at,
        'used' => false,
        'email' => $email,
        'created_at' => date('Y-m-d H:i:s'),
    ]);

    // Send OTP via PHPMailer
    $sent = sendOtpEmail($email, $otp);

    if ($sent === true) {
        echo json_encode(["success" => true, "message" => "OTP sent to your email."]);
    } else {
        http_response_code(500);
        error_log("PHPMailer send error: " . $sent);
        echo json_encode(["success" => false, "message" => "Failed to send OTP email.", "error" => $sent]);
    }
    exit;
}