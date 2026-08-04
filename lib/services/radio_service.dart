import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../models/radio_station.dart';
import '../utils/platform_utils.dart';
import '../config/debug_config.dart';
import '../utils/radio_web_bridge_stub.dart'
    if (dart.library.html) '../utils/radio_web_bridge_web.dart';

class RadioService {
  AudioPlayer? _player;
  RadioStation? _currentStation;
  bool _isPlaying = false;
  double _currentVolume = 0.85;

  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;
  RadioService._internal();

  /// Inicializar servicio
  Future<void> initialize() async {
    if (_player == null) {
      debugLog('📻 [RadioService] Inicializando...');
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setPlayerMode(PlayerMode.mediaPlayer);
      await _player!.setVolume(_currentVolume);
      debugLog('✅ [RadioService] Inicializado correctamente');
    }
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

    await _playStationWeb(station);
  }

  Future<void> _playStationWeb(RadioStation station) async {
    debugLog(
      '🎵 [RadioService Web] _playStationWeb llamado para: ${station.name}',
    );
    debugLog('🎵 [RadioService Web] URL de la estación: ${station.source}');
    try {
      // Si ya está reproduciendo la misma estación, no hacer nada
      if (_currentStation?.source == station.source && _isPlaying) {
        debugLog(
          'ℹ️ [RadioService Web] Ya está reproduciendo la misma estación, omitiendo...',
        );
        return;
      }

      // Siempre detener y liberar cualquier reproducción anterior
      if (_player != null) {
        try {
          await _player!.stop();
          await _player!.release();
        } catch (e) {
          // Ignorar errores al detener
        }
        _player = null; // Limpiar referencia
        // Esperar un momento para asegurar que se libera completamente
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Crear nuevo player siempre (para evitar problemas con instancias anteriores)
      _player = AudioPlayer();

      // Configurar el player
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.setPlayerMode(PlayerMode.mediaPlayer);

      // Configurar volumen desde el estado guardado
      await _player!.setVolume(_currentVolume);

      // Verificar que la URL sea válida
      String sourceUrl = station.source;
      if (sourceUrl.isEmpty) {
        throw Exception('URL de la estación está vacía');
      }

      // Agregar listener para detectar errores
      _player!.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.stopped && _isPlaying) {
          // Si se detuvo inesperadamente, marcar como error
          _isPlaying = false;
          debugLog(
            '⚠️ [RadioService Web] Reproducción detenida inesperadamente',
          );
        }
      });

      _player!.onLog.listen((log) {
        debugLog('📻 [RadioService Web] Log: $log');
      });

      // En web, intentar primero con proxy si es necesario (listen2myradio.com)
      // Los streams HLS (.m3u8) de Mixcloud requieren hls.js
      // ponytail: HLS (hls.js) y el proxy de origen son features de JS, solo
      // disponibles en web. En Windows/Linux con audioplayers reproducimos la
      // URL directa; los streams HLS (.m3u8) no se soportan ahí (techo conocido).
      String finalUrl = sourceUrl;
      bool useProxy = PlatformUtils.isWeb && sourceUrl.contains('listen2myradio.com');
      bool isHLS = PlatformUtils.isWeb && sourceUrl.contains('.m3u8');

