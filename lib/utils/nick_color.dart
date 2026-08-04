import 'dart:ui';

/// Hash estable e independiente de la semilla aleatoria del runtime
/// (String.hashCode cambia entre ejecuciones/web). Así un nick siempre
/// tiene el mismo color, estilo HexChat/Kiwi.
int stableStringHash(String input) {
  var hash = 0x811c9dc5; // FNV-1a 32-bit offset basis
  for (final unit in input.toLowerCase().codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Paleta clásica de colores de nick estilo mIRC/HexChat.
const List<Color> kNickColors = [
  Color(0xFF6BCB77), // verde
  Color(0xFFFFB74D), // naranja
  Color(0xFF64B5F6), // azul
  Color(0xFFF06292), // rosa
  Color(0xFF9575CD), // púrpura
  Color(0xFF4DD0E1), // cian
  Color(0xFFFFF176), // amarillo
  Color(0xFF4DB6AC), // teal
  Color(0xFFFF8A65), // coral
  Color(0xFF81C784), // verde claro
  Color(0xFF7986CB), // índigo
  Color(0xFFE57373), // rojo
  Color(0xFFA1887F), // marrón
  Color(0xFFBA68C8), // lavanda
  Color(0xFF90A4AE), // gris azulado
  Color(0xFFFFD54F), // dorado
];

/// Color estable para un nick.
Color colorForNick(String nick) {
  if (nick.isEmpty) return kNickColors.first;
  return kNickColors[stableStringHash(nick) % kNickColors.length];
}
