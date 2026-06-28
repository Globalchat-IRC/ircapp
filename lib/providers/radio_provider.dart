import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../models/radio_station.dart';
import '../services/radio_service.dart';
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
    this.volume = 0.85,
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

  /// Estaciones retiradas: se migran automáticamente a Qualia_Radio.
  static const _legacyStationNames = {
    'UrbanFlow',
    'NuestrasVoces',
    'SoundMusic',
  };

  static String? _migrateLegacyStationName(String? name) {
    if (name != null && _legacyStationNames.contains(name)) {
      return 'Qualia_Radio';
    }
    return name;
  }

  static String _migrateLegacyStationNameRequired(String name) {
    return _legacyStationNames.contains(name) ? 'Qualia_Radio' : name;
  }

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
      final volume = prefs.getDouble('radio_volume') ?? 0.85;
      final starredJson = prefs.getString('radio_starred');
      var activeName = _migrateLegacyStationName(prefs.getString('radio_active'));

      List<String> starred = [];
      if (starredJson != null) {
        starred = List<String>.from(jsonDecode(starredJson))
            .map(_migrateLegacyStationNameRequired)
            .toSet()
            .toList();
      }

      state = state.copyWith(volume: volume, starredStations: starred);

      await loadStations(activeName);

      // Persistir migración para no conservar nombres antiguos en el dispositivo.
      if (activeName == 'Qualia_Radio' &&
          prefs.getString('radio_active') != null &&
          _legacyStationNames.contains(prefs.getString('radio_active'))) {
        await prefs.setString('radio_active', 'Qualia_Radio');
      }
      if (starredJson != null &&
          starredJson.contains(RegExp(
            r'UrbanFlow|NuestrasVoces|SoundMusic',
          ))) {
        await prefs.setString('radio_starred', jsonEncode(starred));
      }
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

  Future<void> _checkLiveStreams() async {
    try {
      final currentStations = List<RadioStation>.from(state.stations);
      final currentActive = state.activeStation;
      if (!currentStations.any((s) => s.name == 'Qualia_Radio')) return;

      final response = await http
          .get(
            Uri.parse(
              'https://azura.streamingradio.online/api/nowplaying/qualia_radio',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final nowPlaying = data['now_playing'] as Map<String, dynamic>?;
      final live = data['live'] as Map<String, dynamic>?;
      final song = nowPlaying?['song'] as Map<String, dynamic>?;
      final artist = (song?['artist'] as String?)?.trim() ?? '';
      final title = (song?['title'] as String?)?.trim() ?? '';
      final songText = (song?['text'] as String?)?.trim() ?? '';
      final currentArtistSong = songText.isNotEmpty
          ? songText
          : (artist.isNotEmpty && title.isNotEmpty
                ? '$artist - $title'
                : (title.isNotEmpty ? title : null));

      final isLive = live?['is_live'] == true;
      final streamerName = (live?['streamer_name'] as String?)?.trim() ?? '';
      const baseDescription =
          'Qualia Radio - Canal #QualiaRadio en IRC GlobalChat';
      final description = isLive
          ? (streamerName.isNotEmpty
                ? '$baseDescription 🔴 EN VIVO ($streamerName)'
                : '$baseDescription 🔴 EN VIVO')
          : baseDescription;

      final updatedStations = currentStations.map((station) {
        if (station.name == 'Qualia_Radio') {
          return RadioStation(
            id: station.id,
            name: station.name,
            description: description,
            source: station.source,
            namesite: station.namesite,
            salon: station.salon,
            genre: station.genre,
            bitrate: station.bitrate,
            currentArtistSong: isLive
                ? (streamerName.isNotEmpty
                      ? 'En directo: $streamerName'
                      : 'Emisión en directo')
                : currentArtistSong,
          );
        }
        return station;
      }).toList();

      RadioStation? updatedActive = currentActive;
      if (currentActive?.name == 'Qualia_Radio') {
        updatedActive = updatedStations.firstWhere(
          (s) => s.name == 'Qualia_Radio',
          orElse: () => currentActive!,
        );
      }

      state = state.copyWith(
        stations: updatedStations,
        activeStation: updatedActive,
      );
    } catch (e) {
      debugLog('⚠️ [RadioProvider] Error verificando Qualia Radio: $e');
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
    return [
      RadioStation(
        id: 'qualia1',
        name: 'Qualia_Radio',
        description: 'Qualia Radio - Canal #QualiaRadio en IRC GlobalChat',
        source:
            'https://azura.streamingradio.online/listen/qualia_radio/radio.mp3',
        namesite: 'https://azura.streamingradio.online/public/qualia_radio',
        salon: '#QualiaRadio',
        genre: 'VARIEDAD',
        bitrate: '128',
      ),
    ];
  }

  Future<void> loadStations([String? activeName]) async {
    try {
      activeName = _migrateLegacyStationName(activeName);
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
          active = stations.firstWhere((s) => s.name == 'Qualia_Radio');
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
    if (station.name == 'Qualia_Radio') {
      await _checkLiveStreams();
      final updatedStation = state.stations.firstWhere(
        (s) => s.name == 'Qualia_Radio',
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
