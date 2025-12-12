import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/irc_message.dart';
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

final currentNicknameProvider = StateProvider<String?>((ref) {
  return null;
});

final currentChannelProvider = StateProvider<String?>((ref) {
  return null;
});

class MessagesNotifier extends StateNotifier<List<IRCMessage>> {
  final IRCService _service;

  MessagesNotifier(this._service) : super([]) {
    _service.addMessageListener(_onMessage);
  }

  void _onMessage(IRCMessage message) {
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
      // Crear una copia profunda del canal con sus usuarios, topic y hosts
      final channelCopy = IRCChannel(
        name: entry.value.name,
        messages: List.from(entry.value.messages),
        users: List.from(entry.value.users),
        userHosts: Map<String, String>.from(entry.value.userHosts), // Copiar el mapa de hosts
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
      // Crear una copia profunda del canal con sus usuarios, topic y hosts
      final channelCopy = IRCChannel(
        name: entry.value.name,
        messages: List.from(entry.value.messages),
        users: List.from(entry.value.users),
        userHosts: Map<String, String>.from(entry.value.userHosts), // Copiar el mapa de hosts
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
