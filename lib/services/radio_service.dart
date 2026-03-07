import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:just_audio/just_audio.dart';
import 'package:audioplayers/audioplayers.dart' as web_audio;
import 'package:web/web.dart' as web;
import '../models/radio_station.dart';
import '../utils/platform_utils.dart';
import '../config/debug_config.dart';

class RadioService {
  AudioPlayer? _player; // just_audio para nativo
  web_audio.AudioPlayer? _webPlayer; // audioplayers para web
  RadioStation? _currentStation;
  bool _isPlaying = false;
  double _currentVolume = 0.7; // Volumen actual (aumentado para mejor audibilidad)

  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;
  RadioService._internal();

  /// Inicializar servicio
  Future<void> initialize() async {
    if (PlatformUtils.isWeb) {
      if (_webPlayer == null) {
        debugLog('📻 [RadioService] Inicializando para web...');
        _webPlayer = web_audio.AudioPlayer();
        // Configurar el player para web
        await _webPlayer!.setReleaseMode(web_audio.ReleaseMode.stop);
        await _webPlayer!.setPlayerMode(web_audio.PlayerMode.mediaPlayer);
        // Aplicar volumen inicial
        await _webPlayer!.setVolume(_currentVolume);
        debugLog('✅ [RadioService] Inicializado para web correctamente');
      } else {
        debugLog('📻 [RadioService] Ya estaba inicializado para web');
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
    debugLog('🎵 [RadioService] playStation llamado para: ${station.name}');
    debugLog('🎵 [RadioService] URL: ${station.source}');
    debugLog('🎵 [RadioService] Platform.isWeb: ${PlatformUtils.isWeb}');
    
    // Siempre detener la reproducción actual antes de iniciar una nueva
    if (_isPlaying && _currentStation != null) {
      debugLog('🛑 [RadioService] Deteniendo reproducción anterior...');
      await stop();
      // Esperar un momento para asegurar que se detiene completamente
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // La URL ya viene actualizada desde el RadioProvider
    // No necesitamos verificar nada aquí, solo reproducir
    debugLog('🎵 [RadioService] Reproduciendo: ${station.name}');
    debugLog('🎵 [RadioService] URL: ${station.source}');
    
    if (PlatformUtils.isWeb) {
      await _playStationWeb(station);
      return;
    }
    await _playStationNative(station);
  }

  Future<void> _playStationWeb(RadioStation station) async {
    debugLog('🎵 [RadioService Web] _playStationWeb llamado para: ${station.name}');
    debugLog('🎵 [RadioService Web] URL de la estación: ${station.source}');
    try {
      // Si ya está reproduciendo la misma estación, no hacer nada
      if (_currentStation?.source == station.source && _isPlaying) {
        debugLog('ℹ️ [RadioService Web] Ya está reproduciendo la misma estación, omitiendo...');
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
          debugLog('⚠️ [RadioService Web] Reproducción detenida inesperadamente');
        }
      });
      
      _webPlayer!.onLog.listen((log) {
        debugLog('📻 [RadioService Web] Log: $log');
      });
      
      // En web, intentar primero con proxy si es necesario (listen2myradio.com)
      // Los streams HLS (.m3u8) de Mixcloud requieren hls.js
      String finalUrl = sourceUrl;
      bool useProxy = sourceUrl.contains('listen2myradio.com');
      bool isHLS = sourceUrl.contains('.m3u8');
      
      // Si es HLS, usar hls.js en lugar de audioplayers
      if (isHLS) {
        debugLog('🎵 [RadioService Web] Stream HLS detectado, usando hls.js: $sourceUrl');
        
        // Si es de Mixcloud, usar el proxy directamente (evita CORS y URLs expiradas)
        bool isMixcloud = sourceUrl.contains('mixcloud.com');
        
        try {
          String urlToPlay = sourceUrl;
          
          // Si es Mixcloud, usar proxy directamente
          if (isMixcloud) {
            // Asegurar que la URL termine en .m3u8 (no .m3u)
            String urlForProxy = sourceUrl;
            if (urlForProxy.endsWith('.m3u') && !urlForProxy.endsWith('.m3u8')) {
              urlForProxy = urlForProxy.replaceAll(RegExp(r'\.m3u$'), '.m3u8');
              debugLog('📻 [RadioService Web] URL convertida de .m3u a .m3u8: $urlForProxy');
            }
            final encodedUrl = Uri.encodeComponent(urlForProxy);
            urlToPlay = 'https://mobilev1.globalchat.org/api/mixcloud_stream_proxy.php?url=$encodedUrl';
            debugLog('📻 [RadioService Web] Usando proxy para Mixcloud: $urlToPlay');
          }
          
          await _playHLSStream(urlToPlay, 'hls-audio-player');
          // Establecer el volumen después de iniciar la reproducción
          await Future.delayed(const Duration(milliseconds: 1000));
          await setVolume(_currentVolume);
          
          // Verificar que realmente se está reproduciendo
          await Future.delayed(const Duration(milliseconds: 500));
          if (web.window.has('getHLSPlaybackState')) {
            final state = web.window.callMethodVarArgs<JSAny?>(
              'getHLSPlaybackState'.toJS,
              ['hls-audio-player'.toJS],
            );
            final stateObject = state?.dartify();
            if (stateObject is Map) {
              final paused = stateObject['paused'] as bool? ?? true;
              final volume = stateObject['volume'] as num? ?? 0.0;
              debugLog('📊 [RadioService Web] Estado HLS - Paused: $paused, Volume: $volume');
              
              if (paused) {
                debugLog('⚠️ [RadioService Web] El elemento está pausado, intentando reanudar...');
              }
            }
          }
          
          _currentStation = station;
          _isPlaying = true;
          debugLog('✅ [RadioService Web] Reproducción HLS iniciada correctamente');
          return; // Salir temprano si HLS funciona
        } catch (hlsError) {
          debugLog('❌ [RadioService Web] Error con HLS: $hlsError');
          
          // Si es Mixcloud y falló con proxy, intentar con URL directa como último recurso
          if (isMixcloud) {
            try {
              debugLog('🔄 [RadioService Web] Intentando con URL directa como último recurso...');
              await _playHLSStream(sourceUrl, 'hls-audio-player');
              await Future.delayed(const Duration(milliseconds: 1000));
              await setVolume(_currentVolume);
              _currentStation = station;
              _isPlaying = true;
              debugLog('✅ [RadioService Web] Reproducción HLS con URL directa iniciada');
              return;
            } catch (directError) {
              debugLog('❌ [RadioService Web] Error también con URL directa: $directError');
            }
          }
          
          throw Exception('No se pudo reproducir el stream HLS. Error: $hlsError');
        }
      } else if (useProxy) {
        try {
          final uri = Uri.parse(sourceUrl);
            // Proxy para otros servicios
            final proxyPath = '/radio-proxy/${uri.host}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
            final baseHref = web.window.location.href;
            if (baseHref.isNotEmpty) {
              final baseUri = Uri.parse(baseHref);
              finalUrl = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}$proxyPath';
              debugLog('📻 [RadioService Web] Intentando con proxy: $finalUrl');
          }
        } catch (e) {
          debugLog('⚠️ [RadioService Web] Error construyendo proxy, usando URL directa: $e');
          useProxy = false;
        }
      } else {
        debugLog('📻 [RadioService Web] Reproduciendo desde URL directa: $sourceUrl');
      }
      
      // Intentar reproducir
      try {
        debugLog('📻 [RadioService Web] Iniciando reproducción de: $finalUrl');
        await _webPlayer!.play(web_audio.UrlSource(finalUrl));
        
        // Esperar un momento para verificar si hay errores de reproducción
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Verificar el estado del player
        final playerState = _webPlayer!.state;
        debugLog('📻 [RadioService Web] Estado del player después de iniciar: $playerState');
        
        // Verificar si hay errores
        _webPlayer!.onPlayerComplete.listen((_) {
          debugLog('📻 [RadioService Web] Reproducción completada');
          _isPlaying = false;
        });
        
        // Verificar errores de reproducción
        _webPlayer!.onLog.listen((log) {
          debugLog('📻 [RadioService Web] Log del player: $log');
        });
        
        if (playerState == web_audio.PlayerState.stopped) {
          // Si es HLS y falló la URL directa, intentar con proxy (puede ser problema de CORS)
          if (isHLS && finalUrl == sourceUrl) {
            debugLog('⚠️ [RadioService Web] Stream HLS falló con URL directa, intentando con proxy...');
            try {
              // Asegurar que la URL termine en .m3u8 (no .m3u)
              String urlForProxy = sourceUrl;
              if (urlForProxy.endsWith('.m3u') && !urlForProxy.endsWith('.m3u8')) {
                urlForProxy = urlForProxy.replaceAll(RegExp(r'\.m3u$'), '.m3u8');
                debugLog('📻 [RadioService Web] URL convertida de .m3u a .m3u8: $urlForProxy');
              }
              final encodedUrl = Uri.encodeComponent(urlForProxy);
              final proxyUrl = 'https://mobilev1.globalchat.org/api/mixcloud_stream_proxy.php?url=$encodedUrl';
              await _webPlayer!.stop();
              await _webPlayer!.release();
              _webPlayer = web_audio.AudioPlayer();
              await _webPlayer!.setReleaseMode(web_audio.ReleaseMode.stop);
              await _webPlayer!.setPlayerMode(web_audio.PlayerMode.mediaPlayer);
              await _webPlayer!.setVolume(_currentVolume);
              debugLog('📻 [RadioService Web] Intentando con proxy: $proxyUrl');
              await _webPlayer!.play(web_audio.UrlSource(proxyUrl));
              await Future.delayed(const Duration(milliseconds: 1000));
              final retryState = _webPlayer!.state;
              debugLog('📻 [RadioService Web] Estado después de retry con proxy: $retryState');
              if (retryState == web_audio.PlayerState.stopped) {
                throw Exception('No se pudo iniciar la reproducción. El servidor puede tener restricciones CORS o la URL no es válida.');
              }
            } catch (retryError) {
              debugLog('❌ [RadioService Web] Error en retry con proxy: $retryError');
              throw Exception('No se pudo iniciar la reproducción. Error: $retryError');
            }
          } else if (useProxy && finalUrl != sourceUrl) {
            debugLog('⚠️ [RadioService Web] Proxy falló, intentando URL directa...');
            try {
              await _webPlayer!.stop();
              await _webPlayer!.release();
              _webPlayer = web_audio.AudioPlayer();
              await _webPlayer!.setReleaseMode(web_audio.ReleaseMode.stop);
              await _webPlayer!.setPlayerMode(web_audio.PlayerMode.mediaPlayer);
              await _webPlayer!.setVolume(_currentVolume);
              debugLog('📻 [RadioService Web] Intentando URL directa: $sourceUrl');
              await _webPlayer!.play(web_audio.UrlSource(sourceUrl));
              await Future.delayed(const Duration(milliseconds: 1000));
              final retryState = _webPlayer!.state;
              debugLog('📻 [RadioService Web] Estado después de retry: $retryState');
              if (retryState == web_audio.PlayerState.stopped) {
                throw Exception('No se pudo iniciar la reproducción. El servidor puede tener restricciones CORS o la URL no es válida.');
              }
            } catch (retryError) {
              debugLog('❌ [RadioService Web] Error en retry: $retryError');
              throw Exception('No se pudo iniciar la reproducción. Error: $retryError');
            }
          } else {
            throw Exception('No se pudo iniciar la reproducción. El servidor puede tener restricciones CORS o la URL no es válida.');
          }
        }
        
        // Si llegamos aquí, la reproducción debería estar funcionando
        debugLog('✅ [RadioService Web] Reproducción iniciada correctamente');
      } catch (playError) {
        debugLog('❌ [RadioService Web] Error al reproducir: $playError');
        // Si hay un error al reproducir y usamos proxy, intentar URL directa
        if (useProxy && finalUrl != sourceUrl) {
          debugLog('⚠️ [RadioService Web] Error con proxy, intentando URL directa...');
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
              rethrow;
            }
          } catch (retryError) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      
      // Verificar una vez más que el player esté realmente reproduciendo
      await Future.delayed(const Duration(milliseconds: 500));
      final finalState = _webPlayer!.state;
      debugLog('📻 [RadioService Web] Estado final antes de confirmar: $finalState');
      
      if (finalState == web_audio.PlayerState.playing) {
        _currentStation = station;
        _isPlaying = true;
        debugLog('✅ [RadioService Web] Reproducción confirmada: ${station.name}');
      } else {
        debugLog('⚠️ [RadioService Web] El player no está en estado playing, estado actual: $finalState');
        // Intentar una vez más
        if (finalState == web_audio.PlayerState.stopped || finalState == web_audio.PlayerState.paused) {
          try {
            await _webPlayer!.resume();
            await Future.delayed(const Duration(milliseconds: 500));
            if (_webPlayer!.state == web_audio.PlayerState.playing) {
              _currentStation = station;
              _isPlaying = true;
              debugLog('✅ [RadioService Web] Reproducción iniciada después de resume');
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
      debugLog('❌ [RadioService Web] Error reproduciendo ${station.name}: $e');
      debugLog('❌ [RadioService Web] URL: ${station.source}');
      debugLog('❌ [RadioService Web] Stack: $stackTrace');
      
      rethrow; // Re-lanzar el error para que el widget pueda manejarlo
    }
  }

  /// Reproducir stream HLS usando hls.js
  Future<void> _playHLSStream(String url, String audioElementId) async {
    try {
      debugLog('🎵 [RadioService Web] Intentando reproducir HLS: $url');
      
      if (!web.window.has('playHLSStream')) {
        final errorMsg = 'hls.js no está disponible. Asegúrate de que hls.js esté cargado en index.html';
        debugLog('❌ [RadioService Web] $errorMsg');
        throw Exception(errorMsg);
      }
      
      debugLog('✅ [RadioService Web] Función playHLSStream encontrada, llamando...');
      
      final promise = web.window.callMethodVarArgs<JSPromise<JSAny?>>(
        'playHLSStream'.toJS,
        [url.toJS, audioElementId.toJS],
      );
      
      await promise.toDart.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout al reproducir stream HLS (10 segundos)');
        },
      );
      
      debugLog('✅ [RadioService Web] Stream HLS iniciado correctamente');
    } catch (e, stackTrace) {
      debugLog('❌ [RadioService Web] Error al reproducir HLS: $e');
      debugLog('❌ [RadioService Web] Stack: $stackTrace');
      rethrow;
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
                // debugLog('🎵 [RadioService] Usando proxy local en puerto $proxyPort');
              }
            }
          } catch (e) {
            // debugLog('⚠️ [RadioService] Error usando proxy: $e');
          }
        }
        */
        
