import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/irc_message.dart';
import '../providers/irc_provider.dart';
import '../models/server_profile.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../services/irc_service.dart';
import '../services/chat_history_service.dart';
import '../services/sound_service.dart';
import 'login_screen.dart';
import 'user_profile_screen.dart';
import 'emoji_config_screen.dart';
import '../widgets/animated_topic_text.dart';
import '../widgets/user_avatar.dart';
import '../services/avatar_service.dart';
import '../utils/irc_color_parser.dart';
import '../widgets/radio_controls.dart';

// Widget genérico para botones animados
class AnimatedServiceButton extends StatefulWidget {
  final VoidCallback onPressed;
  final AppTheme appTheme;
  final String tooltip;
  final String emoji;
  final String label;

  const AnimatedServiceButton({
    Key? key,
    required this.onPressed,
    required this.appTheme,
    required this.tooltip,
    required this.emoji,
    required this.label,
  }) : super(key: key);

  @override
  State<AnimatedServiceButton> createState() => _AnimatedServiceButtonState();
}

class _AnimatedServiceButtonState extends State<AnimatedServiceButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isPressed ? 0.95 : (_isHovered ? _pulseAnimation.value : 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isHovered
                          ? [
                              widget.appTheme.accent,
                              widget.appTheme.primary,
                            ]
                          : [
                              widget.appTheme.primary.withOpacity(0.8),
                              widget.appTheme.secondary.withOpacity(0.8),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: widget.appTheme.accent.withOpacity(0.6),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: widget.appTheme.primary.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedRotation(
                        turns: _isHovered ? 0.1 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Text(
                          widget.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.appTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Intent para pegar imágenes
class PasteImageIntent extends Intent {
  const PasteImageIntent();
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _channelController = TextEditingController();
  late IRCService _ircService;
  final ImagePicker _imagePicker = ImagePicker();
  bool _initialJoinDone = false;
  final Map<String, List<IRCMessage>> _loadedHistoryByChannel = {};

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
    
    // Listen for new messages to auto-open private messages
    _ircService.addMessageListener(_onMessageReceived);
    
    // Listen for nickname changes
    _ircService.addNickChangeListener(_onNickChanged);

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
      print('📍 [ChatScreen] Waiting for server registration before joining initial channels');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        if (_initialJoinDone) return;

        final favoritesNow = ref.read(favoritesProvider).toList();
        if (favoritesNow.isNotEmpty) {
          _initialJoinDone = true;
          print('📍 [ChatScreen] Joining favorite channels after delay: $favoritesNow');
          for (final fav in favoritesNow) {
            _joinChannel(fav);
          }
        } else {
          _initialJoinDone = true;
          print('📍 [ChatScreen] Joining channel after delay: $targetChannel');
          _joinChannel(targetChannel);
        }
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

  void _onNickChanged(String newNick) {
    print('🔄 [ChatScreen] _onNickChanged called: $newNick');
    print('🔄 [ChatScreen] mounted: $mounted');
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('🔄 [ChatScreen] PostFrameCallback ejecutado, mounted: $mounted');
        if (!mounted) {
          print('🔄 [ChatScreen] ❌ Widget no está montado, cancelando actualización');
          return;
        }
        final oldNick = ref.read(currentNicknameProvider);
        print('🔄 [ChatScreen] Nick anterior en provider: $oldNick');
        print('🔄 [ChatScreen] Actualizando provider a: $newNick');
        ref.read(currentNicknameProvider.notifier).state = newNick;
        final updatedNick = ref.read(currentNicknameProvider);
        print('🔄 [ChatScreen] ✅ Provider actualizado, nuevo valor: $updatedNick');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nick cambiado a $newNick'),
            duration: const Duration(seconds: 2),
          ),
        );
      });
    } else {
      print('🔄 [ChatScreen] ❌ Widget no está montado, no se puede actualizar');
    }
  }

  void _onMessageReceived(IRCMessage message) {
    print('💬 _onMessageReceived: nick="${message.nick}", channel="${message.channel}"');
    
    if (mounted) {
      final currentChannel = ref.read(currentChannelProvider);
      final messageChannel = message.channel.toLowerCase();
      final currentChannelLower = currentChannel?.toLowerCase();
      
      // Establecer typing indicator cuando llega un mensaje (simula que el usuario estaba escribiendo)
      // Solo si no es nuestro propio mensaje
      final currentNick = ref.read(currentNicknameProvider);
      if (message.nick.toLowerCase() != currentNick?.toLowerCase()) {
        ref.read(typingIndicatorProvider.notifier).setTyping(messageChannel, message.nick);
      }

      // Añadir a recientes el canal de cualquier mensaje recibido
      ref.read(recentChannelsProvider.notifier).addRecent(messageChannel);
      
      // Notificaciones y sonidos según tipo de mensaje y reglas
      final settings = ref.read(notificationSettingsProvider);
      final level = settings.levelForChannel(messageChannel);
      final isPrivate = !messageChannel.startsWith('#');
      final isMention = !isPrivate &&
          currentNick != null &&
          message.message
              .toLowerCase()
              .contains(currentNick.toLowerCase());
      final isFromMutedUser = settings.isUserMuted(message.nick);

      if (!isFromMutedUser && level != NotificationLevel.muted) {
        if (isMention && settings.soundForMentions) {
          // Sonido de mención configurable
          switch (settings.mentionSound) {
            case MentionSound.cuack:
              // ignore: unawaited_futures
              SoundService().playMentionCuack();
              break;
            case MentionSound.systemAlert:
              SystemSound.play(SystemSoundType.alert);
              break;
            case MentionSound.systemClick:
              SystemSound.play(SystemSoundType.click);
              break;
          }
        } else if (isPrivate && settings.soundForPrivates) {
          SystemSound.play(SystemSoundType.alert);
        } else if (level == NotificationLevel.allMessages && !isPrivate) {
          SystemSound.play(SystemSoundType.click);
        }
      }

      // Si no estamos en el canal donde llegó el mensaje, incrementar contador de no leídos
      if (currentChannelLower != messageChannel) {
        // Incrementar no leídos tanto para canales como para privados
        print('💬 📬 Mensaje no leído en $messageChannel de: ${message.nick}');
        ref
            .read(unreadMessagesProvider.notifier)
            .incrementUnread(messageChannel);
      } else {
        // Estamos en el canal, marcar como leído
        ref.read(unreadMessagesProvider.notifier).markAsRead(messageChannel);
      }
    }
  }

  Future<void> _loadHistoryIfNeeded(String channel) async {
    final normalized = channel.toLowerCase();
    if (_loadedHistoryByChannel.containsKey(normalized)) return;

    final socket = _ircService.isConnected
        ? (_ircService is IRCService
            ? (_ircService as dynamic)._secureSocket ??
                (_ircService as dynamic)._socket
            : null)
        : null;
    final serverId = socket?.remoteAddress.host ?? 'unknown';

    final history = await ChatHistoryService().loadRecentMessages(
      server: serverId,
      channel: normalized,
      limit: 200,
    );

    if (!mounted) return;
    setState(() {
      _loadedHistoryByChannel[normalized] = history;
    });
  }

  @override
  void dispose() {
    _ircService.removeUserListListener(_onUserListChanged);
    _ircService.removeTopicListener(_onTopicChanged);
    _ircService.removeMessageListener(_onMessageReceived);
    _ircService.removeNickChangeListener(_onNickChanged);
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
    // Guardar canal actual, último canal usado y añadir a recientes
    ref.read(currentChannelProvider.notifier).state = normalizedChannel;
    ref.read(lastChannelProvider.notifier).state = normalizedChannel;
    ref.read(recentChannelsProvider.notifier).addRecent(normalizedChannel);
    print('🔍 [DEBUG] ✅ Channel set in provider: $normalizedChannel');
    _channelController.clear();

    // Cargar historial local para este canal en segundo plano
    // ignore: unawaited_futures
    _loadHistoryIfNeeded(normalizedChannel);
    
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

  void _showChannelNotificationMenu(BuildContext context, String channel) {
    final settings = ref.read(notificationSettingsProvider);
    final level = settings.levelForChannel(channel);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final appTheme = ref.read(themeProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Notificaciones para $channel',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              RadioListTile<NotificationLevel>(
                value: NotificationLevel.allMessages,
                groupValue: level,
                title: const Text('Todas las mensajes'),
                onChanged: (v) {
                  ref
                      .read(notificationSettingsProvider.notifier)
                      .setChannelLevel(
                          channel, NotificationLevel.allMessages);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<NotificationLevel>(
                value: NotificationLevel.mentionsOnly,
                groupValue: level,
                title: const Text('Solo menciones'),
                onChanged: (v) {
                  ref
                      .read(notificationSettingsProvider.notifier)
                      .setChannelLevel(
                          channel, NotificationLevel.mentionsOnly);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<NotificationLevel>(
                value: NotificationLevel.muted,
                groupValue: level,
                title: const Text('Silenciado'),
                onChanged: (v) {
                  ref
                      .read(notificationSettingsProvider.notifier)
                      .setChannelLevel(channel, NotificationLevel.muted);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Sonido para privados'),
                value: settings.soundForPrivates,
                activeColor: appTheme.accent,
                onChanged: (_) {
                  ref
                      .read(notificationSettingsProvider.notifier)
                      .toggleSoundForPrivates();
                },
              ),
              SwitchListTile(
                title: const Text('Sonido para menciones'),
                value: settings.soundForMentions,
                activeColor: appTheme.accent,
                onChanged: (_) {
                  ref
                      .read(notificationSettingsProvider.notifier)
                      .toggleSoundForMentions();
                },
              ),
              ListTile(
                title: const Text('Sonido de mención'),
                subtitle: Text(
                  switch (settings.mentionSound) {
                    MentionSound.cuack => 'Cuack de IRCap',
                    MentionSound.systemAlert => 'Alerta del sistema',
                    MentionSound.systemClick => 'Click del sistema',
                  },
                ),
                trailing: PopupMenuButton<MentionSound>(
                  icon: const Icon(Icons.arrow_drop_down),
                  onSelected: (value) {
                    ref
                        .read(notificationSettingsProvider.notifier)
                        .setMentionSound(value);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: MentionSound.cuack,
                      child: Text('Cuack de IRCap'),
                    ),
                    PopupMenuItem(
                      value: MentionSound.systemAlert,
                      child: Text('Alerta del sistema'),
                    ),
                    PopupMenuItem(
                      value: MentionSound.systemClick,
                      child: Text('Click del sistema'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSearchDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final currentChannel = ref.read(currentChannelProvider);

    final textController = TextEditingController();
    final nickController = TextEditingController();
    DateTime? fromDate;
    DateTime? toDate;
    bool channelOnly = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Buscar en historial'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentChannel != null)
                      SwitchListTile(
                        title: const Text('Buscar solo en este canal'),
                        value: channelOnly,
                        onChanged: (v) {
                          setState(() => channelOnly = v);
                        },
                      ),
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        labelText: 'Texto contiene',
                        prefixIcon: Icon(Icons.text_fields),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nickController,
                      decoration: const InputDecoration(
                        labelText: 'Nick (exacto)',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: fromDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  fromDate = picked;
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              fromDate != null
                                  ? 'Desde: ${DateFormat('dd/MM/yyyy').format(fromDate!)}'
                                  : 'Desde...',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: toDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  toDate = picked.add(
                                    const Duration(hours: 23, minutes: 59),
                                  );
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              toDate != null
                                  ? 'Hasta: ${DateFormat('dd/MM/yyyy').format(toDate!)}'
                                  : 'Hasta...',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.primary,
                    foregroundColor: appTheme.textPrimary,
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _runHistorySearch(
                      context: context,
                      text: textController.text.trim(),
                      nick: nickController.text.trim(),
                      from: fromDate,
                      to: toDate,
                      channel: channelOnly ? currentChannel : null,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _runHistorySearch({
    required BuildContext context,
    String? channel,
    String? nick,
    String? text,
    DateTime? from,
    DateTime? to,
  }) async {
    final socket = _ircService.isConnected
        ? (_ircService is IRCService
            ? (_ircService as dynamic)._secureSocket ??
                (_ircService as dynamic)._socket
            : null)
        : null;
    final serverId = socket?.remoteAddress.host ?? 'unknown';

    final results = await ChatHistoryService().searchMessages(
      server: serverId,
      channel: channel?.toLowerCase(),
      nick: nick?.isEmpty == true ? null : nick,
      text: text?.isEmpty == true ? null : text,
      from: from,
      to: to,
      limit: 300,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      builder: (context) {
        final appTheme = ref.read(themeProvider);
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: appTheme.surface.withOpacity(0.98),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        channel != null
                            ? 'Resultados en $channel'
                            : 'Resultados globales',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${results.length} mensajes',
                        style: TextStyle(
                          color: appTheme.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(
                            child: Text('Sin resultados'),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final msg = results[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '<${msg.nick}> ${msg.message}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '[${msg.channel}] ${DateFormat('dd/MM/yyyy HH:mm').format(msg.timestamp)}',
                                  style: TextStyle(
                                    color: appTheme.textSecondary
                                        .withOpacity(0.8),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  // Saltar al canal del mensaje
                                  _joinChannel(msg.channel);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _sendMessage() {
    final channel = ref.read(currentChannelProvider);
    if (channel == null || _messageController.text.isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    
    // Detectar comandos que empiezan con /
    if (message.startsWith('/')) {
      _handleCommand(message);
      return;
    }

    // Normalizar el nombre del canal antes de enviar
    final normalizedChannel = channel.toLowerCase();
    
    // Si el canal no empieza con #, es un query (mensaje privado)
    if (normalizedChannel.startsWith('#')) {
      _ircService.sendMessage(normalizedChannel, message);
    } else {
      // Es un query, enviar mensaje privado
      _ircService.sendPrivateMessage(normalizedChannel, message);
    }
    
    // Añadir a recientes también al enviar mensaje
    ref.read(recentChannelsProvider.notifier).addRecent(normalizedChannel);

    // Trigger UI update
    ref.read(messagesProvider.notifier);
  }

  void _handleCommand(String command) {
    final parts = command.substring(1).split(' '); // Remover el / inicial
    if (parts.isEmpty) return;
    
    final cmd = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];
    
    switch (cmd) {
      case 'query':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /query <nick> [mensaje]'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        if (nick.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor ingresa un nick válido'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final message = args.length > 1 ? args.sublist(1).join(' ') : '';
        
        // El query es el nick en minúsculas (sin #)
        final queryNick = nick.toLowerCase();
        
        // Asegurarse de que el query existe en los canales
        if (!_ircService.allChannels.containsKey(queryNick)) {
          _ircService.allChannels[queryNick] = IRCChannel(name: queryNick);
          print('📝 [Query] Creado query para: $queryNick');
        }
        
        // Cambiar al query (mensaje privado)
        ref.read(currentChannelProvider.notifier).state = queryNick;
        ref.read(lastChannelProvider.notifier).state = queryNick;
        ref.read(recentChannelsProvider.notifier).addRecent(queryNick);
        
        // Si hay un mensaje, enviarlo como PRIVMSG al nick
        if (message.isNotEmpty) {
          _ircService.sendPrivateMessage(nick, message);
        }
        
        // Forzar actualización de la UI
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ref.read(channelsProvider.notifier).updateChannels();
            setState(() {});
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Abriendo mensaje privado con $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'whois':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /whois <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        if (nick.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor ingresa un nick válido'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        _ircService.sendWhois(nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solicitando información de $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'nick':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /nick <nuevonick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final newNick = args[0].trim();
        if (newNick.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor ingresa un nick válido'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        _ircService.changeNick(newNick);
        // No actualizar el provider aquí, esperar a que el servidor confirme el cambio
        // El listener _onNickChanged actualizará el provider cuando el servidor confirme
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cambiando nick a $newNick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'ignore':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /ignore <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        if (nick.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor ingresa un nick válido'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        _ircService.sendIgnore(nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ignorando mensajes de $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'unignore':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /unignore <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        if (nick.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor ingresa un nick válido'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        _ircService.sendUnignore(nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dejando de ignorar mensajes de $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comando desconocido: /$cmd'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  /// Mostrar diálogo para cambiar de servidor / red mientras estamos conectados.
  /// Nota: cambiar de servidor implica desconectar y volver al login.
  void _showServerSwitchDialog() {
    final appTheme = ref.read(themeProvider);
    final profiles = ref.read(serverProfilesProvider);
    final currentProfile = ref.read(currentServerProfileProvider);

    showDialog(
      context: context,
      builder: (context) {
        ServerProfile? selected = currentProfile;

        return AlertDialog(
          backgroundColor: appTheme.surface,
          title: const Text('Cambiar de servidor / red'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona un servidor de GlobalChat.\n'
                    'Se cerrará la conexión actual y volverás al login.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ServerProfile>(
                    value: selected,
                    decoration: const InputDecoration(
                      labelText: 'Servidor / Red',
                    ),
                    items: profiles
                        .map(
                          (p) => DropdownMenuItem<ServerProfile>(
                            value: p,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  p.useSSL ? Icons.lock : Icons.lock_open,
                                  size: 18,
                                  color: p.useSSL
                                      ? Colors.greenAccent
                                      : appTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (p) {
                      setState(() {
                        selected = p;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () {
                      // Guardar perfil seleccionado y desconectar
                      ref
                          .read(currentServerProfileProvider.notifier)
                          .state = selected;
                      Navigator.of(context).pop();
                      _disconnect();
                      // Volver al login para reconectar con el nuevo servidor
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
              child: const Text('Cambiar y reconectar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndSendImage() async {
    try {
      print('🔍 Iniciando selección de imagen o video...');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'webm', 'mov'],
        allowMultiple: false,
        dialogTitle: 'Seleccionar imagen o video',
        withData: true, // Obtener también los bytes
      );

      print('🔍 Resultado del file picker: ${result != null ? "no null" : "null"}');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        print('🔍 Archivo seleccionado:');
        print('  - name: ${file.name}');
        print('  - path: ${file.path}');
        print('  - bytes: ${file.bytes != null ? "${file.bytes!.length} bytes" : "null"}');
        print('  - size: ${file.size}');
        
        String? filePath = file.path;
        
        // Si no hay path pero hay bytes, guardar en archivo temporal
        if ((filePath == null || filePath.isEmpty) && file.bytes != null) {
          final tempDir = Directory.systemTemp;
          final extension = file.name.split('.').last;
          final tempFile = File('${tempDir.path}/picked_image_${DateTime.now().millisecondsSinceEpoch}.$extension');
          await tempFile.writeAsBytes(file.bytes!);
          filePath = tempFile.path;
          print('✅ Imagen guardada en archivo temporal: $filePath');
        }
        
        if (filePath != null && filePath.isNotEmpty) {
          final mediaFile = File(filePath);
          
          // Verificar que el archivo existe
          if (await mediaFile.exists()) {
            print('✅ Archivo existe, procesando...');
            
            // Detectar si es imagen o video
            final extension = file.name.split('.').last.toLowerCase();
            final isVideo = ['mp4', 'webm', 'mov'].contains(extension);
            
            if (isVideo) {
              await _processAndSendVideo(mediaFile);
            } else {
              await _processAndSendImage(mediaFile);
            }
          } else {
            print('❌ El archivo no existe: $filePath');
            throw Exception('El archivo seleccionado no existe: $filePath');
          }
        } else {
          print('❌ No se pudo obtener la ruta del archivo');
          throw Exception('No se pudo obtener la ruta del archivo seleccionado');
        }
      } else {
        print('ℹ️ No se seleccionó ningún archivo (usuario canceló)');
      }
    } catch (e, stackTrace) {
      print('❌ Error al seleccionar imagen: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _pickAndSendImage,
            ),
          ),
        );
      }
    }
  }

  Future<void> _uploadAndSendToCloudinary(Uint8List imageBytes, String mimeType, String channel) async {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Subiendo imagen a Cloudinary...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }
    
    try {
      // Subir a Cloudinary
      final imageUrl = await _uploadImageToCloudinary(imageBytes, mimeType);
      
      if (imageUrl != null) {
        final normalizedChannel = channel.toLowerCase();
        await Future.delayed(const Duration(milliseconds: 300));
        // Enviar solo la URL (sin prefijo [Imagen] para que se detecte automáticamente)
        _ircService.sendMessage(normalizedChannel, imageUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Imagen subida y URL enviada')),
          );
        }
      } else {
        throw Exception('No se pudo subir la imagen a Cloudinary');
      }
    } catch (e) {
      print('❌ Error al subir imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _uploadAndSendVideoToCloudinary(Uint8List videoBytes, String mimeType, String channel) async {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Subiendo video a Cloudinary...'),
            ],
          ),
          duration: Duration(seconds: 60),
        ),
      );
    }
    
    try {
      // Subir a Cloudinary
      final videoUrl = await _uploadVideoToCloudinary(videoBytes, mimeType);
      
      if (videoUrl != null) {
        final normalizedChannel = channel.toLowerCase();
        await Future.delayed(const Duration(milliseconds: 300));
        // Enviar solo la URL (sin prefijo para que se detecte automáticamente)
        _ircService.sendMessage(normalizedChannel, videoUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Video subido y URL enviada')),
          );
        }
      } else {
        throw Exception('No se pudo subir el video a Cloudinary');
      }
    } catch (e) {
      print('❌ Error al subir video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir video: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes, String mimeType) async {
    try {
      // Configuración de Cloudinary (del plugin web)
      const cloudName = 'datdq7xkz';
      const uploadPreset = 'ml_default';
      const maxSize = 10 * 1024 * 1024; // 10MB
      
      // Verificar tamaño
      if (imageBytes.length > maxSize) {
        print('❌ Imagen demasiado grande: ${(imageBytes.length / 1024 / 1024).toStringAsFixed(2)} MB (máximo 10MB)');
        return null;
      }
      
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      // Crear el body como multipart
      final request = http.MultipartRequest('POST', uri);
      
      // Añadir la imagen
      final extension = mimeType.split('/')[1];
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'image.$extension',
        ),
      );
      
      // Añadir el upload preset
      request.fields['upload_preset'] = uploadPreset;
      
      print('📤 Subiendo imagen a Cloudinary... (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['secure_url'] != null) {
          final imageUrl = jsonResponse['secure_url'] as String;
          print('✅ Imagen subida a Cloudinary: $imageUrl');
          return imageUrl;
        } else {
          print('❌ Error en respuesta de Cloudinary: ${jsonResponse['error']}');
          return null;
        }
      } else {
        print('❌ Error HTTP al subir imagen: ${response.statusCode}');
        print('❌ Respuesta: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al subir imagen a Cloudinary: $e');
      return null;
    }
  }

  Future<String?> _uploadVideoToCloudinary(Uint8List videoBytes, String mimeType) async {
    try {
      // Configuración de Cloudinary (del plugin web)
      const cloudName = 'datdq7xkz';
      const uploadPreset = 'ml_default';
      const maxSize = 100 * 1024 * 1024; // 100MB para videos
      
      // Verificar tamaño
      if (videoBytes.length > maxSize) {
        print('❌ Video demasiado grande: ${(videoBytes.length / 1024 / 1024).toStringAsFixed(2)} MB (máximo 100MB)');
        return null;
      }
      
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');
      
      // Crear el body como multipart
      final request = http.MultipartRequest('POST', uri);
      
      // Añadir el video
      final extension = mimeType.split('/')[1];
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          videoBytes,
          filename: 'video.$extension',
        ),
      );
      
      // Añadir el upload preset
      request.fields['upload_preset'] = uploadPreset;
      
      print('📤 Subiendo video a Cloudinary... (${(videoBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['secure_url'] != null) {
          final videoUrl = jsonResponse['secure_url'] as String;
          print('✅ Video subido a Cloudinary: $videoUrl');
          return videoUrl;
        } else {
          print('❌ Error en respuesta de Cloudinary: ${jsonResponse['error']}');
          return null;
        }
      } else {
        print('❌ Error HTTP al subir video: ${response.statusCode}');
        print('❌ Respuesta: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al subir video a Cloudinary: $e');
      return null;
    }
  }

  Future<void> _checkClipboardForImage() async {
    // Verificar periódicamente si hay una imagen en el portapapeles
    // Esto se puede mejorar con un listener más directo
  }

  Future<void> _pasteImageFromClipboard() async {
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        // Intentar obtener imagen del portapapeles
        final imageData = await Pasteboard.image;
        
        if (imageData != null) {
          print('✅ Imagen encontrada en el portapapeles');
          
          // Convertir Uint8List a File temporal
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/pasted_image_${DateTime.now().millisecondsSinceEpoch}.png');
          await tempFile.writeAsBytes(imageData);
          
          await _processAndSendImage(tempFile);
          
          // Limpiar archivo temporal después de un delay
          Future.delayed(const Duration(seconds: 5), () {
            try {
              tempFile.deleteSync();
            } catch (e) {
              print('⚠️ No se pudo eliminar archivo temporal: $e');
            }
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay imagen en el portapapeles'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error al pegar imagen: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al pegar imagen: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _processAndSendImage(File imageFile) async {
    try {
      final channel = ref.read(currentChannelProvider);
      if (channel == null) return;

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Comprimiendo y procesando imagen...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Leer la imagen
      final originalBytes = await imageFile.readAsBytes();
      final originalSize = originalBytes.length;
      print('📸 Tamaño original de la imagen: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      
      // Detectar el tipo MIME
      final extension = imageFile.path.split('.').last.toLowerCase();
      String mimeType = 'image/png';
      if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == 'gif') {
        mimeType = 'image/gif';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      // Subir TODAS las imágenes a Cloudinary para evitar flood protection
      // IRC tiene límites estrictos y cualquier imagen en base64 causa flood
      await _uploadAndSendToCloudinary(originalBytes, mimeType, channel);
    } catch (e) {
      print('Error al procesar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar imagen: $e')),
        );
      }
    }
  }

  Future<void> _processAndSendVideo(File videoFile) async {
    try {
      final channel = ref.read(currentChannelProvider);
      if (channel == null) return;

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Procesando video...'),
              ],
            ),
            duration: Duration(seconds: 60),
          ),
        );
      }

      // Leer el video
      final originalBytes = await videoFile.readAsBytes();
      final originalSize = originalBytes.length;
      print('🎥 Tamaño original del video: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // Detectar el tipo MIME
      final extension = videoFile.path.split('.').last.toLowerCase();
      String mimeType = 'video/mp4';
      if (extension == 'webm') {
        mimeType = 'video/webm';
      } else if (extension == 'mov') {
        mimeType = 'video/quicktime';
      }

      // Subir TODOS los videos a Cloudinary
      await _uploadAndSendVideoToCloudinary(originalBytes, mimeType, channel);
    } catch (e) {
      print('Error al procesar video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar video: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool _isImageUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null) return false;
    
    // Detectar URLs de Cloudinary
    if (uri.host.contains('cloudinary.com') || uri.host.contains('res.cloudinary.com')) {
      return true;
    }
    
    final path = uri.path.toLowerCase();
    return path.endsWith('.jpg') || 
           path.endsWith('.jpeg') || 
           path.endsWith('.png') || 
           path.endsWith('.gif') || 
           path.endsWith('.webp') ||
           text.startsWith('data:image/');
  }

  bool _isVideoUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null) return false;
    
    // Detectar URLs de Cloudinary para videos
    if (uri.host.contains('cloudinary.com') || uri.host.contains('res.cloudinary.com')) {
      // Cloudinary puede servir videos, verificar si la URL contiene 'video' o tiene extensión de video
      final path = uri.path.toLowerCase();
      return path.contains('/video/') || 
             path.endsWith('.mp4') || 
             path.endsWith('.webm') || 
             path.endsWith('.mov');
    }
    
    final path = uri.path.toLowerCase();
    return path.endsWith('.mp4') || 
           path.endsWith('.webm') || 
           path.endsWith('.mov') ||
           text.startsWith('data:video/');
  }

  void _disconnect() {
    // Antes de limpiar, recordar el último canal para el login
    final currentChannel = ref.read(currentChannelProvider);
    if (currentChannel != null && currentChannel.isNotEmpty) {
      ref.read(lastChannelProvider.notifier).state = currentChannel;
    }

    _ircService.disconnect();
    ref.read(currentNicknameProvider.notifier).state = null;
    ref.read(currentChannelProvider.notifier).state = null;
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildLoadingScreen(AppTheme appTheme, String channelName) {
    return Scaffold(
      backgroundColor: appTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              appTheme.primary.withOpacity(0.15),
              appTheme.secondary.withOpacity(0.12),
              appTheme.accent.withOpacity(0.08),
              appTheme.background,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo animado
              const _ModernLoadingSpinner(),
              const SizedBox(height: 40),
              // Texto de carga
              Text(
                'Conectando a $channelName...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando canal',
                style: TextStyle(
                  fontSize: 16,
                  color: appTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              // Indicador de progreso animado
              const SizedBox(
                width: 200,
                child: _LoadingProgressBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nickname = ref.watch(currentNicknameProvider);
    print('🔄 [ChatScreen] build() - nickname from provider: "$nickname"');
    print('🔄 [ChatScreen] build() - AppBar mostrará: "como $nickname"');
    final currentChannel = ref.watch(currentChannelProvider);
    final messages = ref.watch(messagesProvider);
    final channels = ref.watch(channelsProvider);
    final isConnected = ref.watch(connectionStatusProvider);
    final appTheme = ref.watch(themeProvider);
    
    // Verificar también el estado del servicio directamente como respaldo
    final serviceConnected = _ircService.isConnected;

    // Solo redirigir a LoginScreen si realmente no está conectado
    // Y solo si ya pasó un tiempo razonable desde la inicialización (evitar bucles en Android)
    // Si estamos en proceso de conexión o hay un canal configurado, mostrar pantalla de carga
    if (!isConnected && !serviceConnected) {
      // Si hay un canal configurado o ya intentamos unirnos, mostrar carga en lugar de redirigir
      // Esto evita pantallas negras durante la transición en Android
      if (currentChannel != null || _initialJoinDone) {
        return _buildLoadingScreen(appTheme, currentChannel ?? 'Conectando...');
      }
      // Solo redirigir si realmente no hay nada configurado
      return const LoginScreen();
    }

    // Filtrar mensajes del canal actual (case-insensitive)
    final channelMessages = currentChannel != null
        ? messages
            .where((m) =>
                m.channel.toLowerCase() == currentChannel.toLowerCase())
            .toList()
        : <IRCMessage>[];

    // Añadir historial local si está cargado para este canal
    final normalizedForHistory = currentChannel?.toLowerCase();
    final history = normalizedForHistory != null
        ? (_loadedHistoryByChannel[normalizedForHistory] ?? const <IRCMessage>[])
        : const <IRCMessage>[];

    final allMessages = [
      ...history,
      ...channelMessages,
    ];

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

    // Verificar si el canal está completamente cargado
    // El canal está cargado si:
    // 1. Hay un canal actual
    // 2. El canal está en el mapa de canales (se ha unido exitosamente)
    // Nota: No verificamos si tiene usuarios porque algunos canales pueden estar vacíos
    final bool isChannelLoaded = currentChannel != null && 
        channelKey != null && 
        channels.containsKey(channelKey);

    // Si el canal no está cargado O si estamos conectados pero aún no hay canal,
    // mostrar pantalla de carga (evita pantalla negra en Android durante inicialización)
    if (!isChannelLoaded && (isConnected || serviceConnected)) {
      final channelName = currentChannel ?? 'Conectando...';
      print('🔍 [DEBUG] 🖼️  ChatScreen: Mostrando pantalla de carga - isChannelLoaded=$isChannelLoaded, isConnected=$isConnected, serviceConnected=$serviceConnected, channelName=$channelName');
      return _buildLoadingScreen(appTheme, channelName);
    }

    print('🔍 [DEBUG] 🖼️  ChatScreen: Renderizando contenido principal - isChannelLoaded=$isChannelLoaded, currentChannel=$currentChannel, channels=${channels.keys.toList()}');
    print('🔍 [DEBUG] 🖼️  ChatScreen: appTheme.background=${appTheme.background}');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _disconnect();
        }
      },
      child: Scaffold(
        backgroundColor: appTheme.background,
        appBar: AppBar(
          title: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: constraints.maxWidth > 0 ? constraints.maxWidth : 200,
                    child: _buildChannelNameWithHash(currentChannel ?? 'Cliente IRC', appTheme),
                  ),
                  if (nickname != null)
                    SizedBox(
                      width: constraints.maxWidth > 0 ? constraints.maxWidth : 200,
                      child: Text(
                        'como $nickname',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              );
            },
          ),
          backgroundColor: appTheme.primary,
          foregroundColor: appTheme.textPrimary,
          actions: [
            LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                final showFullButtons = screenWidth > 800;
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // Permitir cambiar de servidor desde el botón de estado
                          _showServerSwitchDialog();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text(
                            isConnected ? '● Conectado' : '● Desconectado',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    if (showFullButtons) ...[
                      AnimatedServiceButton(
                        appTheme: appTheme,
                        tooltip: 'Centro de Atención a Usuarios',
                        emoji: '💬',
                        label: 'CAU',
                        onPressed: () {
                          _showSupportDialog(context);
                        },
                      ),
                      AnimatedServiceButton(
                        appTheme: appTheme,
                        tooltip: 'Registro de Nick',
                        emoji: '📝',
                        label: 'Nick',
                        onPressed: () {
                          _showNickRegistrationDialog(context);
                        },
                      ),
                      AnimatedServiceButton(
                        appTheme: appTheme,
                        tooltip: 'Registro de Canal',
                        emoji: '📢',
                        label: 'Canal',
                        onPressed: () {
                          _ircService.sendServiceMessage('ChanServ', 'HELP');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Solicitando ayuda de registro de canal a ChanServ...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      AnimatedServiceButton(
                        appTheme: appTheme,
                        tooltip: 'Petición de IP Virtual',
                        emoji: '🌐',
                        label: 'IP Virtual',
                        onPressed: () {
                          _ircService.sendServiceMessage('HostServ', 'HELP');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Solicitando ayuda de IP virtual a HostServ...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      // Menú para pantallas pequeñas
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: appTheme.textPrimary),
                        onSelected: (value) {
                          switch (value) {
                            case 'cau':
                              _showSupportDialog(context);
                              break;
                            case 'nick':
                              _showNickRegistrationDialog(context);
                              break;
                            case 'canal':
                              _ircService.sendServiceMessage('ChanServ', 'HELP');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Solicitando ayuda de registro de canal a ChanServ...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              break;
                            case 'ip':
                              _ircService.sendServiceMessage('HostServ', 'HELP');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Solicitando ayuda de IP virtual a HostServ...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'cau',
                            child: Row(
                              children: [
                                Text('💬'),
                                SizedBox(width: 8),
                                Text('CAU'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'nick',
                            child: Row(
                              children: [
                                Text('📝'),
                                SizedBox(width: 8),
                                Text('Registro de Nick'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'canal',
                            child: Row(
                              children: [
                                Text('📢'),
                                SizedBox(width: 8),
                                Text('Registro de Canal'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'ip',
                            child: Row(
                              children: [
                                Text('🌐'),
                                SizedBox(width: 8),
                                Text('IP Virtual'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Buscar en historial',
                      onPressed: () => _showSearchDialog(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.palette),
                      tooltip: 'Cambiar tema',
                      onPressed: () => _showThemeSelector(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.exit_to_app),
                      tooltip: 'Salir de la aplicación',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('¿Salir de la aplicación?'),
                            content: const Text('¿Estás seguro de que deseas cerrar la aplicación?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  _disconnect();
                                  Navigator.pop(context);
                                  // Cerrar la aplicación completamente
                                  exit(0);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Salir'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      body: Builder(
        builder: (context) {
          print('🔍 [DEBUG] 🖼️  ChatScreen body: Construyendo Row con ${channels.length} canales');
          print('🔍 [DEBUG] 🖼️  ChatScreen body: currentChannel=$currentChannel, isChannelLoaded=$isChannelLoaded');
          return Row(
            children: [
              // Channels sidebar
              Expanded(
              flex: 1,
              child: Container(
                color: Colors.grey[900],
                child: Column(
                  children: [
                    // Header con gradiente
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            appTheme.primary,
                            appTheme.secondary,
                          ],
                        ),
                      ),
                      child: const Text(
                        'Canales y Mensajes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Separar canales y queries
                          final channelList = <String>[];
                          final queryList = <String>[];
                          
                          for (var channel in channels.keys) {
                            if (channel.startsWith('#')) {
                              // Filtrar canales que coincidan con el nickname del usuario
                              final currentNick = ref.read(currentNicknameProvider);
                              if (currentNick != null) {
                                final channelWithoutHash = channel.toLowerCase().replaceFirst('#', '');
                                final normalizedNick = currentNick.toLowerCase();
                                if (channelWithoutHash == normalizedNick || 
                                    channel.toLowerCase() == '#$normalizedNick') {
                                  continue; // Saltar este canal
                                }
                              }
                              channelList.add(channel);
                            } else {
                              queryList.add(channel);
                            }
                          }

                          // Favoritos y recientes
                          final favorites = ref.watch(favoritesProvider);
                          final recent = ref.watch(recentChannelsProvider);

                          final favoriteChannels = channelList
                              .where((c) => favorites.contains(c.toLowerCase()))
                              .toList();
                          final favoriteQueries = queryList
                              .where((c) => favorites.contains(c.toLowerCase()))
                              .toList();

                          final nonFavoriteChannels = channelList
                              .where((c) => !favorites.contains(c.toLowerCase()))
                              .toList();
                          final nonFavoriteQueries = queryList
                              .where((c) => !favorites.contains(c.toLowerCase()))
                              .toList();

                          // Recientes que ya no están abiertos
                          final openKeys = {
                            ...channelList.map((e) => e.toLowerCase()),
                            ...queryList.map((e) => e.toLowerCase()),
                          };
                          final recentOnly = recent
                              .where((c) => !openKeys.contains(c.toLowerCase()))
                              .toList();
                          
                          return ListView(
                            children: [
                              // Sección de Favoritos (canales y privados)
                              if (favoriteChannels.isNotEmpty || favoriteQueries.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'FAVORITOS',
                                        style: TextStyle(
                                          color: appTheme.textPrimary.withOpacity(0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...favoriteChannels.map((channel) => _buildChannelItem(
                                  context,
                                  channel,
                                  false,
                                  appTheme,
                                  currentChannel,
                                  ref,
                                )),
                                ...favoriteQueries.map((channel) => _buildChannelItem(
                                  context,
                                  channel,
                                  true,
                                  appTheme,
                                  currentChannel,
                                  ref,
                                )),
                                const SizedBox(height: 8),
                              ],

                              // Sección de Canales (no favoritos)
                              if (nonFavoriteChannels.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.tag,
                                        size: 16,
                                        color: appTheme.textPrimary.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CANALES',
                                        style: TextStyle(
                                          color: appTheme.textPrimary.withOpacity(0.6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...nonFavoriteChannels.map((channel) => _buildChannelItem(
                                  context,
                                  channel,
                                  false,
                                  appTheme,
                                  currentChannel,
                                  ref,
                                )),
                                const SizedBox(height: 8),
                              ],
                              
                              // Sección de Mensajes Privados (no favoritos)
                              if (nonFavoriteQueries.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 16,
                                        color: appTheme.accent.withOpacity(0.8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'MENSAJES PRIVADOS',
                                        style: TextStyle(
                                          color: appTheme.accent.withOpacity(0.8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...nonFavoriteQueries.map((channel) => _buildChannelItem(
                                  context,
                                  channel,
                                  true,
                                  appTheme,
                                  currentChannel,
                                  ref,
                                )),
                              ],

                              // Sección de Recientes cerrados
                              if (recentOnly.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 16,
                                        color: appTheme.textPrimary.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'RECIENTES',
                                        style: TextStyle(
                                          color: appTheme.textPrimary.withOpacity(0.6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...recentOnly.map((channel) => _buildChannelItem(
                                  context,
                                  channel,
                                  !channel.startsWith('#'),
                                  appTheme,
                                  currentChannel,
                                  ref,
                                )),
                              ],
                            ],
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
                          icon: Icon(Icons.add, color: appTheme.textPrimary),
                          label: Text('Unirse', style: TextStyle(color: appTheme.textPrimary)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appTheme.primary,
                            foregroundColor: appTheme.textPrimary,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
              child: Builder(
                builder: (context) {
                  print('🔍 [DEBUG] 🖼️  ChatScreen chat area Column: currentChannel=$currentChannel');
                  return Column(
                    children: [
                      // Topic bar con animación
                      if (currentChannel != null)
                        _buildTopicBar(currentChannel, channels, appTheme),
                      // Messages
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            print('🔍 [DEBUG] 🖼️  ChatScreen messages area: currentChannel=$currentChannel');
                        if (currentChannel == null) {
                          print('🔍 [DEBUG] 🖼️  ChatScreen: Mostrando mensaje de selección de canal');
                          return Center(
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
                          );
                        }
                        print('🔍 [DEBUG] 🖼️  ChatScreen: Construyendo Stack con fondo ASCII para canal $currentChannel');
                        print('🔍 [DEBUG] 🖼️  ChatScreen: Construyendo Stack con ${allMessages.length} mensajes');
                        // Para Android: estructura ultra-simplificada sin Stack ni fondos decorativos
                        if (Platform.isAndroid) {
                          print('🔍 [DEBUG] 🖼️  ChatScreen: Modo Android - estructura simplificada');
                          // Estructura mínima: ListView directamente sin contenedores adicionales
                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: allMessages.length,
                            itemBuilder: (context, index) {
                              print('🔍 [DEBUG] 🖼️  ChatScreen: Construyendo mensaje $index de ${allMessages.length}');
                              final message = allMessages[
                                  allMessages.length - 1 - index];
                              return _buildMessageTile(message);
                            },
                          );
                        }
                        // Para otras plataformas: estructura completa con fondos decorativos
                        return Container(
                          color: appTheme.background,
                          child: Column(
                            children: [
                              _buildPinnedMessagesBar(
                                currentChannel,
                                appTheme,
                              ),
                              Expanded(
                                child: Container(
                                  color: appTheme.background,
                                  child: Stack(
                                    children: [
                                      // Fondo decorativo
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                appTheme.primary.withOpacity(0.08),
                                                appTheme.secondary.withOpacity(0.06),
                                                appTheme.accent.withOpacity(0.04),
                                                appTheme.background,
                                              ],
                                              stops: const [0.0, 0.35, 0.65, 1.0],
                                            ),
                                          ),
                                          child: Opacity(
                                            opacity: (appTheme.name == 'Semana Santa Sevilla' || appTheme.name == 'Canal Sur') ? 0.15 : 0.38,
                                            child: Builder(
                                              builder: (context) {
                                                print('🎨 [Background] Tema activo: ${appTheme.name}');
                                                try {
                                                  if (appTheme.name == 'Semana Santa Sevilla') {
                                                    print('🎨 [Background] Mostrando logo Semana Santa Sevilla');
                                                    return const _SemanaSantaBackground();
                                                  } else if (appTheme.name == 'Canal Sur') {
                                                    print('🎨 [Background] Mostrando logo Canal Sur');
                                                    return const _CanalSurBackground();
                                                  } else {
                                                    print('🎨 [Background] Mostrando fondo ASCII');
                                                    return const _AsciiBackground();
                                                  }
                                                } catch (e) {
                                                  print('🎨 [Background] Error al renderizar fondo: $e');
                                                  return const SizedBox.shrink();
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Lista de mensajes
                                      Positioned.fill(
                                        child: ListView.builder(
                                          reverse: true,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          itemCount: allMessages.length,
                                          itemBuilder: (context, index) {
                                            print('🔍 [DEBUG] 🖼️  ChatScreen: Construyendo mensaje $index de ${allMessages.length}');
                                            final message = allMessages[
                                                allMessages.length - 1 - index];
                                            return _buildMessageTile(message);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        },
                      ),
                  ),
                  const Divider(height: 1),
                  // Typing indicator
                  if (currentChannel != null)
                    Consumer(
                      builder: (context, ref, child) {
                        final typingNick = ref.watch(typingIndicatorProvider)[currentChannel!.toLowerCase()];
                        if (typingNick == null) return const SizedBox.shrink();
                        return _buildTypingIndicator(currentChannel, appTheme, typingNick);
                      },
                    ),
                  // Input area
                  if (currentChannel != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          PopupMenuButton<String>(
                            icon: Icon(Icons.image, color: appTheme.primary),
                            tooltip: 'Adjuntar imagen',
                            onSelected: (value) {
                              if (value == 'pick') {
                                _pickAndSendImage();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'pick',
                                child: Row(
                                  children: [
                                    Icon(Icons.folder, size: 20),
                                    SizedBox(width: 8),
                                    Text('Seleccionar imagen o video'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Shortcuts(
                              shortcuts: {
                                const SingleActivator(LogicalKeyboardKey.keyV, meta: true): 
                                  const PasteImageIntent(),
                              },
                              child: Actions(
                                actions: {
                                  PasteImageIntent: CallbackAction<PasteImageIntent>(
                                    onInvoke: (intent) {
                                      _pasteImageFromClipboard();
                                      return null;
                                    },
                                  ),
                                },
                                child: FocusScope(
                                  child: TextField(
                                    controller: _messageController,
                                    decoration: InputDecoration(
                                      hintText: 'Mensaje... (Pega imágenes con Cmd+V)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      fillColor: appTheme.surface,
                                      filled: true,
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                    minLines: 1,
                                    maxLines: 3,
                                    keyboardType: TextInputType.multiline,
                                    enabled: true,
                                    readOnly: false,
                                    autofocus: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton(
                            onPressed: _sendMessage,
                            mini: true,
                            backgroundColor: appTheme.primary,
                            child: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                    ],
                  );
                },
              ),
            ),
            // Users sidebar - Solo mostrar para canales, no para queries (mensajes privados)
            if (currentChannel != null && currentChannel!.startsWith('#'))
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
                              appTheme.primary,
                              appTheme.secondary,
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
                          child: Builder(
                            builder: (context) {
                              // Obtener el canal para acceder a los modos
                              IRCChannel? currentChannelData;
                              if (channelKey != null && channels.containsKey(channelKey)) {
                                currentChannelData = channels[channelKey];
                              }
                              
                              // Organizar usuarios por tipo y ordenar
                              final sortedUsers = <String>[];
                              
                              // Función para obtener la prioridad del modo
                              int getModePriority(String? mode, bool isRobot) {
                                if (isRobot) return 5;
                                switch (mode) {
                                  case '&': return 1; // Dueño (más alto)
                                  case '@': return 2; // Operador
                                  case '%': return 3; // Halfop
                                  case '+': return 4; // Voz
                                  default: return 6; // Usuario normal
                                }
                              }
                              
                              // Ordenar usuarios por prioridad y luego alfabéticamente
                              sortedUsers.addAll(channelUsers);
                              sortedUsers.sort((a, b) {
                                final modeA = currentChannelData?.getUserMode(a);
                                final modeB = currentChannelData?.getUserMode(b);
                                final isRobotA = currentChannelData?.isRobot(a) ?? false;
                                final isRobotB = currentChannelData?.isRobot(b) ?? false;
                                
                                final priorityA = getModePriority(modeA, isRobotA);
                                final priorityB = getModePriority(modeB, isRobotB);
                                
                                if (priorityA != priorityB) {
                                  return priorityA.compareTo(priorityB);
                                }
                                return a.toLowerCase().compareTo(b.toLowerCase());
                              });
                              
                              return ListView.builder(
                                itemCount: sortedUsers.length,
                            itemBuilder: (context, index) {
                                  final user = sortedUsers[index];
                                  // Obtener el modo del usuario
                                  final userMode = currentChannelData?.getUserMode(user);
                                  final isRobot = currentChannelData?.isRobot(user) ?? false;
                                  final userIcon = _getUserIcon(userMode, isRobot);
                                  
                                  final appTheme = ref.read(themeProvider);
                                  // Generar color para el avatar
                                  final nickHash = user.hashCode;
                                  final userColor = isRobot ? const Color(0xFFFFD700) : _getUserColor(nickHash);
                                  
                              return ListTile(
                                dense: true,
                                    leading: UserAvatar(
                                      nick: user,
                                      size: 32,
                                      fallbackIcon: userIcon,
                                      gradient: isRobot
                                          ? LinearGradient(
                                              colors: [
                                                const Color(0xFFFFD700),
                                                const Color(0xFFFFA500),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : LinearGradient(
                                              colors: [
                                                userColor,
                                                userColor.withOpacity(0.7),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isRobot
                                              ? const Color(0xFFFFD700).withOpacity(0.5)
                                              : userColor.withOpacity(0.4),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                      border: isRobot
                                          ? Border.all(
                                              color: const Color(0xFFFFD700).withOpacity(0.6),
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    title: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: (isRobot || userMode != null) ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (userMode == '@' || userMode == '&') ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: appTheme.primary.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: appTheme.primary.withOpacity(0.6),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              userMode == '&' ? 'Dueño' : 'Operador',
                                              style: TextStyle(
                                                color: appTheme.primary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    onTap: () {
                                      print('🔍 [DEBUG] Tapped on user: $user (mode: $userMode)');
                                      print('🔍 [DEBUG] Calling _showUserContextMenu for: $user');
                                      try {
                                        _showUserContextMenu(context, user);
                                        print('🔍 [DEBUG] _showUserContextMenu called successfully');
                                      } catch (e, stackTrace) {
                                        print('🔍 [ERROR] Error showing user context menu: $e');
                                        print('🔍 [ERROR] Stack trace: $stackTrace');
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
        bottomNavigationBar: RadioControls(),
      ),
    );
  }

  Widget _buildMessageTile(IRCMessage message) {
    final timeFormat = DateFormat('HH:mm');
    final currentNick = ref.read(currentNicknameProvider);
    final isOwnMessage = message.nick == currentNick;
    
    if (message.isSystem) {
      // Detectar si es JOIN o PART
      final isJoin = message.message.contains('se unió');
      final isPart = message.message.contains('dejó') || message.message.contains('salió');
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isJoin
                    ? [
                        Colors.green.withOpacity(0.2),
                        Colors.greenAccent.withOpacity(0.15),
                      ]
                    : [
                        Colors.orange.withOpacity(0.2),
                        Colors.redAccent.withOpacity(0.15),
                      ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isJoin
                    ? Colors.green.withOpacity(0.4)
                    : Colors.orange.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isJoin ? Colors.green : Colors.orange)
                      .withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isJoin ? Colors.green : Colors.orange)
                        .withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isJoin ? Icons.person_add : Icons.person_remove,
                    size: 16,
                    color: isJoin ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  message.nick,
            style: TextStyle(
                    color: isJoin ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  message.message,
                  style: TextStyle(
                    color: isJoin
                        ? Colors.green[600]
                        : Colors.orange[600],
              fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Detectar si es un bot y obtener el modo del usuario
    final channelKey = message.channel.toLowerCase();
    final channels = ref.read(channelsProvider);
    final channelData = channels[channelKey];
    final isBot = channelData?.isRobot(message.nick) ?? false;
    final userMode = channelData?.getUserMode(message.nick);
    
    // Generar color basado en el hash del nickname para consistencia
    final nickHash = message.nick.hashCode;
    final userColor = isBot ? const Color(0xFFFFD700) : _getUserColor(nickHash); // Dorado para bots
    final appTheme = ref.read(themeProvider);
    final pinnedMap = ref.watch(pinnedMessagesProvider);
    final isPinned = (pinnedMap[channelKey] ?? const [])
        .any((m) =>
            m.nick == message.nick &&
            m.message == message.message &&
            m.timestamp == message.timestamp);
    
    // Obtener inicial del usuario para el avatar (o emoji para bots/modos especiales)
    final userIcon = _getUserIcon(userMode, isBot);
    final userInitial = isBot || userMode != null ? userIcon : (message.nick.isNotEmpty 
        ? message.nick[0].toUpperCase() 
        : '?');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwnMessage) ...[
            // Avatar moderno con gradiente (especial para bots) - clickeable
            GestureDetector(
              onTap: () => _showUserContextMenu(context, message.nick),
              child: UserAvatar(
                nick: message.nick,
                size: 42,
                fallbackIcon: userInitial,
                gradient: isBot
                    ? LinearGradient(
                        colors: [
                          const Color(0xFFFFD700),
                          const Color(0xFFFFA500),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          userColor,
                          userColor.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: isBot
                        ? const Color(0xFFFFD700).withOpacity(0.5)
                        : userColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isBot
                    ? Border.all(
                        color: const Color(0xFFFFD700).withOpacity(0.6),
                        width: 2,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Burbuja de mensaje moderna
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isOwnMessage 
                    ? LinearGradient(
                        colors: [
                          appTheme.primary,
                          appTheme.primary.withOpacity(0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : isBot
                        ? LinearGradient(
                            colors: [
                              const Color(0xFFFFF8DC), // Beige claro
                              const Color(0xFFFFFACD), // Limón chiffon
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              appTheme.surface,
                              appTheme.surface.withOpacity(0.95),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isOwnMessage ? 20 : 4),
                  bottomRight: Radius.circular(isOwnMessage ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isOwnMessage
                        ? appTheme.primary.withOpacity(0.3)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isOwnMessage
                    ? null
                    : isBot
                        ? Border.all(
                            color: const Color(0xFFFFD700).withOpacity(0.4),
                            width: 2,
                          )
                        : Border.all(
                            color: appTheme.textPrimary.withOpacity(0.1),
                            width: 1,
                          ),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
        children: [
                  // Nickname, hora y acciones rápidas (pin) en una fila compacta
                  Row(
                    mainAxisSize: MainAxisSize.min,
            children: [
                      GestureDetector(
                        onTap: () => _showUserContextMenu(context, message.nick),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isBot || userMode != null) ...[
                              Text('$userIcon ', style: const TextStyle(fontSize: 14)),
                            ],
              Text(
                message.nick,
                              style: TextStyle(
                                fontWeight: (isBot || userMode != null) ? FontWeight.bold : FontWeight.w600,
                                fontSize: (isBot || userMode != null) ? 15 : 14,
                                color: isOwnMessage 
                                    ? Colors.white 
                                    : isBot
                                        ? const Color(0xFFB8860B) // Dark goldenrod
                                        : userMode == '@' || userMode == '&'
                                            ? const Color(0xFFFFD700) // Dorado para ops
                                            : userMode == '%'
                                                ? const Color(0xFFFFA500) // Naranja para halfop
                                                : userMode == '+'
                                                    ? const Color(0xFF87CEEB) // Azul cielo para voz
                                                    : userColor,
                                letterSpacing: 0.2,
                                decoration: TextDecoration.underline,
                                decorationColor: isOwnMessage 
                                    ? Colors.white.withOpacity(0.5)
                                    : isBot
                                        ? const Color(0xFFB8860B).withOpacity(0.5)
                                        : userColor.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOwnMessage
                              ? Colors.white.withOpacity(0.2)
                              : appTheme.textPrimary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              timeFormat.format(message.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: isOwnMessage
                                    ? Colors.white.withOpacity(0.9)
                                    : appTheme.textPrimary.withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                ref
                                    .read(pinnedMessagesProvider.notifier)
                                    .togglePinned(message);
                              },
                              child: Icon(
                                Icons.push_pin,
                                size: 14,
                                color: isPinned
                                    ? appTheme.accent
                                    : appTheme.textPrimary
                                        .withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Contenido del mensaje con soporte para imágenes
                  _buildMessageContent(message.message, isOwnMessage, isBot: isBot),
                  // Botón de registro si es mensaje de NickServ sobre registro
                  if (_isNickRegistrationMessage(message))
                    _buildRegistrationButton(context, message),
                ],
              ),
            ),
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: 12),
            // Avatar moderno para mensajes propios
            UserAvatar(
              nick: currentNick ?? '',
              size: 42,
              fallbackIcon: currentNick != null && currentNick.isNotEmpty
                  ? currentNick[0].toUpperCase()
                  : 'Y',
              gradient: LinearGradient(
                colors: [
                  appTheme.primary,
                  appTheme.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: appTheme.primary.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Detectar si es un mensaje de NickServ sobre registro
  bool _isNickRegistrationMessage(IRCMessage message) {
    final messageLower = message.message.toLowerCase();
    final isNickServ = message.nick.toLowerCase() == 'nickserv' || 
                       message.nick.toLowerCase().contains('nick');
    return isNickServ && (
      messageLower.contains('no está registrado') ||
      messageLower.contains('no esta registrado') ||
      messageLower.contains('registrar') ||
      messageLower.contains('register') ||
      (messageLower.contains('/msg') && messageLower.contains('register'))
    );
  }

  // Botón para abrir el formulario de registro
  Widget _buildRegistrationButton(BuildContext context, IRCMessage message) {
    final appTheme = ref.read(themeProvider);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: ElevatedButton.icon(
        onPressed: () {
          _showNickRegistrationDialog(context);
        },
        icon: const Icon(Icons.person_add, size: 18),
        label: const Text('Registrar Nick'),
        style: ElevatedButton.styleFrom(
          backgroundColor: appTheme.primary,
          foregroundColor: appTheme.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildMessageContent(String messageText, bool isOwnMessage, {bool isBot = false}) {
    // Detectar si el mensaje contiene una imagen (data URI)
    if (messageText.contains('data:image/')) {
      final parts = messageText.split('data:image/');
      if (parts.length > 1) {
        final dataUri = 'data:image/${parts[1].split(' ')[0]}';
        final remainingText = parts.length > 1 && parts[1].contains(' ')
            ? parts[1].substring(parts[1].indexOf(' ') + 1)
            : '';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (messageText.startsWith('[Imagen]'))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                constraints: const BoxConstraints(
                  maxWidth: 300,
                  maxHeight: 300,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOwnMessage 
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(dataUri.split(',')[1]),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        child: const Icon(Icons.broken_image, size: 48),
                      );
                    },
                  ),
                ),
              ),
            if (remainingText.isNotEmpty)
          Text(
                remainingText,
                style: TextStyle(
                  color: isOwnMessage 
                      ? Colors.white 
                      : isBot
                          ? const Color(0xFF8B6914)
                          : ref.read(themeProvider).textPrimary,
                  fontSize: isBot ? 16 : 15,
                  height: 1.6,
                  fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: isBot ? 0.3 : 0.0,
                ),
              ),
          ],
        );
      }
    }
    
    // Detectar URLs de videos (incluyendo Cloudinary)
    final videoUrlRegex = RegExp(
      r'https?://(?:[^\s]+\.(?:mp4|webm|mov)|res\.cloudinary\.com/[^\s]*video[^\s]*)',
      caseSensitive: false,
    );
    final videoMatches = videoUrlRegex.allMatches(messageText);
    
    if (videoMatches.isNotEmpty) {
      final parts = <Widget>[];
      int lastEnd = 0;
      
      for (var match in videoMatches) {
        // Texto antes de la URL
        if (match.start > lastEnd) {
          final textBefore = messageText.substring(lastEnd, match.start);
          if (isBot && (textBefore.contains('\x03') || textBefore.contains('\x02'))) {
            final defaultColor = isOwnMessage 
                ? Colors.white 
                : isBot
                    ? const Color(0xFF8B6914)
                    : ref.read(themeProvider).textPrimary;
            final spans = IRCColorParser.parseIRCMessage(textBefore, defaultColor: defaultColor);
            parts.add(RichText(
              text: TextSpan(
                children: spans,
                style: TextStyle(
                  fontSize: isBot ? 16 : 15,
                  height: 1.6,
                  fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: isBot ? 0.3 : 0.0,
                ),
              ),
            ));
          } else {
            parts.add(Text(
              textBefore,
              style: TextStyle(
                color: isOwnMessage 
                    ? Colors.white 
                    : isBot
                        ? const Color(0xFF8B6914)
                        : ref.read(themeProvider).textPrimary,
                fontSize: isBot ? 16 : 15,
                height: 1.6,
                fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
                letterSpacing: isBot ? 0.3 : 0.0,
              ),
            ));
          }
        }
        
        // Widget del video
        parts.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 300,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOwnMessage 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Placeholder mientras carga
                  Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.black87,
                    child: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                  // Botón para abrir el video
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final url = match.group(0)!;
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white70,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Mostrar la URL del video como texto
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '🎥 Video - Toca para reproducir',
                        style: const TextStyle(
                          color: Colors.white,
                  fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                ),
              ),
            ],
          ),
            ),
          ),
        );
        
        lastEnd = match.end;
      }
      
      // Texto después de la última URL
      if (lastEnd < messageText.length) {
        final textAfter = messageText.substring(lastEnd);
        if (isBot && (textAfter.contains('\x03') || textAfter.contains('\x02'))) {
          final defaultColor = isOwnMessage 
              ? Colors.white 
              : isBot
                  ? const Color(0xFF8B6914)
                  : ref.read(themeProvider).textPrimary;
          final spans = IRCColorParser.parseIRCMessage(textAfter, defaultColor: defaultColor);
          parts.add(RichText(
            text: TextSpan(
              children: spans,
              style: TextStyle(
                fontSize: isBot ? 16 : 15,
                height: 1.6,
                fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
                letterSpacing: isBot ? 0.3 : 0.0,
              ),
            ),
          ));
        } else {
          parts.add(Text(
            textAfter,
            style: TextStyle(
              color: isOwnMessage 
                  ? Colors.white 
                  : ref.read(themeProvider).textPrimary,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ));
        }
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts,
      );
    }
    
    // Detectar URLs de imágenes (incluyendo Cloudinary)
    final imageUrlRegex = RegExp(
      r'https?://(?:[^\s]+\.(?:jpg|jpeg|png|gif|webp)|res\.cloudinary\.com/[^\s]*(?<!video)[^\s]*)',
      caseSensitive: false,
    );
    final matches = imageUrlRegex.allMatches(messageText);
    
    if (matches.isNotEmpty) {
      final parts = <Widget>[];
      int lastEnd = 0;
      
      for (var match in matches) {
        // Texto antes de la URL
        if (match.start > lastEnd) {
          final textBefore = messageText.substring(lastEnd, match.start);
          if (isBot && (textBefore.contains('\x03') || textBefore.contains('\x02'))) {
            final defaultColor = isOwnMessage 
                ? Colors.white 
                : isBot
                    ? const Color(0xFF8B6914)
                    : ref.read(themeProvider).textPrimary;
            final spans = IRCColorParser.parseIRCMessage(textBefore, defaultColor: defaultColor);
            parts.add(RichText(
              text: TextSpan(
                children: spans,
                style: TextStyle(
                  fontSize: isBot ? 16 : 15,
                  height: 1.6,
                  fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: isBot ? 0.3 : 0.0,
                ),
              ),
            ));
          } else {
            parts.add(Text(
              textBefore,
              style: TextStyle(
                color: isOwnMessage 
                    ? Colors.white 
                    : isBot
                        ? const Color(0xFF8B6914)
                        : ref.read(themeProvider).textPrimary,
                fontSize: isBot ? 16 : 15,
                height: 1.6,
                fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
                letterSpacing: isBot ? 0.3 : 0.0,
              ),
            ));
          }
        }
        
        // Imagen
        parts.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            constraints: const BoxConstraints(
              maxWidth: 300,
              maxHeight: 300,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOwnMessage 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                match.group(0)!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: const CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.broken_image, size: 48),
                  );
                },
              ),
            ),
          ),
        );
        
        lastEnd = match.end;
      }
      
      // Texto después de la última URL
      if (lastEnd < messageText.length) {
        final textAfter = messageText.substring(lastEnd);
        if (isBot && (textAfter.contains('\x03') || textAfter.contains('\x02'))) {
          final defaultColor = isOwnMessage 
              ? Colors.white 
              : isBot
                  ? const Color(0xFF8B6914)
                  : ref.read(themeProvider).textPrimary;
          final spans = IRCColorParser.parseIRCMessage(textAfter, defaultColor: defaultColor);
          parts.add(RichText(
            text: TextSpan(
              children: spans,
              style: TextStyle(
                fontSize: isBot ? 16 : 15,
                height: 1.6,
                fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
                letterSpacing: isBot ? 0.3 : 0.0,
              ),
            ),
          ));
        } else {
          parts.add(Text(
            textAfter,
            style: TextStyle(
              color: isOwnMessage 
                  ? Colors.white 
                  : isBot
                      ? const Color(0xFF8B6914)
                      : ref.read(themeProvider).textPrimary,
              fontSize: isBot ? 16 : 15,
              height: 1.6,
              fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
              letterSpacing: isBot ? 0.3 : 0.0,
            ),
          ));
        }
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts,
      );
    }
    
    // Mensaje normal sin imágenes
    final appTheme = ref.read(themeProvider);
    
    // Siempre parsear códigos IRC si están presentes (para bots y mensajes con formato)
    // También parsear si es un bot para asegurar que se limpien todos los códigos
    if (isBot || messageText.contains('\x03') || messageText.contains('\x02') || 
        messageText.contains('\x1F') || messageText.contains('\x1D') || messageText.contains('\x0F')) {
      final defaultColor = isOwnMessage 
          ? Colors.white 
          : isBot
              ? const Color(0xFF8B6914) // Marrón oscuro para mejor contraste
              : appTheme.textPrimary;
      
      final spans = IRCColorParser.parseIRCMessage(messageText, defaultColor: defaultColor);
      
      // Si no se generaron spans (mensaje vacío después de parsear), mostrar mensaje limpio
      if (spans.isEmpty || (spans.length == 1 && spans[0].text?.isEmpty == true)) {
        final cleaned = IRCColorParser.stripIRCFormatting(messageText);
        if (cleaned.isNotEmpty) {
          return Text(
            cleaned,
            style: TextStyle(
              color: defaultColor,
              fontSize: isBot ? 16 : 15,
              height: 1.6,
              fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
              letterSpacing: isBot ? 0.3 : 0.0,
            ),
          );
        }
      }
      
      return RichText(
        text: TextSpan(
          children: spans,
          style: TextStyle(
            fontSize: isBot ? 16 : 15,
            height: 1.6,
            fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
            letterSpacing: isBot ? 0.3 : 0.0,
          ),
        ),
      );
    }
    
    return Text(
      messageText,
      style: TextStyle(
        color: isOwnMessage 
            ? Colors.white 
            : appTheme.textPrimary,
        fontSize: 15,
        height: 1.6,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  // Obtener el emoticono según el modo del usuario
  String _getUserIcon(String? mode, bool isRobot) {
    final emojiConfig = ref.read(emojiConfigProvider);
    if (isRobot) return emojiConfig.robotEmoji;
    switch (mode) {
      case '@': // Operador
        return emojiConfig.operatorEmoji;
      case '&': // Dueño/Founder
        return emojiConfig.ownerEmoji;
      case '%': // Halfop
        return emojiConfig.halfopEmoji;
      case '+': // Voz
        return emojiConfig.voiceEmoji;
      default: // Sin voz
        return emojiConfig.userEmoji;
    }
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

  // Widget para mostrar el nombre del canal con el # en color dorado para Semana Santa Sevilla
  Widget _buildChannelNameWithHash(
    String channelName,
    AppTheme appTheme, {
    bool isSelected = false,
    bool isQuery = false,
    double fontSize = 16,
  }) {
    // Si el tema es "Semana Santa Sevilla" y el canal empieza con "#", mostrar el # en dorado
    final isSemanaSantaTheme = appTheme.name == 'Semana Santa Sevilla';
    
    if (isSemanaSantaTheme && channelName.startsWith('#')) {
      final hashSymbol = '#';
      final channelWithoutHash = channelName.substring(1);
      
      return RichText(
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: hashSymbol,
              style: TextStyle(
                color: appTheme.accent, // Dorado
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: fontSize,
              ),
            ),
            TextSpan(
              text: channelWithoutHash,
              style: TextStyle(
                color: isSelected
                    ? (isQuery ? appTheme.accent : appTheme.accent)
                    : appTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      );
    }
    
    // Para otros temas o canales sin #, mostrar normalmente
    return Text(
      channelName,
      style: TextStyle(
        color: isSelected
            ? (isQuery ? appTheme.accent : appTheme.accent)
            : appTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: fontSize,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  // Widget para mostrar el topic con animación moderna
  Widget _buildTopicBar(String? channel, Map<String, IRCChannel> channels, AppTheme appTheme) {
    if (channel == null) return const SizedBox.shrink();
    
    final isQuery = !channel.startsWith('#');
    
    // Buscar el canal de forma case-insensitive
    IRCChannel? channelData;
    for (var entry in channels.entries) {
      if (entry.key.toLowerCase() == channel.toLowerCase()) {
        channelData = entry.value;
        break;
      }
    }
    
    final topic = channelData?.topic;
    
    // Si es un mensaje privado y no tiene topic, mostrar "Mensaje Privado con <nick>"
    if (isQuery && (topic == null || topic.isEmpty)) {
      // El nick es el nombre del canal (query)
      final nick = channel;
      return Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              appTheme.accent.withOpacity(0.2),
              appTheme.accent.withOpacity(0.1),
            ],
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person,
                size: 16,
                color: appTheme.accent,
              ),
              const SizedBox(width: 6),
          Text(
                'Mensaje Privado con ',
                style: TextStyle(
                  color: appTheme.textSecondary,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                nick,
                style: TextStyle(
                  color: appTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (topic == null || topic.isEmpty) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              appTheme.primary.withOpacity(0.2),
              appTheme.secondary.withOpacity(0.2),
            ],
          ),
        ),
        child: Center(
          child: Text(
            'Sin tema establecido',
            style: TextStyle(
              color: appTheme.textSecondary,
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
            appTheme.primary,
            appTheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.primary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: double.infinity,
          height: 40,
          child: AnimatedTopicText(topic: topic),
        ),
      ),
    );
  }

  Widget _buildChannelItem(
    BuildContext context,
    String channel,
    bool isQuery,
    AppTheme appTheme,
    String? currentChannel,
    WidgetRef ref,
  ) {
    final normalizedCurrent = currentChannel?.toLowerCase();
    final normalizedChannel = channel.toLowerCase();
    final isSelected = normalizedChannel == normalizedCurrent;
    final unreadCount =
        ref.watch(unreadMessagesProvider)[normalizedChannel] ?? 0;
    final hasUnread = unreadCount > 0;
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.contains(normalizedChannel);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? (isQuery 
                ? appTheme.accent.withOpacity(0.2)
                : appTheme.accent.withOpacity(0.3))
            : (isQuery
                ? appTheme.accent.withOpacity(hasUnread ? 0.15 : 0.05)
                : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: isQuery ? appTheme.accent : appTheme.accent,
                width: 2,
              )
            : (isQuery
                ? Border.all(
                    color: hasUnread 
                        ? appTheme.accent.withOpacity(0.6)
                        : appTheme.accent.withOpacity(0.3),
                    width: hasUnread ? 2 : 1,
                  )
                : null),
      ),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Colors.transparent,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isQuery
                ? appTheme.accent.withOpacity(isSelected ? 0.3 : 0.15)
                : appTheme.primary.withOpacity(isSelected ? 0.3 : 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isQuery ? Icons.person : Icons.tag,
            color: isSelected
                ? (isQuery ? appTheme.accent : appTheme.accent)
                : (isQuery 
                    ? appTheme.accent.withOpacity(0.8)
                    : appTheme.textPrimary.withOpacity(0.7)),
            size: 18,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              flex: 1,
              child: _buildChannelNameWithHash(
                isQuery ? channel : channel,
                appTheme,
                isSelected: isSelected,
                isQuery: isQuery,
                fontSize: 13,
              ),
            ),
            if (isQuery) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: appTheme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PRIV',
                  style: TextStyle(
                    color: appTheme.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (hasUnread) ...[
                const SizedBox(width: 4),
                _UnreadBadge(
                  count: unreadCount,
                  appTheme: appTheme,
                ),
              ],
            ],
          ],
        ),
        onTap: () {
          // Cambiar al canal, marcar como leído y añadir a recientes
          ref.read(currentChannelProvider.notifier).state = channel;
          ref.read(lastChannelProvider.notifier).state = channel;
          ref.read(recentChannelsProvider.notifier).addRecent(channel);
          ref.read(unreadMessagesProvider.notifier).markAsRead(channel);
        },
        onLongPress: () {
          _showChannelNotificationMenu(context, channel);
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isQuery && hasUnread) ...[
              _UnreadBadge(
                count: unreadCount,
                appTheme: appTheme,
              ),
              const SizedBox(width: 4),
            ],
            IconButton(
              tooltip: isFavorite
                  ? 'Quitar de favoritos'
                  : 'Marcar como favorito',
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite
                    ? Colors.amber
                    : appTheme.textPrimary.withOpacity(0.5),
                size: 18,
              ),
              onPressed: () {
                ref
                    .read(favoritesProvider.notifier)
                    .toggleFavorite(channel);
              },
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: appTheme.textPrimary.withOpacity(0.5),
                size: 16,
              ),
              onPressed: () {
                // Si es un query (no empieza con #), solo removerlo de la lista
                if (isQuery) {
                  _ircService.allChannels.remove(channel);
                  ref.read(channelsProvider.notifier).updateChannels();
                  final normalizedCurrentChannel =
                      currentChannel?.toLowerCase();
                  if (normalizedCurrentChannel == normalizedChannel) {
                    ref.read(currentChannelProvider.notifier).state = null;
                  }
                } else {
                  // Si es un canal, hacer PART
                  _ircService.partChannel(channel);
                  ref.read(channelsProvider.notifier).updateChannels();
                  final normalizedCurrentChannel =
                      currentChannel?.toLowerCase();
                  if (normalizedCurrentChannel == normalizedChannel) {
                    ref.read(currentChannelProvider.notifier).state = null;
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Barra superior con los mensajes fijados del canal actual
  Widget _buildPinnedMessagesBar(String? currentChannel, AppTheme appTheme) {
    if (currentChannel == null || currentChannel.isEmpty) {
      return const SizedBox.shrink();
    }

    final pinnedMap = ref.watch(pinnedMessagesProvider);
    final pinned = pinnedMap[currentChannel.toLowerCase()] ?? const [];

    if (pinned.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: appTheme.surface.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(
            color: appTheme.textPrimary.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: appTheme.accent),
              const SizedBox(width: 6),
              Text(
                'Mensajes fijados',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: appTheme.textPrimary.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pinned.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final msg = pinned[index];
                return Container(
                  width: 260,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: appTheme.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: appTheme.accent.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.nick,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: appTheme.accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    appTheme.textPrimary.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: appTheme.textPrimary.withOpacity(0.6),
                        ),
                        tooltip: 'Quitar mensaje fijado',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          ref
                              .read(pinnedMessagesProvider.notifier)
                              .togglePinned(msg);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    final appTheme = ref.read(themeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirse a Canal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            // Placeholder más claro y en español
            hintText: '#canal',
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
              backgroundColor: appTheme.primary,
              foregroundColor: appTheme.textPrimary,
            ),
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                appTheme.primary.withOpacity(0.95),
                appTheme.secondary.withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [appTheme.accent, appTheme.secondary],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '💬',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Centro de Ayuda GlobalChat',
                            style: TextStyle(
                              color: appTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Elige cómo quieres contactar con soporte.',
                            style: TextStyle(
                              color: appTheme.textSecondary.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close,
                          color: appTheme.textPrimary.withOpacity(0.7)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _joinChannel('Ayuda');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Uniéndote al canal #Ayuda...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.accent,
                          foregroundColor: appTheme.textPrimary,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.forum, size: 18),
                            SizedBox(width: 8),
                            Text('Entrar en #Ayuda'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          const url =
                              'http://soporte.globalchat.org/index.php?a=add';
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('No se pudo abrir la página de soporte'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: appTheme.textPrimary,
                          side: BorderSide(
                            color: appTheme.textPrimary.withOpacity(0.6),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.support_agent, size: 18),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Enviar ticket en la web',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'La web de soporte se abrirá en tu navegador para crear un ticket en el Centro de Ayuda de IRC GlobalChat.',
                  style: TextStyle(
                    color: appTheme.textSecondary.withOpacity(0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNickRegistrationDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool _obscurePassword = true;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  appTheme.surface,
                  appTheme.surface.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: appTheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con gradiente
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appTheme.primary,
                          appTheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '📝',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registro de Nick',
                                style: TextStyle(
                                  color: appTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Registra tu nick en el servidor IRC',
                                style: TextStyle(
                                  color: appTheme.textPrimary.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contenido del formulario
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Campo Nick
                        TextFormField(
                          controller: nickController,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Nick a registrar',
                            hintText: 'Ej: MiNick',
                            prefixIcon: Icon(Icons.person, color: appTheme.primary),
                            filled: true,
                            fillColor: appTheme.surface.withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary, width: 2),
                            ),
                            labelStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.7)),
                            hintStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.5)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa un nick';
                            }
                            if (value.contains(' ')) {
                              return 'El nick no puede contener espacios';
                            }
                            if (value.length < 3) {
                              return 'El nick debe tener al menos 3 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Campo Password
                        TextFormField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            hintText: 'Ingresa una contraseña segura',
                            prefixIcon: Icon(Icons.lock, color: appTheme.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: appTheme.textPrimary.withOpacity(0.7),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: appTheme.surface.withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary, width: 2),
                            ),
                            labelStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.7)),
                            hintStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.5)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa una contraseña';
                            }
                            if (value.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Campo Email
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'tu@email.com',
                            prefixIcon: Icon(Icons.email, color: appTheme.primary),
                            filled: true,
                            fillColor: appTheme.surface.withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary, width: 2),
                            ),
                            labelStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.7)),
                            hintStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.5)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa un email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Por favor ingresa un email válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        // Botones
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: appTheme.textPrimary.withOpacity(0.7),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    appTheme.primary,
                                    appTheme.secondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: appTheme.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    // Enviar comando de registro a NickServ
                                    final nick = nickController.text.trim();
                                    final password = passwordController.text;
                                    final email = emailController.text.trim();
                                    
                                    // Comando típico de registro: REGISTER password email
                                    _ircService.sendServiceMessage(
                                      'NickServ',
                                      'REGISTER $password $email',
                                    );
                                    
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Registrando nick "$nick" en NickServ...'),
                                        backgroundColor: appTheme.primary,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Aceptar',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUserContextMenu(BuildContext context, String nick) {
    print('🔍 [MENU] _showUserContextMenu called for nick: "$nick"');
    final appTheme = ref.read(themeProvider);
    final currentNick = ref.read(currentNicknameProvider);
    print('🔍 [MENU] Current nick: "$currentNick", Selected nick: "$nick"');
    
    final isOwnNick = currentNick != null && currentNick.toLowerCase() == nick.toLowerCase();
    
    // Si es el propio nick, mostrar menú de configuración de perfil
    if (isOwnNick) {
      _showProfileConfigMenu(context, nick);
      return;
    }
    
    print('🔍 [MENU] Showing menu for nick: "$nick"');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              appTheme.surface,
              appTheme.surface.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appTheme.primary,
                      appTheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: UserAvatar(
                        nick: nick,
                        size: 60,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nick,
                            style: TextStyle(
                              color: appTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Opciones de usuario',
                            style: TextStyle(
                              color: appTheme.textPrimary.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Opciones del menú
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: appTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.message, color: Colors.orange),
                ),
                title: const Text('Mensaje privado'),
                subtitle: const Text('Abrir conversación privada'),
                onTap: () {
                  Navigator.pop(context);
                  // Abrir mensaje privado
                  final queryNick = nick.toLowerCase();
                  if (!_ircService.allChannels.containsKey(queryNick)) {
                    _ircService.allChannels[queryNick] = IRCChannel(name: queryNick);
                  }
                  ref.read(currentChannelProvider.notifier).state = queryNick;
                  ref.read(channelsProvider.notifier).updateChannels();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: Colors.purple),
                ),
                title: const Text('Ver perfil'),
                subtitle: const Text('Ver información completa del usuario'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(nick: nick),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info, color: Colors.blue),
                ),
                title: const Text('Whois'),
                subtitle: const Text('Solicitar información del usuario'),
                onTap: () {
                  Navigator.pop(context);
                  _ircService.sendWhois(nick);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Solicitando información de $nick...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.block, color: Colors.red),
                ),
                title: const Text('Ignorar'),
                subtitle: const Text('Ignorar mensajes de este usuario'),
                onTap: () {
                  Navigator.pop(context);
                  _ircService.sendIgnore(nick);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ignorando mensajes de $nick...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                title: const Text('Designorar'),
                subtitle: const Text('Dejar de ignorar mensajes de este usuario'),
                onTap: () {
                  Navigator.pop(context);
                  _ircService.sendUnignore(nick);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Dejando de ignorar mensajes de $nick...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileConfigMenu(BuildContext context, String nick) {
    final appTheme = ref.read(themeProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              appTheme.surface,
              appTheme.surface.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appTheme.primary,
                      appTheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mi Perfil',
                            style: TextStyle(
                              color: appTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configuración de cuenta',
                            style: TextStyle(
                              color: appTheme.textPrimary.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Opciones del menú
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                title: const Text('Ver mi perfil'),
                subtitle: const Text('Ver información completa de mi cuenta'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(nick: nick),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit, color: Colors.teal),
                ),
                title: const Text('Cambiar Nick'),
                subtitle: const Text('Cambiar mi nombre de usuario'),
                onTap: () {
                  Navigator.pop(context);
                  _showChangeNickDialog(context, nick);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_circle, color: Colors.purple),
                ),
                title: const Text('Configurar Avatar'),
                subtitle: const Text('Gestionar avatar en panel de GlobalChat'),
                onTap: () {
                  Navigator.pop(context);
                  // Abrir panel de GlobalChat en navegador
                  launchUrl(
                    Uri.parse('https://xmlrpc.globalchat.org/panel-anope/panel-perfil-usuario.html'),
                    mode: LaunchMode.externalApplication,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Abriendo panel de configuración de perfil...'),
                      backgroundColor: appTheme.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.palette, color: Colors.green),
                ),
                title: const Text('Configuración de Tema'),
                subtitle: const Text('Cambiar tema de la aplicación'),
                onTap: () {
                  Navigator.pop(context);
                  _showThemeSelector(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.pink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.emoji_emotions, color: Colors.pink),
                ),
                title: const Text('Configurar Emoticonos'),
                subtitle: const Text('Personalizar emoticonos de roles de usuario'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmojiConfigScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info, color: Colors.orange),
                ),
                title: const Text('Whois'),
                subtitle: const Text('Ver información de mi cuenta'),
                onTap: () {
                  Navigator.pop(context);
                  _ircService.sendWhois(nick);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Solicitando información de $nick...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeNickDialog(BuildContext context, String currentNick) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController(text: currentNick);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Cambiar Nick',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: TextField(
          controller: nickController,
          autofocus: true,
          style: TextStyle(color: appTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Nuevo nick',
            labelStyle: TextStyle(color: appTheme.primary),
            hintText: 'Escribe el nuevo nick',
            hintStyle: TextStyle(color: appTheme.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: appTheme.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: appTheme.primary, width: 2),
            ),
            filled: true,
            fillColor: appTheme.background,
          ),
          onSubmitted: (value) {
            final newNick = value.trim();
            if (newNick.isNotEmpty && newNick != currentNick) {
              _ircService.changeNick(newNick);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cambiando nick a $newNick...'),
                  duration: const Duration(seconds: 2),
                ),
              );
            } else if (newNick.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Por favor ingresa un nick válido'),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: appTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final newNick = nickController.text.trim();
              if (newNick.isNotEmpty && newNick != currentNick) {
                _ircService.changeNick(newNick);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cambiando nick a $newNick...'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else if (newNick.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor ingresa un nick válido'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Cambiar',
              style: TextStyle(
                color: appTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    final currentTheme = ref.read(themeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Tema'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppTheme.themes.length,
            itemBuilder: (context, index) {
              final theme = AppTheme.themes[index];
              final isSelected = theme.name == currentTheme.name;
              
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.accent,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  theme.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(theme);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Widget para mostrar el indicador de typing
  Widget _buildTypingIndicator(String channel, AppTheme appTheme, String typingNick) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: appTheme.surface.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: appTheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(appTheme.accent),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$typingNick está escribiendo...',
            style: TextStyle(
              color: appTheme.textSecondary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// Fondo tipo ASCII con letras en gradiente cálido inspirado en la imagen de referencia
class _AsciiBackground extends StatelessWidget {
  const _AsciiBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AsciiBackgroundPainter(),
    );
  }
}

// Fondo con logo de la Semana Santa de Sevilla
class _SemanaSantaBackground extends StatelessWidget {
  const _SemanaSantaBackground();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.network(
        'http://www.semana-santa.org/wp-content/uploads/2017/01/logo.png',
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          // Si falla la carga, mostrar un placeholder
          return const SizedBox.shrink();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// Fondo con logo de Canal Sur
class _CanalSurBackground extends StatelessWidget {
  const _CanalSurBackground();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.network(
        'https://www.canalsur.es/resources/archivos_offline/2020/3/27/158530909845827_LogoCSRTV.jpg',
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          // Log del error para debug
          print('❌ [CanalSurBackground] Error cargando logo: $error');
          print('❌ [CanalSurBackground] StackTrace: $stackTrace');
          // Mostrar un placeholder en lugar de ocultar
          return Container(
            color: Colors.transparent,
            child: const Center(
              child: Icon(Icons.image_not_supported, color: Colors.grey, size: 64),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ [CanalSurBackground] Logo cargado correctamente');
            return child;
          }
          // Mostrar un indicador de carga
          return Container(
            color: Colors.transparent,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}

// Badge parpadeante para mensajes no leídos
class _UnreadBadge extends StatefulWidget {
  final int count;
  final AppTheme appTheme;

  const _UnreadBadge({
    required this.count,
    required this.appTheme,
  });

  @override
  State<_UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<_UnreadBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: widget.appTheme.accent.withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: widget.appTheme.accent.withOpacity(_animation.value * 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            widget.count > 99 ? '99+' : widget.count.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

// Widget de spinner moderno animado
class _ModernLoadingSpinner extends ConsumerStatefulWidget {
  const _ModernLoadingSpinner();

  @override
  ConsumerState<_ModernLoadingSpinner> createState() => _ModernLoadingSpinnerState();
}

class _ModernLoadingSpinnerState extends ConsumerState<_ModernLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159, // 360 grados en radianes
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    appTheme.primary,
                    appTheme.secondary,
                    appTheme.accent,
                    appTheme.primary,
                  ],
                  stops: const [0.0, 0.33, 0.66, 1.0],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appTheme.background,
                ),
                child: Center(
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 50,
                    color: appTheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Widget de barra de progreso animada
class _LoadingProgressBar extends ConsumerStatefulWidget {
  const _LoadingProgressBar();

  @override
  ConsumerState<_LoadingProgressBar> createState() => _LoadingProgressBarState();
}

class _LoadingProgressBarState extends ConsumerState<_LoadingProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: appTheme.surface,
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: _controller.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        appTheme.primary,
                        appTheme.secondary,
                        appTheme.accent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AsciiBackgroundPainter extends CustomPainter {
  static const String _asciiLogo = '''
   _____ _       _           _  _____ _           _   
  / ____| |     | |         | |/ ____| |         | |  
 | |  __| | ___ | |__   __ _| | |    | |__   __ _| |_ 
 | | |_ | |/ _ \\| '_ \\ / _` | | |    | '_ \\ / _` | __|
 | |__| | | (_) | |_) | (_| | | |____| | | | (_| | |_ 
  \\_____|_|\\___/|_.__/ \\__,_|_|\\_____|_| |_|\\__,_|\\__|

          IRC Network · Desde 1999-2025                
  ''';

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final baseRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = const LinearGradient(
      colors: [
        Color(0xFFFFD700), // Dorado brillante
        Color(0xFFFFF44F), // Amarillo intenso
        Color(0xFFFFD700), // Dorado
        Color(0xFF4169E1), // Azul Royal
        Color(0xFFE31E24), // Rojo GlobalChat
        Color(0xFFFFD700), // Dorado
        Color(0xFFFFF44F), // Amarillo brillante
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(baseRect);

    final logoPaint = Paint()..shader = gradient;
    final logoStyle = TextStyle(
      fontFamily: 'Courier New', // monoespaciada muy estable
      fontFamilyFallback: const ['Menlo', 'SFMono-Regular', 'monospace'],
      fontSize: size.width * 0.022, // aún más pequeña para evitar cualquier wrap
      fontWeight: FontWeight.w700,
      height: 1.0, // filas alineadas
      foreground: logoPaint,
      letterSpacing: 0, // sin espaciado extra
    );

    final logoPainter = TextPainter(
      text: TextSpan(text: _asciiLogo, style: logoStyle),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      textWidthBasis: TextWidthBasis.longestLine,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
    )..layout(maxWidth: size.width * 0.85); // margen mayor para evitar descolocación

    final logoOffset = Offset(
      (size.width - logoPainter.width) / 2,
      (size.height - logoPainter.height) / 2,
    );

    // Opacidad ligera y sensación de texto de fondo
    canvas.saveLayer(baseRect, Paint()..color = Colors.white.withOpacity(0.32));
    logoPainter.paint(canvas, logoOffset);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

