import 'package:flutter/foundation.dart' show kIsWeb;

/// Utilidades para detectar la plataforma y adaptar código
class PlatformUtils {
  /// Verifica si estamos en web
  static bool get isWeb => kIsWeb;
  
  /// Verifica si estamos en móvil (iOS/Android)
  /// En web siempre retorna false
  static bool get isMobile => false; // Simplificado: solo funciona en nativo
  
  /// Verifica si estamos en desktop (macOS/Windows/Linux)
  /// En web siempre retorna false
  static bool get isDesktop => false; // Simplificado: solo funciona en nativo
  
  /// Verifica si estamos en macOS
  /// En web siempre retorna false
  static bool get isMacOS => false; // Simplificado: solo funciona en nativo
  
  /// Verifica si estamos en iOS
  /// En web siempre retorna false
  static bool get isIOS => false; // Simplificado: solo funciona en nativo
  
  /// Verifica si estamos en Android
  /// En web siempre retorna false
  static bool get isAndroid => false; // Simplificado: solo funciona en nativo
  
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
