import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/irc_message.dart';
import 'chat_history_service.dart';
import '../models/whois_info.dart';
import '../utils/irc_color_parser.dart';
import 'irc_connection_interface.dart';
import 'irc_connection_factory.dart';
import '../utils/platform_utils.dart';

class IRCService {
  IRCConnection? _connection;
  String? _currentHost; // Guardar host para serverHost getter
  String? _nickname;
  String? _currentChannel;
  Map<String, IRCChannel> channels = {};
  final List<Function(IRCMessage)> _messageListeners = [];
  final List<Function(String)> _userListListeners = [];
  final List<Function(String)> _topicListeners = [];
  final List<Function()> _connectionListeners = [];
  final List<Function()> _disconnectionListeners = [];
  final List<Function(WhoisInfo)> _whoisListeners = [];
  final List<Function(String)> _nickChangeListeners = []; // Listeners para cambios de nick
  final List<Function()> _ircopListeners = []; // Listeners para cuando se identifica como IRCop
  final List<Function(int)> _lagListeners = []; // Listeners para actualizaciones de lag
  final List<Function(String)> _debugLogListeners = []; // Listeners para logs de debug
  Map<String, WhoisInfo> _whoisCache = {};
  Map<String, WhoisInfo> _pendingWhois = {}; // Para acumular información de whois
  DateTime? _lastPingTime; // Timestamp del último PING recibido
  
  // Resultados de comandos LIST y WHO
  final List<Map<String, dynamic>> _listResults = []; // Lista de canales
  final List<Map<String, dynamic>> _whoResults = []; // Lista de usuarios de WHO
  final List<Function(List<Map<String, dynamic>>)> _listListeners = [];
  final List<Function(List<Map<String, dynamic>>)> _whoListeners = [];
  
  // Resultados de comandos IRCop (LINKS, STATS, TRACE, MAP, MOTD, etc.)
  final List<String> _ircopCommandResults = []; // Líneas de respuesta de comandos IRCop
  final List<Function(List<String>)> _ircopCommandListeners = [];
  String? _currentIRCOpCommand; // Comando IRCop actual que estamos esperando
  String? _currentIRCOpEndCode; // Código numérico que indica el fin del comando
  Timer? _ircopCommandTimer; // Timer para comandos sin código de fin específico (como REHASH)
  bool _isIRCOp = false; // Cache del estado de IRCop del usuario actual
  final Set<String> _ignoredUsers = {}; // Lista de usuarios ignorados (en minúsculas)
  final Map<String, Timer> _pendingMessageTimers = {}; // Timers para mensajes pendientes
  final Map<String, Completer<int?>> _statusCheckCompleters = {}; // Completers para verificaciones de status
  StreamSubscription? _socketSubscription;
  late Completer<void> _connectionCompleter;
  bool _isConnected = false;
  bool _isRegistered = false; // Indica si el usuario está completamente registrado (recibió 001)
  bool _useSSL = false;
  Timer? _lagPingTimer; // Timer para enviar PING periódicamente y medir lag
  DateTime? _lastPingSent; // Timestamp del último PING enviado
  String? _lastPingToken; // Token del último PING enviado para identificar la respuesta

  bool get isConnected => _isConnected;
  String? get currentChannel => _currentChannel;
  String? get nickname => _nickname;
  Map<String, IRCChannel> get allChannels => channels;
  bool get isIRCOp => _isIRCOp;
  
  bool get _hasActiveConnection => _connection != null && _connection!.isConnected;

  /// Obtiene el host del servidor conectado
  String? get serverHost => _currentHost;

  String _currentServerId(String host, int port) => '$host:$port${_useSSL ? ':ssl' : ''}';

