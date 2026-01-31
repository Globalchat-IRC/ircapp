<?php
/**
 * Proxy para streams de Mixcloud
 * Este proxy descarga el stream de Mixcloud y lo sirve con los headers CORS correctos
 * Uso: /mixcloud_stream_proxy.php?url=<URL_DEL_STREAM>
 */

// Los headers CORS los maneja Apache, no los duplicamos aquí

// Manejar preflight OPTIONS
if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Obtener la URL del stream
$streamUrl = $_GET['url'] ?? '';

if (empty($streamUrl)) {
    http_response_code(400);
    echo 'Error: No se proporcionó la URL del stream';
    exit;
}

// Validar que la URL sea de Mixcloud
if (!preg_match('/^https:\/\/live-[a-z0-9-]+\.mixcloud\.com\//', $streamUrl)) {
    http_response_code(400);
    echo 'Error: URL inválida (solo se permiten streams de Mixcloud)';
    exit;
}

// Configurar headers para streaming
header('Content-Type: application/vnd.apple.mpegurl');
header('Cache-Control: no-cache');
header('X-Accel-Buffering: no');

// Usar curl para obtener el stream
$ch = curl_init($streamUrl);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, false);
curl_setopt($ch, CURLOPT_HEADER, false);
curl_setopt($ch, CURLOPT_WRITEFUNCTION, function($curl, $data) {
    echo $data;
    flush();
    return strlen($data);
});
curl_setopt($ch, CURLOPT_TIMEOUT, 0);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

// Ejecutar la petición
$result = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($result === false || $httpCode !== 200) {
    http_response_code(502);
    echo 'Error: No se pudo obtener el stream';
    exit;
}
?>
