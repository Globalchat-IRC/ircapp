import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'irc_connection_interface.dart';
import '../utils/platform_utils.dart';

/// Implementación de conexión IRC usando Socket TCP nativo (móvil/desktop)
class IRCSocketConnection implements IRCConnection {
  Socket? _socket;
  SecureSocket? _secureSocket;
  final StreamController<String> _streamController = StreamController<String>.broadcast();
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String? _host; // Guardar host para referencia

  @override
  Future<void> connect(String host, int port, {bool useSSL = true}) async {
    if (!PlatformUtils.canUseNativeSockets) {
      throw UnsupportedError('Socket TCP no está disponible en web. Use WebSocket.');
    }

    _host = host;
    try {
      if (useSSL) {
        // Crear un SecurityContext más permisivo para macOS
        final context = SecurityContext.defaultContext;
        // Permitir certificados autofirmados y certificados con problemas de validación
        _secureSocket = await SecureSocket.connect(
          host,
          port,
          context: context,
          timeout: const Duration(seconds: 20), // Aumentar timeout para conexiones lentas
          onBadCertificate: (certificate) {
            // Aceptar certificados autofirmados o con problemas de validación
            // Esto es necesario para algunos servidores IRC
            print('⚠️ [IRC] Certificado con problemas de validación para $host:$port, aceptando de todas formas');
            return true;
          },
        );
        _subscription = _secureSocket!.listen(
          (data) {
            // Decodificar como UTF-8 para soportar emoticonos y caracteres especiales
            final message = utf8.decode(data, allowMalformed: true);
            _streamController.add(message);
          },
          onError: (error) {
            _streamController.addError(error);
          },
          onDone: () {
            _isConnected = false;
            _streamController.close();
          },
        );
        _isConnected = true;
      } else {
        _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
        _subscription = _socket!.listen(
          (data) {
            // Decodificar como UTF-8 para soportar emoticonos y caracteres especiales
            final message = utf8.decode(data, allowMalformed: true);
            _streamController.add(message);
          },
          onError: (error) {
            _streamController.addError(error);
          },
          onDone: () {
            _isConnected = false;
            _streamController.close();
          },
        );
        _isConnected = true;
      }
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _secureSocket?.close();
    await _socket?.close();
    _isConnected = false;
    await _streamController.close();
  }

  @override
  void send(String data) {
    if (!_isConnected) {
      throw StateError('No conectado al servidor');
    }
    
    final bytes = data.codeUnits;
    if (_secureSocket != null) {
      _secureSocket!.add(bytes);
    } else if (_socket != null) {
      _socket!.add(bytes);
    }
  }

  @override
  Stream<String> get stream => _streamController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  void close() {
    disconnect();
  }
}

