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

class IRCChannel {
  final String name;
  final List<IRCMessage> messages;
  final List<String> users;
  final Map<String, String> userHosts; // Mapa de nick -> host
  final Map<String, String> userModes; // Mapa de nick -> modo (prefix: @, +, %, &)
  String? topic;
  final List<String> pinnedMessageIds; // IDs de mensajes fijados

  IRCChannel({
    required this.name,
    List<IRCMessage>? messages,
    List<String>? users,
    Map<String, String>? userHosts,
    Map<String, String>? userModes,
    this.topic,
    List<String>? pinnedMessageIds,
  })  : messages = messages ?? [],
        users = users ?? [],
        userHosts = userHosts ?? {},
        userModes = userModes ?? {},
        pinnedMessageIds = pinnedMessageIds ?? [];

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
    
    // Debug: imprimir información de entrada
    print('🤖 [isRobot] Verificando "$nick" (lower: "$nickLower"), customRobots: ${customRobots?.length ?? 0}');
    
    // PRIORIDAD 1: Verificar primero robots personalizados (lista explícita)
    // Esta es la fuente de verdad principal
    if (customRobots != null && customRobots.isNotEmpty) {
      print('🤖 [isRobot] Lista de robots personalizados: ${customRobots.map((r) => r['nick']).toList()}');
    } else {
      print('🤖 [isRobot] No hay robots personalizados (customRobots es null o vacío)');
    }
    
    // Solo verificar robots personalizados si la lista no está vacía
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
        
        // Verificar por nick (coincidencia exacta, case-insensitive)
        if (robotNick == nickLower) {
          // Si tiene host especificado, verificar que coincida
          if (robotHost != null && robotHost.isNotEmpty) {
            if (host.isNotEmpty && host.toLowerCase().contains(robotHost.toLowerCase())) {
              print('🤖 [isRobot] ✅ Detectado "$nick" como robot personalizado (nick y host coinciden)');
              return true;
            } else {
              // Si el host no coincide pero el nick está en la lista, aún así es robot
              // (el host puede cambiar o no estar disponible aún)
              print('🤖 [isRobot] ✅ Detectado "$nick" como robot personalizado (nick en lista, host no coincide pero se acepta)');
              return true;
            }
          } else {
            // Si no tiene host especificado, el nick en la lista es suficiente
            print('🤖 [isRobot] ✅ Detectado "$nick" como robot personalizado (nick en lista)');
            return true;
          }
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
    // Solo usar +b si el nick TERMINA en "bot" (muy específico)
    if (userMode == '+b' && nickLower.endsWith('bot')) {
      print('🤖 [isRobot] ✅ Detectado "$nick" como robot (modo +b y nick termina en bot)');
      return true;
    }
    
    // Verificar si el nick contiene indicadores MUY específicos de bot
    // Ser EXTREMADAMENTE restrictivo: solo si TERMINA en "bot" o EMPIEZA con "radio"
    final isBotByNick = nickLower.endsWith('bot') ||
                        nickLower.startsWith('radio');
    
    // Si el host está vacío, solo confiar en el nick si es MUY específico
    if (host.isEmpty) {
      if (isBotByNick) {
        print('🤖 [isRobot] ✅ Detectado "$nick" como robot por nick específico (sin host)');
        return true;
      } else {
        print('🤖 [isRobot] ❌ "$nick" NO es robot (host vacío y nick no es específico de bot)');
        return false;
      }
    }
    
    // Verificar host SOLO si es específicamente de robots de GlobalChat
    final hostLower = host.toLowerCase();
    final isBotByHost = hostLower == 'robot.globalchat.org' ||
                        hostLower.endsWith('.robot.globalchat.org') ||
                        (hostLower.startsWith('robot.') && hostLower.contains('globalchat.org') && !hostLower.contains('netadmin') && !hostLower.contains('admin'));
    
    // Retornar true SOLO si el nick claramente indica bot O el host es específicamente de robots
    final result = isBotByNick || isBotByHost;
    if (result) {
      print('🤖 [isRobot] ✅ Detectado "$nick" como robot (nick: $isBotByNick, host: $isBotByHost, host: "$host")');
    } else {
      print('🤖 [isRobot] ❌ "$nick" NO es robot (nick: $isBotByNick, host: $isBotByHost, host: "$host")');
    }
    return result;
  }
  
  // Método auxiliar para debug: verificar si un nick está en la lista de robots personalizados
  bool _isInCustomRobotsList(String nickLower, List<Map<String, dynamic>> customRobots) {
    for (var robotData in customRobots) {
      final robotNick = (robotData['nick'] as String?)?.toLowerCase();
      if (robotNick == nickLower) {
        return true;
      }
    }
    return false;
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
