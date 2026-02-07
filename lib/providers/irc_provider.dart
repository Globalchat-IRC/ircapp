import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart' show Notifier, NotifierProvider, Provider, Ref;
import 'package:riverpod/riverpod.dart' show Notifier, NotifierProvider, Provider, Ref;
import 'package:riverpod/legacy.dart' show StateProvider;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/irc_message.dart';
import '../models/whois_info.dart';
import '../models/emoji_config.dart';
import '../models/server_profile.dart';
import '../models/custom_robot.dart';
import '../services/irc_service.dart';
import '../services/chat_history_service.dart';
import '../utils/platform_utils.dart';
import 'history_provider.dart';

final ircServiceProvider = Provider<IRCService>((ref) {
  return IRCService();
});

final messagesProvider = NotifierProvider<MessagesNotifier, List<IRCMessage>>(() {
  final notifier = MessagesNotifier();
  // Observar cambios en el historial para cargar/guardar mensajes
  // Esto se hace en el build del notifier
  return notifier;
});

final channelsProvider = NotifierProvider<ChannelsNotifier, Map<String, IRCChannel>>(() {
  return ChannelsNotifier();
});

final connectionStatusProvider = NotifierProvider<ConnectionStatusNotifier, bool>(() {
  return ConnectionStatusNotifier();
});

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
final messageSendDelayProvider = NotifierProvider<MessageSendDelayNotifier, int>(() {
  return MessageSendDelayNotifier();
});

class MessageSendDelayNotifier extends Notifier<int> {
  static const _prefsKey = 'message_send_delay_seconds';
  static const int _defaultDelay = 10; // 10 segundos por defecto

  @override
  int build() {
    _loadFromPrefs();
    return _defaultDelay;
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

final currentChannelProvider = StateProvider<String?>((ref) => null);

/// Último canal utilizado, para recordar la selección al volver al login
final lastChannelProvider = StateProvider<String?>((ref) => null);

/// Lista de canales para autojoin cuando se cambia de servidor
final autoJoinChannelsProvider = StateProvider<List<String>>((ref) => []);

/// Canales/nicks marcados como favoritos (para autounirse y sección destacada)
final favoritesProvider =
    NotifierProvider<FavoritesNotifier, Set<String>>(() {
  return FavoritesNotifier();
});

/// Lista de canales/nicks recientes (histórico ligero de uso)
final recentChannelsProvider =
    NotifierProvider<RecentChannelsNotifier, List<String>>(() {
  return RecentChannelsNotifier();
});

/// Mensajes fijados por canal (avisos, reglas, enlaces importantes)
final pinnedMessagesProvider = NotifierProvider<PinnedMessagesNotifier,
    Map<String, List<IRCMessage>>>(() {
  return PinnedMessagesNotifier();
});

/// Reglas de notificación por canal y tipo de sonido
final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        () {
  return NotificationSettingsNotifier();
});

/// Perfil de servidor actual (para multi-servidor/multi-red)
/// Persistido en SharedPreferences para mantener el valor entre navegaciones
final currentServerProfileProvider = NotifierProvider<CurrentServerProfileNotifier, ServerProfile?>(() {
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
      print('🔍 [SERVER_PROFILE] Leyendo desde prefs, serverId: $serverId');
      if (serverId != null && serverId.isNotEmpty) {
        // Buscar el perfil por ID en la lista de perfiles por defecto
        final profile = ServerProfile.defaultGlobalChatProfiles.firstWhere(
          (p) => p.id == serverId,
          orElse: () => ServerProfile.defaultGlobalChatProfiles.firstWhere(
            (p) => p.isDefault,
            orElse: () => ServerProfile.defaultGlobalChatProfiles.first,
          ),
        );
        state = profile;
        print('🔍 [SERVER_PROFILE] ✅ Cargado desde prefs: ${profile.name} (${profile.host}:${profile.port})');
      } else {
        print('🔍 [SERVER_PROFILE] No hay serverId guardado en prefs');
      }
    } catch (e) {
      print('❌ [SERVER_PROFILE] Error cargando desde prefs: $e');
    }
  }

