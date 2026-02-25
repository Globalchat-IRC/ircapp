<?php
/**
 * API: Usuarios conectados por país desde UnrealIRCd (JSON-RPC user.list).
 * Devuelve JSON: [ {"code":"ES","name":"Spain","count":7}, ... ] y "no_data" para sin país.
 * Uso: GET https://ceres.globalchat.org/api/countries_unreal.php
 * Requiere en el servidor: conf/unreal_rpc_secret.php con $unreal_rpc_user y $unreal_rpc_pass
 */
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');

$secretFile = __DIR__ . '/unreal_rpc_secret.php';
if (is_file($secretFile)) {
    include $secretFile;
}
$user = isset($unreal_rpc_user) ? $unreal_rpc_user : 'stats';
$pass = isset($unreal_rpc_pass) ? $unreal_rpc_pass : '';

$rpcUrl = 'https://127.0.0.1:8600/api';
$body = json_encode([
    'jsonrpc' => '2.0',
    'method'  => 'user.list',
    'params'  => [ 'object_detail_level' => 2 ],
    'id'      => 1,
]);

$ctx = stream_context_create([
    'http' => [
        'method'  => 'POST',
        'header'  => "Content-Type: application/json\r\nAuthorization: Basic " . base64_encode("$user:$pass") . "\r\n",
        'content' => $body,
        'timeout' => 10,
    ],
    'ssl' => [
        'verify_peer' => false,
        'verify_peer_name' => false,
    ],
]);

$raw = @file_get_contents($rpcUrl, false, $ctx);
if ($raw === false) {
    echo json_encode([ 'error' => 'UnrealIRCd RPC unreachable', 'list' => [] ]);
    exit;
}

$data = json_decode($raw, true);
if (!isset($data['result']['list'])) {
    echo json_encode([ 'error' => 'Invalid RPC response', 'list' => [] ]);
    exit;
}

$list = $data['result']['list'];
$byCountry = [];
$noData = 0;

foreach ($list as $u) {
    $code = isset($u['geoip']['country_code']) ? trim((string)$u['geoip']['country_code']) : '';
    if ($code === '') {
        $noData++;
        continue;
    }
    $code = strtoupper(substr($code, 0, 2));
    if (!isset($byCountry[$code])) {
        $byCountry[$code] = [ 'code' => $code, 'name' => codeToName($code), 'count' => 0 ];
    }
    $byCountry[$code]['count']++;
}

usort($byCountry, function ($a, $b) { return $b['count'] - $a['count']; });
$out = array_values($byCountry);
if ($noData > 0) {
    array_unshift($out, [ 'code' => '', 'name' => 'No data', 'count' => $noData ]);
}

echo json_encode([ 'list' => $out, 'source' => 'unrealircd' ]);

function codeToName($code) {
    static $names = [
        'ES'=>'Spain','AR'=>'Argentina','MX'=>'Mexico','CO'=>'Colombia','CL'=>'Chile','US'=>'United States',
        'BR'=>'Brazil','PE'=>'Peru','EC'=>'Ecuador','VE'=>'Venezuela','FR'=>'France','DE'=>'Germany',
        'IT'=>'Italy','GB'=>'United Kingdom','PT'=>'Portugal','RU'=>'Russia','UA'=>'Ukraine','PL'=>'Poland',
        'NL'=>'Netherlands','BE'=>'Belgium','CA'=>'Canada','AU'=>'Australia','JP'=>'Japan','CN'=>'China',
        'IN'=>'India','UY'=>'Uruguay','PY'=>'Paraguay','BO'=>'Bolivia','CR'=>'Costa Rica','PA'=>'Panama',
        'CU'=>'Cuba','DO'=>'Dominican Republic','GT'=>'Guatemala','HN'=>'Honduras','SV'=>'El Salvador',
        'NI'=>'Nicaragua','PR'=>'Puerto Rico','EC'=>'Ecuador',
    ];
    return isset($names[$code]) ? $names[$code] : $code;
}
