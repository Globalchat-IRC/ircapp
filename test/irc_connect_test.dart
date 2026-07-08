import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:irc_app/services/irc_service.dart';

/// Prueba real de red contra Ceres/Apolo/Caliope. Solo corre si IRC_CONNECT_TEST=1.
/// Ejemplo: IRC_CONNECT_TEST=1 flutter test test/irc_connect_test.dart
void main() {
  test('IRC Ceres/Apolo/Caliope registran nick de prueba', () async {
    if (Platform.environment['IRC_CONNECT_TEST'] != '1') return;

    for (final host in [
      'ceres.globalchat.org',
      'apolo.globalchat.org',
      'caliope.globalchat.org',
    ]) {
      final service = IRCService();
      final nick = 'dbg${DateTime.now().millisecondsSinceEpoch % 100000}';
      await service.connect(
        host: host,
        port: 6697,
        nickname: nick,
        useSSL: true,
      );
      await service.waitForRegistration(
        timeout: const Duration(seconds: 20),
      );
      expect(service.isRegistered, isTrue);
      expect(service.serverHost, isNotNull);
      await service.disconnect();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
