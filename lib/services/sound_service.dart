import 'package:just_audio/just_audio.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _mentionPlayer = AudioPlayer();
  bool _mentionLoaded = false;

  Future<void> _ensureMentionLoaded() async {
    if (_mentionLoaded) return;
    try {
      // El asset está declarado en pubspec.yaml en la raíz del proyecto
      await _mentionPlayer.setAsset('cuac_ircap.mp3');
      _mentionLoaded = true;
    } catch (e) {
      // Silenciar el error - el archivo puede no existir en web
      _mentionLoaded = false;
      // ignore: avoid_print
      // print('⚠️ [SoundService] Error cargando sonido de mención: $e');
    }
  }

  Future<void> playMentionCuack() async {
    await _ensureMentionLoaded();
    if (!_mentionLoaded) return;
    try {
      await _mentionPlayer.seek(Duration.zero);
      await _mentionPlayer.play();
    } catch (e) {
      // ignore: avoid_print
      // print('⚠️ [SoundService] Error reproduciendo cuack de mención: $e');
    }
  }
}