      // Si es HLS, usar hls.js en lugar de audioplayers
      if (isHLS) {
        debugLog(
          '🎵 [RadioService Web] Stream HLS detectado, usando hls.js: $sourceUrl',
        );

        // Si es de Mixcloud, usar el proxy directamente (evita CORS y URLs expiradas)
        bool isMixcloud = sourceUrl.contains('mixcloud.com');

        try {
          String urlToPlay = sourceUrl;

          // Si es Mixcloud, usar proxy directamente
          if (isMixcloud) {
            // Asegurar que la URL termine en .m3u8 (no .m3u)
            String urlForProxy = sourceUrl;
            if (urlForProxy.endsWith('.m3u') &&
                !urlForProxy.endsWith('.m3u8')) {
              urlForProxy = urlForProxy.replaceAll(RegExp(r'\.m3u$'), '.m3u8');
              debugLog(
                '📻 [RadioService Web] URL convertida de .m3u a .m3u8: $urlForProxy',
              );
            }
            final encodedUrl = Uri.encodeComponent(urlForProxy);
            urlToPlay =
                'https://mobilev1.globalchat.org/api/mixcloud_stream_proxy.php?url=$encodedUrl';
            debugLog(
              '📻 [RadioService Web] Usando proxy para Mixcloud: $urlToPlay',
            );
          }

          await _playHLSStream(urlToPlay, 'hls-audio-player');
          // Establecer el volumen después de iniciar la reproducción
          await Future.delayed(const Duration(milliseconds: 1000));
          await setVolume(_currentVolume);

          // Verificar que realmente se está reproduciendo
          await Future.delayed(const Duration(milliseconds: 500));
          final stateObject = getHlsPlaybackState('hls-audio-player');
          if (stateObject != null) {
            final paused = stateObject['paused'] as bool? ?? true;
            final volume = stateObject['volume'] as num? ?? 0.0;
            debugLog(
              '📊 [RadioService Web] Estado HLS - Paused: $paused, Volume: $volume',
            );

            if (paused) {
              debugLog(
                '⚠️ [RadioService Web] El elemento está pausado, intentando reanudar...',
              );
            }
          }

          _currentStation = station;
          _isPlaying = true;
          debugLog(
            '✅ [RadioService Web] Reproducción HLS iniciada correctamente',
          );
          return; // Salir temprano si HLS funciona
        } catch (hlsError) {
          debugLog('❌ [RadioService Web] Error con HLS: $hlsError');

          // Si es Mixcloud y falló con proxy, intentar con URL directa como último recurso
          if (isMixcloud) {
            try {
              debugLog(
                '🔄 [RadioService Web] Intentando con URL directa como último recurso...',
              );
              await _playHLSStream(sourceUrl, 'hls-audio-player');
              await Future.delayed(const Duration(milliseconds: 1000));
              await setVolume(_currentVolume);
              _currentStation = station;
              _isPlaying = true;
              debugLog(
                '✅ [RadioService Web] Reproducción HLS con URL directa iniciada',
              );
              return;
            } catch (directError) {
              debugLog(
                '❌ [RadioService Web] Error también con URL directa: $directError',
              );
            }
          }

          throw Exception(
            'No se pudo reproducir el stream HLS. Error: $hlsError',
          );
        }
      } else if (useProxy) {
        try {
          final uri = Uri.parse(sourceUrl);
          // Proxy para otros servicios
          final proxyPath =
              '/radio-proxy/${uri.host}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
          final origin = getWebPageOrigin();
          if (origin != null) {
            finalUrl = '$origin$proxyPath';
            debugLog('📻 [RadioService Web] Intentando con proxy: $finalUrl');
          }
        } catch (e) {
          debugLog(
            '⚠️ [RadioService Web] Error construyendo proxy, usando URL directa: $e',
          );
          useProxy = false;
        }
      } else {
        debugLog(
          '📻 [RadioService Web] Reproduciendo desde URL directa: $sourceUrl',
        );
      }

