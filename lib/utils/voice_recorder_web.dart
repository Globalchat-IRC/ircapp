import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data' show Uint8List;
import 'package:web/web.dart' as web;

class VoiceRecorderWeb {
  web.MediaRecorder? _recorder;
  web.MediaStream? _stream;
  final List<Uint8List> _chunks = [];
  bool _isRecording = false;
  String _mimeType = 'audio/webm';

  bool get isRecording => _isRecording;

  String get mimeType => _mimeType;

  Future<bool> start() async {
    try {
      final constraints = web.MediaStreamConstraints()..audio = true.toJS;
      _stream = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
      if (_stream == null) return false;

      _chunks.clear();
      _mimeType = _pickMimeType();
      final options = web.MediaRecorderOptions(mimeType: _mimeType);
      _recorder = web.MediaRecorder(_stream!, options);

      _recorder!.addEventListener(
        'dataavailable',
        ((web.Event e) {
          final blobEvent = e as web.BlobEvent;
          final blob = blobEvent.data;
          final reader = web.FileReader();
          reader.onloadend = ((web.Event _) {
            final result = reader.result;
            if (result != null) {
              try {
                final bytes = Uint8List.view((result as JSArrayBuffer).toDart);
                _chunks.add(bytes);
              } catch (_) {}
            }
          }).toJS;
          reader.readAsArrayBuffer(blob);
        }) as web.EventListener,
      );

      _recorder!.start();
      _isRecording = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> stop() async {
    final recorder = _recorder;
    if (recorder == null || !_isRecording) return null;

    final completer = Completer<Uint8List?>();

    recorder.addEventListener(
      'stop',
      ((web.Event _) async {
        await Future.delayed(const Duration(milliseconds: 300));

        if (_chunks.isEmpty) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        try {
          int totalLength = 0;
          for (final chunk in _chunks) {
            totalLength += chunk.length;
          }
          final combined = Uint8List(totalLength);
          int offset = 0;
          for (final chunk in _chunks) {
            combined.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }
          if (!completer.isCompleted) completer.complete(combined);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
      }) as web.EventListener,
    );

    recorder.stop();
    _isRecording = false;
    _stopStream();
    _recorder = null;

    return completer.future;
  }

  void cancel() {
    if (_recorder != null && _isRecording) {
      try { _recorder!.stop(); } catch (_) {}
      _isRecording = false;
    }
    _stopStream();
    _recorder = null;
    _chunks.clear();
  }

  void _stopStream() {
    if (_stream != null) {
      final tracks = _stream!.getTracks();
      for (var i = 0; i < tracks.length; i++) {
        try { tracks[i].stop(); } catch (_) {}
      }
      _stream = null;
    }
  }

  String _pickMimeType() {
    final types = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
    ];
    for (final t in types) {
      try {
        if (web.MediaRecorder.isTypeSupported(t)) return t;
      } catch (_) {}
    }
    return 'audio/webm';
  }
}
