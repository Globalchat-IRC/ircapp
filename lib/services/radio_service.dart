import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audioplayers/audioplayers.dart' as web_audio;
import 'package:audio_session/audio_session.dart' show AudioSession, AudioSessionConfiguration, AVAudioSessionCategory, AVAudioSessionCategoryOptions, AVAudioSessionMode, AVAudioSessionRouteSharingPolicy, AVAudioSessionSetActiveOptions, AndroidAudioAttributes, AndroidAudioContentType, AndroidAudioFlags, AndroidAudioUsage, AndroidAudioFocusGainType;
import '../models/radio_station.dart';
import 'stream_proxy_service.dart';
import '../main.dart' show globalLog;
import '../utils/platform_utils.dart';
// Conditional import for Platform (native only)
import 'dart:io' if (dart.library.html) 'dart:html' as io;

class RadioService {
  AudioPlayer? _player; // just_audio para nativo
  web_audio.AudioPlayer? _webPlayer; // audioplayers para web
  RadioStation? _currentStation;
  bool _isPlaying = false;
  AudioSession? _audioSession;
  double _currentVolume = 0.1; // Volumen actual

  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;
  RadioService._internal();

  /// Inicializar servicio
  Future<void> initialize() async {
    if (PlatformUtils.isWeb) {
      if (_webPlayer == null) {
        _webPlayer = web_audio.AudioPlayer();
        // Aplicar volumen inicial
        await _webPlayer!.setVolume(_currentVolume);
      }
      // print('✅ [RadioService] Inicializado para web');
      return;
    }

    if (_player == null) {
      _player = AudioPlayer();
      // Aplicar volumen inicial
      await _player!.setVolume(_currentVolume);
    }
    
    // Configurar sesión de audio solo en plataformas móviles (iOS/Android)
    // DESHABILITADO TEMPORALMENTE PARA SIMPLIFICAR
    // TODO: Reimplementar cuando sea necesario
    
    // Iniciar el proxy local (solo en macOS/iOS)
    // DESHABILITADO TEMPORALMENTE PARA SIMPLIFICAR
    // TODO: Reimplementar cuando sea necesario
  }

