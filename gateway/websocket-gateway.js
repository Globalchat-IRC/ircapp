#!/usr/bin/env node

/**
 * WebSocket Gateway para IRC
 * 
 * Este servidor actúa como proxy entre clientes WebSocket (web) y servidores IRC (TCP).
 * Permite que clientes web se conecten a cualquier servidor IRC del cluster GlobalChat
 * a través de un único punto de entrada WebSocket.
 * 
 * Para que el servidor IRC vea la IP real del usuario (no la de ceres), configurar
 * WEBIRC_PASSWORD y un bloque webirc {} en UnrealIRCd. Ver docs WebIRC.
 * 
 * Uso:
 *   node websocket-gateway.js
 * 
 * Configuración:
 *   - Puerto WebSocket: 4444 (configurable con PORT)
 *   - WEBIRC_PASSWORD: si está definido, se envía WEBIRC al IRC con la IP real del cliente
 *   - WEBIRC_GATEWAY: nombre del gateway (default: ceres-webirc)
 *   - Timeout de conexión: 10 segundos
 */

const WebSocket = require('ws');
const net = require('net');
const tls = require('tls');
const crypto = require('crypto');

const PORT = process.env.PORT || 4444;
const CONNECTION_TIMEOUT = 10000; // 10 segundos
const WEBIRC_PASSWORD = process.env.WEBIRC_PASSWORD || '';
const WEBIRC_GATEWAY = process.env.WEBIRC_GATEWAY || 'ceres-webirc';

// Mapa de conexiones activas: WebSocket ID -> { ws, tcp, host, port }
const activeConnections = new Map();

// Servidores IRC permitidos (whitelist para seguridad)
const ALLOWED_SERVERS = [
  'ceres.globalchat.org',
  'apolo.globalchat.org',
  // 'creta.globalchat.org', // Comentado temporalmente - servidor con problemas
  'caliope.globalchat.org',
  'localhost',
  '127.0.0.1',
];

// Puertos IRC permitidos
const ALLOWED_PORTS = [6667, 6697];

/**
 * Generar ID único para conexión
 */
function generateConnectionId() {
  return crypto.randomBytes(8).toString('hex');
}

/**
 * Obtener la IP real del cliente (si hay proxy, usar X-Forwarded-For).
 * Normaliza IPv6-mapped IPv4 (::ffff:1.2.3.4 -> 1.2.3.4).
 */
function getClientIP(req) {
  const forwarded = req.headers['x-forwarded-for'];
  const raw = (typeof forwarded === 'string' ? forwarded.split(',')[0].trim() : null) || req.socket.remoteAddress || '';
  if (raw.startsWith('::ffff:')) return raw.slice(7);
  return raw;
}

/**
 * Validar servidor y puerto
 */
function validateServer(host, port) {
  // Verificar servidor permitido
  const isAllowed = ALLOWED_SERVERS.some(allowed => 
    host.toLowerCase().includes(allowed.toLowerCase())
  );
  
  if (!isAllowed) {
    return { valid: false, error: `Servidor no permitido: ${host}` };
  }
  
  // Verificar puerto permitido
  if (!ALLOWED_PORTS.includes(port)) {
    return { valid: false, error: `Puerto no permitido: ${port}` };
  }
  
  return { valid: true };
}

/**
 * Crear conexión TCP/TLS al servidor IRC
 */
function createTCPConnection(host, port, useSSL, connectionId) {
  return new Promise((resolve, reject) => {
    let socket;
    let resolved = false;
    
    // Timeout de conexión
    const timeout = setTimeout(() => {
      if (!resolved) {
        resolved = true;
        if (socket) {
          socket.destroy();
        }
        reject(new Error(`Timeout conectando a ${host}:${port}`));
      }
    }, CONNECTION_TIMEOUT);
    
    const onConnect = () => {
      if (!resolved) {
        resolved = true;
        clearTimeout(timeout);
        console.log(`[${connectionId}] ✅ ${useSSL ? 'TLS' : 'TCP'} conectado a ${host}:${port}`);
        resolve(socket);
      }
    };
    
    const onError = (error) => {
      if (!resolved) {
        resolved = true;
        clearTimeout(timeout);
        console.error(`[${connectionId}] ❌ Error ${useSSL ? 'TLS' : 'TCP'}: ${error.message}`);
        reject(error);
      }
    };
    
    if (useSSL) {
      // Usar TLS para conexiones SSL
      socket = tls.connect({
        host: host,
        port: port,
        rejectUnauthorized: false, // Aceptar certificados autofirmados
      }, onConnect);
      
      socket.on('error', onError);
      socket.on('secureConnect', () => {
        // La conexión TLS está establecida
        if (!resolved) {
          onConnect();
        }
      });
    } else {
      // Usar TCP normal para conexiones no SSL
      socket = net.createConnection(port, host);
      socket.on('connect', onConnect);
      socket.on('error', onError);
    }
  });
}

