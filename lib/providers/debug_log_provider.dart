import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugLogNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void addLog(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    state = [...state, '[$timestamp] $message'];
    
    // Limitar a los últimos 1000 mensajes para evitar problemas de memoria
    if (state.length > 1000) {
      state = state.sublist(state.length - 1000);
    }
  }

  void clearLogs() {
    state = [];
  }
}

final debugLogProvider = NotifierProvider<DebugLogNotifier, List<String>>(() {
  return DebugLogNotifier();
});
