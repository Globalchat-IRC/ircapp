<?php
/**
 * Piloto Qualia Radio — proxy de SOLO LECTURA.
 * Consulta la API pública de AzuraCast sin conectar como emisor IceCast.
 *
 * Uso: GET /api/qualia_radio_status.php
 * Respuesta: JSON normalizado para la app web #QualiaRadio.
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Cache-Control: public, max-age=8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

const STATION_SHORTCODE = 'qualia_radio';
const AZURA_BASE = 'https://azura.streamingradio.online';
const CACHE_FILE = '/tmp/qualia_radio_status_cache.json';
const CACHE_TTL_SECONDS = 8;

function respond(int $code, array $payload): void
{
    http_response_code($code);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function fetchJson(string $url): ?array
{
    $ch = curl_init($url);
    if ($ch === false) {
        return null;
    }

    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 10,
        CURLOPT_HTTPHEADER => [
            'Accept: application/json',
            'User-Agent: GlobalChat-QualiaRadio-Pilot/1.0',
        ],
    ]);

    $body = curl_exec($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($body === false || $status !== 200) {
        return null;
    }

    $decoded = json_decode($body, true);
    return is_array($decoded) ? $decoded : null;
}

function readCache(): ?array
{
    if (!is_readable(CACHE_FILE)) {
        return null;
    }

    $raw = @file_get_contents(CACHE_FILE);
    if ($raw === false) {
        return null;
    }

    $cached = json_decode($raw, true);
    if (!is_array($cached) || !isset($cached['fetched_at'])) {
        return null;
    }

    if (time() - (int) $cached['fetched_at'] > CACHE_TTL_SECONDS) {
        return null;
    }

    return $cached;
}

function writeCache(array $payload): void
{
    @file_put_contents(CACHE_FILE, json_encode($payload));
}

function formatDuration(?int $seconds): ?string
{
    if ($seconds === null || $seconds < 0) {
        return null;
    }

    $minutes = intdiv($seconds, 60);
    $secs = $seconds % 60;
    return sprintf('%d:%02d', $minutes, $secs);
}

function buildStatus(): array
{
    $nowPlayingUrl = AZURA_BASE . '/api/nowplaying/' . STATION_SHORTCODE;
    $stationUrl = AZURA_BASE . '/api/station/' . STATION_SHORTCODE;

    $nowPlaying = fetchJson($nowPlayingUrl);
    $stationMeta = fetchJson($stationUrl);

    if ($nowPlaying === null) {
        return [
            'ok' => false,
            'error' => 'No se pudo consultar AzuraCast (now playing).',
            'fetched_at' => time(),
        ];
    }

    $station = is_array($nowPlaying['station'] ?? null) ? $nowPlaying['station'] : [];
    $listeners = is_array($nowPlaying['listeners'] ?? null) ? $nowPlaying['listeners'] : [];
    $live = is_array($nowPlaying['live'] ?? null) ? $nowPlaying['live'] : [];
    $current = is_array($nowPlaying['now_playing'] ?? null) ? $nowPlaying['now_playing'] : [];
    $next = is_array($nowPlaying['playing_next'] ?? null) ? $nowPlaying['playing_next'] : [];
    $currentSong = is_array($current['song'] ?? null) ? $current['song'] : [];
    $nextSong = is_array($next['song'] ?? null) ? $next['song'] : [];

    $artist = trim((string) ($currentSong['artist'] ?? ''));
    $title = trim((string) ($currentSong['title'] ?? ''));
    $text = trim((string) ($currentSong['text'] ?? ''));
    $displayTitle = $text !== ''
        ? $text
        : ($artist !== '' && $title !== ''
            ? $artist . ' - ' . $title
            : ($title !== '' ? $title : 'Sin información'));

    $nextArtist = trim((string) ($nextSong['artist'] ?? ''));
    $nextTitle = trim((string) ($nextSong['title'] ?? ''));
    $nextText = trim((string) ($nextSong['text'] ?? ''));
    $nextDisplay = $nextText !== ''
        ? $nextText
        : ($nextArtist !== '' && $nextTitle !== ''
            ? $nextArtist . ' - ' . $nextTitle
            : ($nextTitle !== '' ? $nextTitle : null));

    $mounts = is_array($station['mounts'] ?? null) ? $station['mounts'] : [];
    $defaultMount = null;
    foreach ($mounts as $mount) {
        if (!is_array($mount)) {
            continue;
        }
        if (($mount['is_default'] ?? false) === true) {
            $defaultMount = $mount;
            break;
        }
    }
    if ($defaultMount === null && !empty($mounts) && is_array($mounts[0])) {
        $defaultMount = $mounts[0];
    }

    $isLive = ($live['is_live'] ?? false) === true;
    $streamerName = trim((string) ($live['streamer_name'] ?? ''));
    $elapsed = isset($current['elapsed']) ? (int) $current['elapsed'] : null;
    $remaining = isset($current['remaining']) ? (int) $current['remaining'] : null;
    $duration = isset($current['duration']) ? (int) $current['duration'] : null;

    return [
        'ok' => true,
        'source' => 'azuracast_public_api',
        'read_only' => true,
        'fetched_at' => time(),
        'channel' => '#QualiaRadio',
        'dj_room' => '#QualiaRadio-dj',
        'station' => [
            'name' => (string) ($station['name'] ?? 'Qualia Radio'),
            'shortcode' => (string) ($station['shortcode'] ?? STATION_SHORTCODE),
            'description' => (string) ($station['description'] ?? ''),
            'listen_url' => (string) ($station['listen_url'] ?? ''),
            'public_player_url' => (string) ($station['public_player_url'] ?? ''),
            'requests_enabled' => (bool) ($station['requests_enabled'] ?? false),
            'frontend' => (string) ($station['frontend'] ?? ''),
            'backend' => (string) ($station['backend'] ?? ''),
            'timezone' => (string) ($station['timezone'] ?? ''),
        ],
        'live' => [
            'is_live' => $isLive,
            'streamer_name' => $streamerName,
            'mode' => $isLive ? 'live' : 'autodj',
            'label' => $isLive
                ? ($streamerName !== '' ? 'En directo: ' . $streamerName : 'En directo')
                : 'Música automatizada',
        ],
        'now_playing' => [
            'display' => $displayTitle,
            'artist' => $artist,
            'title' => $title,
            'album' => (string) ($currentSong['album'] ?? ''),
            'genre' => (string) ($currentSong['genre'] ?? ''),
            'art_url' => (string) ($currentSong['art'] ?? ''),
            'playlist' => (string) ($current['playlist'] ?? ''),
            'is_request' => (bool) ($current['is_request'] ?? false),
            'elapsed_seconds' => $elapsed,
            'remaining_seconds' => $remaining,
            'duration_seconds' => $duration,
            'elapsed_label' => formatDuration($elapsed),
            'remaining_label' => formatDuration($remaining),
            'duration_label' => formatDuration($duration),
        ],
        'playing_next' => $nextDisplay !== null ? [
            'display' => $nextDisplay,
            'artist' => $nextArtist,
            'title' => $nextTitle,
            'playlist' => (string) ($next['playlist'] ?? ''),
            'is_request' => (bool) ($next['is_request'] ?? false),
        ] : null,
        'listeners' => [
            'current' => (int) ($listeners['current'] ?? 0),
            'unique' => (int) ($listeners['unique'] ?? 0),
            'total' => (int) ($listeners['total'] ?? 0),
        ],
        'stream' => [
            'bitrate' => isset($defaultMount['bitrate']) ? (int) $defaultMount['bitrate'] : null,
            'format' => (string) ($defaultMount['format'] ?? ''),
            'mount' => (string) ($defaultMount['path'] ?? ''),
            'url' => (string) ($defaultMount['url'] ?? ''),
        ],
        'orion' => [
            'commands' => [
                ['command' => '.s', 'description' => 'Canción sonando'],
                ['command' => '.pedir', 'description' => 'Pedir una canción'],
                ['command' => '.dj lista', 'description' => 'Ver listado de peticiones'],
                ['command' => '.dj activar', 'description' => 'Activar/desactivar peticiones'],
                ['command' => '.dj limpiar', 'description' => 'Borrar lista de peticiones'],
            ],
            'note' => 'Los comandos se envían al bot Orion en #QualiaRadio. Este backend no los ejecuta.',
        ],
        'meta' => [
            'station_api_ok' => $stationMeta !== null,
            'hls_url' => (string) ($station['hls_url'] ?? ''),
        ],
    ];
}

$cached = readCache();
if ($cached !== null) {
    respond(200, $cached);
}

$status = buildStatus();
if (($status['ok'] ?? false) === true) {
    writeCache($status);
    respond(200, $status);
}

respond(502, $status);
