// Implementación web del reconocimiento de voz usando la Web Speech API nativa del navegador.

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Verifica si el navegador soporta reconocimiento de voz (Web Speech API).
Future<bool> isWebSpeechAvailable() async {
  try {
    return web.window.has('SpeechRecognition') ||
        web.window.has('webkitSpeechRecognition');
  } catch (_) {
    return false;
  }
}

/// Inicia el reconocimiento de voz y devuelve un stream con los textos.
Stream<String> startWebSpeech(String localeId) {
  final controller = StreamController<String>();
  _startRecognition(localeId, controller);
  return controller.stream;
}

void _startRecognition(String localeId, StreamController<String> controller) {
  try {
    final String constructorName =
        web.window.has('SpeechRecognition')
            ? 'SpeechRecognition'
            : web.window.has('webkitSpeechRecognition')
                ? 'webkitSpeechRecognition'
                : '';

    if (constructorName.isEmpty) {
      _emitError(controller, 'SpeechRecognition no disponible');
      return;
    }

    // Crear instancia usando el constructor global
    final constructor = web.window.getProperty(constructorName.toJS);
    if (constructor == null || constructor.isUndefinedOrNull) {
      _emitError(controller, 'Constructor no encontrado');
      return;
    }

    // new SpeechRecognition()
    final recognition = (constructor as JSFunction).callAsConstructor();
    if (recognition == null || recognition.isUndefinedOrNull) {
      _emitError(controller, 'No se pudo crear SpeechRecognition');
      return;
    }

    final recObj = recognition as JSObject;

    // Configurar propiedades
    recObj.setProperty('lang'.toJS, localeId.toJS);
    recObj.setProperty('interimResults'.toJS, true.toJS);
    recObj.setProperty('continuous'.toJS, false.toJS);
    recObj.setProperty('maxAlternatives'.toJS, 1.toJS);

    bool finalEmitted = false;

    // onresult
    recObj.setProperty(
      'onresult'.toJS,
      ((web.Event _) {
        try {
          final resultIdx = recObj.getProperty('resultIndex'.toJS);
          final int startIndex =
              resultIdx != null && !resultIdx.isUndefinedOrNull
                  ? (resultIdx as JSNumber).toDartInt
                  : 0;

          final results = recObj.getProperty('results'.toJS);
          if (results == null || results.isUndefinedOrNull) return;
          final resultsObj = results as JSObject;

          final lengthVal = resultsObj.getProperty('length'.toJS);
          if (lengthVal == null || lengthVal.isUndefinedOrNull) return;
          final length = (lengthVal as JSNumber).toDartInt;

          String finalText = '';

          for (var i = startIndex; i < length; i++) {
            final item = resultsObj.getProperty(i.toJS);
            if (item == null || item.isUndefinedOrNull) continue;
            final itemObj = item as JSObject;

            final transcriptResult = itemObj.getProperty('0'.toJS);
            if (transcriptResult == null || transcriptResult.isUndefinedOrNull) {
              continue;
            }
            final transcriptObj = transcriptResult as JSObject;
            final transcriptVal =
                transcriptObj.getProperty('transcript'.toJS);
            if (transcriptVal == null || transcriptVal.isUndefinedOrNull) {
              continue;
            }
            final transcript = transcriptVal.toString();

            final isFinalVal = itemObj.getProperty('isFinal'.toJS);
            final isFinal =
                isFinalVal != null && !isFinalVal.isUndefinedOrNull
                    ? (isFinalVal as JSBoolean).toDart
                    : false;

            if (isFinal) {
              finalEmitted = true;
              finalText = transcript;
            } else if (transcript.isNotEmpty && !controller.isClosed) {
              controller.add(transcript);
            }
          }

          if (finalEmitted &&
              finalText.trim().isNotEmpty &&
              !controller.isClosed) {
            controller.add(finalText.trim());
          }
        } catch (_) {}
      }).toJS,
    );

    // onerror
    recObj.setProperty(
      'onerror'.toJS,
      ((web.Event e) {
        _emitError(controller, 'Error de reconocimiento de voz');
      }).toJS,
    );

    // onend
    recObj.setProperty(
      'onend'.toJS,
      ((web.Event _) {
        if (!controller.isClosed) {
          controller.close();
        }
      }).toJS,
    );

    // onnomatch
    recObj.setProperty(
      'onnomatch'.toJS,
      ((web.Event _) {
        if (!controller.isClosed && !finalEmitted) {
          controller.add('__ERROR__');
        }
      }).toJS,
    );

    // start()
    recObj.callMethodVarArgs('start'.toJS);
  } catch (e) {
    _emitError(controller, 'Excepción: $e');
  }
}

void _emitError(StreamController<String> controller, String msg) {
  if (!controller.isClosed) {
    controller.add('__ERROR__');
    Future.microtask(() {
      if (!controller.isClosed) {
        controller.close();
      }
    });
  }
}
