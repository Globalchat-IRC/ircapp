class IRCMessage {
  final String nick;
  final String channel;
  final String message;
  final DateTime timestamp;
  final bool isSystem;
  final bool isPending; // Mensaje enviado pero aún no confirmado por el servidor
  final String? pendingId; // ID único para identificar mensajes pendientes
  final int? delaySeconds; // Delay configurado para este mensaje
  final bool isAction; // Mensaje de acción (/me)

  IRCMessage({
    required this.nick,
    required this.channel,
    required this.message,
    required this.timestamp,
    this.isSystem = false,
    this.isPending = false,
    this.pendingId,
    this.delaySeconds,
    this.isAction = false,
  });

  // Crear una copia con campos modificados
  IRCMessage copyWith({
    String? nick,
    String? channel,
    String? message,
    DateTime? timestamp,
    bool? isSystem,
    bool? isPending,
    String? pendingId,
    int? delaySeconds,
    bool? isAction,
  }) {
    return IRCMessage(
      nick: nick ?? this.nick,
      channel: channel ?? this.channel,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isSystem: isSystem ?? this.isSystem,
      isPending: isPending ?? this.isPending,
      pendingId: pendingId ?? this.pendingId,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      isAction: isAction ?? this.isAction,
    );
  }

  @override
  String toString() => '[$channel] <$nick> $message${isPending ? " [PENDIENTE]" : ""}';
}

class IRCChannel {
  final String name;
  final List<IRCMessage> messages;
  final List<String> users;
  final Map<String, String> userHosts; // Mapa de nick -> host
  final Map<String, String> userModes; // Mapa de nick -> modo (prefix: @, +, %, &)
  String? topic;

  IRCChannel({
    required this.name,
    List<IRCMessage>? messages,
    List<String>? users,
    Map<String, String>? userHosts,
    Map<String, String>? userModes,
    this.topic,
  })  : messages = messages ?? [],
        users = users ?? [],
        userHosts = userHosts ?? {},
        userModes = userModes ?? {};

  void addMessage(IRCMessage msg) {
    messages.add(msg);
  }

  void addUser(String nick, {String? host, String? mode}) {
    if (!users.contains(nick)) {
      users.add(nick);
    }
    if (host != null) {
      userHosts[nick] = host;
    }
    if (mode != null) {
      userModes[nick] = mode;
    }
  }

  void removeUser(String nick) {
    users.remove(nick);
    userHosts.remove(nick);
    userModes.remove(nick);
  }

  void setTopic(String? newTopic) {
    topic = newTopic;
  }

  bool isRobot(String nick) {
    final host = userHosts[nick] ?? '';
    return host.toLowerCase().contains('robot') || userModes[nick] == '+b';
  }

  // Obtener el modo del usuario (prefijo IRC)
  String? getUserMode(String nick) {
    return userModes[nick];
  }
}
