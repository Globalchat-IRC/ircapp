class EmojiConfig {
  final String ownerEmoji; // Emoji para dueño del canal (~, &)
  final String adminEmoji; // Emoji para admin (!)
  final String operatorEmoji; // Emoji para operadores (@)
  final String halfopEmoji; // Emoji para halfop/DJ (%)
  final String voiceEmoji; // Emoji para voz/VIP (+)
  final String userEmoji; // Emoji para usuarios normales
  final String robotEmoji; // Emoji para robots

  EmojiConfig({
    this.ownerEmoji = '👑',
    this.adminEmoji = '🛡️',
    this.operatorEmoji = '⚡',
    this.halfopEmoji = '🎵',
    this.voiceEmoji = '⭐',
    this.userEmoji = '👤',
    this.robotEmoji = '🤖',
  });

  static String getEmojiFromUrl(String unicode) {
    final code = unicode.toLowerCase().replaceAll('u+', '').replaceAll(' ', '-');
    return 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/$code.png';
  }

  static EmojiConfig get defaultConfig => EmojiConfig();

  static EmojiConfig fromJoyPixels({
    String? ownerUnicode,
    String? adminUnicode,
    String? operatorUnicode,
    String? halfopUnicode,
    String? voiceUnicode,
    String? userUnicode,
    String? robotUnicode,
  }) {
    return EmojiConfig(
      ownerEmoji: ownerUnicode != null ? getEmojiFromUrl(ownerUnicode) : '👑',
      adminEmoji: adminUnicode != null ? getEmojiFromUrl(adminUnicode) : '🛡️',
      operatorEmoji: operatorUnicode != null ? getEmojiFromUrl(operatorUnicode) : '⚡',
      halfopEmoji: halfopUnicode != null ? getEmojiFromUrl(halfopUnicode) : '🎵',
      voiceEmoji: voiceUnicode != null ? getEmojiFromUrl(voiceUnicode) : '⭐',
      userEmoji: userUnicode != null ? getEmojiFromUrl(userUnicode) : '👤',
      robotEmoji: robotUnicode != null ? getEmojiFromUrl(robotUnicode) : '🤖',
    );
  }

  EmojiConfig copyWith({
    String? ownerEmoji,
    String? adminEmoji,
    String? operatorEmoji,
    String? halfopEmoji,
    String? voiceEmoji,
    String? userEmoji,
    String? robotEmoji,
  }) {
    return EmojiConfig(
      ownerEmoji: ownerEmoji ?? this.ownerEmoji,
      adminEmoji: adminEmoji ?? this.adminEmoji,
      operatorEmoji: operatorEmoji ?? this.operatorEmoji,
      halfopEmoji: halfopEmoji ?? this.halfopEmoji,
      voiceEmoji: voiceEmoji ?? this.voiceEmoji,
      userEmoji: userEmoji ?? this.userEmoji,
      robotEmoji: robotEmoji ?? this.robotEmoji,
    );
  }
}
