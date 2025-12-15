import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/irc_message.dart';
import 'chat_history_service.dart';
import '../models/whois_info.dart';
import '../utils/irc_color_parser.dart';

class IRCService {
  Socket? _socket;
  SecureSocket? _secureSocket;
  String? _nickname;
  String? _currentChannel;
  Map<String, IRCChannel> channels = {};
  final List<Function(IRCMessage)> _messageListeners = [];
  final List<Function(String)> _userListListeners = [];
  final List<Function(String)> _topicListeners = [];
  final List<Function()> _connectionListeners = [];
  final List<Function()> _disconnectionListeners = [];
  final List<Function(WhoisInfo)> _whoisListeners = [];
  Map<String, WhoisInfo> _whoisCache = {};
  Map<String, WhoisInfo> _pendingWhois = {}; // Para acumular información de whois
  final Set<String> _ignoredUsers = {}; // Lista de usuarios ignorados (en minúsculas)
  StreamSubscription? _socketSubscription;
  late Completer<void> _connectionCompleter;
  bool _isConnected = false;
  bool _isRegistered = false; // Indica si el usuario está completamente registrado (recibió 001)
  bool _useSSL = false;

  bool get isConnected => _isConnected;
  String? get currentChannel => _currentChannel;
  String? get nickname => _nickname;
  Map<String, IRCChannel> get allChannels => channels;
  
  bool get _hasActiveSocket => _socket != null || _secureSocket != null;

  String _currentServerId(String host, int port) => '$host:$port${_useSSL ? ':ssl' : ''}';

