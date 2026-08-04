<?php
/**
 * AI Proxy — proxy seguro para llamadas a Groq API.
 * 
 * La API key nunca se expone al cliente. El frontend envía la pregunta y este
 * endpoint la reenvía a Groq con la key del servidor.
 * 
 * POST application/json { "question": "..." }
 * → { "answer": "...", "source": "groq" }
 * 
 * GET  → { "available": true }
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// Configuración
$API_KEY  = getenv('GROQ_API_KEY') ?: '';
$API_URL  = 'https://api.groq.com/openai/v1/chat/completions';
$MODEL    = 'openai/gpt-oss-120b';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    echo json_encode(['available' => !empty($API_KEY)]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

if (empty($API_KEY)) {
    http_response_code(503);
    echo json_encode(['error' => 'AI service not configured (no GROQ_API_KEY)']);
    exit;
}

$body = json_decode(file_get_contents('php://input'), true);
$question = trim($body['question'] ?? '');

if (empty($question)) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing "question" field']);
    exit;
}

// System prompt para el asistente de GlobalChat
$systemPrompt = <<<PROMPT
Eres un asistente experto en IRC y en la red GlobalChat.
REGLAS DE RESPUESTA:
- Responde SIEMPRE en español.
- Sé breve por defecto (3-6 líneas). Solo escribe una guía larga si el usuario pide "detallado/paso a paso".
- NO inventes nombres de bots, canales o URLs. Si no estás seguro, dilo y sugiere preguntar en #globalchat.
- Para "tickets/soporte", usa EXCLUSIVAMENTE la información de TICKETS/CAU.

Sobre GlobalChat:
CONEXIÓN: irc.globalchat.net:6667 (texto) o 6697 (SSL)
SERVICIOS: NickServ, ChanServ, MemoServ, BotServ, HostServ
Comandos: REGISTER, IDENTIFY, SET PASSWORD, INFO, OP, SEND, READ, SET host, ASSIGN
BOTS: RadioBot_GC, Ayudante, Idle, SeenAllBot, Stats, YoutubeBot
CANALES: #globalchat, #QualiaRadio
TICKETS: http://soporte.globalchat.org/index.php?a=add
ROLES: @ operador, % halfop, + voice
PROMPT;

// Llamada a Groq
$payload = [
    'model'    => $MODEL,
    'messages' => [
        ['role' => 'system', 'content' => $systemPrompt],
        ['role' => 'user',   'content' => $question],
    ],
    'temperature'          => 0.3,
    'max_completion_tokens' => 600,
    'top_p'                => 1,
    'stream'               => false,
];

$ch = curl_init($API_URL);
curl_setopt_array($ch, [
    CURLOPT_POST           => true,
    CURLOPT_POSTFIELDS     => json_encode($payload),
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT        => 30,
    CURLOPT_HTTPHEADER     => [
        'Content-Type: application/json',
        'Authorization: Bearer ' . $API_KEY,
    ],
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$err      = curl_error($ch);
curl_close($ch);

if ($err) {
    http_response_code(502);
    echo json_encode(['error' => "Upstream error: $err"]);
    exit;
}

if ($httpCode !== 200) {
    http_response_code(502);
    echo json_encode(['error' => "Upstream returned $httpCode", 'body' => $response]);
    exit;
}

$data = json_decode($response, true);
$answer = $data['choices'][0]['message']['content'] ?? null;

if ($answer === null) {
    http_response_code(502);
    echo json_encode(['error' => 'No answer from model', 'raw' => $data]);
    exit;
}

echo json_encode(['answer' => trim($answer), 'source' => 'groq']);
