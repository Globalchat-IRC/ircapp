import 'dart:async';
import 'dart:js_interop';

import 'package:dart_webrtc/dart_webrtc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:web/web.dart' as web;

/// Interfaz JS para el helper global `window.backgroundBlur` definido en
/// `web/background_blur.js`.
extension type BackgroundBlur._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> start(web.HTMLVideoElement video, web.HTMLCanvasElement canvas);
  external void stop();
}

/// Obtiene el helper global `backgroundBlur` desde `window`.
@JS('backgroundBlur')
external BackgroundBlur? get _backgroundBlur;

/// Processor de desenfoque de fondo para video tracks locales usando
/// MediaPipe Selfie Segmentation. Solo funciona en web.
class BackgroundBlurProcessor extends lk.TrackProcessor<lk.VideoProcessorOptions> {
  @override
  String get name => 'background-blur';

  web.HTMLVideoElement? _video;
  web.HTMLCanvasElement? _canvas;
  web.MediaStreamTrack? _jsProcessedTrack;
  rtc.MediaStreamTrack? _processedTrack;

  web.MediaStreamTrack _getJsTrack(rtc.MediaStreamTrack track) {
    if (track is MediaStreamTrackWeb) {
      return track.jsTrack;
    }
    throw UnsupportedError('BackgroundBlurProcessor requiere MediaStreamTrackWeb (web)');
  }

  BackgroundBlur? get _blurHelper {
    try {
      return _backgroundBlur;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> init(lk.VideoProcessorOptions options) async {
    final jsTrack = _getJsTrack(options.track);
    final mediaStream = web.MediaStream();
    mediaStream.addTrack(jsTrack);

    _video = web.HTMLVideoElement()
      ..autoplay = true
      ..playsInline = true
      ..muted = true
      ..srcObject = mediaStream
      ..style.display = 'none';

    web.document.body?.append(_video!);

    await _video!.onLoadedMetadata.first;

    _canvas = web.HTMLCanvasElement()
      ..width = _video!.videoWidth
      ..height = _video!.videoHeight
      ..style.display = 'none';

    web.document.body?.append(_canvas!);

    final blur = _blurHelper;
    if (blur == null) {
      throw StateError('backgroundBlur no está disponible. Verifica que el script de MediaPipe esté cargado en index.html');
    }

    await blur.start(_video!, _canvas!).toDart;

    final processedStream = _canvas!.captureStream();
    final tracks = processedStream.getVideoTracks().toDart;
    _jsProcessedTrack = tracks.isNotEmpty ? tracks.first : null;
    if (_jsProcessedTrack != null) {
      _processedTrack = MediaStreamTrackWeb(_jsProcessedTrack!);
    }
  }

  @override
  Future<void> restart(lk.VideoProcessorOptions options) async {
    await destroy();
    await init(options);
  }

  @override
  Future<void> destroy() async {
    _blurHelper?.stop();
    _jsProcessedTrack?.stop();
    _jsProcessedTrack = null;
    _processedTrack = null;
    _video?.remove();
    _video = null;
    _canvas?.remove();
    _canvas = null;
  }

  @override
  Future<void> onPublish(lk.Room room) async {}

  @override
  Future<void> onUnpublish() async {}

  @override
  rtc.MediaStreamTrack? get processedTrack => _processedTrack;
}
