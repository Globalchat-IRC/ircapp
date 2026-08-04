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
  final bool isPinned; // Indica si el mensaje está fijado
  final DateTime? pinnedAt; // Timestamp de cuando se fijó el mensaje
  final String? pinnedBy; // Nick de quien fijó el mensaje
  final DateTime? expiresAt; // Timestamp de expiración para mensajes temporales
  final Map<String, DateTime> readBy; // Confirmación de lectura: nick -> timestamp

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
    this.isPinned = false,
    this.pinnedAt,
    this.pinnedBy,
    this.expiresAt,
    Map<String, DateTime>? readBy,
  }) : reactions = reactions ?? {},
       readBy = readBy ?? {};

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
    bool? isPinned,
    DateTime? pinnedAt,
    String? pinnedBy,
    DateTime? expiresAt,
    Map<String, DateTime>? readBy,
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
      isPinned: isPinned ?? this.isPinned,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      expiresAt: expiresAt ?? this.expiresAt,
      readBy: readBy ?? this.readBy,
    );
  }
  
  // Generar un ID único para el mensaje basado en timestamp y contenido
  static String generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
  }

  // Serializar a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'nick': nick,
      'channel': channel,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isSystem': isSystem,
      'isPending': isPending,
      'pendingId': pendingId,
      'delaySeconds': delaySeconds,
      'isAction': isAction,
      'messageId': messageId,
      'isEdited': isEdited,
      'editedAt': editedAt?.millisecondsSinceEpoch,
      'replyToMessageId': replyToMessageId,
      'reactions': reactions,
      'isPinned': isPinned,
      'pinnedAt': pinnedAt?.millisecondsSinceEpoch,
      'pinnedBy': pinnedBy,
      'expiresAt': expiresAt?.millisecondsSinceEpoch,
      'readBy': readBy.map((key, value) => MapEntry(key, value.millisecondsSinceEpoch)),
    };
  }

  // Deserializar desde JSON
  factory IRCMessage.fromJson(Map<String, dynamic> json) {
    return IRCMessage(
      nick: json['nick'] as String,
      channel: json['channel'] as String,
      message: json['message'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isSystem: json['isSystem'] as bool? ?? false,
      isPending: json['isPending'] as bool? ?? false,
      pendingId: json['pendingId'] as String?,
      delaySeconds: json['delaySeconds'] as int?,
      isAction: json['isAction'] as bool? ?? false,
      messageId: json['messageId'] as String?,
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['editedAt'] as int)
          : null,
      replyToMessageId: json['replyToMessageId'] as String?,
      reactions: json['reactions'] != null
          ? Map<String, int>.from(json['reactions'] as Map)
          : {},
      isPinned: json['isPinned'] as bool? ?? false,
      pinnedAt: json['pinnedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['pinnedAt'] as int)
          : null,
      pinnedBy: json['pinnedBy'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int)
          : null,
      readBy: json['readBy'] != null
          ? Map<String, DateTime>.from(
              (json['readBy'] as Map).map((key, value) => MapEntry(
                key as String,
                DateTime.fromMillisecondsSinceEpoch(value as int),
              )))
          : {},
    );
  }

  @override
  String toString() => '[$channel] <$nick> $message${isPending ? " [PENDIENTE]" : ""}';
}

class ChannelBan {
  final String mask;
  final String setter;
  final DateTime? time;

  const ChannelBan({required this.mask, required this.setter, this.time});
}

class IRCChannel {
  final String name;
  final List<IRCMessage> messages;
  final List<String> users;
  final Map<String, String> userHosts; // Mapa de nick -> host
  final Map<String, String> userModes; // Mapa de nick -> modo (prefix: @, +, %, &)
  String? topic;
  final List<String> pinnedMessageIds; // IDs de mensajes fijados
  final Set<String> channelModes; // Modos del canal (p. ej. 'n', 't', 'm', 'i', 's', 'k', 'l')
  String? key; // Clave del canal (modo +k)
  int? limit; // Límite de usuarios (modo +l)
  final List<ChannelBan> bans; // Lista de baneados (modo +b)

  IRCChannel({
    required this.name,
    List<IRCMessage>? messages,
    List<String>? users,
    Map<String, String>? userHosts,
    Map<String, String>? userModes,
    this.topic,
    List<String>? pinnedMessageIds,
    Set<String>? channelModes,
    this.key,
    this.limit,
    List<ChannelBan>? bans,
  })  : messages = messages ?? [],
        users = users ?? [],
        userHosts = userHosts ?? {},
        userModes = userModes ?? {},
        pinnedMessageIds = pinnedMessageIds ?? [],
        channelModes = channelModes ?? <String>{},
        bans = bans ?? [];

