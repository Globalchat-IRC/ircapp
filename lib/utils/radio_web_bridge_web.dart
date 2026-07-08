import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

Map<String, Object?>? getHlsPlaybackState(String audioElementId) {
  if (!web.window.has('getHLSPlaybackState')) return null;
  final state = web.window.callMethodVarArgs<JSAny?>(
    'getHLSPlaybackState'.toJS,
    [audioElementId.toJS],
  );
  final stateObject = state?.dartify();
  if (stateObject is Map) {
    return stateObject.cast<String, Object?>();
  }
  return null;
}

String? getWebPageOrigin() {
  final href = web.window.location.href;
  if (href.isEmpty) return null;
  final uri = Uri.parse(href);
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
}

Future<void> playHlsStream(String url, String audioElementId) async {
  if (!web.window.has('playHLSStream')) {
    throw Exception(
      'hls.js no está disponible. Asegúrate de que hls.js esté cargado en index.html',
    );
  }

  final promise = web.window.callMethodVarArgs<JSPromise<JSAny?>>(
    'playHLSStream'.toJS,
    [url.toJS, audioElementId.toJS],
  );

  await promise.toDart.timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      throw Exception('Timeout al reproducir stream HLS (10 segundos)');
    },
  );
}

void stopHlsStream(String audioElementId) {
  if (!web.window.has('stopHLSStream')) return;
  web.window.callMethodVarArgs<JSAny?>('stopHLSStream'.toJS, [
    audioElementId.toJS,
  ]);
}

void pauseHlsAudio(String audioElementId) {
  final audioElement =
      web.document.getElementById(audioElementId) as web.HTMLAudioElement?;
  audioElement?.pause();
}

Future<void> resumeHlsAudio(String audioElementId) async {
  final audioElement =
      web.document.getElementById(audioElementId) as web.HTMLAudioElement?;
  if (audioElement != null) {
    await audioElement.play().toDart;
  }
}

bool setHlsAudioVolume(String audioElementId, double volume) {
  if (web.window.has('setHLSVolume')) {
    web.window.callMethodVarArgs<JSAny?>('setHLSVolume'.toJS, [
      audioElementId.toJS,
      volume.toJS,
    ]);
    return true;
  }

  final audioElement =
      web.document.getElementById(audioElementId) as web.HTMLAudioElement?;
  if (audioElement == null) return false;
  audioElement.volume = volume;
  return true;
}
