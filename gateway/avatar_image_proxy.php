<?php
/**
 * Proxy para servir imágenes de avatar desde avatar.globalchat.org
 * Evita problemas de CORS en el cliente web (mobilev1.globalchat.org).
 *
 * Uso: /api/avatar_image_proxy.php?url=<encoded_avatar_url>
 * o:   /api/avatar_image_proxy.php?server=<png|gif>&folder=<default|custom|400|80|40>&hash=<md5>&ext=<png|gif>
 *
 * El proxy descarga la imagen del servidor original y la sirve con
 * headers CORS y caché del navegador.
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Opción 1: URL directa codificada
$url = $_GET['url'] ?? null;

// Opción 2: parámetros individuales
if (!$url) {
    $server = $_GET['server'] ?? 'png';     // 'png' -> avatar.globalchat.org, 'gif' -> xmlrpc.globalchat.org
    $folder = $_GET['folder'] ?? 'default';
    $hash   = $_GET['hash']   ?? null;
    $ext    = $_GET['ext']    ?? ($server === 'gif' ? 'gif' : 'png');

    if (!$hash || !preg_match('/^[a-f0-9]{32}$/', $hash)) {
        http_response_code(400);
        echo 'Missing or invalid hash parameter';
        exit;
    }

    if ($server === 'gif') {
        $url = "https://xmlrpc.globalchat.org/avatar/avatars/{$folder}/{$hash}.{$ext}";
    } else {
        $url = "https://avatar.globalchat.org/avatars/{$folder}/{$hash}.{$ext}";
    }
}

// Validar que la URL sea de dominios conocidos
$parsed = parse_url($url);
$allowedHosts = ['avatar.globalchat.org', 'xmlrpc.globalchat.org'];
if (!$parsed || !isset($parsed['host']) || !in_array($parsed['host'], $allowedHosts)) {
    http_response_code(403);
    echo 'Invalid avatar host';
    exit;
}

// Parámetro de cache-buster opcional (no se reenvía al origin)
$query = $parsed['query'] ?? null;

// Descargar la imagen
// Nota: en ceres, xmlrpc.globalchat.org resuelve a 127.0.0.1 (/etc/hosts)
// pero los archivos están en hub.globalchat.org (147.135.192.74).
// Reemplazar el dominio por la IP real y enviar Host header.
$curlUrl = $url;
$curlHeaders = ['User-Agent: GlobalChat/1.0 AvatarProxy'];
if (isset($parsed['host']) && $parsed['host'] === 'xmlrpc.globalchat.org') {
    $curlUrl = str_replace('https://xmlrpc.globalchat.org', 'https://147.135.192.74', $url);
    $curlHeaders[] = 'Host: xmlrpc.globalchat.org';
}

$ch = curl_init($curlUrl);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_TIMEOUT        => 10,
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_SSL_VERIFYHOST => false,
    CURLOPT_HTTPHEADER     => $curlHeaders,
]);

$imageData = curl_exec($ch);
$httpCode  = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
curl_close($ch);

if ($httpCode !== 200 || $imageData === false || strlen($imageData) === 0) {
    http_response_code(404);
    echo 'Avatar not found';
    exit;
}

// Determinar content type válido
if (str_contains($contentType, 'gif')) {
    $serveContentType = 'image/gif';
} elseif (str_contains($contentType, 'png')) {
    $serveContentType = 'image/png';
} elseif (str_contains($contentType, 'jpeg') || str_contains($contentType, 'jpg')) {
    $serveContentType = 'image/jpeg';
} else {
    // Detectar por magic bytes
    $extBin = substr($imageData, 0, 4);
    if (str_starts_with($extBin, "\x89PNG")) {
        $serveContentType = 'image/png';
    } elseif (str_starts_with($extBin, "GIF8")) {
        $serveContentType = 'image/gif';
    } elseif (str_starts_with($extBin, "\xFF\xD8\xFF")) {
        $serveContentType = 'image/jpeg';
    } else {
        $serveContentType = 'application/octet-stream';
    }
}

// Servir con caché del navegador (1 hora) y CORS
header("Content-Type: {$serveContentType}");
header('Cache-Control: public, max-age=3600');
header('Content-Length: ' . strlen($imageData));

echo $imageData;
