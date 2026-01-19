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
      print('🔍 [addUser] Guardado modo "$mode" para usuario "$existingNick" (userModes ahora: $userModes)');
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
    
    // Verificar primero robots personalizados si se proporcionan
    if (customRobots != null) {
      final host = userHosts[nick] ?? '';
      
      for (var robotData in customRobots) {
        final robotNick = (robotData['nick'] as String?)?.toLowerCase();
        final robotHost = robotData['host'] as String?;
        
        // Verificar por nick
        if (robotNick == nickLower) {
          // Si tiene host especificado, verificar que coincida
          if (robotHost != null && host.isNotEmpty) {
            if (host.toLowerCase().contains(robotHost.toLowerCase())) {
              return true;
            }
          } else {
            // Si no tiene host, cualquier host es válido
            return true;
          }
        }
        
        // Verificar por host si no se encontró por nick
        if (robotHost != null && host.isNotEmpty) {
          if (host.toLowerCase().contains(robotHost.toLowerCase())) {
            return true;
          }
        }
      }
    }
    
    // Verificar primero el modo +b (más rápido y confiable)
    // Buscar de forma case-insensitive en userModes
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
    if (userMode == '+b') {
      return true;
    }
    
    // Verificar si es el usuario "globalchat" en el canal "#globalchat" (es un robot)
    // Normalizar el nombre del canal: remover espacios y convertir a minúsculas
    final channelNameLower = name.toLowerCase().trim();
    final channelNameWithoutHash = channelNameLower.replaceFirst(RegExp(r'^#+'), '');
    
    if (nickLower == 'globalchat') {
      // Debug: imprimir información de detección
      print('🤖 [isRobot] Verificando robot para nick: "$nick" (lower: "$nickLower") en canal: "$name" (lower: "$channelNameLower", sin #: "$channelNameWithoutHash")');
      
      // Verificar si estamos en el canal #globalchat (con o sin #, case-insensitive)
      final isGlobalChatChannel = channelNameLower == '#globalchat' || channelNameWithoutHash == 'globalchat';
      
      if (isGlobalChatChannel) {
        print('🤖 [isRobot] ✅ Detectado usuario "$nick" como robot en canal "$name"');
        return true;
      } else {
        print('🤖 [isRobot] ❌ Usuario "$nick" NO es robot (canal "$name" no es #globalchat)');
      }
    }
    
    // Si no tiene modo +b, verificar el host
    final host = userHosts[nick] ?? '';
    
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
    // Por defecto, detectar automáticamente robots con "Robot.GlobalChat.Org" en su host
    final isBotByHost = hostLower.contains('robot.globalchat.org') ||
                        hostLower.contains('robot.globalchat') ||
                        hostLower.contains('.robot.') ||
                        hostLower.contains('robot');
    
    return isBotByNick || isBotByHost;
  }

  // Obtener el modo del usuario (prefijo IRC)
  // Buscar de forma case-insensitive para encontrar el modo correcto
  String? getUserMode(String nick) {
    // Primero intentar con el nick exacto
    if (userModes.containsKey(nick)) {
      final mode = userModes[nick];
      print('🔍 [getUserMode] Encontrado modo "$mode" para "$nick" (búsqueda exacta)');
      return mode;
    }
    
    // Si no se encuentra, buscar de forma case-insensitive
    final nickLower = nick.toLowerCase();
    for (var entry in userModes.entries) {
      if (entry.key.toLowerCase() == nickLower) {
        final mode = entry.value;
        print('🔍 [getUserMode] Encontrado modo "$mode" para "$nick" (búsqueda case-insensitive, key original: "${entry.key}")');
        return mode;
      }
    }
    
    print('🔍 [getUserMode] NO encontrado modo para "$nick" (userModes keys: ${userModes.keys.toList()})');
    return null;
  }
}
