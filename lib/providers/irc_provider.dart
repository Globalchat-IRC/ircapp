import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart'
    show Notifier, NotifierProvider, Provider;
import 'package:riverpod/legacy.dart' show StateProvider;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/irc_message.dart';
import '../models/whois_info.dart';
import '../models/emoji_config.dart';
import '../models/server_profile.dart';
import '../models/custom_robot.dart';
import '../services/irc_service.dart';
import '../services/radio_service.dart';
import '../services/chat_history_service.dart';
import '../services/translation_service.dart';
import '../services/avatar_service.dart';
import '../utils/platform_utils.dart';
import 'history_provider.dart';
import 'radio_provider.dart';
import '../config/debug_config.dart';
import '../models/custom_action.dart';
import 'qualia_radio_dj_provider.dart';

final ircServiceProvider = Provider<IRCService>((ref) {
  return IRCService();
});

/// Alias de comandos personalizados (estilo Revolution IRC): nombre -> plantilla.
/// Las plantillas admiten ${nick}, ${channel}, ${args} y ${1..9}.
class CommandAliasesNotifier extends Notifier<Map<String, String>> {
  static const _storageKey = 'irc_command_aliases';

  @override
  Map<String, String> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        state = decoded.map(
          (k, v) => MapEntry(k.toLowerCase(), v as String),
        );
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state));
    } catch (_) {}
  }

  void setAlias(String name, String template) {
    final key = name.toLowerCase();
    state = {...state, key: template};
    _persist();
  }

  void removeAlias(String name) {
    final key = name.toLowerCase();
    if (!state.containsKey(key)) return;
    state = {...state}..remove(key);
    _persist();
  }
}

final commandAliasesProvider =
    NotifierProvider<CommandAliasesNotifier, Map<String, String>>(
  CommandAliasesNotifier.new,
);

final messagesProvider = NotifierProvider<MessagesNotifier, List<IRCMessage>>(
  () {
    final notifier = MessagesNotifier();
    // Observar cambios en el historial para cargar/guardar mensajes
    // Esto se hace en el build del notifier
    return notifier;
  },
);

final channelsProvider =
    NotifierProvider<ChannelsNotifier, Map<String, IRCChannel>>(() {
      return ChannelsNotifier();
    });

final connectionStatusProvider =
    NotifierProvider<ConnectionStatusNotifier, bool>(() {
      return ConnectionStatusNotifier();
    });

/// Indica si está conectado via ZNC
final isZncConnectionProvider = NotifierProvider<IsZncConnectionNotifier, bool>(
  () {
    return IsZncConnectionNotifier();
  },
);

class IsZncConnectionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setZncConnection(bool isZnc) {
    state = isZnc;
  }
}

/// Lag (latencia) con el servidor IRC en milisegundos
final lagProvider = NotifierProvider<LagNotifier, int?>(() {
  return LagNotifier();
});

class LagNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void updateLag(int milliseconds) {
    // Si el lag es 0, resetear a null (desconectado)
    if (milliseconds == 0) {
      state = null;
    } else {
      state = milliseconds;
    }
  }

  void reset() {
    state = null;
  }
}

final currentNicknameProvider = StateProvider<String?>((ref) => null);

/// Delay en segundos antes de enviar mensajes al servidor (configurable)
final messageSendDelayProvider =
    NotifierProvider<MessageSendDelayNotifier, int>(() {
      return MessageSendDelayNotifier();
    });

class MessageSendDelayNotifier extends Notifier<int> {
  static const _prefsKey = 'message_send_delay_seconds';
  static const int _defaultDelay = 0; // ponytail: 10s era el default viejo; el mensaje se veía en chat antes de ir al servidor

  @override
  int build() {
    _loadFromPrefs();
    return _defaultDelay;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var delay = prefs.getInt(_prefsKey) ?? _defaultDelay;
      // ponytail: migrar instalaciones con el default antiguo (10s)
      if (delay == 10 && !(prefs.getBool('message_send_delay_migrated_v5050') ?? false)) {
        delay = 0;
        await prefs.setInt(_prefsKey, 0);
        await prefs.setBool('message_send_delay_migrated_v5050', true);
      }
      state = delay;
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> setDelay(int seconds) async {
    if (seconds < 0) seconds = 0;
    if (seconds > 300) seconds = 300; // Máximo 5 minutos
    state = seconds;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, seconds);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }
}

/// Usar NOTICE en lugar de PRIVMSG para mensajes privados (persistido en Ajustes)
final useNoticeForPrivateProvider =
    NotifierProvider<UseNoticeForPrivateNotifier, bool>(() {
      return UseNoticeForPrivateNotifier();
    });

class UseNoticeForPrivateNotifier extends Notifier<bool> {
  static const _prefsKey = 'use_notice_for_private';

  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {}
  }

  Future<void> setValue(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }

  Future<void> toggle() async => setValue(!state);
}

final currentChannelProvider = StateProvider<String?>((ref) => null);

/// Estado de away del usuario actual
final userAwayStatusProvider =
    NotifierProvider<UserAwayStatusNotifier, UserAwayStatus>(() {
      return UserAwayStatusNotifier();
    });

class UserAwayStatus {
  final bool isAway;
  final String? awayMessage;

  UserAwayStatus({this.isAway = false, this.awayMessage});

  UserAwayStatus copyWith({bool? isAway, String? awayMessage}) {
    return UserAwayStatus(
      isAway: isAway ?? this.isAway,
      awayMessage: awayMessage ?? this.awayMessage,
    );
  }
}

class UserAwayStatusNotifier extends Notifier<UserAwayStatus> {
  @override
  UserAwayStatus build() => UserAwayStatus();

  void setAway(String? message) {
    state = state.copyWith(isAway: true, awayMessage: message);
  }

  void setBack() {
    state = state.copyWith(isAway: false, awayMessage: null);
  }

  void updateAwayMessage(String? message) {
    if (state.isAway) {
      state = state.copyWith(awayMessage: message);
    }
  }
}

/// Mensaje de away por defecto
final defaultAwayMessageProvider =
    NotifierProvider<DefaultAwayMessageNotifier, String?>(() {
      return DefaultAwayMessageNotifier();
    });

class DefaultAwayMessageNotifier extends Notifier<String?> {
  static const _prefsKey = 'default_away_message';

  @override
  String? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final message = prefs.getString(_prefsKey);
      state = message;
      // Actualizar IRCService con el mensaje cargado
      final ircService = ref.read(ircServiceProvider);
      ircService.setDefaultAwayMessage(message);
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> setMessage(String? message) async {
    state = message;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (message != null && message.isNotEmpty) {
        await prefs.setString(_prefsKey, message);
      } else {
        await prefs.remove(_prefsKey);
      }
      // Actualizar IRCService
      final ircService = ref.read(ircServiceProvider);
      ircService.setDefaultAwayMessage(message);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }
}

/// Último canal utilizado, para recordar la selección al volver al login
final lastChannelProvider = StateProvider<String?>((ref) => null);

/// Lista de canales para autojoin cuando se cambia de servidor
final autoJoinChannelsProvider = StateProvider<List<String>>((ref) => []);

/// Controla si se debe mostrar el modal de identificación de NickServ (nick registrado).
/// - Por defecto es false (no mostrar modal).
/// - Se activa explícitamente en el login solo cuando la sesión se inicia
///   mediante parámetros de URL con autojoin=true.
final nickIdentifyModalAllowedProvider = StateProvider<bool>((ref) => false);

/// Canales/nicks marcados como favoritos (para autounirse y sección destacada)
final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(() {
  return FavoritesNotifier();
});

/// Lista de canales/nicks recientes (histórico ligero de uso)
final recentChannelsProvider =
    NotifierProvider<RecentChannelsNotifier, List<String>>(() {
      return RecentChannelsNotifier();
    });

/// Lista de privados (queries) archivados.
/// - Solo se aplica a canales que NO empiezan por # (mensajes privados).
/// - Se almacenan como nicks en minúsculas en SharedPreferences.
final archivedPrivatesProvider =
    NotifierProvider<ArchivedPrivatesNotifier, Set<String>>(() {
      return ArchivedPrivatesNotifier();
    });

/// Mensajes fijados por canal (avisos, reglas, enlaces importantes)
final pinnedMessagesProvider =
    NotifierProvider<PinnedMessagesNotifier, Map<String, List<IRCMessage>>>(() {
      return PinnedMessagesNotifier();
    });

/// Reglas de notificación por canal y tipo de sonido
final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(() {
      return NotificationSettingsNotifier();
    });

/// Chats privados con cifrado punto a punto activado (solo cliente local).
/// Clave: nick en minúsculas (canales que no empiezan por #).
final encryptedPrivatesProvider =
    NotifierProvider<EncryptedPrivatesNotifier, Set<String>>(() {
      return EncryptedPrivatesNotifier();
    });

/// Notas privadas por usuario (solo cliente local).
/// Clave: nick en minúsculas, valor: texto libre.
final userNotesProvider =
    NotifierProvider<UserNotesNotifier, Map<String, String>>(() {
      return UserNotesNotifier();
    });

/// Tamaño de fuente del chat: 0=pequeño, 1=normal, 2=grande, 3=muy grande
final chatFontSizeProvider = NotifierProvider<ChatFontSizeNotifier, int>(() {
  return ChatFontSizeNotifier();
});

class ChatFontSizeNotifier extends Notifier<int> {
  static const _prefsKey = 'chat_font_size';
  static const int _default = 1; // normal

  @override
  int build() {
    _loadFromPrefs();
    return _default;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getInt(_prefsKey) ?? _default;
    } catch (_) {}
  }

  Future<void> setFontSize(int value) async {
    if (value < 0 || value > 3) return;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, value);
    } catch (_) {}
  }
}

/// Reducir animaciones (accesibilidad)
final reduceMotionProvider = NotifierProvider<ReduceMotionNotifier, bool>(() {
  return ReduceMotionNotifier();
});

class ReduceMotionNotifier extends Notifier<bool> {
  static const _prefsKey = 'reduce_motion';

  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {}
  }

  Future<void> setReduceMotion(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }
}

/// Plantillas / respuestas rápidas (lista de textos)
final quickRepliesProvider =
    NotifierProvider<QuickRepliesNotifier, List<String>>(() {
      return QuickRepliesNotifier();
    });

class QuickRepliesNotifier extends Notifier<List<String>> {
  static const _prefsKey = 'quick_replies';

  @override
  List<String> build() {
    _loadFromPrefs();
    return [];
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey);
      state = list ?? [];
    } catch (_) {}
  }

  Future<void> setQuickReplies(List<String> list) async {
    state = List.from(list);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, state);
    } catch (_) {}
  }

  Future<void> addQuickReply(String text) async {
    if (text.trim().isEmpty) return;
    state = [...state, text.trim()];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, state);
    } catch (_) {}
  }

  Future<void> removeQuickReplyAt(int index) async {
    if (index < 0 || index >= state.length) return;
    state = List.from(state)..removeAt(index);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, state);
    } catch (_) {}
  }
}

/// Perfil de servidor actual (para multi-servidor/multi-red)
/// Persistido en SharedPreferences para mantener el valor entre navegaciones
final currentServerProfileProvider =
    NotifierProvider<CurrentServerProfileNotifier, ServerProfile?>(() {
      return CurrentServerProfileNotifier();
    });

class CurrentServerProfileNotifier extends Notifier<ServerProfile?> {
  static const _prefsKey = 'current_server_profile_v1';

