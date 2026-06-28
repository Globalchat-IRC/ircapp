// Stub para dart:io en web (Socket no disponible).
// En web no se comprueba el estado del servidor; se muestra "—".

class Socket {
  static Future<Socket> connect(dynamic host, int port, {Duration? timeout}) async {
    throw UnsupportedError('Socket no disponible en web');
  }
  void destroy() {}
}