/**
 * Manejar mensaje inicial del cliente (handshake)
 * Formato esperado: JSON con { host, port, useSSL }
 */
function parseHandshake(message) {
  try {
    const data = JSON.parse(message);
    if (!data.host || !data.port) {
      throw new Error('Faltan host o port');
    }
    return {
      host: data.host,
      port: parseInt(data.port),
      useSSL: data.useSSL === true || data.useSSL === 'true',
    };
  } catch (error) {
    // Si no es JSON, asumir formato legacy: "host:port" o solo host (puerto por defecto 6667)
    const parts = message.trim().split(':');
    const host = parts[0];
    const port = parts[1] ? parseInt(parts[1]) : 6667;
    return { host, port, useSSL: false };
  }
}

/**
 * Servidor WebSocket
 */
const wss = new WebSocket.Server({ 
  port: PORT,
  perMessageDeflate: false, // Deshabilitar compresión para mejor rendimiento
});

console.log(`🚀 WebSocket Gateway iniciado en puerto ${PORT}`);
console.log(`📡 Servidores permitidos: ${ALLOWED_SERVERS.join(', ')}`);
console.log(`🔌 Puertos permitidos: ${ALLOWED_PORTS.join(', ')}`);
if (WEBIRC_PASSWORD) {
  console.log(`📍 WEBIRC: activado (IP real del cliente se enviará al IRC)`);
} else {
  console.log(`⚠️  WEBIRC: desactivado → todos los usuarios verán IP de ceres. Para activar: crear webirc.env con WEBIRC_PASSWORD y configurar webirc {} en UnrealIRCd.`);
}