  IRCChannel copy() {
    return IRCChannel(
      name: name,
      messages: List.from(messages),
      users: List.from(users),
      userHosts: Map<String, String>.from(userHosts),
      userModes: Map<String, String>.from(userModes),
      topic: topic,
      pinnedMessageIds: List<String>.from(pinnedMessageIds),
      channelModes: Set<String>.from(channelModes),
      key: key,
      limit: limit,
      bans: List<ChannelBan>.from(bans),
    );
  }

  bool hasChannelMode(String mode) => channelModes.contains(mode);

  String get modeString {
    if (channelModes.isEmpty) return '';
    final sorted = channelModes.toList()..sort();
    return '+${sorted.join()}';
  }

  void addMessage(IRCMessage msg) {
    // Evitar duplicados por messageId (reconexión, replay del servidor, Chromebook)
    if (msg.messageId != null &&
        messages.any((m) => m.messageId == msg.messageId)) {
      return;
    }
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
    // IMPORTANTE: Actualizar el modo SIEMPRE que se proporcione, incluso si el usuario ya existe
    // Esto asegura que los modos se actualicen correctamente cuando se procesa NAMES
    if (mode != null) {
      userModes[existingNick] = mode;
    }
    // Si mode es null, NO limpiar el modo existente - mantenerlo
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

  bool isRobot(String nick, {List<Map<String, dynamic>>? customRobots}) {
    final nickLower = nick.toLowerCase().trim();
    if (customRobots != null && customRobots.isNotEmpty) {
      // Buscar el host del usuario (case-insensitive)
      String? host;
      for (var entry in userHosts.entries) {
        if (entry.key.toLowerCase() == nickLower) {
          host = entry.value;
          break;
        }
      }
      host = host ?? '';
      
      for (var robotData in customRobots) {
        final robotNick = (robotData['nick'] as String?)?.toLowerCase();
        final robotHost = robotData['host'] as String?;
        
        if (robotNick == nickLower) {
          if (robotHost != null && robotHost.isNotEmpty) {
            if (host.isNotEmpty && host.toLowerCase().contains(robotHost.toLowerCase())) return true;
          }
          return true;
        }
        
        // NO verificar por host si el nick no está en la lista
        // La verificación por host solo debe usarse para confirmar robots que ya están en la lista por nick
        // Esto evita falsos positivos cuando robots tienen hosts genéricos como "GlobalChat.Org"
      }
    }
    
    // PRIORIDAD 2: Detección automática SOLO como último recurso
    // Ser MUY restrictivo para evitar falsos positivos
    
    // Buscar el host del usuario (case-insensitive)
    String? host;
    for (var entry in userHosts.entries) {
      if (entry.key.toLowerCase() == nickLower) {
        host = entry.value;
        break;
      }
    }
    host = host ?? '';
    
    // Verificar el modo +b SOLO si el nick también termina en "bot"
    String? userMode;
    if (userModes.containsKey(nick)) {
      userMode = userModes[nick];
    } else {
      // Buscar de forma case-insensitive
      for (var entry in userModes.entries) {
        if (entry.key.toLowerCase() == nickLower) {
          userMode = entry.value;
          break;
        }
      }
    }
    if (userMode == '+b' && nickLower.endsWith('bot')) return true;
    
    // Verificar si el nick contiene indicadores MUY específicos de bot
    // Ser EXTREMADAMENTE restrictivo: solo si TERMINA en "bot" o EMPIEZA con "radio"
    final isBotByNick = nickLower.endsWith('bot') ||
                        nickLower.startsWith('radio');
    
    if (host.isEmpty) return isBotByNick;
    
    // Verificar host SOLO si es específicamente de robots de GlobalChat
    final hostLower = host.toLowerCase();
    final isBotByHost = hostLower == 'robot.globalchat.org' ||
                        hostLower.endsWith('.robot.globalchat.org') ||
                        (hostLower.startsWith('robot.') && hostLower.contains('globalchat.org') && !hostLower.contains('netadmin') && !hostLower.contains('admin'));
    
    return isBotByNick || isBotByHost;
  }
  
  // Obtener el modo del usuario (prefijo IRC)
  // Buscar de forma case-insensitive para encontrar el modo correcto
  String? getUserMode(String nick) {
    if (userModes.containsKey(nick)) return userModes[nick];
    final nickLower = nick.toLowerCase();
    for (var entry in userModes.entries) {
      if (entry.key.toLowerCase() == nickLower) return entry.value;
    }
    return null;
  }

  void addBan(ChannelBan ban) {
    final existing = bans.indexWhere(
      (b) => b.mask.toLowerCase() == ban.mask.toLowerCase(),
    );
    if (existing >= 0) {
      bans[existing] = ban;
    } else {
      bans.add(ban);
    }
  }

  void removeBan(String mask) {
    bans.removeWhere(
      (b) => b.mask.toLowerCase() == mask.toLowerCase(),
    );
  }

  void clearBans() {
    bans.clear();
  }
}
