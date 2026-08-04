class GiftConfig {
  static const List<GiftItem> gifts = [
    GiftItem(id: 1, name: 'Rosa', icon: '\u{1F339}', value: 50),
    GiftItem(id: 2, name: 'Estrella', icon: '\u2B50', value: 75),
    GiftItem(id: 3, name: 'Cupcake', icon: '\u{1F9C1}', value: 100),
    GiftItem(id: 4, name: 'Regalo', icon: '\u{1F381}', value: 120),
    GiftItem(id: 5, name: 'Diamante', icon: '\u{1F48E}', value: 250),
    GiftItem(id: 6, name: 'Trofeo', icon: '\u{1F3C6}', value: 200),
    GiftItem(id: 7, name: 'Mate', icon: '\u{1F9C9}', value: 60),
    GiftItem(id: 8, name: 'Varita M\u00e1gica', icon: '\u2728', value: 150),
    GiftItem(id: 9, name: 'Cohete', icon: '\u{1F680}', value: 300),
    GiftItem(id: 10, name: 'Avi\u00f3n de papel', icon: '\u{1F6E9}\uFE0F', value: 80),
    GiftItem(id: 11, name: 'C\u00e1mara', icon: '\u{1F4F7}', value: 90),
    GiftItem(id: 12, name: 'Campana', icon: '\u{1F514}', value: 65),
    GiftItem(id: 13, name: 'Paraguas', icon: '\u2602\uFE0F', value: 55),
    GiftItem(id: 14, name: 'Fuego', icon: '\u{1F525}', value: 350),
    GiftItem(id: 15, name: 'Coraz\u00f3n', icon: '\u2764\uFE0F', value: 45),
    GiftItem(id: 16, name: 'M\u00fAsica', icon: '\u{1F3B5}', value: 70),
    GiftItem(id: 17, name: 'Sonrisa', icon: '\u{1F60A}', value: 40),
    GiftItem(id: 18, name: 'Bomba', icon: '\u{1F4A3}', value: 400),
    GiftItem(id: 19, name: 'Mano', icon: '\u270B', value: 30),
    GiftItem(id: 20, name: 'Globo', icon: '\u{1F388}', value: 50),
    GiftItem(id: 21, name: 'Cerveza', icon: '\u{1F37A}', value: 95),
    GiftItem(id: 22, name: 'Luna', icon: '\u{1F319}', value: 75),
    GiftItem(id: 23, name: 'Flor', icon: '\u{1F338}', value: 60),
    GiftItem(id: 24, name: 'Gato', icon: '\u{1F431}', value: 105),
    GiftItem(id: 25, name: 'Perro', icon: '\u{1F436}', value: 105),
    GiftItem(id: 26, name: 'Arco\u00edris', icon: '\u{1F308}', value: 115),
    GiftItem(id: 27, name: 'Brindis', icon: '\u{1F942}', value: 85),
    GiftItem(id: 28, name: 'Pastel', icon: '\u{1F370}', value: 130),
    GiftItem(id: 29, name: 'Corona', icon: '\u{1F451}', value: 180),
    GiftItem(id: 30, name: 'Mariposa', icon: '\u{1F98B}', value: 110),
    GiftItem(id: 31, name: 'Piojos', icon: '\u{1FAB2}', value: 10),
    GiftItem(id: 32, name: 'Sonic', icon: '\u{1F994}', value: 350),
  ];

  static GiftItem? findById(int id) {
    for (final g in gifts) {
      if (g.id == id) return g;
    }
    return null;
  }

  static String buildGiftMessage(String sender, String target, GiftItem gift) {
    return '$sender le ha enviado un regalo a $target ${gift.icon} (${gift.name})';
  }
}

class GiftItem {
  final int id;
  final String name;
  final String icon;
  final int value;

  const GiftItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.value,
  });
}
