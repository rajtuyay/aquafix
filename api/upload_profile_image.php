<?php
header('Content-Type: application/json');
$allowedTypes = ['customer', 'plumber'];
$baseDir = $_SERVER['DOCUMENT_ROOT'] . '/uploads/profiles/';
$baseUrl = 'https://aquafixsansimon.com/uploads/profiles/';

if (!isset($_POST['user_type'], $_POST['user_id']) || !isset($_FILES['profile_image'])) {
    echo json_encode(['error' => 'Missing parameters']);
    exit;
}

$userType = $_POST['user_type'];
$userId = $_POST['user_id'];
if (!in_array($userType, $allowedTypes)) {
    echo json_encode(['error' => 'Invalid user type']);
    exit;
}

$targetDir = $baseDir . $userType . 's/';
if (!is_dir($targetDir)) {
    mkdir($targetDir, 0777, true);
}

$file = $_FILES['profile_image'];
$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
$allowedExts = ['jpg', 'jpeg', 'png', 'gif'];
if (!in_array($ext, $allowedExts)) {
    echo json_encode(['error' => 'Invalid file type']);
    exit;
}

$uniqueName = 'profile_' . $userId . '_' . uniqid() . '.' . $ext;
$targetFile = $targetDir . $uniqueName;

if (!move_uploaded_file($file['tmp_name'], $targetFile)) {
    echo json_encode(['error' => 'Failed to upload file']);
    exit;
}

echo json_encode([
    'profile_image' => $uniqueName,
    'profile_image_url' => $baseUrl . $userType . 's/' . $uniqueName
]);
?>
