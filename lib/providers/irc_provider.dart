import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/irc_message.dart';
import '../models/whois_info.dart';
import '../models/emoji_config.dart';
import '../models/server_profile.dart';
import '../services/irc_service.dart';

final ircServiceProvider = Provider((ref) {
  return IRCService();
});

final messagesProvider = StateNotifierProvider<MessagesNotifier, List<IRCMessage>>((ref) {
  final service = ref.watch(ircServiceProvider);
  return MessagesNotifier(service);
});

final channelsProvider = StateNotifierProvider<ChannelsNotifier, Map<String, IRCChannel>>((ref) {
  final service = ref.watch(ircServiceProvider);
  return ChannelsNotifier(service);
});

final connectionStatusProvider = StateNotifierProvider<ConnectionStatusNotifier, bool>((ref) {
  final service = ref.watch(ircServiceProvider);
  return ConnectionStatusNotifier(service);
});

/// Lag (latencia) con el servidor IRC en milisegundos
final lagProvider = StateNotifierProvider<LagNotifier, int?>((ref) {
  return LagNotifier();
});

class LagNotifier extends StateNotifier<int?> {
  LagNotifier() : super(null);

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

final currentNicknameProvider = StateProvider<String?>((ref) {
  return null;
});

/// Delay en segundos antes de enviar mensajes al servidor (configurable)
final messageSendDelayProvider = StateNotifierProvider<MessageSendDelayNotifier, int>((ref) {
  return MessageSendDelayNotifier();
});

class MessageSendDelayNotifier extends StateNotifier<int> {
  static const _prefsKey = 'message_send_delay_seconds';
  static const int _defaultDelay = 10; // 10 segundos por defecto

  MessageSendDelayNotifier() : super(_defaultDelay) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final delay = prefs.getInt(_prefsKey) ?? _defaultDelay;
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

final currentChannelProvider = StateProvider<String?>((ref) {
  return null;
});

/// Último canal utilizado, para recordar la selección al volver al login
final lastChannelProvider = StateProvider<String?>((ref) {
  return null;
});

/// Canales/nicks marcados como favoritos (para autounirse y sección destacada)
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

/// Lista de canales/nicks recientes (histórico ligero de uso)
final recentChannelsProvider =
    StateNotifierProvider<RecentChannelsNotifier, List<String>>((ref) {
  return RecentChannelsNotifier();
});

/// Mensajes fijados por canal (avisos, reglas, enlaces importantes)
final pinnedMessagesProvider = StateNotifierProvider<PinnedMessagesNotifier,
    Map<String, List<IRCMessage>>>((ref) {
  return PinnedMessagesNotifier();
});

/// Reglas de notificación por canal y tipo de sonido
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        (ref) {
  return NotificationSettingsNotifier();
});

/// Perfil de servidor actual (para multi-servidor/multi-red)
final currentServerProfileProvider = StateProvider<ServerProfile?>((ref) {
  // Por defecto, usar el primer perfil de GlobalChat (Ceres 6667)
  return ServerProfile.defaultGlobalChatProfiles.firstWhere(
    (p) => p.isDefault,
    orElse: () => ServerProfile.defaultGlobalChatProfiles.first,
  );
});

/// Lista de perfiles de servidor disponibles (inicialmente los de GlobalChat)
final serverProfilesProvider =
    StateNotifierProvider<ServerProfilesNotifier, List<ServerProfile>>((ref) {
  return ServerProfilesNotifier();
});

final whoisProvider = StateNotifierProvider<WhoisNotifier, Map<String, WhoisInfo>>((ref) {
  final service = ref.watch(ircServiceProvider);
  return WhoisNotifier(service);
});

final emojiConfigProvider = StateNotifierProvider<EmojiConfigNotifier, EmojiConfig>((ref) {
  return EmojiConfigNotifier();
});

// Provider para mensajes no leídos por canal
final unreadMessagesProvider = StateNotifierProvider<UnreadMessagesNotifier, Map<String, int>>((ref) {
  return UnreadMessagesNotifier();
});

class MessagesNotifier extends StateNotifier<List<IRCMessage>> {
  final IRCService _service;

  MessagesNotifier(this._service) : super([]) {
    _service.addMessageListener(_onMessage);
  }

