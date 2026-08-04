// Stub file para dart:html cuando no está disponible (macOS, iOS, Android)
// Este archivo proporciona clases vacías que no hacen nada

class Window {
  Location get location => Location();
  dynamic get navigator => _Navigator();
  dynamic get console => _Console();
  dynamic get context => _Context();
  void eval(String code) {} // Stub para eval
}

class _Context {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
}

class Location {
  String? get search => null;
  String? get hash => null;
  String? get href => null;
  void reload([
    bool forceGet = false,
  ]) {} // Stub: en web usa dart:html y forceGet fuerza recarga sin caché
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
  Element? getElementById(String id) => null;
}

class Element {
  List<Element> children = [];
  void append(Element element) {}
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

// Stub para Blob (usado en export_service.dart)
class Blob {
  Blob(List<dynamic> data, {String? type}) {
    // Constructor vacío
  }
}

// Stub para Url (usado en export_service.dart)
class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

// Stub para AnchorElement (usado en export_service.dart)
class AnchorElement {
  String? href;
  AnchorElement({this.href});
  void setAttribute(String name, String value) {}
  void click() {}
}

// Stub para IFrameElement (usado en voice_assistant_dialog.dart)
class IFrameElement {
  String src = '';
  dynamic style = _Style();
  String allow = '';
}

class _Style {
  String border = '';
  String width = '';
  String height = '';
}

// Stub para allowInterop (usado en radio_service.dart)
T allowInterop<T extends Function>(T f) => f;

// Stub para AudioElement (usado en radio_service.dart)
class AudioElement {
  String? id;
  String src = '';
  bool paused = true;
  double volume = 1.0;
  Future<void> play() async {}
  void pause() {}
  Stream<dynamic> get onLoadedMetadata => const Stream.empty();
  Stream<dynamic> get onError => const Stream.empty();
}
