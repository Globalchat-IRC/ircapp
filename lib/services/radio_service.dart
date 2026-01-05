import 'dart:io';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audioplayers/audioplayers.dart' as web_audio;
import 'package:audio_session/audio_session.dart' show AudioSession, AudioSessionConfiguration, AVAudioSessionCategory, AVAudioSessionCategoryOptions, AVAudioSessionMode, AVAudioSessionRouteSharingPolicy, AVAudioSessionSetActiveOptions, AndroidAudioAttributes, AndroidAudioContentType, AndroidAudioFlags, AndroidAudioUsage, AndroidAudioFocusGainType;
import '../models/radio_station.dart';
import 'stream_proxy_service.dart';
import '../main.dart' show globalLog;
import '../utils/platform_utils.dart';

class RadioService {
  AudioPlayer? _player; // just_audio para nativo
  web_audio.AudioPlayer? _webPlayer; // audioplayers para web
  RadioStation? _currentStation;
  bool _isPlaying = false;
  double _volume = 1.0; // Volumen inicial al máximo
  final StreamProxyService _proxy = StreamProxyService.instance;
  AudioSession? _audioSession;
  bool _isInitialized = false;
  Completer<void>? _initializationCompleter;

  RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;
  bool get isInitialized => _isInitialized;

  RadioService() {
    if (PlatformUtils.isWeb) {
      _webPlayer = web_audio.AudioPlayer();
    } else {
      _player = AudioPlayer();
    }
    _initializeAudio();
  }