wss.on('connection', (ws, req) => {
  const connectionId = generateConnectionId();
  const clientIP = getClientIP(req);
  
  console.log(`[${connectionId}] 🔵 Nueva conexión WebSocket desde ${clientIP}`);
  
  let tcpSocket = null;
  let handshakeReceived = false;
  let handshakeData = null;
  
  // Buffer para mensajes recibidos antes del handshake
  const messageQueue = [];
  
  /**
   * Limpiar conexión
   */
  function cleanup() {
    if (tcpSocket) {
      tcpSocket.destroy();
      tcpSocket = null;
    }
    activeConnections.delete(connectionId);
    console.log(`[${connectionId}] 🧹 Conexión cerrada`);
  }
  
  /**
   * Enviar mensaje al cliente WebSocket
   */
  function sendToClient(data) {
    if (ws.readyState === WebSocket.OPEN) {
      try {
        ws.send(data);
      } catch (error) {
        console.error(`[${connectionId}] Error enviando a cliente: ${error.message}`);
      }
    }
  }
  
  /**
   * Enviar mensaje al servidor IRC
   */
  function sendToIRC(data) {
    if (tcpSocket && !tcpSocket.destroyed) {
      try {
        tcpSocket.write(data);
      } catch (error) {
        console.error(`[${connectionId}] Error enviando a IRC: ${error.message}`);
      }
    }
  }
  
  /**
   * Procesar handshake y establecer conexión TCP
   */
  async function processHandshake(message) {
    if (handshakeReceived) {
      // Handshake ya procesado, enviar mensaje directamente a IRC
      sendToIRC(message + '\r\n');
      return;
    }
    
    try {
      handshakeData = parseHandshake(message);
      console.log(`[${connectionId}] 📋 Handshake: ${handshakeData.host}:${handshakeData.port} (SSL: ${handshakeData.useSSL})`);
      
      // Validar servidor y puerto
      const validation = validateServer(handshakeData.host, handshakeData.port);
      if (!validation.valid) {
        sendToClient(JSON.stringify({ 
          error: validation.error,
          type: 'handshake_error'
        }));
        ws.close(1008, validation.error);
        return;
      }
      
      // Crear conexión TCP
      tcpSocket = await createTCPConnection(
        handshakeData.host,
        handshakeData.port,
        handshakeData.useSSL,
        connectionId
      );
      
      handshakeReceived = true;
      activeConnections.set(connectionId, {
        ws,
        tcp: tcpSocket,
        host: handshakeData.host,
        port: handshakeData.port,
      });
      
      // WEBIRC: primera línea al servidor IRC para que vea la IP real del usuario (no la de ceres)
      if (WEBIRC_PASSWORD) {
        const hostname = clientIP; // sin reverse DNS, usar IP como hostname
        const webircLine = `WEBIRC ${WEBIRC_PASSWORD} ${WEBIRC_GATEWAY} ${hostname} ${clientIP}\r\n`;
        tcpSocket.write(webircLine);
        console.log(`[${connectionId}] 📍 WEBIRC enviado: IP real ${clientIP}`);
      }
      
      // Enviar confirmación al cliente
      sendToClient(JSON.stringify({
        type: 'handshake_ok',
        host: handshakeData.host,
        port: handshakeData.port,
      }));
      
      // Procesar mensajes en cola
      while (messageQueue.length > 0) {
        const queuedMessage = messageQueue.shift();
        sendToIRC(queuedMessage + '\r\n');
      }
      
      // Configurar listeners TCP
      tcpSocket.on('data', (data) => {
        // Reenviar datos del servidor IRC al cliente WebSocket
        sendToClient(data.toString());
      });
      
      tcpSocket.on('error', (error) => {
        console.error(`[${connectionId}] ❌ Error TCP: ${error.message}`);
        sendToClient(JSON.stringify({
          type: 'irc_error',
          error: error.message,
        }));
        cleanup();
        ws.close(1011, 'Error de conexión IRC');
      });
      
      tcpSocket.on('close', () => {
        console.log(`[${connectionId}] ⛔ TCP desconectado`);
        sendToClient(JSON.stringify({
          type: 'irc_closed',
        }));
        cleanup();
        ws.close(1000, 'Conexión IRC cerrada');
      });
      
      tcpSocket.on('end', () => {
        console.log(`[${connectionId}] 🔚 TCP finalizado por servidor`);
        cleanup();
        ws.close(1000, 'Servidor IRC cerró conexión');
      });
      
    } catch (error) {
      console.error(`[${connectionId}] ❌ Error en handshake: ${error.message}`);
      sendToClient(JSON.stringify({
        type: 'handshake_error',
        error: error.message,
      }));
      ws.close(1011, `Error: ${error.message}`);
    }
  }
  
  // Manejar mensajes del cliente WebSocket
  ws.on('message', async (message) => {
    const messageStr = message.toString();
    
    // Primer mensaje es el handshake
    if (!handshakeReceived) {
      await processHandshake(messageStr);
    } else {
      // Mensajes subsecuentes se envían directamente al servidor IRC
      sendToIRC(messageStr + '\r\n');
    }
  });
  
  // Manejar cierre de conexión WebSocket
  ws.on('close', (code, reason) => {
    console.log(`[${connectionId}] 🔴 WebSocket cerrado (${code}): ${reason}`);
    cleanup();
  });
  
  ws.on('error', (error) => {
    console.error(`[${connectionId}] ❌ Error WebSocket: ${error.message}`);
    cleanup();
  });
  
  // Timeout: si no se recibe handshake en 5 segundos, cerrar
  const handshakeTimeout = setTimeout(() => {
    if (!handshakeReceived) {
      console.log(`[${connectionId}] ⏱️ Timeout esperando handshake`);
      sendToClient(JSON.stringify({
        type: 'handshake_error',
        error: 'Timeout esperando handshake',
      }));
      ws.close(1008, 'Timeout esperando handshake');
    }
  }, 5000);
  
  ws.on('close', () => {
    clearTimeout(handshakeTimeout);
  });
});

// Manejo de señales para cierre limpio
process.on('SIGTERM', () => {
  console.log('🛑 Recibida señal SIGTERM, cerrando servidor...');
  wss.close(() => {
    console.log('✅ Servidor cerrado');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 Recibida señal SIGINT, cerrando servidor...');
  wss.close(() => {
    console.log('✅ Servidor cerrado');
    process.exit(0);
  });
});

