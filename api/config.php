<?php
// Show all errors and flush output immediately
error_reporting(E_ALL);
ini_set('display_errors', 1); // Enable error display for debugging
ini_set('output_buffering', 'off');
ini_set('zlib.output_compression', 0);
ob_implicit_flush(1);

    // filepath: api/config.php
    $servername = "localhost";
    $username = "u405234611_aquafix";
    $password = "Aqfixssm@05";
    $dbname = "u405234611_db_aquafix";

    // Create connection
    $conn = new mysqli($servername, $username, $password, $dbname);

    // Check connection
    if ($conn->connect_error) {
        http_response_code(500);
        echo json_encode(["error" => "Connection failed: " . $conn->connect_error]);
        exit;
    }
?>