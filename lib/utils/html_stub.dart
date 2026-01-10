// Stub file para dart:html cuando no está disponible (macOS, iOS, Android)
// Este archivo proporciona clases vacías que no hacen nada

class Window {
  Location get location => Location();
  dynamic get navigator => _Navigator();
  dynamic get console => _Console();
}

class Location {
  String? get search => null;
  String? get hash => null;
  String? get href => null;
  void reload() {} // Stub method, no hace nada en nativo
}

class _Navigator {
  dynamic get permissions => null;
}

class _Console {
  void log(dynamic message) {}
  void error(dynamic message) {}
  void warn(dynamic message) {}
}

class Document {
  bool get hidden => false;
  Stream<dynamic> get onVisibilityChange => const Stream.empty();
}

class Notification {
  static bool get supported => false;
  static String get permission => 'denied';
  
  static Future<String> requestPermission() async => 'denied';
  
  Notification(String title, {String? body, String? icon}) {
    // Constructor vacío
  }
  
  Stream<dynamic> get onClick => const Stream.empty();
  void close() {}
}

final window = Window();
final document = Document();

// Stub para exit() - no hace nada en web
void exit(int code) {
  // No hacer nada en web, solo en nativo
}
