<?php
/**
 * Sirve el avatar PNG por hash con CORS para que se vea desde mobilev1.globalchat.org (u otro origen).
 * GET ?hash=xxx (32 hex) → devuelve avatars/default/xxx.png con Content-Type: image/png y CORS.
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
$pathsToTry = [$avatarsDir . '/default/' . $hash . '.png'];
foreach (glob($avatarsDir . '/*', GLOB_ONLYDIR) ?: [] as $subdir) {
    $pathsToTry[] = $subdir . '/' . $hash . '.png';
}
foreach ($pathsToTry as $file) {
    if (is_file($file) && is_readable($file)) {
        header('Content-Type: image/png');
        header('Content-Length: ' . filesize($file));
        readfile($file);
        exit;
    }
}

http_response_code(404);
header('Content-Type: application/json');
echo json_encode(['ok' => false, 'error' => 'No encontrado']);
