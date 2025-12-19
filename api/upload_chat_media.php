<?php
header('Content-Type: application/json');
error_log("📥 Starting upload_chat_media.php");

// ==================
// Global error handler for fatal errors
// ==================
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null) {
        error_log("❌ Fatal error: " . print_r($error, true));
        echo json_encode(['error' => 'Fatal server error', 'details' => $error]);
    }
});

// ==================
// Configuration
// ==================
$relativePath = '/uploads/chats_media';
$baseUrl = 'https://aquafixsansimon.com/uploads/chats_media';
$targetDir = $_SERVER['DOCUMENT_ROOT'] . '/uploads/chats_media';

function debug_log($msg) {
    file_put_contents(__DIR__ . '/php-error.log', date('Y-m-d H:i:s') . ' ' . $msg . "\n", FILE_APPEND);
}

// ==================
// Force error reporting and set error log path
// ==================
ini_set('display_errors', 0); // Do not display errors to client
ini_set('display_startup_errors', 0);
error_reporting(E_ALL);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log');

// ==================
// Ensure folder exists
// ==================
debug_log("DOCUMENT_ROOT: " . $_SERVER['DOCUMENT_ROOT']);
debug_log("Target upload dir: $targetDir");
if (!is_dir($targetDir)) {
    debug_log("Target directory does not exist. Attempting to create: $targetDir");
    if (!mkdir($targetDir, 0777, true)) {
        debug_log("❌ Failed to create target directory: $targetDir");
        echo json_encode(['error' => 'Failed to create upload directory.']);
        exit;
    }
}
if (!is_writable($targetDir)) {
    debug_log("❌ Target directory is not writable: $targetDir");
    echo json_encode(['error' => 'Upload directory is not writable.']);
    exit;
}
chmod($targetDir, 0777);

// ==================
// File Upload Validation
// ==================
if (!isset($_FILES['media'])) {
    error_log("❌ No file uploaded");
    echo json_encode(['error' => 'No file uploaded.']);
    exit;
}

$file = $_FILES['media'];
error_log("📁 File upload details: " . json_encode($file));

// Check for PHP upload errors
if ($file['error'] !== UPLOAD_ERR_OK) {
    error_log("❌ PHP file upload error: " . $file['error']);
    $phpErrorMessages = [
        UPLOAD_ERR_INI_SIZE   => 'The uploaded file exceeds the upload_max_filesize directive in php.ini.',
        UPLOAD_ERR_FORM_SIZE  => 'The uploaded file exceeds the MAX_FILE_SIZE directive that was specified in the HTML form.',
        UPLOAD_ERR_PARTIAL    => 'The uploaded file was only partially uploaded.',
        UPLOAD_ERR_NO_FILE    => 'No file was uploaded.',
        UPLOAD_ERR_NO_TMP_DIR => 'Missing a temporary folder.',
        UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk.',
        UPLOAD_ERR_EXTENSION  => 'A PHP extension stopped the file upload.',
    ];
    $errorMsg = $phpErrorMessages[$file['error']] ?? 'Unknown upload error.';
    echo json_encode(['error' => $errorMsg, 'php_error' => $file['error']]);
    exit;
}

$filename = basename($file['name']);
$ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));

$videoExts = ['mp4', 'mov', 'avi', 'webm', 'mkv'];
$imageExts = ['jpg', 'jpeg', 'png', 'gif'];
$allowedExts = array_merge($videoExts, $imageExts);

// Check extension
if (!in_array($ext, $allowedExts)) {
    error_log("❌ Invalid file extension: $ext");
    echo json_encode(['error' => 'Invalid file type.']);
    exit;
}

// Check MIME type
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);

$allowedMimeTypes = [
    'video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/webm', 'video/x-matroska',
    'image/jpeg', 'image/png', 'image/gif'
];
if (!in_array($mimeType, $allowedMimeTypes)) {
    error_log("❌ Invalid MIME type: $mimeType");
    echo json_encode(['error' => 'Invalid file content.']);
    exit;
}

