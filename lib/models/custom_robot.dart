/// Modelo para representar un robot personalizado
class CustomRobot {
  final String nick;
  final String icon;
  final String? host; // Opcional: host/IP para detección automática

  CustomRobot({
    required this.nick,
    required this.icon,
    this.host,
  });

  Map<String, dynamic> toJson() {
    return {
      'nick': nick,
      'icon': icon,
      'host': host,
    };
  }

  factory CustomRobot.fromJson(Map<String, dynamic> json) {
    return CustomRobot(
      nick: json['nick'] as String,
      icon: json['icon'] as String,
      host: json['host'] as String?,
    );
  }

  CustomRobot copyWith({
    String? nick,
    String? icon,
    String? host,
  }) {
    return CustomRobot(
      nick: nick ?? this.nick,
      icon: icon ?? this.icon,
      host: host ?? this.host,
    );
  }
}

