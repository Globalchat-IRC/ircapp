// Implementación web del reconocimiento de voz.
// Por limitaciones de la plataforma actual, se comporta igual que el stub:
// indica que no hay soporte real de reconocimiento de voz desde el navegador.

import 'dart:async';

Future<bool> isWebSpeechAvailable() async => false;

Stream<String> startWebSpeech(String localeId) {
  final controller = StreamController<String>();
  Future.microtask(() {
    controller.add('__ERROR__');
    controller.close();
  });
  return controller.stream;
}