// ==================
// Generate unique filename and target path
// ==================
if (in_array($ext, $imageExts)) {
    $prefix = 'image_';
} elseif (in_array($ext, $videoExts)) {
    $prefix = 'video_';
} else {
    $prefix = 'media_';
}
$uniqueName = uniqid($prefix, true) . '_' . time() . '.' . $ext;
$targetFile = $targetDir . DIRECTORY_SEPARATOR . $uniqueName;

// ==================
// Save Uploaded File
// ==================
debug_log("Saving to: $targetFile");
debug_log("Target dir exists: " . (is_dir($targetDir) ? 'YES' : 'NO'));
debug_log("Target dir writable: " . (is_writable($targetDir) ? 'YES' : 'NO'));
debug_log("Temp file exists: " . (file_exists($file['tmp_name']) ? 'YES' : 'NO'));
debug_log("Temp file readable: " . (is_readable($file['tmp_name']) ? 'YES' : 'NO'));

if (!move_uploaded_file($file['tmp_name'], $targetFile)) {
    debug_log("❌ move_uploaded_file failed. TMP: " . $file['tmp_name']);
    debug_log("Check temp file exists: " . (file_exists($file['tmp_name']) ? 'YES' : 'NO'));
    debug_log("Target writable: " . (is_writable($targetDir) ? 'YES' : 'NO'));
    debug_log("File error code: " . $file['error']);
    debug_log("TargetFile: $targetFile");
    debug_log("Permissions: " . substr(sprintf('%o', fileperms($targetDir)), -4));
    debug_log("Current user: " . get_current_user());
    debug_log("Upload_max_filesize: " . ini_get('upload_max_filesize'));
    debug_log("Post_max_size: " . ini_get('post_max_size'));
    debug_log("File size: " . $file['size']);
    echo json_encode([
        'error' => 'Failed to upload file.',
        'php_error' => $file['error'],
        'target_dir_writable' => is_writable($targetDir),
        'target_dir_exists' => is_dir($targetDir),
        'tmp_file_exists' => file_exists($file['tmp_name']),
        'tmp_file_readable' => is_readable($file['tmp_name']),
        'target_file' => $targetFile,
        'upload_max_filesize' => ini_get('upload_max_filesize'),
        'post_max_size' => ini_get('post_max_size'),
        'file_size' => $file['size'],
        'current_user' => get_current_user()
    ]);
    exit;
}
debug_log("✅ File saved: $targetFile");

$response = [
    'media_path' => $uniqueName,
    'media_url' => $baseUrl . '/' . $uniqueName
];

// ==================
// Generate Thumbnail (for videos)
// ==================
if (in_array($ext, $videoExts)) {
    $baseName = pathinfo($uniqueName, PATHINFO_FILENAME);
    $thumbnailName = 'thumb_' . $baseName . '.jpg';
    $thumbnailPath = $targetDir . DIRECTORY_SEPARATOR . $thumbnailName;

    // Confirm file exists before processing
    if (!file_exists($targetFile)) {
        error_log("❌ Uploaded video not found at: $targetFile");
    }

    // Always use GD for video thumbnail
    $thumbnailSuccess = createPlaceholderThumbnail($thumbnailPath);
    if ($thumbnailSuccess) {
        error_log("✅ GD thumbnail created.");
    } else {
        error_log("❌ GD thumbnail failed.");
    }

    $response['thumbnail_path'] = $thumbnailName;
    $response['thumbnail_url'] = $baseUrl . '/' . $thumbnailName;

    // Log outcome
    if (!$thumbnailSuccess) {
        error_log("❌ Thumbnail NOT FOUND or failed at: $thumbnailPath");
    } else {
        error_log("✅ Thumbnail created: $thumbnailPath");
    }
}

