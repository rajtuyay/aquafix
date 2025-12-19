<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
include 'config.php';

$result = $conn->query("SELECT material_id, material_name, size, price FROM tbl_materials ORDER BY material_name, size");
$materials = [];
while ($row = $result->fetch_assoc()) {
    $materials[] = $row;
}
echo json_encode($materials);
$conn->close();