  /// Reproducir estación de radio
  Future<void> playStation(RadioStation station) async {
    // Siempre detener la reproducción actual antes de iniciar una nueva
    if (_isPlaying && _currentStation != null) {
      await stop();
      // Esperar un momento para asegurar que se detiene completamente
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    if (PlatformUtils.isWeb) {
      await _playStationWeb(station);
      return;
    }
    await _playStationNative(station);
  }

  Future<void> _playStationWeb(RadioStation station) async {
    try {
      // Si ya está reproduciendo la misma estación, no hacer nada
      if (_currentStation?.source == station.source && _isPlaying) {
        return;
      }
      
      // Siempre detener y liberar cualquier reproducción anterior
      if (_webPlayer != null) {
        try {
          await _webPlayer!.stop();
          await _webPlayer!.release();
        } catch (e) {
          // Ignorar errores al detener
        }
        _webPlayer = null; // Limpiar referencia
        // Esperar un momento para asegurar que se libera completamente
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Crear nuevo player siempre (para evitar problemas con instancias anteriores)
      _webPlayer = web_audio.AudioPlayer();
      
      // Configurar el player para web
      await _webPlayer!.setReleaseMode(web_audio.ReleaseMode.stop);
      await _webPlayer!.setPlayerMode(web_audio.PlayerMode.mediaPlayer);
      
      // Configurar volumen desde el estado guardado
      await _webPlayer!.setVolume(_currentVolume);
      
      // Reproducir la estación
      await _webPlayer!.play(web_audio.UrlSource(station.source));
      _currentStation = station;
      _isPlaying = true;
    } catch (e, stackTrace) {
      _isPlaying = false;
      _currentStation = null;
      // Limpiar player en caso de error
      try {
        await _webPlayer?.stop();
        await _webPlayer?.release();
      } catch (_) {}
      _webPlayer = null;
      rethrow; // Re-lanzar el error para que el widget pueda manejarlo
    }
  }

  Future<void> _playStationNative(RadioStation station) async {
    if (_player == null) return;
    
    try {
      // Si ya está reproduciendo la misma estación, no hacer nada
      if (_currentStation?.source == station.source && _isPlaying) {
        return;
      }
      
      // Detener reproducción anterior si hay una diferente
      if (_currentStation?.source != station.source) {
        try {
          await _player!.stop();
          // Esperar un momento para asegurar que se detiene completamente
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // Ignorar errores al detener
        }
        
        String playUrl = station.source;
        
        // En macOS/iOS, usar proxy local si está disponible
        // DESHABILITADO TEMPORALMENTE PARA SIMPLIFICAR
        /*
        if (!PlatformUtils.isWeb) {
          try {
            // ignore: avoid_web_libraries_in_flutter
            final isIOS = io.Platform.isIOS;
            final isMacOS = io.Platform.isMacOS;
            if (isIOS || isMacOS) {
              final proxyPort = StreamProxyService.instance.port;
              if (proxyPort != null) {
                playUrl = 'http://localhost:$proxyPort/proxy?url=${Uri.encodeComponent(station.source)}';
                // print('🎵 [RadioService] Usando proxy local en puerto $proxyPort');
              }
            }
          } catch (e) {
            // print('⚠️ [RadioService] Error usando proxy: $e');
          }
        }
        */
        
        await _player!.setUrl(playUrl);
        await _player!.play();
        _currentStation = station;
        _isPlaying = true;
        // print('🎵 [RadioService] Reproduciendo: ${station.name}');
      }
    } catch (e) {
      _isPlaying = false;
      _currentStation = null;
      // print('❌ [RadioService] Error reproduciendo: $e');
    }
  }

  /// Detener reproducción
  Future<void> stop() async {
    try {
      if (PlatformUtils.isWeb) {
        if (_webPlayer != null) {
          await _webPlayer!.stop();
          await _webPlayer!.release();
          _webPlayer = null; // Liberar referencia
        }
      } else {
        if (_player != null) {
          await _player!.stop();
        }
      }
      _isPlaying = false;
      _currentStation = null;
    } catch (e) {
      _isPlaying = false;
      _currentStation = null;
      // En web, forzar la limpieza incluso si hay error
      if (PlatformUtils.isWeb) {
        _webPlayer = null;
      }
    }
  }

  /// Pausar reproducción
  Future<void> pause() async {
    try {
      if (PlatformUtils.isWeb) {
        await _webPlayer?.pause();
        // print('⏸️ [RadioService] Reproducción pausada en web');
      } else {
        await _player?.pause();
      }
      _isPlaying = false;
    } catch (e) {
      // print('❌ [RadioService] Error al pausar: $e');
    }
  }

  /// Reanudar reproducción
  Future<void> resume() async {
    try {
      if (PlatformUtils.isWeb) {
        await _webPlayer?.resume();
        // print('▶️ [RadioService] Reproducción reanudada en web');
      } else {
        await _player?.play();
      }
      _isPlaying = true;
    } catch (e) {
      // print('❌ [RadioService] Error al reanudar: $e');
    }
  }

  /// Obtener estación actual
  RadioStation? get currentStation => _currentStation;

  /// Verificar si está reproduciendo
  bool get isPlaying => _isPlaying;

  /// Establecer volumen (0.0 a 1.0)
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    if (PlatformUtils.isWeb) {
      await _webPlayer?.setVolume(_currentVolume);
    } else {
      await _player?.setVolume(_currentVolume);
    }
  }
  
  /// Obtener volumen actual
  double get currentVolume => _currentVolume;

  /// Liberar recursos
  Future<void> dispose() async {
    await stop();
    if (PlatformUtils.isWeb) {
      await _webPlayer?.dispose();
    } else {
      await _player?.dispose();
    }
    _audioSession = null;
  }
}
