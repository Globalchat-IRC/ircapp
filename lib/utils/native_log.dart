// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:io' show File, FileMode;

/// Funciones de logging nativas (solo para plataformas no-web)
class NativeLog {
  static void writeToFile(String message) {
    try {
      final logFile = File('/tmp/irc_app.log');
      logFile.writeAsStringSync(message, mode: FileMode.append);
    } catch (e) {
      // Si falla escribir al archivo, ignorar
    }
  }
  
  static void clearLogFile() {
    try {
      final logFile = File('/tmp/irc_app.log');
      logFile.deleteSync();
    } catch (e) {
      // File doesn't exist yet
    }
  }
}


