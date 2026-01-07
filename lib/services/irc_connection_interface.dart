import 'dart:async';

/// Interfaz abstracta para conexiones IRC (Socket o WebSocket)
abstract class IRCConnection {
  /// Conecta al servidor
  Future<void> connect(String host, int port, {bool useSSL = false});
  
  /// Desconecta del servidor
  Future<void> disconnect();
  
  /// Envía datos al servidor
  void send(String data);
  
  /// Stream de datos recibidos
  Stream<String> get stream;
  
  /// Verifica si está conectado
  bool get isConnected;
  
  /// Cierra la conexión
  void close();
}


