<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

// --- Add GD thumbnail function ---
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

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['report_id'])) {
    $report_id = intval($_POST['report_id']);
    $media_dir = "../uploads/report_media/";
    if (!is_dir($media_dir)) {
        mkdir($media_dir, 0777, true);
    }
    $media_saved = [];

    foreach ($_FILES as $key => $file) {
        if (is_array($file['name'])) {
            foreach ($file['name'] as $idx => $name) {
                $tmp_name = $file['tmp_name'][$idx];
                $type = $file['type'][$idx];
                $error = $file['error'][$idx];
                $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
                $media_type = in_array($ext, ['jpg', 'jpeg', 'png']) ? 'image' : (in_array($ext, ['mp4', 'mov']) ? 'video' : 'other');
                if ($error === UPLOAD_ERR_OK && ($media_type === 'image' || $media_type === 'video')) {
                    $filename = uniqid("report{$report_id}_") . '.' . $ext;
                    $target = $media_dir . $filename;
                    if (move_uploaded_file($tmp_name, $target)) {
                        $thumbnail_path = null;

                        // Check if a thumbnail is sent for this media
                        $thumbKey = str_replace('media', 'thumbnail', $key);
                        if (isset($_FILES[$thumbKey])) {
                            $thumbFile = $_FILES[$thumbKey];
                            $thumbExt = strtolower(pathinfo($thumbFile['name'][$idx], PATHINFO_EXTENSION));
                            $thumbName = 'thumb_' . pathinfo($filename, PATHINFO_FILENAME) . '.' . $thumbExt;
                            $thumbTarget = $media_dir . $thumbName;
                            if (move_uploaded_file($thumbFile['tmp_name'][$idx], $thumbTarget)) {
                                $thumbnail_path = $thumbName;
                            }
                        } else if ($media_type === 'video') {
                            // Fallback to GD placeholder if no thumbnail sent
                            $baseName = pathinfo($filename, PATHINFO_FILENAME);
                            $thumbName = 'thumb_' . $baseName . '.jpg';
                            $thumbTarget = $media_dir . $thumbName;
                            if (createPlaceholderThumbnail($thumbTarget)) {
                                $thumbnail_path = $thumbName;
                            }
                        }

                        $stmt = $conn->prepare(
                            "INSERT INTO tbl_report_media (report_id, media_type, file_path, thumbnail_path) VALUES (?, ?, ?, ?)"
                        );
                        $stmt->bind_param("isss", $report_id, $media_type, $filename, $thumbnail_path);
                        $stmt->execute();
                        $media_saved[] = [
                            'file' => $filename,
                            'thumbnail' => $thumbnail_path
                        ];
                    }
                }
            }
        } else {
            $name = $file['name'];
            $tmp_name = $file['tmp_name'];
            $type = $file['type'];
            $error = $file['error'];
            $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
            $media_type = in_array($ext, ['jpg', 'jpeg', 'png']) ? 'image' : (in_array($ext, ['mp4', 'mov']) ? 'video' : 'other');
            if ($error === UPLOAD_ERR_OK && ($media_type === 'image' || $media_type === 'video')) {
                $filename = uniqid("report{$report_id}_") . '.' . $ext;
                $target = $media_dir . $filename;
                if (move_uploaded_file($tmp_name, $target)) {
                    $thumbnail_path = null;

                    // Check if a thumbnail is sent for this media
                    $thumbKey = str_replace('media', 'thumbnail', $key);
                    if (isset($_FILES[$thumbKey])) {
                        $thumbFile = $_FILES[$thumbKey];
                        $thumbExt = strtolower(pathinfo($thumbFile['name'], PATHINFO_EXTENSION));
                        $thumbName = 'thumb_' . pathinfo($filename, PATHINFO_FILENAME) . '.' . $thumbExt;
                        $thumbTarget = $media_dir . $thumbName;
                        if (move_uploaded_file($thumbFile['tmp_name'], $thumbTarget)) {
                            $thumbnail_path = $thumbName;
                        }
                    } else if ($media_type === 'video') {
                        // Fallback to GD placeholder if no thumbnail sent
                        $baseName = pathinfo($filename, PATHINFO_FILENAME);
                        $thumbName = 'thumb_' . $baseName . '.jpg';
                        $thumbTarget = $media_dir . $thumbName;
                        if (createPlaceholderThumbnail($thumbTarget)) {
                            $thumbnail_path = $thumbName;
                        }
                    }

                    $stmt = $conn->prepare(
                        "INSERT INTO tbl_report_media (report_id, media_type, file_path, thumbnail_path) VALUES (?, ?, ?, ?)"
                    );
                    $stmt->bind_param("isss", $report_id, $media_type, $filename, $thumbnail_path);
                    $stmt->execute();
                    $media_saved[] = [
                        'file' => $filename,
                        'thumbnail' => $thumbnail_path
                    ];
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "media" => $media_saved
    ]);
    exit;
}
http_response_code(400);
echo json_encode(["error" => "Invalid request"]);
$conn->close();