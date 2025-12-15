class WhoisInfo {
  final String nick;
  final String? username;
  final String? host;
  final String? realName;
  final String? server;
  final String? serverInfo;
  final int? idleSeconds;
  final DateTime? signonTime;
  final List<String> channels;
  final bool isAway;
  final String? awayMessage;
  // Información de staff / operador
  final bool isStaff;
  final String? staffRole;

  WhoisInfo({
    required this.nick,
    this.username,
    this.host,
    this.realName,
    this.server,
    this.serverInfo,
    this.idleSeconds,
    this.signonTime,
    this.channels = const [],
    this.isAway = false,
    this.awayMessage,
    this.isStaff = false,
    this.staffRole,
  });

  WhoisInfo copyWith({
    String? nick,
    String? username,
    String? host,
    String? realName,
    String? server,
    String? serverInfo,
    int? idleSeconds,
    DateTime? signonTime,
    List<String>? channels,
    bool? isAway,
    String? awayMessage,
    bool? isStaff,
    String? staffRole,
  }) {
    return WhoisInfo(
      nick: nick ?? this.nick,
      username: username ?? this.username,
      host: host ?? this.host,
      realName: realName ?? this.realName,
      server: server ?? this.server,
      serverInfo: serverInfo ?? this.serverInfo,
      idleSeconds: idleSeconds ?? this.idleSeconds,
      signonTime: signonTime ?? this.signonTime,
      channels: channels ?? this.channels,
      isAway: isAway ?? this.isAway,
      awayMessage: awayMessage ?? this.awayMessage,
      isStaff: isStaff ?? this.isStaff,
      staffRole: staffRole ?? this.staffRole,
    );
  }
}



