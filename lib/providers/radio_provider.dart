import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/radio_station.dart';
import '../services/radio_service.dart';

class RadioState {
  final List<RadioStation> stations;
  final RadioStation? activeStation;
  final bool isPlaying;
  final double volume;
  final List<String> starredStations;
  final bool hasError;

  RadioState({
    required this.stations,
    this.activeStation,
    this.isPlaying = false,
    this.volume = 0.1,
    List<String>? starredStations,
    this.hasError = false,
  }) : starredStations = starredStations ?? [];

  RadioState copyWith({
    List<RadioStation>? stations,
    RadioStation? activeStation,
    bool? isPlaying,
    double? volume,
    List<String>? starredStations,
    bool? hasError,
  }) {
    return RadioState(
      stations: stations ?? this.stations,
      activeStation: activeStation ?? this.activeStation,
      isPlaying: isPlaying ?? this.isPlaying,
      volume: volume ?? this.volume,
      starredStations: starredStations ?? this.starredStations,
      hasError: hasError ?? this.hasError,
    );
  }

  List<RadioStation> getStarredStations() {
    return stations.where((station) => starredStations.contains(station.name)).toList();
  }

  bool isStarred(RadioStation station) {
    return starredStations.contains(station.name);
  }
}

class RadioNotifier extends StateNotifier<RadioState> {
  Timer? _nowPlayingTimer;

  RadioNotifier() : super(RadioState(stations: [])) {
    print('📻 RadioNotifier inicializado');
    _loadSettings();
    _startNowPlayingRefresh();
  }

