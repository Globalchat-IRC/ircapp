#!/usr/bin/env node
/** Prueba rápida de conexión wss://ceres.globalchat.org:4443 */
const WebSocket = require('ws');
const url = 'wss://ceres.globalchat.org:4443';
console.log('Conectando a', url, '...');
const ws = new WebSocket(url, { rejectUnauthorized: false });
let done = false;
function finish(msg) {
  if (done) return;
  done = true;
  console.log(msg);
  try { ws.terminate(); } catch (_) {}
  process.exit(0);
}
ws.on('open', () => finish('OK: WebSocket conectado a ' + url));
ws.on('message', (d) => console.log('Msg:', String(d).slice(0, 150)));
ws.on('error', (e) => finish('ERROR: ' + e.message));
setTimeout(() => {
  if (!done) finish('Timeout 8s (sin open ni error)');
}, 8000);
