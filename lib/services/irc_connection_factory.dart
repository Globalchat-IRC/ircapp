import 'irc_connection_interface.dart';
import 'irc_socket_connection.dart';
import 'irc_websocket_connection.dart';
import '../utils/platform_utils.dart';

/// Factory para crear conexiones IRC según la plataforma
class IRCConnectionFactory {
  /// Crea una conexión IRC apropiada para la plataforma actual
  static IRCConnection create() {
    if (PlatformUtils.mustUseWebSocket) {
      return IRCWebSocketConnection();
    } else {
      return IRCSocketConnection();
    }
  }
  
  /// Crea una conexión específica (útil para testing)
  static IRCConnection createSocket() => IRCSocketConnection();
  static IRCConnection createWebSocket() => IRCWebSocketConnection();
}