  @override
  ServerProfile? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverId = prefs.getString(_prefsKey);
      debugLog('🔍 [SERVER_PROFILE] Leyendo desde prefs, serverId: $serverId');
      if (serverId != null && serverId.isNotEmpty) {
        // Buscar el perfil por ID en la lista de perfiles por defecto
        final profile = ServerProfile.activeProfiles.firstWhere(
          (p) => p.id == serverId,
          orElse: () => ServerProfile.activeProfiles.firstWhere(
            (p) => p.isDefault,
            orElse: () => ServerProfile.activeProfiles.first,
          ),
        );
        state = profile;
        debugLog(
          '🔍 [SERVER_PROFILE] ✅ Cargado desde prefs: ${profile.name} (${profile.host}:${profile.port})',
        );
      } else {
        debugLog('🔍 [SERVER_PROFILE] No hay serverId guardado en prefs');
      }
    } catch (e) {
      debugLog('❌ [SERVER_PROFILE] Error cargando desde prefs: $e');
    }
  }

  Future<void> setServerProfile(ServerProfile profile) async {
    debugLog(
      '🔍 [SERVER_PROFILE] setServerProfile llamado: ${profile.name} (${profile.host}:${profile.port}, id: ${profile.id})',
    );
    state = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, profile.id);
      debugLog(
        '🔍 [SERVER_PROFILE] ✅ Guardado en prefs: ${profile.name} (id: ${profile.id})',
      );

      // Verificar que se guardó correctamente
      final savedId = prefs.getString(_prefsKey);
      debugLog(
        '🔍 [SERVER_PROFILE] Verificación - serverId en prefs: $savedId',
      );
    } catch (e) {
      debugLog('❌ [SERVER_PROFILE] Error guardando en prefs: $e');
    }
  }

  void clearServerProfile() {
    state = null;
    try {
      final prefs = SharedPreferences.getInstance();
      prefs.then((p) => p.remove(_prefsKey));
    } catch (e) {
      debugLog('❌ [SERVER_PROFILE] Error limpiando prefs: $e');
    }
  }
}

/// Lista de perfiles de servidor disponibles (inicialmente los de GlobalChat)
final serverProfilesProvider =
    NotifierProvider<ServerProfilesNotifier, List<ServerProfile>>(() {
      return ServerProfilesNotifier();
    });

final whoisProvider = NotifierProvider<WhoisNotifier, Map<String, WhoisInfo>>(
  () {
    return WhoisNotifier();
  },
);

final emojiConfigProvider = NotifierProvider<EmojiConfigNotifier, EmojiConfig>(
  () {
    return EmojiConfigNotifier();
  },
);

// Provider para mensajes no leídos por canal
final unreadMessagesProvider =
    NotifierProvider<UnreadMessagesNotifier, Map<String, int>>(() {
      return UnreadMessagesNotifier();
    });

class MessagesNotifier extends Notifier<List<IRCMessage>> {
  static const String _privateMessagesKey = 'private_messages_web';
  static const String _allMessagesKey = 'all_messages_history';
  IRCService? _service;
  Timer? _saveTimer;

  @override
  List<IRCMessage> build() {
    _service = ref.read(ircServiceProvider);
    _service!.addMessageListener(_onMessage);
    _service!.addPendingRemovalListener(_onPendingRemoved);
    ref.onDispose(() {
      _service?.removeMessageListener(_onMessage);
      _service?.removePendingRemovalListener(_onPendingRemoved);
    });
    // Observar cambios en el historial
    ref.listen<bool>(historyEnabledProvider, (previous, next) {
      final wasEnabled = previous ?? false;
      if (next && !wasEnabled) {
        // Historial activado: cargar mensajes guardados
        loadHistory();
      }
    });
    // Cargar historial si está activado
    _loadHistoryIfEnabled();
    return [];
  }

  /// Cargar historial si está activado
  Future<void> _loadHistoryIfEnabled() async {
    final historyEnabled = ref.read(historyEnabledProvider);
    if (historyEnabled) {
      await loadHistory();
    } else {
      // Si el historial no está activado, solo cargar mensajes privados (comportamiento anterior)
      await _loadPrivateMessages();
    }
  }

  /// Cargar todo el historial de mensajes (canales y privados)
  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_allMessagesKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final loadedMessages = jsonList
            .map((json) => IRCMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        // Filtrar mensajes duplicados basándose en messageId o contenido único
        final Map<String, IRCMessage> uniqueMessages = {};
        for (var msg in loadedMessages) {
          final key =
              msg.messageId ??
              '${msg.channel}_${msg.nick}_${msg.message}_${msg.timestamp.millisecondsSinceEpoch}';
          if (!uniqueMessages.containsKey(key)) {
            uniqueMessages[key] = msg;
          }
        }

        // Actualizar el estado con todos los mensajes cargados (sin duplicados)
        state = uniqueMessages.values.toList();
        debugLog(
          '✅ [MessagesNotifier] Historial cargado: ${state.length} mensajes únicos',
        );
      }
    } catch (e) {
      debugLog('⚠️ [MessagesNotifier] Error cargando historial: $e');
    }
  }

  /// Guardar todo el historial de mensajes (canales y privados).
  /// Se conservan las últimas 100 líneas por canal/privado para respetar la
  /// opción "Mantener historial de chats y privados" del ajustes generales.
  Future<void> _saveHistory() async {
    final historyEnabled = ref.read(historyEnabledProvider);
    if (!historyEnabled) return; // No guardar si el historial está desactivado

    try {
      // Agrupar por canal (case-insensitive) y conservar solo los 100 más recientes
      const maxPerChannel = 100;
      final Map<String, List<IRCMessage>> grouped = {};
      for (final msg in state) {
        final key = msg.channel.toLowerCase();
        grouped.putIfAbsent(key, () => []).add(msg);
      }
      final messagesToSave = <IRCMessage>[];
      for (final list in grouped.values) {
        // Ordenar por timestamp y quedarnos con los últimos 100
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        messagesToSave.addAll(
          list.length > maxPerChannel
              ? list.sublist(list.length - maxPerChannel)
              : list,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonList = messagesToSave.map((msg) => msg.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_allMessagesKey, jsonString);
      // Guardar también en la clave antigua para compatibilidad
      await _savePrivateMessages();
    } catch (e) {
      debugLog('⚠️ [MessagesNotifier] Error guardando historial: $e');
    }
  }

  /// Actualizar estado y guardar historial si está activado
  void _updateStateAndSave(List<IRCMessage> newState) {
    state = newState;
    // Debounce: guardar historial después de 1s de inactividad para no bloquear el UI
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () => _saveHistory());
  }

  void replaceAll(List<IRCMessage> messages) {
    _updateStateAndSave(messages);
  }

  /// Cargar mensajes privados desde SharedPreferences (solo en web)
  Future<void> _loadPrivateMessages() async {
    if (!PlatformUtils.isWeb) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_privateMessagesKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final privateMessages = jsonList
            .map((json) => IRCMessage.fromJson(json as Map<String, dynamic>))
            .where(
              (msg) => !msg.channel.startsWith('#'),
            ) // Solo mensajes privados
            .toList();

        // Añadir los mensajes privados al estado actual (sin duplicar canales)
        final currentChannels = state
            .where((m) => m.channel.startsWith('#'))
            .toList();
        state = [...currentChannels, ...privateMessages];
      }
    } catch (e) {
      // Ignorar errores de carga
      debugLog('⚠️ [MessagesNotifier] Error cargando mensajes privados: $e');
    }
  }

  /// Guardar mensajes privados en SharedPreferences (solo en web).
  /// Se conservan las últimas 100 líneas por conversación privada.
  Future<void> _savePrivateMessages() async {
    if (!PlatformUtils.isWeb) return;

    try {
      const maxPerPrivate = 100;
      final grouped = <String, List<IRCMessage>>{};
      for (final msg in state.where((m) => !m.channel.startsWith('#'))) {
        final key = msg.channel.toLowerCase();
        grouped.putIfAbsent(key, () => []).add(msg);
      }
      final privateMessages = <IRCMessage>[];
      for (final list in grouped.values) {
        list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        privateMessages.addAll(
          list.length > maxPerPrivate
              ? list.sublist(list.length - maxPerPrivate)
              : list,
        );
      }

      final jsonList = privateMessages.map((msg) => msg.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_privateMessagesKey, jsonString);
    } catch (e) {
      // Ignorar errores de guardado
      debugLog('⚠️ [MessagesNotifier] Error guardando mensajes privados: $e');
    }
  }

  /// Limpiar todos los mensajes privados (canales que no empiezan con #)
  /// También limpia específicamente mensajes del privado de "nick" y "nickserv"
  void clearPrivateMessages() {
    state = state.where((message) {
      // Mantener solo mensajes de canales (que empiezan con #)
      if (message.channel.startsWith('#')) {
        return true;
      }
      // Eliminar todos los mensajes privados, especialmente de "nick" y "nickserv"
      return false;
    }).toList();
    _saveHistory();
  }

  /// Borrar historial de un canal específico
  Future<void> clearChannelHistory(String channel) async {
    final normalizedChannel = channel.toLowerCase();
    state = state.where((message) {
      return message.channel.toLowerCase() != normalizedChannel;
    }).toList();

    // Borrar del historial guardado en base de datos
    try {
      final server = ref.read(ircServiceProvider).serverHost;
      if (server != null) {
        await ChatHistoryService().deleteChannelHistory(
          server: server,
          channel: channel,
        );
      }
    } catch (e) {
      debugLog('⚠️ [MessagesNotifier] Error borrando historial del canal: $e');
    }

    _saveHistory();
  }

  /// Borrar historial de un privado específico
  Future<void> clearPrivateHistory(String nick) async {
    final normalizedNick = nick.toLowerCase();
    state = state.where((message) {
      // Eliminar mensajes privados con este nick (canal == nick)
      if (!message.channel.startsWith('#')) {
        return message.channel.toLowerCase() != normalizedNick;
      }
      return true; // Mantener mensajes de canales
    }).toList();

    // Borrar del historial guardado en base de datos
    try {
      final server = ref.read(ircServiceProvider).serverHost;
      if (server != null) {
        await ChatHistoryService().deletePrivateHistory(
          server: server,
          nick: nick,
        );
      }
    } catch (e) {
      debugLog('⚠️ [MessagesNotifier] Error borrando historial privado: $e');
    }

    _saveHistory();
  }

  /// Limpiar historial de NickServ (todas las variantes: nick, nickserv, NickServ, etc.)
  Future<void> clearNickServHistory() async {
    // Lista de todas las variantes posibles de NickServ
    final nickservVariants = [
      'nick',
      'nickserv',
      'nickserv',
      'NickServ',
      'NICKSERV',
    ];

    // Limpiar de la memoria
    state = state.where((message) {
      // Mantener solo mensajes de canales
      if (message.channel.startsWith('#')) {
        return true;
      }
      // Eliminar mensajes privados donde el canal o el nick sea alguna variante de NickServ
      final channelLower = message.channel.toLowerCase();
      final nickLower = message.nick.toLowerCase();
      for (final variant in nickservVariants) {
        if (channelLower == variant.toLowerCase() ||
            nickLower == variant.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();

    // Borrar del historial guardado en base de datos
    try {
      final server = ref.read(ircServiceProvider).serverHost;
      if (server != null) {
        // Limpiar todas las variantes de la base de datos
        for (final variant in nickservVariants) {
          await ChatHistoryService().deletePrivateHistory(
            server: server,
            nick: variant,
          );
        }
      }
    } catch (e) {
      debugLog(
        '⚠️ [MessagesNotifier] Error borrando historial de NickServ: $e',
      );
    }

    _saveHistory();
    debugLog(
      '✅ [MessagesNotifier] Historial de NickServ limpiado (todas las variantes)',
    );
  }

  void _onMessage(IRCMessage message) {
    // Filtrar mensajes GIFT CTCP (se manejan por separado con popup)
    if (message.message.startsWith('\x01GIFT ') && message.message.endsWith('\x01')) {
      return;
    }

    // Si el mensaje tiene un pendingId, buscar si ya existe un mensaje pendiente con ese ID
    if (message.pendingId != null) {
      final index = state.indexWhere((m) => m.pendingId == message.pendingId);
      if (index != -1) {
        // Actualizar el mensaje existente en lugar de añadir uno nuevo
        final updatedState = List<IRCMessage>.from(state);
        updatedState[index] = message;
        _updateStateAndSave(updatedState);
        return;
      }
    }

    // Si el mensaje no tiene pendingId o no se encontró uno existente, verificar si es una actualización
    // de un mensaje pendiente (isPending cambió de true a false)
    if (!message.isPending) {
      // Buscar mensaje con mismo contenido, canal y nick que sea pendiente
      final index = state.indexWhere(
        (m) =>
            m.isPending &&
            m.channel.toLowerCase() == message.channel.toLowerCase() &&
            m.nick == message.nick &&
            m.message.trim() == message.message.trim() &&
            // Timestamp similar (dentro de 5 segundos)
            (m.timestamp.difference(message.timestamp).inSeconds.abs() < 5),
      );
      if (index != -1) {
        // Actualizar el mensaje existente
        final updatedState = List<IRCMessage>.from(state);
        updatedState[index] = message;
        _updateStateAndSave(updatedState);
        return;
      }
    }

    // Si no es una actualización, añadir como nuevo mensaje
    final updatedState = [...state, message];
    // Limitar el estado en memoria: conservar max 500 mensajes por canal
    if (updatedState.length > 2000) {
      // Eliminar mensajes más antiguos, priorizando conservar mensajes pendientes y recientes
      updatedState.removeRange(0, updatedState.length - 1500);
    }
    _updateStateAndSave(updatedState);

    // Actualizar DJ en vivo de Qualia Radio según mensajes de Orion.
    ref.read(qualiaRadioLiveDjProvider.notifier).processOrionMessage(message);
  }

  void _onPendingRemoved(String channel, String pendingId) {
    final index = state.indexWhere(
      (m) => m.isPending && m.pendingId == pendingId,
    );
    if (index != -1) {
      final updatedState = List<IRCMessage>.from(state);
      updatedState.removeAt(index);
      _updateStateAndSave(updatedState);
    }
  }

  void clearMessages() {
    state = [];
    // Limpiar historial guardado si existe
    _clearSavedHistory();
  }

  /// Limpiar el historial guardado
  Future<void> _clearSavedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_allMessagesKey);
      await prefs.remove(_privateMessagesKey);
    } catch (e) {
      debugLog('⚠️ [MessagesNotifier] Error limpiando historial: $e');
    }
  }

  // Nota: En Riverpod 3.x, Notifier no tiene dispose()
  // Los listeners se limpian automáticamente cuando el provider se destruye
}

