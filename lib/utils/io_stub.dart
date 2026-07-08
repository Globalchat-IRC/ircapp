// Stub para dart:io en web (Socket no disponible).
// En web no se comprueba el estado del servidor; se muestra "—".

class Socket {
  static Future<Socket> connect(
    dynamic host,
    int port, {
    Duration? timeout,
  }) async {
    throw UnsupportedError('Socket no disponible en web');
  }

  void destroy() {}
}

class SecureSocket {
  static Future<SecureSocket> connect(
    dynamic host,
    int port, {
    Duration? timeout,
    dynamic onBadCertificate,
  }) async {
    throw UnsupportedError('SecureSocket no disponible en web');
  }

  Future<void> close() async {}
}
