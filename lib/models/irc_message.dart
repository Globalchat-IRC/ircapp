class IRCMessage {
  final String nick;
  final String channel;
  final String message;
  final DateTime timestamp;
  final bool isSystem;

  IRCMessage({
    required this.nick,
    required this.channel,
    required this.message,
    required this.timestamp,
    this.isSystem = false,
  });

  @override
  String toString() => '[$channel] <$nick> $message';
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