class ChannelsNotifier extends Notifier<Map<String, IRCChannel>> {
  IRCService? _service;

  @override
  Map<String, IRCChannel> build() {
    _service = ref.read(ircServiceProvider);
    // Initialize with current channels
    final initialState = {..._service!.channels};
    // Listen for user list updates
    _service!.addUserListListener(_onUserListUpdate);
    return initialState;
  }

  void _onUserListUpdate(String channel) {
    // debugLog('🔍 [DEBUG] 🔄 ChannelsNotifier._onUserListUpdate: channel=$channel');
    // debugLog('🔍 [DEBUG] 📊 Service channels: ${_service.channels.keys.toList()}');
    // debugLog('🔍 [DEBUG] 📊 Current state channels: ${state.keys.toList()}');

    // Always update the entire state with current service state
    final newState = <String, IRCChannel>{};
    for (var entry in _service!.channels.entries) {
      // Crear una copia profunda del canal con usuarios, topic, hosts, modos, bans, etc.
      final channelCopy = entry.value.copy();
      newState[entry.key] = channelCopy;
      // debugLog('🔍 [DEBUG] Copied channel ${entry.key} with ${channelCopy.users.length} users: ${channelCopy.users}, topic: ${channelCopy.topic}');
    }

    if (newState.containsKey(channel)) {
      // debugLog('🔍 [DEBUG] 👥 Channel found in new state, users: ${newState[channel]!.users}');
      // debugLog('🔍 [DEBUG] 👥 Channel users count: ${newState[channel]!.users.length}');
    } else {
      // debugLog('🔍 [DEBUG] ⚠️  Channel not found in service: $channel');
      // debugLog('🔍 [DEBUG] Available channels: ${newState.keys.toList()}');
    }

    // Comparar estados
    newState.entries.any((e) {
      final oldChannel = state[e.key];
      if (oldChannel == null) return true;
      final usersChanged =
          oldChannel.users.length != e.value.users.length ||
          !oldChannel.users.every((u) => e.value.users.contains(u));
      final topicChanged = oldChannel.topic != e.value.topic;
      final modesChanged =
          oldChannel.userModes.length != e.value.userModes.length ||
          oldChannel.userModes.entries.any(
            (entry) => e.value.userModes[entry.key] != entry.value,
          );
      return usersChanged || topicChanged || modesChanged;
    });

    // debugLog('🔍 [DEBUG] Keys changed: $keysChanged, Values changed: $valuesChanged');

    // Always update to ensure UI reflects current state
    // debugLog('🔍 [DEBUG] ✅ Updating state with new channels');
    state = newState;
    // debugLog('🔍 [DEBUG] ✅ State updated, now has ${state.length} channels');
  }

  void updateChannels() {
    // debugLog('🔍 [DEBUG] 🔄 updateChannels() called, service has ${_service.channels.length} channels');
    for (final _ in _service!.channels.entries) {
      // debugLog('🔍 [DEBUG]   - ${entry.key}: ${entry.value.users.length} users: ${entry.value.users}');
    }

    // Crear una copia profunda del estado del servicio
    final newState = <String, IRCChannel>{};
    for (var entry in _service!.channels.entries) {
      // Crear una copia profunda del canal con usuarios, topic, hosts, modos, bans, etc.
      final channelCopy = entry.value.copy();
      newState[entry.key] = channelCopy;
      // debugLog('🔍 [DEBUG] Copied channel ${entry.key} with ${channelCopy.users.length} users, topic: ${channelCopy.topic}');
    }

    // debugLog('🔍 [DEBUG] ✅ Updating state with ${newState.length} channels');
    state = newState;
  }

  // Nota: En Riverpod 3.x, Notifier no tiene dispose()
}

class ConnectionStatusNotifier extends Notifier<bool> {
  IRCService? _service;

  @override
  bool build() {
    _service = ref.read(ircServiceProvider);
    // Inicializar con el estado actual del servicio
    // Esto asegura que si ya está conectado, el estado se refleje correctamente
    final isConnected = _service!.isConnected;
    _service!.addConnectionListener(() => state = true);
    _service!.addDisconnectionListener(() {
      state = false;
      // Si la conexión IRC se cierra (expulsión de red: KILL/GLINE/Closing
      // Link), detener la radio para que no siga sonando sin estar conectado.
      RadioService().stop();
      ref.read(radioProvider.notifier).setPlaying(false);
    });
    return isConnected;
  }
}

class WhoisNotifier extends Notifier<Map<String, WhoisInfo>> {
  IRCService? _service;

  @override
  Map<String, WhoisInfo> build() {
    _service = ref.read(ircServiceProvider);
    _service!.addWhoisListener(_onWhoisReceived);
    // También cargar cualquier información que ya esté en caché
    // (por si se solicitó antes de abrir el perfil)
    return {};
  }

  void _onWhoisReceived(WhoisInfo info) {
    // debugLog('🔍 [WHOIS NOTIFIER] Received whois info for: ${info.nick}');
    // debugLog('🔍 [WHOIS NOTIFIER] Info: ${info.username}@${info.host}, realName: ${info.realName}');
    final newState = {...state, info.nick.toLowerCase(): info};
    state = newState;
    // debugLog('🔍 [WHOIS NOTIFIER] Updated state, now has ${newState.length} entries');
  }

  WhoisInfo? getWhois(String nick) {
    return state[nick.toLowerCase()];
  }

  void requestWhois(String nick) {
    // debugLog('🔍 [WHOIS NOTIFIER] Requesting whois for: $nick');
    // Verificar si ya tenemos la información en caché del servicio
    final cachedInfo = _service?.getWhoisInfo(nick);
    if (cachedInfo != null) {
      // debugLog('🔍 [WHOIS NOTIFIER] Found cached info, updating state');
      _onWhoisReceived(cachedInfo);
    } else {
      // debugLog('🔍 [WHOIS NOTIFIER] No cached info, requesting from server');
      _service?.sendWhois(nick);
    }
  }

  // Nota: En Riverpod 3.x, Notifier no tiene dispose()
}

// Notifier para mensajes no leídos
class UnreadMessagesNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  void incrementUnread(String channel) {
    final normalizedChannel = channel.toLowerCase();
    state = {...state, normalizedChannel: (state[normalizedChannel] ?? 0) + 1};
  }

  void markAsRead(String channel) {
    final normalizedChannel = channel.toLowerCase();
    if (state.containsKey(normalizedChannel)) {
      final newState = {...state};
      newState.remove(normalizedChannel);
      state = newState;
    }
  }

  int getUnreadCount(String channel) {
    return state[channel.toLowerCase()] ?? 0;
  }

  bool hasUnread(String channel) {
    return getUnreadCount(channel) > 0;
  }
}

/// Notifier para favoritos (canales y queries)
class FavoritesNotifier extends Notifier<Set<String>> {
  static const _prefsKey = 'favorite_channels';
  static const _excludedPrefsKey = 'favorite_channels_excluded';

  // Lista de canales que el usuario ha eliminado de favoritos y no deben volver a añadirse automáticamente
  final Set<String> _excludedChannels = {};
  bool _isInitialized = false;
  final Completer<void> _initializationCompleter = Completer<void>();

  @override
  Set<String> build() {
    _initialize();
    return <String>{};
  }

  Future<void> _initialize() async {
    await _loadExcludedChannels();
    await _loadFromPrefs();
    _isInitialized = true;
    if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.complete();
    }
  }

  // Método para esperar a que la inicialización termine
  Future<void> waitForInitialization() async {
    if (_isInitialized) return;
    await _initializationCompleter.future;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? <String>[];
      // debugLog('📋 [FavoritesNotifier] ========== CARGANDO FAVORITOS ==========');
      // debugLog('📋 [FavoritesNotifier] Favoritos RAW de SharedPreferences: $list');
      // debugLog('📋 [FavoritesNotifier] Total favoritos RAW: ${list.length}');
      // debugLog('📋 [FavoritesNotifier] Canales excluidos actuales: $_excludedChannels');
      // debugLog('📋 [FavoritesNotifier] Total excluidos: ${_excludedChannels.length}');

      // Filtrar los canales excluidos al cargar
      final filtered = list
          .map((e) => e.toLowerCase())
          .where((e) => !_excludedChannels.contains(e))
          .toList();

      // debugLog('📋 [FavoritesNotifier] Favoritos después de filtrar excluidos: $filtered');
      // debugLog('📋 [FavoritesNotifier] Total favoritos filtrados: ${filtered.length}');

      // Si hay canales excluidos en la lista guardada, limpiarlos de SharedPreferences
      if (filtered.length != list.length) {
        await prefs.setStringList(_prefsKey, filtered);
        // debugLog('🧹 [FavoritesNotifier] Limpiados ${list.length - filtered.length} canales excluidos de favoritos guardados');
        // debugLog('🧹 [FavoritesNotifier] Canales eliminados específicamente: $removed');
      }

      state = filtered.toSet();
      // debugLog('✅ [FavoritesNotifier] Estado final de favoritos: $state');
      // debugLog('✅ [FavoritesNotifier] Total en estado final: ${state.length}');
      // debugLog('📋 [FavoritesNotifier] ===========================================');
    } catch (e) {
      // debugLog('❌ [FavoritesNotifier] Error al cargar favoritos: $e');
      // Si falla la lectura, simplemente dejamos los favoritos vacíos
    }
  }

  Future<void> _loadExcludedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final excluded = prefs.getStringList(_excludedPrefsKey) ?? <String>[];
      _excludedChannels.addAll(excluded.map((c) => c.toLowerCase()));
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> _saveExcludedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_excludedPrefsKey, _excludedChannels.toList());
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, state.toList());
    } catch (_) {
      // Si falla el guardado, no rompemos la app; solo no se persisten cambios
    }
  }

  String _normalize(String channel) => channel.toLowerCase();

  void toggleFavorite(String channel) {
    final key = _normalize(channel);
    final newState = Set<String>.from(state);
    if (newState.contains(key)) {
      // Si se está eliminando de favoritos, añadir a la lista de excluidos
      newState.remove(key);
      _excludedChannels.add(key);
      _saveExcludedChannels();
      // También eliminar de SharedPreferences inmediatamente
      state = newState;
      _saveToPrefs();
    } else {
      // Si se está añadiendo a favoritos, quitar de la lista de excluidos
      newState.add(key);
      _excludedChannels.remove(key);
      _saveExcludedChannels();
      state = newState;
      _saveToPrefs();
    }
  }

  bool isFavorite(String channel) {
    final key = _normalize(channel);
    // No considerar favorito si está en la lista de excluidos
    if (_excludedChannels.contains(key)) {
      return false;
    }
    return state.contains(key);
  }

  // Método para limpiar la lista de excluidos (útil para debugging)
  void clearExcluded() {
    _excludedChannels.clear();
    _saveExcludedChannels();
  }

  // Método para limpiar todos los favoritos (útil para resetear)
  Future<void> clearAllFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // debugLog('🧹 [FavoritesNotifier] ========== LIMPIANDO TODOS LOS FAVORITOS ==========');
      // debugLog('🧹 [FavoritesNotifier] Estado ANTES de limpiar: $state');
      // debugLog('🧹 [FavoritesNotifier] Excluidos ANTES de limpiar: $_excludedChannels');

      // Obtener los favoritos actuales antes de limpiar para logging
      // debugLog('🧹 [FavoritesNotifier] Favoritos en SharedPreferences ANTES: $currentFavorites');

      // Limpiar favoritos guardados
      await prefs.remove(_prefsKey);
      // debugLog('🧹 [FavoritesNotifier] Favoritos eliminados de SharedPreferences: $removedFavorites');

      // Verificar que se eliminaron correctamente
      prefs.getStringList(_prefsKey);
      // debugLog('🧹 [FavoritesNotifier] Verificación - Favoritos después de remove: $verifyFavorites');

      // Limpiar también la lista de excluidos para permitir que el usuario vuelva a añadir canales
      // debugLog('🧹 [FavoritesNotifier] Excluidos en SharedPreferences ANTES: $currentExcluded');

      _excludedChannels.clear();
      await prefs.remove(_excludedPrefsKey);
      // debugLog('🧹 [FavoritesNotifier] Excluidos eliminados de SharedPreferences: $removedExcluded');

      // Verificar que se eliminaron correctamente
      prefs.getStringList(_excludedPrefsKey);
      // debugLog('🧹 [FavoritesNotifier] Verificación - Excluidos después de remove: $verifyExcluded');

      // Actualizar el estado
      state = <String>{};
      // debugLog('✅ [FavoritesNotifier] Estado DESPUÉS de limpiar: $state');
      // debugLog('✅ [FavoritesNotifier] Excluidos DESPUÉS de limpiar: $_excludedChannels');
      // debugLog('🧹 [FavoritesNotifier] ====================================================');
    } catch (e) {
      // debugLog('❌ [FavoritesNotifier] Error al limpiar favoritos: $e');
    }
  }
}

