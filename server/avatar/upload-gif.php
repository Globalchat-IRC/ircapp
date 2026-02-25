<?php
// CORS lo primero, para que la app web (mobilev1.globalchat.org) pueda llamar a este endpoint
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');
/**
 * Subida de avatar animado (GIF) para la app IRC.
 * POST multipart: "nick" (texto) y "gif" (fichero).
 * Guarda en avatars/default/{hash}.gif con hash = MD5(nick trim) para que
 * todos los clientes carguen la misma URL (getAvatarGifUrl).
 */

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'error' => 'Solo POST']);
    exit;
}

$nick = isset($_POST['nick']) ? trim((string) $_POST['nick']) : '';
if ($nick === '') {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Falta nick']);
    exit;
}

if (!isset($_FILES['gif']) || $_FILES['gif']['error'] !== UPLOAD_ERR_OK) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Falta fichero gif o error de subida']);
    exit;
}

$tmpPath = $_FILES['gif']['tmp_name'];
$size = @filesize($tmpPath);
if ($size === false || $size === 0 || $size > 2 * 1024 * 1024) { // máx 2 MB
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'Fichero no válido o demasiado grande (máx 2 MB)']);
    exit;
}

$header = @file_get_contents($tmpPath, false, null, 0, 6);
if ($header !== false && $header !== 'GIF87a' && $header !== 'GIF89a') {
    http_response_code(400);
    echo json_encode(['ok' => false, 'error' => 'El fichero debe ser un GIF']);
    exit;
}

$hash = md5($nick);
$dir = __DIR__ . '/avatars/default';
if (!is_dir($dir)) {
    if (!@mkdir($dir, 0755, true)) {
        http_response_code(500);
        echo json_encode(['ok' => false, 'error' => 'No se pudo crear el directorio']);
        exit;
    }
}

$dest = $dir . '/' . $hash . '.gif';
if (!@move_uploaded_file($tmpPath, $dest)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'error' => 'No se pudo guardar el fichero']);
    exit;
}

http_response_code(200);
echo json_encode(['ok' => true, 'hash' => $hash]);