  Future<void> setServerProfile(ServerProfile profile) async {
    print('🔍 [SERVER_PROFILE] setServerProfile llamado: ${profile.name} (${profile.host}:${profile.port}, id: ${profile.id})');
    state = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, profile.id);
      print('🔍 [SERVER_PROFILE] ✅ Guardado en prefs: ${profile.name} (id: ${profile.id})');
      
      // Verificar que se guardó correctamente
      final savedId = prefs.getString(_prefsKey);
      print('🔍 [SERVER_PROFILE] Verificación - serverId en prefs: $savedId');
    } catch (e) {
      print('❌ [SERVER_PROFILE] Error guardando en prefs: $e');
    }
  }

  void clearServerProfile() {
    state = null;
    try {
      final prefs = SharedPreferences.getInstance();
      prefs.then((p) => p.remove(_prefsKey));
    } catch (e) {
      print('❌ [SERVER_PROFILE] Error limpiando prefs: $e');
    }
  }
}

/// Lista de perfiles de servidor disponibles (inicialmente los de GlobalChat)
final serverProfilesProvider =
    NotifierProvider<ServerProfilesNotifier, List<ServerProfile>>(() {
  return ServerProfilesNotifier();
});

final whoisProvider = NotifierProvider<WhoisNotifier, Map<String, WhoisInfo>>(() {
  return WhoisNotifier();
});

final emojiConfigProvider = NotifierProvider<EmojiConfigNotifier, EmojiConfig>(() {
  return EmojiConfigNotifier();
});

// Provider para mensajes no leídos por canal
final unreadMessagesProvider = NotifierProvider<UnreadMessagesNotifier, Map<String, int>>(() {
  return UnreadMessagesNotifier();
});

class MessagesNotifier extends Notifier<List<IRCMessage>> {
  static const String _privateMessagesKey = 'private_messages_web';
  static const String _allMessagesKey = 'all_messages_history';
  IRCService? _service;

  @override
  List<IRCMessage> build() {
    _service = ref.read(ircServiceProvider);
    _service!.addMessageListener(_onMessage);
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
          final key = msg.messageId ?? '${msg.channel}_${msg.nick}_${msg.message}_${msg.timestamp.millisecondsSinceEpoch}';
          if (!uniqueMessages.containsKey(key)) {
            uniqueMessages[key] = msg;
          }
        }
        