  void _onMessage(IRCMessage message) {
    // Si el mensaje tiene un pendingId, buscar si ya existe un mensaje pendiente con ese ID
    if (message.pendingId != null) {
      final index = state.indexWhere((m) => m.pendingId == message.pendingId);
      if (index != -1) {
        // Actualizar el mensaje existente en lugar de añadir uno nuevo
        final updatedState = List<IRCMessage>.from(state);
        updatedState[index] = message;
        state = updatedState;
        return;
      }
    }
    
    // Si el mensaje no tiene pendingId o no se encontró uno existente, verificar si es una actualización
    // de un mensaje pendiente (isPending cambió de true a false)
    if (!message.isPending) {
      // Buscar mensaje con mismo contenido, canal y nick que sea pendiente
      final index = state.indexWhere((m) => 
        m.isPending && 
        m.channel.toLowerCase() == message.channel.toLowerCase() &&
        m.nick == message.nick &&
        m.message.trim() == message.message.trim() &&
        // Timestamp similar (dentro de 5 segundos)
        (m.timestamp.difference(message.timestamp).inSeconds.abs() < 5)
      );
      if (index != -1) {
        // Actualizar el mensaje existente
        final updatedState = List<IRCMessage>.from(state);
        updatedState[index] = message;
        state = updatedState;
        return;
      }
    }
    
    // Si no es una actualización, añadir como nuevo mensaje
    state = [...state, message];
  }

  void clearMessages() {
    state = [];
  }

  @override
  void dispose() {
    _service.removeMessageListener(_onMessage);
    super.dispose();
  }
}

class ChannelsNotifier extends StateNotifier<Map<String, IRCChannel>> {
  final IRCService _service;

  ChannelsNotifier(this._service) : super({}) {
    // Initialize with current channels
    state = {..._service.channels};
    // Listen for user list updates
    _service.addUserListListener(_onUserListUpdate);
  }

  void _onUserListUpdate(String channel) {
    print('🔍 [DEBUG] 🔄 ChannelsNotifier._onUserListUpdate: channel=$channel');
    print('🔍 [DEBUG] 📊 Service channels: ${_service.channels.keys.toList()}');
    print('🔍 [DEBUG] 📊 Current state channels: ${state.keys.toList()}');
    
    // Always update the entire state with current service state
    final newState = <String, IRCChannel>{};
    for (var entry in _service.channels.entries) {
      // Crear una copia profunda del canal con sus usuarios, topic, hosts y modos
      final channelCopy = IRCChannel(
        name: entry.value.name,
        messages: List.from(entry.value.messages),
        users: List.from(entry.value.users),
        userHosts: Map<String, String>.from(entry.value.userHosts), // Copiar el mapa de hosts
        userModes: Map<String, String>.from(entry.value.userModes), // Copiar el mapa de modos
        topic: entry.value.topic, // Incluir el topic en la copia
      );
      newState[entry.key] = channelCopy;
      print('🔍 [DEBUG] Copied channel ${entry.key} with ${channelCopy.users.length} users: ${channelCopy.users}, topic: ${channelCopy.topic}');
    }
    
    if (newState.containsKey(channel)) {
      print('🔍 [DEBUG] 👥 Channel found in new state, users: ${newState[channel]!.users}');
      print('🔍 [DEBUG] 👥 Channel users count: ${newState[channel]!.users.length}');
    } else {
      print('🔍 [DEBUG] ⚠️  Channel not found in service: $channel');
      print('🔍 [DEBUG] Available channels: ${newState.keys.toList()}');
    }
    
    // Comparar estados
    final keysChanged = newState.keys.length != state.keys.length;
    final valuesChanged = newState.entries.any((e) {
      final oldChannel = state[e.key];
      if (oldChannel == null) return true;
      final usersChanged = oldChannel.users.length != e.value.users.length ||
          !oldChannel.users.every((u) => e.value.users.contains(u));
      final topicChanged = oldChannel.topic != e.value.topic; // Verificar cambios en el topic
      return usersChanged || topicChanged;
    });
    
    print('🔍 [DEBUG] Keys changed: $keysChanged, Values changed: $valuesChanged');
    
    // Always update to ensure UI reflects current state
    print('🔍 [DEBUG] ✅ Updating state with new channels');
      state = newState;
    print('🔍 [DEBUG] ✅ State updated, now has ${state.length} channels');
  }

