import 'dart:typed_data';

class VoiceRecorderWeb {
  bool get isRecording => false;

  Future<bool> start() async => false;

  Future<Uint8List?> stop() async => null;

  void cancel() {}
}