/// Notifier para canales/nicks recientes
class RecentChannelsNotifier extends Notifier<List<String>> {
  static const int maxItems = 20;
  static const _prefsKey = 'recent_channels_excluded';

  // Lista de canales que el usuario ha eliminado y no deben volver a añadirse automáticamente
  final Set<String> _excludedChannels = {};

  @override
  List<String> build() {
    _loadExcludedChannels();
    return const [];
  }

  String _normalize(String channel) => channel.toLowerCase();

  Future<void> _loadExcludedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final excluded = prefs.getStringList(_prefsKey) ?? <String>[];
      _excludedChannels.addAll(excluded.map((c) => c.toLowerCase()));
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> _saveExcludedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _excludedChannels.toList());
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  void addRecent(String channel) {
    final key = _normalize(channel);
    // No añadir si está en la lista de excluidos
    if (_excludedChannels.contains(key)) {
      return;
    }
    // Evitar duplicados y mantener el orden (más reciente primero)
    final filtered = state
        .where((c) => _normalize(c) != key)
        .toList(growable: true);
    filtered.insert(0, channel);
    if (filtered.length > maxItems) {
      filtered.removeRange(maxItems, filtered.length);
    }
    state = filtered;
  }

  void removeRecent(String channel) {
    final key = _normalize(channel);
    // Añadir a la lista de excluidos para que no se vuelva a añadir automáticamente
    _excludedChannels.add(key);
    _saveExcludedChannels();
    state = state.where((c) => _normalize(c) != key).toList(growable: false);
  }

  void clearExcluded(String channel) {
    final key = _normalize(channel);
    _excludedChannels.remove(key);
    _saveExcludedChannels();
  }
}

/// Notifier para privados con cifrado habilitado.
class EncryptedPrivatesNotifier extends Notifier<Set<String>> {
  static const _prefsKey = 'encrypted_privates_v1';

  @override
  Set<String> build() {
    _loadFromPrefs();
    return <String>{};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? <String>[];
      state = list.map((e) => e.toLowerCase()).toSet();
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, state.toList());
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  String _normalize(String nick) => nick.toLowerCase();

  bool isEncrypted(String nick) => state.contains(_normalize(nick));

  void enable(String nick) {
    final key = _normalize(nick);
    if (!state.contains(key)) {
      state = {...state, key};
      _saveToPrefs();
    }
  }

  void disable(String nick) {
    final key = _normalize(nick);
    if (state.contains(key)) {
      final next = Set<String>.from(state)..remove(key);
      state = next;
      _saveToPrefs();
    }
  }

  void toggle(String nick) {
    final key = _normalize(nick);
    if (state.contains(key)) {
      disable(key);
    } else {
      enable(key);
    }
  }
}

/// Notifier para notas privadas por usuario.
class UserNotesNotifier extends Notifier<Map<String, String>> {
  static const _prefsKey = 'user_private_notes_v1';

  @override
  Map<String, String> build() {
    _loadFromPrefs();
    return <String, String>{};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        final map = <String, String>{};
        decoded.forEach((key, value) {
          map[key.toLowerCase()] = value.toString();
        });
        state = map;
      }
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state));
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  String _normalize(String nick) => nick.toLowerCase();

  String? getNote(String nick) => state[_normalize(nick)];

  Future<void> setNote(String nick, String note) async {
    final key = _normalize(nick);
    final next = Map<String, String>.from(state);
    if (note.trim().isEmpty) {
      next.remove(key);
    } else {
      next[key] = note;
    }
    state = next;
    await _saveToPrefs();
  }

  Future<void> clearNote(String nick) async {
    final key = _normalize(nick);
    if (state.containsKey(key)) {
      final next = Map<String, String>.from(state)..remove(key);
      state = next;
      await _saveToPrefs();
    }
  }
}

/// Notifier para privados archivados (por nick).
class ArchivedPrivatesNotifier extends Notifier<Set<String>> {
  static const _prefsKey = 'archived_privates_v1';

  @override
  Set<String> build() {
    _loadFromPrefs();
    return <String>{};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? <String>[];
      state = list.map((e) => e.toLowerCase()).toSet();
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, state.toList());
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  String _normalize(String nick) => nick.toLowerCase();

  bool isArchived(String nick) => state.contains(_normalize(nick));

  void archive(String nick) {
    final key = _normalize(nick);
    if (!state.contains(key)) {
      state = {...state, key};
      _saveToPrefs();
    }
  }

  void unarchive(String nick) {
    final key = _normalize(nick);
    if (state.contains(key)) {
      final next = Set<String>.from(state)..remove(key);
      state = next;
      _saveToPrefs();
    }
  }

  void toggle(String nick) {
    final key = _normalize(nick);
    if (state.contains(key)) {
      unarchive(key);
    } else {
      archive(key);
    }
  }
}

/// Notifier para mensajes fijados por canal
class PinnedMessagesNotifier extends Notifier<Map<String, List<IRCMessage>>> {
  static const int maxPinnedPerChannel = 5;
  static const _prefsKey = 'pinned_messages_v1';

  @override
  Map<String, List<IRCMessage>> build() {
    _loadFromPrefs();
    return {};
  }

  String _normalize(String channel) => channel.toLowerCase();

  bool _isSameMessage(IRCMessage a, IRCMessage b) {
    return a.nick == b.nick &&
        a.channel.toLowerCase() == b.channel.toLowerCase() &&
        a.message == b.message &&
        a.timestamp == b.timestamp;
  }

  List<IRCMessage> pinnedForChannel(String channel) {
    return state[_normalize(channel)] ?? const [];
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final Map<String, List<IRCMessage>> restored = {};

      decoded.forEach((channelKey, list) {
        final items = (list as List<dynamic>).cast<Map<String, dynamic>>();
        restored[channelKey] = items.map((m) {
          return IRCMessage(
            nick: m['nick'] as String? ?? '',
            channel: m['channel'] as String? ?? channelKey,
            message: m['message'] as String? ?? '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (m['ts'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
            ),
            isSystem: m['isSystem'] as bool? ?? false,
          );
        }).toList();
      });

      state = restored;
    } catch (_) {
      // Si falla la carga, simplemente dejamos el estado vacío
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {};

      state.forEach((channelKey, messages) {
        data[channelKey] = messages.map((m) {
          return {
            'nick': m.nick,
            'channel': m.channel,
            'message': m.message,
            'ts': m.timestamp.millisecondsSinceEpoch,
            'isSystem': m.isSystem,
          };
        }).toList();
      });

      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (_) {
      // Ignorar fallos de guardado para no romper la app
    }
  }

  void togglePinned(IRCMessage message) {
    final key = _normalize(message.channel);
    final current = List<IRCMessage>.from(state[key] ?? const []);

    final existingIndex = current.indexWhere((m) => _isSameMessage(m, message));

    if (existingIndex != -1) {
      // Ya estaba fijado, lo quitamos
      current.removeAt(existingIndex);
    } else {
      // Añadir al principio
      current.insert(0, message);
      if (current.length > maxPinnedPerChannel) {
        current.removeRange(maxPinnedPerChannel, current.length);
      }
    }

    state = {...state, key: current};

    _saveToPrefs();
  }
}

enum NotificationLevel { allMessages, mentionsOnly, muted }

enum MentionSound { cuack, systemAlert, systemClick }

enum MessageTimestampPosition { afterNick, beforeNick, afterMessage }

enum ChannelAvatarPosition { left, right, hidden }

class NotificationSettings {
  final Map<String, NotificationLevel> channelLevels;
  final bool soundForPrivates;
  final bool soundForMentions;
  final bool soundForJoinPart;
  final bool soundForSend;
  final MentionSound sendSound;
  final Set<String> mutedUsers;
  final MentionSound mentionSound;
  final bool nickAutocomplete;
  final MessageTimestampPosition timestampPosition;
  final ChannelAvatarPosition channelAvatarPosition;
  final int? nickColor; // null = auto (hash-based palette)
  final int? timestampColor; // null = theme default

  /// No molestar: no mostrar notificaciones ni sonidos.
  final bool doNotDisturb;

  /// Mostrar mensajes de entrada/salida de usuarios (JOIN/PART/QUIT)
  final bool showJoinPartMessages;

  /// Mostrar avisos de cambio de nick
  final bool showNickChanges;

  /// Sonidos generales activados
  final bool soundsEnabled;

  /// Mostrar opción de pedidos musicales
  final bool musicRequests;

  /// Mostrar horóscopo
  final bool horoscope;

  /// Estilo visual del chat (preset IRC)
  final String chatStylePreset;

  /// Aura del nick (corazón, beso, tormenta, etc.)
  final String nickAura;

  /// Género del usuario (masculino/femenino)
  final String gender;

  /// Información del perfil
  final String biography;
  final String country;
  final int? age;
  final String maritalStatus;
  final int? birthdayDay;
  final int? birthdayMonth;
  final int? birthdayYear;
  final String presenceStatus;
  final bool privateMessagesOpen;
  final bool callsActive;
  final List<CustomAction> customActions;

  const NotificationSettings({
    this.channelLevels = const {},
    this.soundForPrivates = false,
    this.soundForMentions = false,
    this.soundForJoinPart = false,
    this.soundForSend = false,
    this.sendSound = MentionSound.systemClick,
    this.mutedUsers = const {},
    this.mentionSound = MentionSound.cuack,
    this.doNotDisturb = false,
    this.nickAutocomplete = true,
    this.timestampPosition = MessageTimestampPosition.beforeNick,
    this.channelAvatarPosition = ChannelAvatarPosition.left,
    this.nickColor,
    this.timestampColor,
    this.showJoinPartMessages = true,
    this.showNickChanges = true,
    this.soundsEnabled = true,
    this.musicRequests = true,
    this.horoscope = false,
    this.chatStylePreset = 'default',
    this.nickAura = 'none',
    this.gender = '',
    this.biography = '',
    this.country = '',
    this.age,
    this.maritalStatus = '',
    this.birthdayDay,
    this.birthdayMonth,
    this.birthdayYear,
    this.presenceStatus = 'online',
    this.privateMessagesOpen = true,
    this.callsActive = true,
    this.customActions = const [],
  });