  void updateChannels() {
    print('🔍 [DEBUG] 🔄 updateChannels() called, service has ${_service.channels.length} channels');
    for (var entry in _service.channels.entries) {
      print('🔍 [DEBUG]   - ${entry.key}: ${entry.value.users.length} users: ${entry.value.users}');
    }
    
    // Crear una copia profunda del estado del servicio
    final newState = <String, IRCChannel>{};
    for (var entry in _service.channels.entries) {
      // Crear una copia profunda del canal con sus usuarios, topic, hosts y modos
      final channelCopy = IRCChannel(
        name: entry.value.name,
        messages: List.from(entry.value.messages),
        users: List.from(entry.value.users),
        userHosts: Map<String, String>.from(entry.value.userHosts), // Copiar el mapa de hosts
        userModes: Map<String, String>.from(entry.value.userModes), // Copiar el mapa de modos
        topic: entry.value.topic, // Incluir el topic en la copia
      );
      newState[entry.key] = channelCopy;
      print('🔍 [DEBUG] Copied channel ${entry.key} with ${channelCopy.users.length} users, topic: ${channelCopy.topic}');
    }
    
    print('🔍 [DEBUG] ✅ Updating state with ${newState.length} channels');
    state = newState;
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class ConnectionStatusNotifier extends StateNotifier<bool> {
  final IRCService _service;

  ConnectionStatusNotifier(this._service) : super(_service.isConnected) {
    // Inicializar con el estado actual del servicio
    // Esto asegura que si ya está conectado, el estado se refleje correctamente
    if (_service.isConnected) {
      state = true;
    }
    _service.addConnectionListener(() => state = true);
    _service.addDisconnectionListener(() => state = false);
  }
}

class WhoisNotifier extends StateNotifier<Map<String, WhoisInfo>> {
  final IRCService _service;

  WhoisNotifier(this._service) : super({}) {
    _service.addWhoisListener(_onWhoisReceived);
    // También cargar cualquier información que ya esté en caché
    // (por si se solicitó antes de abrir el perfil)
  }

  void _onWhoisReceived(WhoisInfo info) {
    print('🔍 [WHOIS NOTIFIER] Received whois info for: ${info.nick}');
    print('🔍 [WHOIS NOTIFIER] Info: ${info.username}@${info.host}, realName: ${info.realName}');
    final newState = {...state, info.nick.toLowerCase(): info};
    state = newState;
    print('🔍 [WHOIS NOTIFIER] Updated state, now has ${newState.length} entries');
  }

  WhoisInfo? getWhois(String nick) {
    return state[nick.toLowerCase()];
  }

  void requestWhois(String nick) {
    print('🔍 [WHOIS NOTIFIER] Requesting whois for: $nick');
    // Verificar si ya tenemos la información en caché del servicio
    final cachedInfo = _service.getWhoisInfo(nick);
    if (cachedInfo != null) {
      print('🔍 [WHOIS NOTIFIER] Found cached info, updating state');
      _onWhoisReceived(cachedInfo);
    } else {
      print('🔍 [WHOIS NOTIFIER] No cached info, requesting from server');
      _service.sendWhois(nick);
    }
  }

  @override
  void dispose() {
    // No hay removeWhoisListener, pero podríamos agregarlo si es necesario
    super.dispose();
  }
}

// Notifier para mensajes no leídos
class UnreadMessagesNotifier extends StateNotifier<Map<String, int>> {
  UnreadMessagesNotifier() : super({});

  void incrementUnread(String channel) {
    final normalizedChannel = channel.toLowerCase();
    state = {
      ...state,
      normalizedChannel: (state[normalizedChannel] ?? 0) + 1,
    };
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
class FavoritesNotifier extends StateNotifier<Set<String>> {
  static const _prefsKey = 'favorite_channels';
  static const _excludedPrefsKey = 'favorite_channels_excluded';
  
  // Lista de canales que el usuario ha eliminado de favoritos y no deben volver a añadirse automáticamente
  final Set<String> _excludedChannels = {};
  bool _isInitialized = false;
  final Completer<void> _initializationCompleter = Completer<void>();

  FavoritesNotifier() : super(<String>{}) {
    _initialize();
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
      print('📋 [FavoritesNotifier] ========== CARGANDO FAVORITOS ==========');
      print('📋 [FavoritesNotifier] Favoritos RAW de SharedPreferences: $list');
      print('📋 [FavoritesNotifier] Total favoritos RAW: ${list.length}');
      print('📋 [FavoritesNotifier] Canales excluidos actuales: $_excludedChannels');
      print('📋 [FavoritesNotifier] Total excluidos: ${_excludedChannels.length}');
      
      // Filtrar los canales excluidos al cargar
      final filtered = list
          .map((e) => e.toLowerCase())
          .where((e) => !_excludedChannels.contains(e))
          .toList();
      
      print('📋 [FavoritesNotifier] Favoritos después de filtrar excluidos: $filtered');
      print('📋 [FavoritesNotifier] Total favoritos filtrados: ${filtered.length}');
      
      // Si hay canales excluidos en la lista guardada, limpiarlos de SharedPreferences
      if (filtered.length != list.length) {
        final removed = list.where((e) => _excludedChannels.contains(e.toLowerCase())).toList();
        await prefs.setStringList(_prefsKey, filtered);
        print('🧹 [FavoritesNotifier] Limpiados ${list.length - filtered.length} canales excluidos de favoritos guardados');
        print('🧹 [FavoritesNotifier] Canales eliminados específicamente: $removed');
      }
      
      state = filtered.toSet();
      print('✅ [FavoritesNotifier] Estado final de favoritos: $state');
      print('✅ [FavoritesNotifier] Total en estado final: ${state.length}');
      print('📋 [FavoritesNotifier] ===========================================');
    } catch (e) {
      print('❌ [FavoritesNotifier] Error al cargar favoritos: $e');
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
      
      print('🧹 [FavoritesNotifier] ========== LIMPIANDO TODOS LOS FAVORITOS ==========');
      print('🧹 [FavoritesNotifier] Estado ANTES de limpiar: $state');
      print('🧹 [FavoritesNotifier] Excluidos ANTES de limpiar: $_excludedChannels');
      
      // Obtener los favoritos actuales antes de limpiar para logging
      final currentFavorites = prefs.getStringList(_prefsKey) ?? <String>[];
      print('🧹 [FavoritesNotifier] Favoritos en SharedPreferences ANTES: $currentFavorites');
      
      // Limpiar favoritos guardados
      final removedFavorites = await prefs.remove(_prefsKey);
      print('🧹 [FavoritesNotifier] Favoritos eliminados de SharedPreferences: $removedFavorites');
      
      // Verificar que se eliminaron correctamente
      final verifyFavorites = prefs.getStringList(_prefsKey) ?? <String>[];
      print('🧹 [FavoritesNotifier] Verificación - Favoritos después de remove: $verifyFavorites');
      
      // Limpiar también la lista de excluidos para permitir que el usuario vuelva a añadir canales
      final currentExcluded = prefs.getStringList(_excludedPrefsKey) ?? <String>[];
      print('🧹 [FavoritesNotifier] Excluidos en SharedPreferences ANTES: $currentExcluded');
      
      _excludedChannels.clear();
      final removedExcluded = await prefs.remove(_excludedPrefsKey);
      print('🧹 [FavoritesNotifier] Excluidos eliminados de SharedPreferences: $removedExcluded');
      
      // Verificar que se eliminaron correctamente
      final verifyExcluded = prefs.getStringList(_excludedPrefsKey) ?? <String>[];
      print('🧹 [FavoritesNotifier] Verificación - Excluidos después de remove: $verifyExcluded');
      
      // Actualizar el estado
      state = <String>{};
      print('✅ [FavoritesNotifier] Estado DESPUÉS de limpiar: $state');
      print('✅ [FavoritesNotifier] Excluidos DESPUÉS de limpiar: $_excludedChannels');
      print('🧹 [FavoritesNotifier] ====================================================');
    } catch (e) {
      print('❌ [FavoritesNotifier] Error al limpiar favoritos: $e');
    }
  }
}

/// Notifier para canales/nicks recientes
class RecentChannelsNotifier extends StateNotifier<List<String>> {
  static const int maxItems = 20;
  static const _prefsKey = 'recent_channels_excluded';
  
  // Lista de canales que el usuario ha eliminado y no deben volver a añadirse automáticamente
  final Set<String> _excludedChannels = {};

  RecentChannelsNotifier() : super(const []) {
    _loadExcludedChannels();
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
    final filtered =
        state.where((c) => _normalize(c) != key).toList(growable: true);
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

/// Notifier para mensajes fijados por canal
class PinnedMessagesNotifier
    extends StateNotifier<Map<String, List<IRCMessage>>> {
  static const int maxPinnedPerChannel = 5;
  static const _prefsKey = 'pinned_messages_v1';

  PinnedMessagesNotifier() : super({}) {
    _loadFromPrefs();
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

    final existingIndex =
        current.indexWhere((m) => _isSameMessage(m, message));

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

    state = {
      ...state,
      key: current,
    };

    _saveToPrefs();
  }
}

enum NotificationLevel { allMessages, mentionsOnly, muted }

enum MentionSound { cuack, systemAlert, systemClick }

class NotificationSettings {
  final Map<String, NotificationLevel> channelLevels;
  final bool soundForPrivates;
  final bool soundForMentions;
  final Set<String> mutedUsers;
  final MentionSound mentionSound;

  const NotificationSettings({
    this.channelLevels = const {},
    this.soundForPrivates = true,
    this.soundForMentions = true,
    this.mutedUsers = const {},
    this.mentionSound = MentionSound.cuack,
  });

  NotificationSettings copyWith({
    Map<String, NotificationLevel>? channelLevels,
    bool? soundForPrivates,
    bool? soundForMentions,
    Set<String>? mutedUsers,
    MentionSound? mentionSound,
  }) {
    return NotificationSettings(
      channelLevels: channelLevels ?? this.channelLevels,
      soundForPrivates: soundForPrivates ?? this.soundForPrivates,
      soundForMentions: soundForMentions ?? this.soundForMentions,
      mutedUsers: mutedUsers ?? this.mutedUsers,
      mentionSound: mentionSound ?? this.mentionSound,
    );
  }

  NotificationLevel levelForChannel(String channel) {
    final key = channel.toLowerCase();
    return channelLevels[key] ?? NotificationLevel.allMessages;
  }

  bool isUserMuted(String nick) {
    return mutedUsers.contains(nick.toLowerCase());
  }
}

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettings> {
  static const _prefsKeyLevels = 'notification_channel_levels_v1';
  static const _prefsKeyPrivates = 'notification_sound_privates';
  static const _prefsKeyMentions = 'notification_sound_mentions';
  static const _prefsKeyMutedUsers = 'notification_muted_users_v1';
  static const _prefsKeyMentionSound = 'notification_mention_sound_v1';

  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _loadFromPrefs();
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

      final privates = prefs.getBool(_prefsKeyPrivates) ?? true;
      final mentions = prefs.getBool(_prefsKeyMentions) ?? true;
      final mutedList = prefs.getStringList(_prefsKeyMutedUsers) ?? <String>[];
      final mentionSoundRaw =
          prefs.getString(_prefsKeyMentionSound) ?? 'cuack';
      final mentionSound = switch (mentionSoundRaw) {
        'alert' => MentionSound.systemAlert,
        'click' => MentionSound.systemClick,
        _ => MentionSound.cuack,
      };

      state = NotificationSettings(
        channelLevels: levels,
        soundForPrivates: privates,
        soundForMentions: mentions,
        mutedUsers: mutedList.map((e) => e.toLowerCase()).toSet(),
        mentionSound: mentionSound,
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
      await prefs.setStringList(
        _prefsKeyMutedUsers,
        state.mutedUsers.toList(),
      );
      String mentionValue = 'cuack';
      switch (state.mentionSound) {
        case MentionSound.systemAlert:
          mentionValue = 'alert';
          break;
        case MentionSound.systemClick:
          mentionValue = 'click';
          break;
        case MentionSound.cuack:
        default:
          mentionValue = 'cuack';
      }
      await prefs.setString(_prefsKeyMentionSound, mentionValue);
    } catch (_) {}
  }

  void setChannelLevel(String channel, NotificationLevel level) {
    final key = channel.toLowerCase();
    final newLevels = Map<String, NotificationLevel>.from(state.channelLevels);
    newLevels[key] = level;
    state = state.copyWith(channelLevels: newLevels);
    _saveLevels();
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
}

// Notifier para typing indicators
class TypingIndicatorNotifier extends StateNotifier<Map<String, String?>> {
  TypingIndicatorNotifier() : super({});
  final Map<String, Timer> _timers = {};

  void setTyping(String channel, String? nick) {
    final normalizedChannel = channel.toLowerCase();
    
    // Cancelar timer anterior si existe
    _timers[normalizedChannel]?.cancel();
    
    state = {
      ...state,
      normalizedChannel: nick,
    };
    
    // Si hay un nick, programar que desaparezca después de 3 segundos
    if (nick != null) {
      _timers[normalizedChannel] = Timer(const Duration(seconds: 3), () {
        if (state[normalizedChannel] == nick) {
          state = {
            ...state,
            normalizedChannel: null,
          };
        }
      });
    }
  }

  void clearTyping(String channel) {
    final normalizedChannel = channel.toLowerCase();
    _timers[normalizedChannel]?.cancel();
    _timers.remove(normalizedChannel);
    state = {
      ...state,
      normalizedChannel: null,
    };
  }

  String? getTyping(String channel) {
    return state[channel.toLowerCase()];
  }

  @override
  void dispose() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

// Provider para typing indicators (quién está escribiendo en cada canal)
final typingIndicatorProvider = StateNotifierProvider<TypingIndicatorNotifier, Map<String, String?>>((ref) {
  return TypingIndicatorNotifier();
});

// Notifier para refrescar avatares en tiempo real
class AvatarRefreshNotifier extends StateNotifier<Map<String, int>> {
  Timer? _refreshTimer;
  int _currentRefreshIndex = 0;
  bool _isRefreshing = false;

  AvatarRefreshNotifier() : super({}) {
    _startRefreshCycle();
  }
  
  void _startRefreshCycle() {
    // Esperar 60 segundos antes de empezar el ciclo de refresco
    Future.delayed(const Duration(seconds: 60), () {
      if (!mounted) return;
      _refreshNextAvatar();
    });
  }
  
  void _refreshNextAvatar() {
    if (!mounted || _isRefreshing) return;
    
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
      state = {
        ...state,
        entry.key: DateTime.now().millisecondsSinceEpoch,
      };
      _currentRefreshIndex++;
      _isRefreshing = false;
      
      // Esperar 2 segundos antes de actualizar el siguiente avatar
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _refreshNextAvatar();
        }
      });
    } else {
      // Reiniciar el ciclo cuando se hayan actualizado todos
      _currentRefreshIndex = 0;
      _startRefreshCycle();
    }
  }

  void refreshAvatar(String nick) {
    final normalizedNick = nick.toLowerCase();
    state = {
      ...state,
      normalizedNick: DateTime.now().millisecondsSinceEpoch,
    };
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

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// Provider para invalidar/refrescar avatares
final avatarRefreshProvider = StateNotifierProvider<AvatarRefreshNotifier, Map<String, int>>((ref) {
  return AvatarRefreshNotifier();
});

class EmojiConfigNotifier extends StateNotifier<EmojiConfig> {
  EmojiConfigNotifier() : super(EmojiConfig.defaultConfig);

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
class ServerProfilesNotifier extends StateNotifier<List<ServerProfile>> {
  ServerProfilesNotifier()
      : super(List<ServerProfile>.from(ServerProfile.defaultGlobalChatProfiles));

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
enum MessageFormat { bubble, plain }

class MessageFormatPreferences {
  final MessageFormat channelFormat;
  final MessageFormat privateFormat;

  const MessageFormatPreferences({
    this.channelFormat = MessageFormat.bubble,
    this.privateFormat = MessageFormat.bubble,
  });

  MessageFormatPreferences copyWith({
    MessageFormat? channelFormat,
    MessageFormat? privateFormat,
  }) {
    return MessageFormatPreferences(
      channelFormat: channelFormat ?? this.channelFormat,
      privateFormat: privateFormat ?? this.privateFormat,
    );
  }
}

final messageFormatPreferencesProvider =
    StateNotifierProvider<MessageFormatPreferencesNotifier, MessageFormatPreferences>((ref) {
  return MessageFormatPreferencesNotifier();
});

class MessageFormatPreferencesNotifier
    extends StateNotifier<MessageFormatPreferences> {
  static const _prefsKeyChannel = 'message_format_channel';
  static const _prefsKeyPrivate = 'message_format_private';

  MessageFormatPreferencesNotifier()
      : super(const MessageFormatPreferences()) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelRaw = prefs.getString(_prefsKeyChannel) ?? 'bubble';
      final privateRaw = prefs.getString(_prefsKeyPrivate) ?? 'bubble';

      final channelFormat = channelRaw == 'plain'
          ? MessageFormat.plain
          : MessageFormat.bubble;
      final privateFormat = privateRaw == 'plain'
          ? MessageFormat.plain
          : MessageFormat.bubble;

      state = MessageFormatPreferences(
        channelFormat: channelFormat,
        privateFormat: privateFormat,
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
          _prefsKeyChannel, format == MessageFormat.plain ? 'plain' : 'bubble');
    } catch (_) {
      // Ignorar errores de guardado
    }
  }

  Future<void> setPrivateFormat(MessageFormat format) async {
    state = state.copyWith(privateFormat: format);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKeyPrivate, format == MessageFormat.plain ? 'plain' : 'bubble');
    } catch (_) {
      // Ignorar errores de guardado
    }
  }
}

