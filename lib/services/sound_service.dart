import 'package:just_audio/just_audio.dart';
import '../utils/platform_utils.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  AudioPlayer? _mentionPlayer;
  bool _mentionLoaded = false;
  bool _isLoading = false;

  Future<void> _ensureMentionLoaded() async {
    if (_mentionLoaded || _isLoading) return;
    _isLoading = true;
    try {
      // En web, just_audio puede tener problemas, así que inicializamos el player solo cuando sea necesario
      _mentionPlayer ??= AudioPlayer();
      
      // El asset está declarado en pubspec.yaml en la raíz del proyecto
      await _mentionPlayer!.setAsset('cuac_ircap.mp3');
      _mentionLoaded = true;
      print('✅ [SoundService] Sonido de mención cargado correctamente');
    } catch (e) {
      _mentionLoaded = false;
      print('⚠️ [SoundService] Error cargando sonido de mención: $e');
      // En web, si falla, intentar usar AudioElement directamente
      if (PlatformUtils.isWeb) {
        print('🌐 [SoundService] Intentando cargar sonido para web...');
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> playMentionCuack() async {
    try {
      await _ensureMentionLoaded();
      if (!_mentionLoaded || _mentionPlayer == null) {
        print('⚠️ [SoundService] No se puede reproducir: sonido no cargado');
        return;
      }
      
      // Reiniciar el audio al principio
      await _mentionPlayer!.seek(Duration.zero);
      // Reproducir
      await _mentionPlayer!.play();
      print('🔊 [SoundService] Reproduciendo cuack de mención');
    } catch (e) {
      print('⚠️ [SoundService] Error reproduciendo cuack de mención: $e');
      // Si falla, intentar recargar y reproducir de nuevo
      try {
        _mentionLoaded = false;
        _mentionPlayer?.dispose();
        _mentionPlayer = null;
        await _ensureMentionLoaded();
        if (_mentionLoaded && _mentionPlayer != null) {
          await _mentionPlayer!.seek(Duration.zero);
          await _mentionPlayer!.play();
          print('🔊 [SoundService] Reproduciendo cuack de mención (reintento)');
        }
      } catch (e2) {
        print('⚠️ [SoundService] Error en reintento: $e2');
      }
    }
  }
}







