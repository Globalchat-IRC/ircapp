import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart' show AudioSession, AudioSessionConfiguration, AVAudioSessionCategory, AVAudioSessionCategoryOptions, AVAudioSessionMode, AVAudioSessionRouteSharingPolicy, AVAudioSessionSetActiveOptions, AndroidAudioAttributes, AndroidAudioContentType, AndroidAudioFlags, AndroidAudioUsage, AndroidAudioFocusGainType;
import '../models/radio_station.dart';
import 'stream_proxy_service.dart';

class RadioService {
  final AudioPlayer _player = AudioPlayer();
  RadioStation? _currentStation;
  bool _isPlaying = false;
  double _volume = 1.0; // Volumen inicial al máximo
  final StreamProxyService _proxy = StreamProxyService.instance;
  AudioSession? _audioSession;

  RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  RadioService() {
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    try {
      // Configurar sesión de audio (especialmente importante en Android)
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
    
    // Iniciar el proxy local y esperar a que esté listo (solo en macOS/iOS)
    if (!Platform.isAndroid) {
    _proxy.start().then((_) {
      print('✅ Proxy listo para usar');
    }).catchError((e) {
      print('⚠️ Error iniciando proxy: $e');
      print('⚠️ Las estaciones pueden no funcionar sin el proxy');
    });
    }
    
    // Configurar el player para streams de radio
    await _player.setVolume(_volume);
    _player.setLoopMode(LoopMode.one); // Para streams de radio continuos
    
    // Escuchar cambios de estado
    _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      print('🎵 Estado del player: playing=${state.playing}, processingState=${state.processingState}');
    });
    
    // Escuchar errores
    _player.playbackEventStream.listen((event) {
      print('🎵 Playback event: ${event.processingState}');
    });
    
    // Escuchar errores del player
    _player.playerStateStream.listen((state) {
      print('🎵 Player state: playing=${state.playing}, processingState=${state.processingState}');
    });
  }

  Future<void> playStation(RadioStation station) async {
    try {
      print('🎵 ===== INICIANDO REPRODUCCIÓN =====');
      print('🎵 Estación: ${station.name}');
      print('🎵 URL: ${station.source}');
      
      // Validar que la URL tenga un formato válido
      final uri = Uri.tryParse(station.source);
      if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        throw Exception('URL del stream no es válida: ${station.source}');
      }
      
      print('🎵 URL validada correctamente');
      
      // En Android, usar URL directa (el proxy puede causar problemas)
      // En otras plataformas, intentar usar proxy primero
      String streamUrl = station.source;
      
      if (!Platform.isAndroid) {
        // En macOS/iOS, usar proxy si está disponible
      final proxyUrl = _proxy.getProxyUrl(station.source);
      if (proxyUrl != null) {
        streamUrl = proxyUrl;
        print('🎵 Usando proxy: $streamUrl');
        print('🎵 URL original: ${station.source}');
      } else {
          print('⚠️ Proxy no disponible, usando URL directa');
          streamUrl = station.source;
        }
      } else {
        // En Android, usar siempre URL directa
        print('🎵 Android: Usando URL directa (sin proxy)');
        print('🎵 URL directa: ${station.source}');
        streamUrl = station.source;
      }
      
      // Si es una estación diferente, cambiar la fuente y reproducir
      if (_currentStation?.source != station.source) {
        print('🎵 Cambiando de estación...');
        print('🎵 Estación anterior: ${_currentStation?.name ?? "ninguna"}');
        
        // Detener reproducción actual
        try {
          await _player.stop();
          print('🎵 Player detenido');
        } catch (e) {
          print('⚠️ Error al detener (puede ignorarse): $e');
        }
        
        // Esperar un momento para que el player se limpie
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Activar sesión de audio ANTES de configurar la URL (especialmente importante en Android)
        if (_audioSession != null) {
          try {
            await _audioSession!.setActive(true);
            print('✅ Audio session activada ANTES de configurar URL');
          } catch (e) {
            print('⚠️ Error activando audio session: $e');
          }
        }
        
        // Asegurar que el volumen esté al máximo ANTES de configurar la URL
        await _player.setVolume(1.0);
        print('🎵 Volumen configurado a 1.0 ANTES de configurar URL');
        
        print('🎵 Configurando nueva fuente...');
        print('🎵 URL a usar: $streamUrl');
        // Establecer la fuente del audio
        try {
          await _player.setUrl(streamUrl, headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': '*/*',
            'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
            'Connection': 'keep-alive',
          });
          print('🎵 Fuente configurada correctamente');
        } catch (e) {
          print('❌ Error configurando URL: $e');
          // Si falla, intentar sin headers en Android
          if (Platform.isAndroid) {
            print('🔄 Intentando sin headers personalizados...');
            try {
        await _player.setUrl(streamUrl);
              print('🎵 Fuente configurada sin headers');
            } catch (e2) {
              print('❌ También falló sin headers: $e2');
              rethrow;
            }
          } else {
            rethrow;
          }
        }
        
        // Esperar un momento para que se cargue
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verificar y configurar volumen de nuevo después de setUrl
        await _player.setVolume(1.0);
        final volumeBeforePlay = await _player.volume;
        print('🎵 Volumen antes de play: $volumeBeforePlay');
        
        print('🎵 Iniciando reproducción...');
        
        // Asegurar que la sesión de audio esté activa
        if (_audioSession != null) {
          try {
            await _audioSession!.setActive(true);
            print('✅ Audio session activada antes de play');
          } catch (e) {
            print('⚠️ Error activando audio session: $e');
          }
        }
        
        // Reproducir
        await _player.play();
        print('🎵 Comando play() enviado');
        
        // Verificar volumen después de play
        await Future.delayed(const Duration(milliseconds: 200));
        final currentVolume = await _player.volume;
        print('🎵 Volumen actual del player después de play: $currentVolume');
        
        _currentStation = station;
        
        // Esperar un momento y verificar el estado
        await Future.delayed(const Duration(milliseconds: 1500));
        final currentState = _player.playerState;
        _isPlaying = currentState.playing;
        print('🎵 Estado final: playing=$_isPlaying, processingState=${currentState.processingState}');
        
        // Solo lanzar error si realmente hay un problema
        // Si está en estado ready o buffering, está bien (puede estar cargando)
        if (!_isPlaying && currentState.processingState == ProcessingState.idle) {
          print('⚠️ El player se detuvo, puede que la URL no sea compatible');
          print('⚠️ Estado: playing=$_isPlaying, processingState=${currentState.processingState}');
          
          // Esperar un poco más y verificar de nuevo (a veces tarda en iniciar)
          await Future.delayed(const Duration(milliseconds: 2000));
          final retryState = _player.playerState;
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
      print('❌ Error reproduciendo estación: $e');
      print('❌ Stack trace: $stackTrace');
      _isPlaying = false;
      rethrow;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    await _player.play();
    _isPlaying = true;
  }

  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  void dispose() {
    _player.dispose();
    _proxy.stop();
  }
}
