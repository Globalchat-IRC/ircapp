import 'dart:async';

/// Stub para reconocimiento de voz en plataformas que no son web.
/// Siempre indica que no hay soporte.
Future<bool> isWebSpeechAvailable() async => false;

Stream<String> startWebSpeech(String localeId) {
  final controller = StreamController<String>();
  Future.microtask(() {
    controller.add('__ERROR__');
    controller.close();
  });
  return controller.stream;
}