  Future<void> _loadSettings() async {
    try {
      print('📻 _loadSettings iniciado');
      final prefs = await SharedPreferences.getInstance();
      final volume = prefs.getDouble('radio_volume') ?? 0.1;
      final starredJson = prefs.getString('radio_starred');
      final activeName = prefs.getString('radio_active');
      
      print('📻 Configuración cargada: volume=$volume, activeName=$activeName');
      
      List<String> starred = [];
      if (starredJson != null) {
        starred = List<String>.from(jsonDecode(starredJson));
      }

      state = state.copyWith(
        volume: volume,
        starredStations: starred,
      );

      // Cargar estaciones
      print('📻 Llamando a loadStations...');
      await loadStations(activeName);
      print('📻 loadStations completado');
    } catch (e, stackTrace) {
      print('❌ Error cargando configuración de radio: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  void _startNowPlayingRefresh() {
    // Actualizar la canción en curso cada 30 segundos
    _nowPlayingTimer?.cancel();
    _nowPlayingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshNowPlaying(),
    );
  }

  Future<void> _refreshNowPlaying() async {
    if (state.stations.isEmpty) return;

    try {
      final url =
          'https://webchat.globalchat.org/static/plugins/stations.json';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final List<dynamic> jsonList = jsonDecode(response.body);
      final allStations =
          jsonList.map((json) => RadioStation.fromJson(json)).toList();

      // Mapear por nombre para actualizar datos actuales
      final Map<String, RadioStation> byName = {
        for (final s in allStations) s.name: s
      };

      final updatedStations = state.stations.map((old) {
        final fresh = byName[old.name];
        if (fresh == null) return old;
        return RadioStation(
          id: old.id,
          name: old.name,
          description: old.description,
          source: old.source,
          namesite: old.namesite,
          salon: old.salon,
          genre: fresh.genre ?? old.genre,
          bitrate: fresh.bitrate ?? old.bitrate,
          currentArtistSong: fresh.currentArtistSong ?? old.currentArtistSong,
        );
      }).toList();

      RadioStation? updatedActive;
      if (state.activeStation != null) {
        updatedActive = updatedStations.firstWhere(
          (s) => s.name == state.activeStation!.name,
          orElse: () => state.activeStation!,
        );
      }

      state = state.copyWith(
        stations: updatedStations,
        activeStation: updatedActive,
      );
    } catch (_) {
      // Silencioso: si falla, mantenemos el último título conocido
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('radio_volume', state.volume);
      await prefs.setString('radio_starred', jsonEncode(state.starredStations));
      if (state.activeStation != null) {
        await prefs.setString('radio_active', state.activeStation!.name);
      }
    } catch (e) {
      print('Error guardando configuración de radio: $e');
    }
  }

  List<RadioStation> _getDefaultStations() {
    // Estaciones que funcionan bien (Zeno.fm y listen2myradio.com)
    return [
      RadioStation(
        id: 'zeno1',
        name: 'NuestrasVoces',
        description: '🎤✨ Nuevos talentos y dedicatorias',
        source: 'https://stream-179.zeno.fm/td7dw1np6s8uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ0ZDdkdzFucDZzOHV2IiwiaG9zdCI6InN0cmVhbS0xNzkuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImZ6dGxpd002U0RlSmo0S3VfUE1xNWciLCJpYXQiOjE3NTg3NTU0MDMsImV4cCI6MTc1ODc1NTQ2M30.wl2oH7CHKjldHmqf3gkqqVhzl0lpJMTc3XebALO65l0',
        namesite: 'https://globalchat.org/',
        salon: '#nuestrasvoces',
      ),
      RadioStation(
        id: 'zeno2',
        name: 'SoundMusic',
        description: '🎶🌟 Variado gusto musical',
        source: 'https://stream.zeno.fm/3ezwa4mtghmtv',
        namesite: 'https://zeno.fm/radio/soundmusic/',
        salon: '#soundmusic',
      ),
      RadioStation(
        id: 'sonic1',
        name: 'Radio Sonic Frequency',
        description: 'Radio SONIC Frequency - Canal #SonicFrequency en IRC GlobalChat',
        source: 'https://uk18freenew.listen2myradio.com/live.mp3?typeportmount=s1_16892_stream_539618443',
        namesite: 'https://globalchat.org/',
        salon: '#SonicFrequency',
        genre: 'VARIEDAD',
        bitrate: '128',
      ),
    ];
  }

  Future<void> loadStations([String? activeName]) async {
    try {
      print('📻 Cargando estaciones de radio...');
      // Cargar desde la URL correcta del plugin web
      final url = 'https://webchat.globalchat.org/static/plugins/stations.json';
      print('📻 URL: $url');
      
      List<RadioStation> stations = [];
      
      try {
        final response = await http.get(
          Uri.parse(url),
        ).timeout(const Duration(seconds: 10));

        print('📻 Respuesta HTTP: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final List<dynamic> jsonList = jsonDecode(response.body);
          print('📻 Estaciones encontradas en servidor: ${jsonList.length}');
          final allStations = jsonList.map((json) => RadioStation.fromJson(json)).toList();
          
          // Filtrar estaciones que funcionan bien (Zeno.fm y listen2myradio.com)
          stations = allStations.where((station) {
            final source = station.source.toLowerCase();
            return source.contains('zeno.fm') || source.contains('listen2myradio.com');
          }).toList();
          
          print('📻 Estaciones válidas encontradas: ${stations.length}');
          
          // Si no hay estaciones válidas, agregar las que funcionan por defecto
          if (stations.isEmpty) {
            print('📻 No hay estaciones válidas, agregando estaciones predeterminadas...');
            stations = _getDefaultStations();
          }
          
          // Mostrar todas las URLs de stream
          print('📻 ===== URLs DE STREAM EN LA APLICACIÓN =====');
          for (var station in stations) {
            print('📻 ${station.name}:');
            print('   URL: ${station.source}');
            print('   Género: ${station.genre ?? "N/A"}');
            print('   Bitrate: ${station.bitrate ?? "N/A"}');
            print('');
          }
          print('📻 ============================================');
          
          if (stations.isNotEmpty) {
            print('📻 Primera estación: ${stations[0].name} - ${stations[0].source}');
          }
        } else {
          print('⚠️ Error HTTP: ${response.statusCode}, usando estaciones por defecto');
          stations = _getDefaultStations();
        }
      } catch (e) {
        print('⚠️ Error al cargar desde URL: $e');
        print('📻 Usando estaciones por defecto...');
        stations = _getDefaultStations();
      }

      // Si no hay estaciones, usar las por defecto
      if (stations.isEmpty) {
        print('📻 No se encontraron estaciones, usando estaciones por defecto');
        stations = _getDefaultStations();
      }

      RadioStation? active;
      if (activeName != null && stations.isNotEmpty) {
        try {
          active = stations.firstWhere((s) => s.name == activeName);
        } catch (e) {
          active = stations[0];
        }
      } else if (state.starredStations.isNotEmpty && stations.isNotEmpty) {
        final starred = stations.where((s) => state.starredStations.contains(s.name)).toList();
        active = starred.isNotEmpty ? starred[0] : stations[0];
      } else if (stations.isNotEmpty) {
        try {
          active = stations.firstWhere((s) => s.name == 'NuestrasVoces');
        } catch (e) {
          active = stations[0];
        }
      }

      state = state.copyWith(
        stations: stations,
        activeStation: active,
        hasError: false,
      );
      print('📻 ✅ Estaciones cargadas: ${stations.length}');
      print('📻 ✅ Estación activa: ${active?.name ?? "ninguna"}');
    } catch (e, stackTrace) {
      print('❌ Error cargando estaciones de radio: $e');
      print('❌ Stack trace: $stackTrace');
      // Usar estaciones por defecto en caso de error
      final defaultStations = _getDefaultStations();
      state = state.copyWith(
        stations: defaultStations,
        activeStation: defaultStations.isNotEmpty ? defaultStations[0] : null,
        hasError: false,
      );
      print('📻 ✅ Usando ${defaultStations.length} estaciones por defecto');
    }
  }

  void setActiveStation(RadioStation station) {
    state = state.copyWith(activeStation: station, hasError: false);
    _saveSettings();
  }

  void setPlaying(bool playing) {
    state = state.copyWith(isPlaying: playing);
  }

  void setVolume(double volume) {
    state = state.copyWith(volume: volume);
    _saveSettings();
  }

  void toggleStarred(RadioStation station) {
    final starred = List<String>.from(state.starredStations);
    if (starred.contains(station.name)) {
      starred.remove(station.name);
    } else {
      starred.add(station.name);
    }
    state = state.copyWith(starredStations: starred);
    _saveSettings();
  }

  void setError(bool hasError) {
    state = state.copyWith(hasError: hasError);
  }

  @override
  void dispose() {
    _nowPlayingTimer?.cancel();
    super.dispose();
  }
}

final radioProvider = StateNotifierProvider<RadioNotifier, RadioState>((ref) {
  return RadioNotifier();
});

final radioServiceProvider = Provider<RadioService>((ref) {
  final service = RadioService();
  ref.onDispose(() => service.dispose());
  return service;
});