        // Actualizar el estado con todos los mensajes cargados (sin duplicados)
        state = uniqueMessages.values.toList();
        print('✅ [MessagesNotifier] Historial cargado: ${state.length} mensajes únicos');
      }
    } catch (e) {
      print('⚠️ [MessagesNotifier] Error cargando historial: $e');
    }
  }
  
  /// Guardar todo el historial de mensajes (canales y privados)
  Future<void> _saveHistory() async {
    final historyEnabled = ref.read(historyEnabledProvider);
    if (!historyEnabled) return; // No guardar si el historial está desactivado
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limitar a los últimos 10000 mensajes para evitar sobrecargar el almacenamiento
      final messagesToSave = state.length > 10000 
          ? state.sublist(state.length - 10000) 
          : state;
      
      final jsonList = messagesToSave.map((msg) => msg.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_allMessagesKey, jsonString);
      // Guardar también en la clave antigua para compatibilidad
      await _savePrivateMessages();
    } catch (e) {
      print('⚠️ [MessagesNotifier] Error guardando historial: $e');
    }
  }
  
  /// Actualizar estado y guardar historial si está activado
  void _updateStateAndSave(List<IRCMessage> newState) {
    state = newState;
    // Guardar historial de forma asíncrona sin bloquear
    Future.microtask(() => _saveHistory());
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
            .where((msg) => !msg.channel.startsWith('#')) // Solo mensajes privados
            .toList();
        
        // Añadir los mensajes privados al estado actual (sin duplicar canales)
        final currentChannels = state.where((m) => m.channel.startsWith('#')).toList();
        state = [...currentChannels, ...privateMessages];
      }
    } catch (e) {
      // Ignorar errores de carga
      print('⚠️ [MessagesNotifier] Error cargando mensajes privados: $e');
    }
  }

  /// Guardar mensajes privados en SharedPreferences (solo en web)
  Future<void> _savePrivateMessages() async {
    if (!PlatformUtils.isWeb) return;
    
    try {
      final privateMessages = state.where((m) => !m.channel.startsWith('#')).toList();
      final jsonList = privateMessages.map((msg) => msg.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_privateMessagesKey, jsonString);
    } catch (e) {
      // Ignorar errores de guardado
      print('⚠️ [MessagesNotifier] Error guardando mensajes privados: $e');
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
      print('⚠️ [MessagesNotifier] Error borrando historial del canal: $e');
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
      print('⚠️ [MessagesNotifier] Error borrando historial privado: $e');
    }
    
    _saveHistory();
  }

  void _onMessage(IRCMessage message) {
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
        _updateStateAndSave(updatedState);
        return;
      }
    }
    
    // Si no es una actualización, añadir como nuevo mensaje
    _updateStateAndSave([...state, message]);
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
      print('⚠️ [MessagesNotifier] Error limpiando historial: $e');
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
    // print('🔍 [DEBUG] 🔄 ChannelsNotifier._onUserListUpdate: channel=$channel');
    // print('🔍 [DEBUG] 📊 Service channels: ${_service.channels.keys.toList()}');
    // print('🔍 [DEBUG] 📊 Current state channels: ${state.keys.toList()}');
    
    // Always update the entire state with current service state
    final newState = <String, IRCChannel>{};
    for (var entry in _service!.channels.entries) {
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
      // print('🔍 [DEBUG] Copied channel ${entry.key} with ${channelCopy.users.length} users: ${channelCopy.users}, topic: ${channelCopy.topic}');
    }
    
    if (newState.containsKey(channel)) {
      // print('🔍 [DEBUG] 👥 Channel found in new state, users: ${newState[channel]!.users}');
      // print('🔍 [DEBUG] 👥 Channel users count: ${newState[channel]!.users.length}');
    } else {
      // print('🔍 [DEBUG] ⚠️  Channel not found in service: $channel');
      // print('🔍 [DEBUG] Available channels: ${newState.keys.toList()}');
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
    
    // print('🔍 [DEBUG] Keys changed: $keysChanged, Values changed: $valuesChanged');
    
    // Always update to ensure UI reflects current state
    // print('🔍 [DEBUG] ✅ Updating state with new channels');
      state = newState;
    // print('🔍 [DEBUG] ✅ State updated, now has ${state.length} channels');
  }

  void updateChannels() {
    // print('🔍 [DEBUG] 🔄 updateChannels() called, service has ${_service.channels.length} channels');
    for (var entry in _service!.channels.entries) {
      // print('🔍 [DEBUG]   - ${entry.key}: ${entry.value.users.length} users: ${entry.value.users}');
    }
    
    // Crear una copia profunda del estado del servicio
    final newState = <String, IRCChannel>{};
    for (var entry in _service!.channels.entries) {
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
      // print('🔍 [DEBUG] Copied channel ${entry.key} with ${channelCopy.users.length} users, topic: ${channelCopy.topic}');
    }
    
    // print('🔍 [DEBUG] ✅ Updating state with ${newState.length} channels');
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
    _service!.addDisconnectionListener(() => state = false);
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
    // print('🔍 [WHOIS NOTIFIER] Received whois info for: ${info.nick}');
    // print('🔍 [WHOIS NOTIFIER] Info: ${info.username}@${info.host}, realName: ${info.realName}');
    final newState = {...state, info.nick.toLowerCase(): info};
    state = newState;
    // print('🔍 [WHOIS NOTIFIER] Updated state, now has ${newState.length} entries');
  }

  WhoisInfo? getWhois(String nick) {
    return state[nick.toLowerCase()];
  }

  void requestWhois(String nick) {
    // print('🔍 [WHOIS NOTIFIER] Requesting whois for: $nick');
    // Verificar si ya tenemos la información en caché del servicio
      final cachedInfo = _service?.getWhoisInfo(nick);
    if (cachedInfo != null) {
      // print('🔍 [WHOIS NOTIFIER] Found cached info, updating state');
      _onWhoisReceived(cachedInfo);
    } else {
      // print('🔍 [WHOIS NOTIFIER] No cached info, requesting from server');
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
      // print('📋 [FavoritesNotifier] ========== CARGANDO FAVORITOS ==========');
      // print('📋 [FavoritesNotifier] Favoritos RAW de SharedPreferences: $list');
      // print('📋 [FavoritesNotifier] Total favoritos RAW: ${list.length}');
      // print('📋 [FavoritesNotifier] Canales excluidos actuales: $_excludedChannels');
      // print('📋 [FavoritesNotifier] Total excluidos: ${_excludedChannels.length}');
      
      // Filtrar los canales excluidos al cargar
      final filtered = list
          .map((e) => e.toLowerCase())
          .where((e) => !_excludedChannels.contains(e))
          .toList();
      
      // print('📋 [FavoritesNotifier] Favoritos después de filtrar excluidos: $filtered');
      // print('📋 [FavoritesNotifier] Total favoritos filtrados: ${filtered.length}');
      
      // Si hay canales excluidos en la lista guardada, limpiarlos de SharedPreferences
      if (filtered.length != list.length) {
        final removed = list.where((e) => _excludedChannels.contains(e.toLowerCase())).toList();
        await prefs.setStringList(_prefsKey, filtered);
        // print('🧹 [FavoritesNotifier] Limpiados ${list.length - filtered.length} canales excluidos de favoritos guardados');
        // print('🧹 [FavoritesNotifier] Canales eliminados específicamente: $removed');
      }
      
      state = filtered.toSet();
      // print('✅ [FavoritesNotifier] Estado final de favoritos: $state');
      // print('✅ [FavoritesNotifier] Total en estado final: ${state.length}');
      // print('📋 [FavoritesNotifier] ===========================================');
    } catch (e) {
      // print('❌ [FavoritesNotifier] Error al cargar favoritos: $e');
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
      
      // print('🧹 [FavoritesNotifier] ========== LIMPIANDO TODOS LOS FAVORITOS ==========');
      // print('🧹 [FavoritesNotifier] Estado ANTES de limpiar: $state');
      // print('🧹 [FavoritesNotifier] Excluidos ANTES de limpiar: $_excludedChannels');
      
      // Obtener los favoritos actuales antes de limpiar para logging
      final currentFavorites = prefs.getStringList(_prefsKey) ?? <String>[];
      // print('🧹 [FavoritesNotifier] Favoritos en SharedPreferences ANTES: $currentFavorites');
      
      // Limpiar favoritos guardados
      final removedFavorites = await prefs.remove(_prefsKey);
      // print('🧹 [FavoritesNotifier] Favoritos eliminados de SharedPreferences: $removedFavorites');
      
      // Verificar que se eliminaron correctamente
      final verifyFavorites = prefs.getStringList(_prefsKey) ?? <String>[];
      // print('🧹 [FavoritesNotifier] Verificación - Favoritos después de remove: $verifyFavorites');
      
      // Limpiar también la lista de excluidos para permitir que el usuario vuelva a añadir canales
      final currentExcluded = prefs.getStringList(_excludedPrefsKey) ?? <String>[];
      // print('🧹 [FavoritesNotifier] Excluidos en SharedPreferences ANTES: $currentExcluded');
      
      _excludedChannels.clear();
      final removedExcluded = await prefs.remove(_excludedPrefsKey);
      // print('🧹 [FavoritesNotifier] Excluidos eliminados de SharedPreferences: $removedExcluded');
      
      // Verificar que se eliminaron correctamente
      final verifyExcluded = prefs.getStringList(_excludedPrefsKey) ?? <String>[];
      // print('🧹 [FavoritesNotifier] Verificación - Excluidos después de remove: $verifyExcluded');
      
      // Actualizar el estado
      state = <String>{};
      // print('✅ [FavoritesNotifier] Estado DESPUÉS de limpiar: $state');
      // print('✅ [FavoritesNotifier] Excluidos DESPUÉS de limpiar: $_excludedChannels');
      // print('🧹 [FavoritesNotifier] ====================================================');
    } catch (e) {
      // print('❌ [FavoritesNotifier] Error al limpiar favoritos: $e');
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
    extends Notifier<Map<String, List<IRCMessage>>> {
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
    extends Notifier<NotificationSettings> {
  static const _prefsKeyLevels = 'notification_channel_levels_v1';
  static const _prefsKeyPrivates = 'notification_sound_privates';
  static const _prefsKeyMentions = 'notification_sound_mentions';
  static const _prefsKeyMutedUsers = 'notification_muted_users_v1';
  static const _prefsKeyMentionSound = 'notification_mention_sound_v1';

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
class TypingIndicatorNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};
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
    // Nota: En Riverpod 3.x, Notifier no tiene dispose()
  }
}

// Provider para typing indicators (quién está escribiendo en cada canal)
final typingIndicatorProvider = NotifierProvider<TypingIndicatorNotifier, Map<String, String?>>(() {
  return TypingIndicatorNotifier();
});

// Notifier para refrescar avatares en tiempo real
class AvatarRefreshNotifier extends Notifier<Map<String, int>> {
  Timer? _refreshTimer;
  int _currentRefreshIndex = 0;
  bool _isRefreshing = false;

  @override
  Map<String, int> build() {
    _startRefreshCycle();
    return {};
  }
  
  void _startRefreshCycle() {
    // Esperar 60 segundos antes de empezar el ciclo de refresco
    Future.delayed(const Duration(seconds: 60), () {
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
      state = {
        ...state,
        entry.key: DateTime.now().millisecondsSinceEpoch,
      };
      _currentRefreshIndex++;
      _isRefreshing = false;
      
      // Esperar 2 segundos antes de actualizar el siguiente avatar
      Future.delayed(const Duration(seconds: 2), () {
        // Nota: Notifier no tiene 'mounted'
        {
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
  // Nota: En Riverpod 3.x, Notifier no tiene dispose()
  // Limpiar timers en un método separado si es necesario
  void _cleanup() {
    _refreshTimer?.cancel();
  }
}

// Provider para invalidar/refrescar avatares
final avatarRefreshProvider = NotifierProvider<AvatarRefreshNotifier, Map<String, int>>(() {
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
  List<ServerProfile> build() => List<ServerProfile>.from(ServerProfile.defaultGlobalChatProfiles);

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
  final bool showTimestamp;
  final double channelFontSize;
  final double privateFontSize;
  final String channelFontFamily;
  final String privateFontFamily;
  final double emojiSize;

  const MessageFormatPreferences({
    this.channelFormat = MessageFormat.plain,
    this.privateFormat = MessageFormat.plain,
    this.showTimestamp = true,
    this.channelFontSize = 15.0,
    this.privateFontSize = 15.0,
    this.channelFontFamily = 'Roboto',
    this.privateFontFamily = 'Roboto',
    this.emojiSize = 40.0,
  });

  MessageFormatPreferences copyWith({
    MessageFormat? channelFormat,
    MessageFormat? privateFormat,
    bool? showTimestamp,
    double? channelFontSize,
    double? privateFontSize,
    String? channelFontFamily,
    String? privateFontFamily,
    double? emojiSize,
  }) {
    return MessageFormatPreferences(
      channelFormat: channelFormat ?? this.channelFormat,
      privateFormat: privateFormat ?? this.privateFormat,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      channelFontSize: channelFontSize ?? this.channelFontSize,
      privateFontSize: privateFontSize ?? this.privateFontSize,
      channelFontFamily: channelFontFamily ?? this.channelFontFamily,
      privateFontFamily: privateFontFamily ?? this.privateFontFamily,
      emojiSize: emojiSize ?? this.emojiSize,
    );
  }
}

final messageFormatPreferencesProvider =
    NotifierProvider<MessageFormatPreferencesNotifier, MessageFormatPreferences>(() {
  return MessageFormatPreferencesNotifier();
});

class MessageFormatPreferencesNotifier
    extends Notifier<MessageFormatPreferences> {
  static const _prefsKeyChannel = 'message_format_channel';
  static const _prefsKeyPrivate = 'message_format_private';
  static const _prefsKeyShowTimestamp = 'message_show_timestamp';
  static const _prefsKeyChannelFontSize = 'message_channel_font_size';
  static const _prefsKeyPrivateFontSize = 'message_private_font_size';
  static const _prefsKeyChannelFontFamily = 'message_channel_font_family';
  static const _prefsKeyPrivateFontFamily = 'message_private_font_family';
   static const _prefsKeyEmojiSize = 'message_emoji_size';

  @override
  MessageFormatPreferences build() {
    _loadFromPrefs();
    return const MessageFormatPreferences();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelRaw = prefs.getString(_prefsKeyChannel) ?? 'plain';
      final privateRaw = prefs.getString(_prefsKeyPrivate) ?? 'plain';
      final showTimestamp = prefs.getBool(_prefsKeyShowTimestamp) ?? true;
      final channelFontSize = prefs.getDouble(_prefsKeyChannelFontSize) ?? 15.0;
      final privateFontSize = prefs.getDouble(_prefsKeyPrivateFontSize) ?? 15.0;
      final channelFontFamily = prefs.getString(_prefsKeyChannelFontFamily) ?? 'Roboto';
      final privateFontFamily = prefs.getString(_prefsKeyPrivateFontFamily) ?? 'Roboto';
      final emojiSize = prefs.getDouble(_prefsKeyEmojiSize) ?? 40.0;

      final channelFormat = channelRaw == 'plain'
          ? MessageFormat.plain
          : MessageFormat.bubble;
      final privateFormat = privateRaw == 'plain'
          ? MessageFormat.plain
          : MessageFormat.bubble;

      state = MessageFormatPreferences(
        channelFormat: channelFormat,
        privateFormat: privateFormat,
        showTimestamp: showTimestamp,
        channelFontSize: channelFontSize,
        privateFontSize: privateFontSize,
        channelFontFamily: channelFontFamily,
        privateFontFamily: privateFontFamily,
        emojiSize: emojiSize,
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

  Future<void> setShowTimestamp(bool show) async {
    state = state.copyWith(showTimestamp: show);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyShowTimestamp, show);
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
}

/// Provider para iconos personalizados de usuarios
/// Mapea nick -> icono (emoji o inicial)
final userIconsProvider = NotifierProvider<UserIconsNotifier, Map<String, String>>(() {
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
      // print('Error cargando iconos personalizados: $e');
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
      // print('Error guardando icono personalizado: $e');
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
      // print('Error eliminando icono personalizado: $e');
    }
  }
  
  String? getIcon(String nick) {
    return state[nick.toLowerCase()];
  }
}

/// Provider para robots personalizados
/// Permite añadir robots manualmente y asignarles iconos personalizados
final customRobotsProvider = NotifierProvider<CustomRobotsNotifier, List<CustomRobot>>(() {
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
      ];
      
      if (robotsJson != null) {
        final List<dynamic> decoded = json.decode(robotsJson);
        final loadedRobots = decoded.map((json) => CustomRobot.fromJson(json as Map<String, dynamic>)).toList();
        
        // Añadir robots por defecto que no estén ya en la lista
        bool needsSave = false;
        for (var defaultRobot in defaultRobots) {
          final exists = loadedRobots.any((r) => r.nick.toLowerCase() == defaultRobot.nick.toLowerCase());
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
      print('Error cargando robots personalizados: $e');
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
      ];
    }
  }
  
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final robotsJson = json.encode(state.map((r) => r.toJson()).toList());
      await prefs.setString(_prefsKey, robotsJson);
    } catch (e) {
      print('Error guardando robots personalizados: $e');
    }
  }
  
  Future<void> addRobot(CustomRobot robot) async {
    // Verificar que no exista ya
    final existingIndex = state.indexWhere((r) => r.nick.toLowerCase() == robot.nick.toLowerCase());
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
    state = state.where((r) => r.nick.toLowerCase() != nick.toLowerCase()).toList();
    await _saveToPrefs();
  }
  
  Future<void> updateRobot(String nick, CustomRobot updatedRobot) async {
    final index = state.indexWhere((r) => r.nick.toLowerCase() == nick.toLowerCase());
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
      return state.any((r) => 
        r.host != null && 
        host.toLowerCase().contains(r.host!.toLowerCase())
      );
    }
    
    return false;
  }

  /// Agregar múltiples robots a la vez
  /// Útil para inicializar con una lista de bots conocidos
  Future<void> addRobots(List<CustomRobot> robots) async {
    final newState = List<CustomRobot>.from(state);
    
    for (var robot in robots) {
      final existingIndex = newState.indexWhere((r) => r.nick.toLowerCase() == robot.nick.toLowerCase());
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