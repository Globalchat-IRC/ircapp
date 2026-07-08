Map<String, Object?>? getHlsPlaybackState(String audioElementId) => null;

String? getWebPageOrigin() => null;

Future<void> playHlsStream(String url, String audioElementId) async {
  throw UnsupportedError('HLS web bridge is only available on web');
}

void stopHlsStream(String audioElementId) {}

void pauseHlsAudio(String audioElementId) {}

Future<void> resumeHlsAudio(String audioElementId) async {}

bool setHlsAudioVolume(String audioElementId, double volume) => false;
