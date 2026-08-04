import 'dart:typed_data' show Uint8List;

class VoiceRecorderWeb {
  bool get isRecording => false;

  String get mimeType => 'audio/webm';

  Future<bool> start() async => false;

  Future<Uint8List?> stop() async => null;

  void cancel() {}
}
