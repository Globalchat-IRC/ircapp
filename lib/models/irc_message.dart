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
  final String? messageId; // ID único del mensaje para edición/reacciones/respuestas
  final bool isEdited; // Indica si el mensaje fue editado
  final DateTime? editedAt; // Timestamp de la última edición
  final String? replyToMessageId; // ID del mensaje al que responde (para threads)
  final Map<String, int> reactions; // Reacciones: emoji -> cantidad

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
    this.messageId,
    this.isEdited = false,
    this.editedAt,
    this.replyToMessageId,
    Map<String, int>? reactions,
  }) : reactions = reactions ?? {};

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
    String? messageId,
    bool? isEdited,
    DateTime? editedAt,
    String? replyToMessageId,
    Map<String, int>? reactions,
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
      messageId: messageId ?? this.messageId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      reactions: reactions ?? this.reactions,
    );
  }
  
  // Generar un ID único para el mensaje basado en timestamp y contenido
  static String generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
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
    // Buscar si el usuario ya existe (case-insensitive)
    final nickLower = nick.toLowerCase();
    String? existingNick;
    for (var existingUser in users) {
      if (existingUser.toLowerCase() == nickLower) {
        existingNick = existingUser;
        break;
      }
    }
    
    // Si no existe, agregarlo
    if (existingNick == null) {
      users.add(nick);
      existingNick = nick;
    }
    
    // Actualizar host y modo usando el nick existente (para mantener consistencia de mayúsculas/minúsculas)
    if (host != null) {
      userHosts[existingNick] = host;
    }
    if (mode != null) {
      userModes[existingNick] = mode;
    }
  }

  void removeUser(String nick) {
    // Buscar el usuario de forma case-insensitive
    final nickLower = nick.toLowerCase();
    String? existingNick;
    for (var user in users) {
      if (user.toLowerCase() == nickLower) {
        existingNick = user;
        break;
      }
    }
    
    // Si se encontró, remover usando el nick exacto (para mantener consistencia)
    if (existingNick != null) {
      users.remove(existingNick);
      userHosts.remove(existingNick);
      userModes.remove(existingNick);
    }
  }

  void setTopic(String? newTopic) {
    topic = newTopic;
  }

  bool isRobot(String nick) {
    // Verificar primero el modo +b (más rápido y confiable)
    if (userModes[nick] == '+b') {
      return true;
    }
    
    // Si no tiene modo +b, verificar el host
    final host = userHosts[nick] ?? '';
    final nickLower = nick.toLowerCase();
    
    // Verificar si el nick contiene "robot", "bot", o empieza con "radio" (para bots de radio)
    final isBotByNick = nickLower.contains('robot') || 
                        nickLower.contains('bot') ||
                        nickLower.endsWith('bot') ||
                        nickLower.startsWith('radio');
    
    if (host.isEmpty) {
      return isBotByNick;
    }
    
    final hostLower = host.toLowerCase();
    // Verificar si el host contiene "robot.globalchat.org" o "robot"
    // También verificar variaciones con mayúsculas/minúsculas
    final isBotByHost = hostLower.contains('robot.globalchat.org') ||
                        hostLower.contains('robot.globalchat') ||
                        hostLower.contains('.robot.') ||
                        hostLower.contains('robot');
    
    return isBotByNick || isBotByHost;
  }

  // Obtener el modo del usuario (prefijo IRC)
  String? getUserMode(String nick) {
    return userModes[nick];
  }
}
