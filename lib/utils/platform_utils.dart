import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Utilidades para detectar la plataforma y adaptar código
class PlatformUtils {
  /// Verifica si estamos en web
  static bool get isWeb => kIsWeb;

  /// Verifica si estamos en iOS
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Verifica si estamos en Android
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Verifica si estamos en móvil (iOS/Android)
  static bool get isMobile => isIOS || isAndroid;

  /// Verifica si estamos en macOS
  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Verifica si estamos en Windows
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Verifica si estamos en Linux
  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// La radio usa audioplayers (web/Windows/Linux) porque just_audio no
  /// soporta Windows/Linux. macOS/iOS/Android usan just_audio.
  static bool get radioUsesAudioPlayers => kIsWeb || isWindows || isLinux;

  /// Verifica si estamos en desktop (macOS/Windows/Linux)
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

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