        await _player!.setUrl(playUrl);
        await _player!.play();
        _currentStation = station;
        _isPlaying = true;
        // debugLog('🎵 [RadioService] Reproduciendo: ${station.name}');
      }
    } catch (e) {
      _isPlaying = false;
      _currentStation = null;
      // debugLog('❌ [RadioService] Error reproduciendo: $e');
    }
  }

  /// Detener reproducción
  Future<void> stop() async {
    try {
      if (PlatformUtils.isWeb) {
        // Si es HLS, usar la función JavaScript para detener
        if (_currentStation?.source.contains('.m3u8') ?? false) {
          if (web.window.has('stopHLSStream')) {
            web.window.callMethodVarArgs<JSAny?>(
              'stopHLSStream'.toJS,
              ['hls-audio-player'.toJS],
            );
          }
        }
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
        // Si es HLS, pausar el elemento de audio directamente
        if (_currentStation?.source.contains('.m3u8') ?? false) {
          final audioElement = web.document.getElementById('hls-audio-player') as web.HTMLAudioElement?;
          if (audioElement != null) {
            audioElement.pause();
          }
        } else {
          await _webPlayer?.pause();
        }
        // debugLog('⏸️ [RadioService] Reproducción pausada en web');
      } else {
        await _player?.pause();
      }
      _isPlaying = false;
    } catch (e) {
      // debugLog('❌ [RadioService] Error al pausar: $e');
    }
  }

  /// Reanudar reproducción
  Future<void> resume() async {
    try {
      if (PlatformUtils.isWeb) {
        // Si es HLS, reanudar el elemento de audio directamente
        if (_currentStation?.source.contains('.m3u8') ?? false) {
          final audioElement = web.document.getElementById('hls-audio-player') as web.HTMLAudioElement?;
          if (audioElement != null) {
            debugLog('▶️ [RadioService Web] Reanudando reproducción HLS');
            await audioElement.play().toDart;
            debugLog('✅ [RadioService Web] Reproducción HLS reanudada');
          } else {
            debugLog('⚠️ [RadioService Web] No se encontró el elemento de audio HLS para reanudar');
          }
        } else {
          await _webPlayer?.resume();
        }
        // debugLog('▶️ [RadioService] Reproducción reanudada en web');
      } else {
        await _player?.play();
      }
      _isPlaying = true;
    } catch (e) {
      debugLog('❌ [RadioService Web] Error al reanudar: $e');
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
      // Si es HLS, actualizar el volumen del elemento de audio directamente
      if (_currentStation?.source.contains('.m3u8') ?? false) {
        if (web.window.has('setHLSVolume')) {
          web.window.callMethodVarArgs<JSAny?>(
            'setHLSVolume'.toJS,
            ['hls-audio-player'.toJS, _currentVolume.toJS],
          );
          debugLog('🔊 [RadioService Web] Volumen HLS establecido a: $_currentVolume (vía JS)');
        } else {
          // Fallback: usar el elemento de audio directamente
          final audioElement = web.document.getElementById('hls-audio-player') as web.HTMLAudioElement?;
          if (audioElement != null) {
            audioElement.volume = _currentVolume;
            debugLog('🔊 [RadioService Web] Volumen HLS establecido a: $_currentVolume (directo)');
          } else {
            debugLog('⚠️ [RadioService Web] No se encontró el elemento de audio HLS para establecer volumen');
          }
        }
      } else {
        await _webPlayer?.setVolume(_currentVolume);
      }
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
  }
}