  NotificationSettings copyWith({
    Map<String, NotificationLevel>? channelLevels,
    bool? soundForPrivates,
    bool? soundForMentions,
    bool? soundForJoinPart,
    bool? soundForSend,
    MentionSound? sendSound,
    Set<String>? mutedUsers,
    MentionSound? mentionSound,
    bool? doNotDisturb,
    bool? nickAutocomplete,
    MessageTimestampPosition? timestampPosition,
    ChannelAvatarPosition? channelAvatarPosition,
    int? nickColor,
    int? timestampColor,
    bool? showJoinPartMessages,
    bool? showNickChanges,
    bool? soundsEnabled,
    bool? musicRequests,
    bool? horoscope,
    String? chatStylePreset,
    String? nickAura,
    String? gender,
    String? biography,
    String? country,
    int? age,
    String? maritalStatus,
    int? birthdayDay,
    int? birthdayMonth,
    int? birthdayYear,
    String? presenceStatus,
    bool? privateMessagesOpen,
    bool? callsActive,
    List<CustomAction>? customActions,
  }) {
    return NotificationSettings(
      channelLevels: channelLevels ?? this.channelLevels,
      soundForPrivates: soundForPrivates ?? this.soundForPrivates,
      soundForMentions: soundForMentions ?? this.soundForMentions,
      soundForJoinPart: soundForJoinPart ?? this.soundForJoinPart,
      soundForSend: soundForSend ?? this.soundForSend,
      sendSound: sendSound ?? this.sendSound,
      mutedUsers: mutedUsers ?? this.mutedUsers,
      mentionSound: mentionSound ?? this.mentionSound,
      doNotDisturb: doNotDisturb ?? this.doNotDisturb,
      nickAutocomplete: nickAutocomplete ?? this.nickAutocomplete,
      timestampPosition: timestampPosition ?? this.timestampPosition,
      channelAvatarPosition: channelAvatarPosition ?? this.channelAvatarPosition,
      nickColor: nickColor ?? this.nickColor,
      timestampColor: timestampColor ?? this.timestampColor,
      showJoinPartMessages: showJoinPartMessages ?? this.showJoinPartMessages,
      showNickChanges: showNickChanges ?? this.showNickChanges,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
      musicRequests: musicRequests ?? this.musicRequests,
      horoscope: horoscope ?? this.horoscope,
      chatStylePreset: chatStylePreset ?? this.chatStylePreset,
      nickAura: nickAura ?? this.nickAura,
      gender: gender ?? this.gender,
      biography: biography ?? this.biography,
      country: country ?? this.country,
      age: age ?? this.age,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      birthdayDay: birthdayDay ?? this.birthdayDay,
      birthdayMonth: birthdayMonth ?? this.birthdayMonth,
      birthdayYear: birthdayYear ?? this.birthdayYear,
      presenceStatus: presenceStatus ?? this.presenceStatus,
      privateMessagesOpen: privateMessagesOpen ?? this.privateMessagesOpen,
      callsActive: callsActive ?? this.callsActive,
      customActions: customActions ?? this.customActions,
    );
  }

  NotificationLevel levelForChannel(String channel) {
    final key = channel.toLowerCase();
    return channelLevels[key] ?? NotificationLevel.mentionsOnly;
  }

  bool isUserMuted(String nick) {
    return mutedUsers.contains(nick.toLowerCase());
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  static const _prefsKeyLevels = 'notification_channel_levels_v1';
  static const _prefsKeyPrivates = 'notification_sound_privates';
  static const _prefsKeyMentions = 'notification_sound_mentions';
  static const _prefsKeyMutedUsers = 'notification_muted_users_v1';
  static const _prefsKeyMentionSound = 'notification_mention_sound_v1';
  static const _prefsKeyDoNotDisturb = 'notification_do_not_disturb_v1';
  static const _prefsKeySoundForSend = 'notification_sound_for_send_v1';
  static const _prefsKeySendSound = 'notification_send_sound_v1';
  static const _prefsKeySoundForJoinPart = 'notification_sound_join_part_v1';
  static const _prefsKeyNickAutocomplete = 'notification_nick_autocomplete_v1';
  static const _prefsKeyTimestampPosition = 'notification_timestamp_position_v1';
  static const _prefsKeyChannelAvatarPosition = 'notification_channel_avatar_position_v1';
  static const _prefsKeyNickColor = 'notification_nick_color_v1';
  static const _prefsKeyTimestampColor = 'notification_timestamp_color_v1';
  static const _prefsKeyShowJoinPart = 'notification_show_join_part_v1';
  static const _prefsKeyShowNickChanges = 'notification_show_nick_changes_v1';
  static const _prefsKeySoundsEnabled = 'notification_sounds_enabled_v1';
  static const _prefsKeyMusicRequests = 'notification_music_requests_v1';
  static const _prefsKeyHoroscope = 'notification_horoscope_v1';
  static const _prefsKeyChatStylePreset = 'notification_chat_style_preset_v1';
  static const _prefsKeyNickAura = 'notification_nick_aura_v1';
  static const _prefsKeyGender = 'notification_gender_v1';
  static const _prefsKeyBiography = 'notification_biography_v1';
  static const _prefsKeyCountry = 'notification_country_v1';
  static const _prefsKeyAge = 'notification_age_v1';
  static const _prefsKeyMaritalStatus = 'notification_marital_status_v1';
  static const _prefsKeyBirthdayDay = 'notification_birthday_day_v1';
  static const _prefsKeyBirthdayMonth = 'notification_birthday_month_v1';
  static const _prefsKeyBirthdayYear = 'notification_birthday_year_v1';
  static const _prefsKeyPresenceStatus = 'notification_presence_status_v1';
  static const _prefsKeyPrivateMessagesOpen = 'notification_private_messages_open_v1';
  static const _prefsKeyCallsActive = 'notification_calls_active_v1';
  static const _prefsKeyCustomActions = 'notification_custom_actions_v1';

  @override
  NotificationSettings build() {
    _loadFromPrefs();
    return const NotificationSettings();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawLevels = prefs.getString(_prefsKeyLevels);
      Map<String, NotificationLevel> levels = {};
      if (rawLevels != null && rawLevels.isNotEmpty) {
        final decoded = jsonDecode(rawLevels) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          switch (value as String?) {
            case 'mentions':
              levels[key] = NotificationLevel.mentionsOnly;
              break;
            case 'muted':
              levels[key] = NotificationLevel.muted;
              break;
            default:
              levels[key] = NotificationLevel.allMessages;
          }
        });
      }

