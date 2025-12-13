import 'package:just_audio/just_audio.dart';
import '../models/radio_station.dart';
import 'stream_proxy_service.dart';

class RadioService {
  final AudioPlayer _player = AudioPlayer();
  RadioStation? _currentStation;
  bool _isPlaying = false;
  double _volume = 0.1;
  final StreamProxyService _proxy = StreamProxyService.instance;

  RadioStation? get currentStation => _currentStation;
  bool get isPlaying => _isPlaying;
  double get volume => _volume;

  RadioService() {
    // Iniciar el proxy local y esperar a que esté listo
    _proxy.start().then((_) {
      print('✅ Proxy listo para usar');
    }).catchError((e) {
      print('⚠️ Error iniciando proxy: $e');
      print('⚠️ Las estaciones pueden no funcionar sin el proxy');
    });
    
    // Configurar el player para streams de radio
    _player.setVolume(_volume);
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
      
      // Obtener URL del proxy si está disponible, sino usar la URL original
      String streamUrl = station.source;
      final proxyUrl = _proxy.getProxyUrl(station.source);
      if (proxyUrl != null) {
        streamUrl = proxyUrl;
        print('🎵 Usando proxy: $streamUrl');
        print('🎵 URL original: ${station.source}');
      } else {
        print('⚠️ Proxy no disponible, intentando URL directa (puede fallar)');
        print('🎵 URL directa: ${station.source}');
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
        
        print('🎵 Configurando nueva fuente...');
        // Establecer la fuente del audio
        await _player.setUrl(streamUrl);
        print('🎵 Fuente configurada');
        
        // Esperar un momento para que se cargue
        await Future.delayed(const Duration(milliseconds: 300));
        
        print('🎵 Iniciando reproducción...');
        // Reproducir
        await _player.play();
        print('🎵 Comando play() enviado');
        
        _currentStation = station;
        
        // Esperar un momento y verificar el estado
        await Future.delayed(const Duration(milliseconds: 1000));
        final currentState = _player.playerState;
        _isPlaying = currentState.playing;
        print('🎵 Estado final: playing=$_isPlaying, processingState=${currentState.processingState}');
        
        if (!_isPlaying && currentState.processingState == ProcessingState.idle) {
          print('⚠️ El player se detuvo, puede que la URL no sea compatible');
          throw Exception('No se pudo reproducir el stream. La URL puede no ser compatible.');
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
