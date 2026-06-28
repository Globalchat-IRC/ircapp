// Stub para dart:ui_web cuando no está disponible (macOS, iOS, Android).
// Evita errores de compilación al usar platformViewRegistry solo en web.

class _PlatformViewRegistry {
  void registerViewFactory(String viewType, dynamic Function(int viewId) callback) {}
}

final platformViewRegistry = _PlatformViewRegistry();
