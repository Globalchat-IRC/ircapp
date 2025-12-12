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
  String? topic;

  IRCChannel({
    required this.name,
    List<IRCMessage>? messages,
    List<String>? users,
    Map<String, String>? userHosts,
    this.topic,
  })  : messages = messages ?? [],
        users = users ?? [],
        userHosts = userHosts ?? {};

  void addMessage(IRCMessage msg) {
    messages.add(msg);
  }

  void addUser(String nick, {String? host}) {
    if (!users.contains(nick)) {
      users.add(nick);
    }
    if (host != null) {
      userHosts[nick] = host;
    }
  }

  void removeUser(String nick) {
    users.remove(nick);
    userHosts.remove(nick);
  }

  void setTopic(String? newTopic) {
    topic = newTopic;
  }

  bool isRobot(String nick) {
    final host = userHosts[nick] ?? '';
    return host.toLowerCase().contains('robot');
  }
}
