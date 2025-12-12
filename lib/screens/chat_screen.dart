import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/irc_message.dart';
import '../providers/irc_provider.dart';
import '../services/irc_service.dart';
import 'login_screen.dart';
import '../widgets/animated_topic_text.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _channelController = TextEditingController();
  late IRCService _ircService;

  @override
  void initState() {
    super.initState();
    _ircService = ref.read(ircServiceProvider);
    
    print('🎬 [ChatScreen] Initialized');
    print('🎬 [ChatScreen] isConnected=${_ircService.isConnected}');
    
    // Listen for user list changes
    _ircService.addUserListListener(_onUserListChanged);
    
    // Listen for topic changes
    _ircService.addTopicListener(_onTopicChanged);
    
    // Get the channel from provider (was set in LoginScreen)
    final channel = ref.read(currentChannelProvider);
    print('🎬 [ChatScreen] Got channel from provider: $channel');
    
    // Únete después del primer frame y esperar a que el servidor termine de registrar al usuario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetChannel = (channel != null && channel.isNotEmpty) ? channel : '#general';
      if (channel == null || channel.isEmpty) {
        print('⚠️  [ChatScreen] No channel specified, using #general');
      }
      
      // Esperar un poco más para asegurar que el servidor haya terminado de registrar al usuario
      // El servidor envía el 001 (Welcome) cuando el usuario está registrado
      print('📍 [ChatScreen] Waiting for server registration before joining channel: $targetChannel');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        print('📍 [ChatScreen] Joining channel after delay: $targetChannel');
        _joinChannel(targetChannel);
      });
    });
  }

  void _onUserListChanged(String channel) {
    print('👥 _onUserListChanged called for: $channel');
    if (mounted) {
      print('  🔄 Scheduling Riverpod update post-frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(channelsProvider.notifier).updateChannels();
        setState(() {
          print('  🔄 setState after post-frame');
        });
      });
    }
  }

  void _onTopicChanged(String channel) {
    print('📌 _onTopicChanged called for: $channel');
    if (mounted) {
      print('  🔄 Scheduling Riverpod update post-frame for topic');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(channelsProvider.notifier).updateChannels();
        setState(() {
          print('  🔄 setState after post-frame for topic');
        });
      });
    }
  }

  @override
  void dispose() {
    _ircService.removeUserListListener(_onUserListChanged);
    _ircService.removeTopicListener(_onTopicChanged);
    _messageController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  void _joinChannel(String channel) {
    if (channel.isEmpty) return;
    
    // Normalizar el nombre del canal (asegurar que tenga #)
    String normalizedChannel = channel.trim();
    
    // Remover ':' si está al inicio
    if (normalizedChannel.startsWith(':')) {
      normalizedChannel = normalizedChannel.substring(1).trim();
    }
    
    // Remover # duplicados al inicio
    while (normalizedChannel.startsWith('##')) {
      normalizedChannel = normalizedChannel.substring(1);
    }
    
    // Asegurar que empiece con # (solo uno)
    if (!normalizedChannel.startsWith('#')) {
      normalizedChannel = '#$normalizedChannel';
    }
    
    // Normalizar a minúsculas para consistencia
    normalizedChannel = normalizedChannel.toLowerCase();
    
    print('🔍 [DEBUG] 🚪 Joining channel: "$channel" -> normalized: "$normalizedChannel"');
    _ircService.joinChannel(normalizedChannel);
    ref.read(currentChannelProvider.notifier).state = normalizedChannel;
    print('🔍 [DEBUG] ✅ Channel set in provider: $normalizedChannel');
    _channelController.clear();
    
    // Force UI update
    print('🔍 [DEBUG] 🔄 Forcing channels provider update...');
    ref.read(channelsProvider.notifier).updateChannels();
    
    // Also update after delays to catch late responses
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        print('🔍 [DEBUG] 🔄 Secondary channels update (800ms)');
        ref.read(channelsProvider.notifier).updateChannels();
      }
    });
    
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        print('🔍 [DEBUG] 🔄 Tertiary channels update (2000ms)');
        ref.read(channelsProvider.notifier).updateChannels();
      }
    });
  }

  void _sendMessage() {
    final channel = ref.read(currentChannelProvider);
    if (channel == null || _messageController.text.isEmpty) return;

    // Normalizar el nombre del canal antes de enviar
    final normalizedChannel = channel.toLowerCase();
    _ircService.sendMessage(normalizedChannel, _messageController.text);
    _messageController.clear();
    
    // Trigger UI update
    ref.read(messagesProvider.notifier);
  }

  void _disconnect() {
    _ircService.disconnect();
    ref.read(currentNicknameProvider.notifier).state = null;
    ref.read(currentChannelProvider.notifier).state = null;
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = ref.watch(currentNicknameProvider);
    final currentChannel = ref.watch(currentChannelProvider);
    final messages = ref.watch(messagesProvider);
    final channels = ref.watch(channelsProvider);
    final isConnected = ref.watch(connectionStatusProvider);
    
    // Verificar también el estado del servicio directamente como respaldo
    final serviceConnected = _ircService.isConnected;

    // Solo redirigir a LoginScreen si realmente no está conectado
    // (ni el provider ni el servicio indican conexión)
    if (!isConnected && !serviceConnected) {
      return const LoginScreen();
    }

    // Filtrar mensajes del canal actual (case-insensitive)
    final channelMessages = currentChannel != null
        ? messages.where((m) => m.channel.toLowerCase() == currentChannel.toLowerCase()).toList()
        : <IRCMessage>[];

    // Normalizar el nombre del canal para búsqueda (case-insensitive)
    print('🔍 [DEBUG] 🖼️  ChatScreen build: currentChannel=$currentChannel');
    print('🔍 [DEBUG] Available channels in provider: ${channels.keys.toList()}');
    
    final normalizedCurrentChannel = currentChannel?.toLowerCase();
    print('🔍 [DEBUG] Normalized current channel: $normalizedCurrentChannel');
    
    String? channelKey;
    if (normalizedCurrentChannel != null) {
      try {
        channelKey = channels.keys.firstWhere(
          (key) => key.toLowerCase() == normalizedCurrentChannel,
        );
        print('🔍 [DEBUG] Found channel key: $channelKey');
      } catch (e) {
        print('🔍 [DEBUG] ⚠️  Channel key not found: $e');
        channelKey = null;
      }
    }
    
    if (channelKey != null && channels.containsKey(channelKey)) {
      print('🔍 [DEBUG] Channel found in map: $channelKey');
      print('🔍 [DEBUG] Users in channel: ${channels[channelKey]!.users}');
      print('🔍 [DEBUG] Users count: ${channels[channelKey]!.users.length}');
    } else {
      print('🔍 [DEBUG] ⚠️  Channel not found or key is null');
      print('🔍 [DEBUG] channelKey: $channelKey');
      print('🔍 [DEBUG] channels.containsKey(channelKey): ${channelKey != null ? channels.containsKey(channelKey) : 'N/A'}');
    }
    
    final channelUsers = currentChannel != null && 
        channelKey != null && 
        channels.containsKey(channelKey)
        ? channels[channelKey]!.users
        : <String>[];

    print('🔍 [DEBUG] Final channelUsers count: ${channelUsers.length}');
    print('🔍 [DEBUG] Final channelUsers list: $channelUsers');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _disconnect();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(currentChannel ?? 'Cliente IRC'),
              if (nickname != null)
                Text(
                  'como $nickname',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
            ],
          ),
          backgroundColor: const Color(0xFFFF8C00), // Naranja oscuro
          foregroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child:                     Text(
                      isConnected ? '● Conectado' : '● Desconectado',
                      style: const TextStyle(color: Colors.white),
                    ),
                ),
              ),
            ),
          ],
        ),
        body: Row(
          children: [
            // Channels sidebar
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.grey[900],
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFF8C00), // Naranja oscuro
                            const Color(0xFFFFA500), // Naranja
                          ],
                        ),
                      ),
                      child: const Text(
                        'Canales',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final channel = channels.keys.elementAt(index);
                          
                          // Filtrar canales inválidos (que no empiecen con #)
                          if (!channel.startsWith('#')) {
                            return const SizedBox.shrink();
                          }
                          
                          // Filtrar canales que coincidan con el nickname del usuario
                          final currentNick = ref.read(currentNicknameProvider);
                          if (currentNick != null) {
                            final channelWithoutHash = channel.toLowerCase().replaceFirst('#', '');
                            final normalizedNick = currentNick.toLowerCase();
                            if (channelWithoutHash == normalizedNick || 
                                channel.toLowerCase() == '#$normalizedNick') {
                              return const SizedBox.shrink();
                            }
                          }
                          
                          // Normalizar para comparación (case-insensitive)
                          final normalizedCurrent = currentChannel?.toLowerCase();
                          final normalizedChannel = channel.toLowerCase();
                          final isSelected = normalizedChannel == normalizedCurrent;
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? const Color(0xFFFFA500).withOpacity(0.3) // Naranja brillante cuando está seleccionado
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: const Color(0xFFFFD700), // Amarillo dorado
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: ListTile(
                              selected: isSelected,
                              selectedTileColor: Colors.transparent,
                              title: Text(
                                channel,
                                style: TextStyle(
                                  color: isSelected 
                                      ? const Color(0xFFFFD700) // Amarillo dorado cuando está seleccionado
                                      : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () {
                                ref.read(currentChannelProvider.notifier).state = channel;
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white70, size: 18),
                                onPressed: () {
                                  _ircService.partChannel(channel);
                                  ref.read(channelsProvider.notifier).updateChannels();
                                  final normalizedCurrentChannel = currentChannel?.toLowerCase();
                                  if (normalizedCurrentChannel == normalizedChannel) {
                                    ref.read(currentChannelProvider.notifier).state =
                                        null;
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                        child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showJoinDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Unirse'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFA500), // Naranja
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chat area
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Topic bar con animación
                  if (currentChannel != null)
                    _buildTopicBar(currentChannel, channels),
                  // Messages
                  Expanded(
                    child: currentChannel == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Selecciona un canal para comenzar a chatear',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            color: Colors.grey[50],
                            child: ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: channelMessages.length,
                              itemBuilder: (context, index) {
                                final message =
                                    channelMessages[channelMessages.length - 1 - index];
                                return _buildMessageTile(message);
                              },
                            ),
                          ),
                  ),
                  const Divider(height: 1),
                  // Input area
                  if (currentChannel != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Mensaje...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                              minLines: 1,
                              maxLines: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton(
                            onPressed: _sendMessage,
                            mini: true,
                            backgroundColor: const Color(0xFFFFA500), // Naranja
                            child: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Users sidebar
            if (currentChannel != null)
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.grey[900],
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF8C00), // Naranja oscuro
                              const Color(0xFFFFA500), // Naranja
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Usuarios',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${channelUsers.length} usuarios',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (channelUsers.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Aún no hay usuarios',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: channelUsers.length,
                            itemBuilder: (context, index) {
                              final user = channelUsers[index];
                              // Obtener el canal para verificar si el usuario es un robot
                              IRCChannel? currentChannelData;
                              if (channelKey != null && channels.containsKey(channelKey)) {
                                currentChannelData = channels[channelKey];
                              }
                              // Verificar si el usuario es un robot
                              final isRobot = currentChannelData?.isRobot(user) ?? false;
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  isRobot ? Icons.smart_toy : Icons.person,
                                  color: isRobot ? const Color(0xFFFFD700) : Colors.white70,
                                  size: 16,
                                ),
                                title: Text(
                                  user,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: isRobot ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _disconnect,
          backgroundColor: Colors.red,
          child: const Icon(Icons.logout),
        ),
      ),
    );
  }

  Widget _buildMessageTile(IRCMessage message) {
    final timeFormat = DateFormat('HH:mm');
    final currentNick = ref.read(currentNicknameProvider);
    final isOwnMessage = message.nick == currentNick;
    
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${message.nick} ${message.message}',
              style: TextStyle(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    // Generar color basado en el hash del nickname para consistencia
    final nickHash = message.nick.hashCode;
    final userColor = _getUserColor(nickHash);
    
    // Obtener inicial del usuario para el avatar
    final userInitial = message.nick.isNotEmpty 
        ? message.nick[0].toUpperCase() 
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwnMessage) ...[
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: userColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: userColor.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  userInitial,
                  style: TextStyle(
                    color: userColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Burbuja de mensaje
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOwnMessage 
                    ? const Color(0xFFFFA500) // Naranja para mensajes propios
                    : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isOwnMessage ? 18 : 4),
                  bottomRight: Radius.circular(isOwnMessage ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nickname y hora
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.nick,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isOwnMessage 
                              ? Colors.white 
                              : userColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeFormat.format(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isOwnMessage 
                              ? Colors.white70 
                              : Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Contenido del mensaje
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isOwnMessage 
                          ? Colors.white 
                          : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: 8),
            // Avatar para mensajes propios
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFA500).withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFA500).withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  currentNick != null && currentNick.isNotEmpty
                      ? currentNick[0].toUpperCase()
                      : 'Y',
                  style: const TextStyle(
                    color: Color(0xFFFF8C00), // Naranja oscuro
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Generar color consistente basado en el hash del nickname
  Color _getUserColor(int hash) {
    final colors = [
      const Color(0xFFFFA500), // Naranja
      const Color(0xFFFFD700), // Amarillo dorado
      const Color(0xFFFF8C00), // Naranja oscuro
      const Color(0xFFFFE4B5), // Amarillo claro
      Colors.orange,
      Colors.amber,
      const Color(0xFFFFB347), // Naranja claro
      const Color(0xFFFFCC00), // Amarillo
      Colors.deepOrange,
      const Color(0xFFFFE135), // Amarillo brillante
    ];
    return colors[hash.abs() % colors.length];
  }

  // Widget para mostrar el topic con animación moderna
  Widget _buildTopicBar(String? channel, Map<String, IRCChannel> channels) {
    if (channel == null) return const SizedBox.shrink();
    
    // Buscar el canal de forma case-insensitive
    IRCChannel? channelData;
    for (var entry in channels.entries) {
      if (entry.key.toLowerCase() == channel.toLowerCase()) {
        channelData = entry.value;
        break;
      }
    }
    
    final topic = channelData?.topic;
    
    if (topic == null || topic.isEmpty) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFFD700).withOpacity(0.2), // Amarillo dorado
              const Color(0xFFFFA500).withOpacity(0.2), // Naranja
            ],
          ),
        ),
        child: const Center(
          child: Text(
            'Sin tema establecido',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700), // Amarillo dorado
            const Color(0xFFFFA500), // Naranja
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxHeight: 40,
          child: AnimatedTopicText(topic: topic),
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirse a Canal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '#channelname',
            prefixIcon: Icon(Icons.tag),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _joinChannel(controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFA500), // Naranja
              foregroundColor: Colors.white,
            ),
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }
}