  Future<void> connect({
    required String host,
    required int port,
    required String nickname,
    bool useSSL = false,
  }) async {
    try {
      _useSSL = useSSL;
      print('📡 [IRCService.connect] Connecting to $host:$port as $nickname (SSL: $useSSL)');
      _nickname = nickname;
      _isRegistered = false; // Reset registration status
      _connectionCompleter = Completer<void>(); // Reinicializar el completer
      
      // Connect to the server with timeout
      if (useSSL) {
        // Usar SecureSocket para conexiones SSL/TLS
        final context = SecurityContext.defaultContext;
        try {
          _secureSocket = await SecureSocket.connect(
            host,
            port,
            context: context,
            timeout: const Duration(seconds: 15),
            onBadCertificate: (X509Certificate cert) {
              // Aceptar certificados autofirmados o con problemas
              // En producción, deberías validar el certificado adecuadamente
              print('⚠️ [IRCService] Certificate warning: ${cert.subject}');
              print('⚠️ [IRCService] Accepting certificate anyway');
              return true; // Aceptar el certificado
            },
          );
          print('✅ [IRCService] SecureSocket connected (SSL/TLS)');
        } catch (e) {
          print('❌ [IRCService] SSL connection error: $e');
          print('❌ [IRCService] Error type: ${e.runtimeType}');
          rethrow;
        }
        
        // Start listening to incoming data (non-blocking)
        _socketSubscription = _secureSocket!.listen(
          (List<int> event) {
            // Decodificar como UTF-8 para soportar emoticonos y caracteres especiales
            String data = utf8.decode(event, allowMalformed: true);
            _handleData(data);
          },
          onDone: () {
            print('⛔ [IRCService] SecureSocket closed');
            _onDisconnect();
          },
          onError: (error) {
            print('❌ [IRCService] SecureSocket error: $error');
            _onDisconnect();
          },
        );
      } else {
        // Usar Socket normal para conexiones no seguras
        _socket = await Socket.connect(host, port,
            timeout: const Duration(seconds: 10));
        print('✅ [IRCService] Socket connected');
        
        // Start listening to incoming data (non-blocking)
        _socketSubscription = _socket!.listen(
          (List<int> event) {
            // Decodificar como UTF-8 para soportar emoticonos y caracteres especiales
            String data = utf8.decode(event, allowMalformed: true);
            _handleData(data);
          },
          onDone: () {
            print('⛔ [IRCService] Socket closed');
            _onDisconnect();
          },
          onError: (error) {
            print('❌ [IRCService] Socket error: $error');
            _onDisconnect();
          },
        );
      }
      
      // Send initial IRC commands
      _sendCommand('NICK $nickname');
      _sendCommand('USER $nickname 0 * :$nickname');
      
      print('✅ [IRCService] Commands sent');
      print('✅ [IRCService] Listener registered');
      
      // Set connection as established
      _isConnected = true;
      
      // Notify listeners
      print('📢 [IRCService] Notifying listeners');
      for (var listener in _connectionListeners) {
        listener();
      }
      
      print('✅ [IRCService.connect] Connection completed and returned');
    } catch (e) {
      print('❌ [IRCService] Fatal connection error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  void disconnect() {
    if (_useSSL && _secureSocket != null) {
      _sendCommand('QUIT :Goodbye');
      _socketSubscription?.cancel();
      _secureSocket?.close();
      _secureSocket = null;
      _isConnected = false;
    } else if (_socket != null) {
      _sendCommand('QUIT :Goodbye');
      _socketSubscription?.cancel();
      _socket?.close();
      _socket = null;
      _isConnected = false;
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
      print('🔍 [DEBUG] ⚠️  Invalid channel name after normalization: "$normalized" (original: "$channelName")');
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
    
    print('🔍 [DEBUG] joinChannel called with: "$channelName" -> normalized: "$normalized"');
    print('🔍 [DEBUG] User registered status: $_isRegistered');
    
    // Si el usuario no está registrado todavía, esperar un poco más
    if (!_isRegistered) {
      print('🔍 [DEBUG] ⚠️  User not registered yet, waiting for 001 message...');
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (_isRegistered) {
          print('🔍 [DEBUG] ✅ User now registered, joining channel');
          _doJoinChannel(normalized);
        } else {
          print('🔍 [DEBUG] ⚠️  Still not registered, trying anyway...');
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
      print('🔍 [DEBUG] Created new channel entry: $normalized');
    } else {
      print('🔍 [DEBUG] Channel already exists: $normalized');
    }
    
    // Solicitar la lista de usuarios y el TOPIC después de unirse
    // Usar múltiples intentos para asegurar que se reciba la lista
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isConnected && _hasActiveSocket) {
        print('🔍 [DEBUG] Requesting NAMES for $normalized (first attempt)');
        _sendCommand('NAMES $normalized');
        print('🔍 [DEBUG] Requesting TOPIC for $normalized (first attempt)');
        _sendCommand('TOPIC $normalized');
      }
    });
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isConnected && _hasActiveSocket) {
        print('🔍 [DEBUG] Requesting NAMES for $normalized (second attempt)');
        _sendCommand('NAMES $normalized');
        print('🔍 [DEBUG] Requesting TOPIC for $normalized (second attempt)');
        _sendCommand('TOPIC $normalized');
      }
    });
    
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (_isConnected && _hasActiveSocket) {
        print('🔍 [DEBUG] Requesting NAMES for $normalized (third attempt)');
        _sendCommand('NAMES $normalized');
        print('🔍 [DEBUG] Requesting TOPIC for $normalized (third attempt)');
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

  void sendMessage(String channel, String message) {
    // Normalizar el nombre del canal
    final normalized = _normalizeChannelName(channel);
    
    // Dividir el mensaje en líneas y enviar cada línea como un PRIVMSG separado
    // pero mostrar el mensaje completo en la UI
    final lines = message.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
        _sendCommand('PRIVMSG $normalized :$line');
      }
    }
    
    // Add to local channel (el mensaje completo, no dividido)
    if (channels.containsKey(normalized)) {
      final msg = IRCMessage(
        nick: _nickname ?? 'You',
        channel: normalized,
        message: message, // Mensaje completo con saltos de línea
        timestamp: DateTime.now(),
      );
      channels[normalized]!.addMessage(msg);
      _notifyMessageListeners(msg);
    }
  }

  // Enviar mensaje privado a un servicio IRC (NickServ, ChanServ, HostServ, etc.)
  void sendServiceMessage(String service, String message) {
    // Los servicios IRC no usan #, solo el nombre del servicio
    final serviceName = service.trim();
    _sendCommand('PRIVMSG $serviceName :$message');
    print('📤 [IRCService] Enviando mensaje a servicio $serviceName: $message');
  }

  // Enviar mensaje privado a un nick (query)
  void sendWhois(String nick) {
    _sendCommand('WHOIS $nick');
  }

  void sendIgnore(String nick) {
    final normalizedNick = nick.trim().toLowerCase();
    if (normalizedNick.isEmpty) return;
    
    // Añadir a la lista local de ignorados
    _ignoredUsers.add(normalizedNick);
    print('🚫 [IRCService] Usuario añadido a lista de ignorados: $normalizedNick');
    
    _sendCommand('MODE $nick +b'); // Ignorar usando modo ban (depende del servidor IRC)
    // Alternativa: algunos servidores usan /ignore directamente
    _sendCommand('IGNORE $nick');
  }

  void sendUnignore(String nick) {
    final normalizedNick = nick.trim().toLowerCase();
    if (normalizedNick.isEmpty) return;
    
    // Remover de la lista local de ignorados
    _ignoredUsers.remove(normalizedNick);
    print('✅ [IRCService] Usuario removido de lista de ignorados: $normalizedNick');
    
    _sendCommand('MODE $nick -b'); // Designorar usando modo ban
    // Alternativa: algunos servidores usan /unignore directamente
    _sendCommand('UNIGNORE $nick');
  }
  
  bool isUserIgnored(String nick) {
    return _ignoredUsers.contains(nick.toLowerCase());
  }

  void sendPrivateMessage(String nick, String message) {
    final normalizedNick = nick.trim();
    if (normalizedNick.isEmpty) return;
    
    // Crear un canal privado si no existe (los queries usan el nick como "canal")
    final queryChannel = normalizedNick.toLowerCase();
    if (!channels.containsKey(queryChannel)) {
      channels[queryChannel] = IRCChannel(name: queryChannel);
      print('📤 [IRCService] Creado canal privado para: $queryChannel');
    }
    
    // Enviar el mensaje
    final lines = message.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
        _sendCommand('PRIVMSG $normalizedNick :$line');
      }
    }
    
    // Agregar el mensaje al canal privado local
    final msg = IRCMessage(
      nick: _nickname ?? 'You',
      channel: queryChannel,
      message: message,
      timestamp: DateTime.now(),
    );
    channels[queryChannel]!.addMessage(msg);
    _notifyMessageListeners(msg);
    
    print('📤 [IRCService] Mensaje privado enviado a $normalizedNick: $message');
  }

  void _sendCommand(String command) {
    if (_useSSL && _secureSocket != null) {
      print('🔍 [DEBUG] Sending command (SSL): $command');
      _secureSocket!.writeln(command);
    } else if (_socket != null) {
      print('🔍 [DEBUG] Sending command: $command');
      _socket!.writeln(command);
    } else {
      print('🔍 [DEBUG] ⚠️  Cannot send command "$command": socket is null');
    }
  }

  void _handleData(String rawData) {
    final lines = rawData.split('\r\n');
    
    for (var line in lines) {
      if (line.isEmpty) continue;
      print('IRC >> $line');
      
      // Log especial para comandos JOIN, 353, 366, 332 (TOPIC)
      if (line.contains(' JOIN ') || line.contains(' 353 ') || line.contains(' 366 ') || line.contains(' 332 ')) {
        print('🔍 [DEBUG] ⭐ Important IRC message: $line');
      }
      
      // Log específico para TOPIC
      if (line.contains(' 332 ')) {
        print('🔍 [DEBUG] 📌📌📌 RAW TOPIC MESSAGE RECEIVED: $line');
        print('🔍 [DEBUG] 📌📌📌 Full raw line length: ${line.length}');
        print('🔍 [DEBUG] 📌📌📌 Line bytes: ${line.codeUnits}');
      }
      
      _parseIRCMessage(line);
    }
  }

  void _parseIRCMessage(String line) {
    if (line.startsWith('PING')) {
      _sendCommand('PONG ${line.substring(5)}');
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
        print('🔍 [DEBUG] Received numeric command: $command (line: $line)');
        // Log específico para comandos whois
        if (['311', '312', '313', '317', '318', '319', '301'].contains(command)) {
          print('🔍 [WHOIS DEBUG] Command: $command, Args: $args');
        }
      }
      
      // Log si el mensaje contiene nuestro nickname
      if (_nickname != null && line.contains(_nickname!)) {
        print('🔍 [DEBUG] ⭐ Message contains our nickname "$_nickname": $line');
      }

      switch (command) {
        case '001': // Welcome
          print('✅ Welcome message received - connected as $nick');
          print('🔍 [DEBUG] ✅✅✅ User is now fully registered! Ready for JOIN commands ✅✅✅');
          _isRegistered = true; // Marcar que el usuario está registrado
          if (!_connectionCompleter.isCompleted) {
            _connectionCompleter.complete();
          }
          break;
        
        case '332': // TOPIC
          print('🔍 [DEBUG] 📌📌📌 TOPIC command received! Raw line: $line');
          print('🔍 [DEBUG] 📌📌📌 Full line breakdown:');
          print('🔍 [DEBUG] 📌📌📌   - Line length: ${line.length}');
          print('🔍 [DEBUG] 📌📌📌   - Parts count: ${parts.length}');
          print('🔍 [DEBUG] 📌📌📌   - Args count: ${args.length}');
          print('🔍 [DEBUG] 📌📌📌   - Args: $args');
          print('🔍 [DEBUG] 📌📌📌   - Source: $source');
          print('🔍 [DEBUG] 📌📌📌   - Command: $command');
          
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
            
            print('🔍 [DEBUG] 📌📌📌 Potential channel from args: "$potentialChannel"');
            // Guardar el canal original antes de normalizar para buscarlo en la línea
            final originalChannelInLine = potentialChannel;
            channel = _normalizeChannelName(potentialChannel);
            print('🔍 [DEBUG] 📌📌📌 Normalized channel: "$channel"');
            
            // Extraer el topic: el formato es :server 332 nick #channel :topic
            // Necesitamos encontrar el ':' que viene después del nombre del canal
            // Buscar el canal ORIGINAL (sin normalizar) en la línea y luego el ':' que viene después
            final channelIndex = line.indexOf(originalChannelInLine);
            if (channelIndex != -1) {
              // Buscar el ':' que viene después del nombre del canal
              final colonIndex = line.indexOf(':', channelIndex + originalChannelInLine.length);
              print('🔍 [DEBUG] 📌📌📌 Channel index: $channelIndex, Colon index after channel: $colonIndex');
              
              if (colonIndex != -1 && colonIndex < line.length - 1) {
                final rawTopic = line.substring(colonIndex + 1).trim();
                // Limpiar códigos de formato IRC (colores, subrayado, etc.) para que se vean bien en el topic
                topicText = IRCColorParser.stripIRCFormatting(rawTopic);
                print('🔍 [DEBUG] 📌📌📌 Topic text extracted (raw): "$rawTopic"');
                print('🔍 [DEBUG] 📌📌📌 Topic text cleaned: "$topicText"');
                print('🔍 [DEBUG] 📌📌📌 Topic text length: ${topicText.length}');
              } else {
                print('🔍 [DEBUG] 📌📌📌 ⚠️  No colon found after channel name');
              }
            } else {
              print('🔍 [DEBUG] 📌📌📌 ⚠️  Channel not found in line (searched for: "$originalChannelInLine")');
            }
          }
          
          if (channel != null && channel.startsWith('#')) {
            // Usar una variable local no-nullable para evitar problemas de tipos
            String finalChannel = channel;
            
            // Buscar el canal en el mapa (case-insensitive)
            String? actualChannelKey = finalChannel;
            if (!channels.containsKey(finalChannel)) {
              print('🔍 [DEBUG] 📌📌📌 Channel "$finalChannel" not found, searching case-insensitive...');
              print('🔍 [DEBUG] 📌📌📌 Available channels: ${channels.keys.toList()}');
              // Buscar case-insensitive
              for (var existingKey in channels.keys) {
                if (existingKey.toLowerCase() == finalChannel.toLowerCase()) {
                  actualChannelKey = existingKey;
                  finalChannel = existingKey;
                  print('🔍 [DEBUG] 📌📌📌 Found channel case-insensitive: "$finalChannel"');
                  break;
                }
              }
            }
            
            // Si el canal existe, actualizar el topic
            if (channels.containsKey(finalChannel)) {
              if (topicText != null) {
                channels[finalChannel]!.setTopic(topicText);
                print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic set for existing channel: $finalChannel');
                print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic value: "${channels[finalChannel]!.topic}"');
              } else {
                // Si no hay topic, establecer como vacío
                channels[finalChannel]!.setTopic('');
                print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic cleared for channel: $finalChannel');
              }
              // Notificar cambio de topic
              _notifyTopicListeners(finalChannel);
              print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic listeners notified');
            } else {
              // Crear el canal si no existe
              channels[finalChannel] = IRCChannel(name: finalChannel, topic: topicText ?? '');
              print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic set for new channel: $finalChannel');
              print('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic value: "${channels[finalChannel]!.topic}"');
              _notifyTopicListeners(finalChannel);
            }
          } else {
            print('🔍 [DEBUG] 📌📌📌 ⚠️  ⚠️  ⚠️  Invalid channel in TOPIC command: $channel');
            print('🔍 [DEBUG] 📌📌📌 ⚠️  ⚠️  ⚠️  Full line for inspection: $line');
          }
          break;
        
        case '433': // Nickname in use - try alternative
          if (_nickname != null && !_nickname!.endsWith('_')) {
            final newNick = '${_nickname}_';
            _nickname = newNick;
            _sendCommand('NICK $newNick');
          }
          break;
        
        case '353': // Names reply (users in channel)
          print('🔍 [DEBUG] 📋 Received user list (353) from server');
          print('🔍 [DEBUG] Raw line: $line');
          if (args.length >= 3) {
            // Format: 353 nick = #channel :user1 user2 user3
            final channelPrivacy = args[1]; // '=' for public
            var channel = args[2]; // The actual channel name
            
            print('🔍 [DEBUG] Original channel from args[2]: "$channel"');
            print('🔍 [DEBUG] All args: $args');
            
            // Normalizar el nombre del canal primero
            final originalChannel = channel;
            channel = _normalizeChannelName(channel);
            
            print('🔍 [DEBUG] Normalized channel: "$channel" (from "$originalChannel")');
            
            // Validación adicional: si todavía tiene problemas, intentar extraer del mensaje completo
            if (channel.contains(':#') || channel.startsWith(':#')) {
              print('🔍 [DEBUG] ⚠️  Channel still has issues, trying to extract from full line');
              // Intentar extraer el canal del formato completo
              final match = RegExp(r'353\s+\S+\s+=\s+(#\S+)').firstMatch(line);
              if (match != null) {
                channel = _normalizeChannelName(match.group(1)!);
                print('🔍 [DEBUG] Extracted channel from regex: "$channel"');
              }
            }
            
            print('🔍 [DEBUG] Final normalized channel: "$channel"');
            print('🔍 [DEBUG] All current channels in map: ${channels.keys.toList()}');
            
            // Solo procesar si es un canal válido (empieza con #)
            if (!channel.startsWith('#')) {
              print('🔍 [DEBUG] ⚠️  Invalid channel name (doesn\'t start with #): $channel');
              break;
            }
            
            // Validación CRÍTICA: el canal NO debe ser igual al nickname (con o sin #)
            // Esto evita crear canales como #flutteruser cuando el nickname es FlutterUser
            if (_nickname != null) {
              final normalizedNick = _nickname!.toLowerCase();
              final channelWithoutHash = channel.toLowerCase().replaceFirst('#', '');
              
              // Verificar si el canal es igual al nickname (con o sin #)
              if (channelWithoutHash == normalizedNick || 
                  channel.toLowerCase() == '#$normalizedNick' ||
                  originalChannel.toLowerCase() == normalizedNick) {
                print('🔍 [DEBUG] ⚠️  ⚠️  ⚠️  BLOCKING 353: channel "$channel" matches nickname "$_nickname" - SKIPPING');
                break;
              }
            }
            
            // Si el canal no existe con el nombre exacto, buscar por nombre normalizado (case-insensitive)
            // Esto es importante porque el servidor puede devolver el nombre con diferente capitalización
            String? actualChannelKey = channel;
            if (!channels.containsKey(channel)) {
              print('🔍 [DEBUG] ⚠️  Channel "$channel" not found with exact name, searching case-insensitive...');
              print('🔍 [DEBUG] Available channels: ${channels.keys.map((k) => '"$k"').join(", ")}');
              
              // Buscar el canal con el mismo nombre normalizado
              for (var existingKey in channels.keys) {
                if (existingKey.toLowerCase() == channel.toLowerCase()) {
                  actualChannelKey = existingKey;
                  print('🔍 [DEBUG] ✅ Found matching channel: "$existingKey" (normalized matches "$channel")');
                  channel = existingKey; // Usar el nombre que realmente existe en el mapa
                  break;
                }
              }
              
              if (actualChannelKey == channel && !channels.containsKey(channel)) {
                print('🔍 [DEBUG] ⚠️  Channel not found even with case-insensitive search, will create new: $channel');
              }
            } else {
              print('🔍 [DEBUG] ✅ Channel found with exact name: $channel');
            }
            
            // Find the position of ':' to get the users list
            final colonIndex = line.indexOf(':');
            if (colonIndex != -1) {
              final usersList = line.substring(colonIndex + 1).trim();
              final users = usersList.split(' ').where((u) => u.isNotEmpty).toList();
              
              print('🔍 [DEBUG] Channel: $channel (privacy: $channelPrivacy)');
              print('🔍 [DEBUG] Raw users string: "$usersList"');
              print('🔍 [DEBUG] Parsed users count: ${users.length}');
              print('🔍 [DEBUG] Parsed users list: $users');
              
              // Create channel if it doesn't exist (usar nombre normalizado)
              if (!channels.containsKey(channel)) {
                print('🔍 [DEBUG] ℹ️  Channel not in map, creating it: $channel');
                channels[channel] = IRCChannel(name: channel);
              } else {
                print('🔍 [DEBUG] ✅ Channel already exists: $channel');
                print('🔍 [DEBUG] Current users in channel before update: ${channels[channel]!.users}');
              }
              
              int addedCount = 0;
              int updatedCount = 0;
              // Agregar usuarios a la lista (addUser ya verifica duplicados)
              for (var user in users) {
                // Extraer el prefijo de modo IRC antes de limpiar
                String? userMode;
                String cleanUser = user.trim();
                
                // Detectar prefijos IRC: @ (op), + (voice), % (halfop), & (founder/owner)
                if (cleanUser.startsWith('@')) {
                  userMode = '@';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith('&')) {
                  userMode = '&';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith('%')) {
                  userMode = '%';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith('+')) {
                  userMode = '+';
                  cleanUser = cleanUser.substring(1).trim();
                } else if (cleanUser.startsWith(':')) {
                  cleanUser = cleanUser.substring(1).trim();
                }
                
                print('🔍 [DEBUG] Processing user: "$user" -> mode: "$userMode", cleaned: "$cleanUser"');
                
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
                  // Si el usuario ya existe, actualizar su modo
                  if (channels[channel]!.users.contains(cleanUser)) {
                    if (userMode != null) {
                      channels[channel]!.addUser(cleanUser, mode: userMode);
                      updatedCount++;
                      print('🔍 [DEBUG] ✅ Updated mode for existing user: "$cleanUser" -> "$userMode"');
                    } else {
                      // Si no tiene modo en la lista actual, mantener el modo existente si lo tiene
                      final existingMode = channels[channel]!.getUserMode(cleanUser);
                      if (existingMode != null) {
                        print('🔍 [DEBUG] ℹ️  Keeping existing mode for user: "$cleanUser" -> "$existingMode"');
                      }
                    }
                  } else {
                    print('🔍 [DEBUG] ➕ Adding new user: "$cleanUser" with mode: "$userMode"');
                    channels[channel]!.addUser(cleanUser, mode: userMode);
                    addedCount++;
                  }
                } else {
                  if (isServerHost) {
                    print('🔍 [DEBUG] ❌ Skipping server/host name: "$cleanUser"');
                  } else {
                    print('🔍 [DEBUG] ❌ Skipping invalid user: "$cleanUser"');
                  }
                }
              }
              
              print('🔍 [DEBUG] Added $addedCount new users, updated $updatedCount existing users');
              print('🔍 [DEBUG] Total users in channel now: ${channels[channel]!.users.length}');
              print('🔍 [DEBUG] Users list: ${channels[channel]!.users}');
              // Debug: mostrar modos de todos los usuarios
              for (var u in channels[channel]!.users) {
                final mode = channels[channel]!.getUserMode(u);
                if (mode != null) {
                  print('🔍 [DEBUG] User "$u" has mode: "$mode"');
                }
              }
              
              // Notificar que la lista de usuarios se actualizó
              print('🔍 [DEBUG] Notifying user list listeners for channel: $channel');
              _notifyUserListListeners(channel);
              print('🔍 [DEBUG] ✅ User list updated for $channel with ${channels[channel]!.users.length} users');
            } else {
              print('🔍 [DEBUG] ⚠️  No colon found in line, cannot parse users');
            }
          } else {
            print('🔍 [DEBUG] ⚠️  Not enough args in 353 command: ${args.length}');
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
              print('  ✅ Final user count for $channel: ${channels[channel]!.users.length}');
            }
          }
          break;
        
        case 'JOIN':
          print('🔍 [DEBUG] ⭐ JOIN command received! Full line: $line');
          print('🔍 [DEBUG] JOIN - args: $args, nick from source: "$nick", our nickname: "$_nickname"');
          
          if (args.isNotEmpty) {
            var channel = args[0];
            print('🔍 [DEBUG] JOIN - raw channel from args[0]: "$channel"');
            channel = _normalizeChannelName(channel);
            print('🔍 [DEBUG] JOIN - normalized channel: "$channel"');
            
            // Solo procesar si es un canal válido
            if (!channel.startsWith('#')) {
              print('🔍 [DEBUG] ⚠️  Invalid channel name in JOIN: $channel');
              break;
            }
            
            if (!channels.containsKey(channel)) {
              channels[channel] = IRCChannel(name: channel);
              print('🔍 [DEBUG] Created channel entry for JOIN: $channel');
            }
            
            // Validar que el nick no sea un servidor/host antes de agregarlo
            final isServerHost = nick.contains('.') && 
                (nick.split('.').length > 2 || // Múltiples puntos (ej: ceres.globalchat.org)
                 RegExp(r'\.(org|com|net|edu|gov|io|co|uk|de|fr|es|it|nl|be|ch|at|se|no|dk|fi|pl|cz|sk|hu|ro|bg|gr|pt|ie|lu|mt|cy|ee|lv|lt|si|hr|rs|ba|mk|al|me|is|li|ad|mc|sm|va|by|ua|md|ge|am|az|kz|uz|tm|tj|kg|mn|cn|jp|kr|in|au|nz|za|br|mx|ar|cl|co|pe|ve|ec|uy|py|bo|cr|pa|do|gt|hn|ni|sv|bz|jm|tt|bb|gd|lc|vc|ag|bs|dm|kn|sr|gy|fk|ai|vg|ky|bm|tc|ms|pw|fm|mh|nr|ki|tv|to|ws|sb|vu|nc|pf|as|gu|mp|pr|vi|um|us|ca)$', caseSensitive: false).hasMatch(nick)); // Termina en dominio común
            
            if (!isServerHost) {
              channels[channel]!.addUser(nick, host: host);
              print('🔍 [DEBUG] Added user "$nick" to channel "$channel" with host: ${host ?? "unknown"}');
              // Notificar cambio en la lista de usuarios
              _notifyUserListListeners(channel);
            } else {
              print('🔍 [DEBUG] ❌ Skipping server/host name in JOIN: "$nick"');
            }
            
            final msg = IRCMessage(
              nick: nick,
              channel: channel,
              message: 'se unió al canal',
              timestamp: DateTime.now(),
              isSystem: true,
            );
            channels[channel]!.addMessage(msg);
            _notifyMessageListeners(msg);
            
            // Si es nuestro propio JOIN, solicitar la lista de usuarios
            final isOurJoin = nick == _nickname;
            print('🔍 [DEBUG] JOIN check: nick="$nick" == nickname="$_nickname" ? $isOurJoin');
            
            if (isOurJoin) {
              print('🔍 [DEBUG] ✅✅✅ Our own JOIN detected! ✅✅✅');
              print('🔍 [DEBUG] Requesting NAMES for $channel (immediate)');
              _sendCommand('NAMES $channel');
              
              // Solicitar el TOPIC del canal
              print('🔍 [DEBUG] Requesting TOPIC for $channel (immediate)');
              _sendCommand('TOPIC $channel');
              
              // También solicitar después de delays
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_isConnected && _hasActiveSocket) {
                  print('🔍 [DEBUG] Requesting NAMES for $channel (delayed 500ms)');
                  _sendCommand('NAMES $channel');
                  print('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 500ms)');
                  _sendCommand('TOPIC $channel');
                }
              });
              
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (_isConnected && _hasActiveSocket) {
                  print('🔍 [DEBUG] Requesting NAMES for $channel (delayed 1500ms)');
                  _sendCommand('NAMES $channel');
                  print('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 1500ms)');
                  _sendCommand('TOPIC $channel');
                }
              });
              
              Future.delayed(const Duration(milliseconds: 3000), () {
                if (_isConnected && _hasActiveSocket) {
                  print('🔍 [DEBUG] Requesting NAMES for $channel (delayed 3000ms)');
                  _sendCommand('NAMES $channel');
                  print('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 3000ms)');
                  _sendCommand('TOPIC $channel');
                }
              });
            } else {
              print('🔍 [DEBUG] ❌ Not our JOIN: nick="$nick" != nickname="$_nickname"');
            }
          } else {
            print('🔍 [DEBUG] ⚠️  JOIN command with no args');
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
                isSystem: true,
              );
              channels[channel]!.addMessage(msg);
              _notifyMessageListeners(msg);
              // Notificar cambio en la lista de usuarios
              _notifyUserListListeners(channel);
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
            print('🔍 [WHOIS] 311 - User info for $targetNick: $username@$host ($realName)');
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
            print('🔍 [WHOIS] 312 - Server info for $targetNick: $server ($serverInfo)');
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
            print('🔍 [WHOIS] 313 - $targetNick staff: ${_pendingWhois[targetNick]!.staffRole}');
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
            print('🔍 [WHOIS] 317 - Idle/signon for $targetNick: ${idleSeconds}s idle, signed on: $signonTime');
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
              print('🔍 [WHOIS] 318 - End of WHOIS for $targetNick');
            }
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
            print('🔍 [WHOIS] 319 - Channels for $targetNick: $channelsList');
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
            print('🔍 [WHOIS] 671 - $targetNick is using a secure connection (SSL/TLS)');
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
            print('🔍 [WHOIS] 301 - $targetNick is away: $awayMessage');
          }
          break;
        
        case 'PRIVMSG':
          if (args.isNotEmpty) {
            print('🔍 [DEBUG] 📨 PRIVMSG recibido - Raw line: $line');
            print('🔍 [DEBUG] 📨 PRIVMSG - nick del source: "$nick", args: $args');
            
            var target = args[0];
            print('🔍 [DEBUG] 📨 PRIVMSG - target original: "$target"');
            print('🔍 [DEBUG] 📨 PRIVMSG - nuestro nickname: "$_nickname"');
            
            var targetChannel = _normalizeChannelName(target);
            
            // Determinar si es un canal (#) o un mensaje privado (nick)
            bool isChannel = target.startsWith('#');
            String channelKey;
            bool isPrivateMessageToUs = false;
            
            print('🔍 [DEBUG] 📨 PRIVMSG - isChannel: $isChannel');
            
            if (isChannel) {
              // Es un canal, usar el nombre del canal normalizado
              channelKey = targetChannel;
              print('🔍 [DEBUG] 📨 PRIVMSG - Es un mensaje de canal: $channelKey');
            } else {
              // Es un mensaje privado
              print('🔍 [DEBUG] 📨 PRIVMSG - Es un mensaje privado (target no empieza con #)');
              print('🔍 [DEBUG] 📨 PRIVMSG - Comparando target "$target" (lowercase: ${target.toLowerCase()}) con nickname "$_nickname" (lowercase: ${_nickname?.toLowerCase()})');
              
              // Si el target es nuestro nickname, es un mensaje que NOS ENVIAN
              // En ese caso, usar el nick del remitente como channelKey
              // Si el target NO es nuestro nickname, es un mensaje que ENVIAMOS
              // En ese caso, usar el target como channelKey
              
              // Limpiar el target de posibles espacios o caracteres extra
              final cleanTarget = target.trim();
              final cleanNickname = _nickname?.trim();
              
              print('🔍 [DEBUG] 📨 PRIVMSG - Comparación detallada:');
              print('🔍 [DEBUG] 📨 PRIVMSG - target limpio: "$cleanTarget" (length: ${cleanTarget.length})');
              print('🔍 [DEBUG] 📨 PRIVMSG - nickname limpio: "$cleanNickname" (length: ${cleanNickname?.length ?? 0})');
              print('🔍 [DEBUG] 📨 PRIVMSG - target.toLowerCase(): "${cleanTarget.toLowerCase()}"');
              print('🔍 [DEBUG] 📨 PRIVMSG - nickname.toLowerCase(): "${cleanNickname?.toLowerCase() ?? "null"}"');
              print('🔍 [DEBUG] 📨 PRIVMSG - ¿Son iguales?: ${cleanNickname != null && cleanTarget.toLowerCase() == cleanNickname.toLowerCase()}');
              
              if (cleanNickname != null && cleanTarget.toLowerCase() == cleanNickname.toLowerCase()) {
                // Mensaje privado que nos envían, usar el nick del remitente
                isPrivateMessageToUs = true;
                channelKey = nick.toLowerCase();
                print('🔍 [DEBUG] 📨 PRIVMSG: ✅✅✅ Mensaje privado RECIBIDO de "$nick", usando channelKey="$channelKey" ✅✅✅');
                
                // Verificar si el remitente está en la lista de ignorados (solo para mensajes que nos envían)
                final senderNick = nick.toLowerCase();
                if (_ignoredUsers.contains(senderNick)) {
                  print('🚫 [IRCService] Mensaje privado ignorado de usuario: $nick (en lista de ignorados: $_ignoredUsers)');
                  break; // Ignorar el mensaje completamente
                }
                print('✅ [IRCService] Mensaje privado de "$nick" NO está en lista de ignorados. Lista actual: $_ignoredUsers');
                print('✅ [IRCService] Procediendo a procesar mensaje privado de "$nick"');
              } else {
                // Mensaje privado que enviamos, usar el target
                channelKey = cleanTarget.toLowerCase();
                print('🔍 [DEBUG] 📨 PRIVMSG: Mensaje privado ENVIADO a "$cleanTarget", usando channelKey="$channelKey"');
              }
            }
            
            // Para mensajes de canal, también verificar si el remitente está ignorado
            if (isChannel) {
              final senderNick = nick.toLowerCase();
              if (_ignoredUsers.contains(senderNick)) {
                print('🚫 [IRCService] Mensaje de canal ignorado de usuario: $nick en $target');
                break; // Ignorar el mensaje completamente
              }
            }
            
            // Crear el canal/query si no existe
            final isNewChannel = !channels.containsKey(channelKey);
            if (isNewChannel) {
              channels[channelKey] = IRCChannel(name: channelKey);
              print('🔍 [DEBUG] Creado ${isChannel ? "canal" : "query"}: $channelKey');
            }
            
            // Guardar el host del usuario si está disponible (solo para canales)
            if (isChannel && host != null) {
              channels[channelKey]!.addUser(nick, host: host);
            }
            
            // El formato es: :nick!user@host PRIVMSG target :mensaje
            final privmsgIndex = line.indexOf('PRIVMSG');
            if (privmsgIndex != -1) {
              // Encontrar el ':' que viene después del target
              final targetEndIndex = line.indexOf(target, privmsgIndex) + target.length;
              final colonIndex = line.indexOf(':', targetEndIndex);
              
              if (colonIndex != -1) {
                // El mensaje es todo lo que viene después del ':'
                final messageContent = line.substring(colonIndex + 1).trim();
                
                print('🔍 [DEBUG] PRIVMSG parsed: nick="$nick", target="$target", channelKey="$channelKey", message="$messageContent"');
                
                final msg = IRCMessage(
                  nick: nick,
                  channel: channelKey,
                  message: messageContent,
                  timestamp: DateTime.now(),
                );
                
                print('🔍 [DEBUG] ✅ Añadiendo mensaje al canal/query: $channelKey');
                print('🔍 [DEBUG] ✅ Canal existe en mapa: ${channels.containsKey(channelKey)}');
                channels[channelKey]!.addMessage(msg);
                print('🔍 [DEBUG] ✅ Mensaje añadido. Total mensajes en canal: ${channels[channelKey]!.messages.length}');
                
                // Guardar en historial local (no bloquear el hilo principal)
                // Usamos el host actual como identificador de servidor
                final serverId = (_secureSocket ?? _socket)?.remoteAddress.host ?? 'unknown';
                // Ignorar errores de forma silenciosa dentro del Future
                // para no afectar al flujo de mensajes
                // ignore: unawaited_futures
                ChatHistoryService().saveMessage(
                  server: serverId,
                  message: msg,
                );
                
                // Notificar a los listeners de mensajes
                _notifyMessageListeners(msg);
                print('🔍 [DEBUG] ✅ Listeners notificados. Total listeners: ${_messageListeners.length}');
                
                // Si es un nuevo canal/query, notificar también a los listeners de lista de usuarios
                // para que el provider se actualice y muestre el nuevo canal en la UI
                if (isNewChannel) {
                  print('🔍 [DEBUG] 🔄 Nuevo canal/query creado, notificando userListListeners para actualizar UI');
                  _notifyUserListListeners(channelKey);
                }
              } else {
                print('🔍 [DEBUG] ⚠️  PRIVMSG: No colon found after target');
              }
            } else {
              print('🔍 [DEBUG] ⚠️  PRIVMSG: PRIVMSG keyword not found in line');
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
      print('Error parsing IRC message: $e');
    }
  }

  void _onDisconnect() {
    channels.clear();
    _currentChannel = null;
    _socket = null;
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

  void addWhoisListener(Function(WhoisInfo) listener) {
    _whoisListeners.add(listener);
  }

  void removeWhoisListener(Function(WhoisInfo) listener) {
    _whoisListeners.remove(listener);
  }

  WhoisInfo? getWhoisInfo(String nick) {
    return _whoisCache[nick.toLowerCase()];
  }

  void _notifyWhoisListeners(WhoisInfo info) {
    for (var listener in _whoisListeners) {
      listener(info);
    }
  }

  void _notifyMessageListeners(IRCMessage message) {
    for (var listener in _messageListeners) {
      listener(message);
    }
  }

  void _notifyUserListListeners(String channel) {
    print('🔔 _notifyUserListListeners: channel=$channel, listeners=${_userListListeners.length}');
    for (var listener in _userListListeners) {
      listener(channel);
    }
  }

  void _notifyTopicListeners(String channel) {
    print('🔔 _notifyTopicListeners: channel=$channel, listeners=${_topicListeners.length}');
    for (var listener in _topicListeners) {
      listener(channel);
    }
  }
}
