import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Provider para gestionar imágenes de fondo por canal
final channelBackgroundProvider =
    NotifierProvider<ChannelBackgroundNotifier, Map<String, String>>(() {
  return ChannelBackgroundNotifier();
});

class ChannelBackgroundNotifier extends Notifier<Map<String, String>> {
  static const _prefsKey = 'channel_background_images_v1';

  @override
  Map<String, String> build() {
    _initialize();
    return {};
  }

  Future<void> _initialize() async {
    await _loadFromPrefs();
    await _loadDefaults();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final Map<String, String> backgrounds = {};
        decoded.forEach((key, value) {
          backgrounds[key.toLowerCase()] = value as String;
        });
        state = backgrounds;
      }
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state));
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  /// Cargar configuraciones por defecto si no existen en preferencias
  Future<void> _loadDefaults() async {
    // Asegurar que los defaults estén presentes si no existen
    final defaults = {
      '#urbanflow': 'https://technosonic.radio12345.com/banner_images/3418735/128/95/785047816424filebaner.png',
    };
    final newState = Map<String, String>.from(state);
    bool hasChanges = false;
    
    defaults.forEach((key, value) {
      final normalizedKey = key.toLowerCase();
      if (!newState.containsKey(normalizedKey)) {
        newState[normalizedKey] = value;
        hasChanges = true;
      }
    });
    
    if (hasChanges) {
      state = newState;
      await _saveToPrefs();
    }
  }

  /// Obtener la URL de imagen de fondo para un canal
  String? getBackgroundForChannel(String? channel) {
    if (channel == null) return null;
    return state[channel.toLowerCase()];
  }

  /// Establecer la URL de imagen de fondo para un canal
  Future<void> setBackgroundForChannel(String channel, String? url) async {
    final key = channel.toLowerCase();
    final newState = Map<String, String>.from(state);
    
    if (url == null || url.trim().isEmpty) {
      newState.remove(key);
    } else {
      newState[key] = url.trim();
    }
    
    state = newState;
    await _saveToPrefs();
  }

  /// Eliminar la imagen de fondo de un canal
  Future<void> removeBackgroundForChannel(String channel) async {
    await setBackgroundForChannel(channel, null);
  }

  /// Obtener todos los canales con imágenes de fondo configuradas
  Map<String, String> getAllBackgrounds() {
    return Map<String, String>.from(state);
  }
}