      final privates = prefs.getBool(_prefsKeyPrivates) ?? false;
      final mentions = prefs.getBool(_prefsKeyMentions) ?? false;
      final mutedList = prefs.getStringList(_prefsKeyMutedUsers) ?? <String>[];
      final mentionSoundRaw = prefs.getString(_prefsKeyMentionSound) ?? 'cuack';
      final mentionSound = switch (mentionSoundRaw) {
        'alert' => MentionSound.systemAlert,
        'click' => MentionSound.systemClick,
        _ => MentionSound.cuack,
      };
      final doNotDisturb = prefs.getBool(_prefsKeyDoNotDisturb) ?? false;
      final soundForSend = prefs.getBool(_prefsKeySoundForSend) ?? false;
      final soundForJoinPart = prefs.getBool(_prefsKeySoundForJoinPart) ?? false;
      final nickAutocomplete = prefs.getBool(_prefsKeyNickAutocomplete) ?? true;
      final timestampPositionRaw = prefs.getString(_prefsKeyTimestampPosition) ?? 'beforeNick';
      final timestampPosition = switch (timestampPositionRaw) {
        'beforeNick' => MessageTimestampPosition.beforeNick,
        'afterMessage' => MessageTimestampPosition.afterMessage,
        _ => MessageTimestampPosition.afterNick,
      };
      final channelAvatarPositionRaw = prefs.getString(_prefsKeyChannelAvatarPosition) ?? 'left';
      final channelAvatarPosition = switch (channelAvatarPositionRaw) {
        'right' => ChannelAvatarPosition.right,
        'hidden' => ChannelAvatarPosition.hidden,
        _ => ChannelAvatarPosition.left,
      };
      final sendSoundRaw = prefs.getString(_prefsKeySendSound) ?? 'click';
      final sendSound = switch (sendSoundRaw) {
        'cuack' => MentionSound.cuack,
        'alert' => MentionSound.systemAlert,
        _ => MentionSound.systemClick,
      };
      final nickColor = prefs.getInt(_prefsKeyNickColor);
      final timestampColor = prefs.getInt(_prefsKeyTimestampColor);
      final showJoinPart = prefs.getBool(_prefsKeyShowJoinPart) ?? true;
      final showNickChanges = prefs.getBool(_prefsKeyShowNickChanges) ?? true;
      final soundsEnabled = prefs.getBool(_prefsKeySoundsEnabled) ?? true;
      final musicRequests = prefs.getBool(_prefsKeyMusicRequests) ?? true;
      final horoscope = prefs.getBool(_prefsKeyHoroscope) ?? false;
      final chatStylePreset = prefs.getString(_prefsKeyChatStylePreset) ?? 'default';
      final nickAura = prefs.getString(_prefsKeyNickAura) ?? 'none';
      final gender = prefs.getString(_prefsKeyGender) ?? '';
      final biography = prefs.getString(_prefsKeyBiography) ?? '';
      final country = prefs.getString(_prefsKeyCountry) ?? '';
      final age = prefs.getInt(_prefsKeyAge);
      final maritalStatus = prefs.getString(_prefsKeyMaritalStatus) ?? '';
      final birthdayDay = prefs.getInt(_prefsKeyBirthdayDay);
      final birthdayMonth = prefs.getInt(_prefsKeyBirthdayMonth);
      final birthdayYear = prefs.getInt(_prefsKeyBirthdayYear);
      final presenceStatus = prefs.getString(_prefsKeyPresenceStatus) ?? 'online';
      final privateMessagesOpen = prefs.getBool(_prefsKeyPrivateMessagesOpen) ?? true;
      final callsActive = prefs.getBool(_prefsKeyCallsActive) ?? true;
      final customActionsRaw = prefs.getString(_prefsKeyCustomActions);
      List<CustomAction> customActions = [];
      if (customActionsRaw != null && customActionsRaw.isNotEmpty) {
        final decoded = jsonDecode(customActionsRaw) as List<dynamic>;
        customActions = decoded
            .map((e) => CustomAction.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      state = state.copyWith(
        channelLevels: levels,
        soundForPrivates: privates,
        soundForMentions: mentions,
        soundForJoinPart: soundForJoinPart,
        soundForSend: soundForSend,
        sendSound: sendSound,
        mutedUsers: mutedList.map((e) => e.toLowerCase()).toSet(),
        mentionSound: mentionSound,
        doNotDisturb: doNotDisturb,
        nickAutocomplete: nickAutocomplete,
        timestampPosition: timestampPosition,
        channelAvatarPosition: channelAvatarPosition,
        nickColor: nickColor,
        timestampColor: timestampColor,
        showJoinPartMessages: showJoinPart,
        showNickChanges: showNickChanges,
        soundsEnabled: soundsEnabled,
        musicRequests: musicRequests,
        horoscope: horoscope,
        chatStylePreset: chatStylePreset,
        nickAura: nickAura,
        gender: state.gender.isNotEmpty ? state.gender : gender,
        biography: state.biography.isNotEmpty ? state.biography : biography,
        country: state.country.isNotEmpty ? state.country : country,
        age: age ?? state.age,
        maritalStatus: state.maritalStatus.isNotEmpty ? state.maritalStatus : maritalStatus,
        birthdayDay: birthdayDay ?? state.birthdayDay,
        birthdayMonth: birthdayMonth ?? state.birthdayMonth,
        birthdayYear: birthdayYear ?? state.birthdayYear,
        presenceStatus: presenceStatus,
        privateMessagesOpen: privateMessagesOpen,
        callsActive: callsActive,
        customActions: customActions,
      );
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> _saveLevels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, String> data = {};
      state.channelLevels.forEach((key, level) {
        switch (level) {
          case NotificationLevel.allMessages:
            data[key] = 'all';
            break;
          case NotificationLevel.mentionsOnly:
            data[key] = 'mentions';
            break;
          case NotificationLevel.muted:
            data[key] = 'muted';
            break;
        }
      });
      await prefs.setString(_prefsKeyLevels, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _saveFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyPrivates, state.soundForPrivates);
      await prefs.setBool(_prefsKeyMentions, state.soundForMentions);
      await prefs.setBool(_prefsKeyDoNotDisturb, state.doNotDisturb);
      await prefs.setStringList(_prefsKeyMutedUsers, state.mutedUsers.toList());
      String mentionValue = 'cuack';
      switch (state.mentionSound) {
        case MentionSound.systemAlert:
          mentionValue = 'alert';
          break;
        case MentionSound.systemClick:
          mentionValue = 'click';
          break;
        case MentionSound.cuack:
          mentionValue = 'cuack';
      }
      await prefs.setString(_prefsKeyMentionSound, mentionValue);
      await prefs.setBool(_prefsKeySoundForSend, state.soundForSend);
      await prefs.setBool(_prefsKeySoundForJoinPart, state.soundForJoinPart);
      await prefs.setBool(_prefsKeyNickAutocomplete, state.nickAutocomplete);
      String tsValue = 'afterNick';
      switch (state.timestampPosition) {
        case MessageTimestampPosition.beforeNick:
          tsValue = 'beforeNick';
          break;
        case MessageTimestampPosition.afterMessage:
          tsValue = 'afterMessage';
          break;
        case MessageTimestampPosition.afterNick:
          tsValue = 'afterNick';
      }
      await prefs.setString(_prefsKeyTimestampPosition, tsValue);
      String avatarValue = 'left';
      switch (state.channelAvatarPosition) {
        case ChannelAvatarPosition.right:
          avatarValue = 'right';
          break;
        case ChannelAvatarPosition.hidden:
          avatarValue = 'hidden';
          break;
        case ChannelAvatarPosition.left:
          avatarValue = 'left';
      }
      await prefs.setString(_prefsKeyChannelAvatarPosition, avatarValue);
      if (state.nickColor != null) {
        await prefs.setInt(_prefsKeyNickColor, state.nickColor!);
      } else {
        await prefs.remove(_prefsKeyNickColor);
      }
      if (state.timestampColor != null) {
        await prefs.setInt(_prefsKeyTimestampColor, state.timestampColor!);
      } else {
        await prefs.remove(_prefsKeyTimestampColor);
      }
      String sendValue = 'click';
      switch (state.sendSound) {
        case MentionSound.cuack:
          sendValue = 'cuack';
          break;
        case MentionSound.systemAlert:
          sendValue = 'alert';
          break;
        case MentionSound.systemClick:
          sendValue = 'click';
      }
      await prefs.setString(_prefsKeySendSound, sendValue);
      await prefs.setBool(_prefsKeyShowJoinPart, state.showJoinPartMessages);
      await prefs.setBool(_prefsKeyShowNickChanges, state.showNickChanges);
      await prefs.setBool(_prefsKeySoundsEnabled, state.soundsEnabled);
      await prefs.setBool(_prefsKeyMusicRequests, state.musicRequests);
      await prefs.setBool(_prefsKeyHoroscope, state.horoscope);
      await prefs.setString(_prefsKeyChatStylePreset, state.chatStylePreset);
      await prefs.setString(_prefsKeyNickAura, state.nickAura);
      await prefs.setString(_prefsKeyGender, state.gender);
      await prefs.setString(_prefsKeyBiography, state.biography);
      await prefs.setString(_prefsKeyCountry, state.country);
      if (state.age != null) {
        await prefs.setInt(_prefsKeyAge, state.age!);
      } else {
        await prefs.remove(_prefsKeyAge);
      }
      await prefs.setString(_prefsKeyMaritalStatus, state.maritalStatus);
      if (state.birthdayDay != null) {
        await prefs.setInt(_prefsKeyBirthdayDay, state.birthdayDay!);
      } else {
        await prefs.remove(_prefsKeyBirthdayDay);
      }
      if (state.birthdayMonth != null) {
        await prefs.setInt(_prefsKeyBirthdayMonth, state.birthdayMonth!);
      } else {
        await prefs.remove(_prefsKeyBirthdayMonth);
      }
      if (state.birthdayYear != null) {
        await prefs.setInt(_prefsKeyBirthdayYear, state.birthdayYear!);
      } else {
        await prefs.remove(_prefsKeyBirthdayYear);
      }
      await prefs.setString(_prefsKeyPresenceStatus, state.presenceStatus);
      await prefs.setBool(_prefsKeyPrivateMessagesOpen, state.privateMessagesOpen);
      await prefs.setBool(_prefsKeyCallsActive, state.callsActive);
      await prefs.setString(
          _prefsKeyCustomActions,
          jsonEncode(state.customActions.map((a) => a.toJson()).toList()));
    } catch (_) {}
  }

  void setChannelLevel(String channel, NotificationLevel level) {
    final key = channel.toLowerCase();
    final newLevels = Map<String, NotificationLevel>.from(state.channelLevels);
    newLevels[key] = level;
    state = state.copyWith(channelLevels: newLevels);
    _saveLevels();
  }

  void setDoNotDisturb(bool value) {
    state = state.copyWith(doNotDisturb: value);
    _saveFlags();
  }

  void toggleSoundForPrivates() {
    state = state.copyWith(soundForPrivates: !state.soundForPrivates);
    _saveFlags();
  }

  void toggleSoundForMentions() {
    state = state.copyWith(soundForMentions: !state.soundForMentions);
    _saveFlags();
  }

  void toggleMuteUser(String nick) {
    final key = nick.toLowerCase();
    final newMuted = Set<String>.from(state.mutedUsers);
    if (newMuted.contains(key)) {
      newMuted.remove(key);
    } else {
      newMuted.add(key);
    }
    state = state.copyWith(mutedUsers: newMuted);
    _saveFlags();
  }

  void setMentionSound(MentionSound sound) {
    state = state.copyWith(mentionSound: sound);
    _saveFlags();
  }

  void toggleSoundForSend() {
    state = state.copyWith(soundForSend: !state.soundForSend);
    _saveFlags();
  }

  void setSendSound(MentionSound sound) {
    state = state.copyWith(sendSound: sound);
    _saveFlags();
  }

  void toggleSoundForJoinPart() {
    state = state.copyWith(soundForJoinPart: !state.soundForJoinPart);
    _saveFlags();
  }

  void toggleNickAutocomplete() {
    state = state.copyWith(nickAutocomplete: !state.nickAutocomplete);
    _saveFlags();
  }

  void setTimestampPosition(MessageTimestampPosition position) {
    state = state.copyWith(timestampPosition: position);
    _saveFlags();
  }

  void setChannelAvatarPosition(ChannelAvatarPosition position) {
    state = state.copyWith(channelAvatarPosition: position);
    _saveFlags();
  }

  void setNickColor(int? color) {
    state = state.copyWith(nickColor: color);
    _saveFlags();
  }

  void setTimestampColor(int? color) {
    state = state.copyWith(timestampColor: color);
    _saveFlags();
  }

  void setGender(String gender) {
    state = state.copyWith(gender: gender);
    _saveFlags();
  }

  void addCustomAction(String emoji, String label) {
    final newActions = List<CustomAction>.from(state.customActions)
      ..add(CustomAction(emoji: emoji, label: label));
    state = state.copyWith(customActions: newActions);
    _saveFlags();
  }

  void removeCustomAction(int index) {
    final newActions = List<CustomAction>.from(state.customActions)
      ..removeAt(index);
    state = state.copyWith(customActions: newActions);
    _saveFlags();
  }
}

// Notifier para typing indicators
class TypingIndicatorNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};
  final Map<String, Timer> _timers = {};

  void setTyping(String channel, String? nick) {
    final normalizedChannel = channel.toLowerCase();

    // Cancelar timer anterior si existe
    _timers[normalizedChannel]?.cancel();

    state = {...state, normalizedChannel: nick};

    // Si hay un nick, programar que desaparezca después de 3 segundos
    if (nick != null) {
      _timers[normalizedChannel] = Timer(const Duration(seconds: 3), () {
        if (state[normalizedChannel] == nick) {
          state = {...state, normalizedChannel: null};
        }
      });
    }
  }

  void clearTyping(String channel) {
    final normalizedChannel = channel.toLowerCase();
    _timers[normalizedChannel]?.cancel();
    _timers.remove(normalizedChannel);
    state = {...state, normalizedChannel: null};
  }

  String? getTyping(String channel) {
    return state[channel.toLowerCase()];
  }

  void dispose() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    // Nota: En Riverpod 3.x, Notifier no tiene dispose()
  }
}

// Provider para typing indicators (quién está escribiendo en cada canal)
final typingIndicatorProvider =
    NotifierProvider<TypingIndicatorNotifier, Map<String, String?>>(() {
      return TypingIndicatorNotifier();
    });

// Notifier para refrescar avatares en tiempo real
class AvatarRefreshNotifier extends Notifier<Map<String, int>> {
  int _currentRefreshIndex = 0;
  bool _isRefreshing = false;

  // Intervalos del ciclo de refresco. Se mantienen amplios para que el refresco
  // sea poco intrusivo: cada recarga fuerza una descarga real de la imagen
  // (URL con ?t=timestamp), así que refrescar con frecuencia provoca parpadeos
  // y sensación de "movimiento" en la lista y el chat.
  static const Duration _initialDelay = Duration(seconds: 90);
  // Tiempo entre el refresco de un avatar y el siguiente dentro de una vuelta.
  static const Duration _perAvatarDelay = Duration(seconds: 20);
  // Pausa entre vueltas completas a todos los avatares.
  static const Duration _cyclePause = Duration(minutes: 5);

  @override
  Map<String, int> build() {
    _startRefreshCycle();
    return {};
  }

  void _startRefreshCycle({Duration? delay}) {
    Future.delayed(delay ?? _initialDelay, () {
      // Nota: Notifier no tiene 'mounted', usar ref.read para verificar si el provider está activo
      _refreshNextAvatar();
    });
  }

  void _refreshNextAvatar() {
    if (_isRefreshing) return;

    final entries = state.entries.toList();
    if (entries.isEmpty) {
      _currentRefreshIndex = 0;
      _startRefreshCycle();
      return;
    }

    // Actualizar solo un avatar a la vez
    if (_currentRefreshIndex < entries.length) {
      _isRefreshing = true;
      final entry = entries[_currentRefreshIndex];
      state = {...state, entry.key: DateTime.now().millisecondsSinceEpoch};
      _currentRefreshIndex++;
      _isRefreshing = false;

      // Esperar antes de actualizar el siguiente avatar (refresco espaciado)
      Future.delayed(_perAvatarDelay, () {
        // Nota: Notifier no tiene 'mounted'
        {
          _refreshNextAvatar();
        }
      });
    } else {
      // Reiniciar el ciclo tras una pausa larga cuando se hayan actualizado todos
      _currentRefreshIndex = 0;
      _startRefreshCycle(delay: _cyclePause);
    }
  }

  void refreshAvatar(String nick) {
    final normalizedNick = nick.toLowerCase();
    state = {...state, normalizedNick: DateTime.now().millisecondsSinceEpoch};
  }

  void refreshAllAvatars() {
    final newState = <String, int>{};
    for (var entry in state.entries) {
      newState[entry.key] = DateTime.now().millisecondsSinceEpoch;
    }
    state = newState;
  }

  int? getRefreshTimestamp(String nick) {
    return state[nick.toLowerCase()];
  }
}

// Provider para invalidar/refrescar avatares
final avatarRefreshProvider =
    NotifierProvider<AvatarRefreshNotifier, Map<String, int>>(() {
      return AvatarRefreshNotifier();
    });

