<?php
/**
 * Servicio para extraer la última sesión grabada (upload) de Mixcloud
 * Uso: /mixcloud_recorded_extractor.php?username=djsonic_vlc
 */

header('Content-Type: application/json');
// Los headers CORS los maneja Apache, no los duplicamos aquí

// Manejar preflight OPTIONS
if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Obtener el username de Mixcloud
$username = $_GET['username'] ?? 'djsonic_vlc';

// Sanitizar el username para evitar inyección
$username = preg_replace('/[^a-zA-Z0-9_-]/', '', $username);

try {
    // Usar la API pública de Mixcloud para obtener los cloudcasts (uploads)
    // La API devuelve JSON con información sobre las sesiones grabadas
    $apiUrl = "https://api.mixcloud.com/{$username}/cloudcasts/?limit=1&format=json";
    
    // Hacer la petición a la API de Mixcloud
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $apiUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);
    curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);
    
    if ($httpCode !== 200 || !empty($curlError)) {
        throw new Exception('Error al obtener datos de la API de Mixcloud: ' . ($curlError ?: "HTTP $httpCode"));
    }
    
    $data = json_decode($response, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error parseando respuesta de Mixcloud API');
    }
    
    // Verificar que hay cloudcasts disponibles
    if (empty($data['data']) || !is_array($data['data']) || count($data['data']) === 0) {
        echo json_encode([
            'success' => false,
            'username' => $username,
            'message' => 'No hay sesiones grabadas disponibles',
            'timestamp' => time(),
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }
    
    // Obtener la última sesión grabada
    $latestCloudcast = $data['data'][0];
    
    // La URL de reproducción está en el campo 'url' o 'key'
    $cloudcastKey = $latestCloudcast['key'] ?? '';
    $cloudcastUrl = $latestCloudcast['url'] ?? '';
    $cloudcastName = $latestCloudcast['name'] ?? 'Sesión grabada';
    $cloudcastCreatedTime = $latestCloudcast['created_time'] ?? '';
    
    // Construir la URL completa de Mixcloud para esta sesión
    $fullUrl = !empty($cloudcastUrl) ? $cloudcastUrl : "https://www.mixcloud.com/{$username}/{$cloudcastKey}/";
    
    // Intentar obtener la URL del stream HLS directamente desde la página del cloudcast
    // La URL sigue el patrón: https://audio.mixcloud.stream/secure/hls/...
    $streamUrl = null;
    
    // Obtener el HTML de la página del cloudcast para extraer la URL del stream
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $fullUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);
    curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    
    $html = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode === 200 && !empty($html)) {
        // Buscar la URL del stream HLS en el HTML
        // Patrón mejorado: https://audio.mixcloud.stream/secure/hls/... (puede tener comas, puntos, etc.)
        // El patrón puede ser: /secure/hls/,5/0/3/b/58ef-28ca-4722-b5a0-0a497e7acaaa,.../index.m3u8
        // O también: .../58ef-28ca-4722-b5a0-0a497e7acaaa-192K,.m4a.urlset/index.m3u8
        
        // Primero buscar el patrón específico .urlset/index.m3u8 (más específico)
        if (preg_match('/https?:\/\/audio\.mixcloud\.stream\/secure\/hls\/[^"\'<>\s]+\.urlset\/index\.m3u8/i', $html, $matches)) {
            $streamUrl = $matches[0];
            error_log("Mixcloud Recorded: URL encontrada con patrón .urlset/index.m3u8 (con protocolo): $streamUrl");
        } elseif (preg_match('/audio\.mixcloud\.stream\/secure\/hls\/[^"\'<>\s]+\.urlset\/index\.m3u8/i', $html, $matches)) {
            // Si falta el protocolo, agregarlo
            $streamUrl = 'https://' . $matches[0];
            error_log("Mixcloud Recorded: URL encontrada con patrón .urlset/index.m3u8 (sin protocolo): $streamUrl");
        } elseif (preg_match('/https?:\/\/audio\.mixcloud\.stream\/secure\/hls\/[^"\'<>\s]+(?:\.m3u8|index\.m3u8)/i', $html, $matches)) {
            $streamUrl = $matches[0];
            error_log("Mixcloud Recorded: URL encontrada con patrón .m3u8 (con protocolo): $streamUrl");
        } elseif (preg_match('/audio\.mixcloud\.stream\/secure\/hls\/[^"\'<>\s]+(?:\.m3u8|index\.m3u8)/i', $html, $matches)) {
            // Si falta el protocolo, agregarlo
            $streamUrl = 'https://' . $matches[0];
            error_log("Mixcloud Recorded: URL encontrada con patrón .m3u8 (sin protocolo): $streamUrl");
        } else {
            error_log("Mixcloud Recorded: No se encontró URL en HTML con regex directo, buscando en JSON/JS...");
            // Buscar en el JSON embebido (app-context o similar)
            if (preg_match('/<script[^>]*id=["\']app-context["\'][^>]*>(.*?)<\/script>/is', $html, $scriptMatches)) {
                $appContext = $scriptMatches[1];
                $appContextJson = json_decode($appContext, true);
                if ($appContextJson && isset($appContextJson['cloudcast'])) {
                    // Buscar en diferentes campos posibles
                    $cloudcastData = $appContextJson['cloudcast'];
                    if (isset($cloudcastData['streamUrl'])) {
                        $streamUrl = $cloudcastData['streamUrl'];
                    } elseif (isset($cloudcastData['stream_url'])) {
                        $streamUrl = $cloudcastData['stream_url'];
                    } elseif (isset($cloudcastData['hlsUrl'])) {
                        $streamUrl = $cloudcastData['hlsUrl'];
                    } elseif (isset($cloudcastData['hls_url'])) {
                        $streamUrl = $cloudcastData['hls_url'];
                    } elseif (isset($cloudcastData['stream_info']) && is_array($cloudcastData['stream_info'])) {
                        // Buscar en stream_info
                        $streamInfo = $cloudcastData['stream_info'];
                        if (isset($streamInfo['url'])) {
                            $streamUrl = $streamInfo['url'];
                        } elseif (isset($streamInfo['hls_url'])) {
                            $streamUrl = $streamInfo['hls_url'];
                        }
                    }
                }
            }
            
            // Si aún no se encontró, buscar en variables JavaScript con patrón más flexible
            if (empty($streamUrl)) {
                // Buscar cualquier URL que contenga audio.mixcloud.stream y .urlset/index.m3u8 (patrón más específico primero)
                if (preg_match('/["\']([^"\']*audio\.mixcloud\.stream[^"\']*\.urlset\/index\.m3u8[^"\']*)["\']/i', $html, $matches)) {
                    $streamUrl = $matches[1];
                } elseif (preg_match('/["\']([^"\']*audio\.mixcloud\.stream[^"\']*\.m3u8[^"\']*)["\']/i', $html, $matches)) {
                    $streamUrl = $matches[1];
                } elseif (preg_match('/["\']streamUrl["\']\s*:\s*["\']([^"\']+)["\']/i', $html, $matches)) {
                    $streamUrl = $matches[1];
                } elseif (preg_match('/["\']hlsUrl["\']\s*:\s*["\']([^"\']+)["\']/i', $html, $matches)) {
                    $streamUrl = $matches[1];
                } elseif (preg_match('/audio\.mixcloud\.stream\/secure\/hls\/[^"\'<>\s]+\.urlset\/index\.m3u8/i', $html, $matches)) {
                    // Reconstruir la URL completa con patrón .urlset/index.m3u8
                    $streamUrl = 'https://' . $matches[0];
                } elseif (preg_match('/audio\.mixcloud\.stream\/secure\/hls\/[^"\'<>\s]+(?:\.m3u8|index\.m3u8)/i', $html, $matches)) {
                    // Reconstruir la URL completa
                    $streamUrl = 'https://' . $matches[0];
                }
            }
        }
    } else {
        error_log("Mixcloud Recorded: Error al obtener HTML de la página del cloudcast (HTTP $httpCode)");
    }
    
    // Si aún no se encontró, intentar obtener desde la API de Mixcloud directamente
    // La API puede tener información del stream en el objeto del cloudcast
    if (empty($streamUrl) && isset($latestCloudcast['key'])) {
        // Intentar obtener información detallada del cloudcast desde la API
        $cloudcastApiUrl = "https://api.mixcloud.com/{$username}/{$latestCloudcast['key']}/?format=json";
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $cloudcastApiUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);
        curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        
        $cloudcastResponse = curl_exec($ch);
        $cloudcastHttpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($cloudcastHttpCode === 200 && !empty($cloudcastResponse)) {
            $cloudcastDetail = json_decode($cloudcastResponse, true);
            if ($cloudcastDetail && isset($cloudcastDetail['stream_info'])) {
                $streamInfo = $cloudcastDetail['stream_info'];
                if (isset($streamInfo['url'])) {
                    $streamUrl = $streamInfo['url'];
                } elseif (isset($streamInfo['hls_url'])) {
                    $streamUrl = $streamInfo['hls_url'];
                }
            }
        }
    }
    
    // Si aún no se encontró, usar Playwright como fallback
    if (empty($streamUrl)) {
        error_log("Mixcloud Recorded: HTML scraping no encontró URL, intentando con Playwright...");
        
        $scriptPath = __DIR__ . '/mixcloud_recorded_stream_playwright.js';
        if (file_exists($scriptPath)) {
            // Verificar si Node.js está disponible
            $nodePath = trim(shell_exec('which node 2>/dev/null'));
            
            if (!empty($nodePath)) {
                // Configurar variables de entorno para Playwright
                $env = 'TMPDIR=/media/globalchat/tmp TMP=/media/globalchat/tmp PLAYWRIGHT_BROWSERS_PATH=/media/globalchat/tmp/.playwright ';
                
                // Usar ruta absoluta del script
                $scriptPath = realpath($scriptPath);
                
                // Ejecutar Playwright con timeout extendido
                $command = $env . "timeout 60 " . escapeshellcmd($nodePath . " " . escapeshellarg($scriptPath) . " " . escapeshellarg($fullUrl)) . " 2>&1";
                $rawPlaywrightOutput = @shell_exec($command);
                
                if (!empty($rawPlaywrightOutput)) {
                    // Buscar la última línea que sea JSON válido (similar a mixcloud_stream_extractor.php)
                    $lines = explode("\n", trim($rawPlaywrightOutput));
                    $playwrightOutput = null;
                    for ($i = count($lines) - 1; $i >= 0; $i--) {
                        $line = trim($lines[$i]);
                        if (empty($line)) continue;
                        // Verificar si es JSON válido
                        $test = json_decode($line, true);
                        if (json_last_error() === JSON_ERROR_NONE && isset($test['success'])) {
                            $playwrightOutput = $line;
                            break;
                        }
                    }
                    
                    // Si no encontramos JSON en líneas individuales, intentar con todo el output
                    if ($playwrightOutput === null) {
                        $test = json_decode(trim($rawPlaywrightOutput), true);
                        if (json_last_error() === JSON_ERROR_NONE && isset($test['success'])) {
                            $playwrightOutput = trim($rawPlaywrightOutput);
                        }
                    }
                    
                    if ($playwrightOutput) {
                        $playwrightJson = json_decode($playwrightOutput, true);
                        if (json_last_error() === JSON_ERROR_NONE && isset($playwrightJson['success']) && $playwrightJson['success'] === true && !empty($playwrightJson['stream_url'])) {
                            $streamUrl = $playwrightJson['stream_url'];
                            error_log("Mixcloud Recorded: URL extraída con Playwright: $streamUrl");
                        } else {
                            error_log("Mixcloud Recorded: Playwright no pudo extraer la URL. Output: " . substr($playwrightOutput, 0, 500));
                        }
                    } else {
                        error_log("Mixcloud Recorded: No se pudo parsear JSON de Playwright. Raw: " . substr($rawPlaywrightOutput, 0, 500));
                    }
                } else {
                    error_log("Mixcloud Recorded: Playwright no devolvió output o timeout.");
                }
            } else {
                error_log("Mixcloud Recorded: Node.js no está disponible.");
            }
        } else {
            error_log("Mixcloud Recorded: Script de Playwright no encontrado en: $scriptPath");
        }
    }
    
    if (empty($streamUrl)) {
        error_log("Mixcloud Recorded: No se pudo extraer la URL del stream después de todos los intentos para: $fullUrl");
    } else {
        error_log("Mixcloud Recorded: URL del stream extraída exitosamente: $streamUrl");
    }
    
    echo json_encode([
        'success' => true,
        'username' => $username,
        'cloudcast' => [
            'key' => $cloudcastKey,
            'name' => $cloudcastName,
            'url' => $fullUrl,
            'created_time' => $cloudcastCreatedTime,
            'stream_url' => $streamUrl, // URL del stream de audio si se pudo extraer
        ],
        'timestamp' => time(),
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    
} catch (Exception $e) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'username' => $username,
        'message' => 'Error al obtener sesiones grabadas',
        'timestamp' => time(),
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
