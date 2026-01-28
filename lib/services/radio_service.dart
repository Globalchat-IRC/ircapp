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
// Conditional import for window location (web only)
import 'dart:html' if (dart.library.io) 'package:irc_app/utils/html_stub.dart' as html;

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
        print('📻 [RadioService] Inicializando para web...');
        _webPlayer = web_audio.AudioPlayer();
        // Configurar el player para web
        await _webPlayer!.setReleaseMode(web_audio.ReleaseMode.stop);
        await _webPlayer!.setPlayerMode(web_audio.PlayerMode.mediaPlayer);
        // Aplicar volumen inicial
        await _webPlayer!.setVolume(_currentVolume);
        print('✅ [RadioService] Inicializado para web correctamente');
      } else {
        print('📻 [RadioService] Ya estaba inicializado para web');
      }
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
      
      // Verificar que la URL sea válida
      String sourceUrl = station.source;
      if (sourceUrl.isEmpty) {
        throw Exception('URL de la estación está vacía');
      }
      
      // Agregar listener para detectar errores
      _webPlayer!.onPlayerStateChanged.listen((state) {
        if (state == web_audio.PlayerState.stopped && _isPlaying) {
          // Si se detuvo inesperadamente, marcar como error
          _isPlaying = false;
          print('⚠️ [RadioService Web] Reproducción detenida inesperadamente');
        }
      });
      
      _webPlayer!.onLog.listen((log) {
        print('📻 [RadioService Web] Log: $log');
      });
      
      // En web, intentar primero con proxy si es necesario (listen2myradio.com o mixcloud HLS)
      String finalUrl = sourceUrl;
      bool useProxy = sourceUrl.contains('listen2myradio.com') || 
                      (sourceUrl.contains('mixcloud.com') && sourceUrl.contains('.m3u8'));
      
      if (useProxy) {
        try {
          final uri = Uri.parse(sourceUrl);
          // Para Mixcloud HLS, usar un proxy diferente o intentar convertir a formato compatible
          if (sourceUrl.contains('mixcloud.com') && sourceUrl.contains('.m3u8')) {
            // Los streams HLS no son compatibles directamente con audioplayers en web
            // Intentar usar la URL directa primero, si falla mostrar error
            print('⚠️ [RadioService Web] Stream HLS detectado - puede no funcionar en web debido a CORS');
            // Por ahora, intentar directo pero probablemente fallará
            finalUrl = sourceUrl;
          } else {
            // Proxy para otros servicios
            final proxyPath = '/radio-proxy/${uri.host}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
            final baseHref = html.window.location.href;
            if (baseHref != null && baseHref.isNotEmpty) {
              final baseUri = Uri.parse(baseHref);
              finalUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$proxyPath';
              print('📻 [RadioService Web] Intentando con proxy: $finalUrl');
            }
          }
        } catch (e) {
          print('⚠️ [RadioService Web] Error construyendo proxy, usando URL directa: $e');
          useProxy = false;
        }
      } else {
        print('📻 [RadioService Web] Reproduciendo desde URL directa: $sourceUrl');
      }
      
      // Intentar reproducir
      try {
        print('📻 [RadioService Web] Iniciando reproducción de: $finalUrl');
        await _webPlayer!.play(web_audio.UrlSource(finalUrl));
        
        // Esperar un momento para verificar si hay errores de reproducción
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Verificar el estado del player
        final playerState = _webPlayer!.state;
        print('📻 [RadioService Web] Estado del player después de iniciar: $playerState');
        
        // Verificar si hay errores
        _webPlayer!.onPlayerComplete.listen((_) {
          print('📻 [RadioService Web] Reproducción completada');
          _isPlaying = false;
        });
        
        // Verificar errores de reproducción
        _webPlayer!.onLog.listen((log) {
          print('📻 [RadioService Web] Log del player: $log');
        });
        
        if (playerState == web_audio.PlayerState.stopped) {
          // Si se detuvo inmediatamente y usamos proxy, intentar URL directa
          if (useProxy && finalUrl != sourceUrl) {
            print('⚠️ [RadioService Web] Proxy falló, intentando URL directa...');
            try {
              await _webPlayer!.stop();
              await _webPlayer!.release();
              _webPlayer = web_audio.AudioPlayer();
              await _webPlayer!.setReleaseMode(web_audio.ReleaseMode.stop);
              await _webPlayer!.setPlayerMode(web_audio.PlayerMode.mediaPlayer);
              await _webPlayer!.setVolume(_currentVolume);
              print('📻 [RadioService Web] Intentando URL directa: $sourceUrl');
              await _webPlayer!.play(web_audio.UrlSource(sourceUrl));
              await Future.delayed(const Duration(milliseconds: 1000));
              final retryState = _webPlayer!.state;
              print('📻 [RadioService Web] Estado después de retry: $retryState');
              if (retryState == web_audio.PlayerState.stopped) {
                throw Exception('No se pudo iniciar la reproducción. El servidor puede tener restricciones CORS o la URL no es válida.');
              }
            } catch (retryError) {
              print('❌ [RadioService Web] Error en retry: $retryError');
              throw Exception('No se pudo iniciar la reproducción. Error: $retryError');
            }
          } else {
            throw Exception('No se pudo iniciar la reproducción. El servidor puede tener restricciones CORS o la URL no es válida.');
          }
        }
        
        // Si llegamos aquí, la reproducción debería estar funcionando
        print('✅ [RadioService Web] Reproducción iniciada correctamente');
      } catch (playError) {
        print('❌ [RadioService Web] Error al reproducir: $playError');
        // Si hay un error al reproducir y usamos proxy, intentar URL directa
        if (useProxy && finalUrl != sourceUrl) {
          print('⚠️ [RadioService Web] Error con proxy, intentando URL directa...');
          try {
            await _webPlayer!.stop();
            await _webPlayer!.release();
            _webPlayer = web_audio.AudioPlayer();
            await _webPlayer!.setReleaseMode(web_audio.ReleaseMode.stop);
            await _webPlayer!.setPlayerMode(web_audio.PlayerMode.mediaPlayer);
            await _webPlayer!.setVolume(_currentVolume);
            await _webPlayer!.play(web_audio.UrlSource(sourceUrl));
            await Future.delayed(const Duration(milliseconds: 800));
            final retryState = _webPlayer!.state;
            if (retryState == web_audio.PlayerState.stopped && _isPlaying == false) {
              throw playError; // Re-lanzar el error original
            }
          } catch (retryError) {
            throw playError; // Re-lanzar el error original
          }
        } else {
          throw playError;
        }
      }
      
      // Verificar una vez más que el player esté realmente reproduciendo
      await Future.delayed(const Duration(milliseconds: 500));
      final finalState = _webPlayer!.state;
      print('📻 [RadioService Web] Estado final antes de confirmar: $finalState');
      
      if (finalState == web_audio.PlayerState.playing) {
        _currentStation = station;
        _isPlaying = true;
        print('✅ [RadioService Web] Reproducción confirmada: ${station.name}');
      } else {
        print('⚠️ [RadioService Web] El player no está en estado playing, estado actual: $finalState');
        // Intentar una vez más
        if (finalState == web_audio.PlayerState.stopped || finalState == web_audio.PlayerState.paused) {
          try {
            await _webPlayer!.resume();
            await Future.delayed(const Duration(milliseconds: 500));
            if (_webPlayer!.state == web_audio.PlayerState.playing) {
              _currentStation = station;
              _isPlaying = true;
              print('✅ [RadioService Web] Reproducción iniciada después de resume');
            } else {
              throw Exception('No se pudo iniciar la reproducción después de varios intentos');
            }
          } catch (e) {
            throw Exception('No se pudo iniciar la reproducción. Estado: $finalState, Error: $e');
          }
        }
      }
    } catch (e, stackTrace) {
      _isPlaying = false;
      _currentStation = null;
      // Limpiar player en caso de error
      try {
        await _webPlayer?.stop();
        await _webPlayer?.release();
      } catch (_) {}
      _webPlayer = null;
      
      // Log del error para debugging
      print('❌ [RadioService Web] Error reproduciendo ${station.name}: $e');
      print('❌ [RadioService Web] URL: ${station.source}');
      print('❌ [RadioService Web] Stack: $stackTrace');
      
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