class EmojiConfigNotifier extends Notifier<EmojiConfig> {
  @override
  EmojiConfig build() => EmojiConfig.defaultConfig;

  void updateConfig(EmojiConfig config) {
    state = config;
  }

  void updateOwnerEmoji(String emoji) {
    state = state.copyWith(ownerEmoji: emoji);
  }

  void updateOperatorEmoji(String emoji) {
    state = state.copyWith(operatorEmoji: emoji);
  }

  void updateHalfopEmoji(String emoji) {
    state = state.copyWith(halfopEmoji: emoji);
  }

  void updateVoiceEmoji(String emoji) {
    state = state.copyWith(voiceEmoji: emoji);
  }

  void updateUserEmoji(String emoji) {
    state = state.copyWith(userEmoji: emoji);
  }

  void updateRobotEmoji(String emoji) {
    state = state.copyWith(robotEmoji: emoji);
  }
}

/// Notifier para gestionar perfiles de servidor (multi-servidor / multi-red)
class ServerProfilesNotifier extends Notifier<List<ServerProfile>> {
  @override
  List<ServerProfile> build() =>
      List<ServerProfile>.from(ServerProfile.activeProfiles);

  void addProfile(ServerProfile profile) {
    state = [...state, profile];
  }

  void removeProfile(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updateProfile(ServerProfile profile) {
    state = state
        .map((p) => p.id == profile.id ? profile : p)
        .toList(growable: false);
  }
}

/// Preferencias de formato de mensaje (burbuja vs texto plano)
/// Formatos de presentación de mensajes:
/// - bubble: burbujas de chat (estilo apps modernas)
/// - plain: texto plano con tarjeta/caja por mensaje
/// - compact: texto corrido sin cajas, estilo IRC clásico (mIRC/IRCap)
enum MessageFormat { bubble, plain, compact }

/// Convierte un MessageFormat a string para persistencia.
String messageFormatToString(MessageFormat f) {
  switch (f) {
    case MessageFormat.bubble:
      return 'bubble';
    case MessageFormat.plain:
      return 'plain';
    case MessageFormat.compact:
      return 'compact';
  }
}

/// Convierte un string persistido a MessageFormat (con valor por defecto).
MessageFormat messageFormatFromString(String? value, MessageFormat fallback) {
  switch (value) {
    case 'bubble':
      return MessageFormat.bubble;
    case 'plain':
      return MessageFormat.plain;
    case 'compact':
      return MessageFormat.compact;
    default:
      return fallback;
  }
}

class MessageFormatPreferences {
  final MessageFormat channelFormat;
  final MessageFormat privateFormat;
  final bool showTimestamp;
  final bool showInlineChannelAvatar;
  final double channelFontSize;
  final double privateFontSize;
  final String channelFontFamily;
  final String privateFontFamily;
  final double emojiSize;

  /// Factor global para escalar el tamaño de los avatares (1.0 = tamaño base).
  final double avatarScale;
  final bool enableThreadsInChannels;
  final bool enableReactions;

  /// Controla si se permiten avatares animados (GIFs) en la interfaz.
  final bool enableAnimatedAvatars;

  /// Si está activado, hacer doble tap en un usuario de la lista abre un MP.
  final bool doubleTapOpensPrivateMessage;

  const MessageFormatPreferences({
    this.channelFormat = MessageFormat.compact,
    this.privateFormat = MessageFormat.compact,
    this.showTimestamp = true,
    this.showInlineChannelAvatar = false,
    this.channelFontSize = 15.0,
    this.privateFontSize = 15.0,
    this.channelFontFamily = 'Roboto',
    this.privateFontFamily = 'Roboto',
    this.emojiSize = 40.0,
    this.avatarScale = 1.0,
    this.enableThreadsInChannels = false,
    this.enableReactions = false,
    this.enableAnimatedAvatars = true,
    this.doubleTapOpensPrivateMessage = true,
  });

  MessageFormatPreferences copyWith({
    MessageFormat? channelFormat,
    MessageFormat? privateFormat,
    bool? showTimestamp,
    bool? showInlineChannelAvatar,
    double? channelFontSize,
    double? privateFontSize,
    String? channelFontFamily,
    String? privateFontFamily,
    double? emojiSize,
    double? avatarScale,
    bool? enableThreadsInChannels,
    bool? enableReactions,
    bool? enableAnimatedAvatars,
    bool? doubleTapOpensPrivateMessage,
  }) {
    return MessageFormatPreferences(
      channelFormat: channelFormat ?? this.channelFormat,
      privateFormat: privateFormat ?? this.privateFormat,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      showInlineChannelAvatar:
          showInlineChannelAvatar ?? this.showInlineChannelAvatar,
      channelFontSize: channelFontSize ?? this.channelFontSize,
      privateFontSize: privateFontSize ?? this.privateFontSize,
      channelFontFamily: channelFontFamily ?? this.channelFontFamily,
      privateFontFamily: privateFontFamily ?? this.privateFontFamily,
      emojiSize: emojiSize ?? this.emojiSize,
      avatarScale: avatarScale ?? this.avatarScale,
      enableThreadsInChannels:
          enableThreadsInChannels ?? this.enableThreadsInChannels,
      enableReactions: enableReactions ?? this.enableReactions,
      enableAnimatedAvatars:
          enableAnimatedAvatars ?? this.enableAnimatedAvatars,
      doubleTapOpensPrivateMessage:
          doubleTapOpensPrivateMessage ?? this.doubleTapOpensPrivateMessage,
    );
  }
}

final messageFormatPreferencesProvider =
    NotifierProvider<
      MessageFormatPreferencesNotifier,
      MessageFormatPreferences
    >(() {
      return MessageFormatPreferencesNotifier();
    });

class MessageFormatPreferencesNotifier
    extends Notifier<MessageFormatPreferences> {
  static const _prefsKeyChannel = 'message_format_channel';
  static const _prefsKeyPrivate = 'message_format_private';
  static const _prefsKeyShowTimestamp = 'message_show_timestamp';
  static const _prefsKeyShowInlineChannelAvatar =
      'message_show_inline_channel_avatar';
  static const _prefsKeyChannelFontSize = 'message_channel_font_size';
  static const _prefsKeyPrivateFontSize = 'message_private_font_size';
  static const _prefsKeyChannelFontFamily = 'message_channel_font_family';
  static const _prefsKeyPrivateFontFamily = 'message_private_font_family';
  static const _prefsKeyEmojiSize = 'message_emoji_size';
  static const _prefsKeyAvatarScale = 'avatar_scale';
  static const _prefsKeyEnableThreadsInChannels = 'enable_threads_in_channels';
  static const _prefsKeyEnableReactions = 'enable_reactions';
  static const _prefsKeyEnableAnimatedAvatars = 'enable_animated_avatars';
  static const _prefsKeyDoubleTapOpensPrivateMessage = 'double_tap_opens_private_message';

  @override
  MessageFormatPreferences build() {
    _loadFromPrefs();
    return const MessageFormatPreferences();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelRaw = prefs.getString(_prefsKeyChannel);
      final privateRaw = prefs.getString(_prefsKeyPrivate);
      final showTimestamp = prefs.getBool(_prefsKeyShowTimestamp) ?? true;
      final showInlineChannelAvatar =
          prefs.getBool(_prefsKeyShowInlineChannelAvatar) ?? false;
      final channelFontSize = prefs.getDouble(_prefsKeyChannelFontSize) ?? 15.0;
      final privateFontSize = prefs.getDouble(_prefsKeyPrivateFontSize) ?? 15.0;
      final channelFontFamily =
          prefs.getString(_prefsKeyChannelFontFamily) ?? 'Roboto';
      final privateFontFamily =
          prefs.getString(_prefsKeyPrivateFontFamily) ?? 'Roboto';
      final emojiSize = prefs.getDouble(_prefsKeyEmojiSize) ?? 40.0;
      final avatarScale = prefs.getDouble(_prefsKeyAvatarScale) ?? 1.0;
      final enableThreadsInChannels =
          prefs.getBool(_prefsKeyEnableThreadsInChannels) ?? false;
      final enableReactions = prefs.getBool(_prefsKeyEnableReactions) ?? false;
      final enableAnimatedAvatars =
          prefs.getBool(_prefsKeyEnableAnimatedAvatars) ?? true;
      final doubleTapOpensPrivateMessage =
          prefs.getBool(_prefsKeyDoubleTapOpensPrivateMessage) ?? true;

      // Por defecto: canal = compacto (estilo IRC), privado = texto plano.
      final channelFormat = messageFormatFromString(
        channelRaw,
        MessageFormat.compact,
      );
      final privateFormat = messageFormatFromString(
        privateRaw,
        MessageFormat.compact,
      );

      state = MessageFormatPreferences(
        channelFormat: channelFormat,
        privateFormat: privateFormat,
        showTimestamp: showTimestamp,
        showInlineChannelAvatar: showInlineChannelAvatar,
        channelFontSize: channelFontSize,
        privateFontSize: privateFontSize,
        channelFontFamily: channelFontFamily,
        privateFontFamily: privateFontFamily,
        emojiSize: emojiSize,
        avatarScale: avatarScale,
        enableThreadsInChannels: enableThreadsInChannels,
        enableReactions: enableReactions,
        enableAnimatedAvatars: enableAnimatedAvatars,
        doubleTapOpensPrivateMessage: doubleTapOpensPrivateMessage,
      );
    } catch (_) {
      // Ignorar errores de carga
    }
  }

  Future<void> setChannelFormat(MessageFormat format) async {
    state = state.copyWith(channelFormat: format);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyChannel,
        messageFormatToString(format),
      );
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setPrivateFormat(MessageFormat format) async {
    state = state.copyWith(privateFormat: format);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyPrivate,
        messageFormatToString(format),
      );
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setShowTimestamp(bool show) async {
    state = state.copyWith(showTimestamp: show);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyShowTimestamp, show);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setShowInlineChannelAvatar(bool show) async {
    state = state.copyWith(showInlineChannelAvatar: show);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyShowInlineChannelAvatar, show);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setChannelFontSize(double size) async {
    if (size < 10.0) size = 10.0;
    if (size > 30.0) size = 30.0;
    state = state.copyWith(channelFontSize: size);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyChannelFontSize, size);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setPrivateFontSize(double size) async {
    if (size < 10.0) size = 10.0;
    if (size > 30.0) size = 30.0;
    state = state.copyWith(privateFontSize: size);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyPrivateFontSize, size);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setEmojiSize(double size) async {
    if (size < 16.0) size = 16.0;
    if (size > 80.0) size = 80.0;
    state = state.copyWith(emojiSize: size);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyEmojiSize, size);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setAvatarScale(double scale) async {
    if (scale < 0.6) scale = 0.6;
    if (scale > 1.6) scale = 1.6;
    state = state.copyWith(avatarScale: scale);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKeyAvatarScale, scale);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setChannelFontFamily(String family) async {
    state = state.copyWith(channelFontFamily: family);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyChannelFontFamily, family);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setPrivateFontFamily(String family) async {
    state = state.copyWith(privateFontFamily: family);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyPrivateFontFamily, family);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setEnableThreadsInChannels(bool enable) async {
    state = state.copyWith(enableThreadsInChannels: enable);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyEnableThreadsInChannels, enable);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setEnableReactions(bool enable) async {
    state = state.copyWith(enableReactions: enable);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyEnableReactions, enable);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setEnableAnimatedAvatars(bool enable) async {
    state = state.copyWith(enableAnimatedAvatars: enable);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyEnableAnimatedAvatars, enable);
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setDoubleTapOpensPrivateMessage(bool enable) async {
    state = state.copyWith(doubleTapOpensPrivateMessage: enable);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        _prefsKeyDoubleTapOpensPrivateMessage,
        enable,
      );
    } catch (_) {
      // Ignorar errores de guardado
    }
  }
}

/// Provider para iconos personalizados de usuarios
/// Mapea nick -> icono (emoji o inicial)
final userIconsProvider =
    NotifierProvider<UserIconsNotifier, Map<String, String>>(() {
      return UserIconsNotifier();
    });

class UserIconsNotifier extends Notifier<Map<String, String>> {
  static const _prefsKey = 'user_custom_icons';

