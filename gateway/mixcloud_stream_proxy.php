<?php
/**
 * Proxy para streams de Mixcloud HLS
 * Este proxy descarga el stream de Mixcloud, reescribe las URLs para que pasen por el proxy,
 * y lo sirve con los headers CORS correctos
 * Uso: /mixcloud_stream_proxy.php?url=<URL_DEL_STREAM>
 * 
 * Última actualización: 2026-02-04 22:50:00 UTC
 */
// Forzar recarga de opcache
if (function_exists('opcache_reset')) {
    opcache_reset();
}

// Deshabilitar output buffering para debugging
if (ob_get_level()) {
    ob_end_clean();
}

// Los headers CORS los maneja Apache, no los duplicamos aquí

// Manejar preflight OPTIONS
if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Debug: verificar que el script se está ejecutando
@file_put_contents('/tmp/mixcloud_proxy_debug.log', date('Y-m-d H:i:s') . " - Script ejecutado\n", FILE_APPEND);

// Obtener la URL del stream
$streamUrl = $_GET['url'] ?? '';

@file_put_contents('/tmp/mixcloud_proxy_debug.log', date('Y-m-d H:i:s') . " - URL recibida: " . ($streamUrl ?: 'VACIA') . "\n", FILE_APPEND);

if (empty($streamUrl)) {
    http_response_code(400);
    echo 'Error: No se proporcionó la URL del stream';
    exit;
}

// Decodificar la URL si viene codificada
$streamUrl = urldecode($streamUrl);

// Si la URL termina en .m3u (sin el 8), reemplazar directamente por .m3u8
// Mixcloud siempre usa .m3u8, así que esto es seguro
if (preg_match('/\.m3u$/', $streamUrl) && !preg_match('/\.m3u8$/', $streamUrl)) {
    $streamUrl = preg_replace('/\.m3u$/', '.m3u8', $streamUrl);
}

// Debug: log de la URL recibida (después de conversión)
error_log("Mixcloud Proxy: URL procesada: " . $streamUrl);

// Validar que la URL sea de Mixcloud
if (!preg_match('/^https:\/\/live-[a-z0-9-]+\.mixcloud\.com\//', $streamUrl)) {
    http_response_code(400);
    echo 'Error: URL inválida (solo se permiten streams de Mixcloud): ' . htmlspecialchars($streamUrl);
    exit;
}

// Determinar el tipo de contenido
// Detectar tanto .m3u8 como .m3u (algunos streams usan .m3u)
$isM3U8 = preg_match('/\.m3u8?/', $streamUrl);
$isTS = preg_match('/\.ts/', $streamUrl);

// La URL ya fue convertida arriba si era necesario
$actualUrl = $streamUrl;

// Debug: verificar que la URL sea válida antes de hacer curl
error_log("Mixcloud Proxy: Antes de curl - actualUrl=$actualUrl, streamUrl=$streamUrl");

// Obtener el contenido del stream
$ch = curl_init($actualUrl);
if ($ch === false) {
    error_log("Mixcloud Proxy: ERROR - curl_init falló para URL: $actualUrl");
    http_response_code(502);
    echo "Error: No se pudo inicializar cURL para la URL";
    exit;
}

curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HEADER, false);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');

$content = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
$curlErrno = curl_errno($ch);
curl_close($ch);

// Debug logging
error_log("Mixcloud Proxy Debug: URL=$actualUrl, HTTP=$httpCode, Error=$error, Errno=$curlErrno, ContentLength=" . strlen($content ?: ''));

if ($content === false || $httpCode !== 200) {
    // Forzar output inmediato
    if (ob_get_level()) {
        ob_end_clean();
    }
    
    http_response_code(502);
    
    // Construir mensaje de error detallado
    $errorMsg = "Error: No se pudo obtener el stream\n";
    $errorMsg .= "HTTP Code: " . var_export($httpCode, true) . "\n";
    $errorMsg .= "cURL Errno: " . var_export($curlErrno, true) . "\n";
    $errorMsg .= "cURL Error: " . var_export($error, true) . "\n";
    $errorMsg .= "URL Original: " . htmlspecialchars($streamUrl) . "\n";
    $errorMsg .= "URL Intentada: " . htmlspecialchars($actualUrl) . "\n";
    $errorMsg .= "Content: " . var_export($content === false ? 'FALSE' : substr($content, 0, 100), true) . "\n";
    
    // Escribir a error_log y también a un archivo temporal para debugging
    $logMsg = "Mixcloud Proxy Error: HTTP=$httpCode, Errno=$curlErrno, Error=$error, URL=$actualUrl";
    error_log($logMsg);
    @file_put_contents('/tmp/mixcloud_proxy_error.log', date('Y-m-d H:i:s') . " - $logMsg\n", FILE_APPEND);
    
    // Mostrar error en formato texto plano para debugging
    header('Content-Type: text/plain; charset=utf-8');
    echo $errorMsg;
    exit;
}