  Future<void> connect({
    required String host,
    required int port,
    required String nickname,
    bool useSSL = true,
  }) async {
    try {
      _useSSL = useSSL;
      _currentHost = host;
      print('📡 [IRCService.connect] Connecting to $host:$port as $nickname (SSL: $useSSL)');
      print('📡 [IRCService.connect] Platform: ${PlatformUtils.isWeb ? "Web" : "Native"}');
      _nickname = nickname;
      _isRegistered = false; // Reset registration status
      _connectionCompleter = Completer<void>(); // Reinicializar el completer
      
      // Crear conexión apropiada para la plataforma
      _connection = IRCConnectionFactory.create();
      
      // Conectar usando la interfaz abstracta
      await _connection!.connect(host, port, useSSL: useSSL);
      print('✅ [IRCService] Connection established to $host:$port');
      
      // Start listening to incoming data (non-blocking)
      // El stream ya devuelve String, no necesita decodificación
      _socketSubscription = _connection!.stream.listen(
        (String data) {
          _handleData(data);
        },
        onDone: () {
          // print('⛔ [IRCService] Connection closed');
          _onDisconnect();
        },
        onError: (error) {
          // print('❌ [IRCService] Connection error: $error');
          _onDisconnect();
        },
      );

      // Send initial IRC commands
      _sendCommand('NICK $nickname');
      _sendCommand('USER $nickname 0 * :$nickname');
      
      print('✅ [IRCService] Commands sent: NICK $nickname, USER $nickname');
      // print('✅ [IRCService] Listener registered');
      
      // Set connection as established
      _isConnected = true;
      _startLagPingTimer();
      
      // Notify listeners
      // print('📢 [IRCService] Notifying listeners');
      for (var listener in _connectionListeners) {
        listener();
      }
      
      // print('✅ [IRCService.connect] Connection completed and returned');
    } catch (e) {
      // print('❌ [IRCService] Fatal connection error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void disconnect() {
    if (_connection != null && _connection!.isConnected) {
      _sendCommand('QUIT :Goodbye');
      _socketSubscription?.cancel();
      // Cancelar todos los timers pendientes
      _pendingMessageTimers.values.forEach((timer) => timer.cancel());
      _pendingMessageTimers.clear();
      _connection!.close();
      _connection = null;
      _isConnected = false;
      _currentHost = null;
    }
  }

  // Normalizar nombre de canal (case-insensitive, sin espacios)
  String _normalizeChannelName(String channelName) {
    if (channelName.isEmpty) return channelName;
    
    // Remover espacios y normalizar
    channelName = channelName.trim();
    
    // Remover cualquier ':' al inicio o después de espacios (puede venir de algunos mensajes IRC)
    while (channelName.startsWith(':')) {
      channelName = channelName.substring(1).trim();
    }
    
    // Remover cualquier '#' duplicado al inicio
    while (channelName.startsWith('##')) {
      channelName = channelName.substring(1);
    }
    
    // Asegurar que empiece con # (solo uno)
    if (!channelName.startsWith('#')) {
      channelName = '#$channelName';
    }
    
    // Convertir a minúsculas para comparación (IRC es case-insensitive para canales)
    final normalized = channelName.toLowerCase();
    
    // Validación final: debe empezar con # y no tener : después
    if (!normalized.startsWith('#') || normalized.contains(':#')) {
      // print('🔍 [DEBUG] ⚠️  Invalid channel name after normalization: "$normalized" (original: "$channelName")');
      // Intentar limpiar más agresivamente
      var cleaned = normalized.replaceAll(':#', '#').replaceAll('::', ':');
      if (cleaned.startsWith(':')) {
        cleaned = cleaned.substring(1);
      }
      if (!cleaned.startsWith('#')) {
        cleaned = '#$cleaned';
      }
      return cleaned.toLowerCase();
    }
    
    return normalized;
  }
  
  // Obtener la clave del canal normalizada (para búsqueda case-insensitive)
  String? _getChannelKey(String? channelName) {
    if (channelName == null || channelName.isEmpty) return null;
    return _normalizeChannelName(channelName);
  }

  void joinChannel(String channelName) {
    if (channelName.isEmpty) return;
    
    // Normalizar el nombre del canal
    final normalized = _normalizeChannelName(channelName);
    
    // print('🔍 [DEBUG] joinChannel called with: "$channelName" -> normalized: "$normalized"');
    // print('🔍 [DEBUG] User registered status: $_isRegistered');
    
    // Si el usuario no está registrado todavía, esperar un poco más
    if (!_isRegistered) {
      // print('🔍 [DEBUG] ⚠️  User not registered yet, waiting for 001 message...');
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (_isRegistered) {
          // print('🔍 [DEBUG] ✅ User now registered, joining channel');
          _doJoinChannel(normalized);
        } else {
          // print('🔍 [DEBUG] ⚠️  Still not registered, trying anyway...');
          _doJoinChannel(normalized);
        }
      });
    } else {
      _doJoinChannel(normalized);
    }
  }
  
  void _doJoinChannel(String normalized) {
    _currentChannel = normalized;
    _sendCommand('JOIN $normalized');
    
    // Initialize channel if not exists (usar nombre normalizado)
    if (!channels.containsKey(normalized)) {
      channels[normalized] = IRCChannel(name: normalized);
      // print('🔍 [DEBUG] Created new channel entry: $normalized');
    } else {
      // print('🔍 [DEBUG] Channel already exists: $normalized');
    }
    
    // Solicitar la lista de usuarios y el TOPIC después de unirse
    // Usar múltiples intentos para asegurar que se reciba la lista
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isConnected && _hasActiveConnection) {
        // print('🔍 [DEBUG] Requesting NAMES for $normalized (first attempt)');
        _sendCommand('NAMES $normalized');
        // print('🔍 [DEBUG] Requesting TOPIC for $normalized (first attempt)');
        _sendCommand('TOPIC $normalized');
      }
    });
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isConnected && _hasActiveConnection) {
        // print('🔍 [DEBUG] Requesting NAMES for $normalized (second attempt)');
        _sendCommand('NAMES $normalized');
        // print('🔍 [DEBUG] Requesting TOPIC for $normalized (second attempt)');
        _sendCommand('TOPIC $normalized');
      }
    });
    
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (_isConnected && _hasActiveConnection) {
        // print('🔍 [DEBUG] Requesting NAMES for $normalized (third attempt)');
        _sendCommand('NAMES $normalized');
        // print('🔍 [DEBUG] Requesting TOPIC for $normalized (third attempt)');
        _sendCommand('TOPIC $normalized');
      }
    });
  }

  void partChannel(String channelName) {
    final normalized = _normalizeChannelName(channelName);
    _sendCommand('PART $normalized');
    channels.remove(normalized);
    final currentNormalized = _getChannelKey(_currentChannel);
    if (currentNormalized == normalized) {
      _currentChannel = null;
    }
  }

  void sendMessage(String channel, String message, {int delaySeconds = 0, String? replyToMessageId}) {
    // Normalizar el nombre del canal
    final normalized = _normalizeChannelName(channel);
    
    // Generar un ID único para este mensaje pendiente
    final pendingId = '${DateTime.now().millisecondsSinceEpoch}_${message.hashCode}';
    
    // Add to local channel (el mensaje completo, no dividido) como PENDIENTE
    if (channels.containsKey(normalized)) {
      final msg = IRCMessage(
        nick: _nickname ?? 'You',
        channel: normalized,
        message: message, // Mensaje completo con saltos de línea
        timestamp: DateTime.now(),
        isPending: true,
        pendingId: pendingId,
        delaySeconds: delaySeconds > 0 ? delaySeconds : null,
        messageId: IRCMessage.generateMessageId(),
        replyToMessageId: replyToMessageId,
      );
      channels[normalized]!.addMessage(msg);
      _notifyMessageListeners(msg);
      // print('📤 [IRCService] Mensaje marcado como PENDIENTE: $pendingId (delay: ${delaySeconds}s)');
      
      // Programar el envío después del delay
      if (delaySeconds > 0) {
        // print('⏱️  [IRCService] Programando envío de mensaje $pendingId en ${delaySeconds}s');
        final timer = Timer(Duration(seconds: delaySeconds), () {
          // print('⏱️  [IRCService] Timer ejecutado, enviando mensaje $pendingId');
    // Dividir el mensaje en líneas y enviar cada línea como un PRIVMSG separado
    final lines = message.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
              // print('📤 [IRCService] Enviando línea: $line');
        _sendCommand('PRIVMSG $normalized :$line');
      }
    }
          // print('📤 [IRCService] Mensaje enviado al servidor después de delay: $pendingId');
          // Eliminar el timer del mapa después de ejecutarse
          _pendingMessageTimers.remove(pendingId);
          
          // Auto-confirmar después de 500ms si el servidor no hace eco
          Timer(const Duration(milliseconds: 500), () {
            final channelObj = channels[normalized];
            if (channelObj != null) {
              final currentPendingMessages = channelObj.messages.where((m) => m.isPending && m.pendingId == pendingId).toList();
              if (currentPendingMessages.isNotEmpty) {
                // print('⚠️  [IRCService] Mensaje con delay $pendingId aún pendiente después de 500ms, auto-confirmando.');
                confirmPendingMessage(normalized, message, DateTime.now());
              }
            }
          });
        });
        _pendingMessageTimers[pendingId] = timer;
      } else {
        // Sin delay, enviar inmediatamente
        // print('📤 [IRCService] Enviando mensaje sin delay inmediatamente: $pendingId');
        final lines = message.split('\n');
        for (var line in lines) {
          line = line.trim();
          if (line.isNotEmpty) {
            // print('📤 [IRCService] Enviando línea sin delay: $line');
            _sendCommand('PRIVMSG $normalized :$line');
          }
        }
        // print('✅ [IRCService] Mensaje sin delay enviado, esperando confirmación del servidor (pendingId: $pendingId)');
        
        // Si el servidor no devuelve el PRIVMSG como eco, confirmar automáticamente después de un breve delay
        // Esto es necesario porque algunos servidores IRC no devuelven el PRIVMSG como eco
        Timer(const Duration(milliseconds: 500), () {
          // Verificar si el mensaje aún está pendiente (no fue confirmado por el servidor)
          final channelObj = channels[normalized];
          if (channelObj != null) {
            final pendingMsg = channelObj.messages.firstWhere(
              (msg) => msg.pendingId == pendingId && msg.isPending,
              orElse: () => IRCMessage(
        nick: _nickname ?? 'You',
        channel: normalized,
                message: '',
        timestamp: DateTime.now(),
              ),
            );
            
            // Si el mensaje aún está pendiente, confirmarlo automáticamente
            if (pendingMsg.isPending && pendingMsg.pendingId == pendingId) {
              // print('⏰ [IRCService] Servidor no devolvió PRIVMSG, confirmando automáticamente después de 500ms');
              final confirmed = confirmPendingMessage(normalized, message, DateTime.now());
              if (confirmed) {
                // print('✅ [IRCService] Mensaje confirmado automáticamente: $pendingId');
              } else {
                // print('⚠️  [IRCService] No se pudo confirmar automáticamente el mensaje: $pendingId');
              }
            } else {
              // print('✅ [IRCService] Mensaje ya fue confirmado por el servidor: $pendingId');
            }
          }
        });
      }
    }
  }
  
  // Eliminar un mensaje pendiente antes de que llegue al servidor
  bool removePendingMessage(String channel, String pendingId) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) {
      return false;
    }
    
    // Cancelar el timer si existe
    final timer = _pendingMessageTimers.remove(pendingId);
    if (timer != null) {
      timer.cancel();
      // print('⏱️  [IRCService] Timer cancelado para mensaje: $pendingId');
    }
    
    final channelObj = channels[normalized]!;
    final index = channelObj.messages.indexWhere(
      (msg) => msg.isPending && msg.pendingId == pendingId,
    );
    
    if (index != -1) {
      channelObj.messages.removeAt(index);
      // print('🗑️  [IRCService] Mensaje pendiente eliminado: $pendingId');
      // Notificar a los listeners para actualizar la UI
      _notifyMessageListeners(channelObj.messages.isNotEmpty 
          ? channelObj.messages.last 
          : IRCMessage(
              nick: '',
              channel: normalized,
              message: '',
              timestamp: DateTime.now(),
              messageId: IRCMessage.generateMessageId(),
            ));
      return true;
    }
    
    return false;
  }
  
  // Forzar el envío inmediato del mensaje pendiente más reciente en un canal
  bool forceSendPendingMessage(String channel) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) {
      return false;
    }
    
    final channelObj = channels[normalized]!;
    // Buscar el mensaje pendiente más reciente
    final pendingMessages = channelObj.messages.where((msg) => msg.isPending && msg.pendingId != null).toList();
    if (pendingMessages.isEmpty) {
      // print('⚠️  [IRCService] No hay mensajes pendientes para forzar envío');
      return false;
    }
    
    // Ordenar por timestamp (más reciente primero) y tomar el primero
    pendingMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final pendingMsg = pendingMessages.first;
    final pendingId = pendingMsg.pendingId!;
    
    // print('⚡ [IRCService] Forzando envío inmediato del mensaje: $pendingId');
    
    // Cancelar el timer si existe
    final timer = _pendingMessageTimers.remove(pendingId);
    if (timer != null) {
      timer.cancel();
      // print('⏱️  [IRCService] Timer cancelado para forzar envío: $pendingId');
    }
    
    // Enviar el mensaje inmediatamente
    final message = pendingMsg.message;
    final lines = message.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
        // print('📤 [IRCService] Enviando línea inmediatamente: $line');
        _sendCommand('PRIVMSG $normalized :$line');
      }
    }
    
    // NO confirmar aquí - esperar a que el servidor devuelva el PRIVMSG
    // confirmPendingMessage(normalized, message, DateTime.now());
    // print('✅ [IRCService] Mensaje enviado inmediatamente: $pendingId (esperando confirmación del servidor)');
    return true;
  }
  
  // Forzar el envío inmediato de un mensaje privado pendiente
  bool forceSendPendingPrivateMessage(String nick) {
    final normalized = nick.toLowerCase();
    if (!channels.containsKey(normalized)) {
      return false;
    }
    
    final channelObj = channels[normalized]!;
    // Buscar el mensaje pendiente más reciente
    final pendingMessages = channelObj.messages.where((msg) => msg.isPending && msg.pendingId != null).toList();
    if (pendingMessages.isEmpty) {
      // print('⚠️  [IRCService] No hay mensajes privados pendientes para forzar envío');
      return false;
    }
    
    // Ordenar por timestamp (más reciente primero) y tomar el primero
    pendingMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final pendingMsg = pendingMessages.first;
    final pendingId = pendingMsg.pendingId!;
    
    // print('⚡ [IRCService] Forzando envío inmediato del mensaje privado: $pendingId');
    
    // Cancelar el timer si existe
    final timer = _pendingMessageTimers.remove(pendingId);
    if (timer != null) {
      timer.cancel();
      // print('⏱️  [IRCService] Timer cancelado para forzar envío privado: $pendingId');
    }
    
    // Enviar el mensaje inmediatamente
    final message = pendingMsg.message;
    final lines = message.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
        // print('📤 [IRCService] Enviando línea privada inmediatamente: $line');
        _sendCommand('PRIVMSG $normalized :$line');
      }
    }
    
    // Confirmar el mensaje inmediatamente
    confirmPendingMessage(normalized, message, DateTime.now());
    // print('✅ [IRCService] Mensaje privado enviado inmediatamente: $pendingId');
    return true;
  }
  
  // Confirmar un mensaje pendiente cuando el servidor lo confirma
  // Retorna true si se confirmó un mensaje, false si no se encontró
  bool confirmPendingMessage(String channel, String message, DateTime timestamp) {
    // Para canales normales, normalizar con '#'. Para queries privados (nick),
    // usar el nombre tal cual en minúsculas.
    final normalized = channel.startsWith('#')
        ? _normalizeChannelName(channel)
        : channel.trim().toLowerCase();
    if (!channels.containsKey(normalized)) {
      // print('⚠️  [IRCService] Canal no existe para confirmar: $normalized');
      return false;
    }
    
    final channelObj = channels[normalized]!;
    // Buscar mensaje pendiente que coincida (mismo canal, mismo mensaje, mismo timestamp aproximado)
    // Comparar mensajes normalizados (sin espacios extra, case-insensitive para el contenido)
    final normalizedReceivedMessage = message.trim();
    // print('🔍 [IRCService] Buscando mensaje pendiente para confirmar: "$normalizedReceivedMessage" en canal $normalized');
    // print('🔍 [IRCService] Total mensajes en canal: ${channelObj.messages.length}');
    
    // Buscar desde el final (más reciente) hacia el principio para encontrar el mensaje más reciente primero
    for (var i = channelObj.messages.length - 1; i >= 0; i--) {
      final msg = channelObj.messages[i];
      if (msg.isPending && msg.channel == normalized) {
        // Comparar mensajes normalizados (trim y comparar)
        final normalizedPendingMessage = msg.message.trim();
        // print('🔍 [IRCService] Comparando pendiente[$i]: "$normalizedPendingMessage" con recibido: "$normalizedReceivedMessage"');
        // También verificar si el mensaje recibido contiene el mensaje pendiente o viceversa
        // (por si hay diferencias menores en el formato)
        if (normalizedPendingMessage == normalizedReceivedMessage ||
            normalizedReceivedMessage.contains(normalizedPendingMessage) ||
            normalizedPendingMessage.contains(normalizedReceivedMessage)) {
          // Confirmar el mensaje (marcar como no pendiente, preservando todos los campos)
          final confirmedMsg = msg.copyWith(
            isPending: false, 
            pendingId: null,
            // Preservar replyToMessageId y otros campos
          );
          channelObj.messages[i] = confirmedMsg;
          // print('✅ [IRCService] Mensaje confirmado en índice $i: ${msg.pendingId}');
          // Notificar a los listeners de mensajes para actualizar la UI
          _notifyMessageListeners(confirmedMsg);
          // También notificar a los listeners de lista de usuarios para forzar actualización del provider
          _notifyUserListListeners(normalized);
          return true;
        }
      }
    }
    // print('⚠️  [IRCService] No se encontró mensaje pendiente para confirmar: "$normalizedReceivedMessage" en canal $normalized');
    // Listar todos los mensajes pendientes para debug
    final pendingMessages = channelObj.messages.where((m) => m.isPending).toList();
    // print('🔍 [IRCService] Mensajes pendientes en canal: ${pendingMessages.length}');
    for (var pending in pendingMessages) {
      // print('🔍 [IRCService]   - Pending: "${pending.message}" (ID: ${pending.pendingId})');
    }
    return false;
  }

  // Enviar mensaje privado a un servicio IRC (NickServ, ChanServ, HostServ, etc.)
  void sendServiceMessage(String service, String message) {
    // Los servicios IRC no usan #, solo el nombre del servicio
    final serviceName = service.trim();
    _sendCommand('PRIVMSG $serviceName :$message');
    // print('📤 [IRCService] Enviando mensaje a servicio $serviceName: $message');
  }

  // Identificar el nick con el bot "nick" usando IDENTIFY
  void identifyNick(String password) {
    if (_nickname == null || _nickname!.isEmpty) {
      // print('⚠️ [IRCService] No hay nick para identificar');
      return;
    }
    
    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      // print('⚠️ [IRCService] La contraseña está vacía');
      return;
    }
    
    // Enviar IDENTIFY al bot "nick" (no "NickServ") con la contraseña
    // Formato: PRIVMSG nick :IDENTIFY nick password
    // Algunos bots requieren el nick en el comando
    final command = 'PRIVMSG nick :IDENTIFY ${_nickname} $trimmedPassword';
    // print('🔐 [IRCService] Identificando nick ${_nickname} con bot "nick"');
    // print('🔐 [IRCService] Comando completo: $command');
    _sendCommand(command);
  }

        // Verificar el status de un nick (STATUS nick)
        // Retorna un Completer que se completa con el status (3 = registrado)
        Completer<int?> checkNickStatus(String nick) {
        final completer = Completer<int?>();
        final normalizedNick = nick.trim().toLowerCase();
        
        // Guardar el completer para que el parser de NOTICE lo pueda completar
        _statusCheckCompleters[normalizedNick] = completer;
        
        // Enviar comando STATUS al bot "nick" (no "NickServ")
        // Formato: PRIVMSG nick :STATUS nick
        _sendCommand('PRIVMSG nick :STATUS $nick');
        // print('📋 [IRCService] Verificando status del nick: $nick');
        // print('📋 [IRCService] Comando enviado: PRIVMSG nick :STATUS $nick');
    
    // Timeout después de 10 segundos (aumentado para dar más tiempo al servidor)
    Timer(const Duration(seconds: 10), () {
      // Verificar si el completer todavía existe y no está completado
      final existingCompleter = _statusCheckCompleters[normalizedNick];
      if (existingCompleter != null && existingCompleter == completer && !completer.isCompleted) {
        // print('⏱️  [IRCService] Timeout verificando status del nick: $nick');
        _statusCheckCompleters.remove(normalizedNick);
        completer.complete(null);
      } else if (completer.isCompleted) {
        // print('✅ [IRCService] Status ya recibido para nick: $nick (timeout ignorado)');
      }
    });
    
    return completer;
  }

  // Enviar mensaje privado a un nick (query)
  void sendWhois(String nick) {
    _sendCommand('WHOIS $nick');
  }

  // Comandos de información
  void sendWho(String channel) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('WHO $normalized');
    // print('👤 [IRCService] Solicitando información de usuarios en $normalized');
  }

  void sendList([String? pattern]) {
    if (pattern != null && pattern.isNotEmpty) {
      _sendCommand('LIST $pattern');
    } else {
      _sendCommand('LIST');
    }
    // print('📋 [IRCService] Solicitando lista de canales${pattern != null ? " (patrón: $pattern)" : ""}');
  }

  void sendNames(String channel) {
    final normalized = _normalizeChannelName(channel);
        _sendCommand('NAMES $normalized');
        print('👥 [IRCService] Solicitando lista de usuarios de $normalized');
  }

  // Comandos de gestión
  void sendAway([String? message]) {
    if (message != null && message.isNotEmpty) {
      _sendCommand('AWAY :$message');
      // print('🚶 [IRCService] Estableciendo mensaje de ausencia: $message');
    } else {
      _sendCommand('AWAY');
      // print('🚶 [IRCService] Estableciendo mensaje de ausencia (sin mensaje)');
    }
  }

  void sendBack() {
    _sendCommand('AWAY');
    // print('✅ [IRCService] Volviendo de ausencia');
  }

  void sendMe(String channel, String action) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('PRIVMSG $normalized :\x01ACTION $action\x01');
    // print('🎭 [IRCService] Enviando acción /me en $normalized: $action');
  }

  void sendNotice(String target, String message) {
    _sendCommand('NOTICE $target :$message');
    // print('📢 [IRCService] Enviando NOTICE a $target: $message');
  }

  // Comandos de moderación
  void kickUser(String channel, String nick, [String? reason]) {
    final normalized = _normalizeChannelName(channel);
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('KICK $normalized $nick :$reason');
    } else {
      _sendCommand('KICK $normalized $nick');
    }
    // print('👢 [IRCService] Expulsando $nick de $normalized${reason != null ? " (razón: $reason)" : ""}');
    
    // Actualizar la lista de usuarios inmediatamente (optimización)
    // El servidor enviará el evento KICK que también actualizará la lista
    if (channels.containsKey(normalized)) {
      channels[normalized]!.removeUser(nick);
      _notifyUserListListeners(normalized);
    }
  }

  void banUser(String channel, String nick, [String? reason]) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('MODE $normalized +b $nick');
    // print('🚫 [IRCService] Baneando $nick en $normalized');
  }

  void unbanUser(String channel, String nick) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('MODE $normalized -b $nick');
    // print('✅ [IRCService] Desbaneando $nick en $normalized');
  }

  void setChannelMode(String channel, String modes, [String? target]) {
    final normalized = _normalizeChannelName(channel);
    if (target != null && target.isNotEmpty) {
      _sendCommand('MODE $normalized $modes $target');
    } else {
      _sendCommand('MODE $normalized $modes');
    }
    // print('⚙️  [IRCService] Cambiando modo de $normalized: $modes${target != null ? " $target" : ""}');
  }

  void setChannelTopic(String channel, String topic) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('TOPIC $normalized :$topic');
    // print('📌 [IRCService] Cambiando topic de $normalized: $topic');
  }

  // ========== COMANDOS DE IRCOP (UnrealIRCd) ==========
  
  // OPER: Autenticarse como operador IRC
  void oper(String nick, String password) {
    _sendCommand('OPER $nick $password');
    // print('🔐 [IRCService] Intentando autenticarse como operador: $nick');
  }
  
  // KILL: Desconectar a un usuario del servidor
  void killUser(String nick, [String? reason]) {
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('KILL $nick :$reason');
    } else {
      _sendCommand('KILL $nick');
    }
    // print('💀 [IRCService] KILL: Desconectando $nick${reason != null ? " (razón: $reason)" : ""}');
  }

  // GLINE: Prohibir a un usuario o rango de IPs conectarse al servidor
  void glineUser(String userhost, [String? duration, String? reason]) {
    String command = 'GLINE $userhost';
    if (duration != null && duration.isNotEmpty) {
      command += ' $duration';
    }
    if (reason != null && reason.isNotEmpty) {
      command += ' :$reason';
    }
    _sendCommand(command);
    // print('🚫 [IRCService] GLINE: $userhost${duration != null ? " por $duration" : ""}${reason != null ? " (razón: $reason)" : ""}');
  }

  // KLINE: Similar a GLINE pero solo para el servidor local
  void klineUser(String userhost, [String? duration, String? reason]) {
    String command = 'KLINE $userhost';
    if (duration != null && duration.isNotEmpty) {
      command += ' $duration';
    }
    if (reason != null && reason.isNotEmpty) {
      command += ' :$reason';
    }
    _sendCommand(command);
    // print('🚫 [IRCService] KLINE: $userhost${duration != null ? " por $duration" : ""}${reason != null ? " (razón: $reason)" : ""}');
  }

  // ZLINE: Banear una IP específica
  void zlineIP(String ip, [String? duration, String? reason]) {
    String command = 'ZLINE $ip';
    if (duration != null && duration.isNotEmpty) {
      command += ' $duration';
    }
    if (reason != null && reason.isNotEmpty) {
      command += ' :$reason';
    }
    _sendCommand(command);
    // print('🚫 [IRCService] ZLINE: $ip${duration != null ? " por $duration" : ""}${reason != null ? " (razón: $reason)" : ""}');
  }

  // SHUN: Silenciar a un usuario
  void shunUser(String userhost, [String? duration, String? reason]) {
    String command = 'SHUN $userhost';
    if (duration != null && duration.isNotEmpty) {
      command += ' $duration';
    }
    if (reason != null && reason.isNotEmpty) {
      command += ' :$reason';
    }
    _sendCommand(command);
    // print('🔇 [IRCService] SHUN: $userhost${duration != null ? " por $duration" : ""}${reason != null ? " (razón: $reason)" : ""}');
  }

  // SAJOIN: Forzar a un usuario a unirse a un canal
  void sajoinUser(String nick, String channel) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('SAJOIN $nick $normalized');
    // print('➡️ [IRCService] SAJOIN: Forzando a $nick a unirse a $normalized');
  }

  // SAPART: Forzar a un usuario a salir de un canal
  void sapartUser(String nick, String channel) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('SAPART $nick $normalized');
    // print('⬅️ [IRCService] SAPART: Forzando a $nick a salir de $normalized');
  }

  // SAMODE: Cambiar los modos de un canal sin ser operador
  void samodeChannel(String channel, String modes, [String? target]) {
    final normalized = _normalizeChannelName(channel);
    if (target != null && target.isNotEmpty) {
      _sendCommand('SAMODE $normalized $modes $target');
    } else {
      _sendCommand('SAMODE $normalized $modes');
    }
    // print('⚙️ [IRCService] SAMODE: Cambiando modo de $normalized: $modes${target != null ? " $target" : ""}');
  }

  // SANICK: Cambiar el nick de un usuario
  void sanickUser(String nick, String newNick) {
    _sendCommand('SANICK $nick $newNick');
    // print('👤 [IRCService] SANICK: Cambiando nick de $nick a $newNick');
  }

  // SAPRIVMSG: Enviar mensaje privado como servicio
  void saprivmsgUser(String nick, String message) {
    _sendCommand('SAPRIVMSG $nick :$message');
    // print('📨 [IRCService] SAPRIVMSG: Enviando mensaje a $nick: $message');
  }

  // SQUIT: Desconectar un servidor de la red
  void squitServer(String server, [String? reason]) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'SQUIT';
    _currentIRCOpEndCode = null;
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'SQUIT') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de SQUIT (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('SQUIT $server :$reason');
    } else {
      _sendCommand('SQUIT $server');
    }
    // print('🔌 [IRCService] SQUIT: Desconectando servidor $server${reason != null ? " (razón: $reason)" : ""}');
  }

  // REHASH: Recargar la configuración del servidor
  void rehashServer() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'REHASH';
    _currentIRCOpEndCode = null; // REHASH devuelve NOTICE, no códigos numéricos
    // Cancelar timer anterior si existe
    _ircopCommandTimer?.cancel();
    // Timer para finalizar la captura después de 3 segundos
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'REHASH') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de REHASH (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('REHASH');
    // print('🔄 [IRCService] REHASH: Recargando configuración del servidor');
  }

  // RESTART: Reiniciar el servidor
  void restartServer([String? reason]) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'RESTART';
    _currentIRCOpEndCode = null;
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'RESTART') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de RESTART (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('RESTART :$reason');
    } else {
      _sendCommand('RESTART');
    }
    // print('🔄 [IRCService] RESTART: Reiniciando servidor${reason != null ? " (razón: $reason)" : ""}');
  }

  // DIE: Apagar el servidor
  void dieServer([String? reason]) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'DIE';
    _currentIRCOpEndCode = null;
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'DIE') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de DIE (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('DIE :$reason');
    } else {
      _sendCommand('DIE');
    }
    // print('💀 [IRCService] DIE: Apagando servidor${reason != null ? " (razón: $reason)" : ""}');
  }

  // CONNECT: Conectar un servidor a la red
  void connectServer(String server, int port, [String? password]) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'CONNECT';
    _currentIRCOpEndCode = null;
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 5), () {
      if (_currentIRCOpCommand == 'CONNECT') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de CONNECT (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    String command = 'CONNECT $server $port';
    if (password != null && password.isNotEmpty) {
      command += ' $password';
    }
    _sendCommand(command);
    // print('🔗 [IRCService] CONNECT: Conectando servidor $server:$port');
  }

  // DCCDENY: Denegar DCC de un usuario
  void dccdenyUser(String nick) {
    _sendCommand('DCCDENY $nick');
    // print('🚫 [IRCService] DCCDENY: Denegando DCC de $nick');
  }

  // UNDCCDENY: Permitir DCC de un usuario
  void undccdenyUser(String nick) {
    _sendCommand('UNDCCDENY $nick');
    // print('✅ [IRCService] UNDCCDENY: Permitiendo DCC de $nick');
  }

  // TSCTL: Comandos de control de timestamp
  void tsctlCommand(String command) {
    _sendCommand('TSCTL $command');
    // print('⏰ [IRCService] TSCTL: $command');
  }

  // MKPASSWD: Generar hash de contraseña
  void mkpasswd(String password) {
    _sendCommand('MKPASSWD $password');
    // print('🔐 [IRCService] MKPASSWD: Generando hash de contraseña');
  }

  // STATS: Obtener estadísticas del servidor
  void statsCommand(String type) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'STATS';
    _currentIRCOpEndCode = '219';
    _sendCommand('STATS $type');
    // print('📊 [IRCService] STATS: Solicitando estadísticas tipo $type');
  }

  // TRACE: Rastrear la ruta de un usuario o servidor
  void traceTarget(String target) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'TRACE';
    _currentIRCOpEndCode = '262';
    _sendCommand('TRACE $target');
    // print('🔍 [IRCService] TRACE: Rastreando $target');
  }

  // LINKS: Listar servidores conectados
  void linksCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'LINKS';
    _currentIRCOpEndCode = '365';
    _sendCommand('LINKS');
    // print('🔗 [IRCService] LINKS: Solicitando lista de servidores');
  }

  // MAP: Mapa de la red
  void mapCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'MAP';
    _currentIRCOpEndCode = '007';
    _sendCommand('MAP');
    // print('🗺️ [IRCService] MAP: Solicitando mapa de la red');
  }

  // MOTD: Mensaje del día
  void motdCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'MOTD';
    _currentIRCOpEndCode = '376';
    _sendCommand('MOTD');
    // print('📝 [IRCService] MOTD: Solicitando mensaje del día');
  }

  // VERSION: Versión del servidor
  void versionCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'VERSION';
    _currentIRCOpEndCode = null;
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'VERSION') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de VERSION (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('VERSION');
    // print('ℹ️ [IRCService] VERSION: Solicitando versión del servidor');
  }

  // ADMIN: Información de administración
  void adminCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'ADMIN';
    _currentIRCOpEndCode = null;
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'ADMIN') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de ADMIN (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('ADMIN');
    // print('👨‍💼 [IRCService] ADMIN: Solicitando información de administración');
  }

  // LUSERS: Estadísticas de usuarios
  void lusersCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'LUSERS';
    _currentIRCOpEndCode = null;
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'LUSERS') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de LUSERS (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('LUSERS');
    // print('👥 [IRCService] LUSERS: Solicitando estadísticas de usuarios');
  }

  // TIME: Hora del servidor
  void timeCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'TIME';
    _currentIRCOpEndCode = null;
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'TIME') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // print('📋 [IRCOp] Fin de TIME (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _currentIRCOpEndCode = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('TIME');
    // print('🕐 [IRCService] TIME: Solicitando hora del servidor');
  }

  // WALLOPS: Mensaje a todos los operadores
  void wallops(String message) {
    _sendCommand('WALLOPS :$message');
    // print('📢 [IRCService] WALLOPS: $message');
  }

  // GLOBOPS: Mensaje global a todos los operadores
  void globops(String message) {
    _sendCommand('GLOBOPS :$message');
    // print('🌍 [IRCService] GLOBOPS: $message');
  }

  // ADMIND: Mensaje a administradores
  void admind(String message) {
    _sendCommand('ADMIND :$message');
    // print('👨‍💼 [IRCService] ADMIND: $message');
  }

  // LOCOPS: Mensaje a operadores locales
  void locops(String message) {
    _sendCommand('LOCOPS :$message');
    // print('🏠 [IRCService] LOCOPS: $message');
  }

  void sendIgnore(String nick) {
    final normalizedNick = nick.trim().toLowerCase();
    if (normalizedNick.isEmpty) return;
    
    // Añadir a la lista local de ignorados
    _ignoredUsers.add(normalizedNick);
    // print('🚫 [IRCService] Usuario añadido a lista de ignorados: $normalizedNick');
    
    _sendCommand('MODE $nick +b'); // Ignorar usando modo ban (depende del servidor IRC)
    // Alternativa: algunos servidores usan /ignore directamente
    _sendCommand('IGNORE $nick');
  }

  void sendUnignore(String nick) {
    final normalizedNick = nick.trim().toLowerCase();
    if (normalizedNick.isEmpty) return;
    
    // Remover de la lista local de ignorados
    _ignoredUsers.remove(normalizedNick);
    // print('✅ [IRCService] Usuario removido de lista de ignorados: $normalizedNick');
    
    _sendCommand('MODE $nick -b'); // Designorar usando modo ban
    // Alternativa: algunos servidores usan /unignore directamente
    _sendCommand('UNIGNORE $nick');
  }
  
  bool isUserIgnored(String nick) {
    return _ignoredUsers.contains(nick.toLowerCase());
  }

  // Enviar comando a ChanServ (Anope)
  void sendChanServCommand(String channel, String command, [String? params]) {
    final normalized = _normalizeChannelName(channel);
    String fullCommand = command;
    if (params != null && params.isNotEmpty) {
      fullCommand = '$command $normalized $params';
    } else {
      fullCommand = '$command $normalized';
    }
    sendPrivateMessage('ChanServ', fullCommand);
    // print('🔧 [IRCService] Comando ChanServ enviado: $fullCommand');
  }

  void sendPrivateMessage(String nick, String message, {int delaySeconds = 0}) {
    final normalizedNick = nick.trim();
    if (normalizedNick.isEmpty) return;
    
    // Crear un canal privado si no existe (los queries usan el nick como "canal")
    final queryChannel = normalizedNick.toLowerCase();
    if (!channels.containsKey(queryChannel)) {
      channels[queryChannel] = IRCChannel(name: queryChannel);
      // print('📤 [IRCService] Creado canal privado para: $queryChannel');
    }
    
    // Generar un ID único para este mensaje pendiente
    final pendingId = '${DateTime.now().millisecondsSinceEpoch}_${message.hashCode}';
    
    // Agregar el mensaje al canal privado local como PENDIENTE
    final msg = IRCMessage(
      nick: _nickname ?? 'You',
      channel: queryChannel,
        message: message,
        timestamp: DateTime.now(),
      isPending: true,
      pendingId: pendingId,
      delaySeconds: delaySeconds > 0 ? delaySeconds : null,
      messageId: IRCMessage.generateMessageId(),
      );
    channels[queryChannel]!.addMessage(msg);
      _notifyMessageListeners(msg);
    
    // print('📤 [IRCService] Mensaje privado marcado como PENDIENTE: $pendingId (delay: ${delaySeconds}s)');
    
    // Programar el envío después del delay
    if (delaySeconds > 0) {
      // print('⏱️  [IRCService] Programando envío de mensaje privado $pendingId en ${delaySeconds}s');
      final timer = Timer(Duration(seconds: delaySeconds), () {
        // print('⏱️  [IRCService] Timer ejecutado, enviando mensaje privado $pendingId');
        // Enviar el mensaje
        final lines = message.split('\n');
        for (var line in lines) {
          line = line.trim();
          if (line.isNotEmpty) {
            // print('📤 [IRCService] Enviando línea privada: $line');
            _sendCommand('PRIVMSG $normalizedNick :$line');
          }
        }
        // print('📤 [IRCService] Mensaje privado enviado al servidor después de delay: $pendingId');
        // Eliminar el timer del mapa después de ejecutarse
        _pendingMessageTimers.remove(pendingId);
        
        // Auto-confirmar después de 500ms si el servidor no hace eco
        Timer(const Duration(milliseconds: 500), () {
          final channelObj = channels[queryChannel];
          if (channelObj != null) {
            final currentPendingMessages = channelObj.messages.where((m) => m.isPending && m.pendingId == pendingId).toList();
            if (currentPendingMessages.isNotEmpty) {
              // print('⚠️  [IRCService] Mensaje privado con delay $pendingId aún pendiente después de 500ms, auto-confirmando.');
              confirmPendingMessage(queryChannel, message, DateTime.now());
            }
          }
        });
      });
      _pendingMessageTimers[pendingId] = timer;
    } else {
      // Sin delay, enviar inmediatamente
      // print('📤 [IRCService] Enviando mensaje privado sin delay inmediatamente: $pendingId');
      final lines = message.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isNotEmpty) {
          // print('📤 [IRCService] Enviando línea privada sin delay: $line');
          _sendCommand('PRIVMSG $normalizedNick :$line');
        }
      }
      // print('✅ [IRCService] Mensaje privado sin delay enviado, esperando confirmación del servidor (pendingId: $pendingId)');
      
      // Auto-confirmar después de 500ms si el servidor no hace eco
      Timer(const Duration(milliseconds: 500), () {
        final channelObj = channels[queryChannel];
        if (channelObj != null) {
          final currentPendingMessages = channelObj.messages.where((m) => m.isPending && m.pendingId == pendingId).toList();
          if (currentPendingMessages.isNotEmpty) {
            // print('⚠️  [IRCService] Mensaje privado $pendingId aún pendiente después de 500ms, auto-confirmando.');
            confirmPendingMessage(queryChannel, message, DateTime.now());
          }
        }
      });
    }
  }

  // Cambiar el nickname
  void changeNick(String newNick) {
    final trimmedNick = newNick.trim();
    if (trimmedNick.isEmpty) {
      // print('⚠️  [IRCService] No se puede cambiar a un nick vacío');
      return;
    }
    
    if (trimmedNick == _nickname) {
      // print('ℹ️  [IRCService] Ya estás usando ese nick');
      return;
    }
    
    // print('🔄 [IRCService] Cambiando nick de "$_nickname" a "$trimmedNick"');
    _sendCommand('NICK $trimmedNick');
    // El servidor confirmará el cambio con un mensaje NICK, entonces actualizaremos _nickname
    // cuando recibamos la confirmación del servidor
  }

  void _sendCommand(String command) {
    if (_connection != null && _connection!.isConnected) {
      // print('🔍 [DEBUG] Sending command: $command');
      // Agregar \r\n para compatibilidad IRC
      final ircCommand = command.endsWith('\r\n') ? command : '$command\r\n';
      _connection!.send(ircCommand);
    } else {
      // print('🔍 [DEBUG] ⚠️  Cannot send command "$command": connection is null or not connected');
    }
  }

  // Método para agregar listeners de debug
  void addDebugLogListener(Function(String) listener) {
    _debugLogListeners.add(listener);
  }

  void removeDebugLogListener(Function(String) listener) {
    _debugLogListeners.remove(listener);
  }

  void _notifyDebugLog(String message) {
    for (var listener in _debugLogListeners) {
      try {
        listener(message);
      } catch (e) {
        // Ignorar errores en listeners
      }
    }
  }

  void _handleData(String rawData) {
    // Notificar a los listeners de debug
    _notifyDebugLog(rawData);
    
    final lines = rawData.split('\r\n');
    
    for (var line in lines) {
      if (line.isEmpty) continue;
      // print('IRC >> $line');
      
      // Log especial para comandos JOIN, 353, 366, 332 (TOPIC), NICK
      if (line.contains(' JOIN ') || line.contains(' 353 ') || line.contains(' 366 ') || line.contains(' 332 ') || line.contains(' NICK ')) {
        // print('🔍 [DEBUG] ⭐ Important IRC message: $line');
      }
      
      // Log específico para TOPIC
      if (line.contains(' 332 ')) {
        // print('🔍 [DEBUG] 📌📌📌 RAW TOPIC MESSAGE RECEIVED: $line');
        // print('🔍 [DEBUG] 📌📌📌 Full raw line length: ${line.length}');
        // print('🔍 [DEBUG] 📌📌📌 Line bytes: ${line.codeUnits}');
      }
      
      // Log específico para NICK
      if (line.contains(' NICK ')) {
        // print('🔄 [DEBUG] 🔄🔴 RAW NICK MESSAGE RECEIVED: $line');
      }
      
      _parseIRCMessage(line);
    }
  }

  void _parseIRCMessage(String line) {
    // Manejar PING del servidor
    if (line.startsWith('PING')) {
      final pingToken = line.substring(5).trim();
      _sendCommand('PONG $pingToken');
      
      // Si el servidor nos envía PING, también podemos medir el lag
      // pero es mejor usar nuestro propio PING periódico
      return;
    }
    
    // Detectar PONG del servidor (respuesta a nuestro PING)
    // Formato: PONG :token o :server PONG :token
    if (line.contains(' PONG ') || line.startsWith('PONG')) {
      String? pongToken;
      // Intentar extraer el token del PONG
      if (line.startsWith('PONG')) {
        // Formato: PONG :token
        final parts = line.split(' ');
        if (parts.length > 1) {
          pongToken = parts[1].replaceFirst(':', '').trim();
        }
      } else {
        // Formato: :server PONG :token
        final pongMatch = RegExp(r'PONG\s+:?(.+)').firstMatch(line);
        if (pongMatch != null) {
          pongToken = pongMatch.group(1)?.trim();
        }
      }
      
      // Si es respuesta a nuestro PING, calcular el lag
      if (pongToken != null && _lastPingSent != null && _lastPingToken != null && pongToken == _lastPingToken) {
        final lagMs = DateTime.now().difference(_lastPingSent!).inMilliseconds;
        _notifyLagListeners(lagMs);
        _lastPingSent = null;
        _lastPingToken = null;
        // print('📊 [IRCService] Lag medido: ${lagMs}ms');
      }
      return;
    }

    // Parse `:nick!user@host COMMAND args`
    if (!line.startsWith(':')) return;

    try {
      final parts = line.split(' ');
      if (parts.length < 2) return;

      final source = parts[0].substring(1); // Remove ':'
      final command = parts[1];
      final args = parts.sublist(2);

      final nick = source.split('!')[0];
      // Extraer el host del source (formato: nick!user@host)
      String? host;
      if (source.contains('@')) {
        host = source.split('@').length > 1 ? source.split('@')[1] : null;
      }
      
      // Log todos los comandos numéricos (353, 366, etc.) para debug
      if (RegExp(r'^\d{3}$').hasMatch(command)) {
        // print('🔍 [DEBUG] Received numeric command: $command (line: $line)');
        // Log específico para comandos whois
        if (['311', '312', '313', '317', '318', '319', '301'].contains(command)) {
          // print('🔍 [WHOIS DEBUG] Command: $command, Args: $args');
        }
      }
      
      // Log si el mensaje contiene nuestro nickname
      if (_nickname != null && line.contains(_nickname!)) {
        // print('🔍 [DEBUG] ⭐ Message contains our nickname "$_nickname": $line');
      }

      switch (command) {
        case '001': // Welcome
          print('✅ Welcome message received - connected as $nick to $_currentHost');
          // print('🔍 [DEBUG] ✅✅✅ User is now fully registered! Ready for JOIN commands ✅✅✅');
          _isRegistered = true; // Marcar que el usuario está registrado
          // Actualizar el nickname con el confirmado por el servidor (puede tener guion si fue rechazado)
          if (nick != null && nick.isNotEmpty && nick != _nickname) {
            _nickname = nick;
            // Notificar a los listeners del cambio de nick
            for (var listener in _nickChangeListeners) {
              try {
                listener(nick);
              } catch (e) {
                // Ignorar errores en listeners
              }
            }
          }
          if (!_connectionCompleter.isCompleted) {
            _connectionCompleter.complete();
          }
          break;
        
        case '332': // TOPIC
          // print('🔍 [DEBUG] 📌📌📌 TOPIC command received! Raw line: $line');
          // print('🔍 [DEBUG] 📌📌📌 Full line breakdown:');
          // print('🔍 [DEBUG] 📌📌📌   - Line length: ${line.length}');
          // print('🔍 [DEBUG] 📌📌📌   - Parts count: ${parts.length}');
          // print('🔍 [DEBUG] 📌📌📌   - Args count: ${args.length}');
          // print('🔍 [DEBUG] 📌📌📌   - Args: $args');
          // print('🔍 [DEBUG] 📌📌📌   - Source: $source');
          // print('🔍 [DEBUG] 📌📌📌   - Command: $command');
          
          // El formato típico es: :server 332 nick #channel :topic text
          // Pero también puede ser: :server 332 #channel :topic text (sin nick)
          String? channel;
          String? topicText;
          
          // Intentar extraer el canal y el topic
          if (args.length >= 1) {
            // El canal puede estar en args[0] o args[1] dependiendo del formato
            var potentialChannel = args.length >= 2 ? args[1] : args[0];
            
            // Si el primer arg no parece un canal, intentar el segundo
            if (!potentialChannel.startsWith('#') && args.length >= 2) {
              potentialChannel = args[0];
            }
            
            // print('🔍 [DEBUG] 📌📌📌 Potential channel from args: "$potentialChannel"');
            // Guardar el canal original antes de normalizar para buscarlo en la línea
            final originalChannelInLine = potentialChannel;
            channel = _normalizeChannelName(potentialChannel);
            // print('🔍 [DEBUG] 📌📌📌 Normalized channel: "$channel"');
            
            // Extraer el topic: el formato es :server 332 nick #channel :topic
            // Necesitamos encontrar el ':' que viene después del nombre del canal
            // Buscar el canal ORIGINAL (sin normalizar) en la línea y luego el ':' que viene después
            final channelIndex = line.indexOf(originalChannelInLine);
            if (channelIndex != -1) {
              // Buscar el ':' que viene después del nombre del canal
              final colonIndex = line.indexOf(':', channelIndex + originalChannelInLine.length);
              // print('🔍 [DEBUG] 📌📌📌 Channel index: $channelIndex, Colon index after channel: $colonIndex');
              
              if (colonIndex != -1 && colonIndex < line.length - 1) {
                final rawTopic = line.substring(colonIndex + 1).trim();
                // Limpiar códigos de formato IRC (colores, subrayado, etc.) para que se vean bien en el topic
                topicText = IRCColorParser.stripIRCFormatting(rawTopic);
                // print('🔍 [DEBUG] 📌📌📌 Topic text extracted (raw): "$rawTopic"');
                // print('🔍 [DEBUG] 📌📌📌 Topic text cleaned: "$topicText"');
                // print('🔍 [DEBUG] 📌📌📌 Topic text length: ${topicText.length}');
              } else {
                // print('🔍 [DEBUG] 📌📌📌 ⚠️  No colon found after channel name');
              }
            } else {
              // print('🔍 [DEBUG] 📌📌📌 ⚠️  Channel not found in line (searched for: "$originalChannelInLine")');
            }
          }
          
          if (channel != null && channel.startsWith('#')) {
            // Usar una variable local no-nullable para evitar problemas de tipos
            String finalChannel = channel;
            
            // Buscar el canal en el mapa (case-insensitive)
            String? actualChannelKey = finalChannel;
            if (!channels.containsKey(finalChannel)) {
              // print('🔍 [DEBUG] 📌📌📌 Channel "$finalChannel" not found, searching case-insensitive...');
              // print('🔍 [DEBUG] 📌📌📌 Available channels: ${channels.keys.toList()}');
              // Buscar case-insensitive
              for (var existingKey in channels.keys) {
                if (existingKey.toLowerCase() == finalChannel.toLowerCase()) {
                  actualChannelKey = existingKey;
                  finalChannel = existingKey;
                  // print('🔍 [DEBUG] 📌📌📌 Found channel case-insensitive: "$finalChannel"');
                  break;
                }
              }
            }
            
            // Si el canal existe, actualizar el topic
            if (channels.containsKey(finalChannel)) {
              if (topicText != null) {
                channels[finalChannel]!.setTopic(topicText);
                // print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic set for existing channel: $finalChannel');
                // print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic value: "${channels[finalChannel]!.topic}"');
              } else {
                // Si no hay topic, establecer como vacío
                channels[finalChannel]!.setTopic('');
                // print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic cleared for channel: $finalChannel');
              }
              // Notificar cambio de topic
              _notifyTopicListeners(finalChannel);
              // print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic listeners notified');
            } else {
              // Crear el canal si no existe
              channels[finalChannel] = IRCChannel(name: finalChannel, topic: topicText ?? '');
              // print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic set for new channel: $finalChannel');
              // print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic value: "${channels[finalChannel]!.topic}"');
              _notifyTopicListeners(finalChannel);
            }
          } else {
            // print('🔍 [DEBUG] 📌📌📌 ⚠️  ⚠️  ⚠️  Invalid channel in TOPIC command: $channel');
            // print('🔍 [DEBUG] 📌📌📌 ⚠️  ⚠️  ⚠️  Full line for inspection: $line');
          }
          break;
        
        case '433': // Nickname in use - try alternative
          if (_nickname != null && !_nickname!.endsWith('_')) {
            final newNick = '${_nickname}_';
            _nickname = newNick;
            _sendCommand('NICK $newNick');
            // Notificar a los listeners del cambio de nick
            for (var listener in _nickChangeListeners) {
              try {
                listener(newNick);
              } catch (e) {
                // Ignorar errores en listeners
              }
            }
          }
          break;
        
        case '353': // Names reply (users in channel)
          print('🔍 [DEBUG] 📋 Received user list (353) from server');
          print('🔍 [DEBUG] Raw line: $line');
          print('🔍 [DEBUG] 📋 Args count: ${args.length}, Args: $args');
          
          // Método más simple y robusto: buscar cualquier palabra que empiece con # en la línea
          String? channel;
          
          // Primero intentar con regex para encontrar cualquier #canal en la línea
          final channelMatch = RegExp(r'(#\S+)').firstMatch(line);
          if (channelMatch != null) {
            channel = channelMatch.group(1);
            print('🔍 [DEBUG] 📋 Found channel with regex: "$channel"');
          }
          
          // Si no se encontró, intentar con args
          if (channel == null || !channel.startsWith('#')) {
            // Buscar en todos los args el que empiece con #
            for (var arg in args) {
              if (arg.startsWith('#')) {
                channel = arg;
                print('🔍 [DEBUG] 📋 Found channel in args: "$channel"');
                break;
              }
            }
          }
          
          // Si todavía no se encontró, intentar métodos alternativos
          if (channel == null || !channel.startsWith('#')) {
            if (args.length >= 3) {
              // Formato típico: 353 nick = #channel :users
              // args[1] podría ser '=' y args[2] el canal
              if (args[1] == '=' || args[1] == '@' || args[1] == '&' || args[1] == '*') {
                channel = args[2];
              } else if (args[1].startsWith('#')) {
                channel = args[1];
              } else if (args[2].startsWith('#')) {
                channel = args[2];
              }
              print('🔍 [DEBUG] 📋 Channel from args (method 2): "$channel"');
            } else if (args.length >= 2) {
              channel = args[1];
              print('🔍 [DEBUG] 📋 Channel from args[1]: "$channel"');
            }
          }
          
          if (channel == null || channel.isEmpty || !channel.startsWith('#')) {
            print('🔍 [DEBUG] ⚠️  ⚠️  ⚠️  Could not extract channel from 353 command');
            print('🔍 [DEBUG] Full line was: $line');
            print('🔍 [DEBUG] Args were: $args');
            break;
          }
          
          // Normalizar el nombre del canal
          String originalChannel = channel;
          channel = _normalizeChannelName(channel);
          
          print('🔍 [DEBUG] 📋 Normalized channel: "$channel" (from "$originalChannel")');
          print('🔍 [DEBUG] 📋 Available channels in map: ${channels.keys.toList()}');
          
          // En este punto, channel no puede ser null (ya validado arriba)
          final validChannel = channel;
          
          // Validación CRÍTICA: el canal NO debe ser igual al nickname (con o sin #)
          // Esto evita crear canales como #flutteruser cuando el nickname es FlutterUser
          if (_nickname != null) {
            final normalizedNick = _nickname!.toLowerCase();
            final channelWithoutHash = validChannel.toLowerCase().replaceFirst('#', '');
            
            // Verificar si el canal es igual al nickname (con o sin #)
            if (channelWithoutHash == normalizedNick || 
                validChannel.toLowerCase() == '#$normalizedNick' ||
                originalChannel.toLowerCase() == normalizedNick) {
              print('🔍 [DEBUG] ⚠️  ⚠️  ⚠️  BLOCKING 353: channel "$validChannel" matches nickname "$_nickname" - SKIPPING');
              break;
            }
          }
          
          // Si el canal no existe con el nombre exacto, buscar por nombre normalizado (case-insensitive)
          // Esto es importante porque el servidor puede devolver el nombre con diferente capitalización
          String finalChannel = validChannel;
          
          // Buscar el canal con el mismo nombre normalizado (case-insensitive)
          if (!channels.containsKey(validChannel)) {
            print('🔍 [DEBUG] ⚠️  Channel "$validChannel" not found with exact name, searching case-insensitive...');
            print('🔍 [DEBUG] Available channels: ${channels.keys.map((k) => '"$k"').join(", ")}');
            
            for (var existingKey in channels.keys) {
              if (existingKey.toLowerCase() == validChannel.toLowerCase()) {
                finalChannel = existingKey;
                print('🔍 [DEBUG] ✅ Found matching channel: "$existingKey" (normalized matches "$validChannel")');
                break;
              }
            }
            
            // Si no se encontró, crear el canal con el nombre normalizado
            if (!channels.containsKey(finalChannel)) {
              print('🔍 [DEBUG] ⚠️  Channel not found, will create new: $finalChannel');
            }
          } else {
            print('🔍 [DEBUG] ✅ Channel found with exact name: $validChannel');
          }
          
          // Find the position of ':' to get the users list
          final colonIndex = line.indexOf(':');
          if (colonIndex != -1) {
              final usersList = line.substring(colonIndex + 1).trim();
              final users = usersList.split(' ').where((u) => u.isNotEmpty).toList();
              
            print('🔍 [DEBUG] Channel: $finalChannel');
            print('🔍 [DEBUG] Raw users string: "$usersList"');
            print('🔍 [DEBUG] Parsed users count: ${users.length}');
            print('🔍 [DEBUG] Parsed users list: $users');
            
            // Create channel if it doesn't exist (usar nombre normalizado)
            if (!channels.containsKey(finalChannel)) {
              // print('🔍 [DEBUG] ℹ️  Channel not in map, creating it: $finalChannel');
              channels[finalChannel] = IRCChannel(name: finalChannel);
            } else {
              // print('🔍 [DEBUG] ✅ Channel already exists: $finalChannel');
              // print('🔍 [DEBUG] Current users in channel before update: ${channels[finalChannel]!.users}');
            }
            
            int addedCount = 0;
            int updatedCount = 0;
            // Agregar usuarios a la lista (addUser ya verifica duplicados)
            for (var user in users) {
                // Extraer el prefijo de modo IRC antes de limpiar
                String? userMode;
                String cleanUser = user.trim();
                
                // Detectar prefijos IRC: @ (op), + (voice), % (halfop), & (founder/owner), ! (admin), h (halfop)
                if (cleanUser.startsWith('@')) {
                  userMode = '@';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith('&')) {
                  userMode = '&';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith('%')) {
                  userMode = '%';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith('!')) {
                  userMode = '!';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith('h')) {
                  userMode = 'h';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith('+')) {
                  userMode = '+';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith(':')) {
                  cleanUser = cleanUser.substring(1).trim();
                }
                
                // print('🔍 [DEBUG] Processing user: "$user" -> mode: "$userMode", cleaned: "$cleanUser"');
                
                // Validar que no sea un servidor/host (excluir nombres con múltiples puntos o que parezcan dominios)
                final isServerHost = cleanUser.contains('.') && 
                    (cleanUser.split('.').length > 2 || // Múltiples puntos (ej: ceres.globalchat.org)
                     RegExp(r'\.(org|com|net|edu|gov|io|co|uk|de|fr|es|it|nl|be|ch|at|se|no|dk|fi|pl|cz|sk|hu|ro|bg|gr|pt|ie|lu|mt|cy|ee|lv|lt|si|hr|rs|ba|mk|al|me|is|li|ad|mc|sm|va|by|ua|md|ge|am|az|kz|uz|tm|tj|kg|mn|cn|jp|kr|in|au|nz|za|br|mx|ar|cl|co|pe|ve|ec|uy|py|bo|cr|pa|do|gt|hn|ni|sv|bz|jm|tt|bb|gd|lc|vc|ag|bs|dm|kn|sr|gy|fk|ai|vg|ky|bm|tc|ms|pw|fm|mh|nr|ki|tv|to|ws|sb|vu|nc|pf|as|gu|mp|pr|vi|um|us|ca)$', caseSensitive: false).hasMatch(cleanUser)); // Termina en dominio común
                
                // Only add if it's a valid username (alphanumeric, underscore, hyphen)
                // and doesn't start with # or : or numbers only
                // and is not a server/host name
                if (cleanUser.isNotEmpty && 
                    !cleanUser.startsWith(':') && 
                    !cleanUser.startsWith('#') &&
                    !isServerHost &&
                    RegExp(r'^[a-zA-Z_\-][a-zA-Z0-9_\-]*$').hasMatch(cleanUser)) { // Removido el punto de la regex
                  // Verificar si el usuario ya existe (case-insensitive)
                  final cleanUserLower = cleanUser.toLowerCase();
                  String? existingUser;
                  for (var user in channels[finalChannel]!.users) {
                    if (user.toLowerCase() == cleanUserLower) {
                      existingUser = user;
                      break;
                    }
                  }
                  
                  // Si el usuario ya existe, actualizar su modo
                  if (existingUser != null) {
                    if (userMode != null) {
                      channels[finalChannel]!.addUser(existingUser, mode: userMode);
                      updatedCount++;
                      // print('🔍 [DEBUG] ✅ Updated mode for existing user: "$existingUser" -> "$userMode"');
                    } else {
                      // Si no tiene modo en la lista actual, mantener el modo existente si lo tiene
                      final existingMode = channels[finalChannel]!.getUserMode(existingUser);
                      if (existingMode != null) {
                        // print('🔍 [DEBUG] ℹ️  Keeping existing mode for user: "$existingUser" -> "$existingMode"');
                      }
                    }
                  } else {
                    // print('🔍 [DEBUG] ➕ Adding new user: "$cleanUser" with mode: "$userMode"');
                    channels[finalChannel]!.addUser(cleanUser, mode: userMode);
                  addedCount++;
                }
              } else {
                if (isServerHost) {
                  // print('🔍 [DEBUG] ❌ Skipping server/host name: "$cleanUser"');
                } else {
                  // print('🔍 [DEBUG] ❌ Skipping invalid user: "$cleanUser"');
                }
              }
            }
            
            print('🔍 [DEBUG] Added $addedCount new users, updated $updatedCount existing users');
            print('🔍 [DEBUG] Total users in channel now: ${channels[finalChannel]!.users.length}');
            print('🔍 [DEBUG] Users list: ${channels[finalChannel]!.users}');
            // Debug: mostrar modos de todos los usuarios
            for (var u in channels[finalChannel]!.users) {
              final mode = channels[finalChannel]!.getUserMode(u);
              if (mode != null) {
                // print('🔍 [DEBUG] User "$u" has mode: "$mode"');
              }
            }
            
            // Notificar que la lista de usuarios se actualizó
            // print('🔍 [DEBUG] Notifying user list listeners for channel: $finalChannel');
            _notifyUserListListeners(finalChannel);
            // print('🔍 [DEBUG] ✅ User list updated for $channel with ${channels[channel]!.users.length} users');
          } else {
            print('🔍 [DEBUG] ⚠️  No colon found in line, cannot parse users');
          }
          break;
        
        case '366': // End of NAMES list
          print('📋 End of NAMES list (366)');
          if (args.length >= 2) {
            var channel = args[1];
            channel = _normalizeChannelName(channel);
            print('  ✅ Finished receiving user list for $channel');
            // Notificar una vez más para asegurar que la UI se actualice
            if (channels.containsKey(channel)) {
              _notifyUserListListeners(channel);
              // Solicitar información WHO para obtener hosts de usuarios (especialmente robots)
              // Esto se hace después de recibir la lista de usuarios para detectar robots
              Future.delayed(const Duration(milliseconds: 500), () {
                if (channels.containsKey(channel)) {
                  sendWho(channel);
                }
              });
              print('  ✅ Final user count for $channel: ${channels[channel]!.users.length}');
            }
          }
          break;
        
        case 'NICK':
          // El servidor confirma el cambio de nick
          // Formato: :oldnick!user@host NICK :newnick
          // O: :oldnick NICK :newnick
          // print('🔄 [IRCService] 🔴🔴🔴 NICK command received - Full line: $line');
          // print('🔄 [IRCService] NICK command - source: $source, command: $command, args: $args');
          // print('🔄 [IRCService] NICK command - parts: $parts');
          // print('🔄 [IRCService] NICK command - nick from source: $nick');
          
          if (args.isNotEmpty) {
            // El nuevo nick puede estar en args[0] con o sin ':'
            var newNick = args[0];
            if (newNick.startsWith(':')) {
              newNick = newNick.substring(1);
            }
            newNick = newNick.trim();
            
            // El oldNick viene del source (antes del !)
            final oldNick = nick;
            
            // print('🔄 [IRCService] NICK parsed - oldNick="$oldNick", newNick="$newNick", our nickname="$_nickname"');
            // print('🔄 [IRCService] Comparación: oldNick.toLowerCase()="${oldNick?.toLowerCase()}" == _nickname.toLowerCase()="${_nickname?.toLowerCase()}"');
            // print('🔄 [IRCService] ¿Son iguales?: ${oldNick != null && _nickname != null && oldNick.toLowerCase() == _nickname!.toLowerCase()}');
            
            // Si es nuestro propio cambio de nick
            if (oldNick != null && _nickname != null && oldNick.toLowerCase() == _nickname!.toLowerCase()) {
              // print('🔄 [IRCService] ✅✅✅ Nuestro nick cambió de "$oldNick" a "$newNick"');
              _nickname = newNick;
              // print('🔄 [IRCService] _nickname actualizado a: "$_nickname"');
              
              // Actualizar el nick en todos los canales donde aparezca nuestro nick antiguo
              // print('🔄 [IRCService] Actualizando nick en canales...');
              for (var channel in channels.values) {
                if (channel.users.contains(oldNick)) {
                  // print('🔄 [IRCService] Actualizando nick en canal "${channel.name}": "$oldNick" -> "$newNick"');
                  channel.users.remove(oldNick);
                  channel.users.add(newNick);
                  _notifyUserListListeners(channel.name);
                }
              }
              
              // print('🔄 [IRCService] Notificando ${_nickChangeListeners.length} listeners...');
              // Notificar a los listeners del cambio de nick
              for (var i = 0; i < _nickChangeListeners.length; i++) {
                try {
                  // print('🔄 [IRCService] Llamando listener $i con: "$newNick"');
                  _nickChangeListeners[i](newNick);
                  // print('🔄 [IRCService] Listener $i llamado exitosamente');
                } catch (e, stackTrace) {
                  // print('⚠️  [IRCService] Error en listener $i de cambio de nick: $e');
                  // print('⚠️  [IRCService] Stack trace: $stackTrace');
                }
              }
              // print('🔄 [IRCService] ✅ Todos los listeners notificados');
            } else {
              // Es el cambio de nick de otro usuario
              // print('🔄 [IRCService] Usuario "$oldNick" cambió su nick a "$newNick" (no es nuestro)');
              // Actualizar el nick en todos los canales donde aparezca
              for (var channel in channels.values) {
                if (channel.users.contains(oldNick)) {
                  channel.users.remove(oldNick);
                  channel.users.add(newNick);
                  _notifyUserListListeners(channel.name);
                }
              }
            }
          } else {
            // print('⚠️  [IRCService] NICK command sin argumentos: $line');
          }
          break;
        
        case 'JOIN':
          // print('🔍 [DEBUG] ⭐ JOIN command received! Full line: $line');
          // print('🔍 [DEBUG] JOIN - args: $args, nick from source: "$nick", our nickname: "$_nickname"');
          
          if (args.isNotEmpty) {
            var channel = args[0];
            // print('🔍 [DEBUG] JOIN - raw channel from args[0]: "$channel"');
            channel = _normalizeChannelName(channel);
            // print('🔍 [DEBUG] JOIN - normalized channel: "$channel"');
            
            // Solo procesar si es un canal válido
            if (!channel.startsWith('#')) {
              // print('🔍 [DEBUG] ⚠️  Invalid channel name in JOIN: $channel');
              break;
            }
            
            if (!channels.containsKey(channel)) {
              channels[channel] = IRCChannel(name: channel);
              // print('🔍 [DEBUG] Created channel entry for JOIN: $channel');
            }
            
            // Validar que el nick no sea un servidor/host antes de agregarlo
            final isServerHost = nick.contains('.') && 
                (nick.split('.').length > 2 || // Múltiples puntos (ej: ceres.globalchat.org)
                 RegExp(r'\.(org|com|net|edu|gov|io|co|uk|de|fr|es|it|nl|be|ch|at|se|no|dk|fi|pl|cz|sk|hu|ro|bg|gr|pt|ie|lu|mt|cy|ee|lv|lt|si|hr|rs|ba|mk|al|me|is|li|ad|mc|sm|va|by|ua|md|ge|am|az|kz|uz|tm|tj|kg|mn|cn|jp|kr|in|au|nz|za|br|mx|ar|cl|co|pe|ve|ec|uy|py|bo|cr|pa|do|gt|hn|ni|sv|bz|jm|tt|bb|gd|lc|vc|ag|bs|dm|kn|sr|gy|fk|ai|vg|ky|bm|tc|ms|pw|fm|mh|nr|ki|tv|to|ws|sb|vu|nc|pf|as|gu|mp|pr|vi|um|us|ca)$', caseSensitive: false).hasMatch(nick)); // Termina en dominio común
            
            if (!isServerHost) {
              channels[channel]!.addUser(nick, host: host);
              // print('🔍 [DEBUG] Added user "$nick" to channel "$channel" with host: ${host ?? "unknown"}');
              // Notificar cambio en la lista de usuarios
              _notifyUserListListeners(channel);
            } else {
              // print('🔍 [DEBUG] ❌ Skipping server/host name in JOIN: "$nick"');
            }
            
            final msg = IRCMessage(
              nick: nick,
              channel: channel,
              message: 'se unió al canal',
              timestamp: DateTime.now(),
              isSystem: true,
              messageId: IRCMessage.generateMessageId(),
            );
            channels[channel]!.addMessage(msg);
            _notifyMessageListeners(msg);
            
            // Si es nuestro propio JOIN, solicitar la lista de usuarios
            final isOurJoin = nick == _nickname;
            // print('🔍 [DEBUG] JOIN check: nick="$nick" == nickname="$_nickname" ? $isOurJoin');
            
            if (isOurJoin) {
              print('🔍 [DEBUG] ✅✅✅ Our own JOIN detected! ✅✅✅');
              print('🔍 [DEBUG] Requesting NAMES for $channel (immediate)');
              _sendCommand('NAMES $channel');
              
              // Solicitar el TOPIC del canal
              // print('🔍 [DEBUG] Requesting TOPIC for $channel (immediate)');
              _sendCommand('TOPIC $channel');
              
              // También solicitar después de delays
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_isConnected && _hasActiveConnection) {
                  // print('🔍 [DEBUG] Requesting NAMES for $channel (delayed 500ms)');
                  _sendCommand('NAMES $channel');
                  // print('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 500ms)');
                  _sendCommand('TOPIC $channel');
                }
              });
              
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (_isConnected && _hasActiveConnection) {
                  // print('🔍 [DEBUG] Requesting NAMES for $channel (delayed 1500ms)');
                  _sendCommand('NAMES $channel');
                  // print('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 1500ms)');
                  _sendCommand('TOPIC $channel');
                }
              });
              
              Future.delayed(const Duration(milliseconds: 3000), () {
                if (_isConnected && _hasActiveConnection) {
                  // print('🔍 [DEBUG] Requesting NAMES for $channel (delayed 3000ms)');
                  _sendCommand('NAMES $channel');
                  // print('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 3000ms)');
                  _sendCommand('TOPIC $channel');
                }
              });
            } else {
              // print('🔍 [DEBUG] ❌ Not our JOIN: nick="$nick" != nickname="$_nickname"');
            }
          } else {
            // print('🔍 [DEBUG] ⚠️  JOIN command with no args');
          }
          break;
        
        case 'PART':
          if (args.isNotEmpty) {
            var channel = args[0];
            channel = _normalizeChannelName(channel);
            
            if (channels.containsKey(channel)) {
              channels[channel]!.removeUser(nick);
              
              final msg = IRCMessage(
                nick: nick,
                channel: channel,
                message: 'dejó el canal',
                timestamp: DateTime.now(),
                messageId: IRCMessage.generateMessageId(),
                isSystem: true,
              );
              channels[channel]!.addMessage(msg);
              _notifyMessageListeners(msg);
              // Notificar cambio en la lista de usuarios
              _notifyUserListListeners(channel);
            }
          }
          break;
        
        case 'KICK':
          // Formato: :nick!user@host KICK #channel target :reason
          if (args.length >= 2) {
            var channel = args[0];
            final kickedNick = args[1];
            channel = _normalizeChannelName(channel);
            
            if (channels.containsKey(channel)) {
              // Remover el usuario de la lista del canal
              channels[channel]!.removeUser(kickedNick);
              
              // Obtener la razón si existe
              final reason = args.length > 2 
                  ? args.sublist(2).join(' ').replaceFirst(':', '').trim()
                  : null;
              
              final msg = IRCMessage(
                nick: nick,
                channel: channel,
                message: reason != null && reason.isNotEmpty
                    ? 'expulsó a $kickedNick (razón: $reason)'
                    : 'expulsó a $kickedNick',
                timestamp: DateTime.now(),
                isSystem: true,
                messageId: IRCMessage.generateMessageId(),
              );
              channels[channel]!.addMessage(msg);
              _notifyMessageListeners(msg);
              // Notificar cambio en la lista de usuarios
              _notifyUserListListeners(channel);
              // print('👢 [IRCService] Usuario $kickedNick expulsado de $channel');
            }
          }
          break;
        
        // WHOIS responses
        case '311': // WHOIS user info: :server 311 nick target username host * :realname
          if (args.length >= 5) {
            final targetNick = args[1];
            final username = args[2];
            final host = args[3];
            final realName = args.length > 5 ? args.sublist(4).join(' ').replaceFirst(':', '').trim() : null;
            
            _pendingWhois[targetNick] = WhoisInfo(
              nick: targetNick,
              username: username,
              host: host,
              realName: realName,
            );
            
            // Actualizar el host en todos los canales donde esté el usuario (case-insensitive)
            final affectedChannels = <String>[];
            final targetNickLower = targetNick.toLowerCase();
            for (var channelEntry in channels.entries) {
              // Buscar el usuario de forma case-insensitive
              bool userExists = false;
              String? existingNick;
              for (var user in channelEntry.value.users) {
                if (user.toLowerCase() == targetNickLower) {
                  userExists = true;
                  existingNick = user;
                  break;
                }
              }
              if (userExists && existingNick != null) {
                channelEntry.value.addUser(existingNick, host: host);
                affectedChannels.add(channelEntry.key);
              }
            }
            // Notificar cambios en los canales afectados para actualizar la UI
            for (var channel in affectedChannels) {
              _notifyUserListListeners(channel);
            }
            // print('🔍 [WHOIS] 311 - User info for $targetNick: $username@$host ($realName)');
          }
          break;
        
        case '312': // WHOIS server info: :server 312 nick target server :server info
          if (args.length >= 3) {
            final targetNick = args[1];
            final server = args[2];
            final serverInfo = args.length > 3 ? args.sublist(3).join(' ').replaceFirst(':', '').trim() : null;
            
            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                server: server,
                serverInfo: serverInfo,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                server: server,
                serverInfo: serverInfo,
              );
            }
            // print('🔍 [WHOIS] 312 - Server info for $targetNick: $server ($serverInfo)');
          }
          break;
        
        case '313': // WHOIS operator: :server 313 nick target :is an IRC Operator
          if (args.length >= 3) {
            final targetNick = args[1];
            // El resto de args suele contener el texto con el rol
            final roleText = args.sublist(2).join(' ').replaceFirst(':', '').trim();
            
            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                isStaff: true,
                staffRole: roleText.isNotEmpty ? roleText : 'Operador IRC',
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                isStaff: true,
                staffRole: roleText.isNotEmpty ? roleText : 'Operador IRC',
              );
            }
            
            // Actualizar cache de IRCop si es el usuario actual
            if (targetNick.toLowerCase() == _nickname?.toLowerCase()) {
              _isIRCOp = true;
            }
            
            // print('🔍 [WHOIS] 313 - $targetNick staff: ${_pendingWhois[targetNick]!.staffRole}');
          }
          break;
        
        case '381': // RPL_YOUREOPER: :server 381 nick :You are now an IRC Operator
          // El código 381 siempre es para el usuario que ejecutó OPER
          // Formato típico: :server 381 nick :You are now an IRC Operator
          // print('🔍 [IRCService] Código 381 recibido, línea completa: $line');
          // print('🔍 [IRCService] Args: $args, nuestro nick: $_nickname');
          
          // El código 381 siempre es para nosotros si lo recibimos
          // No necesitamos verificar el nick
          _isIRCOp = true;
          // print('✅ [IRCService] Identificado como IRCop exitosamente (código 381)');
          
          // Notificar a los listeners de IRCop
          for (var listener in _ircopListeners) {
            listener();
          }
          break;
        
        case '491': // ERR_NOOPERHOST: :server 491 nick :No O-lines for your host
          if (args.length >= 2) {
            final targetNick = args[1];
            if (targetNick.toLowerCase() == _nickname?.toLowerCase()) {
              // print('❌ [IRCService] Error: No tienes permisos de operador para este host');
            }
          }
          break;
        
        case '317': // WHOIS idle/signon: :server 317 nick target idle signon :seconds idle, signon time
          if (args.length >= 4) {
            final targetNick = args[1];
            final idleSeconds = int.tryParse(args[2]);
            final signonTimestamp = int.tryParse(args[3]);
            final signonTime = signonTimestamp != null 
                ? DateTime.fromMillisecondsSinceEpoch(signonTimestamp * 1000)
                : null;
            
            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                idleSeconds: idleSeconds,
                signonTime: signonTime,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                idleSeconds: idleSeconds,
                signonTime: signonTime,
              );
            }
            // print('🔍 [WHOIS] 317 - Idle/signon for $targetNick: ${idleSeconds}s idle, signed on: $signonTime');
          }
          break;
        
        case '318': // End of WHOIS: :server 318 nick target :End of /WHOIS list.
          if (args.length >= 2) {
            final targetNick = args[1];
            if (_pendingWhois.containsKey(targetNick)) {
              final whoisInfo = _pendingWhois[targetNick]!;
              _whoisCache[targetNick.toLowerCase()] = whoisInfo;
              _notifyWhoisListeners(whoisInfo);
              _pendingWhois.remove(targetNick);
              // print('🔍 [WHOIS] 318 - End of WHOIS for $targetNick');
            } else {
              // Si no hay información pendiente, crear una entrada básica para notificar
              // Esto puede pasar si el servidor envía 318 sin enviar otros códigos
              // print('⚠️  [WHOIS] 318 recibido pero no hay información pendiente para $targetNick');
              final basicInfo = WhoisInfo(nick: targetNick);
              _whoisCache[targetNick.toLowerCase()] = basicInfo;
              _notifyWhoisListeners(basicInfo);
            }
          }
          break;
        
        case '321': // RPL_LISTSTART: Inicio de lista de canales
          _listResults.clear();
          // print('📋 [LIST] Iniciando lista de canales');
          break;
        
        case '322': // RPL_LIST: Información de un canal
          // Formato: :server 322 nick channel user_count :topic
          if (args.length >= 3) {
            final channel = args[1];
            final userCount = int.tryParse(args[2]) ?? 0;
            final topic = args.length > 3 ? args.sublist(3).join(' ').replaceFirst(':', '').trim() : '';
            
            _listResults.add({
              'channel': channel,
              'users': userCount,
              'topic': topic,
            });
            // print('📋 [LIST] Canal: $channel, Usuarios: $userCount, Topic: $topic');
          }
          break;
        
        case '323': // RPL_LISTEND: Fin de lista de canales
          _notifyListListeners(_listResults);
          // print('📋 [LIST] Fin de lista (${_listResults.length} canales)');
          break;
        
        case '352': // RPL_WHOREPLY: Información de un usuario en WHO
          // Formato: :server 352 nick channel username host server nick status :realname
          if (args.length >= 7) {
            final channel = args[1];
            final username = args[2];
            final host = args[3];
            final server = args[4];
            final nick = args[5];
            final status = args[6];
            final realname = args.length > 7 ? args.sublist(7).join(' ').replaceFirst(':', '').trim() : '';
            
            _whoResults.add({
              'channel': channel,
              'username': username,
              'host': host,
              'server': server,
              'nick': nick,
              'status': status,
              'realname': realname,
            });
            
            // Actualizar el host en el canal si existe
            final normalizedChannel = _normalizeChannelName(channel);
            if (channels.containsKey(normalizedChannel)) {
              channels[normalizedChannel]!.addUser(nick, host: host);
              // Notificar cambio en la lista de usuarios para actualizar la UI
              _notifyUserListListeners(normalizedChannel);
            }
            // print('👤 [WHO] Usuario: $nick ($username@$host) en $channel, estado: $status');
          }
          break;
        
        case '315': // RPL_ENDOFWHO: Fin de WHO
          _notifyWhoListeners(_whoResults);
          // Notificar cambios en todos los canales afectados
          for (var result in _whoResults) {
            final channel = result['channel'] as String?;
            if (channel != null) {
              final normalizedChannel = _normalizeChannelName(channel);
              if (channels.containsKey(normalizedChannel)) {
                _notifyUserListListeners(normalizedChannel);
              }
            }
          }
          // print('👤 [WHO] Fin de WHO (${_whoResults.length} usuarios)');
          _whoResults.clear(); // Limpiar después de notificar
          break;
        
        // Comandos IRCop - capturar respuestas genéricas
        case '364': // RPL_LINKS: Información de un servidor en LINKS
        case '371': // RPL_INFO: Línea de información (STATS, MOTD, etc.)
        case '372': // RPL_MOTD: Línea del mensaje del día
        case '373': // RPL_INFOSTART: Inicio de información
        case '374': // RPL_ENDOFINFO: Fin de información
        case '375': // RPL_MOTDSTART: Inicio de MOTD
        case '213': // RPL_STATSCOMMANDS: Estadísticas de comandos
        case '214': // RPL_STATSCLINE: Estadísticas de conexiones
        case '215': // RPL_STATSNLINE: Estadísticas de N-lines
        case '216': // RPL_STATSILINE: Estadísticas de I-lines
        case '217': // RPL_STATSKLINE: Estadísticas de K-lines
        case '218': // RPL_STATSYLINE: Estadísticas de Y-lines
        case '200': // RPL_TRACELINK: Información de TRACE
        case '201': // RPL_TRACECONNECTING: TRACE conectando
        case '202': // RPL_TRACEHANDSHAKE: TRACE handshake
        case '203': // RPL_TRACEUNKNOWN: TRACE desconocido
        case '204': // RPL_TRACEOPERATOR: TRACE operador
        case '205': // RPL_TRACEUSER: TRACE usuario
        case '206': // RPL_TRACESERVER: TRACE servidor
        case '208': // RPL_TRACENEWTYPE: TRACE nuevo tipo
        case '261': // RPL_TRACELOG: TRACE log
        case '006': // RPL_MAP: Línea del mapa
        case '234': // RPL_SERVLIST: Lista de servicios
          // Capturar líneas de respuesta de comandos IRCop
          if (_currentIRCOpCommand != null) {
            final message = args.length > 1 ? args.sublist(1).join(' ').replaceFirst(':', '').trim() : '';
            if (message.isNotEmpty) {
              _ircopCommandResults.add(message);
              // print('📋 [IRCOp] Respuesta de $_currentIRCOpCommand: $message');
            }
          }
          break;
        
        case '365': // RPL_ENDOFLINKS: Fin de LINKS
        case '219': // RPL_ENDOFSTATS: Fin de STATS
        case '262': // RPL_TRACEEND: Fin de TRACE
        case '007': // RPL_MAPEND: Fin de MAP
        case '376': // RPL_ENDOFMOTD: Fin de MOTD
        case '235': // RPL_SERVLISTEND: Fin de lista de servicios
          // Fin de comandos IRCop
          if (_currentIRCOpCommand != null) {
            _notifyIRCOpCommandListeners(_ircopCommandResults);
            // print('📋 [IRCOp] Fin de $_currentIRCOpCommand (${_ircopCommandResults.length} líneas)');
            _ircopCommandResults.clear();
            _currentIRCOpCommand = null;
            _currentIRCOpEndCode = null;
          }
          break;
        
        case '401': // ERR_NOSUCHNICK: :server 401 nick target :No such nick/channel
          if (args.length >= 2) {
            final targetNick = args[1];
            // print('⚠️  [WHOIS] 401 - No such nick: $targetNick');
            // Notificar que el nick no existe
            final errorInfo = WhoisInfo(nick: targetNick);
            _whoisCache[targetNick.toLowerCase()] = errorInfo;
            _notifyWhoisListeners(errorInfo);
            _pendingWhois.remove(targetNick);
          }
          break;
        
        case '319': // WHOIS channels: :server 319 nick target :#channel1 #channel2
          if (args.length >= 3) {
            final targetNick = args[1];
            final channelsStr = args.sublist(2).join(' ').replaceFirst(':', '').trim();
            final channelsList = channelsStr.split(' ').where((c) => c.isNotEmpty).toList();
            
            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                channels: channelsList,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                channels: channelsList,
              );
            }
            // print('🔍 [WHOIS] 319 - Channels for $targetNick: $channelsList');
          }
          break;

        case '671': // WHOIS secure connection (RPL_WHOISSECURE): :server 671 nick target :is using a secure connection
          if (args.length >= 2) {
            final targetNick = args[1];
            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                isSecureConnection: true,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                isSecureConnection: true,
              );
            }
            // print('🔍 [WHOIS] 671 - $targetNick is using a secure connection (SSL/TLS)');
          }
          break;
        
        case '301': // AWAY message: :server 301 nick target :away message
          if (args.length >= 3) {
            final targetNick = args[1];
            final awayMessage = args.sublist(2).join(' ').replaceFirst(':', '').trim();
            
            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                isAway: true,
                awayMessage: awayMessage,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                isAway: true,
                awayMessage: awayMessage,
              );
            }
            // print('🔍 [WHOIS] 301 - $targetNick is away: $awayMessage');
          }
          break;
        
        case 'PRIVMSG':
          if (args.isNotEmpty) {
            // print('🔍🔍🔍 [DEBUG PRIVMSG] 📨 PRIVMSG recibido - Raw line: $line');
            // print('🔍🔍🔍 [DEBUG PRIVMSG] 📨 PRIVMSG - nick del source: "$nick", args: $args');
            
            var target = args[0];
            // print('🔍🔍🔍 [DEBUG PRIVMSG] 📨 PRIVMSG - target original: "$target"');
            // print('🔍🔍🔍 [DEBUG PRIVMSG] 📨 PRIVMSG - nuestro nickname: "$_nickname"');
            
            var targetChannel = _normalizeChannelName(target);
            
            // Determinar si es un canal (#) o un mensaje privado (nick)
            bool isChannel = target.startsWith('#');
            String channelKey;
            bool isPrivateMessageToUs = false;
            
            // print('🔍 [DEBUG] 📨 PRIVMSG - isChannel: $isChannel');
            
            if (isChannel) {
              // Es un canal, usar el nombre del canal normalizado
              channelKey = targetChannel;
              // print('🔍 [DEBUG] 📨 PRIVMSG - Es un mensaje de canal: $channelKey');
            } else {
              // Es un mensaje privado
              // print('🔍 [DEBUG] 📨 PRIVMSG - Es un mensaje privado (target no empieza con #)');
              // print('🔍 [DEBUG] 📨 PRIVMSG - Comparando target "$target" (lowercase: ${target.toLowerCase()}) con nickname "$_nickname" (lowercase: ${_nickname?.toLowerCase()})');
              
              // Si el target es nuestro nickname, es un mensaje que NOS ENVIAN
              // En ese caso, usar el nick del remitente como channelKey
              // Si el target NO es nuestro nickname, es un mensaje que ENVIAMOS
              // En ese caso, usar el target como channelKey
              
              // Limpiar el target de posibles espacios o caracteres extra
              final cleanTarget = target.trim();
              final cleanNickname = _nickname?.trim();
              
              // print('🔍 [DEBUG] 📨 PRIVMSG - Comparación detallada:');
              // print('🔍 [DEBUG] 📨 PRIVMSG - target limpio: "$cleanTarget" (length: ${cleanTarget.length})');
              // print('🔍 [DEBUG] 📨 PRIVMSG - nickname limpio: "$cleanNickname" (length: ${cleanNickname?.length ?? 0})');
              // print('🔍 [DEBUG] 📨 PRIVMSG - target.toLowerCase(): "${cleanTarget.toLowerCase()}"');
              // print('🔍 [DEBUG] 📨 PRIVMSG - nickname.toLowerCase(): "${cleanNickname?.toLowerCase() ?? "null"}"');
              // print('🔍 [DEBUG] 📨 PRIVMSG - ¿Son iguales?: ${cleanNickname != null && cleanTarget.toLowerCase() == cleanNickname.toLowerCase()}');
              
              if (cleanNickname != null && cleanTarget.toLowerCase() == cleanNickname.toLowerCase()) {
                // Mensaje privado que nos envían, usar el nick del remitente
                isPrivateMessageToUs = true;
                channelKey = nick.toLowerCase();
                // print('🔍 [DEBUG] 📨 PRIVMSG: ✅✅✅ Mensaje privado RECIBIDO de "$nick", usando channelKey="$channelKey" ✅✅✅');
                
                // Verificar si el remitente está en la lista de ignorados (solo para mensajes que nos envían)
                final senderNick = nick.toLowerCase();
                if (_ignoredUsers.contains(senderNick)) {
                  // print('🚫 [IRCService] Mensaje privado ignorado de usuario: $nick (en lista de ignorados: $_ignoredUsers)');
                  break; // Ignorar el mensaje completamente
                }
                // print('✅ [IRCService] Mensaje privado de "$nick" NO está en lista de ignorados. Lista actual: $_ignoredUsers');
                // print('✅ [IRCService] Procediendo a procesar mensaje privado de "$nick"');
              } else {
                // Mensaje privado que enviamos, usar el target
                channelKey = cleanTarget.toLowerCase();
                // print('🔍 [DEBUG] 📨 PRIVMSG: Mensaje privado ENVIADO a "$cleanTarget", usando channelKey="$channelKey"');
              }
            }
            
            // Para mensajes de canal, también verificar si el remitente está ignorado
            if (isChannel) {
              final senderNick = nick.toLowerCase();
              if (_ignoredUsers.contains(senderNick)) {
                // print('🚫 [IRCService] Mensaje de canal ignorado de usuario: $nick en $target');
                break; // Ignorar el mensaje completamente
              }
            }
            
            // Crear el canal/query si no existe
            final isNewChannel = !channels.containsKey(channelKey);
            if (isNewChannel) {
              channels[channelKey] = IRCChannel(name: channelKey);
              // print('🔍 [DEBUG] Creado ${isChannel ? "canal" : "query"}: $channelKey');
            }
            
            // Agregar el usuario a la lista del canal si es un mensaje de canal
            // Esto asegura que todos los usuarios que envían mensajes aparezcan en la lista
            if (isChannel) {
              final channelObj = channels[channelKey]!;
              // Verificar si el usuario ya está en la lista (case-insensitive)
              final nickLower = nick.toLowerCase();
              bool userExists = false;
              for (var existingUser in channelObj.users) {
                if (existingUser.toLowerCase() == nickLower) {
                  userExists = true;
                  break;
                }
              }
              
              if (!userExists) {
                // Agregar el usuario (con host si está disponible)
                channelObj.addUser(nick, host: host);
                // Notificar cambio en la lista de usuarios
                _notifyUserListListeners(channelKey);
                // print('🔍 [DEBUG] Usuario "$nick" agregado a la lista del canal "$channelKey" desde PRIVMSG');
              } else if (host != null) {
                // Si el usuario ya está en la lista pero tenemos un host nuevo, actualizarlo
                channelObj.addUser(nick, host: host);
                // Notificar para actualizar la UI
                _notifyUserListListeners(channelKey);
              }
            }
            
            // El formato es: :nick!user@host PRIVMSG target :mensaje
            final privmsgIndex = line.indexOf('PRIVMSG');
            if (privmsgIndex != -1) {
              // Encontrar el ':' que viene después del target
              final targetEndIndex = line.indexOf(target, privmsgIndex) + target.length;
              final colonIndex = line.indexOf(':', targetEndIndex);
              
              if (colonIndex != -1) {
                // El mensaje es todo lo que viene después del ':'
                var messageContent = line.substring(colonIndex + 1).trim();
                
                // Detectar y procesar mensajes ACTION (/me)
                bool isAction = false;
                String? actionText;
                if (messageContent.startsWith('\x01ACTION ') && messageContent.endsWith('\x01')) {
                  isAction = true;
                  // Extraer el texto de la acción (sin \x01ACTION y sin el \x01 final)
                  actionText = messageContent.substring(8, messageContent.length - 1).trim();
                  messageContent = actionText; // Usar el texto de la acción como mensaje
                  // print('🎭 [IRCService] Mensaje ACTION detectado: "$actionText"');
                }
                
                // Verificar si es una respuesta de STATUS de NickServ (viene como NOTICE pero se procesa como PRIVMSG)
                // Formato: :NickServ!NickServ@services.globalchat.org NOTICE nick :STATUS nick 3
                // O como PRIVMSG: :NickServ!NickServ@services.globalchat.org PRIVMSG nick :STATUS nick 3
                if ((nick.toLowerCase() == 'nickserv' || nick.toLowerCase() == 'nick') && 
                    messageContent.contains('STATUS')) {
                  final match = RegExp(r'STATUS\s+(\S+)\s+(\d+)').firstMatch(messageContent);
                  if (match != null) {
                    final checkedNick = match.group(1)!.toLowerCase();
                    final status = int.tryParse(match.group(2)!);
                    // print('📋 [IRCService] Status recibido para nick "$checkedNick": $status');
                    final completer = _statusCheckCompleters.remove(checkedNick);
                    if (completer != null && !completer.isCompleted) {
                      completer.complete(status);
                    }
                    // No procesar como mensaje normal si es una respuesta de STATUS
                    return;
                  }
                }
                
                // Ignorar SOLO el mensaje IDENTIFY que **nosotros** enviamos al bot "nick"
                // Formato típico ecoado por el servidor:
                //   :NuestroNick!user@host PRIVMSG nick :IDENTIFY NuestroNick password
                // - nick (source)  -> nuestro propio nick
                // - target         -> "nick"
                // - messageContent -> comienza por "IDENTIFY ..."
                //
                // Las respuestas del bot "nick" (por ejemplo "You are now identified")
                // NO deben coincidir con esta condición y se mostrarán normalmente.
                if (_nickname != null &&
                    nick.toLowerCase() == _nickname!.toLowerCase() &&
                    target.toLowerCase() == 'nick' &&
                    messageContent.toUpperCase().startsWith('IDENTIFY')) {
                  // print('🔐 [IRCService] Ignorando PRIVMSG IDENTIFY que enviamos al bot \"nick\" (no debe aparecer en el chat)');
                  return;
                }
                
                // print('🔍🔍🔍 [DEBUG PRIVMSG] PRIVMSG parsed: nick="$nick", target="$target", channelKey="$channelKey", message="$messageContent"');
            
                // Verificar si es nuestro propio mensaje (confirmación del servidor)
                // - Para mensajes de canal: el nick del remitente debe ser nuestro nick
                // - Para mensajes privados: también el nick del remitente debe ser nuestro nick
                //   (el target será el nick del otro usuario o servicio, p.ej. "nick")
                final isOurOwnMessage = _nickname != null &&
                    nick.toLowerCase() == _nickname!.toLowerCase();
                
                // print('🔍🔍🔍 [DEBUG PRIVMSG] Verificando si es nuestro mensaje:');
                // print('  - nick del source: "$nick"');
                // print('  - nuestro nickname: "$_nickname"');
                // print('  - isChannel: $isChannel');
                // print('  - Comparación: "${nick.toLowerCase()}" == "${_nickname?.toLowerCase()}" = $isOurOwnMessage');
                // print('  - Mensaje recibido: "$messageContent"');
                // print('  - Canal: "$channelKey"');
                
                if (isOurOwnMessage) {
                  // Es nuestro propio mensaje, verificar si hay un mensaje pendiente
                  // print('✅✅✅ [DEBUG PRIVMSG] Mensaje propio detectado: "$messageContent" en canal "$channelKey"');
                  
                  // Buscar mensaje pendiente que coincida
                  if (!channels.containsKey(channelKey)) {
                    // print('❌❌❌ [DEBUG PRIVMSG] ERROR: Canal "$channelKey" no existe en channels!');
                    // print('❌❌❌ [DEBUG PRIVMSG] Canales disponibles: ${channels.keys.toList()}');
                    return;
                  }
                  
                  final channelObj = channels[channelKey]!;
                  
                  // Buscar el mensaje pendiente más reciente que coincida
                  int pendingMsgIndex = -1;
                  IRCMessage? pendingMsg;
                  
                  // Buscar desde el final (más reciente) hacia el principio
                  // print('🔍🔍🔍 [DEBUG PRIVMSG] Buscando mensaje pendiente. Total mensajes: ${channelObj.messages.length}');
                  for (int i = channelObj.messages.length - 1; i >= 0; i--) {
                    final msg = channelObj.messages[i];
                    if (msg.isPending && 
                        msg.channel == channelKey &&
                        msg.nick == _nickname) {
                      // Verificar si el contenido coincide (exacto o similar)
                      final msgContent = msg.message.trim();
                      final receivedContent = messageContent.trim();
                      // print('🔍 [IRCService] Comparando pendiente[$i]: "$msgContent" con recibido: "$receivedContent"');
                      if (msgContent == receivedContent ||
                          receivedContent.contains(msgContent) ||
                          msgContent.contains(receivedContent)) {
                        pendingMsgIndex = i;
                        pendingMsg = msg;
                        // print('✅ [IRCService] Mensaje pendiente encontrado en índice $i: "${msg.message}" (pendingId: ${msg.pendingId})');
                        break;
                      }
                    }
                  }
                  
                  if (pendingMsgIndex == -1) {
                    // print('⚠️  [IRCService] No se encontró mensaje pendiente. Listando todos los pendientes:');
                    for (int i = 0; i < channelObj.messages.length; i++) {
                      final msg = channelObj.messages[i];
                      if (msg.isPending && msg.channel == channelKey && msg.nick == _nickname) {
                        // print('  - [$i] "${msg.message}" (pendingId: ${msg.pendingId})');
                      }
                    }
                  }
                  
                  if (pendingMsgIndex != -1 && pendingMsg != null) {
                    // Verificar si el mensaje pendiente tiene un timer activo
                    final hasActiveTimer = pendingMsg.pendingId != null && 
                                          _pendingMessageTimers.containsKey(pendingMsg.pendingId);
                    
                    if (hasActiveTimer) {
                      // El timer aún está activo, el mensaje aún no se ha enviado
                      // El servidor está respondiendo a un mensaje anterior o hay un problema
                      // print('⏱️  [IRCService] Mensaje pendiente aún tiene timer activo (delay en curso), ignorando confirmación temprana del servidor');
                      return; // Ignorar la confirmación temprana del servidor
                    } else {
                      // El timer ya se ejecutó o no había timer (envío inmediato), confirmar el mensaje
                      // print('✅ [IRCService] Timer ya ejecutado o sin delay, confirmando mensaje pendiente');
                      final confirmed = confirmPendingMessage(channelKey, messageContent, DateTime.now());
                      if (confirmed) {
                        // print('✅ [IRCService] Mensaje pendiente confirmado, no se añadirá duplicado');
                        return; // Salir temprano para evitar añadir un mensaje duplicado
                      } else {
                        // print('⚠️  [IRCService] No se pudo confirmar el mensaje pendiente, pero es nuestro mensaje, no añadir duplicado');
                        return; // No añadir duplicado aunque no se confirmó
                      }
                    }
                  } else {
                    // print('⚠️  [IRCService] No se encontró mensaje pendiente para confirmar, puede ser un mensaje ya confirmado o de otro usuario');
                    // Si es nuestro mensaje pero no hay pendiente, no añadir duplicado
                    return; // No añadir duplicado
                  }
                } else {
                  // Es un mensaje de otro usuario, añadirlo normalmente
            final msg = IRCMessage(
              nick: nick,
                  channel: channelKey,
              message: messageContent,
              timestamp: DateTime.now(),
              isAction: isAction,
              messageId: IRCMessage.generateMessageId(),
            );
                
                // print('🔍 [DEBUG] ✅ Añadiendo mensaje al canal/query: $channelKey');
                // print('🔍 [DEBUG] ✅ Canal existe en mapa: ${channels.containsKey(channelKey)}');
                channels[channelKey]!.addMessage(msg);
                // print('🔍 [DEBUG] ✅ Mensaje añadido. Total mensajes en canal: ${channels[channelKey]!.messages.length}');
                
                // Guardar en historial local (no bloquear el hilo principal)
                // Usamos el host actual como identificador de servidor
                final serverId = _currentHost ?? 'unknown';
                // Ignorar errores de forma silenciosa dentro del Future
                // para no afectar al flujo de mensajes
                // ignore: unawaited_futures
                ChatHistoryService().saveMessage(
                  server: serverId,
                  message: msg,
                );
                
                // Notificar a los listeners de mensajes
            _notifyMessageListeners(msg);
                }
                // print('🔍 [DEBUG] ✅ Listeners notificados. Total listeners: ${_messageListeners.length}');
                
                // Si es un nuevo canal/query, notificar también a los listeners de lista de usuarios
                // para que el provider se actualice y muestre el nuevo canal en la UI
                if (isNewChannel) {
                  // print('🔍 [DEBUG] 🔄 Nuevo canal/query creado, notificando userListListeners para actualizar UI');
                  _notifyUserListListeners(channelKey);
                }
              } else {
                // print('🔍 [DEBUG] ⚠️  PRIVMSG: No colon found after target');
              }
            } else {
              // print('🔍 [DEBUG] ⚠️  PRIVMSG: PRIVMSG keyword not found in line');
            }
          }
          break;
        
        case 'NOTICE':
          // Los NOTICE de NickServ / bot "nick" se procesan aquí
          if (args.isNotEmpty) {
            var target = args[0];
            final noticeIndex = line.indexOf('NOTICE');
            if (noticeIndex != -1) {
              final targetEndIndex =
                  line.indexOf(target, noticeIndex) + target.length;
              final colonIndex = line.indexOf(':', targetEndIndex);

              if (colonIndex != -1) {
                final messageContent = line.substring(colonIndex + 1).trim();

                // 1) Verificar si es una respuesta de STATUS de NickServ/nick
                // El formato puede ser: STATUS Fran 3 Fran (con el nick repetido al final)
                if ((nick.toLowerCase() == 'nickserv' ||
                        nick.toLowerCase() == 'nick') &&
                    messageContent.contains('STATUS')) {
                  // Buscar el patrón STATUS nick número (puede tener el nick repetido al final)
                  final match =
                      RegExp(r'STATUS\s+(\S+)\s+(\d+)').firstMatch(messageContent);
                  if (match != null) {
                    final checkedNick = match.group(1)!.toLowerCase();
                    final status = int.tryParse(match.group(2)!);
                    // print('📋 [IRCService] Status recibido (NOTICE) para nick "$checkedNick": $status');
                    // print('📋 [IRCService] Mensaje completo: $messageContent');
                    final completer =
                        _statusCheckCompleters.remove(checkedNick);
                    if (completer != null && !completer.isCompleted) {
                      completer.complete(status);
                      // print('✅ [IRCService] Completer completado con status: $status');
                    } else if (completer != null && completer.isCompleted) {
                      // print('⚠️  [IRCService] Completer ya estaba completado para nick: $checkedNick');
                    } else {
                      // print('⚠️  [IRCService] No se encontró completer para nick: $checkedNick');
                    }
                    // No procesar como mensaje normal si es una respuesta de STATUS
                    break;
                  }
                }

                // 2) Capturar NOTICE relacionados con comandos IRCop (como REHASH)
                if (_currentIRCOpCommand != null) {
                  // Verificar si el mensaje está dirigido a nosotros o es un mensaje del servidor
                  final cleanTarget = target.trim();
                  final cleanNickname = _nickname?.trim();
                  final isToUs = cleanNickname != null &&
                      cleanTarget.toLowerCase() == cleanNickname.toLowerCase();
                  final isFromServer = nick.contains('.') || nick == 'GlobalChat' || 
                      nick.toLowerCase().contains('server') || 
                      messageContent.toLowerCase().contains('rehash') ||
                      messageContent.toLowerCase().contains('reload');
                  
                  if (isToUs || isFromServer) {
                    _ircopCommandResults.add(messageContent);
                    // print('📋 [IRCOp] NOTICE capturado para $_currentIRCOpCommand: $messageContent');
                    // Si el mensaje indica que el comando terminó, finalizar inmediatamente
                    if (messageContent.toLowerCase().contains('completed') ||
                        messageContent.toLowerCase().contains('error') ||
                        messageContent.toLowerCase().contains('failed')) {
                      _ircopCommandTimer?.cancel();
                      _notifyIRCOpCommandListeners(_ircopCommandResults);
                      // print('📋 [IRCOp] Fin de $_currentIRCOpCommand (completado)');
                      _ircopCommandResults.clear();
                      _currentIRCOpCommand = null;
                      _currentIRCOpEndCode = null;
                      _ircopCommandTimer = null;
                    }
                    // No procesar como mensaje normal si es parte de un comando IRCop
                    break;
                  }
                }

                // 3) Si es un NOTICE del bot "nick" dirigido a nosotros,
                // mostrarlo en el query privado "nick"
                final cleanTarget = target.trim();
                final cleanNickname = _nickname?.trim();
                if (nick.toLowerCase() == 'nick' &&
                    cleanNickname != null &&
                    cleanTarget.toLowerCase() == cleanNickname.toLowerCase()) {
                  const channelKey = 'nick'; // nombre del query en la UI
                  if (!channels.containsKey(channelKey)) {
                    channels[channelKey] = IRCChannel(name: channelKey);
                  }
                  final msg = IRCMessage(
                    nick: 'nick',
                    channel: channelKey,
                    message: messageContent,
                    timestamp: DateTime.now(),
                  );
                  channels[channelKey]!.addMessage(msg);
                  _notifyMessageListeners(msg);
                  // print('📥 [IRCService] NOTICE del bot "nick" añadido al query: "$messageContent"');
                }
              }
            }
          }
          break;
        
        case 'QUIT':
          // User quit from all channels
          final affectedChannels = <String>[];
          for (var entry in channels.entries) {
            if (entry.value.users.contains(nick)) {
              entry.value.removeUser(nick);
              affectedChannels.add(entry.key);
              
              // Crear mensaje de sistema para cada canal
              final msg = IRCMessage(
                nick: nick,
                channel: entry.key,
                message: 'salió del canal',
                timestamp: DateTime.now(),
                isSystem: true,
              );
              entry.value.addMessage(msg);
              _notifyMessageListeners(msg);
            }
          }
          // Notificar cambios en la lista de usuarios para cada canal afectado
          for (var channel in affectedChannels) {
            _notifyUserListListeners(channel);
          }
          break;
      }
    } catch (e) {
      // print('Error parsing IRC message: $e');
    }
  }

  void _onDisconnect() {
    _stopLagPingTimer();
    _isConnected = false;
    // Resetear el lag al desconectar
    _notifyLagListeners(0); // Notificar lag 0 para resetear
    channels.clear();
    _currentChannel = null;
    _connection = null;
    _currentHost = null;
    for (var listener in _disconnectionListeners) {
      listener();
    }
  }

  void addMessageListener(Function(IRCMessage) listener) {
    _messageListeners.add(listener);
  }

  void removeMessageListener(Function(IRCMessage) listener) {
    _messageListeners.remove(listener);
  }

  void addUserListListener(Function(String) listener) {
    _userListListeners.add(listener);
  }

  void removeUserListListener(Function(String) listener) {
    _userListListeners.remove(listener);
  }

  void addConnectionListener(Function() listener) {
    _connectionListeners.add(listener);
  }

  void addDisconnectionListener(Function() listener) {
    _disconnectionListeners.add(listener);
  }

  void addTopicListener(Function(String) listener) {
    _topicListeners.add(listener);
  }

  void removeTopicListener(Function(String) listener) {
    _topicListeners.remove(listener);
  }

  void addNickChangeListener(Function(String) listener) {
    _nickChangeListeners.add(listener);
  }

  void removeNickChangeListener(Function(String) listener) {
    _nickChangeListeners.remove(listener);
  }

  void addWhoisListener(Function(WhoisInfo) listener) {
    _whoisListeners.add(listener);
  }

  void removeWhoisListener(Function(WhoisInfo) listener) {
    _whoisListeners.remove(listener);
  }

  void addIRCOpListener(Function() listener) {
    _ircopListeners.add(listener);
  }

  void removeIRCOpListener(Function() listener) {
    _ircopListeners.remove(listener);
  }

  WhoisInfo? getWhoisInfo(String nick) {
    return _whoisCache[nick.toLowerCase()];
  }

  void _notifyWhoisListeners(WhoisInfo info) {
    for (var listener in _whoisListeners) {
      listener(info);
    }
  }

  // Listeners para LIST
  void addListListener(Function(List<Map<String, dynamic>>) listener) {
    _listListeners.add(listener);
  }

  void removeListListener(Function(List<Map<String, dynamic>>) listener) {
    _listListeners.remove(listener);
  }

  void _notifyListListeners(List<Map<String, dynamic>> results) {
    for (var listener in _listListeners) {
      listener(results);
    }
  }

  // Listeners para WHO
  void addWhoListener(Function(List<Map<String, dynamic>>) listener) {
    _whoListeners.add(listener);
  }

  void removeWhoListener(Function(List<Map<String, dynamic>>) listener) {
    _whoListeners.remove(listener);
  }

  void _notifyWhoListeners(List<Map<String, dynamic>> results) {
    for (var listener in _whoListeners) {
      listener(results);
    }
  }

  // Listeners para comandos IRCop
  void addIRCOpCommandListener(Function(List<String>) listener) {
    _ircopCommandListeners.add(listener);
  }

  void removeIRCOpCommandListener(Function(List<String>) listener) {
    _ircopCommandListeners.remove(listener);
  }

  void _notifyIRCOpCommandListeners(List<String> results) {
    for (var listener in _ircopCommandListeners) {
      listener(results);
    }
  }

  void addLagListener(Function(int) listener) {
    _lagListeners.add(listener);
  }

  void removeLagListener(Function(int) listener) {
    _lagListeners.remove(listener);
  }

  void _notifyLagListeners(int lagMs) {
    for (var listener in _lagListeners) {
      try {
        listener(lagMs);
      } catch (e) {
        // print('❌ Error notificando lag listener: $e');
      }
    }
  }

  void _startLagPingTimer() {
    _lagPingTimer?.cancel();
    
    // Enviar un PING inmediatamente al conectar
    if (_isConnected && _hasActiveConnection) {
      _lastPingToken = DateTime.now().millisecondsSinceEpoch.toString();
      _lastPingSent = DateTime.now();
      _sendCommand('PING $_lastPingToken');
      // print('📊 [IRCService] Enviando PING inicial para medir lag: $_lastPingToken');
    }
    
    // Enviar PING cada 3 segundos para medición en tiempo real
    _lagPingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isConnected && _hasActiveConnection) {
        // Solo enviar si no hay un PING pendiente (evitar spam)
        if (_lastPingSent == null || DateTime.now().difference(_lastPingSent!).inSeconds > 2) {
          // Generar un token único para este PING
          _lastPingToken = DateTime.now().millisecondsSinceEpoch.toString();
          _lastPingSent = DateTime.now();
          _sendCommand('PING $_lastPingToken');
          // print('📊 [IRCService] Enviando PING para medir lag: $_lastPingToken');
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _stopLagPingTimer() {
    _lagPingTimer?.cancel();
    _lagPingTimer = null;
    _lastPingSent = null;
    _lastPingToken = null;
  }

  void _notifyMessageListeners(IRCMessage message) {
    for (var listener in _messageListeners) {
      listener(message);
    }
  }

  void _notifyUserListListeners(String channel) {
    // print('🔔 _notifyUserListListeners: channel=$channel, listeners=${_userListListeners.length}');
    for (var listener in _userListListeners) {
      listener(channel);
    }
  }

  void _notifyTopicListeners(String channel) {
    // print('🔔 _notifyTopicListeners: channel=$channel, listeners=${_topicListeners.length}');
    for (var listener in _topicListeners) {
      listener(channel);
    }
  }
  
  // Editar un mensaje propio
  bool editMessage(String channel, String messageId, String newMessage) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return false;
    
    final channelObj = channels[normalized]!;
    final messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId && msg.nick == _nickname,
    );
    
    if (messageIndex == -1) return false;
    
    final oldMessage = channelObj.messages[messageIndex];
    
    // Si el mensaje está pendiente, actualizar el mensaje que se enviará
    if (oldMessage.isPending && oldMessage.pendingId != null) {
      final pendingId = oldMessage.pendingId!;
      
      // Verificar si el mensaje ya fue enviado (timer ya ejecutado o fue forzado)
      final hasActiveTimer = _pendingMessageTimers.containsKey(pendingId);
      
      // Cancelar el timer anterior si existe
      final oldTimer = _pendingMessageTimers.remove(pendingId);
      if (oldTimer != null) {
        oldTimer.cancel();
        // print('⏱️  [IRCService] Timer cancelado para editar mensaje pendiente: $pendingId');
      }
      
      // Actualizar el mensaje pendiente con el nuevo contenido
      // IMPORTANTE: Si el mensaje ya fue enviado (fuerza envío), eliminar el delaySeconds
      // para que no se cree un nuevo timer cuando se edite
      final updatedMessage = oldMessage.copyWith(
        message: newMessage,
        isEdited: true,
        editedAt: DateTime.now(),
        delaySeconds: hasActiveTimer ? oldMessage.delaySeconds : null, // Si ya fue enviado, quitar delay
      );
      channelObj.messages[messageIndex] = updatedMessage;
      _notifyMessageListeners(updatedMessage);
      
      // Si el mensaje ya fue enviado (no tenía timer activo), enviar el nuevo contenido inmediatamente
      // Esto ocurre cuando se fuerza el envío y luego se edita
      if (!hasActiveTimer) {
        // El mensaje ya fue enviado, pero ahora tiene contenido nuevo, enviarlo inmediatamente
        // print('📤 [IRCService] Mensaje ya fue enviado (fuerza envío), enviando contenido editado inmediatamente');
        final lines = newMessage.split('\n');
        for (var line in lines) {
          line = line.trim();
          if (line.isNotEmpty) {
            // print('📤 [IRCService] Enviando línea editada: $line');
            _sendCommand('PRIVMSG $normalized :$line');
          }
        }
        // print('✅ [IRCService] Mensaje editado enviado inmediatamente (mensaje ya estaba enviado)');
        
        // Auto-confirmar después de 500ms si el servidor no hace eco
        Timer(const Duration(milliseconds: 500), () {
          final channelObj = channels[normalized];
          if (channelObj != null) {
            final currentPendingMessages = channelObj.messages.where((m) => m.isPending && m.pendingId == pendingId).toList();
            if (currentPendingMessages.isNotEmpty) {
              // print('⚠️  [IRCService] Mensaje editado (forzado) $pendingId aún pendiente después de 500ms, auto-confirmando.');
              confirmPendingMessage(normalized, newMessage, DateTime.now());
            }
          }
        });
      } else {
        // El mensaje aún tiene timer activo, crear un nuevo timer con el contenido editado
        // Si hay un delay configurado, crear un nuevo timer con el mensaje actualizado
        if (updatedMessage.delaySeconds != null && updatedMessage.delaySeconds! > 0) {
          final delaySeconds = updatedMessage.delaySeconds!;
          // print('⏱️  [IRCService] Programando envío de mensaje editado $pendingId en ${delaySeconds}s');
          final timer = Timer(Duration(seconds: delaySeconds), () {
            // print('⏱️  [IRCService] Timer ejecutado, enviando mensaje editado $pendingId');
            final lines = newMessage.split('\n');
            for (var line in lines) {
              line = line.trim();
              if (line.isNotEmpty) {
                // print('📤 [IRCService] Enviando línea editada: $line');
                _sendCommand('PRIVMSG $normalized :$line');
              }
            }
            // print('📤 [IRCService] Mensaje editado enviado al servidor después de delay: $pendingId');
            _pendingMessageTimers.remove(pendingId);
            
            // Auto-confirmar después de 500ms si el servidor no hace eco
            Timer(const Duration(milliseconds: 500), () {
              final channelObj = channels[normalized];
              if (channelObj != null) {
                final currentPendingMessages = channelObj.messages.where((m) => m.isPending && m.pendingId == pendingId).toList();
                if (currentPendingMessages.isNotEmpty) {
                  // print('⚠️  [IRCService] Mensaje editado con delay $pendingId aún pendiente después de 500ms, auto-confirmando.');
                  confirmPendingMessage(normalized, newMessage, DateTime.now());
                }
              }
            });
          });
          _pendingMessageTimers[pendingId] = timer;
          // print('✅ [IRCService] Timer creado para mensaje editado, se enviará en ${delaySeconds}s');
        } else {
          // Sin delay, enviar inmediatamente
          // print('📤 [IRCService] Enviando mensaje editado inmediatamente (sin delay)');
          final lines = newMessage.split('\n');
          for (var line in lines) {
            line = line.trim();
            if (line.isNotEmpty) {
              // print('📤 [IRCService] Enviando línea editada: $line');
              _sendCommand('PRIVMSG $normalized :$line');
            }
          }
          // print('✅ [IRCService] Mensaje editado enviado inmediatamente');
          
          // Auto-confirmar después de 500ms si el servidor no hace eco
          Timer(const Duration(milliseconds: 500), () {
            final channelObj = channels[normalized];
            if (channelObj != null) {
              final currentPendingMessages = channelObj.messages.where((m) => m.isPending && m.pendingId == pendingId).toList();
              if (currentPendingMessages.isNotEmpty) {
                // print('⚠️  [IRCService] Mensaje editado sin delay $pendingId aún pendiente después de 500ms, auto-confirmando.');
                confirmPendingMessage(normalized, newMessage, DateTime.now());
              }
            }
          });
        }
      }
      
      // print('✏️  [IRCService] Mensaje pendiente editado: $messageId en $normalized');
      return true;
    } else {
      // Mensaje ya enviado, solo actualizar el contenido localmente
      final updatedMessage = oldMessage.copyWith(
        message: newMessage,
        isEdited: true,
        editedAt: DateTime.now(),
      );
      
      channelObj.messages[messageIndex] = updatedMessage;
      _notifyMessageListeners(updatedMessage);
      
      // Enviar comando de edición al servidor (si el servidor lo soporta)
      // Nota: IRC no tiene un comando estándar para editar mensajes
      // Esto es una funcionalidad del cliente
      // print('✏️  [IRCService] Mensaje confirmado editado: $messageId en $normalized');
      return true;
    }
  }
  
  // Añadir o quitar una reacción a un mensaje
  bool toggleReaction(String channel, String messageId, String emoji) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return false;
    
    final channelObj = channels[normalized]!;
    final messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId,
    );
    
    if (messageIndex == -1) return false;
    
    final oldMessage = channelObj.messages[messageIndex];
    final currentReactions = Map<String, int>.from(oldMessage.reactions);
    
    // Toggle: si existe, incrementar; si no, añadir con 1
    if (currentReactions.containsKey(emoji)) {
      currentReactions[emoji] = (currentReactions[emoji] ?? 0) + 1;
    } else {
      currentReactions[emoji] = 1;
    }
    
    final updatedMessage = oldMessage.copyWith(reactions: currentReactions);
    channelObj.messages[messageIndex] = updatedMessage;
    _notifyMessageListeners(updatedMessage);
    
    // print('👍 [IRCService] Reacción añadida: $emoji a mensaje $messageId');
    return true;
  }
  
  // Responder a un mensaje específico
  void replyToMessage(String channel, String replyToMessageId, String message, {int delaySeconds = 0}) {
    final normalized = _normalizeChannelName(channel);
    
    // Enviar el mensaje directamente con la referencia al mensaje original
    sendMessage(normalized, message, delaySeconds: delaySeconds, replyToMessageId: replyToMessageId);
    
    // print('💬 [IRCService] Respondiendo a mensaje $replyToMessageId en $normalized');
  }
  
  // Obtener un mensaje por su ID
  IRCMessage? getMessageById(String channel, String messageId) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return null;
    
    try {
      return channels[normalized]!.messages.firstWhere(
        (msg) => msg.messageId == messageId,
      );
    } catch (e) {
      return null;
    }
  }
}
