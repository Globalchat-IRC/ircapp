class EmojiConfig {
  final String ownerEmoji; // Emoji para dueño del canal (&)
  final String operatorEmoji; // Emoji para operadores (@)
  final String halfopEmoji; // Emoji para halfop (%)
  final String voiceEmoji; // Emoji para voz (+)
  final String userEmoji; // Emoji para usuarios normales
  final String robotEmoji; // Emoji para robots

  EmojiConfig({
    this.ownerEmoji = '👑',
    this.operatorEmoji = '👑',
    this.halfopEmoji = '⭐',
    this.voiceEmoji = '🎤',
    this.userEmoji = '👤',
    this.robotEmoji = '🤖',
  });

  // Cargar emoji desde URL de JoyPixels
  static String getEmojiFromUrl(String unicode) {
    // Convertir código unicode a URL de imagen
    // Ejemplo: 1F451 -> https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f451.png
    final code = unicode.toLowerCase().replaceAll('u+', '').replaceAll(' ', '-');
    return 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/$code.png';
  }

  // Emoji por defecto (emojis Unicode)
  static EmojiConfig get defaultConfig => EmojiConfig();

  // Configuración con imágenes desde JoyPixels
  static EmojiConfig fromJoyPixels({
    String? ownerUnicode,
    String? operatorUnicode,
    String? halfopUnicode,
    String? voiceUnicode,
    String? userUnicode,
    String? robotUnicode,
  }) {
    return EmojiConfig(
      ownerEmoji: ownerUnicode != null ? getEmojiFromUrl(ownerUnicode) : '👑',
      operatorEmoji: operatorUnicode != null ? getEmojiFromUrl(operatorUnicode) : '👑',
      halfopEmoji: halfopUnicode != null ? getEmojiFromUrl(halfopUnicode) : '⭐',
      voiceEmoji: voiceUnicode != null ? getEmojiFromUrl(voiceUnicode) : '🎤',
      userEmoji: userUnicode != null ? getEmojiFromUrl(userUnicode) : '👤',
      robotEmoji: robotUnicode != null ? getEmojiFromUrl(robotUnicode) : '🤖',
    );
  }

  EmojiConfig copyWith({
    String? ownerEmoji,
    String? operatorEmoji,
    String? halfopEmoji,
    String? voiceEmoji,
    String? userEmoji,
    String? robotEmoji,
  }) {
    return EmojiConfig(
      ownerEmoji: ownerEmoji ?? this.ownerEmoji,
      operatorEmoji: operatorEmoji ?? this.operatorEmoji,
      halfopEmoji: halfopEmoji ?? this.halfopEmoji,
      voiceEmoji: voiceEmoji ?? this.voiceEmoji,
      userEmoji: userEmoji ?? this.userEmoji,
      robotEmoji: robotEmoji ?? this.robotEmoji,
    );
  }
}