  /// Espera a que el servicio esté completamente inicializado
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }
    _initializationCompleter = Completer<void>();
    await _initializeAudio();
    _initializationCompleter!.complete();
  }

  Future<void> _initializeAudio() async {
    // En web, usar audioplayers (más compatible)
    if (PlatformUtils.isWeb) {
      globalLog('[RadioService] Inicializando para web con audioplayers');
      _isInitialized = true;
      return;
    }
    
    // Configurar sesión de audio solo en plataformas móviles (iOS/Android)
    // Windows y macOS desktop no necesitan esta configuración
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        _audioSession = await AudioSession.instance;
        await _audioSession!.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: false,
        ));
        
        // Activar la sesión inmediatamente después de configurarla
        await _audioSession!.setActive(true);
        print('✅ Audio session activada después de configurar');
        print('✅ Audio session configurada correctamente');
      } catch (e) {
        print('⚠️ Error configurando audio session: $e');
      }
    } else {
      print('ℹ️ Audio session no requerida en ${Platform.operatingSystem}');
    }
    
    // Iniciar el proxy local (solo en macOS/iOS, no en Android, Windows ni Web)
    if (!PlatformUtils.isWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        globalLog('[RadioService] Iniciando proxy...');
        await _proxy.start();
        // Verificar que el proxy esté realmente listo
        final proxyUrl = _proxy.getProxyUrl('https://test.com');
        if (proxyUrl != null) {
          globalLog('[RadioService] ✅ Proxy iniciado correctamente y listo para usar en: $proxyUrl');
        } else {
          globalLog('[RadioService] ⚠️ Proxy iniciado pero getProxyUrl retorna null');
        }
      } catch (e, stackTrace) {
        globalLog('[RadioService] ❌ Error iniciando proxy: $e');
        globalLog('[RadioService] Stack trace: $stackTrace');
        globalLog('[RadioService] ⚠️ Las estaciones pueden no funcionar sin el proxy');
      }
    } else {
      globalLog('[RadioService] ℹ️ Proxy no requerido en web');
    }
    
    // Configurar el player para streams de radio (solo en nativo)
    if (_player != null) {
      await _player!.setVolume(_volume);
      _player!.setLoopMode(LoopMode.one); // Para streams de radio continuos
      
      // Escuchar cambios de estado
      _player!.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        print('🎵 Estado del player: playing=${state.playing}, processingState=${state.processingState}');
      });
      
      // Escuchar errores
      _player!.playbackEventStream.listen((event) {
        print('🎵 Playback event: ${event.processingState}');
      });
    }
    
    // Marcar como inicializado
    _isInitialized = true;
    globalLog('[RadioService] ✅ RadioService completamente inicializado');
  }

  Future<void> playStation(RadioStation station) async {
    try {
      // Asegurar que el servicio esté completamente inicializado antes de reproducir
      // Esto es crítico en release donde la inicialización puede no estar completa
      globalLog('[RadioService] Verificando inicialización antes de reproducir...');
      await ensureInitialized();
      globalLog('[RadioService] ✅ Servicio inicializado, procediendo con reproducción');
      
      globalLog('[RadioService] ===== INICIANDO REPRODUCCIÓN =====');
      globalLog('[RadioService] Estación: ${station.name}');
      globalLog('[RadioService] URL: ${station.source}');
      
      // Validar que la URL tenga un formato válido
      final uri = Uri.tryParse(station.source);
      if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw Exception('URL del stream no es válida: ${station.source}');
      }
      
      print('🎵 URL validada correctamente');
      
      // Log específico para Radio Sonic Frequency
      if (station.name.contains('Sonic Frequency') || station.source.contains('listen2myradio.com') || station.source.contains('radio12345.com')) {
        print('🎙️ [SONIC FREQUENCY] Detectada estación Sonic Frequency');
        print('🎙️ [SONIC FREQUENCY] URL: ${station.source}');
        print('🎙️ [SONIC FREQUENCY] Verificando accesibilidad...');
        
        // Verificar si la URL es válida
        if (station.source.contains('radio12345.com') || station.source.contains('fdsfdsfdsf')) {
          print('⚠️ [SONIC FREQUENCY] ADVERTENCIA: URL parece ser de prueba y puede no funcionar');
          print('⚠️ [SONIC FREQUENCY] Si esta URL no funciona, necesitas actualizar la URL en radio_provider.dart');
        }
      }
      
      // Seleccionar URL según la plataforma:
      // - Android y Windows: URL directa (mejor compatibilidad)
      // - macOS/iOS: Proxy si está disponible
      String streamUrl = station.source;
      
      if (Platform.isIOS || Platform.isMacOS) {
        // En macOS/iOS, asegurar que el proxy esté iniciado antes de obtener la URL
        try {
          globalLog('[RadioService] Verificando/iniciando proxy antes de obtener URL...');
          await _proxy.start();
          // Pequeña espera para asegurar que el servidor esté completamente listo
          await Future.delayed(const Duration(milliseconds: 50));
          globalLog('[RadioService] Proxy verificado/iniciado');
        } catch (e, stackTrace) {
          globalLog('[RadioService] ⚠️ Error verificando proxy: $e');
          globalLog('[RadioService] Stack trace: $stackTrace');
        }
        
        // En macOS/iOS, usar proxy si está disponible
        final proxyUrl = _proxy.getProxyUrl(station.source);
        if (proxyUrl != null) {
          streamUrl = proxyUrl;
          globalLog('[RadioService] ✅ Usando proxy: $streamUrl');
          globalLog('[RadioService] URL original: ${station.source}');
        } else {
          globalLog('[RadioService] ⚠️ Proxy no disponible (getProxyUrl retorna null), usando URL directa');
          streamUrl = station.source;
        }
      } else {
        // En Android y Windows, usar siempre URL directa
        print('🎵 ${Platform.operatingSystem}: Usando URL directa (sin proxy)');
        print('🎵 URL directa: ${station.source}');
        streamUrl = station.source;
      }
      
      // Si es una estación diferente, cambiar la fuente y reproducir
      if (_currentStation?.source != station.source) {
        print('🎵 Cambiando de estación...');
        print('🎵 Estación anterior: ${_currentStation?.name ?? "ninguna"}');
        
        // Detener reproducción actual
        try {
          if (PlatformUtils.isWeb && _webPlayer != null) {
            await _webPlayer!.stop();
          } else if (_player != null) {
            await _player!.stop();
          }
          print('🎵 Player detenido');
        } catch (e) {
          print('⚠️ Error al detener (puede ignorarse): $e');
        }
        
        // Esperar un momento para que el player se limpie
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Activar sesión de audio ANTES de configurar la URL (solo en móviles)
        if (_audioSession != null && (Platform.isAndroid || Platform.isIOS)) {
          try {
            await _audioSession!.setActive(true);
            print('✅ Audio session activada ANTES de configurar URL');
          } catch (e) {
            print('⚠️ Error activando audio session: $e');
          }
        }
        
        // Asegurar que el volumen esté al máximo ANTES de configurar la URL
        if (PlatformUtils.isWeb && _webPlayer != null) {
          await _webPlayer!.setVolume(1.0);
        } else if (_player != null) {
          await _player!.setVolume(1.0);
        }
        print('🎵 Volumen configurado a 1.0 ANTES de configurar URL');
        
        print('🎵 Configurando nueva fuente...');
        print('🎵 URL a usar: $streamUrl');
        
        // Establecer la fuente del audio
        // En web, usar audioplayers directamente (ya se hizo arriba, esto es para nativo)
        if (PlatformUtils.isWeb) {
          // Ya se manejó arriba, no debería llegar aquí
          return;
        }
        
        // Para listen2myradio.com, usar SIEMPRE el proxy en macOS/iOS
        if (streamUrl.contains('listen2myradio.com')) {
          print('🎙️ [SONIC FREQUENCY] Detectada estación listen2myradio.com');
          print('🎙️ [SONIC FREQUENCY] URL original: ${station.source}');
          
          // En macOS/iOS, SIEMPRE usar el proxy para listen2myradio.com
          if (Platform.isMacOS || Platform.isIOS) {
            // Asegurar que el proxy esté iniciado y completamente listo
            try {
              globalLog('[RadioService] [SONIC FREQUENCY] Iniciando/verificando proxy...');
              await _proxy.start();
              // Esperar un momento adicional para asegurar que el servidor esté completamente listo
              await Future.delayed(const Duration(milliseconds: 100));
              
              // Verificar que el proxy realmente funciona
              final testProxyUrl = _proxy.getProxyUrl('https://test.com');
              if (testProxyUrl != null) {
                globalLog('[RadioService] [SONIC FREQUENCY] ✅ Proxy iniciado/verificado y listo en: $testProxyUrl');
              } else {
                globalLog('[RadioService] [SONIC FREQUENCY] ⚠️ Proxy iniciado pero getProxyUrl retorna null');
              }
            } catch (e, stackTrace) {
              globalLog('[RadioService] [SONIC FREQUENCY] ❌ Error iniciando proxy: $e');
              globalLog('[RadioService] [SONIC FREQUENCY] Stack trace: $stackTrace');
            }
            
            final proxyUrl = _proxy.getProxyUrl(station.source);
            if (proxyUrl != null) {
              streamUrl = proxyUrl;
              globalLog('[RadioService] [SONIC FREQUENCY] ✅ Usando proxy: $streamUrl');
            } else {
              globalLog('[RadioService] [SONIC FREQUENCY] ⚠️ Proxy no disponible (getProxyUrl retorna null), intentando URL directa');
            }
          }
          
          print('🎙️ [SONIC FREQUENCY] Intentando múltiples variantes de URL...');
          List<String> urlVariants = [];
          
          // Prioridad 1: Proxy (si está disponible en macOS/iOS)
          if (Platform.isMacOS || Platform.isIOS) {
            final proxyUrl = _proxy.getProxyUrl(station.source);
            if (proxyUrl != null) {
              urlVariants.add(proxyUrl);
              print('🎙️ [SONIC FREQUENCY] Variante 1: Proxy URL');
            }
          }
          
          // Prioridad 2: URL original directa
          urlVariants.add(station.source);
          
          // Prioridad 3: URL sin parámetros
          if (station.source.contains('?')) {
            urlVariants.add(station.source.split('?')[0]);
          }
          
          // Prioridad 4: URL base simplificada
          urlVariants.add('https://uk18freenew.listen2myradio.com/live.mp3');
          
          // Prioridad 5: Intentar sin el subdominio específico
          if (station.source.contains('uk18freenew')) {
            urlVariants.add('https://listen2myradio.com/live.mp3');
          }
          
          bool success = false;
          Exception? lastError;
          for (int i = 0; i < urlVariants.length; i++) {
            final variant = urlVariants[i];
            print('🎙️ [SONIC FREQUENCY] Intentando variante ${i + 1}/${urlVariants.length}: $variant');
            try {
              // Para macOS/iOS, si es proxy, no usar headers (el proxy los maneja)
              // Si es URL directa, usar headers
              if (_player != null) {
                if (Platform.isMacOS || Platform.isIOS) {
                  if (variant.contains('localhost')) {
                    // Es proxy, no usar headers
                    await _player!.setUrl(variant);
                    print('🎙️ [SONIC FREQUENCY] Proxy URL configurada sin headers');
                  } else {
                    // Es URL directa, usar headers
                    await _player!.setUrl(variant, headers: {
                      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      'Accept': '*/*',
                      'Referer': 'https://listen2myradio.com/',
                      'Origin': 'https://listen2myradio.com',
                      'Accept-Encoding': 'identity',
                    });
                    print('🎙️ [SONIC FREQUENCY] URL directa configurada con headers');
                  }
                } else {
                  await _player!.setUrl(variant);
                }
                
                // Esperar un momento para verificar que la URL se configuró correctamente
                await Future.delayed(const Duration(milliseconds: 300));
                
                // Verificar el estado del player para confirmar que la URL funcionó
                final state = _player!.playerState;
                if (state.processingState == ProcessingState.ready || 
                    state.processingState == ProcessingState.buffering ||
                    state.processingState == ProcessingState.loading) {
                  print('✅ [SONIC FREQUENCY] Variante ${i + 1} funcionó! Estado: ${state.processingState}');
                  streamUrl = variant; // Actualizar streamUrl con la variante que funcionó
                  success = true;
                  break;
                } else {
                  throw Exception('Player no está listo. Estado: ${state.processingState}');
                }
              }
            } catch (err, stackTrace) {
              lastError = err is Exception ? err : Exception(err.toString());
              print('❌ [SONIC FREQUENCY] Variante ${i + 1} falló: $err');
              print('❌ [SONIC FREQUENCY] Stack trace: $stackTrace');
              if (i == urlVariants.length - 1) {
                // Última variante
                print('❌ [SONIC FREQUENCY] Todas las variantes fallaron');
              }
            }
          }
          if (!success) {
            throw lastError ?? Exception('Todas las variantes de URL fallaron para listen2myradio.com');
          }
        } else if (_player != null) {
          if (Platform.isWindows) {
            // En Windows, intentar primero sin headers (mejor compatibilidad)
            print('🎵 Windows: Configurando sin headers personalizados');
            try {
              await _player!.setUrl(streamUrl);
              print('🎵 Fuente configurada correctamente (sin headers)');
            } catch (e) {
              print('❌ Error configurando URL en Windows: $e');
              rethrow;
            }
          } else {
            // En otras plataformas, usar headers
            // Headers específicos para listen2myradio.com
            Map<String, String> headers = {
              'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': '*/*',
              'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
              'Connection': 'keep-alive',
            };
            
            // Headers adicionales para listen2myradio.com
            if (streamUrl.contains('listen2myradio.com')) {
              headers['Referer'] = 'https://listen2myradio.com/';
              headers['Origin'] = 'https://listen2myradio.com';
              headers['Accept-Encoding'] = 'identity'; // Sin compresión para streams
              print('🎙️ [SONIC FREQUENCY] Aplicando headers específicos para listen2myradio.com');
            }
            
            try {
              await _player!.setUrl(streamUrl, headers: headers);
              print('🎵 Fuente configurada correctamente (con headers)');
            } catch (e) {
              print('❌ Error configurando URL: $e');
              // Si falla, intentar sin headers
              if (Platform.isAndroid || streamUrl.contains('listen2myradio.com')) {
                print('🔄 Intentando sin headers personalizados...');
                try {
                  await _player!.setUrl(streamUrl);
                  print('🎵 Fuente configurada sin headers');
                } catch (e2) {
                  print('❌ También falló sin headers: $e2');
                  // Último intento: probar con URL sin parámetros de query
                  if (streamUrl.contains('listen2myradio.com')) {
                    print('🔄 [SONIC FREQUENCY] Intentando con URL simplificada...');
                    try {
                      final baseUrl = streamUrl.split('?')[0];
                      await _player!.setUrl(baseUrl);
                      print('🎵 Fuente configurada con URL simplificada');
                    } catch (e3) {
                      print('❌ También falló con URL simplificada: $e3');
                      rethrow;
                    }
                  } else {
                    rethrow;
                  }
                }
              } else {
                rethrow;
              }
            }
          }
        }
        
        // Esperar un momento para que se cargue
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verificar y configurar volumen de nuevo después de setUrl
        if (_player != null) {
          await _player!.setVolume(1.0);
          final volumeBeforePlay = await _player!.volume;
        print('🎵 Volumen antes de play: $volumeBeforePlay');
        
        print('🎵 Iniciando reproducción...');
        
        // Asegurar que la sesión de audio esté activa (solo en móviles)
        if (_audioSession != null && (Platform.isAndroid || Platform.isIOS)) {
          try {
            await _audioSession!.setActive(true);
            print('✅ Audio session activada antes de play');
          } catch (e) {
            print('⚠️ Error activando audio session: $e');
          }
        }
        
        // Reproducir
        if (_player != null) {
          await _player!.play();
          print('🎵 Comando play() enviado');
          
          // Verificar volumen después de play
          await Future.delayed(const Duration(milliseconds: 200));
          final currentVolume = await _player!.volume;
          print('🎵 Volumen actual del player después de play: $currentVolume');
          
          _currentStation = station;
          
          // Esperar un momento y verificar el estado
          await Future.delayed(const Duration(milliseconds: 1500));
          final currentState = _player!.playerState;
          _isPlaying = currentState.playing;
          print('🎵 Estado final: playing=$_isPlaying, processingState=${currentState.processingState}');
          
          // Solo lanzar error si realmente hay un problema
          // Si está en estado ready o buffering, está bien (puede estar cargando)
          if (!_isPlaying && currentState.processingState == ProcessingState.idle) {
          print('⚠️ El player se detuvo, puede que la URL no sea compatible');
          print('⚠️ Estado: playing=$_isPlaying, processingState=${currentState.processingState}');
          
          // Esperar un poco más y verificar de nuevo (a veces tarda en iniciar)
          await Future.delayed(const Duration(milliseconds: 2000));
          if (_player != null) {
            final retryState = _player!.playerState;
            _isPlaying = retryState.playing;
          
          // Solo lanzar error si después de esperar sigue en idle y no está reproduciendo
          // Si está en ready o buffering, está bien (puede estar cargando el stream)
          if (!_isPlaying && retryState.processingState == ProcessingState.idle) {
            print('❌ Después de esperar, sigue sin reproducir');
            print('❌ Estado final: playing=$_isPlaying, processingState=${retryState.processingState}');
            throw Exception('No se pudo reproducir el stream. Verifica que la URL sea válida y accesible.');
          } else {
            print('✅ Reproducción iniciada o cargando (processingState: ${retryState.processingState})');
            _isPlaying = retryState.playing || retryState.processingState != ProcessingState.idle;
          }
        } else {
          // Si está en ready, buffering o playing, está bien
          print('✅ Reproducción iniciada correctamente (playing=$_isPlaying, processingState=${currentState.processingState})');
        }
        
        print('🎵 ✅ Reproducción iniciada: $_isPlaying');
      } else {
        // Misma estación, solo reanudar si está pausada
        print('🎵 Reanudando estación actual...');
        await _player.play();
        _isPlaying = true;
        print('🎵 Reproducción reanudada');
      }
    } catch (e, stackTrace) {
      globalLog('[RadioService] ===== ERROR REPRODUCIENDO ESTACIÓN =====');
      globalLog('[RadioService] Estación: ${station.name}');
      globalLog('[RadioService] URL: ${station.source}');
      globalLog('[RadioService] Error: $e');
      globalLog('[RadioService] Tipo de error: ${e.runtimeType}');
      globalLog('[RadioService] Stack trace: $stackTrace');
      _isPlaying = false;
      rethrow;
    }
  }

  Future<void> pause() async {
    if (PlatformUtils.isWeb && _webPlayer != null) {
      await _webPlayer!.pause();
    } else if (_player != null) {
      await _player!.pause();
    }
    _isPlaying = false;
  }

  Future<void> resume() async {
    if (PlatformUtils.isWeb && _webPlayer != null) {
      await _webPlayer!.resume();
    } else if (_player != null) {
      await _player!.play();
    }
    _isPlaying = true;
  }

  Future<void> stop() async {
    if (PlatformUtils.isWeb && _webPlayer != null) {
      await _webPlayer!.stop();
    } else if (_player != null) {
      await _player!.stop();
    }
    _isPlaying = false;
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (PlatformUtils.isWeb && _webPlayer != null) {
      await _webPlayer!.setVolume(_volume);
    } else if (_player != null) {
      await _player!.setVolume(_volume);
    }
  }

  void dispose() {
    _player?.dispose();
    _webPlayer?.dispose();
    if (!PlatformUtils.isWeb) {
      _proxy.stop();
    }
  }
}
