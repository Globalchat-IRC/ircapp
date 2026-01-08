import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'irc_connection_interface.dart';
import '../utils/platform_utils.dart';

/// Implementación de conexión IRC usando WebSocket (web)
/// Usa un gateway en ceres.globalchat.org:4443 que enruta a cualquier servidor IRC
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
    
    // Cancelar suscripción anterior si existe
    await _subscription?.cancel();
    _subscription = null;
    
    // Cerrar canal anterior si existe
    try {
      await _channel?.sink.close(status.goingAway);
    } catch (e) {
      // Ignorar errores al cerrar canal anterior
    }
    _channel = null;

    try {
      // Guardar información del servidor destino
      _targetHost = host;
      _targetPort = port;
      _targetUseSSL = useSSL;
      
      // Crear nuevo completer para este intento de conexión
      _handshakeCompleter = Completer<void>();
      
      // SIEMPRE conectarse al gateway en ceres.globalchat.org:4444
      final bool pageIsHTTPS = Uri.base.scheme == 'https';
      final String protocol = pageIsHTTPS ? 'wss' : 'ws';
      final String gatewayHost = 'ceres.globalchat.org';
      final int gatewayPort = 4444;
      
      final uri = Uri.parse('$protocol://$gatewayHost:$gatewayPort');
      
      // Conectar WebSocket
      _channel = WebSocketChannel.connect(uri);
      
      // Configurar listeners ANTES de enviar el handshake
      _setupChannelListeners();
      
      // Pequeño delay para asegurar que los listeners estén listos
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Enviar handshake con el servidor destino
      final handshake = jsonEncode({
        'host': host,
        'port': port,
        'useSSL': useSSL,
      });
      
      _channel!.sink.add(handshake);
      
      // Esperar confirmación del handshake (máximo 10 segundos)
      await _handshakeCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _isConnected = false;
          _handshakeComplete = false;
          throw TimeoutException('Timeout esperando handshake del gateway');
        },
      );
      
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
      _handshakeComplete = false;
      
      // Limpiar recursos en caso de error
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
    
    // Si el handshake no está completo, no enviar mensajes IRC
    if (!_handshakeComplete) {
      throw StateError('Handshake no completado. No se pueden enviar mensajes IRC.');
    }
    
    // Enviar mensaje IRC (sin \r\n, el gateway lo añadirá)
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
  
  /// Configurar listeners del canal WebSocket
  void _setupChannelListeners() {
    _subscription = _channel!.stream.listen(
      (data) {
        try {
          // WebSocket puede devolver String o List<int>
          String message;
          if (data is String) {
            message = data;
          } else if (data is List<int>) {
            message = String.fromCharCodes(data);
          } else {
            message = data.toString();
          }
          
          // Verificar si es un mensaje de control del gateway (JSON)
          if (message.trim().startsWith('{') && message.trim().endsWith('}')) {
            try {
              final jsonData = jsonDecode(message);
              final type = jsonData['type'] as String?;
              
            if (type == 'handshake_ok') {
              // Handshake exitoso
              _handshakeComplete = true;
              if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
                _handshakeCompleter!.complete();
              }
              return; // No reenviar este mensaje al stream IRC
            } else if (type == 'handshake_error') {
              // Error en handshake
              final errorMsg = jsonData['error'] as String? ?? 'Error desconocido en handshake';
              _handshakeComplete = false;
              if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
                _handshakeCompleter!.completeError(Exception(errorMsg));
              }
              _streamController.addError(Exception(errorMsg));
              return;
              } else if (type == 'irc_error') {
                // Error de conexión IRC
                final errorMsg = jsonData['error'] as String? ?? 'Error de conexión IRC';
                _streamController.addError(Exception(errorMsg));
                return;
              } else if (type == 'irc_closed') {
                // Conexión IRC cerrada
                _isConnected = false;
                _streamController.close();
                return;
              }
              // Si es otro tipo de JSON, continuar procesando como mensaje IRC
            } catch (e) {
              // Si no es JSON válido o hay error parseando, tratarlo como mensaje IRC normal
            }
          }
          
          // Mensaje IRC normal, reenviarlo al stream
          _streamController.add(message);
        } catch (e) {
          // Capturar cualquier error en el procesamiento
          _streamController.addError(e);
        }
      },
      onError: (error) {
        try {
          _streamController.addError(error);
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.completeError(error);
          }
        } catch (e) {
          // Error al manejar el error, al menos completar el completer
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.completeError(error);
          }
        }
      },
      onDone: () {
        try {
          _isConnected = false;
          _handshakeComplete = false;
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.completeError(Exception('Conexión WebSocket cerrada'));
          }
          _streamController.close();
        } catch (e) {
          // Error al cerrar, al menos completar el completer
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.completeError(Exception('Conexión WebSocket cerrada'));
          }
        }
      },
      cancelOnError: false,
    );
  }
}