      // Intentar reproducir
      try {
        debugLog('📻 [RadioService Web] Iniciando reproducción de: $finalUrl');
        await _player!.play(UrlSource(finalUrl));

        // Esperar un momento para verificar si hay errores de reproducción
        await Future.delayed(const Duration(milliseconds: 1000));

        // Verificar el estado del player
        final playerState = _player!.state;
        debugLog(
          '📻 [RadioService Web] Estado del player después de iniciar: $playerState',
        );

        // Verificar si hay errores
        _player!.onPlayerComplete.listen((_) {
          debugLog('📻 [RadioService Web] Reproducción completada');
          _isPlaying = false;
        });

        // Verificar errores de reproducción
        _player!.onLog.listen((log) {
          debugLog('📻 [RadioService Web] Log del player: $log');
        });

        if (playerState == PlayerState.stopped) {
          // Si es HLS y falló la URL directa, intentar con proxy (puede ser problema de CORS)
          if (isHLS && finalUrl == sourceUrl) {
            debugLog(
              '⚠️ [RadioService Web] Stream HLS falló con URL directa, intentando con proxy...',
            );
            try {
              // Asegurar que la URL termine en .m3u8 (no .m3u)
              String urlForProxy = sourceUrl;
              if (urlForProxy.endsWith('.m3u') &&
                  !urlForProxy.endsWith('.m3u8')) {
                urlForProxy = urlForProxy.replaceAll(
                  RegExp(r'\.m3u$'),
                  '.m3u8',
                );
                debugLog(
                  '📻 [RadioService Web] URL convertida de .m3u a .m3u8: $urlForProxy',
                );
              }
              final encodedUrl = Uri.encodeComponent(urlForProxy);
              final proxyUrl =
                  'https://mobilev1.globalchat.org/api/mixcloud_stream_proxy.php?url=$encodedUrl';
              await _player!.stop();
              await _player!.release();
              _player = AudioPlayer();
              await _player!.setReleaseMode(ReleaseMode.stop);
              await _player!.setPlayerMode(PlayerMode.mediaPlayer);
              await _player!.setVolume(_currentVolume);
              debugLog('📻 [RadioService Web] Intentando con proxy: $proxyUrl');
              await _player!.play(UrlSource(proxyUrl));
              await Future.delayed(const Duration(milliseconds: 1000));
              final retryState = _player!.state;
              debugLog(
                '📻 [RadioService Web] Estado después de retry con proxy: $retryState',
              );
              if (retryState == PlayerState.stopped) {
                throw Exception(
                  'No se pudo iniciar la reproducción. El servidor puede tener restricciones CORS o la URL no es válida.',
                );
              }
            } catch (retryError) {
              debugLog(
                '❌ [RadioService Web] Error en retry con proxy: $retryError',
              );
              throw Exception(
                'No se pudo iniciar la reproducción. Error: $retryError',
              );
            }
          } else if (useProxy && finalUrl != sourceUrl) {
            debugLog(
              '⚠️ [RadioService Web] Proxy falló, intentando URL directa...',
            );
            try {
              await _player!.stop();
              await _player!.release();
              _player = AudioPlayer();
              await _player!.setReleaseMode(ReleaseMode.stop);
              await _player!.setPlayerMode(PlayerMode.mediaPlayer);
              await _player!.setVolume(_currentVolume);
              debugLog(
                '📻 [RadioService Web] Intentando URL directa: $sourceUrl',
              );
              await _player!.play(UrlSource(sourceUrl));
              await Future.delayed(const Duration(milliseconds: 1000));
              final retryState = _player!.state;
              debugLog(
                '📻 [RadioService Web] Estado después de retry: $retryState',
              );
              if (retryState == PlayerState.stopped) {
                throw Exception(
                  'No se pudo iniciar la reproducción. El servidor puede tener restricciones CORS o la URL no es válida.',
                );
              }
            } catch (retryError) {
              debugLog('❌ [RadioService Web] Error en retry: $retryError');
              throw Exception(
                'No se pudo iniciar la reproducción. Error: $retryError',
              );
            }
          } else {
            throw Exception(
              'No se pudo iniciar la reproducción. El servidor puede tener restricciones CORS o la URL no es válida.',
            );
          }
        }

        // Si llegamos aquí, la reproducción debería estar funcionando
        debugLog('✅ [RadioService Web] Reproducción iniciada correctamente');
      } catch (playError) {
        debugLog('❌ [RadioService Web] Error al reproducir: $playError');
        // Si hay un error al reproducir y usamos proxy, intentar URL directa
        if (useProxy && finalUrl != sourceUrl) {
          debugLog(
            '⚠️ [RadioService Web] Error con proxy, intentando URL directa...',
          );
          try {
            await _player!.stop();
            await _player!.release();
            _player = AudioPlayer();
            await _player!.setReleaseMode(ReleaseMode.stop);
            await _player!.setPlayerMode(PlayerMode.mediaPlayer);
            await _player!.setVolume(_currentVolume);
            await _player!.play(UrlSource(sourceUrl));
            await Future.delayed(const Duration(milliseconds: 800));
            final retryState = _player!.state;
            if (retryState == PlayerState.stopped &&
                _isPlaying == false) {
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
      final finalState = _player!.state;
      debugLog(
        '📻 [RadioService Web] Estado final antes de confirmar: $finalState',
      );

      if (finalState == PlayerState.playing) {
        _currentStation = station;
        _isPlaying = true;
        debugLog(
          '✅ [RadioService Web] Reproducción confirmada: ${station.name}',
        );
      } else {
        debugLog(
          '⚠️ [RadioService Web] El player no está en estado playing, estado actual: $finalState',
        );
        // Intentar una vez más
        if (finalState == PlayerState.stopped ||
            finalState == PlayerState.paused) {
          try {
            await _player!.resume();
            await Future.delayed(const Duration(milliseconds: 500));
            if (_player!.state == PlayerState.playing) {
              _currentStation = station;
              _isPlaying = true;
              debugLog(
                '✅ [RadioService Web] Reproducción iniciada después de resume',
              );
            } else {
              throw Exception(
                'No se pudo iniciar la reproducción después de varios intentos',
              );
            }
          } catch (e) {
            throw Exception(
              'No se pudo iniciar la reproducción. Estado: $finalState, Error: $e',
            );
          }
        }
      }
    } catch (e, stackTrace) {
      _isPlaying = false;
      _currentStation = null;
      // Limpiar player en caso de error
      try {
        await _player?.stop();
        await _player?.release();
      } catch (_) {}
      _player = null;

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

      debugLog(
        '✅ [RadioService Web] Función playHLSStream encontrada, llamando...',
      );

      await playHlsStream(url, audioElementId);

      debugLog('✅ [RadioService Web] Stream HLS iniciado correctamente');
    } catch (e, stackTrace) {
      debugLog('❌ [RadioService Web] Error al reproducir HLS: $e');
      debugLog('❌ [RadioService Web] Stack: $stackTrace');
      rethrow;
    }
  }

  /// Detener reproducción
  Future<void> stop() async {
    try {
      if (_currentStation?.source.contains('.m3u8') ?? false) {
        stopHlsStream('hls-audio-player');
      }
      if (_player != null) {
        await _player!.stop();
        await _player!.release();
        _player = null;
      }
      _isPlaying = false;
      _currentStation = null;
    } catch (e) {
      _isPlaying = false;
      _currentStation = null;
      _player = null;
    }
  }

  /// Pausar reproducción
  Future<void> pause() async {
    try {
      if (_currentStation?.source.contains('.m3u8') ?? false) {
        pauseHlsAudio('hls-audio-player');
      } else {
        await _player?.pause();
      }
      _isPlaying = false;
    } catch (e) {
    }
  }

  /// Reanudar reproducción
  Future<void> resume() async {
    try {
      if (_currentStation?.source.contains('.m3u8') ?? false) {
        await resumeHlsAudio('hls-audio-player');
      } else {
        await _player?.resume();
      }
      _isPlaying = true;
    } catch (e) {
    }
  }

  /// Obtener estación actual
  RadioStation? get currentStation => _currentStation;

  /// Verificar si está reproduciendo
  bool get isPlaying => _isPlaying;

  /// Establecer volumen (0.0 a 1.0)
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
    if (_currentStation?.source.contains('.m3u8') ?? false) {
      setHlsAudioVolume('hls-audio-player', _currentVolume);
    } else {
      await _player?.setVolume(_currentVolume);
    }
  }

  /// Obtener volumen actual
  double get currentVolume => _currentVolume;

  /// Liberar recursos
  Future<void> dispose() async {
    await stop();
    await _player?.dispose();
  }
}
