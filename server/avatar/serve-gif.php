<?php
/**
 * Sirve el avatar GIF por hash. Busca en avatars/default/ y en subcarpetas (p. ej. avatars/40/).
 * Si no existe, devuelve 1x1 GIF transparente para que la URL siempre sea imagen válida.
 */
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Cache-Control: public, max-age=300');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$hash = isset($_GET['hash']) ? trim((string) $_GET['hash']) : '';
if (!preg_match('/^[a-f0-9]{32}$/i', $hash)) {
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['ok' => false, 'error' => 'Hash inválido']);
    exit;
}

$avatarsDir = __DIR__ . '/avatars';
$pathsToTry = [$avatarsDir . '/default/' . $hash . '.gif'];
foreach (glob($avatarsDir . '/*', GLOB_ONLYDIR) ?: [] as $subdir) {
    $pathsToTry[] = $subdir . '/' . $hash . '.gif';
}
foreach ($pathsToTry as $file) {
    if (is_file($file) && is_readable($file)) {
        header('Content-Type: image/gif');
        header('Content-Length: ' . filesize($file));
        readfile($file);
        exit;
    }
}

// Sin archivo: 1x1 GIF transparente para que la URL siempre devuelva imagen
header('Content-Type: image/gif');
header('Cache-Control: public, max-age=60');
echo base64_decode('R0lGODlhAQABAIABAP///wAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==');
