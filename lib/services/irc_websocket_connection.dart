import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'irc_connection_interface.dart';
import '../utils/platform_utils.dart';

/// Puerto WebSocket nativo de UnrealIRCd (modo directo: el IRC ve la IP real del usuario).
const int kUnrealIRCdWebSocketPort = 4443;

/// Sufijo de dominios GlobalChat; todos los nodos tienen WebSocket en 4443.
const String _globalChatHostSuffix = '.globalchat.org';

bool _isGlobalChatHost(String host) {
  return host.toLowerCase().trim().endsWith(_globalChatHostSuffix);
}

/// Implementación de conexión IRC usando WebSocket (web).
/// - Nodos GlobalChat: siempre conexión directa a wss://host:4443; el IRC ve la IP de cada usuario.
/// - Otros servidores: gateway ceres:4444 + handshake JSON.
class IRCWebSocketConnection implements IRCConnection {
  WebSocketChannel? _channel;
  final StreamController<String> _streamController = StreamController<String>.broadcast();
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _handshakeComplete = false;
  String? _targetHost;
  int? _targetPort;
  bool? _targetUseSSL;
  Completer<void>? _handshakeCompleter;
  bool _directMode = false;

  @override
  Future<void> connect(String host, int port, {bool useSSL = true}) async {
    if (!PlatformUtils.mustUseWebSocket) {
      throw UnsupportedError('WebSocket solo está disponible en web. Use Socket TCP.');
    }

    // Limpiar estado previo
    _isConnected = false;
    _handshakeComplete = false;
    _targetHost = null;
    _targetPort = null;
    _targetUseSSL = null;
    _directMode = false;
    
    await _subscription?.cancel();
    _subscription = null;
    
    try {
      await _channel?.sink.close(status.goingAway);
    } catch (e) {
      // Ignorar errores al cerrar canal anterior
    }
    _channel = null;

    try {
      _targetHost = host;
      _targetPort = port;
      _targetUseSSL = useSSL;
      // En web, todos los nodos GlobalChat tienen 4443: conectar al nodo elegido en ese puerto (IP visible).
      _directMode = port == kUnrealIRCdWebSocketPort || _isGlobalChatHost(host);

      if (_directMode) {
        final int wsPort = _isGlobalChatHost(host) ? kUnrealIRCdWebSocketPort : port;
        final String protocol = useSSL ? 'wss' : 'ws';
        final uri = Uri.parse('$protocol://$host:$wsPort');
        _channel = WebSocketChannel.connect(uri);
        _handshakeComplete = true;
        _setupChannelListeners(directMode: true);
        _isConnected = true;
      } else {
        // Modo gateway: ceres:4444 + handshake JSON (servidores no GlobalChat)
        _handshakeCompleter = Completer<void>();
        final bool pageIsHTTPS = Uri.base.scheme == 'https';
        final String protocol = pageIsHTTPS ? 'wss' : 'ws';
        const String gatewayHost = 'ceres.globalchat.org';
        const int gatewayPort = 4444;
        final uri = Uri.parse('$protocol://$gatewayHost:$gatewayPort');
        _channel = WebSocketChannel.connect(uri);
        _setupChannelListeners(directMode: false);
        await Future.delayed(const Duration(milliseconds: 100));
        final handshake = jsonEncode({
          'host': host,
          'port': port,
          'useSSL': useSSL,
        });
        _channel!.sink.add(handshake);
        await _handshakeCompleter!.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            _isConnected = false;
            _handshakeComplete = false;
            throw TimeoutException('Timeout esperando handshake del gateway');
          },
        );
        _isConnected = true;
      }
    } catch (e) {
      _isConnected = false;
      _handshakeComplete = false;
      _directMode = false;
      try {
        await _subscription?.cancel();
        _subscription = null;
      } catch (_) {}
      try {
        await _channel?.sink.close(status.goingAway);
        _channel = null;
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
    await _streamController.close();
  }

  @override
  void send(String data) {
    if (!_isConnected || _channel == null) {
      throw StateError('No conectado al servidor');
    }
    if (!_handshakeComplete) {
      throw StateError('Handshake no completado. No se pueden enviar mensajes IRC.');
    }
    // El gateway añade \r\n
    _channel!.sink.add(data);
  }

  @override
  Stream<String> get stream => _streamController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void close() {
    disconnect();
  }
  
  void _setupChannelListeners({required bool directMode}) {
    _subscription = _channel!.stream.listen(
      (data) {
        try {
          String message;
          if (data is String) {
            message = data;
          } else if (data is List<int>) {
            message = String.fromCharCodes(data);
          } else {
            message = data.toString();
          }
          if (directMode) {
            _streamController.add(message);
            return;
          }
          // Mensajes de control del gateway (JSON)
          if (message.trim().startsWith('{') && message.trim().endsWith('}')) {
            try {
              final jsonData = jsonDecode(message);
              final type = jsonData['type'] as String?;
              if (type == 'handshake_ok') {
                _handshakeComplete = true;
                if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
                  _handshakeCompleter!.complete();
                }
                return;
              } else if (type == 'handshake_error') {
                final errorMsg = jsonData['error'] as String? ?? 'Error desconocido en handshake';
                _handshakeComplete = false;
                if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
                  _handshakeCompleter!.completeError(Exception(errorMsg));
                }
                _streamController.addError(Exception(errorMsg));
                return;
              } else if (type == 'irc_error') {
                final errorMsg = jsonData['error'] as String? ?? 'Error de conexión IRC';
                _streamController.addError(Exception(errorMsg));
                return;
              } else if (type == 'irc_closed') {
                _isConnected = false;
                _streamController.close();
                return;
              }
            } catch (e) {
              // No es JSON de control, tratar como IRC
            }
          }
          _streamController.add(message);
        } catch (e) {
          _streamController.addError(e);
        }
      },
      onError: (error) {
        _streamController.addError(error);
        if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
          _handshakeCompleter!.completeError(error);
        }
      },
      onDone: () {
        _isConnected = false;
        _handshakeComplete = false;
        if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
          _handshakeCompleter!.completeError(Exception('Conexión WebSocket cerrada'));
        }
        _streamController.close();
      },
      cancelOnError: false,
    );
  }
}