  @override
  Map<String, String> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iconsJson = prefs.getString(_prefsKey);
      if (iconsJson != null) {
        final Map<String, dynamic> decoded = json.decode(iconsJson);
        state = Map<String, String>.from(decoded);
      }
    } catch (e) {
      // debugLog('Error cargando iconos personalizados: $e');
    }
  }

  Future<void> setIcon(String nick, String icon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newState = Map<String, String>.from(state);
      newState[nick.toLowerCase()] = icon;
      state = newState;

      final iconsJson = json.encode(newState);
      await prefs.setString(_prefsKey, iconsJson);
    } catch (e) {
      // debugLog('Error guardando icono personalizado: $e');
    }
  }

  Future<void> removeIcon(String nick) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newState = Map<String, String>.from(state);
      newState.remove(nick.toLowerCase());
      state = newState;

      final iconsJson = json.encode(newState);
      await prefs.setString(_prefsKey, iconsJson);
    } catch (e) {
      // debugLog('Error eliminando icono personalizado: $e');
    }
  }

  String? getIcon(String nick) {
    return state[nick.toLowerCase()];
  }
}

/// Avatar GIF global (subido en Ajustes). Guarda path en disco o data URL en web.
final globalAvatarGifProvider =
    NotifierProvider<GlobalAvatarGifNotifier, String?>(() {
      return GlobalAvatarGifNotifier();
    });

class GlobalAvatarGifNotifier extends Notifier<String?> {
  static const _prefsKey = 'global_avatar_gif';

  @override
  String? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null && stored.isNotEmpty) {
        state = stored;
      }
    } catch (_) {}
  }

  Future<void> setGlobalAvatarGif(String? value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value != null && value.isNotEmpty) {
        await prefs.setString(_prefsKey, value);
      } else {
        await prefs.remove(_prefsKey);
      }
    } catch (_) {}
  }

  Future<void> clear() async => setGlobalAvatarGif(null);

  /// Sube el GIF guardado al servidor (xmlrpc) para que otros usuarios lo vean.
  /// Se llama automáticamente al conectar y al cambiar nick; no requiere que el usuario haga nada.
  void syncGifToServer(String? nick) {
    if (nick == null || nick.trim().isEmpty) return;
    final dataUrl = state;
    if (dataUrl == null || dataUrl.isEmpty) return;
    if (!dataUrl.startsWith('data:image/gif;base64,')) return;
    try {
      final base64Data = dataUrl.contains(',')
          ? dataUrl.substring(dataUrl.indexOf(',') + 1)
          : dataUrl;
      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) return;
      AvatarService.uploadAvatarGif(nick.trim(), bytes)
          .then((result) {
            if (result.success &&
                result.url != null &&
                result.url!.isNotEmpty) {
              // Sustituir la data URL local por la URL remota en el servidor
              if (!PlatformUtils.isWeb) {
                setGlobalAvatarGif(result.url);
              }
            } else if (!result.success) {
              // Para revisar si la subida falla: abre la consola del navegador (F12) y busca este mensaje
              debugLog(
                '🖼️ [AVATAR] Subida automática GIF falló: ${result.errorMessage}',
              );
            }
          })
          .catchError((error) {
            debugLog('🖼️ [AVATAR] Excepción en subida automática GIF: $error');
          });
    } catch (_) {}
  }
}

/// Provider para robots personalizados
/// Permite añadir robots manualmente y asignarles iconos personalizados
final customRobotsProvider =
    NotifierProvider<CustomRobotsNotifier, List<CustomRobot>>(() {
      return CustomRobotsNotifier();
    });

class CustomRobotsNotifier extends Notifier<List<CustomRobot>> {
  static const _prefsKey = 'custom_robots';

  @override
  List<CustomRobot> build() {
    _loadFromPrefs();
    return [];
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final robotsJson = prefs.getString(_prefsKey);

      // Lista de robots por defecto
      final defaultRobots = [
        CustomRobot(nick: 'GlobalChat', icon: '🤖', host: 'GlobalChat.Org'),
        CustomRobot(nick: 'orion', icon: '🤖'),
        CustomRobot(nick: 'SeenAllBot', icon: '🤖'),
        CustomRobot(nick: 'Stats', icon: '🤖'),
        CustomRobot(nick: 'YoutubeBot', icon: '🤖'),
        CustomRobot(nick: 'Chan', icon: '🤖'),
        CustomRobot(nick: 'Nick', icon: '🤖'),
        CustomRobot(nick: 'Memo', icon: '🤖'),
        CustomRobot(nick: 'Ircop', icon: '🤖'),
        CustomRobot(nick: 'Global', icon: '🤖'),
        CustomRobot(nick: 'ipvirtual', icon: '🤖'),
        CustomRobot(nick: 'botita', icon: '🤖'), // Robot oficial de #QualiaRadio
        CustomRobot(nick: 'Z', icon: '🤖'),
        CustomRobot(nick: 'Futbol', icon: '🤖'),
      ];

      if (robotsJson != null) {
        final List<dynamic> decoded = json.decode(robotsJson);
        final loadedRobots = decoded
            .map((json) => CustomRobot.fromJson(json as Map<String, dynamic>))
            .toList();

        // Añadir robots por defecto que no estén ya en la lista
        bool needsSave = false;
        for (var defaultRobot in defaultRobots) {
          final exists = loadedRobots.any(
            (r) => r.nick.toLowerCase() == defaultRobot.nick.toLowerCase(),
          );
          if (!exists) {
            loadedRobots.add(defaultRobot);
            needsSave = true;
          }
        }

        state = loadedRobots;
        if (needsSave) {
          await _saveToPrefs(); // Guardar con los robots por defecto incluidos
        }
      } else {
        // Inicializar con robots por defecto
        state = defaultRobots;
        await _saveToPrefs(); // Guardar la lista inicial
      }
    } catch (e) {
      debugLog('Error cargando robots personalizados: $e');
      // En caso de error, usar lista por defecto
      state = [
        CustomRobot(nick: 'GlobalChat', icon: '🤖', host: 'GlobalChat.Org'),
        CustomRobot(nick: 'orion', icon: '🤖'),
        CustomRobot(nick: 'SeenAllBot', icon: '🤖'),
        CustomRobot(nick: 'Stats', icon: '🤖'),
        CustomRobot(nick: 'YoutubeBot', icon: '🤖'),
        CustomRobot(nick: 'Chan', icon: '🤖'),
        CustomRobot(nick: 'Nick', icon: '🤖'),
        CustomRobot(nick: 'Memo', icon: '🤖'),
        CustomRobot(nick: 'Ircop', icon: '🤖'),
        CustomRobot(nick: 'Global', icon: '🤖'),
        CustomRobot(nick: 'ipvirtual', icon: '🤖'),
        CustomRobot(nick: 'botita', icon: '🤖'), // Robot oficial de #QualiaRadio
        CustomRobot(nick: 'Z', icon: '🤖'),
        CustomRobot(nick: 'Futbol', icon: '🤖'),
      ];
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final robotsJson = json.encode(state.map((r) => r.toJson()).toList());
      await prefs.setString(_prefsKey, robotsJson);
    } catch (e) {
      debugLog('Error guardando robots personalizados: $e');
    }
  }

  Future<void> addRobot(CustomRobot robot) async {
    // Verificar que no exista ya
    final existingIndex = state.indexWhere(
      (r) => r.nick.toLowerCase() == robot.nick.toLowerCase(),
    );
    if (existingIndex != -1) {
      // Actualizar el existente
      final newState = List<CustomRobot>.from(state);
      newState[existingIndex] = robot;
      state = newState;
    } else {
      // Añadir nuevo
      state = [...state, robot];
    }
    await _saveToPrefs();
  }

  Future<void> removeRobot(String nick) async {
    state = state
        .where((r) => r.nick.toLowerCase() != nick.toLowerCase())
        .toList();
    await _saveToPrefs();
  }

  Future<void> updateRobot(String nick, CustomRobot updatedRobot) async {
    final index = state.indexWhere(
      (r) => r.nick.toLowerCase() == nick.toLowerCase(),
    );
    if (index != -1) {
      final newState = List<CustomRobot>.from(state);
      newState[index] = updatedRobot;
      state = newState;
      await _saveToPrefs();
    }
  }

  CustomRobot? getRobot(String nick) {
    try {
      return state.firstWhere(
        (r) => r.nick.toLowerCase() == nick.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  bool isCustomRobot(String nick, {String? host}) {
    // Verificar por nick
    final robot = getRobot(nick);
    if (robot != null) {
      // Si tiene host especificado, verificar que coincida
      if (robot.host != null && host != null) {
        return host.toLowerCase().contains(robot.host!.toLowerCase());
      }
      // Si no tiene host, cualquier host es válido
      return true;
    }

    // Verificar por host si no se encontró por nick
    if (host != null) {
      return state.any(
        (r) =>
            r.host != null &&
            host.toLowerCase().contains(r.host!.toLowerCase()),
      );
    }

    return false;
  }

  /// Agregar múltiples robots a la vez
  /// Útil para inicializar con una lista de bots conocidos
  Future<void> addRobots(List<CustomRobot> robots) async {
    final newState = List<CustomRobot>.from(state);

    for (var robot in robots) {
      final existingIndex = newState.indexWhere(
        (r) => r.nick.toLowerCase() == robot.nick.toLowerCase(),
      );
      if (existingIndex != -1) {
        // Actualizar el existente
        newState[existingIndex] = robot;
      } else {
        // Añadir nuevo
        newState.add(robot);
      }
    }

    state = newState;
    await _saveToPrefs();
  }
}

// --- Traductor automático (estilo AutoTraductor IRC) ---

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService();
});

const _translationChannelsPrefsKey = 'translation_enabled_channels';

/// Canales donde la traducción automática está activada (mensajes → español).
final translationEnabledChannelsProvider =
    NotifierProvider<TranslationEnabledChannelsNotifier, Set<String>>(() {
      return TranslationEnabledChannelsNotifier();
    });

class TranslationEnabledChannelsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_translationChannelsPrefsKey);
      if (list != null) state = list.toSet();
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_translationChannelsPrefsKey, state.toList());
    } catch (_) {}
  }

  void toggle(String channel) {
    final key = channel.toLowerCase();
    final next = Set<String>.from(state);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    state = next;
    _saveToPrefs();
  }

  void setEnabled(String channel, bool enabled) {
    final key = channel.toLowerCase();
    final next = Set<String>.from(state);
    if (enabled) {
      next.add(key);
    } else {
      next.remove(key);
    }
    state = next;
    _saveToPrefs();
  }

  bool isEnabled(String channel) => state.contains(channel.toLowerCase());
}

/// Caché de traducciones (texto original → traducido) para refrescar UI.
final translationCacheProvider =
    NotifierProvider<TranslationCacheNotifier, Map<String, String>>(() {
      return TranslationCacheNotifier();
    });

class TranslationCacheNotifier extends Notifier<Map<String, String>> {
  final Set<String> _pending = {};

  @override
  Map<String, String> build() => {};

  Future<String?> getOrTranslate(
    String text,
    TranslationService service,
  ) async {
    final clean = text.trim();
    if (clean.length < TranslationService.minChars) return null;
    if (state.containsKey(clean)) return state[clean];
    if (_pending.contains(clean)) return null;
    _pending.add(clean);
    try {
      final translated = await service.translateToSpanish(clean);
      if (translated != null) {
        state = Map<String, String>.from(state)..[clean] = translated;
        return translated;
      }
    } finally {
      _pending.remove(clean);
    }
    return null;
  }

  void clearCache() {
    ref.read(translationServiceProvider).clearCache();
    state = {};
  }
}

/// Ignorar todos los mensajes privados (toggle global).
final ignoreAllPrivatesProvider =
    NotifierProvider<IgnoreAllPrivatesNotifier, bool>(() {
      return IgnoreAllPrivatesNotifier();
    });

class IgnoreAllPrivatesNotifier extends Notifier<bool> {
  static const _prefsKey = 'ignore_all_privates';

  @override
  bool build() {
    _init();
    return false;
  }

  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {}
  }

  void toggle() {
    state = !state;
    _saveToPrefs();
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, state);
    } catch (_) {}
  }
}
