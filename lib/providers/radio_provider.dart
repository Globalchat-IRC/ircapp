import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
import '../services/mixcloud_live_service.dart';
import '../config/debug_config.dart';

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
    return stations
        .where((station) => starredStations.contains(station.name))
        .toList();
  }

  bool isStarred(RadioStation station) {
    return starredStations.contains(station.name);
  }
}

class RadioNotifier extends Notifier<RadioState> {
  Timer? _nowPlayingTimer;
  Timer? _liveStreamCheckTimer;

  @override
  RadioState build() {
    // debugLog('📻 RadioNotifier inicializado');
    _loadSettings();
    _startNowPlayingRefresh();
    _startLiveStreamCheck();
    return RadioState(stations: []);
  }

  Future<void> _loadSettings() async {
    try {
      // debugLog('📻 _loadSettings iniciado');
      final prefs = await SharedPreferences.getInstance();
      final volume = prefs.getDouble('radio_volume') ?? 0.1;
      final starredJson = prefs.getString('radio_starred');
      final activeName = prefs.getString('radio_active');

      // debugLog('📻 Configuración cargada: volume=$volume, activeName=$activeName');

      List<String> starred = [];
      if (starredJson != null) {
        starred = List<String>.from(jsonDecode(starredJson));
      }

      state = state.copyWith(volume: volume, starredStations: starred);

      // Cargar estaciones
      // debugLog('📻 Llamando a loadStations...');
      await loadStations(activeName);
      // debugLog('📻 loadStations completado');
    } catch (e) {
      // debugLog('❌ Error cargando configuración de radio: $e');
      // debugLog('❌ Stack trace: $stackTrace');
    }
  }

