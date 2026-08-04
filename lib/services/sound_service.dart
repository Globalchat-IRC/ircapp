// Web-only: uses dart:html for AudioElement. Not compilable on non-web platforms.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math' as math;
import '../config/debug_config.dart';
import '../providers/irc_provider.dart' show MentionSound;

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  html.AudioElement? _mentionAudio;
  html.AudioElement? _alertAudio;
  html.AudioElement? _clickAudio;
  html.AudioElement? _mentionSpecialAudio;
  html.AudioElement? _pmAudio;

  Future<void> _ensureMentionLoaded() async {
    if (_mentionAudio != null) return;
    try {
      _mentionAudio = html.AudioElement();
      _mentionAudio!.src = 'cuac_ircap.mp3';
      _mentionAudio!.preload = 'auto';
      _mentionAudio!.load();
      debugLog('✅ [SoundService] Sonido de mención cargado correctamente');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error cargando sonido de mención: $e');
    }
  }

  void _ensureAlertLoaded() {
    if (_alertAudio != null) return;
    try {
      _alertAudio = html.AudioElement();
      _alertAudio!.src = _beepDataUrl(600, 0.15);
      _alertAudio!.preload = 'auto';
      _alertAudio!.load();
      debugLog('✅ [SoundService] Sonido de alerta generado');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error generando alerta: $e');
    }
  }

  void _ensureClickLoaded() {
    if (_clickAudio != null) return;
    try {
      _clickAudio = html.AudioElement();
      _clickAudio!.src = _beepDataUrl(1200, 0.03);
      _clickAudio!.preload = 'auto';
      _clickAudio!.load();
      debugLog('✅ [SoundService] Sonido de click generado');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error generando click: $e');
    }
  }

  void _ensureMentionSpecialLoaded() {
    if (_mentionSpecialAudio != null) return;
    try {
      _mentionSpecialAudio = html.AudioElement();
      _mentionSpecialAudio!.src = _beepDataUrl(880, 0.2);
      _mentionSpecialAudio!.preload = 'auto';
      _mentionSpecialAudio!.load();
      debugLog('✅ [SoundService] Sonido especial de mención generado');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error generando sonido especial de mención: $e');
    }
  }

  void _ensurePmLoaded() {
    if (_pmAudio != null) return;
    try {
      _pmAudio = html.AudioElement();
      _pmAudio!.src = _beepDataUrl(440, 0.3);
      _pmAudio!.preload = 'auto';
      _pmAudio!.load();
      debugLog('✅ [SoundService] Sonido de PM generado');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error generando sonido de PM: $e');
    }
  }

  /// Genera un tono simple como data URL WAV usando un oscilador matemático.
  String _beepDataUrl(double freqHz, double durationSec) {
    final sampleRate = 8000;
    final numSamples = (sampleRate * durationSec).toInt();
    final samples = <int>[];
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Envelope para evitar clicks al inicio/final
      final envelope = (i < 100 ? i / 100.0 : 1.0) *
          (i > numSamples - 100 ? (numSamples - i) / 100.0 : 1.0);
      final value = (envelope * 127 * (math.sin(t * freqHz * 3.14159 * 2))).round() + 128;
      samples.add(value.clamp(0, 255));
    }
    final header = _wavHeader(sampleRate, 8, 1, numSamples);
    final allBytes = [...header, ...samples];
    return 'data:audio/wav;base64,${base64Encode(allBytes)}';
  }

  List<int> _wavHeader(int sampleRate, int bitsPerSample, int numChannels, int numSamples) {
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;
    final dataSize = numSamples * blockAlign;
    final header = List<int>.filled(44, 0);
    header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46; // "RIFF"
    _writeInt32(header, 4, 36 + dataSize);
    header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45; // "WAVE"
    header[12] = 0x66; header[13] = 0x6D; header[14] = 0x74; header[15] = 0x20; // "fmt "
    _writeInt32(header, 16, 16); // chunk size
    _writeInt16(header, 20, 1); // PCM
    _writeInt16(header, 22, numChannels);
    _writeInt32(header, 24, sampleRate);
    _writeInt32(header, 28, byteRate);
    _writeInt16(header, 32, blockAlign);
    _writeInt16(header, 34, bitsPerSample);
    header[36] = 0x64; header[37] = 0x61; header[38] = 0x74; header[39] = 0x61; // "data"
    _writeInt32(header, 40, dataSize);
    return header;
  }

  void _writeInt16(List<int> buf, int offset, int value) {
    buf[offset] = value & 0xFF;
    buf[offset + 1] = (value >> 8) & 0xFF;
  }

  void _writeInt32(List<int> buf, int offset, int value) {
    buf[offset] = value & 0xFF;
    buf[offset + 1] = (value >> 8) & 0xFF;
    buf[offset + 2] = (value >> 16) & 0xFF;
    buf[offset + 3] = (value >> 24) & 0xFF;
  }

  void _playAudio(html.AudioElement? audio) {
    if (audio == null) return;
    audio.currentTime = 0;
    audio.play();
  }

  Future<void> playMentionCuack() async {
    try {
      await _ensureMentionLoaded();
      _playAudio(_mentionAudio);
      debugLog('🔊 [SoundService] Reproduciendo cuack de mención');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error reproduciendo cuack de mención: $e');
    }
  }

  void playSystemAlert() {
    try {
      _ensureAlertLoaded();
      _playAudio(_alertAudio);
      debugLog('🔊 [SoundService] Reproduciendo alerta del sistema');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error reproduciendo alerta: $e');
    }
  }

  void playSystemClick() {
    try {
      _ensureClickLoaded();
      _playAudio(_clickAudio);
      debugLog('🔊 [SoundService] Reproduciendo click del sistema');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error reproduciendo click: $e');
    }
  }

  void playMentionSpecial() {
    try {
      _ensureMentionSpecialLoaded();
      _playAudio(_mentionSpecialAudio);
      debugLog('🔊 [SoundService] Reproduciendo sonido especial de mención');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error reproduciendo sonido especial: $e');
    }
  }

  void playPrivateMessage() {
    try {
      _ensurePmLoaded();
      _playAudio(_pmAudio);
      debugLog('🔊 [SoundService] Reproduciendo sonido de PM');
    } catch (e) {
      debugLog('⚠️ [SoundService] Error reproduciendo sonido de PM: $e');
    }
  }

  void playMessageSent(MentionSound sound) {
    try {
      switch (sound) {
        case MentionSound.cuack:
          playMentionCuack();
          break;
        case MentionSound.systemAlert:
          playSystemAlert();
          break;
        case MentionSound.systemClick:
          playSystemClick();
          break;
      }
    } catch (e) {
      debugLog('⚠️ [SoundService] Error reproduciendo sonido de envío: $e');
    }
  }
}
