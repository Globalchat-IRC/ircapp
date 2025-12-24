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
import '../services/emoji_service.dart';
import '../models/whois_info.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/update_banner.dart';  // Sistema de actualizaciones
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/video_provider.dart';
import '../widgets/video_terms_dialog.dart';
import '../widgets/video_report_dialog.dart';
import '../widgets/reputation_badge.dart';
import '../widgets/user_profile_dialog.dart';
import '../widgets/email_verification_dialog.dart';
import '../models/user_role.dart';
import '../models/video_report.dart' as video_report_model;
import '../services/video_conference_service.dart' show ConferenceType;
import '../services/video_database_service.dart';

// Clase auxiliar para items del menú IRCop
class _IRCOpMenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _IRCOpMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

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
  bool _showEmojiPicker = false;
  final FocusNode _messageFocusNode = FocusNode();
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  List<IRCMessage> _searchResults = [];
  
  // Autocompletado de comandos
  List<Map<String, String>> _commandSuggestions = [];
  int _selectedSuggestionIndex = -1;
  bool _showCommandSuggestions = false;
  
  // Autocompletado de nicks
  List<String> _nickSuggestions = [];
  int _selectedNickIndex = -1;
  bool _showNickSuggestions = false;
  
  // Información de versión
  String _appVersion = '';
  int _nickStartPosition = -1; // Posición donde empieza el nick que se está autocompletando
  
  // Perfil de usuario para videoconferencias
  UserProfile? _userProfile;
  
  // Lista de comandos disponibles con sus descripciones
  static final List<Map<String, String>> _availableCommands = [
    {'command': 'join', 'description': 'Unirse a un canal', 'usage': '/join <canal>'},
    {'command': 'part', 'description': 'Salir de un canal', 'usage': '/part [canal]'},
    {'command': 'msg', 'description': 'Enviar mensaje privado', 'usage': '/msg <nick> <mensaje>'},
    {'command': 'query', 'description': 'Abrir mensaje privado', 'usage': '/query <nick> [mensaje]'},
    {'command': 'whois', 'description': 'Información de usuario', 'usage': '/whois <nick>'},
    {'command': 'nick', 'description': 'Cambiar nick', 'usage': '/nick <nuevonick>'},
    {'command': 'ignore', 'description': 'Ignorar usuario', 'usage': '/ignore <nick>'},
    {'command': 'unignore', 'description': 'Dejar de ignorar', 'usage': '/unignore <nick>'},
    {'command': 'kick', 'description': 'Expulsar usuario', 'usage': '/kick <nick> [razón]'},
    {'command': 'ban', 'description': 'Banear usuario', 'usage': '/ban <nick>'},
    {'command': 'unban', 'description': 'Desbanear usuario', 'usage': '/unban <nick>'},
    {'command': 'mode', 'description': 'Cambiar modos del canal', 'usage': '/mode <modos> [target]'},
    {'command': 'voice', 'description': 'Dar voz a usuario', 'usage': '/voice <nick>'},
    {'command': 'v', 'description': 'Dar voz (atajo)', 'usage': '/v <nick>'},
    {'command': 'devoice', 'description': 'Quitar voz', 'usage': '/devoice <nick>'},
    {'command': '-v', 'description': 'Quitar voz (atajo)', 'usage': '/-v <nick>'},
    {'command': 'halfop', 'description': 'Dar halfop', 'usage': '/halfop <nick>'},
    {'command': 'h', 'description': 'Dar halfop (atajo)', 'usage': '/h <nick>'},
    {'command': 'dehalfop', 'description': 'Quitar halfop', 'usage': '/dehalfop <nick>'},
    {'command': '-h', 'description': 'Quitar halfop (atajo)', 'usage': '/-h <nick>'},
    {'command': 'oper', 'description': 'Autenticarse como IRCop', 'usage': '/oper <nick> <contraseña>'},
    {'command': 'topic', 'description': 'Cambiar topic del canal', 'usage': '/topic [nuevo topic]'},
    {'command': 'who', 'description': 'Listar usuarios con info', 'usage': '/who [canal]'},
    {'command': 'list', 'description': 'Listar canales', 'usage': '/list [patrón]'},
    {'command': 'names', 'description': 'Listar usuarios del canal', 'usage': '/names [canal]'},
    {'command': 'away', 'description': 'Establecer ausencia', 'usage': '/away [mensaje]'},
    {'command': 'back', 'description': 'Volver de ausencia', 'usage': '/back'},
    {'command': 'me', 'description': 'Acción (/me)', 'usage': '/me <acción>'},
    {'command': 'notice', 'description': 'Enviar NOTICE', 'usage': '/notice <nick/canal> <mensaje>'},
    {'command': 'links', 'description': 'Lista de servidores (IRCop)', 'usage': '/links'},
    {'command': 'stats', 'description': 'Estadísticas del servidor (IRCop)', 'usage': '/stats <tipo>'},
    {'command': 'trace', 'description': 'Rastrear ruta (IRCop)', 'usage': '/trace <usuario/servidor>'},
    {'command': 'map', 'description': 'Mapa de la red (IRCop)', 'usage': '/map'},
    {'command': 'motd', 'description': 'Mensaje del día', 'usage': '/motd'},
    {'command': 'version', 'description': 'Versión del servidor', 'usage': '/version'},
    {'command': 'admin', 'description': 'Info de administración', 'usage': '/admin'},
    {'command': 'lusers', 'description': 'Estadísticas de usuarios', 'usage': '/lusers'},
    {'command': 'time', 'description': 'Hora del servidor', 'usage': '/time'},
    {'command': 'rehash', 'description': 'Recargar configuración (IRCop)', 'usage': '/rehash'},
  ];

  @override
  void initState() {
    super.initState();
    _ircService = ref.read(ircServiceProvider);
    
    print('🎬 [ChatScreen] Initialized');
    print('🎬 [ChatScreen] isConnected=${_ircService.isConnected}');
    
    // Cargar información de versión
    _loadAppVersion();
    
    // Inicializar perfil de usuario para videoconferencias
    _initializeUserProfile();
    
    // Listen for user list changes
    _ircService.addUserListListener(_onUserListChanged);
    
    // Listen for topic changes
    _ircService.addTopicListener(_onTopicChanged);
    
    // Listen for new messages to auto-open private messages
    _ircService.addMessageListener(_onMessageReceived);
    
    // Listen for nickname changes
    _ircService.addNickChangeListener(_onNickChanged);
    
    // Listen for IRCop identification
    _ircService.addIRCOpListener(_onIRCOpIdentified);
    
    // Listener para autocompletado de comandos
    _messageController.addListener(_onMessageTextChanged);
    
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
      Future.delayed(const Duration(milliseconds: 2000), () async {
        if (!mounted) return;
        if (_initialJoinDone) return;

        // Esperar explícitamente a que los favoritos se inicialicen completamente
        try {
          final favoritesNotifier = ref.read(favoritesProvider.notifier);
          // Acceder al método waitForInitialization usando dynamic
          final dynamic notifier = favoritesNotifier;
          if (notifier.runtimeType.toString().contains('FavoritesNotifier')) {
            await notifier.waitForInitialization();
            print('✅ [ChatScreen] Favoritos inicializados completamente');
          }
        } catch (e) {
          print('⚠️  [ChatScreen] Error esperando inicialización de favoritos: $e');
        }
        
        // Esperar un poco más para asegurar que los favoritos se hayan cargado completamente
        await Future.delayed(const Duration(milliseconds: 300));
        
        final favoritesNow = ref.read(favoritesProvider).toList();
        print('📍 [ChatScreen] ========== AUTOJOIN DE CANALES ==========');
        print('📍 [ChatScreen] Favoritos cargados del provider: $favoritesNow');
        print('📍 [ChatScreen] Total de favoritos: ${favoritesNow.length}');
        
        // Filtrar solo canales válidos (que empiecen con #)
        final validFavorites = favoritesNow.where((fav) => fav.startsWith('#')).toList();
        print('📍 [ChatScreen] Favoritos válidos (que empiezan con #): $validFavorites');
        print('📍 [ChatScreen] Total de favoritos válidos: ${validFavorites.length}');
        
        // TEMPORALMENTE DESHABILITADO: Autojoin de favoritos
        // El usuario puede unirse manualmente a los canales que quiera
        // Esto evita que canales no deseados se unan automáticamente
        _initialJoinDone = true;
        print('📍 [ChatScreen] ✅ Autojoin de favoritos DESHABILITADO. Uniéndose solo a canal por defecto: $targetChannel');
        print('📍 [ChatScreen] ℹ️  Si quieres unirte a favoritos, hazlo manualmente desde el menú');
        _joinChannel(targetChannel);
        
        // CÓDIGO ORIGINAL (comentado para debugging):
        // if (validFavorites.isNotEmpty) {
        //   _initialJoinDone = true;
        //   print('📍 [ChatScreen] ⚠️  AUTOJOIN: Uniéndose a canales favoritos válidos: $validFavorites');
        //   for (final fav in validFavorites) {
        //     print('📍 [ChatScreen]   → Auto-uniéndose a: $fav');
        //     _joinChannel(fav);
        //   }
        // } else {
        //   _initialJoinDone = true;
        //   print('📍 [ChatScreen] ✅ No hay favoritos válidos, uniéndose solo a canal por defecto: $targetChannel');
        //   _joinChannel(targetChannel);
        // }
        print('📍 [ChatScreen] ===========================================');
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

  void _onIRCOpIdentified() {
    if (mounted) {
      // Forzar actualización del estado para que el botón se actualice
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ Te has identificado como operador IRC exitosamente',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
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
      
      // Añadir a recientes el canal de cualquier mensaje recibido
      ref.read(recentChannelsProvider.notifier).addRecent(messageChannel);
      
      // Notificaciones y sonidos según tipo de mensaje y reglas
      final settings = ref.read(notificationSettingsProvider);
      final level = settings.levelForChannel(messageChannel);
      final isPrivate = !messageChannel.startsWith('#');
      final currentNick = ref.read(currentNicknameProvider);
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

  // Función para manejar cambios en el texto del mensaje (autocompletado)
  void _onMessageTextChanged() {
    final text = _messageController.text;
    final cursorPosition = _messageController.selection.baseOffset;
    
    // Autocompletado de comandos (si empieza con "/")
    if (text.startsWith('/') && text.length > 1) {
      final commandPart = text.substring(1).toLowerCase().trim();
      
      // Si hay un espacio, ya no mostrar sugerencias de comandos (el usuario está escribiendo argumentos)
      if (commandPart.contains(' ')) {
        setState(() {
          _showCommandSuggestions = false;
          _commandSuggestions = [];
          _selectedSuggestionIndex = -1;
        });
        // Pero podríamos mostrar sugerencias de nicks si estamos en un canal
        _checkNickAutocomplete(text, cursorPosition);
        return;
      }
      
      // Filtrar comandos que coincidan
      final suggestions = _ChatScreenState._availableCommands
          .where((cmd) => cmd['command']!.toLowerCase().startsWith(commandPart))
          .take(10) // Limitar a 10 sugerencias
          .toList();
      
      setState(() {
        _commandSuggestions = suggestions;
        _showCommandSuggestions = suggestions.isNotEmpty;
        _selectedSuggestionIndex = -1;
        _showNickSuggestions = false;
        _nickSuggestions = [];
        _selectedNickIndex = -1;
      });
    } else {
      // No es un comando, ocultar sugerencias de comandos
      setState(() {
        _showCommandSuggestions = false;
        _commandSuggestions = [];
        _selectedSuggestionIndex = -1;
      });
      
      // Verificar autocompletado de nicks
      _checkNickAutocomplete(text, cursorPosition);
    }
  }
  
  // Función para verificar y mostrar autocompletado de nicks
  void _checkNickAutocomplete(String text, int cursorPosition) {
    // Obtener el canal actual y sus usuarios
    final currentChannel = ref.read(currentChannelProvider);
    if (currentChannel == null || !currentChannel.startsWith('#')) {
      setState(() {
        _showNickSuggestions = false;
        _nickSuggestions = [];
        _selectedNickIndex = -1;
      });
      return;
    }
    
    final channels = ref.read(channelsProvider);
    final normalizedCurrentChannel = currentChannel.toLowerCase();
    String? channelKey;
    try {
      channelKey = channels.keys.firstWhere(
        (key) => key.toLowerCase() == normalizedCurrentChannel,
      );
    } catch (e) {
      setState(() {
        _showNickSuggestions = false;
        _nickSuggestions = [];
        _selectedNickIndex = -1;
      });
      return;
    }
    
    if (channelKey == null || !channels.containsKey(channelKey)) {
      setState(() {
        _showNickSuggestions = false;
        _nickSuggestions = [];
        _selectedNickIndex = -1;
      });
      return;
    }
    
    final channelUsers = channels[channelKey]!.users;
    if (channelUsers.isEmpty) {
      setState(() {
        _showNickSuggestions = false;
        _nickSuggestions = [];
        _selectedNickIndex = -1;
      });
      return;
    }
    
    // Encontrar la palabra actual donde está el cursor
    // Buscar hacia atrás desde el cursor para encontrar el inicio de la palabra
    int wordStart = cursorPosition;
    while (wordStart > 0 && text[wordStart - 1] != ' ' && text[wordStart - 1] != '@') {
      wordStart--;
    }
    
    // Si hay un '@' antes del cursor, también considerar eso como inicio
    if (wordStart > 0 && text[wordStart - 1] == '@') {
      wordStart--;
    }
    
    // Obtener la palabra actual
    final wordEnd = cursorPosition;
    final currentWord = text.substring(wordStart, wordEnd).trim();
    
    // Si la palabra está vacía o es muy corta, no mostrar sugerencias
    if (currentWord.isEmpty || currentWord.length < 1) {
      setState(() {
        _showNickSuggestions = false;
        _nickSuggestions = [];
        _selectedNickIndex = -1;
        _nickStartPosition = -1;
      });
      return;
    }
    
    // Remover '@' si está presente
    final searchTerm = currentWord.startsWith('@') 
        ? currentWord.substring(1).toLowerCase() 
        : currentWord.toLowerCase();
    
    // Filtrar nicks que coincidan
    final suggestions = channelUsers
        .where((nick) => nick.toLowerCase().startsWith(searchTerm))
        .take(10) // Limitar a 10 sugerencias
        .toList();
    
    if (suggestions.isNotEmpty) {
      setState(() {
        _nickSuggestions = suggestions;
        _showNickSuggestions = true;
        _selectedNickIndex = -1;
        _nickStartPosition = wordStart;
      });
    } else {
      setState(() {
        _showNickSuggestions = false;
        _nickSuggestions = [];
        _selectedNickIndex = -1;
        _nickStartPosition = -1;
      });
    }
  }
  
  // Función para seleccionar un nick del autocompletado
  void _selectNickSuggestion(int index) {
    if (index >= 0 && index < _nickSuggestions.length && _nickStartPosition >= 0) {
      final selectedNick = _nickSuggestions[index];
      final currentText = _messageController.text;
      final cursorPosition = _messageController.selection.baseOffset;
      
      // Reemplazar la palabra actual con el nick seleccionado
      final beforeWord = currentText.substring(0, _nickStartPosition);
      final afterWord = currentText.substring(cursorPosition);
      
      // Añadir '@' si la palabra original empezaba con '@'
      final nickToInsert = currentText[_nickStartPosition] == '@' 
          ? '@$selectedNick ' 
          : '$selectedNick ';
      
      final newText = beforeWord + nickToInsert + afterWord;
      final newCursorPosition = beforeWord.length + nickToInsert.length;
      
      _messageController.text = newText;
      _messageController.selection = TextSelection.collapsed(offset: newCursorPosition);
      
      setState(() {
        _showNickSuggestions = false;
        _nickSuggestions = [];
        _selectedNickIndex = -1;
        _nickStartPosition = -1;
      });
    }
  }

  // Función para seleccionar un comando del autocompletado
  void _selectCommandSuggestion(int index) {
    if (index >= 0 && index < _commandSuggestions.length) {
      final command = _commandSuggestions[index]['command']!;
      final usage = _commandSuggestions[index]['usage']!;
      
      // Reemplazar el texto actual con el comando completo
      final currentText = _messageController.text;
      final slashIndex = currentText.indexOf('/');
      
      if (slashIndex != -1) {
        // Obtener el texto antes del "/"
        final beforeSlash = currentText.substring(0, slashIndex);
        // Construir el nuevo texto con el comando y un espacio
        final newText = '$beforeSlash/$command ';
        _messageController.text = newText;
        _messageController.selection = TextSelection.collapsed(offset: newText.length);
      }
      
      setState(() {
        _showCommandSuggestions = false;
        _commandSuggestions = [];
        _selectedSuggestionIndex = -1;
      });
    }
  }
  
  // Cargar información de versión de la app
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
      print('📦 [ChatScreen] App version: $_appVersion');
    } catch (e) {
      print('❌ [ChatScreen] Error loading app version: $e');
    }
  }
  
  // Inicializar perfil de usuario para videoconferencias
  Future<void> _initializeUserProfile() async {
    final nickname = ref.read(currentNicknameProvider);
    if (nickname == null) return;
    
    try {
      final db = ref.read(videoDatabaseProvider);
      
      // Intentar cargar perfil existente
      var profile = await db.getUserProfile(nickname);
      
      if (profile == null) {
        // Crear nuevo perfil
        profile = UserProfile(
          nick: nickname,
          role: _ircService.isIRCOp ? UserRole.ircop : UserRole.user,
          emailVerified: false,
          reputation: 50,
        );
        
        // Guardar en BD
        await db.saveUserProfile(profile);
        print('👤 [VIDEO] Perfil creado para: $nickname');
      } else {
        print('👤 [VIDEO] Perfil cargado desde BD: $nickname (Rep: ${profile.reputation})');
      }
      
      setState(() {
        _userProfile = profile;
      });
      
      // Actualizar provider
      ref.read(currentUserProfileProvider.notifier).state = _userProfile;
      
    } catch (e) {
      print('❌ [VIDEO] Error al inicializar perfil: $e');
      // Fallback: crear perfil en memoria
      setState(() {
        _userProfile = UserProfile(
          nick: nickname,
          role: _ircService.isIRCOp ? UserRole.ircop : UserRole.user,
          emailVerified: false,
          reputation: 50,
        );
      });
    }
  }
  
  // Iniciar videoconferencia en canal
  Future<void> _iniciarVideoconferenciaCanal() async {
    try {
      final videoService = ref.read(videoConferenceServiceProvider);
      final currentChannel = ref.read(currentChannelProvider);
      
      if (currentChannel == null || _userProfile == null) {
        _mostrarMensajeError('Error al iniciar videoconferencia');
        return;
      }
      
      // Verificar si aceptó términos
      if (!_userProfile!.hasAcceptedVideoTerms) {
        final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => VideoTermsDialog(
            onAccept: () => Navigator.pop(context, true),
            onReject: () => Navigator.pop(context, false),
          ),
        );
        
        if (accepted != true) return;
        
        // Guardar que aceptó términos
        setState(() {
          _userProfile = _userProfile!.copyWith(hasAcceptedVideoTerms: true);
          ref.read(currentUserProfileProvider.notifier).state = _userProfile;
        });
      }
      
      // Verificar restricciones
      if (!_userProfile!.canStartConference) {
        _mostrarMensajeError('No tienes permisos para iniciar conferencias');
        return;
      }
      
      // Mostrar diálogo de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Iniciando videoconferencia...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      
      // Iniciar conferencia
      await videoService.startChannelConference(
        channel: currentChannel,
        userNick: _userProfile!.nick,
        userProfile: _userProfile!,
      );
      
      // Cerrar diálogo de carga
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Enviar mensaje al canal
      _ircService.sendMessage(
        currentChannel,
        '🎥 Ha iniciado una videoconferencia. ¡Únete! /join-video',
      );
      
      print('✅ [VIDEO] Videoconferencia iniciada en $currentChannel');
      
    } catch (e) {
      print('❌ [VIDEO] Error al iniciar videoconferencia: $e');
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga si está abierto
        _mostrarMensajeError('Error: $e');
      }
    }
  }
  
  // Iniciar videollamada privada
  Future<void> _iniciarVideollamadaPrivada(String otherNick) async {
    try {
      final videoService = ref.read(videoConferenceServiceProvider);
      
      if (_userProfile == null) {
        _mostrarMensajeError('Error al iniciar videollamada');
        return;
      }
      
      // Verificar si aceptó términos
      if (!_userProfile!.hasAcceptedVideoTerms) {
        final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => VideoTermsDialog(
            onAccept: () => Navigator.pop(context, true),
            onReject: () => Navigator.pop(context, false),
          ),
        );
        
        if (accepted != true) return;
        
        // Guardar que aceptó términos
        setState(() {
          _userProfile = _userProfile!.copyWith(hasAcceptedVideoTerms: true);
          ref.read(currentUserProfileProvider.notifier).state = _userProfile;
        });
      }
      
      // Verificar restricciones
      final restriccionRazon = _userProfile!.videoRestrictionReason;
      if (restriccionRazon != null) {
        _mostrarMensajeError(restriccionRazon);
        return;
      }
      
      // Generar sala única
      final roomName = 'globalchat-private-${DateTime.now().millisecondsSinceEpoch}';
      
      // Enviar invitación por privado
      _ircService.sendPrivateMessage(
        otherNick,
        '🎥 Te invita a una videollamada: $roomName',
      );
      
      // Mostrar diálogo
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Iniciando videollamada...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      
      // Unirse a la sala
      await videoService.joinConference(
        roomName: roomName,
        userNick: _userProfile!.nick,
        userProfile: _userProfile!,
        type: ConferenceType.private, // Videollamada privada
      );
      
      // Cerrar diálogo
      if (mounted) {
        Navigator.pop(context);
      }
      
      print('✅ [VIDEO] Videollamada iniciada con $otherNick');
      
    } catch (e) {
      print('❌ [VIDEO] Error al iniciar videollamada: $e');
      if (mounted) {
        Navigator.pop(context);
        _mostrarMensajeError('Error: $e');
      }
    }
  }
  
  // Mostrar mensaje de error
  void _mostrarMensajeError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
  
  // Obtener nick con emoticono de video si está en conferencia
  String _getNickWithVideoEmoji(String nick) {
    final videoService = ref.read(videoConferenceServiceProvider);
    final status = videoService.getUserVideoStatus(nick);
    if (status != null) {
      return '${status.emoji} $nick';
    }
    return nick;
  }
  
  // Mostrar perfil de usuario
  void _showUserProfile(String nick) {
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(nick: nick),
    );
  }
  
  // Mostrar diálogo de verificación de email
  void _showEmailVerification() {
    final nickname = ref.read(currentNicknameProvider);
    if (nickname == null) return;
    
    showDialog(
      context: context,
      builder: (context) => EmailVerificationDialog(
        nick: nickname,
        onVerified: () {
          // Recargar perfil después de verificar
          _initializeUserProfile();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ ¡Email verificado! Tus restricciones han sido removidas.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _ircService.removeUserListListener(_onUserListChanged);
    _ircService.removeTopicListener(_onTopicChanged);
    _ircService.removeMessageListener(_onMessageReceived);
    _ircService.removeNickChangeListener(_onNickChanged);
    _messageController.removeListener(_onMessageTextChanged);
    _messageController.dispose();
    _channelController.dispose();
    _messageFocusNode.dispose();
    _searchController.dispose();
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

  void _sendMessage({bool forceImmediate = false}) {
    final channel = ref.read(currentChannelProvider);
    if (channel == null || _messageController.text.isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    
    // Detectar comandos que empiezan con /
    if (message.startsWith('/')) {
      _handleCommand(message);
      return;
    }

    // Obtener el delay configurado (0 si se fuerza envío inmediato)
    final delaySeconds = forceImmediate ? 0 : ref.read(messageSendDelayProvider);
    print('🔍 [ChatScreen] Delay configurado: ${delaySeconds}s ${forceImmediate ? "(forzado inmediato)" : ""}');
    
    // Normalizar el nombre del canal antes de enviar
    final normalizedChannel = channel.toLowerCase();
    
    // Si el canal no empieza con #, es un query (mensaje privado)
    if (normalizedChannel.startsWith('#')) {
      _ircService.sendMessage(normalizedChannel, message, delaySeconds: delaySeconds);
    } else {
      // Es un query, enviar mensaje privado
      _ircService.sendPrivateMessage(normalizedChannel, message, delaySeconds: delaySeconds);
    }
    
    // Añadir a recientes también al enviar mensaje
    ref.read(recentChannelsProvider.notifier).addRecent(normalizedChannel);
    
    // Trigger UI update
    ref.read(messagesProvider.notifier);
  }
  
  // Forzar el envío inmediato del mensaje pendiente más reciente
  void _forceSendPendingMessage() {
    final channel = ref.read(currentChannelProvider);
    if (channel == null) return;
    
    final normalizedChannel = channel.toLowerCase();
    bool success;
    
    if (normalizedChannel.startsWith('#')) {
      success = _ircService.forceSendPendingMessage(normalizedChannel);
    } else {
      success = _ircService.forceSendPendingPrivateMessage(normalizedChannel);
    }
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Mensaje enviado inmediatamente'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
        // Mostrar ventana de resultados cuando llegue la información
        _showWhoisResultsWindow(nick);
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
        
      case 'kick':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /kick <nick> [razón]'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        final reason = args.length > 1 ? args.sublist(1).join(' ') : null;
        
        _ircService.kickUser(currentChannel, nick, reason);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expulsando $nick${reason != null ? " (razón: $reason)" : ""}...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'ban':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /ban <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        _ircService.banUser(currentChannel, nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Baneando $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'unban':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /unban <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        _ircService.unbanUser(currentChannel, nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Desbaneando $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'mode':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /mode <modos> [target]\nEjemplo: /mode +o nick (dar op)'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final modes = args[0].trim();
        final target = args.length > 1 ? args.sublist(1).join(' ') : null;
        
        _ircService.setChannelMode(currentChannel, modes, target);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cambiando modo: $modes${target != null ? " $target" : ""}...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'voice':
      case 'v':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /voice <nick> o /v <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        _ircService.setChannelMode(currentChannel, '+v', nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dando voz a $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'devoice':
      case '-v':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /devoice <nick> o /-v <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        _ircService.setChannelMode(currentChannel, '-v', nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quitando voz a $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'halfop':
      case 'h':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /halfop <nick> o /h <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        _ircService.setChannelMode(currentChannel, '+h', nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dando halfop a $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'dehalfop':
      case '-h':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /dehalfop <nick> o /-h <nick>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        _ircService.setChannelMode(currentChannel, '-h', nick);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quitando halfop a $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'oper':
        if (args.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /oper <nick> <contraseña>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final operNick = args[0].trim();
        final operPassword = args.sublist(1).join(' ').trim();
        
        if (operNick.isEmpty || operPassword.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor ingresa un nick y contraseña válidos'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        _ircService.oper(operNick, operPassword);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Intentando autenticarse como operador IRC...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'topic':
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null || !currentChannel.startsWith('#')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        if (args.isEmpty) {
          // Mostrar el topic actual
          final channels = ref.read(channelsProvider);
          final normalized = currentChannel.toLowerCase();
          final channelKey = channels.keys.firstWhere(
            (key) => key.toLowerCase() == normalized,
            orElse: () => normalized,
          );
          
          if (channels.containsKey(channelKey) && channels[channelKey]!.topic != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Topic: ${channels[channelKey]!.topic}'),
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Este canal no tiene topic'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
        
        final topic = args.join(' ');
        _ircService.setChannelTopic(currentChannel, topic);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cambiando topic a: $topic...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'who':
        if (args.isEmpty) {
          final currentChannel = ref.read(currentChannelProvider);
          if (currentChannel == null || !currentChannel.startsWith('#')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Uso: /who <canal> o estar en un canal'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
          _ircService.sendWho(currentChannel);
          _showWhoResultsWindow(currentChannel);
        } else {
          final channel = args[0].trim();
          _ircService.sendWho(channel);
          _showWhoResultsWindow(channel);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitando información de usuarios...'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
        
      case 'list':
        final pattern = args.isNotEmpty ? args.join(' ') : null;
        _ircService.sendList(pattern);
        _showListResultsWindow(pattern);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Solicitando lista de canales${pattern != null ? " (patrón: $pattern)" : ""}...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'names':
        if (args.isEmpty) {
          final currentChannel = ref.read(currentChannelProvider);
          if (currentChannel == null || !currentChannel.startsWith('#')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Uso: /names <canal> o estar en un canal'),
                duration: Duration(seconds: 2),
              ),
            );
            return;
          }
          _ircService.sendNames(currentChannel);
          _showNamesResultsWindow(currentChannel);
        } else {
          final channel = args[0].trim();
          _ircService.sendNames(channel);
          _showNamesResultsWindow(channel);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitando lista de usuarios...'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
        
      case 'away':
        final message = args.isNotEmpty ? args.join(' ') : null;
        _ircService.sendAway(message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message != null ? 'Mensaje de ausencia establecido: $message' : 'Mensaje de ausencia establecido'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      case 'back':
        _ircService.sendBack();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volviendo de ausencia...'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
        
      case 'me':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /me <acción>\nEjemplo: /me saluda a todos'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
        
        final currentChannel = ref.read(currentChannelProvider);
        if (currentChannel == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes estar en un canal o query para usar este comando'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final action = args.join(' ');
        _ircService.sendMe(currentChannel, action);
        break;
        
      case 'notice':
        if (args.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /notice <nick/canal> <mensaje>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final target = args[0].trim();
        final message = args.sublist(1).join(' ');
        _ircService.sendNotice(target, message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enviando NOTICE a $target...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      // Comandos IRCop
      case 'links':
        _ircService.linksCommand();
        _showIRCOpResultsWindow('LINKS', 'Lista de Servidores');
        break;
        
      case 'stats':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /stats <tipo>\nEjemplo: /stats c (comandos), /stats u (usuarios), etc.'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
        final type = args[0].trim();
        _ircService.statsCommand(type);
        _showIRCOpResultsWindow('STATS $type', 'Estadísticas del Servidor');
        break;
        
      case 'trace':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /trace <usuario/servidor>'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        final target = args.join(' ');
        _ircService.traceTarget(target);
        _showIRCOpResultsWindow('TRACE $target', 'Rastreo de Ruta');
        break;
        
      case 'map':
        _ircService.mapCommand();
        _showIRCOpResultsWindow('MAP', 'Mapa de la Red');
        break;
        
      case 'motd':
        _ircService.motdCommand();
        _showIRCOpResultsWindow('MOTD', 'Mensaje del Día');
        break;
        
      case 'version':
        _ircService.versionCommand();
        _showIRCOpResultsWindow('VERSION', 'Versión del Servidor');
        break;
        
      case 'admin':
        _ircService.adminCommand();
        _showIRCOpResultsWindow('ADMIN', 'Información de Administración');
        break;
        
      case 'lusers':
        _ircService.lusersCommand();
        _showIRCOpResultsWindow('LUSERS', 'Estadísticas de Usuarios');
        break;
        
      case 'time':
        _ircService.timeCommand();
        _showIRCOpResultsWindow('TIME', 'Hora del Servidor');
        break;
        
      case 'rehash':
        _ircService.rehashServer();
        _showIRCOpResultsWindow('REHASH', 'Recarga de Configuración');
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

  // Ventana para mostrar resultados de /whois
  void _showWhoisResultsWindow(String nick) {
    // Esperar a que llegue la información de whois
    Function(WhoisInfo)? listener;
    listener = (info) {
      if (info.nick.toLowerCase() == nick.toLowerCase() && mounted) {
        if (listener != null) {
          _ircService.removeWhoisListener(listener);
        }
        _displayWhoisResults(info);
      }
    };
    _ircService.addWhoisListener(listener);
  }

  void _displayWhoisResults(WhoisInfo info) {
    final appTheme = ref.read(themeProvider);
    
    // Detectar si es un robot
    final isRobot = _isRobotUser(info);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Row(
          children: [
            Icon(
              isRobot ? Icons.smart_toy : Icons.person,
              color: isRobot ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              'Información de ${info.nick}',
              style: TextStyle(color: appTheme.textPrimary),
            ),
            if (isRobot) ...[
              const SizedBox(width: 8),
              const Text('🤖', style: TextStyle(fontSize: 20)),
            ],
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.username != null || info.host != null) ...[
                _buildInfoRow('Usuario', '${info.username ?? "N/A"}@${info.host ?? "N/A"}'),
                const SizedBox(height: 8),
              ],
              if (info.realName != null) ...[
                _buildInfoRow('Nombre real', info.realName!),
                const SizedBox(height: 8),
              ],
              if (info.server != null) ...[
                _buildInfoRow('Servidor', info.server!),
                const SizedBox(height: 8),
              ],
              if (info.serverInfo != null) ...[
                _buildInfoRow('Info del servidor', info.serverInfo!),
                const SizedBox(height: 8),
              ],
              if (info.isStaff) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Staff: ${info.staffRole ?? "Operador IRC"}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (info.idleSeconds != null) ...[
                _buildInfoRow('Tiempo inactivo', '${info.idleSeconds}s'),
                const SizedBox(height: 8),
              ],
              if (info.signonTime != null) ...[
                _buildInfoRow('Conectado desde', _formatDateTime(info.signonTime!)),
                const SizedBox(height: 8),
              ],
              if (info.channels != null && info.channels!.isNotEmpty) ...[
                _buildInfoRow('Canales', info.channels!.join(', ')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(color: appTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final appTheme = ref.read(themeProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              color: appTheme.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: appTheme.textPrimary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Ventana para mostrar resultados de /list
  void _showListResultsWindow(String? pattern) {
    Function(List<Map<String, dynamic>>)? listener;
    listener = (listResults) {
      if (mounted) {
        if (listener != null) {
          _ircService.removeListListener(listener);
        }
        _displayListResults(listResults, pattern);
      }
    };
    _ircService.addListListener(listener);
  }

  void _displayListResults(List<Map<String, dynamic>> results, String? pattern) {
    final appTheme = ref.read(themeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.list, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Lista de Canales${pattern != null ? " ($pattern)" : ""}',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? Text(
                  'No se encontraron canales',
                  style: TextStyle(color: appTheme.textSecondary),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final channel = results[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        channel['channel'] ?? '',
                        style: TextStyle(
                          color: appTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        channel['topic'] ?? 'Sin topic',
                        style: TextStyle(
                          color: appTheme.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: appTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${channel['users'] ?? 0}',
                          style: TextStyle(
                            color: appTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _joinChannel(channel['channel'] ?? '');
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(color: appTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  // Ventana para mostrar resultados de /who
  void _showWhoResultsWindow(String channel) {
    Function(List<Map<String, dynamic>>)? listener;
    listener = (whoResults) {
      if (mounted) {
        if (listener != null) {
          _ircService.removeWhoListener(listener);
        }
        _displayWhoResults(whoResults, channel);
      }
    };
    _ircService.addWhoListener(listener);
  }

  void _displayWhoResults(List<Map<String, dynamic>> results, String channel) {
    final appTheme = ref.read(themeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.people, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Usuarios en $channel',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? Text(
                  'No se encontraron usuarios',
                  style: TextStyle(color: appTheme.textSecondary),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final user = results[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        user['nick'] ?? '',
                        style: TextStyle(
                          color: appTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${user['username'] ?? ""}@${user['host'] ?? ""}',
                            style: TextStyle(
                              color: appTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (user['realname'] != null && user['realname'].toString().isNotEmpty)
                            Text(
                              user['realname'],
                              style: TextStyle(
                                color: appTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                      trailing: Text(
                        user['status'] ?? '',
                        style: TextStyle(
                          color: appTheme.primary,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(color: appTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  // Ventana para mostrar resultados de /names (mejorada)
  void _showNamesResultsWindow(String channel) {
    final appTheme = ref.read(themeProvider);
    final channels = ref.read(channelsProvider);
    final normalized = channel.toLowerCase();
    final channelKey = channels.keys.firstWhere(
      (key) => key.toLowerCase() == normalized,
      orElse: () => normalized,
    );
    
    if (!channels.containsKey(channelKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canal no encontrado'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final channelObj = channels[channelKey]!;
    final users = channelObj.users;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.people, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              'Usuarios en $channel',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: users.isEmpty
              ? Text(
                  'No hay usuarios en este canal',
                  style: TextStyle(color: appTheme.textSecondary),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final mode = channelObj.getUserMode(user);
                    return ListTile(
                      dense: true,
                      leading: mode != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getModeColor(mode).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                mode,
                                style: TextStyle(
                                  color: _getModeColor(mode),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : null,
                      title: Text(
                        user,
                        style: TextStyle(
                          color: appTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showUserContextMenu(context, user);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cerrar',
              style: TextStyle(color: appTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case '@':
        return Colors.red;
      case '&':
        return Colors.purple;
      case '%':
        return Colors.orange;
      case '+':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  // Ventana para mostrar resultados de comandos IRCop
  void _showIRCOpResultsWindow(String command, String title) {
    Function(List<String>)? listener;
    listener = (results) {
      if (mounted) {
        if (listener != null) {
          _ircService.removeIRCOpCommandListener(listener);
        }
        _displayIRCOpResults(results, command, title);
      }
    };
    _ircService.addIRCOpCommandListener(listener);
  }

  void _displayIRCOpResults(List<String> results, String command, String title) {
    final appTheme = ref.read(themeProvider);
    
    // Función para limpiar y formatear los mensajes
    String _formatMessage(String message) {
      // Remover prefijos numéricos y códigos al inicio (ej: "14config.CONFIG_RELOAD 03")
      String cleaned = message;
      
      // Intentar extraer solo la parte del mensaje después de [info], [error], etc.
      final infoMatch = RegExp(r'\[(info|error|warn|debug)\]\s*(.+)$', caseSensitive: false).firstMatch(message);
      if (infoMatch != null) {
        cleaned = infoMatch.group(2) ?? message;
      }
      
      // Si no hay match, intentar remover prefijos comunes
      if (cleaned == message) {
        // Remover prefijos como "14config.CONFIG_RELOAD 03"
        cleaned = message.replaceFirst(RegExp(r'^\d+\w+\.\w+\s+\d+\s+'), '');
        // Remover tags [info], [error], etc. si están al inicio
        cleaned = cleaned.replaceFirst(RegExp(r'^\[(info|error|warn|debug)\]\s*', caseSensitive: false), '');
      }
      
      return cleaned.trim();
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.info, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: appTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No se recibieron resultados',
                    style: TextStyle(
                      color: appTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : Container(
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: appTheme.textSecondary.withOpacity(0.2),
                    ),
                    itemBuilder: (context, index) {
                      final message = results[index];
                      final formatted = _formatMessage(message);
                      final isError = message.toLowerCase().contains('[error]') || 
                                     message.toLowerCase().contains('error') ||
                                     message.toLowerCase().contains('failed');
                      final isSuccess = message.toLowerCase().contains('loaded') ||
                                       message.toLowerCase().contains('completed') ||
                                       message.toLowerCase().contains('success');
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isError 
                                  ? Icons.error_outline 
                                  : isSuccess 
                                      ? Icons.check_circle_outline 
                                      : Icons.info_outline,
                              size: 16,
                              color: isError 
                                  ? Colors.red 
                                  : isSuccess 
                                      ? Colors.green 
                                      : appTheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formatted,
                                style: TextStyle(
                                  color: isError 
                                      ? Colors.red.shade300 
                                      : isSuccess 
                                          ? Colors.green.shade300 
                                          : appTheme.textPrimary,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: appTheme.primary),
            label: Text(
              'Cerrar',
              style: TextStyle(color: appTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  // Detectar si un usuario es un robot basándose en su información de whois
  bool _isRobotUser(WhoisInfo info) {
    final nick = info.nick.toLowerCase();
    final username = info.username?.toLowerCase() ?? '';
    final host = info.host?.toLowerCase() ?? '';
    final realName = info.realName?.toLowerCase() ?? '';
    final server = info.server?.toLowerCase() ?? '';
    
    return nick.contains('robot') ||
           username.contains('robot') ||
           host.contains('robot') ||
           realName.contains('robot') ||
           server.contains('robot');
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
          leading: nickname != null
              ? GestureDetector(
                  onTap: () {
                    _showProfileConfigMenu(context, nickname!);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: UserAvatar(
                      nick: nickname!,
                      size: 40,
                    ),
                  ),
                )
              : null,
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
                    // Botón de búsqueda
                    IconButton(
                      icon: Icon(_showSearch ? Icons.close : Icons.search, color: appTheme.textPrimary),
                      tooltip: 'Buscar mensajes',
                      onPressed: () {
                        setState(() {
                          _showSearch = !_showSearch;
                          if (!_showSearch) {
                            _searchController.clear();
                            _searchResults = [];
                          }
                        });
                      },
                    ),
                    // Botón de IRCop (siempre visible)
                    Builder(
                      builder: (context) {
                        final isIRCOp = _ircService.isIRCOp;
                        return IconButton(
                          icon: Icon(
                            Icons.admin_panel_settings, 
                            color: isIRCOp ? Colors.orange : Colors.orange.withOpacity(0.6),
                          ),
                          tooltip: isIRCOp ? 'Menú IRCop (Identificado)' : 'Menú IRCop',
                          onPressed: () {
                            _showIRCOpMenu(context);
                          },
                        );
                      },
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
                          _showChannelRegistrationDialog(context);
                        },
                      ),
                      AnimatedServiceButton(
                        appTheme: appTheme,
                        tooltip: 'Petición de IP Virtual',
                        emoji: '🌐',
                        label: 'IP Virtual',
                        onPressed: () {
                          _showVirtualIPDialog(context);
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
                              _showVirtualIPDialog(context);
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
      body: Stack(
        children: [
          // Contenido principal
          Builder(
            builder: (context) {
              print('🔍 [DEBUG] 🖼️  ChatScreen body: Construyendo Row con ${channels.length} canales');
              print('🔍 [DEBUG] 🖼️  ChatScreen body: currentChannel=$currentChannel, isChannelLoaded=$isChannelLoaded');
              return Column(
              children: [
                // Banner de actualización
                const UpdateBanner(),
                
                // Contenido principal
                Expanded(
                  child: Row(
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
                        
                        // Mostrar búsqueda si está activa
                        if (_showSearch) {
                          return _buildSearchWidget(allMessages, appTheme);
                        }
                        
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
                          IconButton(
                            icon: Icon(Icons.emoji_emotions, color: appTheme.primary),
                            tooltip: 'Emoticonos',
                            onPressed: () {
                              setState(() {
                                _showEmojiPicker = !_showEmojiPicker;
                              });
                            },
                          ),
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
                          // Botón de videoconferencia
                          if (currentChannel != null)
                            IconButton(
                              icon: Icon(
                                currentChannel!.startsWith('#') 
                                    ? Icons.videocam 
                                    : Icons.video_call,
                                color: appTheme.primary,
                              ),
                              tooltip: currentChannel!.startsWith('#') 
                                  ? 'Iniciar videoconferencia del canal'
                                  : 'Videollamada con ${currentChannel!}',
                              onPressed: () {
                                if (currentChannel!.startsWith('#')) {
                                  _iniciarVideoconferenciaCanal();
                                } else {
                                  _iniciarVideollamadaPrivada(currentChannel!);
                                }
                              },
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
                                child: KeyboardListener(
                                  focusNode: FocusNode(),
                                  onKeyEvent: (event) {
                                    if (event is KeyDownEvent) {
                                      // Manejar autocompletado de comandos
                                      if (_showCommandSuggestions && _commandSuggestions.isNotEmpty) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          setState(() {
                                            _selectedSuggestionIndex = (_selectedSuggestionIndex + 1) % _commandSuggestions.length;
                                          });
                                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                          setState(() {
                                            _selectedSuggestionIndex = _selectedSuggestionIndex <= 0 
                                                ? _commandSuggestions.length - 1 
                                                : _selectedSuggestionIndex - 1;
                                          });
                                        } else if (event.logicalKey == LogicalKeyboardKey.tab) {
                                          if (_selectedSuggestionIndex >= 0) {
                                            _selectCommandSuggestion(_selectedSuggestionIndex);
                                          }
                                        }
                                      }
                                      // Manejar autocompletado de nicks
                                      else if (_showNickSuggestions && _nickSuggestions.isNotEmpty) {
                                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                          setState(() {
                                            _selectedNickIndex = (_selectedNickIndex + 1) % _nickSuggestions.length;
                                          });
                                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                          setState(() {
                                            _selectedNickIndex = _selectedNickIndex <= 0 
                                                ? _nickSuggestions.length - 1 
                                                : _selectedNickIndex - 1;
                                          });
                                        } else if (event.logicalKey == LogicalKeyboardKey.tab) {
                                          if (_selectedNickIndex >= 0) {
                                            _selectNickSuggestion(_selectedNickIndex);
                                          }
                                        }
                                      }
                                    }
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                              controller: _messageController,
                                        focusNode: _messageFocusNode,
                              decoration: InputDecoration(
                                          hintText: 'Mensaje...',
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
                                        onSubmitted: (_) {
                                          if (_selectedSuggestionIndex >= 0 && _showCommandSuggestions) {
                                            _selectCommandSuggestion(_selectedSuggestionIndex);
                                          } else if (_selectedNickIndex >= 0 && _showNickSuggestions) {
                                            _selectNickSuggestion(_selectedNickIndex);
                                          } else {
                                            _sendMessage();
                                          }
                                        },
                              minLines: 1,
                              maxLines: 3,
                                        keyboardType: TextInputType.multiline,
                                        textInputAction: TextInputAction.newline,
                                        enabled: true,
                                        readOnly: false,
                                        autofocus: false,
                                      ),
                                    // Mostrar sugerencias de comandos
                                    if (_showCommandSuggestions && _commandSuggestions.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: BoxDecoration(
                                          color: appTheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: appTheme.primary.withOpacity(0.3)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          itemCount: _commandSuggestions.length,
                                          separatorBuilder: (context, index) => Divider(
                                            height: 1,
                                            color: appTheme.primary.withOpacity(0.1),
                                          ),
                                          itemBuilder: (context, index) {
                                            final cmd = _commandSuggestions[index];
                                            final isSelected = index == _selectedSuggestionIndex;
                                            
                                            return InkWell(
                                              onTap: () => _selectCommandSuggestion(index),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                color: isSelected 
                                                    ? appTheme.primary.withOpacity(0.2) 
                                                    : Colors.transparent,
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      '/${cmd['command']}',
                                                      style: TextStyle(
                                                        color: appTheme.primary,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        cmd['description'] ?? '',
                                                        style: TextStyle(
                                                          color: appTheme.textSecondary,
                                                          fontSize: 12,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Flexible(
                                                      child: Text(
                                                        cmd['usage'] ?? '',
                                                        style: TextStyle(
                                                          color: appTheme.textSecondary.withOpacity(0.6),
                                                          fontSize: 11,
                                                          fontStyle: FontStyle.italic,
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
                                    // Mostrar sugerencias de nicks
                                    if (_showNickSuggestions && _nickSuggestions.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: BoxDecoration(
                                          color: appTheme.surface,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: appTheme.accent.withOpacity(0.3)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          itemCount: _nickSuggestions.length,
                                          separatorBuilder: (context, index) => Divider(
                                            height: 1,
                                            color: appTheme.accent.withOpacity(0.1),
                                          ),
                                          itemBuilder: (context, index) {
                                            final nick = _nickSuggestions[index];
                                            final isSelected = index == _selectedNickIndex;
                                            
                                            return InkWell(
                                              onTap: () => _selectNickSuggestion(index),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                color: isSelected 
                                                    ? appTheme.accent.withOpacity(0.2) 
                                                    : Colors.transparent,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.person,
                                                      color: appTheme.accent,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      nick,
                                                      style: TextStyle(
                                                        color: appTheme.accent,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
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
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón para enviar con delay normal
                          FloatingActionButton(
                            onPressed: _sendMessage,
                            mini: true,
                            backgroundColor: appTheme.primary,
                            tooltip: 'Enviar mensaje (con delay configurado)',
                            child: const Icon(Icons.send),
                          ),
                          const SizedBox(width: 4),
                          // Botón para enviar inmediatamente (sin delay)
                          FloatingActionButton(
                            onPressed: () {
                              print('⚡⚡⚡ [ChatScreen] Botón de rayo presionado, enviando con forceImmediate=true');
                              _sendMessage(forceImmediate: true);
                            },
                            mini: true,
                            backgroundColor: appTheme.accent,
                            tooltip: 'Enviar inmediatamente (sin delay)',
                            child: const Icon(Icons.flash_on, size: 18),
                          ),
                        ],
                      ),
                    ),
                    // Selector de emoticonos
                    if (_showEmojiPicker && currentChannel != null)
                      EmojiPicker(
                        appTheme: appTheme,
                        onEmojiSelected: (emojiCode) {
                          final currentText = _messageController.text;
                          final cursorPosition = _messageController.selection.baseOffset;
                          final newText = currentText.substring(0, cursorPosition) +
                              emojiCode +
                              currentText.substring(cursorPosition);
                          _messageController.text = newText;
                          _messageController.selection = TextSelection.collapsed(
                            offset: cursorPosition + emojiCode.length,
                          );
                        },
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
                        child: Row(
                          children: [
                            Expanded(
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
                            // Icono de configuración del canal
                            IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.white,
                                size: 20,
                              ),
                              tooltip: 'Configuración del canal',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _showChannelSettingsMenu(context, currentChannel!);
                              },
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
            ),
          ),
          ],
          );
        },
          ),
          
          // Widget de versión en la esquina inferior derecha (por encima de todo)
          if (_appVersion.isNotEmpty)
            Positioned(
              bottom: 70,  // Encima de RadioControls
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: appTheme.primary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: appTheme.secondary.withOpacity(0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
        bottomNavigationBar: RadioControls(),
      ),
    );
  }

  void _performSearch(String query, List<IRCMessage> allMessages) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }
    
    final searchQuery = query.toLowerCase();
    final currentChannel = ref.read(currentChannelProvider);
    final normalizedChannel = currentChannel?.toLowerCase();
    
    setState(() {
      _searchResults = allMessages.where((msg) {
        // Buscar solo en el canal actual
        if (normalizedChannel != null && msg.channel.toLowerCase() != normalizedChannel) {
          return false;
        }
        
        // Buscar en el contenido del mensaje
        final messageText = msg.message.toLowerCase();
        final nickText = msg.nick.toLowerCase();
        
        return messageText.contains(searchQuery) || nickText.contains(searchQuery);
      }).toList();
    });
  }

  Widget _buildSearchWidget(List<IRCMessage> allMessages, AppTheme appTheme) {
    return Column(
      children: [
        // Barra de búsqueda
        Container(
          padding: const EdgeInsets.all(16),
          color: appTheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: appTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Buscar mensajes...',
                    hintStyle: TextStyle(color: appTheme.textSecondary),
                    prefixIcon: Icon(Icons.search, color: appTheme.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: appTheme.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('', allMessages);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: appTheme.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: appTheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: appTheme.background,
                  ),
                  onChanged: (value) {
                    _performSearch(value, allMessages);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_searchResults.length} resultado${_searchResults.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: appTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Resultados de búsqueda
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: appTheme.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Escribe para buscar mensajes'
                            : 'No se encontraron resultados',
                        style: TextStyle(
                          color: appTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  reverse: false,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final message = _searchResults[index];
                    return _buildSearchResultTile(message, appTheme, _searchController.text);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(IRCMessage message, AppTheme appTheme, String searchQuery) {
    final timeFormat = DateFormat('HH:mm');
    final currentNick = ref.read(currentNicknameProvider);
    final isOwnMessage = message.nick == currentNick;
    
    return InkWell(
      onTap: () {
        // Cerrar búsqueda y volver al chat
        setState(() {
          _showSearch = false;
        });
        // TODO: Scroll al mensaje en el chat
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: appTheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  message.nick,
                  style: TextStyle(
                    color: isOwnMessage ? appTheme.primary : appTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeFormat.format(message.timestamp),
                  style: TextStyle(
                    color: appTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  message.channel,
                  style: TextStyle(
                    color: appTheme.textSecondary.withOpacity(0.7),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildHighlightedText(message.message, searchQuery, appTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query, AppTheme appTheme) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: appTheme.textPrimary),
      );
    }
    
    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final matches = <int>[];
    
    int index = 0;
    while ((index = textLower.indexOf(queryLower, index)) != -1) {
      matches.add(index);
      index += queryLower.length;
    }
    
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(color: appTheme.textPrimary),
      );
    }
    
    final spans = <TextSpan>[];
    int lastIndex = 0;
    
    for (final matchIndex in matches) {
      if (matchIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, matchIndex),
          style: TextStyle(color: appTheme.textPrimary),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(matchIndex, matchIndex + query.length),
        style: TextStyle(
          color: appTheme.primary,
          fontWeight: FontWeight.bold,
          backgroundColor: appTheme.primary.withOpacity(0.2),
        ),
      ));
      lastIndex = matchIndex + query.length;
    }
    
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: appTheme.textPrimary),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
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
                  // Contenido del mensaje con soporte para imágenes y acciones
                  message.isAction
                      ? _buildActionMessage(message.nick, message.message, isOwnMessage, userColor, appTheme)
                      : _buildMessageContent(message.message, isOwnMessage, isBot: isBot),
                  // Indicador de "enviando..." y botón de eliminar para mensajes pendientes
                  if (message.isPending && isOwnMessage)
                    _buildPendingMessageIndicator(context, message),
                  // Indicador de mensaje editado
                  if (message.isEdited)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 12, color: appTheme.textSecondary.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            'editado',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: appTheme.textSecondary.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Mostrar mensaje al que se responde (si existe)
                  if (message.replyToMessageId != null)
                    _buildReplyPreview(context, message, appTheme),
                  // Reacciones y acciones del mensaje
                  if (!message.isSystem && message.messageId != null)
                    _buildMessageActions(context, message, isOwnMessage, appTheme),
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

  // Widget para mostrar el indicador de mensaje pendiente con contador
  Widget _buildPendingMessageIndicator(BuildContext context, IRCMessage message) {
    return Consumer(
      builder: (context, ref, _) {
            final delaySeconds = message.delaySeconds ?? ref.read(messageSendDelayProvider);
            return StatefulBuilder(
              builder: (context, setState) {
                // Calcular tiempo restante
                final elapsed = DateTime.now().difference(message.timestamp).inSeconds;
                final delayValue = delaySeconds ?? 0;
                final remaining = delayValue > 0 ? (delayValue - elapsed).clamp(0, delayValue) : 0;
                
                // Actualizar cada segundo si hay tiempo restante
                if (remaining > 0 && message.isPending) {
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted && message.isPending) {
                      setState(() {});
                    }
                  });
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        delayValue > 0 && remaining > 0
                            ? 'Enviando en ${remaining}s...'
                            : 'Enviando...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  // Botón para forzar envío inmediato
                  IconButton(
                    icon: const Icon(Icons.send, size: 16),
                    color: Colors.white.withOpacity(0.9),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Enviar inmediatamente',
                    onPressed: () {
                      _forceSendPendingMessage();
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Colors.white.withOpacity(0.7),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      if (message.pendingId != null) {
                        final success = _ircService.removePendingMessage(message.channel, message.pendingId!);
                        if (success) {
                          // Forzar actualización del provider de mensajes sincronizando con el canal
                          final currentChannel = ref.read(currentChannelProvider);
                          if (currentChannel != null) {
                            final normalizedChannel = currentChannel.toLowerCase();
                            final channelObj = _ircService.allChannels[normalizedChannel];
                            if (channelObj != null) {
                              // Obtener todos los mensajes del provider actual
                              final allMessages = ref.read(messagesProvider);
                              // Filtrar y actualizar solo los mensajes de este canal
                              final otherChannelMessages = allMessages.where(
                                (m) => m.channel.toLowerCase() != normalizedChannel
                              ).toList();
                              // Añadir los mensajes actualizados del canal
                              final updatedMessages = [...otherChannelMessages, ...channelObj.messages];
                              ref.read(messagesProvider.notifier).state = updatedMessages;
                            }
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mensaje eliminado antes de enviar'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    tooltip: 'Eliminar mensaje',
                  ),
                ],
              ),
            );
          },
        );
      },
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

  // Widget para mostrar preview del mensaje al que se responde
  Widget _buildReplyPreview(BuildContext context, IRCMessage message, AppTheme appTheme) {
    final replyToMessage = _ircService.getMessageById(message.channel, message.replyToMessageId!);
    if (replyToMessage == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: appTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: appTheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 14, color: appTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  replyToMessage.nick,
                  style: TextStyle(
                    fontSize: 12,
                  fontWeight: FontWeight.bold,
                    color: appTheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyToMessage.message.length > 50
                      ? '${replyToMessage.message.substring(0, 50)}...'
                      : replyToMessage.message,
                  style: TextStyle(
                    fontSize: 11,
                    color: appTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Widget para mostrar acciones del mensaje (editar, reacciones, responder)
  Widget _buildMessageActions(BuildContext context, IRCMessage message, bool isOwnMessage, AppTheme appTheme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de responder
          IconButton(
            icon: const Icon(Icons.reply, size: 16),
            color: appTheme.textSecondary.withOpacity(0.6),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Responder',
            onPressed: () => _showReplyDialog(context, message),
          ),
          const SizedBox(width: 4),
          // Reacciones rápidas
          PopupMenuButton<String>(
            icon: Icon(Icons.add_reaction, size: 16, color: appTheme.textSecondary.withOpacity(0.6)),
            tooltip: 'Reaccionar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            itemBuilder: (context) => [
              const PopupMenuItem(value: '👍', child: Text('👍')),
              const PopupMenuItem(value: '❤️', child: Text('❤️')),
              const PopupMenuItem(value: '😂', child: Text('😂')),
              const PopupMenuItem(value: '😮', child: Text('😮')),
              const PopupMenuItem(value: '😢', child: Text('😢')),
              const PopupMenuItem(value: '🔥', child: Text('🔥')),
              const PopupMenuItem(value: '⭐', child: Text('⭐')),
            ],
            onSelected: (emoji) {
              if (message.messageId != null) {
                _ircService.toggleReaction(message.channel, message.messageId!, emoji);
              }
            },
          ),
          // Mostrar reacciones existentes
          if (message.reactions.isNotEmpty) ...[
              const SizedBox(width: 8),
            ...message.reactions.entries.map((entry) {
              return GestureDetector(
                onTap: () {
                  if (message.messageId != null) {
                    _ircService.toggleReaction(message.channel, message.messageId!, entry.key);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: appTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: appTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
              Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 11,
                          color: appTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          // Botón de editar (solo para mensajes propios con delay que aún no se han enviado)
          if (isOwnMessage && !message.isSystem && message.isPending && message.delaySeconds != null && message.delaySeconds! > 0) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit, size: 16),
              color: appTheme.textSecondary.withOpacity(0.6),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Editar',
              onPressed: () => _showEditMessageDialog(context, message),
            ),
          ],
        ],
      ),
    );
  }
  
  // Diálogo para editar un mensaje
  void _showEditMessageDialog(BuildContext context, IRCMessage message) {
    final appTheme = ref.read(themeProvider);
    final editController = TextEditingController(text: message.message);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('Editar mensaje', style: TextStyle(color: appTheme.textPrimary)),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 5,
          style: TextStyle(color: appTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Mensaje...',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty && message.messageId != null) {
                _ircService.editMessage(message.channel, message.messageId!, editController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mensaje editado')),
                );
              }
            },
            child: Text('Guardar', style: TextStyle(color: appTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  // Diálogo para responder a un mensaje
  void _showReplyDialog(BuildContext context, IRCMessage message) {
    final appTheme = ref.read(themeProvider);
    final replyController = TextEditingController();
    final currentChannel = ref.read(currentChannelProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Row(
          children: [
            Icon(Icons.reply, color: appTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Responder a ${message.nick}', style: TextStyle(color: appTheme.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview del mensaje original
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: appTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: appTheme.primary, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.nick,
                style: TextStyle(
                  fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: appTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.message.length > 100
                              ? '${message.message.substring(0, 100)}...'
                              : message.message,
                          style: TextStyle(
                            fontSize: 11,
                            color: appTheme.textSecondary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: replyController,
              autofocus: true,
              maxLines: 5,
              style: TextStyle(color: appTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Tu respuesta...',
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
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (replyController.text.trim().isNotEmpty && 
                  message.messageId != null && 
                  currentChannel != null) {
                _ircService.replyToMessage(
                  currentChannel,
                  message.messageId!,
                  replyController.text.trim(),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Respuesta enviada')),
                );
              }
            },
            child: Text('Enviar', style: TextStyle(color: appTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Widget para mostrar mensajes de acción (/me) con emoticono moderno
  Widget _buildActionMessage(String nick, String actionText, bool isOwnMessage, Color userColor, AppTheme appTheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoticono moderno para acciones
        Text(
          '✨',
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(width: 8),
        // Texto de la acción
        Flexible(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isOwnMessage
                    ? Colors.white.withOpacity(0.95)
                    : appTheme.textPrimary,
              ),
              children: [
                TextSpan(
                  text: nick,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOwnMessage ? Colors.white : userColor,
                  ),
                ),
                const TextSpan(text: ' '),
                TextSpan(text: actionText),
              ],
            ),
          ),
        ),
      ],
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
              _buildTextWithEmojis(
                remainingText,
                isOwnMessage: isOwnMessage,
                isBot: isBot,
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
            parts.add(_buildTextWithEmojis(
              textBefore,
              isOwnMessage: isOwnMessage,
              isBot: isBot,
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
          parts.add(_buildTextWithEmojis(
            textAfter,
            isOwnMessage: isOwnMessage,
            isBot: isBot,
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
            parts.add(_buildTextWithEmojis(
              textBefore,
              isOwnMessage: isOwnMessage,
              isBot: isBot,
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
          parts.add(_buildTextWithEmojis(
            textAfter,
            isOwnMessage: isOwnMessage,
            isBot: isBot,
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
          return _buildTextWithEmojis(
            cleaned,
            isOwnMessage: isOwnMessage,
            isBot: isBot,
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
    
    return _buildTextWithEmojis(
      messageText,
      isOwnMessage: isOwnMessage,
      isBot: isBot,
    );
  }

  // Construir texto con emoticonos
  Widget _buildTextWithEmojis(
    String text, {
    required bool isOwnMessage,
    bool isBot = false,
  }) {
    final appTheme = ref.read(themeProvider);
    final defaultColor = isOwnMessage 
        ? Colors.white 
        : isBot
            ? const Color(0xFF8B6914)
            : appTheme.textPrimary;
    
    final parts = EmojiService.parseEmojiCodes(text);
    final textSpans = <InlineSpan>[];
    
    for (final part in parts) {
      if (part.startsWith(':') && part.endsWith(':')) {
        // Es un código de emoticono
        final emojiUrl = EmojiService.getEmojiUrl(part);
        if (emojiUrl != null) {
          textSpans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Image.network(
                emojiUrl,
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    part,
                    style: TextStyle(
                      color: defaultColor,
                      fontSize: 15,
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          // Emoticono no encontrado, mostrar como texto
          textSpans.add(
            TextSpan(
              text: part,
              style: TextStyle(
                color: defaultColor,
                fontSize: 15,
              ),
            ),
          );
        }
      } else {
        // Es texto normal
        if (isBot && (part.contains('\x03') || part.contains('\x02'))) {
          // Parsear códigos IRC
          final spans = IRCColorParser.parseIRCMessage(part, defaultColor: defaultColor);
          textSpans.addAll(spans);
        } else {
          textSpans.add(
            TextSpan(
              text: part,
              style: TextStyle(
                color: defaultColor,
                fontSize: isBot ? 16 : 15,
                height: 1.6,
                fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
                letterSpacing: isBot ? 0.3 : 0.0,
              ),
            ),
          );
        }
      }
    }
    
    return RichText(
      text: TextSpan(
        children: textSpans,
        style: TextStyle(
          fontSize: isBot ? 16 : 15,
          height: 1.6,
          fontWeight: isBot ? FontWeight.w500 : FontWeight.w400,
          letterSpacing: isBot ? 0.3 : 0.0,
        ),
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
          // Asegurarse de que el canal/query existe en el servicio
          // Si es un canal reciente cerrado, volver a hacer JOIN antes de seleccionarlo
          if (!isQuery && channel.startsWith('#')) {
            final channelsMap = ref.read(channelsProvider);
            final normalizedChannelLower = channel.toLowerCase();
            final isAlreadyOpen = channelsMap.keys.any(
              (key) => key.toLowerCase() == normalizedChannelLower,
            );
            if (!isAlreadyOpen) {
              _ircService.joinChannel(channel);
            }
          }

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
                  // Eliminar de recientes también
                  ref.read(recentChannelsProvider.notifier).removeRecent(channel);
                  final normalizedCurrentChannel =
                      currentChannel?.toLowerCase();
                  if (normalizedCurrentChannel == normalizedChannel) {
                    // Si es el canal actual, seleccionar otro canal disponible
                    final remainingChannels = ref.read(channelsProvider).keys
                        .where((c) => c.toLowerCase() != normalizedChannel)
                        .toList();
                    if (remainingChannels.isNotEmpty) {
                      ref.read(currentChannelProvider.notifier).state = remainingChannels.first;
                    } else {
                      ref.read(currentChannelProvider.notifier).state = null;
                    }
                  }
                } else {
                  // Si es un canal, hacer PART
                  _ircService.partChannel(channel);
                  ref.read(channelsProvider.notifier).updateChannels();
                  // Eliminar de recientes también cuando se hace PART
                  ref.read(recentChannelsProvider.notifier).removeRecent(channel);
                  final normalizedCurrentChannel =
                      currentChannel?.toLowerCase();
                  if (normalizedCurrentChannel == normalizedChannel) {
                    // Si es el canal actual, seleccionar otro canal disponible
                    final remainingChannels = ref.read(channelsProvider).keys
                        .where((c) => c.toLowerCase() != normalizedChannel)
                        .toList();
                    if (remainingChannels.isNotEmpty) {
                      ref.read(currentChannelProvider.notifier).state = remainingChannels.first;
                    } else {
                      ref.read(currentChannelProvider.notifier).state = null;
                    }
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
      isScrollControlled: true,
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
          child: SingleChildScrollView(
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
              // Separador y opciones de moderación (solo si el usuario es moderador)
              Builder(
                builder: (context) {
                  final currentChannel = ref.read(currentChannelProvider);
                  if (currentChannel == null || !currentChannel.startsWith('#')) {
                    return const SizedBox.shrink();
                  }
                  
                  final channels = ref.read(channelsProvider);
                  final normalizedChannel = currentChannel.toLowerCase();
                  final channelKey = channels.keys.firstWhere(
                    (key) => key.toLowerCase() == normalizedChannel,
                    orElse: () => normalizedChannel,
                  );
                  
                  if (!channels.containsKey(channelKey)) {
                    return const SizedBox.shrink();
                  }
                  
                  final channelData = channels[channelKey];
                  final currentNick = ref.read(currentNicknameProvider);
                  if (currentNick == null) {
                    return const SizedBox.shrink();
                  }
                  
                  final userMode = channelData?.getUserMode(currentNick);
                  // Verificar si es moderador: @ (op), & (founder/owner), % (halfop)
                  // O si es IRCop (los IRCops pueden moderar sin tener modo en el canal)
                  final isModerator = userMode == '@' || userMode == '&' || userMode == '%';
                  final isIRCOp = _ircService.isIRCOp;
                  final canModerate = isModerator || isIRCOp;
                  
                  if (!canModerate) {
                    return const SizedBox.shrink();
                  }
                  
                  return Column(
                    children: [
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.shield, color: appTheme.primary, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'ACCIONES DE MODERACIÓN',
                              style: TextStyle(
                                color: appTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_remove, color: Colors.orange),
                        ),
                        title: const Text('Expulsar (Kick)'),
                        subtitle: const Text('Expulsar usuario del canal'),
                        onTap: () {
                          Navigator.pop(context);
                          _showKickDialog(context, nick, currentChannel);
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
                        title: const Text('Banear'),
                        subtitle: const Text('Banear usuario del canal'),
                        onTap: () {
                          Navigator.pop(context);
                          _showBanDialog(context, nick, currentChannel);
                        },
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_circle_outline, color: Colors.green),
                        ),
                        title: const Text('Desbanear'),
                        subtitle: const Text('Quitar ban del usuario'),
                        onTap: () {
                          Navigator.pop(context);
                          _ircService.unbanUser(currentChannel, nick);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Desbaneando $nick...'),
                              duration: const Duration(seconds: 2),
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
                          child: const Icon(Icons.admin_panel_settings, color: Colors.blue),
                        ),
                        title: const Text('Dar Op'),
                        subtitle: const Text('Dar privilegios de operador'),
                        onTap: () {
                          Navigator.pop(context);
                          _ircService.setChannelMode(currentChannel, '+o', nick);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Dando op a $nick...'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.remove_moderator, color: Colors.purple),
                        ),
                        title: const Text('Quitar Op'),
                        subtitle: const Text('Quitar privilegios de operador'),
                        onTap: () {
                          Navigator.pop(context);
                          _ircService.setChannelMode(currentChannel, '-o', nick);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Quitando op a $nick...'),
                              duration: const Duration(seconds: 2),
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
                          child: const Icon(Icons.person_add, color: Colors.orange),
                        ),
                        title: const Text('Dar Halfop'),
                        subtitle: const Text('Dar privilegios de halfop'),
                        onTap: () {
                          Navigator.pop(context);
                          _ircService.setChannelMode(currentChannel, '+h', nick);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Dando halfop a $nick...'),
                              duration: const Duration(seconds: 2),
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
                          child: const Icon(Icons.person_remove, color: Colors.orange),
                        ),
                        title: const Text('Quitar Halfop'),
                        subtitle: const Text('Quitar privilegios de halfop'),
                        onTap: () {
                          Navigator.pop(context);
                          _ircService.setChannelMode(currentChannel, '-h', nick);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Quitando halfop a $nick...'),
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
                          child: const Icon(Icons.mic, color: Colors.green),
                        ),
                        title: const Text('Dar Voz'),
                        subtitle: const Text('Dar privilegios de voz'),
                        onTap: () {
                          Navigator.pop(context);
                          _ircService.setChannelMode(currentChannel, '+v', nick);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Dando voz a $nick...'),
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
                          child: const Icon(Icons.mic_off, color: Colors.green),
                        ),
                        title: const Text('Quitar Voz'),
                        subtitle: const Text('Quitar privilegios de voz'),
                        onTap: () {
                          Navigator.pop(context);
                          _ircService.setChannelMode(currentChannel, '-v', nick);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Quitando voz a $nick...'),
                              duration: const Duration(seconds: 2),
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
                        title: const Text('Cambiar Topic'),
                        subtitle: const Text('Cambiar el topic del canal'),
                        onTap: () {
                          Navigator.pop(context);
                          _showTopicDialog(context, currentChannel);
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _showBanDialog(BuildContext context, String nick, String channel) {
    final appTheme = ref.read(themeProvider);
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Banear usuario',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Banear a $nick del canal',
              style: TextStyle(color: appTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: TextStyle(color: appTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'Razón del ban',
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
            ),
          ],
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
              final reason = reasonController.text.trim();
              _ircService.banUser(channel, nick, reason.isNotEmpty ? reason : null);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Baneando $nick${reason.isNotEmpty ? " (razón: $reason)" : ""}...'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Banear',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showKickDialog(BuildContext context, String nick, String channel) {
    final appTheme = ref.read(themeProvider);
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Expulsar usuario',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expulsar a $nick del canal',
              style: TextStyle(color: appTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: TextStyle(color: appTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'Razón de la expulsión',
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
            ),
          ],
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
              final reason = reasonController.text.trim();
              _ircService.kickUser(channel, nick, reason.isNotEmpty ? reason : null);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Expulsando $nick${reason.isNotEmpty ? " (razón: $reason)" : ""}...'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Expulsar',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChannelSettingsMenu(BuildContext context, String channel) {
    final appTheme = ref.read(themeProvider);
    final channels = ref.read(channelsProvider);
    final normalized = channel.toLowerCase();
    final channelKey = channels.keys.firstWhere(
      (key) => key.toLowerCase() == normalized,
      orElse: () => normalized,
    );
    
    if (!channels.containsKey(channelKey)) {
      return;
    }
    
    final channelData = channels[channelKey];
    final currentNick = ref.read(currentNicknameProvider);
    if (currentNick == null) {
      return;
    }
    
    // Verificar permisos del usuario
    final userMode = channelData?.getUserMode(currentNick);
    final isModerator = userMode == '@' || userMode == '&' || userMode == '%';
    final isIRCOp = _ircService.isIRCOp;
    final canModerate = isModerator || isIRCOp;
    
    // Verificar si tiene voz (puede cambiar topic en algunos canales)
    final hasVoice = userMode == '+' || isModerator || isIRCOp;
    
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
          child: SingleChildScrollView(
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.settings, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuración del Canal',
                              style: TextStyle(
                                color: appTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              channel,
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
                if (canModerate || hasVoice) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit, color: Colors.teal),
                    ),
                    title: const Text('Cambiar Topic'),
                    subtitle: const Text('Modificar el topic del canal'),
                    enabled: canModerate || hasVoice,
                    onTap: canModerate || hasVoice ? () {
                      Navigator.pop(context);
                      _showTopicDialog(context, channel);
                    } : null,
                  ),
                ],
                if (canModerate) ...[
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.shield, color: appTheme.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Opciones de Moderación',
                          style: TextStyle(
                            color: appTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune, color: Colors.blue),
                    ),
                    title: const Text('Modos del Canal'),
                    subtitle: const Text('Cambiar modos del canal (ej: +n, +t, +s)'),
                    onTap: () {
                      Navigator.pop(context);
                      _showChannelModeDialog(context, channel);
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showChannelModeDialog(BuildContext context, String channel) {
    final appTheme = ref.read(themeProvider);
    final modeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Modos del Canal',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Canal: $channel',
              style: TextStyle(
                color: appTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: modeController,
              style: TextStyle(color: appTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Modos (ej: +n, +t, +s, -i)',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: '+n +t',
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
            ),
            const SizedBox(height: 8),
            Text(
              'Ejemplos:\n+n (no mensajes externos)\n+t (topic solo para ops)\n+s (canal secreto)\n+i (invite only)',
              style: TextStyle(
                color: appTheme.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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
              final modes = modeController.text.trim();
              if (modes.isNotEmpty) {
                _ircService.setChannelMode(channel, modes);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Aplicando modos: $modes...'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              'Aplicar',
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

  void _showTopicDialog(BuildContext context, String channel) {
    final appTheme = ref.read(themeProvider);
    final channels = ref.read(channelsProvider);
    final normalized = channel.toLowerCase();
    final channelKey = channels.keys.firstWhere(
      (key) => key.toLowerCase() == normalized,
      orElse: () => normalized,
    );
    
    final currentTopic = channels.containsKey(channelKey) 
        ? channels[channelKey]!.topic 
        : null;
    
    final topicController = TextEditingController(text: currentTopic ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Cambiar Topic',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Canal: $channel',
              style: TextStyle(
                color: appTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: topicController,
              style: TextStyle(color: appTheme.textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Nuevo topic',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'Escribe el nuevo topic del canal',
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
            ),
          ],
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
              final newTopic = topicController.text.trim();
              if (newTopic.isNotEmpty) {
                _ircService.setChannelTopic(channel, newTopic);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cambiando topic a: $newTopic...'),
                    duration: const Duration(seconds: 2),
                  ),
                );
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

  void _showIRCOpMenu(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final currentNick = ref.read(currentNicknameProvider);
    final isIRCOp = _ircService.isIRCOp;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
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
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange,
                      Colors.deepOrange,
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
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Menú IRCop',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isIRCOp 
                                ? 'Comandos de operador IRC (UnrealIRCd)'
                                : 'Comandos de operador IRC (requiere autenticación)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Advertencia si no está identificado como IRCop
              if (!isIRCOp) ...[
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No estás identificado como IRCop',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Usa /oper nick contraseña o el menú de perfil para autenticarte',
                              style: TextStyle(
                                color: Colors.orange.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Contenido del menú
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gestión de usuarios
                      _buildIRCOpSection(
                        context,
                        appTheme,
                        'Gestión de Usuarios',
                        Icons.people,
                        [
                          _IRCOpMenuItem(
                            icon: Icons.person_off,
                            iconColor: Colors.red,
                            title: 'KILL',
                            subtitle: 'Desconectar usuario del servidor',
                            onTap: () => _showKillDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.block,
                            iconColor: Colors.red,
                            title: 'GLINE',
                            subtitle: 'Prohibir usuario/IP globalmente',
                            onTap: () => _showGlineDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.block,
                            iconColor: Colors.orange,
                            title: 'KLINE',
                            subtitle: 'Prohibir usuario/IP localmente',
                            onTap: () => _showKlineDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.network_check,
                            iconColor: Colors.red,
                            title: 'ZLINE',
                            subtitle: 'Banear IP específica',
                            onTap: () => _showZlineDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.volume_off,
                            iconColor: Colors.purple,
                            title: 'SHUN',
                            subtitle: 'Silenciar usuario',
                            onTap: () => _showShunDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Gestión de canales
                      _buildIRCOpSection(
                        context,
                        appTheme,
                        'Gestión de Canales',
                        Icons.tag,
                        [
                          _IRCOpMenuItem(
                            icon: Icons.login,
                            iconColor: Colors.blue,
                            title: 'SAJOIN',
                            subtitle: 'Forzar usuario a unirse a canal',
                            onTap: () => _showSajoinDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.logout,
                            iconColor: Colors.orange,
                            title: 'SAPART',
                            subtitle: 'Forzar usuario a salir de canal',
                            onTap: () => _showSapartDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.settings,
                            iconColor: Colors.teal,
                            title: 'SAMODE',
                            subtitle: 'Cambiar modos de canal',
                            onTap: () => _showSamodeDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.badge,
                            iconColor: Colors.purple,
                            title: 'SANICK',
                            subtitle: 'Cambiar nick de usuario',
                            onTap: () => _showSanickDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.message,
                            iconColor: Colors.blue,
                            title: 'SAPRIVMSG',
                            subtitle: 'Enviar mensaje privado como servicio',
                            onTap: () => _showSaprivmsgDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Gestión del servidor
                      _buildIRCOpSection(
                        context,
                        appTheme,
                        'Gestión del Servidor',
                        Icons.dns,
                        [
                          _IRCOpMenuItem(
                            icon: Icons.power_settings_new,
                            iconColor: Colors.red,
                            title: 'SQUIT',
                            subtitle: 'Desconectar servidor de la red',
                            onTap: () => _showSquitDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.refresh,
                            iconColor: Colors.blue,
                            title: 'REHASH',
                            subtitle: 'Recargar configuración del servidor',
                            onTap: () {
                              Navigator.pop(context);
                              _ircService.rehashServer();
                              _showIRCOpResultsWindow('REHASH', 'Recarga de Configuración');
                            },
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.restart_alt,
                            iconColor: Colors.orange,
                            title: 'RESTART',
                            subtitle: 'Reiniciar el servidor',
                            onTap: () => _showRestartDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.power_off,
                            iconColor: Colors.red,
                            title: 'DIE',
                            subtitle: 'Apagar el servidor',
                            onTap: () => _showDieDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.link,
                            iconColor: Colors.green,
                            title: 'CONNECT',
                            subtitle: 'Conectar servidor a la red',
                            onTap: () => _showConnectDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Información y estadísticas
                      _buildIRCOpSection(
                        context,
                        appTheme,
                        'Información y Estadísticas',
                        Icons.info,
                        [
                          _IRCOpMenuItem(
                            icon: Icons.bar_chart,
                            iconColor: Colors.blue,
                            title: 'STATS',
                            subtitle: 'Obtener estadísticas del servidor',
                            onTap: () => _showStatsDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.track_changes,
                            iconColor: Colors.purple,
                            title: 'TRACE',
                            subtitle: 'Rastrear ruta de usuario/servidor',
                            onTap: () {
                              Navigator.pop(context);
                              _showTraceDialog(context);
                            },
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.link,
                            iconColor: Colors.green,
                            title: 'LINKS',
                            subtitle: 'Listar servidores conectados',
                            onTap: () {
                              Navigator.pop(context);
                              _ircService.linksCommand();
                              _showIRCOpResultsWindow('LINKS', 'Lista de Servidores');
                            },
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.map,
                            iconColor: Colors.teal,
                            title: 'MAP',
                            subtitle: 'Mapa de la red',
                            onTap: () {
                              Navigator.pop(context);
                              _ircService.mapCommand();
                              _showIRCOpResultsWindow('MAP', 'Mapa de la Red');
                            },
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.description,
                            iconColor: Colors.orange,
                            title: 'MOTD',
                            subtitle: 'Mensaje del día',
                            onTap: () {
                              Navigator.pop(context);
                              _ircService.motdCommand();
                              _showIRCOpResultsWindow('MOTD', 'Mensaje del Día');
                            },
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.info_outline,
                            iconColor: Colors.blue,
                            title: 'VERSION',
                            subtitle: 'Versión del servidor',
                            onTap: () {
                              Navigator.pop(context);
                              _ircService.versionCommand();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Solicitando versión del servidor...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.admin_panel_settings,
                            iconColor: Colors.purple,
                            title: 'ADMIN',
                            subtitle: 'Información de administración',
                            onTap: () {
                              Navigator.pop(context);
                              _ircService.adminCommand();
                              _showIRCOpResultsWindow('ADMIN', 'Información de Administración');
                            },
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.people_outline,
                            iconColor: Colors.green,
                            title: 'LUSERS',
                            subtitle: 'Estadísticas de usuarios',
                            onTap: () {
                              Navigator.pop(context);
                              _ircService.lusersCommand();
                              _showIRCOpResultsWindow('LUSERS', 'Estadísticas de Usuarios');
                            },
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.access_time,
                            iconColor: Colors.blue,
                            title: 'TIME',
                            subtitle: 'Hora del servidor',
                            onTap: () {
                              Navigator.pop(context);
                              _ircService.timeCommand();
                              _showIRCOpResultsWindow('TIME', 'Hora del Servidor');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Mensajes a operadores
                      _buildIRCOpSection(
                        context,
                        appTheme,
                        'Mensajes a Operadores',
                        Icons.notifications,
                        [
                          _IRCOpMenuItem(
                            icon: Icons.campaign,
                            iconColor: Colors.orange,
                            title: 'WALLOPS',
                            subtitle: 'Mensaje a todos los operadores',
                            onTap: () => _showWallopsDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.public,
                            iconColor: Colors.blue,
                            title: 'GLOBOPS',
                            subtitle: 'Mensaje global a operadores',
                            onTap: () => _showGlobopsDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.admin_panel_settings,
                            iconColor: Colors.purple,
                            title: 'ADMIND',
                            subtitle: 'Mensaje a administradores',
                            onTap: () => _showAdmindDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.home,
                            iconColor: Colors.green,
                            title: 'LOCOPS',
                            subtitle: 'Mensaje a operadores locales',
                            onTap: () => _showLocopsDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Otros comandos
                      _buildIRCOpSection(
                        context,
                        appTheme,
                        'Otros Comandos',
                        Icons.more_horiz,
                        [
                          _IRCOpMenuItem(
                            icon: Icons.block,
                            iconColor: Colors.red,
                            title: 'DCCDENY',
                            subtitle: 'Denegar DCC de usuario',
                            onTap: () => _showDccdenyDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.check_circle,
                            iconColor: Colors.green,
                            title: 'UNDCCDENY',
                            subtitle: 'Permitir DCC de usuario',
                            onTap: () => _showUndccdenyDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.access_time,
                            iconColor: Colors.blue,
                            title: 'TSCTL',
                            subtitle: 'Control de timestamp',
                            onTap: () => _showTsctlDialog(context),
                          ),
                          _IRCOpMenuItem(
                            icon: Icons.lock,
                            iconColor: Colors.purple,
                            title: 'MKPASSWD',
                            subtitle: 'Generar hash de contraseña',
                            onTap: () => _showMkpasswdDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIRCOpSection(
    BuildContext context,
    AppTheme appTheme,
    String title,
    IconData icon,
    List<_IRCOpMenuItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: appTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: appTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: appTheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildIRCOpMenuItem(context, appTheme, item)),
      ],
    );
  }

  Widget _buildIRCOpMenuItem(BuildContext context, AppTheme appTheme, _IRCOpMenuItem item) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: item.iconColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(item.icon, color: item.iconColor, size: 20),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: appTheme.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: TextStyle(
          color: appTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      onTap: item.onTap,
    );
  }

  // Diálogos para comandos IRCop
  void _showKillDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('KILL - Desconectar Usuario', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickController,
              decoration: InputDecoration(
                labelText: 'Nick',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (nickController.text.trim().isNotEmpty) {
                _ircService.killUser(nickController.text.trim(), reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Desconectando ${nickController.text.trim()}...')),
                );
              }
            },
            child: Text('KILL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showGlineDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final userhostController = TextEditingController();
    final durationController = TextEditingController();
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('GLINE - Prohibir Globalmente', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userhostController,
              decoration: InputDecoration(
                labelText: 'Usuario@host o IP',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'usuario@host.com o 192.168.1.1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              decoration: InputDecoration(
                labelText: 'Duración (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: '1d, 2h, 30m',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (userhostController.text.trim().isNotEmpty) {
                _ircService.glineUser(
                  userhostController.text.trim(),
                  durationController.text.trim().isNotEmpty ? durationController.text.trim() : null,
                  reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Aplicando GLINE a ${userhostController.text.trim()}...')),
                );
              }
            },
            child: Text('GLINE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showKlineDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final userhostController = TextEditingController();
    final durationController = TextEditingController();
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('KLINE - Prohibir Localmente', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userhostController,
              decoration: InputDecoration(
                labelText: 'Usuario@host o IP',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              decoration: InputDecoration(
                labelText: 'Duración (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (userhostController.text.trim().isNotEmpty) {
                _ircService.klineUser(
                  userhostController.text.trim(),
                  durationController.text.trim().isNotEmpty ? durationController.text.trim() : null,
                  reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Aplicando KLINE a ${userhostController.text.trim()}...')),
                );
              }
            },
            child: Text('KLINE', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showZlineDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final ipController = TextEditingController();
    final durationController = TextEditingController();
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('ZLINE - Banear IP', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                labelText: 'IP',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: '192.168.1.1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              decoration: InputDecoration(
                labelText: 'Duración (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (ipController.text.trim().isNotEmpty) {
                _ircService.zlineIP(
                  ipController.text.trim(),
                  durationController.text.trim().isNotEmpty ? durationController.text.trim() : null,
                  reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Aplicando ZLINE a ${ipController.text.trim()}...')),
                );
              }
            },
            child: Text('ZLINE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showShunDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final userhostController = TextEditingController();
    final durationController = TextEditingController();
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('SHUN - Silenciar Usuario', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: userhostController,
              decoration: InputDecoration(
                labelText: 'Usuario@host',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              decoration: InputDecoration(
                labelText: 'Duración (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (userhostController.text.trim().isNotEmpty) {
                _ircService.shunUser(
                  userhostController.text.trim(),
                  durationController.text.trim().isNotEmpty ? durationController.text.trim() : null,
                  reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Aplicando SHUN a ${userhostController.text.trim()}...')),
                );
              }
            },
            child: Text('SHUN', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSajoinDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    final channelController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('SAJOIN - Forzar Unirse a Canal', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickController,
              decoration: InputDecoration(
                labelText: 'Nick',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: channelController,
              decoration: InputDecoration(
                labelText: 'Canal',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: '#canal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (nickController.text.trim().isNotEmpty && channelController.text.trim().isNotEmpty) {
                _ircService.sajoinUser(nickController.text.trim(), channelController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Forzando a ${nickController.text.trim()} a unirse a ${channelController.text.trim()}...')),
                );
              }
            },
            child: Text('SAJOIN', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSapartDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    final channelController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('SAPART - Forzar Salir de Canal', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickController,
              decoration: InputDecoration(
                labelText: 'Nick',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: channelController,
              decoration: InputDecoration(
                labelText: 'Canal',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: '#canal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (nickController.text.trim().isNotEmpty && channelController.text.trim().isNotEmpty) {
                _ircService.sapartUser(nickController.text.trim(), channelController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Forzando a ${nickController.text.trim()} a salir de ${channelController.text.trim()}...')),
                );
              }
            },
            child: Text('SAPART', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSamodeDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final channelController = TextEditingController();
    final modesController = TextEditingController();
    final targetController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('SAMODE - Cambiar Modos de Canal', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: channelController,
              decoration: InputDecoration(
                labelText: 'Canal',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: '#canal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: modesController,
              decoration: InputDecoration(
                labelText: 'Modos',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: '+o, -m, etc.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              decoration: InputDecoration(
                labelText: 'Target (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'nick o parámetro',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (channelController.text.trim().isNotEmpty && modesController.text.trim().isNotEmpty) {
                _ircService.samodeChannel(
                  channelController.text.trim(),
                  modesController.text.trim(),
                  targetController.text.trim().isNotEmpty ? targetController.text.trim() : null,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cambiando modos de ${channelController.text.trim()}...')),
                );
              }
            },
            child: Text('SAMODE', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSanickDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    final newNickController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('SANICK - Cambiar Nick', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickController,
              decoration: InputDecoration(
                labelText: 'Nick actual',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newNickController,
              decoration: InputDecoration(
                labelText: 'Nuevo nick',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (nickController.text.trim().isNotEmpty && newNickController.text.trim().isNotEmpty) {
                _ircService.sanickUser(nickController.text.trim(), newNickController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cambiando nick de ${nickController.text.trim()} a ${newNickController.text.trim()}...')),
                );
              }
            },
            child: Text('SANICK', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSaprivmsgDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('SAPRIVMSG - Mensaje Privado como Servicio', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickController,
              decoration: InputDecoration(
                labelText: 'Nick',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (nickController.text.trim().isNotEmpty && messageController.text.trim().isNotEmpty) {
                _ircService.saprivmsgUser(nickController.text.trim(), messageController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Enviando mensaje a ${nickController.text.trim()}...')),
                );
              }
            },
            child: Text('SAPRIVMSG', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSquitDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final serverController = TextEditingController();
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('SQUIT - Desconectar Servidor', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serverController,
              decoration: InputDecoration(
                labelText: 'Servidor',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (serverController.text.trim().isNotEmpty) {
                _ircService.squitServer(
                  serverController.text.trim(),
                  reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                );
                Navigator.pop(context);
                _showIRCOpResultsWindow('SQUIT ${serverController.text.trim()}', 'Desconexión de Servidor');
              }
            },
            child: Text('SQUIT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRestartDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('RESTART - Reiniciar Servidor', style: TextStyle(color: Colors.orange)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Estás seguro de que quieres reiniciar el servidor?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _ircService.restartServer(reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null);
              Navigator.pop(context);
              _showIRCOpResultsWindow('RESTART', 'Reinicio de Servidor');
            },
            child: Text('RESTART', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDieDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('DIE - Apagar Servidor', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️ ADVERTENCIA: Esto apagará el servidor completamente.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _ircService.dieServer(reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null);
              Navigator.pop(context);
              _showIRCOpResultsWindow('DIE', 'Apagado de Servidor');
            },
            child: Text('DIE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConnectDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final serverController = TextEditingController();
    final portController = TextEditingController(text: '6667');
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('CONNECT - Conectar Servidor', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serverController,
              decoration: InputDecoration(
                labelText: 'Servidor',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Puerto',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña (opcional)',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (serverController.text.trim().isNotEmpty && portController.text.trim().isNotEmpty) {
                final port = int.tryParse(portController.text.trim());
                if (port != null) {
                  final server = serverController.text.trim();
                  final password = passwordController.text.trim().isNotEmpty ? passwordController.text.trim() : null;
                  _ircService.connectServer(server, port, password);
                  Navigator.pop(context);
                  _showIRCOpResultsWindow('CONNECT $server:$port', 'Conexión de Servidor');
                }
              }
            },
            child: Text('CONNECT', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final typeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('STATS - Estadísticas', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: typeController,
              decoration: InputDecoration(
                labelText: 'Tipo de estadísticas',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'c, d, h, i, k, l, m, o, u, y, etc.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (typeController.text.trim().isNotEmpty) {
                _ircService.statsCommand(typeController.text.trim());
                Navigator.pop(context);
                _showIRCOpResultsWindow('STATS ${typeController.text.trim()}', 'Estadísticas del Servidor');
              }
            },
            child: Text('STATS', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTraceDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final targetController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('TRACE - Rastrear', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: targetController,
              decoration: InputDecoration(
                labelText: 'Usuario o servidor',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (targetController.text.trim().isNotEmpty) {
                final target = targetController.text.trim();
                _ircService.traceTarget(target);
                Navigator.pop(context);
                _showIRCOpResultsWindow('TRACE $target', 'Rastreo de Ruta');
              }
            },
            child: Text('TRACE', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showWallopsDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('WALLOPS - Mensaje a Operadores', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (messageController.text.trim().isNotEmpty) {
                _ircService.wallops(messageController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enviando WALLOPS...')),
                );
              }
            },
            child: Text('WALLOPS', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showGlobopsDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('GLOBOPS - Mensaje Global', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (messageController.text.trim().isNotEmpty) {
                _ircService.globops(messageController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enviando GLOBOPS...')),
                );
              }
            },
            child: Text('GLOBOPS', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAdmindDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('ADMIND - Mensaje a Administradores', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (messageController.text.trim().isNotEmpty) {
                _ircService.admind(messageController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enviando ADMIND...')),
                );
              }
            },
            child: Text('ADMIND', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLocopsDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('LOCOPS - Mensaje a Operadores Locales', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (messageController.text.trim().isNotEmpty) {
                _ircService.locops(messageController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enviando LOCOPS...')),
                );
              }
            },
            child: Text('LOCOPS', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDccdenyDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('DCCDENY - Denegar DCC', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickController,
              decoration: InputDecoration(
                labelText: 'Nick',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (nickController.text.trim().isNotEmpty) {
                _ircService.dccdenyUser(nickController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Denegando DCC de ${nickController.text.trim()}...')),
                );
              }
            },
            child: Text('DCCDENY', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUndccdenyDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('UNDCCDENY - Permitir DCC', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickController,
              decoration: InputDecoration(
                labelText: 'Nick',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (nickController.text.trim().isNotEmpty) {
                _ircService.undccdenyUser(nickController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Permitiendo DCC de ${nickController.text.trim()}...')),
                );
              }
            },
            child: Text('UNDCCDENY', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTsctlDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final commandController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('TSCTL - Control de Timestamp', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: commandController,
              decoration: InputDecoration(
                labelText: 'Comando',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'alltime, etc.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (commandController.text.trim().isNotEmpty) {
                _ircService.tsctlCommand(commandController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ejecutando TSCTL ${commandController.text.trim()}...')),
                );
              }
            },
            child: Text('TSCTL', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMkpasswdDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('MKPASSWD - Generar Hash', style: TextStyle(color: appTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                labelStyle: TextStyle(color: appTheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (passwordController.text.trim().isNotEmpty) {
                _ircService.mkpasswd(passwordController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generando hash de contraseña...')),
                );
              }
            },
            child: Text('MKPASSWD', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
          ),
        ],
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
          child: SingleChildScrollView(
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
              Consumer(
                builder: (context, ref, _) {
                  final delaySeconds = ref.watch(messageSendDelayProvider);
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.timer, color: Colors.amber),
                    ),
                    title: const Text('Delay de Envío'),
                    subtitle: Text('Esperar ${delaySeconds}s antes de enviar (${delaySeconds == 0 ? "desactivado" : "activado"})'),
                    onTap: () {
                      Navigator.pop(context);
                      _showMessageDelayDialog(context);
                    },
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
                  child: const Icon(Icons.admin_panel_settings, color: Colors.orange),
                ),
                title: const Text('Autenticarse como IRCop'),
                subtitle: Builder(
                  builder: (context) {
                    final isIRCOp = _ircService.isIRCOp;
                    return Text(
                      isIRCOp ? 'Ya estás autenticado como operador' : 'Autenticarse como operador IRC',
                      style: TextStyle(
                        color: isIRCOp ? Colors.green : null,
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showOperDialog(context, nick);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.deepOrange),
                ),
                title: const Text('Menú IRCop'),
                subtitle: Builder(
                  builder: (context) {
                    final isIRCOp = _ircService.isIRCOp;
                    return Text(
                      isIRCOp ? 'Abrir menú de comandos IRCop' : 'Abrir menú IRCop (requiere autenticación)',
                      style: TextStyle(
                        color: isIRCOp ? Colors.green : Colors.orange,
                      ),
                    );
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showIRCOpMenu(context);
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
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_sweep, color: Colors.red),
                ),
                title: const Text('Limpiar todos los favoritos'),
                subtitle: const Text('Eliminar todos los canales de favoritos'),
                onTap: () {
                  Navigator.pop(context);
                  _showClearFavoritesDialog(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bug_report, color: Colors.orange),
                ),
                title: const Text('Debug: Ver favoritos actuales'),
                subtitle: const Text('Ver qué favoritos están cargados en la consola'),
                onTap: () {
                  Navigator.pop(context);
                  final favorites = ref.read(favoritesProvider).toList();
                  print('🔍 [DEBUG] Favoritos actuales en el provider: $favorites');
                  print('🔍 [DEBUG] Total: ${favorites.length}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Favoritos: ${favorites.length} canales. Ver consola para detalles.'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearFavoritesDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Limpiar todos los favoritos',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar todos los canales de favoritos? Esta acción no se puede deshacer.',
          style: TextStyle(color: appTheme.textSecondary),
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                final favoritesNotifier = ref.read(favoritesProvider.notifier);
                final dynamic notifier = favoritesNotifier;
                if (notifier.runtimeType.toString().contains('FavoritesNotifier')) {
                  await notifier.clearAllFavorites();
                  // Forzar rebuild de la UI
                  if (mounted) {
                    setState(() {});
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Todos los favoritos han sido eliminados. Reinicia la aplicación para aplicar los cambios completamente.'),
                      duration: Duration(seconds: 4),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error al limpiar favoritos: $e'),
                    duration: const Duration(seconds: 3),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Limpiar',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOperDialog(BuildContext context, String currentNick) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController(text: currentNick);
    final passwordController = TextEditingController();
    final isIRCOp = _ircService.isIRCOp;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              'Autenticarse como IRCop',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isIRCOp) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ya estás autenticado como operador IRC',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: nickController,
              style: TextStyle(color: appTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nick de operador',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'Tu nick de operador',
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
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: appTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Contraseña de operador',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: 'Contraseña de operador',
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
            ),
            const SizedBox(height: 12),
            Text(
              'Nota: La contraseña se enviará al servidor para autenticarte como operador IRC.',
              style: TextStyle(
                color: appTheme.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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
              final operNick = nickController.text.trim();
              final operPassword = passwordController.text.trim();
              
              if (operNick.isEmpty || operPassword.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Por favor ingresa un nick y contraseña válidos'),
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }
              
              _ircService.oper(operNick, operPassword);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Intentando autenticarse como operador IRC...'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text(
              'Autenticarse',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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

  void _showMessageDelayDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final currentDelay = ref.read(messageSendDelayProvider);
    final delayController = TextEditingController(text: currentDelay.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Delay de Envío de Mensajes',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configura cuántos segundos esperar antes de enviar mensajes al servidor. Durante este tiempo puedes eliminar el mensaje antes de que se envíe.',
              style: TextStyle(
                color: appTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: delayController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: appTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Segundos de delay (0-300)',
                labelStyle: TextStyle(color: appTheme.primary),
                hintText: '10',
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
            ),
            const SizedBox(height: 8),
            Text(
              'Valor actual: ${currentDelay}s ${currentDelay == 0 ? "(desactivado)" : ""}',
              style: TextStyle(
                color: appTheme.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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
              final delayText = delayController.text.trim();
              final delay = int.tryParse(delayText);
              if (delay != null && delay >= 0 && delay <= 300) {
                ref.read(messageSendDelayProvider.notifier).setDelay(delay);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      delay == 0 
                        ? 'Delay desactivado. Los mensajes se enviarán inmediatamente.'
                        : 'Delay configurado a ${delay}s. Los mensajes esperarán ${delay} segundos antes de enviarse.',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor ingresa un número entre 0 y 300'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              'Guardar',
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

  void _showChannelRegistrationDialog(BuildContext context) async {
    final appTheme = ref.read(themeProvider);
    final currentNick = ref.read(currentNicknameProvider) ?? '';
    
    if (currentNick.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No estás conectado. Por favor, conéctate primero.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Verificar el status del nick primero
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Verificando registro del nick...',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
    
    final statusCompleter = _ircService.checkNickStatus(currentNick);
    final status = await statusCompleter.future;
    
    if (!context.mounted) return;
    Navigator.pop(context); // Cerrar diálogo de carga
    
    if (status != 3) {
      // El nick no está registrado
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: appTheme.surface,
          title: Text(
            'Nick no registrado',
            style: TextStyle(color: appTheme.textPrimary),
          ),
          content: Text(
            'Tu nick "$currentNick" no está registrado (status: ${status ?? "desconocido"}). '
            'Debes registrar tu nick primero antes de poder registrar un canal.\n\n'
            'Status 3 = Registrado\n'
            'Status 0 = No registrado',
            style: TextStyle(color: appTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cerrar',
                style: TextStyle(color: appTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showNickRegistrationDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.primary,
              ),
              child: const Text('Registrar Nick'),
            ),
          ],
        ),
      );
      return;
    }
    
    // El nick está registrado, mostrar el formulario
    final channelController = TextEditingController();
    final logoController = TextEditingController();
    final descriptionController = TextEditingController();
    final emailController = TextEditingController();
    final webController = TextEditingController();
    final topicController = TextEditingController();
    final passwordController = TextEditingController();
    final antispamController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool _obscurePassword = true;
    bool _isSubmitting = false;
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
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
                  // Header
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
                            '📢',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registro de Canal',
                                style: TextStyle(
                                  color: appTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Registra un nuevo canal en GlobalChat',
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
                  // Contenido con scroll
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Nombre del canal
                          TextFormField(
                            controller: channelController,
                            style: TextStyle(color: appTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Nombre del canal *',
                              labelStyle: TextStyle(color: appTheme.primary),
                              hintText: '#micanal',
                              hintStyle: TextStyle(color: appTheme.textSecondary),
                              prefixIcon: const Icon(Icons.tag),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'El nombre del canal es requerido';
                              }
                              if (!value.startsWith('#')) {
                                return 'El canal debe comenzar con #';
                              }
                              if (value.length < 3) {
                                return 'El canal debe tener al menos 3 caracteres';
                              }
                              if (!RegExp(r'^#[a-zA-Z0-9\[\]\-_]+$').hasMatch(value)) {
                                return 'Solo se permiten letras, números, [], - y _';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Logo del canal (opcional)
                          TextFormField(
                            controller: logoController,
                            style: TextStyle(color: appTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Logo del canal (opcional)',
                              labelStyle: TextStyle(color: appTheme.primary),
                              hintText: 'URL del logo',
                              hintStyle: TextStyle(color: appTheme.textSecondary),
                              prefixIcon: const Icon(Icons.image),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Descripción
                          TextFormField(
                            controller: descriptionController,
                            style: TextStyle(color: appTheme.textPrimary),
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Descripción *',
                              labelStyle: TextStyle(color: appTheme.primary),
                              hintText: 'Describe tu canal',
                              hintStyle: TextStyle(color: appTheme.textSecondary),
                              prefixIcon: const Icon(Icons.description),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La descripción es requerida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Email
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: appTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Email de contacto *',
                              labelStyle: TextStyle(color: appTheme.primary),
                              hintText: 'tu@email.com',
                              hintStyle: TextStyle(color: appTheme.textSecondary),
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'El email es requerido';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Email inválido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Web (opcional)
                          TextFormField(
                            controller: webController,
                            keyboardType: TextInputType.url,
                            style: TextStyle(color: appTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Web (opcional)',
                              labelStyle: TextStyle(color: appTheme.primary),
                              hintText: 'https://tuweb.com',
                              hintStyle: TextStyle(color: appTheme.textSecondary),
                              prefixIcon: const Icon(Icons.language),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Topic (opcional)
                          TextFormField(
                            controller: topicController,
                            style: TextStyle(color: appTheme.textPrimary),
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Topic (opcional)',
                              labelStyle: TextStyle(color: appTheme.primary),
                              hintText: 'Tema del canal',
                              hintStyle: TextStyle(color: appTheme.textSecondary),
                              prefixIcon: const Icon(Icons.topic),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Nick de IRC (readonly)
                          TextFormField(
                            initialValue: currentNick,
                            readOnly: true,
                            style: TextStyle(color: appTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Nick de IRC *',
                              labelStyle: TextStyle(color: appTheme.primary),
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Contraseña del nick
                          TextFormField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: appTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Contraseña del nick *',
                              labelStyle: TextStyle(color: appTheme.primary),
                              hintText: 'Contraseña de tu nick',
                              hintStyle: TextStyle(color: appTheme.textSecondary),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La contraseña es requerida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Pregunta antispam
                          TextFormField(
                            controller: antispamController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: appTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Pregunta antispam: ¿Cuánto es 3 + 4? *',
                              labelStyle: TextStyle(color: appTheme.primary),
                              hintText: '7',
                              hintStyle: TextStyle(color: appTheme.textSecondary),
                              prefixIcon: const Icon(Icons.security),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: appTheme.background,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La respuesta es requerida';
                              }
                              if (value.trim() != '7') {
                                return 'Respuesta incorrecta';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Botones
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: appTheme.surface.withOpacity(0.5),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
                            onPressed: _isSubmitting ? null : () async {
                              if (formKey.currentState!.validate()) {
                                setDialogState(() {
                                  _isSubmitting = true;
                                });
                                
                                // Abrir el formulario web con los datos
                                final url = Uri.parse('https://registro-chan.globalchat.org/formulario.html');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Formulario abierto en el navegador. Por favor, completa el registro allí.',
                                        ),
                                        duration: const Duration(seconds: 4),
                                        backgroundColor: appTheme.primary,
                                      ),
                                    );
                                  }
                                } else {
                                  setDialogState(() {
                                    _isSubmitting = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('No se pudo abrir el formulario web'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        appTheme.textPrimary,
                                      ),
                                    ),
                                  )
                                : const Text('Registrar Canal'),
                          ),
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

  void _showVirtualIPDialog(BuildContext context) async {
    final appTheme = ref.read(themeProvider);
    final currentNick = ref.read(currentNicknameProvider) ?? '';
    
    if (currentNick.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No estás conectado. Por favor, conéctate primero.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // Verificar el status del nick primero
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Verificando registro del nick...',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
    
    final statusCompleter = _ircService.checkNickStatus(currentNick);
    final status = await statusCompleter.future;
    
    if (!context.mounted) return;
    Navigator.pop(context); // Cerrar diálogo de carga
    
    if (status != 3) {
      // El nick no está registrado
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: appTheme.surface,
          title: Text(
            'Nick no registrado',
            style: TextStyle(color: appTheme.textPrimary),
          ),
          content: Text(
            'Tu nick "$currentNick" no está registrado (status: ${status ?? "desconocido"}). '
            'Debes registrar tu nick primero antes de poder solicitar una IP virtual.\n\n'
            'Status 3 = Registrado\n'
            'Status 0 = No registrado',
            style: TextStyle(color: appTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cerrar',
                style: TextStyle(color: appTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showNickRegistrationDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: appTheme.primary,
              ),
              child: const Text('Registrar Nick'),
            ),
          ],
        ),
      );
      return;
    }
    
    // El nick está registrado, mostrar el formulario
    final vhostController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool _isSubmitting = false;
    
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
                  // Header
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
                            '🌐',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Solicitar IP Virtual',
                                style: TextStyle(
                                  color: appTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Solicita un host virtual (vhost) para tu nick',
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
                  // Contenido
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Información
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: appTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: appTheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: appTheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Información',
                                    style: TextStyle(
                                      color: appTheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Un host virtual (vhost) te permite ocultar tu IP real y mostrar un host personalizado. '
                                'Ejemplo: usuario.globalchat.org',
                                style: TextStyle(
                                  color: appTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Vhost
                        TextFormField(
                          controller: vhostController,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Host Virtual (vhost) *',
                            labelStyle: TextStyle(color: appTheme.primary),
                            hintText: 'usuario.globalchat.org',
                            hintStyle: TextStyle(color: appTheme.textSecondary),
                            prefixIcon: const Icon(Icons.dns),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: appTheme.background,
                            helperText: 'El vhost debe ser un nombre de host válido',
                            helperStyle: TextStyle(
                              color: appTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'El vhost es requerido';
                            }
                            // Validar formato de host (ej: usuario.globalchat.org)
                            if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]*[a-zA-Z0-9]$').hasMatch(value)) {
                              return 'Formato de host inválido';
                            }
                            if (value.length < 3) {
                              return 'El vhost debe tener al menos 3 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Nick de IRC (readonly)
                        TextFormField(
                          initialValue: currentNick,
                          readOnly: true,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Nick de IRC *',
                            labelStyle: TextStyle(color: appTheme.primary),
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: appTheme.background.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botones
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: appTheme.surface.withOpacity(0.5),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
                            onPressed: _isSubmitting ? null : () async {
                              if (formKey.currentState!.validate()) {
                                setDialogState(() {
                                  _isSubmitting = true;
                                });
                                
                                final vhost = vhostController.text.trim();
                                
                                // Enviar comando REQUEST al bot ipvirtual
                                _ircService.sendServiceMessage('ipvirtual', 'REQUEST $vhost');
                                
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Solicitando IP virtual "$vhost" a IpVirtual...',
                                      ),
                                      duration: const Duration(seconds: 3),
                                      backgroundColor: appTheme.primary,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        appTheme.textPrimary,
                                      ),
                                    ),
                                  )
                                : const Text('Solicitar IP Virtual'),
                          ),
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

