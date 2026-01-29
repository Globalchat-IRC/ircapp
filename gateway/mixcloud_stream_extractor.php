<?php
/**
 * Servicio para extraer la URL del stream HLS de Mixcloud Live
 * Uso: /mixcloud_stream_extractor.php?username=djsonic_vlc
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Manejar preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Obtener el username de Mixcloud
$username = $_GET['username'] ?? 'djsonic_vlc';

// URL de Mixcloud Live
$mixcloudUrl = "https://www.mixcloud.com/live/{$username}/";

try {
    // Configurar contexto para la petición HTTP
    $context = stream_context_create([
        'http' => [
            'method' => 'GET',
            'header' => implode("\r\n", [
                'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language: es-ES,es;q=0.9,en;q=0.8',
                'Accept-Encoding: gzip, deflate',
                'Connection: keep-alive',
                'Upgrade-Insecure-Requests: 1',
            ]),
            'timeout' => 10,
            'follow_location' => true,
            'max_redirects' => 3,
        ],
        'ssl' => [
            'verify_peer' => false,
            'verify_peer_name' => false,
        ]
    ]);

    // Obtener el HTML de la página
    $html = @file_get_contents($mixcloudUrl, false, $context);
    
    if ($html === false) {
        throw new Exception('No se pudo obtener la página de Mixcloud');
    }

    // Buscar la URL del stream HLS (.m3u8)
    // Patrón para encontrar URLs de stream HLS de Mixcloud
    $pattern = '/https?:\/\/[^\s"\'<>]+\.m3u8[^\s"\'<>]*/i';
    
    if (preg_match($pattern, $html, $matches)) {
        $streamUrl = $matches[0];
        
        // Limpiar la URL si tiene caracteres extra
        $streamUrl = preg_replace('/["\'].*$/', '', $streamUrl);
        
        // Verificar que la URL sea válida
        if (filter_var($streamUrl, FILTER_VALIDATE_URL)) {
            // Intentar obtener información adicional del stream
            $streamInfo = getStreamInfo($streamUrl);
            
            echo json_encode([
                'success' => true,
                'stream_url' => $streamUrl,
                'username' => $username,
                'is_live' => true,
                'timestamp' => time(),
                'info' => $streamInfo,
            ]);
        } else {
            throw new Exception('URL del stream no válida');
        }
    } else {
        // No se encontró stream en vivo
        echo json_encode([
            'success' => false,
            'is_live' => false,
            'username' => $username,
            'message' => 'No hay emisión en directo actualmente',
            'timestamp' => time(),
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'username' => $username,
        'timestamp' => time(),
    ]);
}

/**
 * Obtener información adicional del stream
 */
function getStreamInfo($streamUrl) {
    $info = [
        'format' => 'HLS',
        'type' => 'm3u8',
    ];
    
    try {
        // Intentar obtener el master playlist para información de calidad
        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'timeout' => 5,
                'header' => 'User-Agent: Mozilla/5.0',
            ],
            'ssl' => [
                'verify_peer' => false,
                'verify_peer_name' => false,
            ]
        ]);
        
        $playlist = @file_get_contents($streamUrl, false, $context);
        
        if ($playlist !== false) {
            // Buscar información de bitrate/resolución
            if (preg_match('/BANDWIDTH=(\d+)/', $playlist, $matches)) {
                $bandwidth = intval($matches[1]);
                $info['bitrate'] = round($bandwidth / 1000) . ' kbps';
            }
            
            // Verificar si hay múltiples calidades
            $qualities = preg_match_all('/#EXT-X-STREAM-INF/', $playlist);
            if ($qualities > 0) {
                $info['qualities'] = $qualities;
            }
        }
    } catch (Exception $e) {
        // Silencioso, solo devolver info básica
    }
    
    return $info;
}
