import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para la configuración de historial de mensajes
final historyEnabledProvider = NotifierProvider<HistoryEnabledNotifier, bool>(() {
  return HistoryEnabledNotifier();
});

class HistoryEnabledNotifier extends Notifier<bool> {
  static const _prefsKey = 'chat_history_enabled';
  static const bool _defaultValue = false;

  @override
  bool build() {
    _loadFromPrefs();
    return _defaultValue;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_prefsKey) ?? _defaultValue;
      state = value;
    } catch (e) {
      print('Error cargando configuración de historial: $e');
      state = _defaultValue;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
    } catch (e) {
      print('Error guardando configuración de historial: $e');
    }
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}
