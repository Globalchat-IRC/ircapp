<?php
/**
 * Servicio para extraer la URL del stream HLS de Mixcloud Live
 * Uso: /mixcloud_stream_extractor.php?username=djsonic_vlc
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

// Sanitizar el username para evitar inyección de comandos
$username = preg_replace('/[^a-zA-Z0-9_-]/', '', $username);

try {
    // Intentar primero con Playwright (más confiable), luego Puppeteer, luego bash
    $playwrightScriptPath = __DIR__ . '/mixcloud_stream_extractor_playwright.js';
    $nodeScriptPath = __DIR__ . '/mixcloud_stream_extractor.js';
    $bashScriptPath = __DIR__ . '/mixcloud_stream_extractor.sh';
    
    $output = null;
    $usedMethod = 'bash';
    
    // Verificar si Node.js está disponible
    $nodePath = trim(shell_exec('which node 2>/dev/null'));
    
    // Intentar primero con Playwright (más confiable)
    if (!empty($nodePath) && file_exists($playwrightScriptPath)) {
        // Aumentar el timeout de PHP para permitir que Playwright termine
        $oldTimeout = ini_get('max_execution_time');
        set_time_limit(120); // 2 minutos
        ignore_user_abort(true); // Continuar aunque el cliente se desconecte
        
        // Usar ruta absoluta del script para evitar problemas
        $playwrightScriptPath = realpath($playwrightScriptPath);
        
        // Verificar si Playwright está instalado
        $playwrightCheck = shell_exec("cd " . escapeshellarg(__DIR__) . " && $nodePath -e \"try { require('playwright'); console.log('OK'); } catch(e) { console.log('NOT_INSTALLED'); }\" 2>&1");
        $playwrightCheck = trim($playwrightCheck);
        
        if ($playwrightCheck === 'NOT_INSTALLED') {
            error_log("Mixcloud Stream Extractor: Playwright no está instalado, usando fallback");
            $output = null; // Forzar fallback
        } else {
            // Usar shell_exec con ruta absoluta y variables de entorno explícitas
            // Capturar tanto stdout como stderr para debugging
            $env = 'TMPDIR=/media/globalchat/tmp TMP=/media/globalchat/tmp PLAYWRIGHT_BROWSERS_PATH=/media/globalchat/tmp/.playwright ';
            $command = $env . "timeout 90 " . escapeshellcmd($nodePath . " " . escapeshellarg($playwrightScriptPath) . " " . escapeshellarg($username)) . " 2>&1";
            error_log("Mixcloud Stream Extractor: Ejecutando Playwright con comando: " . substr($command, 0, 200));
            $rawOutput = @shell_exec($command);
            
            $usedMethod = 'playwright';
            
            // Extraer solo el JSON del output (puede haber mensajes de debug antes)
            if (!empty($rawOutput)) {
                error_log("Mixcloud Stream Extractor: Playwright devolvió output (longitud: " . strlen($rawOutput) . ")");
                // Buscar la última línea que sea JSON válido
                $lines = explode("\n", trim($rawOutput));
                $output = null;
                for ($i = count($lines) - 1; $i >= 0; $i--) {
                    $line = trim($lines[$i]);
                    if (empty($line)) continue;
                    // Verificar si es JSON válido
                    $test = json_decode($line, true);
                    if (json_last_error() === JSON_ERROR_NONE && isset($test['success'])) {
                        $output = $line;
                        error_log("Mixcloud Stream Extractor: JSON válido encontrado en línea " . ($i + 1));
                        break;
                    }
                }
                // Si no encontramos JSON en líneas individuales, intentar con todo el output
                if ($output === null) {
                    $test = json_decode(trim($rawOutput), true);
                    if (json_last_error() === JSON_ERROR_NONE && isset($test['success'])) {
                        $output = trim($rawOutput);
                        error_log("Mixcloud Stream Extractor: JSON válido encontrado en output completo");
                    } else {
                        error_log("Mixcloud Stream Extractor: No se pudo parsear JSON. Error: " . json_last_error_msg() . ". Output: " . substr($rawOutput, 0, 500));
                    }
                }
                
                // Si tenemos output válido con success:true, usarlo directamente y salir
                if (!empty($output)) {
                    $decoded = json_decode($output, true);
                    if (json_last_error() === JSON_ERROR_NONE && isset($decoded['success']) && $decoded['success'] === true) {
                        error_log("Mixcloud Stream Extractor: Playwright encontró stream en vivo, devolviendo resultado");
                        // El output es válido, devolverlo directamente
                        echo $output;
                        exit;
                    } else {
                        error_log("Mixcloud Stream Extractor: Playwright devolvió success=false o sin success, usando fallback");
                        $output = null; // Forzar fallback
                    }
                } else {
                    error_log("Mixcloud Stream Extractor: Playwright no devolvió JSON válido, usando fallback");
                    $output = null; // Forzar fallback
                }
            } else {
                error_log("Mixcloud Stream Extractor: Playwright no devolvió output, usando fallback");
                $output = null; // Forzar fallback
            }
        }
        
        // Restaurar timeout original
        if ($oldTimeout !== false) {
            set_time_limit($oldTimeout);
        }
    } else {
        if (empty($nodePath)) {
            error_log("Mixcloud Stream Extractor: Node.js no está disponible");
        }
        if (!file_exists($playwrightScriptPath)) {
            error_log("Mixcloud Stream Extractor: Script de Playwright no encontrado: " . $playwrightScriptPath);
        }
    }
    
    // Si Playwright falló o no se ejecutó, intentar con Puppeteer
    if (($output === null || trim($output) === '' || (strpos($output, '"success":false') !== false && strpos($output, 'is_live":false') !== false)) 
        && !empty($nodePath) && file_exists($nodeScriptPath)) {
        // Redirigir stderr a /dev/null y capturar solo stdout (JSON)
        $command = escapeshellcmd($nodePath . " " . escapeshellarg($nodeScriptPath) . " " . escapeshellarg($username)) . " 2>/dev/null";
        $output = shell_exec($command);
        $usedMethod = 'puppeteer';
    }
    
    // Si Node.js falló o no está disponible, usar el script bash
    if ($output === null || trim($output) === '' || (strpos($output, '"success":false') !== false && strpos($output, 'is_live":false') !== false)) {
        if (file_exists($bashScriptPath)) {
            // Verificar que el script sea ejecutable
            if (!is_executable($bashScriptPath)) {
                chmod($bashScriptPath, 0755);
    }
    
    // Ejecutar el script bash con captura de errores
            $command = escapeshellcmd("bash " . escapeshellarg($bashScriptPath) . " " . escapeshellarg($username)) . " 2>&1";
    $output = shell_exec($command);
            $usedMethod = 'bash';
        } else {
            throw new Exception('Ningún script disponible (ni Node.js ni bash)');
        }
    }
    
    if ($output === null || trim($output) === '') {
        throw new Exception('Error ejecutando el script: sin salida (método: ' . $usedMethod . ')');
    }
    
    // Verificar que la salida sea JSON válido
    $decoded = json_decode($output, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        // Si no es JSON válido, podría ser un error del script
        throw new Exception('El script devolvió datos inválidos: ' . substr($output, 0, 100) . ' (método: ' . $usedMethod . ')');
    }
    
    // Agregar información de debugging sobre el método usado
    $decoded = json_decode($output, true);
    if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
        $decoded['debug_method'] = $usedMethod;
        
        // Si no hay stream en vivo (success: false o is_live: false), intentar obtener sesión grabada como fallback
        $noLiveStream = false;
        if (isset($decoded['success']) && $decoded['success'] === false) {
            // Si success es false, asumir que no hay stream en vivo
            $noLiveStream = true;
        } elseif (isset($decoded['success']) && $decoded['success'] === true && isset($decoded['is_live']) && $decoded['is_live'] === false) {
            // Si success es true pero is_live es false, no hay stream en vivo
            $noLiveStream = true;
        } elseif (!isset($decoded['is_live']) || (isset($decoded['is_live']) && $decoded['is_live'] === false)) {
            // Si is_live no está definido o es false, no hay stream en vivo
            $noLiveStream = true;
        }
        
        if ($noLiveStream) {
            // No hay stream en vivo, intentar obtener sesión grabada
            error_log("Mixcloud Stream Extractor: No hay stream en vivo, intentando obtener sesión grabada...");
            
            // Ejecutar el script de sesiones grabadas con timeout de 30 segundos
            $recordedExtractorPath = __DIR__ . '/mixcloud_recorded_extractor.php';
            if (file_exists($recordedExtractorPath)) {
                // Configurar timeout de 30 segundos
                $oldTimeout = ini_get('max_execution_time');
                set_time_limit(30);
                
                // Simular $_GET para el script
                $originalGet = $_GET;
                $_GET['username'] = $username;
                
                // Ejecutar con timeout usando shell_exec
                try {
                    $phpPath = trim(shell_exec('which php 2>/dev/null')) ?: 'php';
                    $command = "timeout 30 " . escapeshellcmd($phpPath) . " " . escapeshellarg($recordedExtractorPath) . " 2>&1";
                    $recordedResponse = shell_exec($command);
                    
                    // Restaurar $_GET original
                    $_GET = $originalGet;
                    
                    if (!empty($recordedResponse)) {
                        $recordedJson = json_decode(trim($recordedResponse), true);
                        if (json_last_error() === JSON_ERROR_NONE && isset($recordedJson['success']) && $recordedJson['success'] === true) {
                            $cloudcast = $recordedJson['cloudcast'] ?? null;
                            if ($cloudcast && !empty($cloudcast['stream_url'])) {
                                // Usar la sesión grabada
                                $decoded['success'] = true;
                                $decoded['is_live'] = false;
                                $decoded['stream_url'] = $cloudcast['stream_url'];
                                $decoded['message'] = 'Reproduciendo sesión grabada: ' . ($cloudcast['name'] ?? 'Sesión grabada');
                                $decoded['cloudcast'] = $cloudcast;
                                error_log("Mixcloud Stream Extractor: Sesión grabada encontrada: " . $cloudcast['stream_url']);
                            } else {
                                error_log("Mixcloud Stream Extractor: Sesión grabada encontrada pero sin URL de stream");
                            }
                        } else {
                            error_log("Mixcloud Stream Extractor: No se pudo obtener sesión grabada desde el extractor");
                        }
                    } else {
                        error_log("Mixcloud Stream Extractor: No se obtuvo respuesta del extractor de sesiones grabadas");
                    }
                } catch (Exception $e) {
                    $_GET = $originalGet;
                    error_log("Mixcloud Stream Extractor: Error al obtener sesión grabada: " . $e->getMessage());
                }
                
                // Restaurar timeout original
                if ($oldTimeout !== false) {
                    set_time_limit($oldTimeout);
                }
                
                // Si después de intentar obtener la sesión grabada no hay URL válida, usar fallback por defecto
                if (empty($decoded['stream_url']) || !isset($decoded['stream_url'])) {
                    // URL de fallback para sesión grabada por defecto
                    $fallbackStreamUrl = 'https://audio.mixcloud.stream/secure/hls/5/0/3/b/58ef-28ca-4722-b5a0-0a497e7acaaa-192K.m4a/streamindex-a1.m3u8';
                    $decoded['success'] = true;
                    $decoded['is_live'] = false;
                    $decoded['stream_url'] = $fallbackStreamUrl;
                    $decoded['message'] = 'Reproduciendo sesión grabada por defecto';
                    error_log("Mixcloud Stream Extractor: Usando URL de fallback por defecto: " . $fallbackStreamUrl);
                }
            } else {
                // Si el script de sesiones grabadas no existe, usar fallback por defecto directamente
                error_log("Mixcloud Stream Extractor: Script de sesiones grabadas no encontrado, usando fallback por defecto");
                $fallbackStreamUrl = 'https://audio.mixcloud.stream/secure/hls/5/0/3/b/58ef-28ca-4722-b5a0-0a497e7acaaa-192K.m4a/streamindex-a1.m3u8';
                $decoded['success'] = true;
                $decoded['is_live'] = false;
                $decoded['stream_url'] = $fallbackStreamUrl;
                $decoded['message'] = 'Reproduciendo sesión grabada por defecto';
                error_log("Mixcloud Stream Extractor: Usando URL de fallback por defecto: " . $fallbackStreamUrl);
            }
            
            // Verificación final: si después de todo el proceso no hay stream_url, usar fallback
            if (empty($decoded['stream_url']) || !isset($decoded['stream_url'])) {
                $fallbackStreamUrl = 'https://audio.mixcloud.stream/secure/hls/5/0/3/b/58ef-28ca-4722-b5a0-0a497e7acaaa-192K.m4a/streamindex-a1.m3u8';
                $decoded['success'] = true;
                $decoded['is_live'] = false;
                $decoded['stream_url'] = $fallbackStreamUrl;
                $decoded['message'] = 'Reproduciendo sesión grabada por defecto';
                error_log("Mixcloud Stream Extractor: Fallback final aplicado - URL: " . $fallbackStreamUrl);
            }
        }
        
        $output = json_encode($decoded, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
    
    // El script ya devuelve JSON, solo lo pasamos
    echo $output;
    
} catch (Exception $e) {
    // Asegurar que siempre devolvemos JSON, incluso en caso de error
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'is_live' => false,
        'error' => $e->getMessage(),
        'username' => $username,
        'message' => 'Error al obtener información del stream',
        'timestamp' => time(),
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
