/// Configuración de logs de debug en consola.
///
/// Cambiar a `true` para activar todos los prints de debug (IRC, radio, avatares, etc.).
/// Dejar en `false` para producción y que la consola quede limpia.
// ignore: prefer_const_declarations
final bool kDebugConsole = true; // true = activar debug en consola

void debugLog(String message) {
  if (kDebugConsole) {
    // ignore: avoid_print
    print(message);
  }
}
