// Stub file para dart:js cuando no está disponible (macOS, iOS, Android)
// Este archivo proporciona clases vacías que no hacen nada

class JsObject {
  dynamic callMethod(String method, List<dynamic>? args) => null;
  dynamic apply(List<dynamic>? args) => null;
}

class JsContext {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
}

final context = JsContext();

// Stub para allowInterop
T allowInterop<T extends Function>(T f) => f;
