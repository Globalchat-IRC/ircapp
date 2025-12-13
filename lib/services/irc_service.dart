import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/irc_message.dart';

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
                topicText = line.substring(colonIndex + 1).trim();
                print('🔍 [DEBUG] 📌📌📌 Topic text extracted: "$topicText"');
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
              // Agregar usuarios a la lista (addUser ya verifica duplicados)
              for (var user in users) {
                // Remove IRC user modes: @(op), +(voice), %(halfop), :(other)
                final cleanUser = user.replaceAll(RegExp(r'^[@+%:]'), '').trim();
                print('🔍 [DEBUG] Processing user: "$user" -> cleaned: "$cleanUser"');
                
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
                  print('🔍 [DEBUG] ➕ Adding user: "$cleanUser"');
                  channels[channel]!.addUser(cleanUser);
                  addedCount++;
                } else {
                  if (isServerHost) {
                    print('🔍 [DEBUG] ❌ Skipping server/host name: "$cleanUser"');
                  } else {
                    print('🔍 [DEBUG] ❌ Skipping invalid user: "$cleanUser"');
                  }
                }
              }
              
              print('🔍 [DEBUG] Added $addedCount new users');
              print('🔍 [DEBUG] Total users in channel now: ${channels[channel]!.users.length}');
              print('🔍 [DEBUG] Users list: ${channels[channel]!.users}');
              
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
        
        case 'PRIVMSG':
          if (args.isNotEmpty) {
            var target = args[0];
            var targetChannel = _normalizeChannelName(target);
            
            // Determinar si es un canal (#) o un mensaje privado (nick)
            bool isChannel = target.startsWith('#');
            String channelKey;
            
            if (isChannel) {
              // Es un canal, usar el nombre del canal normalizado
              channelKey = targetChannel;
            } else {
              // Es un mensaje privado
              // Si el target es nuestro nickname, es un mensaje que NOS ENVIAN
              // En ese caso, usar el nick del remitente como channelKey
              // Si el target NO es nuestro nickname, es un mensaje que ENVIAMOS
              // En ese caso, usar el target como channelKey
              if (_nickname != null && target.toLowerCase() == _nickname!.toLowerCase()) {
                // Mensaje privado que nos envían, usar el nick del remitente
                channelKey = nick.toLowerCase();
                print('🔍 [DEBUG] PRIVMSG: Mensaje privado recibido de "$nick", usando channelKey="$channelKey"');
              } else {
                // Mensaje privado que enviamos, usar el target
                channelKey = target.toLowerCase();
                print('🔍 [DEBUG] PRIVMSG: Mensaje privado enviado a "$target", usando channelKey="$channelKey"');
              }
            }
            
            // Crear el canal/query si no existe
            if (!channels.containsKey(channelKey)) {
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
                channels[channelKey]!.addMessage(msg);
                _notifyMessageListeners(msg);
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
