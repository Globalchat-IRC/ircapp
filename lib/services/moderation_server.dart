import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../models/user_role.dart';
import 'video_conference_service.dart';

/// Servidor HTTP para panel de moderación
class ModerationServer {
  HttpServer? _server;
  final VideoConferenceService _videoService;
  final int port;
  
  // Tokens de autenticación (nick -> token)
  final Map<String, String> _authTokens = {};
  
  // WebSocket clientes conectados
  final List<WebSocketChannel> _wsClients = [];
  
  // Stream de eventos para clientes WebSocket
  final StreamController<Map<String, dynamic>> _eventsController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  ModerationServer(this._videoService, {this.port = 8765});
  
  /// Iniciar servidor
  Future<void> start() async {
    if (_server != null) {
      print('⚠️ [MOD-SERVER] Servidor ya está corriendo en puerto $port');
      return;
    }
    
    try {
      final router = _createRouter();
      
      final handler = const shelf.Pipeline()
          .addMiddleware(_corsMiddleware())
          .addMiddleware(shelf.logRequests())
          .addHandler(router.call);
      
      _server = await io.serve(handler, 'localhost', port);
      
      print('✅ [MOD-SERVER] Panel de moderación disponible en:');
      print('   http://localhost:$port/mod');
      print('   Autenticación: http://localhost:$port/auth');
      
      // Escuchar cambios de video para notificar clientes
      _videoService.onUsersVideoStatusChanged.listen((status) {
        _broadcastToClients({
          'type': 'video_status_update',
          'data': status.map((nick, s) => MapEntry(nick, {
            'nick': s.nick,
            'type': s.type.name,
            'conferenceId': s.conferenceId,
            'joinedAt': s.joinedAt.toIso8601String(),
          })),
        });
      });
      
    } catch (e) {
      print('❌ [MOD-SERVER] Error al iniciar servidor: $e');
      rethrow;
    }
  }
  