  void _startNowPlayingRefresh() {
    // Actualizar la canción en curso cada 30 segundos
    _nowPlayingTimer?.cancel();
    _nowPlayingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshNowPlaying(),
    );
  }

  void _startLiveStreamCheck() {
    // Verificar si hay stream en vivo cada 1 minuto
    // Las URLs cambian frecuentemente, así que verificamos más a menudo
    _liveStreamCheckTimer?.cancel();
    _liveStreamCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkLiveStreams(),
    );
    // Verificar inmediatamente al iniciar
    Future.delayed(const Duration(seconds: 5), () => _checkLiveStreams());
  }

  Future<void> _checkLiveStreams({bool forceRefresh = false}) async {
    try {
      // Snapshot al inicio para evitar modificación concurrente con refreshNowPlaying
      final currentStations = List<RadioStation>.from(state.stations);
      final currentActive = state.activeStation;
      final mixcloudService = MixcloudLiveService();
      if (forceRefresh) {
        mixcloudService.clearCache();
        debugLog(
          '🔄 [RadioProvider] Caché limpiado, obteniendo URL fresca del stream...',
        );
      }
      final stream = await mixcloudService.getUrbanFlowStream();
      if (stream != null && stream.streamUrl.isNotEmpty) {
        final isLive = stream.isLive;
        final cloudcastName = stream.info?['cloudcast_name'] ?? '';
        if (isLive) {
          debugLog('🔴 [RadioProvider] UrbanFlow está EN VIVO');
          debugLog('🎵 [RadioProvider] URL del stream: ${stream.streamUrl}');
        } else {
          debugLog(
            '📼 [RadioProvider] UrbanFlow NO está en vivo, usando última sesión grabada: $cloudcastName',
          );
          debugLog(
            '🎵 [RadioProvider] URL del stream grabado: ${stream.streamUrl}',
          );
        }
        final updatedStations = currentStations.map((station) {
          if (station.name == 'UrbanFlow') {
            return RadioStation(
              id: station.id,
              name: station.name,
              description: isLive
                  ? (station.description.contains('🔴')
                        ? station.description
                        : 'UrbanFlow - Canal #urbanflow en IRC GlobalChat 🔴 EN VIVO')
                  : (cloudcastName.isNotEmpty
                        ? 'UrbanFlow - Canal #urbanflow en IRC GlobalChat 📼 $cloudcastName'
                        : 'UrbanFlow - Canal #urbanflow en IRC GlobalChat 📼 Sesión grabada'),
              source: stream.streamUrl, // ← URL del stream (en vivo o grabado)
              namesite: station.namesite,
              salon: station.salon,
              genre: station.genre,
              bitrate: stream.info?['bitrate'] ?? station.bitrate,
              currentArtistSong: isLive
                  ? 'Emisión en directo'
                  : (cloudcastName.isNotEmpty
                        ? cloudcastName
                        : 'Sesión grabada'),
            );
          }
          return station;
        }).toList();

        // Actualizar también la estación activa si es UrbanFlow
        RadioStation? updatedActive = state.activeStation;
        if (state.activeStation?.name == 'UrbanFlow') {
          updatedActive = updatedStations.firstWhere(
            (s) => s.name == 'UrbanFlow',
            orElse: () => state.activeStation!,
          );
        }

        state = state.copyWith(
          stations: updatedStations,
          activeStation: updatedActive,
        );
      } else {
        debugLog(
          'ℹ️ [RadioProvider] UrbanFlow NO está disponible (ni en vivo ni grabado), usando URL por defecto',
        );

        // Restaurar la URL por defecto de Mixcloud
        final updatedStations = state.stations.map((station) {
          if (station.name == 'UrbanFlow') {
            return RadioStation(
              id: station.id,
              name: station.name,
              description: 'UrbanFlow - Canal #urbanflow en IRC GlobalChat',
              source: 'https://www.mixcloud.com/djsonic_vlc/',
              namesite: 'https://www.mixcloud.com/djsonic_vlc/',
              salon: station.salon,
              genre: 'VARIEDAD',
              bitrate: '128',
              currentArtistSong: station.currentArtistSong,
            );
          }
          return station;
        }).toList();
        RadioStation? updatedActive = currentActive;
        if (currentActive?.name == 'UrbanFlow') {
          try {
            updatedActive = updatedStations.firstWhere(
              (s) => s.name == 'UrbanFlow',
              orElse: () => currentActive!,
            );
          } catch (_) {
            updatedActive = currentActive;
          }
        }
        state = state.copyWith(
          stations: updatedStations,
          activeStation: updatedActive,
        );
      }
    } catch (e) {
      debugLog('⚠️ [RadioProvider] Error verificando streams: $e');
    }
  }

  // Método público para forzar actualización de la canción actual
  Future<void> refreshNowPlaying() async {
    // Snapshot de state al inicio para evitar "Concurrent modification during iteration"
    // si otro timer (_checkLiveStreams) actualiza state mientras estamos en await
    final currentStations = List<RadioStation>.from(state.stations);
    final currentActive = state.activeStation;
    if (currentStations.isEmpty) return;

    try {
      final urls = [
        'https://mobilev1.globalchat.org/static/plugins/stations.json',
        'https://webchat.globalchat.org/static/plugins/stations.json',
      ];
      http.Response? response;
      for (var i = 0; i < urls.length; i++) {
        try {
          response = await http
              .get(Uri.parse(urls[i]))
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) break;
        } catch (_) {
          continue;
        }
      }

      if (response == null || response.statusCode != 200) return;

      final List<dynamic> jsonList = jsonDecode(response.body);
      final allStations = jsonList
          .map((json) => RadioStation.fromJson(json))
          .toList();
      final byName = <String, RadioStation>{};
      for (var i = 0; i < allStations.length; i++) {
        byName[allStations[i].name] = allStations[i];
      }

      final updatedStations = currentStations.map((old) {
        final fresh = byName[old.name];
        if (fresh == null) {
          if (currentActive?.name == old.name &&
              currentActive?.currentArtistSong != null &&
              currentActive!.currentArtistSong != old.currentArtistSong) {
            return RadioStation(
              id: old.id,
              name: old.name,
              description: old.description,
              source: old.source,
              namesite: old.namesite,
              salon: old.salon,
              genre: old.genre,
              bitrate: old.bitrate,
              currentArtistSong: currentActive.currentArtistSong,
            );
          }
          return old;
        }
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
      if (currentActive != null) {
        try {
          updatedActive = updatedStations.firstWhere(
            (s) => s.name == currentActive.name,
            orElse: () => currentActive,
          );
        } catch (_) {
          updatedActive = currentActive;
        }
      }

      state = state.copyWith(
        stations: updatedStations,
        activeStation: updatedActive,
      );
    } catch (e, stackTrace) {
      debugLog('❌ [RadioProvider] Error al actualizar canción: $e');
      debugLog('❌ [RadioProvider] Stack: $stackTrace');
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
      // debugLog('Error guardando configuración de radio: $e');
    }
  }

  List<RadioStation> _getDefaultStations() {
    // Estaciones que funcionan bien (Zeno.fm y listen2myradio.com)
    return [
      RadioStation(
        id: 'zeno1',
        name: 'NuestrasVoces',
        description: '🎤✨ Nuevos talentos y dedicatorias',
        source:
            'https://stream-179.zeno.fm/td7dw1np6s8uv?zt=eyJhbGciOiJIUzI1NiJ9.eyJzdHJlYW0iOiJ0ZDdkdzFucDZzOHV2IiwiaG9zdCI6InN0cmVhbS0xNzkuemVuby5mbSIsInJ0dGwiOjUsImp0aSI6ImZ6dGxpd002U0RlSmo0S3VfUE1xNWciLCJpYXQiOjE3NTg3NTU0MDMsImV4cCI6MTc1ODc1NTQ2M30.wl2oH7CHKjldHmqf3gkqqVhzl0lpJMTc3XebALO65l0',
        namesite: 'https://globalchat.org/',
        salon: '#nuestrasvoces',
      ),
      // SoundMusic comentada temporalment
      // RadioStation(
      //   id: 'zeno2',
      //   name: 'SoundMusic',
      //   description: '🎶🌟 Variado gusto musical',
      //   source: 'https://stream.zeno.fm/3ezwa4mtghmtv',
      //   namesite: 'https://zeno.fm/radio/soundmusic/',
      //   salon: '#soundmusic',
      // ),
      RadioStation(
        id: 'urban1',
        name: 'UrbanFlow',
        description: 'UrbanFlow - Canal #urbanflow en IRC GlobalChat',
        source: 'https://www.mixcloud.com/djsonic_vlc/',
        namesite: 'https://www.mixcloud.com/djsonic_vlc/',
        salon: '#urbanflow',
        genre: 'VARIEDAD',
        bitrate: '128',
      ),
    ];
  }

  Future<void> loadStations([String? activeName]) async {
    try {
      // Usar solo las estaciones por defecto (las 3 configuradas)
      final stations = _getDefaultStations();

      RadioStation? active;
      if (activeName != null && stations.isNotEmpty) {
        try {
          active = stations.firstWhere((s) => s.name == activeName);
        } catch (e) {
          active = stations[0];
        }
      } else if (state.starredStations.isNotEmpty && stations.isNotEmpty) {
        final starred = stations
            .where((s) => state.starredStations.contains(s.name))
            .toList();
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
      // debugLog('📻 ✅ Estaciones cargadas: ${stations.length}');
      // debugLog('📻 ✅ Estación activa: ${active?.name ?? "ninguna"}');
    } catch (e) {
      // debugLog('❌ Error cargando estaciones de radio: $e');
      // debugLog('❌ Stack trace: $stackTrace');
      // Usar estaciones por defecto en caso de error
      final defaultStations = _getDefaultStations();
      state = state.copyWith(
        stations: defaultStations,
        activeStation: defaultStations.isNotEmpty ? defaultStations[0] : null,
        hasError: false,
      );
      // debugLog('📻 ✅ Usando ${defaultStations.length} estaciones por defecto');
    }
  }

  Future<void> setActiveStation(RadioStation station) async {
    // Si es UrbanFlow, verificar primero si hay stream en vivo
    if (station.name == 'UrbanFlow') {
      debugLog(
        '🎵 [RadioProvider] Usuario seleccionó UrbanFlow, obteniendo URL fresca del stream...',
      );
      // Forzar actualización para obtener URL fresca (sin caché)
      await _checkLiveStreams(forceRefresh: true);
      // Después de verificar, obtener la estación actualizada
      final updatedStation = state.stations.firstWhere(
        (s) => s.name == 'UrbanFlow',
        orElse: () => station,
      );
      state = state.copyWith(activeStation: updatedStation, hasError: false);
    } else {
      state = state.copyWith(activeStation: station, hasError: false);
    }
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
}

final radioProvider = NotifierProvider<RadioNotifier, RadioState>(() {
  return RadioNotifier();
});

final radioServiceProvider = Provider<RadioService>((ref) {
  final service = RadioService();
  ref.onDispose(() => service.dispose());
  return service;
});