// Save uploaded thumbnail if present
if (isset($_FILES['thumbnail'])) {
    $thumbFile = $_FILES['thumbnail'];
    $thumbName = 'thumb_' . pathinfo($uniqueName, PATHINFO_FILENAME) . '.jpg';
    $thumbTarget = $targetDir . DIRECTORY_SEPARATOR . $thumbName;
    move_uploaded_file($thumbFile['tmp_name'], $thumbTarget);
    $response['thumbnail_path'] = $thumbName;
    $response['thumbnail_url'] = $baseUrl . '/' . $thumbName;
}

// ==================
// After file upload, before saving to DB, add ffprobe validation for videos
// ==================
function is_valid_mp4_h264_aac($filePath) {
    // Only check for .mp4 files
    if (strtolower(pathinfo($filePath, PATHINFO_EXTENSION)) !== 'mp4') {
        return false;
    }
    // Use ffprobe from the /bin/ directory
    $ffprobePath = $_SERVER['DOCUMENT_ROOT'] . '/bin/ffprobe.exe';
    if (!file_exists($ffprobePath)) {
        error_log("❌ ffprobe not found at $ffprobePath");
        return false;
    }
    // Check if shell_exec is available
    if (!function_exists('shell_exec')) {
        error_log("❌ shell_exec() is disabled on this server. Cannot validate video codecs.");
        // If you want to reject all videos when shell_exec is disabled, return false:
        // return false;
        // If you want to allow videos but warn, return true:
        return true;
    }
    // Windows: wrap path in quotes and use escapeshellarg for file
    $cmdVideo = "\"$ffprobePath\" -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filePath);
    $videoCodec = trim(shell_exec($cmdVideo));
    $cmdAudio = "\"$ffprobePath\" -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 " . escapeshellarg($filePath);
    $audioCodec = trim(shell_exec($cmdAudio));
    // Accept only H.264 video and AAC audio
    return (strtolower($videoCodec) === 'h264' && strtolower($audioCodec) === 'aac');
}

if (in_array($ext, $videoExts)) {
    if (!is_valid_mp4_h264_aac($targetFile)) {
        // Optionally, unlink($targetFile);
        http_response_code(400);
        echo json_encode(['error' => 'Video must be MP4 (H.264/AAC).']);
        exit;
    }
}

// ==================
// Final Output
// ==================
echo json_encode($response);

// ==================
// GD fallback function
// ==================
// Remove or leave as is, but it will not be used for videos anymore
function createPlaceholderThumbnail($thumbnailPath) {
    if (!extension_loaded('gd')) {
        error_log("❌ GD library not loaded");
        return false;
    }

    try {
        $width = 320;
        $height = 240;
        $img = imagecreatetruecolor($width, $height);
        $bgColor = imagecolorallocate($img, 30, 30, 30);
        $accentColor = imagecolorallocate($img, 45, 156, 208);
        $textColor = imagecolorallocate($img, 255, 255, 255);

        imagefilledrectangle($img, 0, 0, $width, $height, $bgColor);

        $playButtonSize = 60;
        $centerX = $width / 2;
        $centerY = $height / 2;
        imagefilledellipse($img, $centerX, $centerY, $playButtonSize, $playButtonSize, $accentColor);

        $triangle = [
            $centerX - 5, $centerY - 10,
            $centerX - 5, $centerY + 10,
            $centerX + 10, $centerY
        ];
        imagefilledpolygon($img, $triangle, $textColor);

        $text = "VIDEO";
        $font = 4;
        $textWidth = imagefontwidth($font) * strlen($text);
        $textX = ($width - $textWidth) / 2;
        $textY = $height - 25;
        imagestring($img, $font, $textX, $textY, $text, $textColor);

        $result = imagejpeg($img, $thumbnailPath, 90);
        imagedestroy($img);

        return $result && file_exists($thumbnailPath);
    } catch (Exception $e) {
        error_log("❌ GD error: " . $e->getMessage());
        return false;
    }
}
?>