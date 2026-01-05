import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'irc_connection_interface.dart';
import '../utils/platform_utils.dart';

/// Implementación de conexión IRC usando WebSocket (web)
class IRCWebSocketConnection implements IRCConnection {
  WebSocketChannel? _channel;
  final StreamController<String> _streamController = StreamController<String>.broadcast();
  StreamSubscription? _subscription;
  bool _isConnected = false;

  @override
  Future<void> connect(String host, int port, {bool useSSL = false}) async {
    if (!PlatformUtils.mustUseWebSocket) {
      throw UnsupportedError('WebSocket solo está disponible en web. Use Socket TCP.');
    }

    try {
      // Construir URI WebSocket
      final protocol = useSSL ? 'wss' : 'ws';
      final uri = Uri.parse('$protocol://$host:$port');
      
      _channel = WebSocketChannel.connect(uri);
      
      _subscription = _channel!.stream.listen(
        (data) {
          // WebSocket puede devolver String o List<int>
          String message;
          if (data is String) {
            message = data;
          } else if (data is List<int>) {
            message = String.fromCharCodes(data);
          } else {
            message = data.toString();
          }
          _streamController.add(message);
        },
        onError: (error) {
          _streamController.addError(error);
        },
        onDone: () {
          _isConnected = false;
          _streamController.close();
        },
        cancelOnError: false,
      );
      
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
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
}