// Si es un archivo .m3u8 o .m3u, reescribir las URLs para que pasen por el proxy
if ($isM3U8) {
    // Obtener la URL base del archivo actual (usar $actualUrl que puede ser .m3u8)
    $urlParts = parse_url($actualUrl);
    $baseUrl = $urlParts['scheme'] . '://' . $urlParts['host'] . dirname($urlParts['path']);
    
    // URL base del proxy - detectar HTTPS de múltiples formas
    $isHttps = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || 
               (!empty($_SERVER['SERVER_PORT']) && $_SERVER['SERVER_PORT'] == 443) ||
               (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https');
    $scheme = $isHttps ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? $_SERVER['SERVER_NAME'] ?? 'mobilev1.globalchat.org';
    $scriptPath = $_SERVER['SCRIPT_NAME'] ?? '/api/mixcloud_stream_proxy.php';
    $scriptDir = dirname($scriptPath);
    // Asegurar que el directorio no termine con punto
    $scriptDir = rtrim($scriptDir, '.');
    $proxyBase = $scheme . '://' . rtrim($host, '.') . $scriptDir;
    
    // Reescribir las líneas del M3U8
    $lines = explode("\n", $content);
    $rewritten = [];
    
    // Agregar comentario con hora de actualización del proxy
    $updateTime = date('Y-m-d H:i:s T');
    $rewritten[] = "#EXT-X-PROXY-UPDATED: $updateTime";
    
    foreach ($lines as $line) {
        $trimmed = trim($line);
        
        // Si la línea está vacía, mantenerla tal cual
        if (empty($trimmed)) {
            $rewritten[] = $line;
            continue;
        }
        
        // Si es un comentario, verificar si contiene URLs (como #EXT-X-MAP:URI="...")
        if ($trimmed[0] === '#') {
            // Buscar URLs dentro de comentarios (ej: #EXT-X-MAP:URI="init.mp4")
            if (preg_match('/URI=["\']([^"\']+)["\']/', $trimmed, $matches)) {
                $uriValue = $matches[1];
                // Si es una URL relativa, convertirla a absoluta
                if (!preg_match('/^https?:\/\//', $uriValue)) {
                    $absoluteUri = rtrim($baseUrl, '/') . '/' . ltrim($uriValue, '/');
                    $proxyUri = $proxyBase . '/mixcloud_stream_proxy.php?url=' . urlencode($absoluteUri);
                    // Reemplazar en la línea original manteniendo el formato
                    $rewritten[] = preg_replace('/URI=["\'][^"\']+["\']/', 'URI="' . $proxyUri . '"', $line);
                } else {
                    // URL absoluta, reescribir para que pase por el proxy
                    $proxyUri = $proxyBase . '/mixcloud_stream_proxy.php?url=' . urlencode($uriValue);
                    // Reemplazar en la línea original manteniendo el formato
                    $rewritten[] = preg_replace('/URI=["\'][^"\']+["\']/', 'URI="' . $proxyUri . '"', $line);
                }
            } else {
                // Comentario sin URLs, mantenerlo tal cual
                $rewritten[] = $line;
            }
            continue;
        }
        
        // Si la línea parece una URL (relativa o absoluta)
        // Detectar archivos .m3u8, .ts, .m4s, .mp4, etc.
        if (preg_match('/^https?:\/\//', $trimmed)) {
            // URL absoluta - reescribir para que pase por el proxy
            $rewritten[] = $proxyBase . '/mixcloud_stream_proxy.php?url=' . urlencode($trimmed);
        } else if (preg_match('/\.(m3u8?|ts|m4s|mp4)(\?|$)/', $trimmed)) {
            // URL relativa que parece un archivo de stream - convertir a absoluta y luego reescribir
            $absoluteUrl = rtrim($baseUrl, '/') . '/' . ltrim($trimmed, '/');
            $rewritten[] = $proxyBase . '/mixcloud_stream_proxy.php?url=' . urlencode($absoluteUrl);
        } else if (!empty($trimmed) && !preg_match('/^#/', $trimmed)) {
            // Cualquier otra línea que no sea comentario - intentar reescribir si parece una URL
            $absoluteUrl = rtrim($baseUrl, '/') . '/' . ltrim($trimmed, '/');
            $rewritten[] = $proxyBase . '/mixcloud_stream_proxy.php?url=' . urlencode($absoluteUrl);
        } else {
            // Mantener la línea tal cual si no parece una URL
            $rewritten[] = $line;
        }
    }
    
    $content = implode("\n", $rewritten);
    
    // Configurar headers para M3U8
    header('Content-Type: application/vnd.apple.mpegurl');
} else if ($isTS) {
    // Para archivos .ts, servir directamente
    header('Content-Type: video/mp2t');
} else {
    // Por defecto, asumir M3U8
    header('Content-Type: application/vnd.apple.mpegurl');
}

header('Cache-Control: no-cache');
header('X-Accel-Buffering: no');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: *');

echo $content;
?>
