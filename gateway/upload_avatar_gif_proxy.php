<?php
/**
 * Proxy de subida de avatar GIF en mismo origen (mobilev1).
 * Recibe POST multipart (nick + gif) y reenvía a xmlrpc.globalchat.org/avatar/upload-gif.php
 * para evitar CORS cuando la app web (mobilev1) no puede hacer POST cross-origin.
 */
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');
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

$targetUrl = 'https://xmlrpc.globalchat.org/avatar/upload-gif.php';
$tmpPath = $_FILES['gif']['tmp_name'];

$cfile = new CURLFile($tmpPath, 'image/gif', 'avatar.gif');
$post = [
    'nick' => $nick,
    'gif'  => $cfile,
];

$ch = curl_init($targetUrl);
curl_setopt_array($ch, [
    CURLOPT_POST           => true,
    CURLOPT_POSTFIELDS     => $post,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_TIMEOUT        => 20,
    CURLOPT_HTTPHEADER     => [],
]);

$body = curl_exec($ch);
$code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
$err = curl_error($ch);
curl_close($ch);

if ($err !== '') {
    http_response_code(502);
    echo json_encode(['ok' => false, 'error' => 'Error al reenviar: ' . $err]);
    exit;
}

http_response_code($code);
echo $body !== false ? $body : json_encode(['ok' => false, 'error' => 'Respuesta vacía']);
