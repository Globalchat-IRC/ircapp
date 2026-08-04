<?php
/**
 * Proxy de subida de avatar GIF para evitar problemas CORS desde la web.
 * Recibe multipart/form-data y reenvía la subida al xmlrpc remoto.
 */

if (function_exists('opcache_reset')) {
    opcache_reset();
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'Método no permitido',
    ]);
    exit;
}

$hash = $_POST['hash'] ?? '';
$username = $_POST['username'] ?? '';

if (empty($hash) || empty($username) || !isset($_FILES['avatar'])) {
    http_response_code(400);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'Faltan parámetros requeridos',
    ]);
    exit;
}

$avatarFile = $_FILES['avatar'];
if (!isset($avatarFile['tmp_name']) || !is_uploaded_file($avatarFile['tmp_name'])) {
    http_response_code(400);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'Archivo de avatar inválido',
    ]);
    exit;
}

$remoteUrl = 'https://xmlrpc.globalchat.org/avatar/upload-custom-avatar.php';
$mimeType = $avatarFile['type'] ?? 'image/gif';
$fileName = $avatarFile['name'] ?? ($hash . '.gif');

$postFields = [
    'hash' => $hash,
    'username' => $username,
    'avatar' => new CURLFile($avatarFile['tmp_name'], $mimeType, $fileName),
];

$ch = curl_init($remoteUrl);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $postFields);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Accept: application/json, text/plain, */*',
]);

$responseBody = curl_exec($ch);
$curlError = curl_error($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($responseBody === false) {
    http_response_code(502);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode([
        'success' => false,
        'message' => 'Error al contactar con xmlrpc',
        'details' => $curlError,
    ]);
    exit;
}

http_response_code($httpCode > 0 ? $httpCode : 200);
header('Content-Type: application/json; charset=utf-8');
echo $responseBody;
