import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Utilidades para detectar la plataforma y adaptar código
class PlatformUtils {
  /// Verifica si estamos en web
  static bool get isWeb => kIsWeb;
  
  /// Verifica si estamos en móvil (iOS/Android)
  static bool get isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  
  /// Verifica si estamos en desktop (macOS/Windows/Linux)
  static bool get isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
  
  /// Verifica si estamos en macOS
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  
  /// Verifica si estamos en iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  
  /// Verifica si estamos en Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  
  /// Verifica si podemos usar sockets TCP nativos
  static bool get canUseNativeSockets => !kIsWeb;
  
  /// Verifica si debemos usar WebSocket
  static bool get mustUseWebSocket => kIsWeb;
  
  /// Verifica si podemos usar sistema de archivos nativo
  static bool get canUseNativeFileSystem => !kIsWeb;
  
  /// Verifica si podemos usar SQLite
  static bool get canUseSQLite => !kIsWeb;
  
  /// Verifica si debemos usar IndexedDB/localStorage
  static bool get mustUseWebStorage => kIsWeb;
}

