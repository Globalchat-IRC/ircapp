// Stub para web - el servidor HTTP de moderación solo funciona en nativo

import 'dart:async';

class ModerationServer {
  ModerationServer(dynamic videoService, {int port = 8765});

  Future<void> start() async {}
  Future<void> stop() async {}
  Future<void> dispose() async {}
}
