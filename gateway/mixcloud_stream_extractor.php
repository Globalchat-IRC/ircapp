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

// Sanitizar el username para evitar inyección de comandos
$username = preg_replace('/[^a-zA-Z0-9_-]/', '', $username);

try {
    // Llamar al script bash que SÍ funciona
    $scriptPath = __DIR__ . '/mixcloud_stream_extractor.sh';
    
    if (!file_exists($scriptPath)) {
        throw new Exception('Script no encontrado');
    }
    
    // Ejecutar el script bash
    $command = escapeshellcmd("bash $scriptPath " . escapeshellarg($username));
    $output = shell_exec($command);
    
    if ($output === null) {
        throw new Exception('Error ejecutando el script');
    }
    
    // El script ya devuelve JSON, solo lo pasamos
    echo $output;
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'username' => $username,
        'timestamp' => time(),
    ]);
}