  /// Detener servidor
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      print('🛑 [MOD-SERVER] Servidor detenido');
    }
    
    // Cerrar todas las conexiones WebSocket
    for (var client in _wsClients) {
      await client.sink.close();
    }
    _wsClients.clear();
  }
  
  /// Crear router con endpoints
  Router _createRouter() {
    final router = Router();
    
    // === AUTENTICACIÓN ===
    
    // POST /auth - Autenticar moderador
    router.post('/auth', (shelf.Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);
        final nick = data['nick'] as String?;
        final password = data['password'] as String?;
        
        if (nick == null || password == null) {
          return shelf.Response.forbidden(
            jsonEncode({'error': 'Nick y password requeridos'}),
            headers: _jsonHeaders(),
          );
        }
        
        // TODO: Verificar password contra base de datos
        // Por ahora, aceptamos cualquier IRCop
        
        // Generar token
        final token = const Uuid().v4();
        _authTokens[nick] = token;
        
        print('🔑 [MOD-SERVER] Token generado para $nick');
        
        return shelf.Response.ok(
          jsonEncode({
            'token': token,
            'nick': nick,
            'expiresIn': 86400, // 24 horas
          }),
          headers: _jsonHeaders(),
        );
        
      } catch (e) {
        return shelf.Response.internalServerError(
          body: jsonEncode({'error': 'Error al autenticar: $e'}),
          headers: _jsonHeaders(),
        );
      }
    });
    
    // === PANEL DE MODERACIÓN ===
    
    // GET /mod - Dashboard HTML
    router.get('/mod', (shelf.Request request) {
      return shelf.Response.ok(
        _getDashboardHtml(),
        headers: {'Content-Type': 'text/html'},
      );
    });
    
    // GET /api/conferences - Listar conferencias activas
    router.get('/api/conferences', _authMiddleware((shelf.Request request) {
      final conferences = _videoService.activeConferences.map((conf) {
        return {
          'id': conf.id,
          'channel': conf.channel,
          'roomName': conf.roomName,
          'participants': conf.participants,
          'startTime': conf.startTime.toIso8601String(),
          'isModerated': conf.isModerated,
          'moderatorNick': conf.moderatorNick,
        };
      }).toList();
      
      return shelf.Response.ok(
        jsonEncode({'conferences': conferences}),
        headers: _jsonHeaders(),
      );
    }));
    
    // GET /api/users-in-video - Usuarios en videoconferencia
    router.get('/api/users-in-video', _authMiddleware((shelf.Request request) {
      final users = _videoService.usersInVideo.map((nick, status) {
        return MapEntry(nick, {
          'nick': status.nick,
          'type': status.type.name,
          'emoji': status.emoji,
          'conferenceId': status.conferenceId,
          'joinedAt': status.joinedAt.toIso8601String(),
        });
      });
      
      return shelf.Response.ok(
        jsonEncode({'users': users}),
        headers: _jsonHeaders(),
      );
    }));
    
    // GET /api/reports - Reportes pendientes
    router.get('/api/reports', _authMiddleware((shelf.Request request) {
      final reports = _videoService.pendingReports.map((report) {
        return {
          'id': report.id,
          'reporterNick': report.reporterNick,
          'reportedNick': report.reportedNick,
          'conferenceId': report.conferenceId,
          'type': report.type.name,
          'description': report.description,
          'timestamp': report.timestamp.toIso8601String(),
          'status': report.status.name,
        };
      }).toList();
      
      return shelf.Response.ok(
        jsonEncode({'reports': reports}),
        headers: _jsonHeaders(),
      );
    }));
    
    // === ACCIONES DE MODERACIÓN ===
    
    // POST /api/kick - Expulsar usuario
    router.post('/api/kick', _authMiddleware((shelf.Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);
        final nick = data['nick'] as String?;
        final conferenceId = data['conferenceId'] as String?;
        final reason = data['reason'] as String? ?? 'Incumplimiento de normas';
        
        if (nick == null || conferenceId == null) {
          return shelf.Response.badRequest(
            body: jsonEncode({'error': 'Nick y conferenceId requeridos'}),
            headers: _jsonHeaders(),
          );
        }
        
        // TODO: Implementar lógica de expulsión real con Jitsi API
        print('🚪 [MOD-SERVER] Expulsando a $nick de $conferenceId. Razón: $reason');
        
        // Registrar acción
        _videoService.logModerationAction(
          moderatorNick: _getModerator(request),
          targetNick: nick,
          conferenceId: conferenceId,
          action: 'kick',
          reason: reason,
        );
        
        // Notificar a clientes WebSocket
        _broadcastToClients({
          'type': 'user_kicked',
          'nick': nick,
          'conferenceId': conferenceId,
          'reason': reason,
        });
        
        return shelf.Response.ok(
          jsonEncode({'success': true, 'message': 'Usuario expulsado'}),
          headers: _jsonHeaders(),
        );
        
      } catch (e) {
        return shelf.Response.internalServerError(
          body: jsonEncode({'error': 'Error al expulsar: $e'}),
          headers: _jsonHeaders(),
        );
      }
    }));
    
    // POST /api/ban - Banear usuario
    router.post('/api/ban', _authMiddleware((shelf.Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);
        final nick = data['nick'] as String?;
        final reason = data['reason'] as String? ?? 'Incumplimiento grave';
        final permanent = data['permanent'] as bool? ?? false;
        
        if (nick == null) {
          return shelf.Response.badRequest(
            body: jsonEncode({'error': 'Nick requerido'}),
            headers: _jsonHeaders(),
          );
        }
        
        // TODO: Implementar ban en base de datos
        print('🚫 [MOD-SERVER] Baneando a $nick (${permanent ? "permanente" : "temporal"}). Razón: $reason');
        
        // Registrar acción
        _videoService.logModerationAction(
          moderatorNick: _getModerator(request),
          targetNick: nick,
          conferenceId: 'N/A',
          action: permanent ? 'ban_permanent' : 'ban_temporal',
          reason: reason,
        );
        
        // Notificar a clientes WebSocket
        _broadcastToClients({
          'type': 'user_banned',
          'nick': nick,
          'permanent': permanent,
          'reason': reason,
        });
        
        return shelf.Response.ok(
          jsonEncode({'success': true, 'message': 'Usuario baneado'}),
          headers: _jsonHeaders(),
        );
        
      } catch (e) {
        return shelf.Response.internalServerError(
          body: jsonEncode({'error': 'Error al banear: $e'}),
          headers: _jsonHeaders(),
        );
      }
    }));
    
    // === WEBSOCKET ===
    
    // GET /ws - WebSocket para actualizaciones en tiempo real
    router.get('/ws', webSocketHandler((WebSocketChannel webSocket, String? protocol) {
      print('🔌 [MOD-SERVER] Cliente WebSocket conectado (protocol: $protocol)');
      _wsClients.add(webSocket);
      
      // Enviar estado inicial
      webSocket.sink.add(jsonEncode({
        'type': 'connected',
        'message': 'Conectado al servidor de moderación',
      }));
      
      // Escuchar mensajes del cliente
      webSocket.stream.listen(
        (message) {
          print('📨 [MOD-SERVER] Mensaje recibido: $message');
        },
        onDone: () {
          print('🔌 [MOD-SERVER] Cliente WebSocket desconectado');
          _wsClients.remove(webSocket);
        },
        onError: (error) {
          print('❌ [MOD-SERVER] Error WebSocket: $error');
          _wsClients.remove(webSocket);
        },
      );
    }));
    
    return router;
  }
  
  /// Middleware de CORS
  shelf.Middleware _corsMiddleware() {
    return shelf.createMiddleware(
      responseHandler: (shelf.Response response) {
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
        });
      },
    );
  }
  
  /// Middleware de autenticación
  shelf.Handler _authMiddleware(shelf.Handler handler) {
    return (shelf.Request request) {
      final authHeader = request.headers['authorization'];
      
      if (authHeader == null) {
        return shelf.Response.forbidden(
          jsonEncode({'error': 'Token de autenticación requerido'}),
          headers: _jsonHeaders(),
        );
      }
      
      final token = authHeader.replaceFirst('Bearer ', '');
      
      // Verificar token
      if (!_authTokens.containsValue(token)) {
        return shelf.Response.forbidden(
          jsonEncode({'error': 'Token inválido o expirado'}),
          headers: _jsonHeaders(),
        );
      }
      
      return handler(request);
    };
  }
  
  /// Obtener nick del moderador desde el request
  String _getModerator(shelf.Request request) {
    final authHeader = request.headers['authorization'];
    if (authHeader == null) return 'unknown';
    
    final token = authHeader.replaceFirst('Bearer ', '');
    return _authTokens.entries
        .firstWhere((e) => e.value == token, orElse: () => const MapEntry('unknown', ''))
        .key;
  }
  
  /// Headers JSON
  Map<String, String> _jsonHeaders() {
    return {'Content-Type': 'application/json'};
  }
  
  /// Broadcast a todos los clientes WebSocket
  void _broadcastToClients(Map<String, dynamic> message) {
    final json = jsonEncode(message);
    for (var client in _wsClients) {
      try {
        client.sink.add(json);
      } catch (e) {
        print('❌ [MOD-SERVER] Error al enviar mensaje: $e');
      }
    }
  }
  
  /// HTML del dashboard de moderación
  String _getDashboardHtml() {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Panel de Moderación - GlobalChat IRC</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: #fff;
            min-height: 100vh;
        }
        
        .header {
            background: rgba(0, 0, 0, 0.3);
            padding: 20px;
            border-bottom: 2px solid rgba(255, 255, 255, 0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .header h1 {
            font-size: 24px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .header .status {
            display: flex;
            gap: 20px;
            align-items: center;
        }
        
        .status-badge {
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: bold;
        }
        
        .status-badge.online {
            background: #4caf50;
        }
        
        .status-badge.offline {
            background: #f44336;
        }
        
        .container {
            padding: 20px;
            max-width: 1800px;
            margin: 0 auto;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: rgba(255, 255, 255, 0.1);
            padding: 20px;
            border-radius: 12px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }
        
        .stat-card h3 {
            font-size: 14px;
            color: rgba(255, 255, 255, 0.7);
            margin-bottom: 10px;
        }
        
        .stat-card .value {
            font-size: 32px;
            font-weight: bold;
            color: #fff;
        }
        
        .section {
            background: rgba(255, 255, 255, 0.1);
            padding: 20px;
            border-radius: 12px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            margin-bottom: 20px;
        }
        
        .section h2 {
            font-size: 20px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .cameras-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 15px;
        }
        
        .camera-card {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 8px;
            overflow: hidden;
            border: 2px solid transparent;
            transition: all 0.3s;
        }
        
        .camera-card:hover {
            border-color: #4caf50;
            transform: translateY(-2px);
        }
        
        .camera-card.reported {
            border-color: #ff9800;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { border-color: #ff9800; }
            50% { border-color: #f44336; }
        }
        
        .camera-video {
            width: 100%;
            height: 200px;
            background: #000;
            display: flex;
            align-items: center;
            justify-content: center;
            position: relative;
        }
        
        .camera-placeholder {
            font-size: 48px;
        }
        
        .camera-info {
            padding: 12px;
        }
        
        .camera-nick {
            font-weight: bold;
            font-size: 16px;
            margin-bottom: 5px;
        }
        
        .camera-details {
            font-size: 12px;
            color: rgba(255, 255, 255, 0.7);
            margin-bottom: 10px;
        }
        
        .camera-actions {
            display: flex;
            gap: 8px;
        }
        
        .btn {
            padding: 8px 16px;
            border: none;
            border-radius: 6px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s;
            font-size: 12px;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
        }
        
        .btn-kick {
            background: #ff9800;
            color: #fff;
        }
        
        .btn-ban {
            background: #f44336;
            color: #fff;
        }
        
        .btn-mute {
            background: #9c27b0;
            color: #fff;
        }
        
        .reports-list {
            max-height: 400px;
            overflow-y: auto;
        }
        
        .report-item {
            background: rgba(255, 255, 255, 0.05);
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 10px;
            border-left: 4px solid #ff9800;
        }
        
        .report-item.critical {
            border-left-color: #f44336;
        }
        
        .report-header {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
        }
        
        .report-nick {
            font-weight: bold;
            color: #ff9800;
        }
        
        .report-time {
            color: rgba(255, 255, 255, 0.5);
            font-size: 12px;
        }
        
        .report-description {
            margin-bottom: 10px;
            font-size: 14px;
        }
        
        .auth-modal {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.8);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 1000;
        }
        
        .auth-box {
            background: linear-gradient(135deg, #2a5298 0%, #1e3c72 100%);
            padding: 40px;
            border-radius: 12px;
            width: 400px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5);
        }
        
        .auth-box h2 {
            margin-bottom: 20px;
            text-align: center;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: bold;
        }
        
        .form-group input {
            width: 100%;
            padding: 12px;
            border: none;
            border-radius: 6px;
            font-size: 14px;
            background: rgba(255, 255, 255, 0.1);
            color: #fff;
            border: 2px solid transparent;
            transition: all 0.3s;
        }
        
        .form-group input:focus {
            outline: none;
            border-color: #4caf50;
            background: rgba(255, 255, 255, 0.15);
        }
        
        .btn-login {
            width: 100%;
            padding: 14px;
            background: #4caf50;
            color: #fff;
            border: none;
            border-radius: 6px;
            font-weight: bold;
            font-size: 16px;
            cursor: pointer;
            transition: all 0.3s;
        }
        
        .btn-login:hover {
            background: #45a049;
            transform: translateY(-2px);
        }
        
        .logs-container {
            max-height: 300px;
            overflow-y: auto;
            background: rgba(0, 0, 0, 0.3);
            padding: 15px;
            border-radius: 8px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
        }
        
        .log-entry {
            margin-bottom: 5px;
            padding: 5px;
            border-radius: 4px;
        }
        
        .log-entry.info {
            color: #4caf50;
        }
        
        .log-entry.warning {
            color: #ff9800;
        }
        
        .log-entry.error {
            color: #f44336;
        }
    </style>
</head>
<body>
    <div id="authModal" class="auth-modal">
        <div class="auth-box">
            <h2>🔐 Autenticación de Moderador</h2>
            <div class="form-group">
                <label>Nick de IRCop:</label>
                <input type="text" id="authNick" placeholder="Tu nick">
            </div>
            <div class="form-group">
                <label>Password:</label>
                <input type="password" id="authPassword" placeholder="Tu password">
            </div>
            <button class="btn-login" onclick="authenticate()">Entrar</button>
        </div>
    </div>

    <div class="header">
        <h1>
            <span>👮</span>
            Panel de Moderación - GlobalChat IRC
        </h1>
        <div class="status">
            <span id="moderatorNick" style="opacity: 0.7;"></span>
            <div id="wsStatus" class="status-badge offline">⚫ Desconectado</div>
        </div>
    </div>

    <div class="container">
        <!-- Estadísticas -->
        <div class="stats">
            <div class="stat-card">
                <h3>🎥 Conferencias Activas</h3>
                <div class="value" id="statConferences">0</div>
            </div>
            <div class="stat-card">
                <h3>👥 Usuarios en Video</h3>
                <div class="value" id="statUsers">0</div>
            </div>
            <div class="stat-card">
                <h3>⚠️ Reportes Pendientes</h3>
                <div class="value" id="statReports">0</div>
            </div>
            <div class="stat-card">
                <h3>📊 Total Acciones</h3>
                <div class="value" id="statActions">0</div>
            </div>
        </div>

        <!-- Cámaras en Vivo -->
        <div class="section">
            <h2>📹 Cámaras en Tiempo Real</h2>
            <div id="camerasGrid" class="cameras-grid"></div>
        </div>

        <!-- Reportes -->
        <div class="section">
            <h2>⚠️ Reportes Pendientes</h2>
            <div id="reportsList" class="reports-list"></div>
        </div>

        <!-- Logs -->
        <div class="section">
            <h2>📋 Logs de Moderación</h2>
            <div id="logsContainer" class="logs-container"></div>
        </div>
    </div>

    <script>
        let authToken = null;
        let ws = null;
        let moderatorNick = null;

        // Autenticación
        async function authenticate() {
            const nick = document.getElementById('authNick').value;
            const password = document.getElementById('authPassword').value;

            try {
                const response = await fetch('http://localhost:8765/auth', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ nick, password }),
                });

                const data = await response.json();

                if (response.ok) {
                    authToken = data.token;
                    moderatorNick = data.nick;
                    document.getElementById('authModal').style.display = 'none';
                    document.getElementById('moderatorNick').textContent = '👮 ' + moderatorNick;
                    addLog('✅ Autenticado como ' + moderatorNick, 'info');
                    connectWebSocket();
                    loadData();
                } else {
                    alert('Error: ' + data.error);
                }
            } catch (error) {
                alert('Error de conexión: ' + error);
            }
        }

        // WebSocket
        function connectWebSocket() {
            ws = new WebSocket('ws://localhost:8765/ws');

            ws.onopen = () => {
                document.getElementById('wsStatus').className = 'status-badge online';
                document.getElementById('wsStatus').textContent = '🟢 Conectado';
                addLog('🔌 Conectado al servidor WebSocket', 'info');
            };

            ws.onmessage = (event) => {
                const message = JSON.parse(event.data);
                handleWebSocketMessage(message);
            };

            ws.onclose = () => {
                document.getElementById('wsStatus').className = 'status-badge offline';
                document.getElementById('wsStatus').textContent = '⚫ Desconectado';
                addLog('🔌 Desconectado del servidor WebSocket', 'warning');
                // Reconectar después de 5 segundos
                setTimeout(connectWebSocket, 5000);
            };

            ws.onerror = (error) => {
                addLog('❌ Error WebSocket: ' + error, 'error');
            };
        }

        // Manejar mensajes WebSocket
        function handleWebSocketMessage(message) {
            switch (message.type) {
                case 'connected':
                    addLog('✅ ' + message.message, 'info');
                    break;
                case 'video_status_update':
                    loadCameras();
                    break;
                case 'user_kicked':
                    addLog('🚪 ' + message.nick + ' expulsado de ' + message.conferenceId, 'warning');
                    loadData();
                    break;
                case 'user_banned':
                    addLog('🚫 ' + message.nick + ' baneado (' + (message.permanent ? 'permanente' : 'temporal') + ')', 'error');
                    loadData();
                    break;
            }
        }

        // Cargar datos
        async function loadData() {
            await Promise.all([
                loadCameras(),
                loadReports(),
            ]);
        }

        // Cargar cámaras
        async function loadCameras() {
            try {
                const response = await fetch('http://localhost:8765/api/users-in-video', {
                    headers: { 'Authorization': 'Bearer ' + authToken },
                });

                const data = await response.json();
                const users = Object.values(data.users);

                document.getElementById('statUsers').textContent = users.length;

                const grid = document.getElementById('camerasGrid');
                grid.innerHTML = '';

                users.forEach(user => {
                    const card = document.createElement('div');
                    card.className = 'camera-card';
                    card.innerHTML = \`
                        <div class="camera-video">
                            <div class="camera-placeholder">\${user.emoji}</div>
                        </div>
                        <div class="camera-info">
                            <div class="camera-nick">\${user.nick}</div>
                            <div class="camera-details">
                                Tipo: \${user.type === 'channel' ? '🎥 Canal' : '📹 Privado'}<br>
                                Conferencia: \${user.conferenceId}<br>
                                Conectado: \${new Date(user.joinedAt).toLocaleTimeString()}
                            </div>
                            <div class="camera-actions">
                                <button class="btn btn-kick" onclick="kickUser('\${user.nick}', '\${user.conferenceId}')">Expulsar</button>
                                <button class="btn btn-ban" onclick="banUser('\${user.nick}')">Banear</button>
                                <button class="btn btn-mute" onclick="muteUser('\${user.nick}')">Silenciar</button>
                            </div>
                        </div>
                    \`;
                    grid.appendChild(card);
                });

            } catch (error) {
                addLog('❌ Error al cargar cámaras: ' + error, 'error');
            }
        }

        // Cargar reportes
        async function loadReports() {
            try {
                const response = await fetch('http://localhost:8765/api/reports', {
                    headers: { 'Authorization': 'Bearer ' + authToken },
                });

                const data = await response.json();
                const reports = data.reports;

                document.getElementById('statReports').textContent = reports.length;

                const list = document.getElementById('reportsList');
                list.innerHTML = '';

                reports.forEach(report => {
                    const item = document.createElement('div');
                    item.className = 'report-item' + (report.type === 'nudity' ? ' critical' : '');
                    item.innerHTML = \`
                        <div class="report-header">
                            <span class="report-nick">⚠️ \${report.reportedNick}</span>
                            <span class="report-time">\${new Date(report.timestamp).toLocaleString()}</span>
                        </div>
                        <div class="report-description">
                            <strong>Tipo:</strong> \${report.type}<br>
                            <strong>Reportado por:</strong> \${report.reporterNick}<br>
                            <strong>Descripción:</strong> \${report.description || 'N/A'}
                        </div>
                        <div class="camera-actions">
                            <button class="btn btn-kick" onclick="kickUser('\${report.reportedNick}', '\${report.conferenceId}')">Expulsar</button>
                            <button class="btn btn-ban" onclick="banUser('\${report.reportedNick}')">Banear</button>
                        </div>
                    \`;
                    list.appendChild(item);
                });

            } catch (error) {
                addLog('❌ Error al cargar reportes: ' + error, 'error');
            }
        }

        // Acciones de moderación
        async function kickUser(nick, conferenceId) {
            if (!confirm(\`¿Expulsar a \${nick}?\`)) return;

            const reason = prompt('Razón de expulsión:', 'Incumplimiento de normas');
            if (!reason) return;

            try {
                const response = await fetch('http://localhost:8765/api/kick', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + authToken,
                    },
                    body: JSON.stringify({ nick, conferenceId, reason }),
                });

                const data = await response.json();

                if (response.ok) {
                    addLog(\`✅ \${nick} expulsado exitosamente\`, 'info');
                    loadData();
                } else {
                    alert('Error: ' + data.error);
                }
            } catch (error) {
                alert('Error: ' + error);
            }
        }

        async function banUser(nick) {
            if (!confirm(\`¿Banear a \${nick}?\`)) return;

            const reason = prompt('Razón del ban:', 'Incumplimiento grave');
            if (!reason) return;

            const permanent = confirm('¿Ban permanente?');

            try {
                const response = await fetch('http://localhost:8765/api/ban', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'Authorization': 'Bearer ' + authToken,
                    },
                    body: JSON.stringify({ nick, reason, permanent }),
                });

                const data = await response.json();

                if (response.ok) {
                    addLog(\`✅ \${nick} baneado exitosamente\`, 'info');
                    loadData();
                } else {
                    alert('Error: ' + data.error);
                }
            } catch (error) {
                alert('Error: ' + error);
            }
        }

        function muteUser(nick) {
            addLog(\`🔇 Silenciar a \${nick} (no implementado aún)\`, 'warning');
        }

        // Agregar log
        function addLog(message, type = 'info') {
            const container = document.getElementById('logsContainer');
            const entry = document.createElement('div');
            entry.className = 'log-entry ' + type;
            entry.textContent = \`[\${new Date().toLocaleTimeString()}] \${message}\`;
            container.insertBefore(entry, container.firstChild);

            // Limitar a 100 logs
            while (container.children.length > 100) {
                container.removeChild(container.lastChild);
            }
        }

        // Actualizar periódicamente
        setInterval(loadData, 10000); // Cada 10 segundos
    </script>
</body>
</html>
    ''';
  }
}

