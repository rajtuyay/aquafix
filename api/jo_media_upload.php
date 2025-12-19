<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// Directory to save uploads
$uploadDir = "../uploads/jo_media/";

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Required fields: job_order_id, media_type, file
    if (!isset($_POST['job_order_id']) || !isset($_POST['media_type']) || !isset($_FILES['file'])) {
        http_response_code(400);
        echo json_encode(["error" => "Missing required fields"]);
        exit;
    }

    $job_order_id = intval($_POST['job_order_id']);
    $media_type = $_POST['media_type']; // 'image' or 'video'
    $file = $_FILES['file'];

    // Validate media_type
    if (!in_array($media_type, ['image', 'video'])) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid media_type"]);
        exit;
    }

    // Validate file
    if (!isset($file['error']) || is_array($file['error'])) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid file upload parameters"]);
        exit;
    }
    if ($file['error'] !== UPLOAD_ERR_OK) {
        $errorMsg = "File upload error";
        switch ($file['error']) {
            case UPLOAD_ERR_INI_SIZE:
            case UPLOAD_ERR_FORM_SIZE:
                $errorMsg = "File is too large";
                break;
            case UPLOAD_ERR_PARTIAL:
                $errorMsg = "File was only partially uploaded";
                break;
            case UPLOAD_ERR_NO_FILE:
                $errorMsg = "No file was uploaded";
                break;
            case UPLOAD_ERR_NO_TMP_DIR:
                $errorMsg = "Missing a temporary folder";
                break;
            case UPLOAD_ERR_CANT_WRITE:
                $errorMsg = "Failed to write file to disk";
                break;
            case UPLOAD_ERR_EXTENSION:
                $errorMsg = "File upload stopped by extension";
                break;
        }
        http_response_code(400);
        echo json_encode(["error" => $errorMsg]);
        exit;
    }

    // Check file size (example: max 20MB for video, 5MB for image)
    $maxSize = $media_type === 'image' ? 5 * 1024 * 1024 : 20 * 1024 * 1024;
    if ($file['size'] > $maxSize) {
        http_response_code(400);
        echo json_encode(["error" => "File exceeds maximum allowed size"]);
        exit;
    }

    // Get file extension
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed = $media_type === 'image' ? ['jpg', 'jpeg', 'png'] : ['mp4', 'mov'];
    if (!in_array($ext, $allowed)) {
        http_response_code(400);
        echo json_encode(["error" => "Invalid file extension"]);
        exit;
    }

    // Ensure upload directory exists
    if (!is_dir($uploadDir)) {
        if (!mkdir($uploadDir, 0777, true)) {
            http_response_code(500);
            echo json_encode(["error" => "Failed to create upload directory"]);
            exit;
        }
    }

    // Generate unique file name
    $filename = uniqid("jo{$job_order_id}_") . '.' . $ext;
    $targetPath = $uploadDir . $filename;

    // Move uploaded file
    if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
        http_response_code(500);
        echo json_encode(["error" => "Failed to save file. Check directory permissions."]);
        exit;
    }

    // Save to tbl_jo_media
    $stmt = $conn->prepare("INSERT INTO tbl_jo_media (job_order_id, media_type, file_path) VALUES (?, ?, ?)");
    if (!$stmt) {
        http_response_code(500);
        echo json_encode(["error" => "Database prepare failed: " . $conn->error]);
        // Optionally, remove the uploaded file if DB fails
        @unlink($targetPath);
        exit;
    }
    $stmt->bind_param("iss", $job_order_id, $media_type, $filename);
    if ($stmt->execute()) {
        echo json_encode(["success" => true, "filename" => $filename]);
    } else {
        http_response_code(500);
        echo json_encode(["error" => "Database insert failed: " . $stmt->error]);
        // Optionally, remove the uploaded file if DB fails
        @unlink($targetPath);
    }
    exit;
}

http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();
