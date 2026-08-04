import 'dart:async';
import 'irc_connection_interface.dart';

class IRCSocketConnection implements IRCConnection {
  @override
  Future<void> connect(String host, int port, {bool useSSL = true}) async {
    throw UnsupportedError('TCP sockets no disponibles en web');
  }

  @override
  Future<void> disconnect() async {}

  @override
  void send(String data) {}

  @override
  Stream<String> get stream => const Stream.empty();

  @override
  bool get isConnected => false;

  @override
  void close() {}
}
