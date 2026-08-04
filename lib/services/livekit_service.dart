import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as lk;
import '../config/debug_config.dart';
import '../models/video_report.dart';
import 'background_blur_processor.dart';
import 'video_conference_service.dart';

class _RoomInfo {
  final bool hasPassword;
  final bool hasOwner;
  final String? owner;
  _RoomInfo({required this.hasPassword, required this.hasOwner, this.owner});
}

class LiveKitService extends VideoConferenceService {
  static final LiveKitService _instance = LiveKitService._internal();
  factory LiveKitService() => _instance;
  LiveKitService._internal() : super.internal();

  lk.Room? _room;
  lk.Room? get room => _room;
  lk.LocalParticipant? get localParticipant => _room?.localParticipant;
  lk.CancelListenFunc? _roomEventSub;

  String? _serverUrl;
  String? _tokenEndpoint;

  bool _isOwner = false;
  bool get isOwner => _isOwner;

  bool _defaultMute = false;
  bool get defaultMute => _defaultMute;

  BackgroundBlurProcessor? _blurProcessor;
  bool get isBackgroundBlurEnabled => _blurProcessor != null;

  bool get isConnected => _room?.connectionState == lk.ConnectionState.connected;

  void configure({String? serverUrl, String? tokenEndpoint}) {
    _serverUrl = serverUrl;
    _tokenEndpoint = tokenEndpoint;
  }

  String get _baseEndpoint {
    final ep = _tokenEndpoint;
    if (ep == null) return '';
    final uri = Uri.parse(ep);
    return '${uri.scheme}://${uri.host}${uri.port == 80 || uri.port == 443 ? '' : ':${uri.port}'}';
  }

  Future<String?> _requestToken(
    String roomName,
    String identity, {
    bool isOwner = false,
    String? password,
  }) async {
    final endpoint = _tokenEndpoint;
    if (endpoint == null) return null;

    try {
      final body = <String, dynamic>{
        'room': roomName,
        'identity': identity,
        'isOwner': isOwner,
      };
      if (password != null) body['password'] = password;

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _defaultMute = data['defaultMute'] == true;
        return data['token'] as String?;
      }
      if (response.statusCode == 403) {
        debugLog('❌ [LiveKit] Token rejected: invalid password');
        return '__PASSWORD_REQUIRED__';
      }
    } catch (e) {
      debugLog('❌ [LiveKit] Error getting token: $e');
    }
    return null;
  }

  Future<_RoomInfo?> getRoomInfo(String roomName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/check-room'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room': roomName}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _RoomInfo(
          hasPassword: data['hasPassword'] as bool,
          hasOwner: data['hasOwner'] as bool,
          owner: data['owner'] as String?,
        );
      }
    } catch (e) {
      debugLog('❌ [LiveKit] Error checking room: $e');
    }
    return null;
  }

  Future<bool> connectToRoom(String roomName, String identity, {bool isOwner = false, String? password}) async {
    if (_serverUrl == null) return false;
    if (isConnected) return true;

    try {
      final token = await _requestToken(roomName, identity, isOwner: isOwner, password: password);
      if (token == null) return false;
      if (token == '__PASSWORD_REQUIRED__') return false;

      final connectOpts = lk.ConnectOptions(
        autoSubscribe: true,
      );

      final e2ee = await lk.E2EEOptions.sharedKey('globalchat-e2e-$roomName');

      _room = lk.Room(
        roomOptions: lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          e2eeOptions: e2ee,
        ),
      );

      _roomEventSub = _room!.events.listen(_onRoomEvent);

      await _room!.connect(
        _serverUrl!,
        token,
        connectOptions: connectOpts,
      );

      _isOwner = isOwner;
      addUserToVideo(identity, ConferenceType.channel, roomName);

      activeConferencesMap[roomName] = ConferenceInfo(
        id: roomName,
        channel: roomName,
        roomName: roomName,
        participants: _room!.remoteParticipants.values
            .map((p) => p.identity)
            .toList(),
        isModerated: isOwner,
        moderatorNick: isOwner ? identity : null,
      );

      conferenceStartedController.add(activeConferencesMap[roomName]!);
      return true;
    } catch (e) {
      debugLog('❌ [LiveKit] Connection error: $e');
      return false;
    }
  }

  void _onRoomEvent(lk.RoomEvent event) {
    if (event is lk.ParticipantConnectedEvent) {
      final identity = event.participant.identity;
      if (identity != null) {
        addUserToVideo(identity, ConferenceType.channel, _room?.name ?? '');
      }
    } else if (event is lk.ParticipantDisconnectedEvent) {
      final identity = event.participant.identity;
      if (identity != null) {
        removeUserFromVideo(identity);
      }
    }
  }

  Future<void> disconnectFromRoom() async {
    if (_room?.localParticipant?.identity case final identity?) {
      removeUserFromVideo(identity);
    }
    await _room?.disconnect();
    final cb = _roomEventSub;
    if (cb != null) await cb();
    _roomEventSub = null;
    _room = null;
    _isOwner = false;
  }

  @override
  Future<String?> startChannelConference({
    required String channel,
    required String userNick,
    dynamic userProfile,
    bool? audioOnly,
    bool isOwner = true,
    String? password,
    String? roomName,
  }) async {
    roomName ??= 'channel_${channel.replaceAll('#', '')}_${DateTime.now().millisecondsSinceEpoch}';
    if (password != null) {
      await setRoomPassword(roomName, password, identity: userNick);
    }
    final connected = await connectToRoom(roomName, userNick, isOwner: isOwner, password: password);
    return connected ? roomName : null;
  }

  @override
  Future<void> joinConference({
    required String roomName,
    required String userNick,
    required ConferenceType type,
    dynamic userProfile,
    bool? audioOnly,
  }) async {
    await connectToRoom(roomName, userNick);
  }

  Future<bool> joinConferenceWithPassword({
    required String roomName,
    required String userNick,
    String? password,
    ConferenceType type = ConferenceType.channel,
    bool? audioOnly,
  }) async {
    final connected = await connectToRoom(roomName, userNick, password: password);
    return connected;
  }

  @override
  Future<void> leaveConference() async {
    await disconnectFromRoom();
    conferenceEndedController.add('left');
  }

  Future<bool> hasRoomPassword(String roomName) async {
    final info = await getRoomInfo(roomName);
    return info?.hasPassword ?? false;
  }

  Future<bool> setRoomPassword(String room, String password, {required String identity}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/set-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room': room, 'password': password, 'identity': identity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugLog('❌ [LiveKit] Error setting password: $e');
      return false;
    }
  }

  Future<bool> removeRoomPassword(String room, {required String identity}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/set-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room': room, 'password': '', 'identity': identity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugLog('❌ [LiveKit] Error removing password: $e');
      return false;
    }
  }

  Future<bool> setDefaultMute(String room, bool defaultMute, {required String identity}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/admin/set-default-mute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room': room, 'identity': identity, 'defaultMute': defaultMute}),
      );
      if (response.statusCode == 200) {
        _defaultMute = defaultMute;
        return true;
      }
      return false;
    } catch (e) {
      debugLog('❌ [LiveKit] Error setting default mute: $e');
      return false;
    }
  }

  Future<bool> endRoomForAll(String room) async {
    if (!_isOwner) return false;
    final localIdentity = _room?.localParticipant?.identity;
    if (localIdentity == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/admin/end-room'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room': room, 'identity': localIdentity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugLog('❌ [LiveKit] Error ending room: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getNetworkStats() async {
    final stats = <String, dynamic>{};
    try {
      final publisher = _room?.engine.publisher;
      final subscriber = _room?.engine.subscriber;
      if (publisher != null) {
        final reports = await publisher.pc.getStats();
        for (final r in reports) {
          final values = r.values;
          if (values['type'] == 'candidate-pair' && values['state'] == 'succeeded') {
            final rtt = values['currentRoundTripTime'];
            if (rtt != null) stats['pubRtt'] = (rtt as num).toDouble();
          }
          if (values['type'] == 'remote-inbound-rtp') {
            final jitter = values['jitter'];
            final packetsLost = values['packetsLost'];
            if (jitter != null) stats['pubJitter'] = (jitter as num).toDouble();
            if (packetsLost != null) stats['pubPacketsLost'] = packetsLost as int;
          }
        }
      }
      if (subscriber != null) {
        final reports = await subscriber.pc.getStats();
        for (final r in reports) {
          final values = r.values;
          if (values['type'] == 'candidate-pair' && values['state'] == 'succeeded') {
            final rtt = values['currentRoundTripTime'];
            if (rtt != null) stats['subRtt'] = (rtt as num).toDouble();
          }
          if (values['type'] == 'inbound-rtp') {
            final jitter = values['jitter'];
            final packetsLost = values['packetsLost'];
            if (jitter != null) stats['subJitter'] = (jitter as num).toDouble();
            if (packetsLost != null) stats['subPacketsLost'] = packetsLost as int;
          }
        }
      }
    } catch (e) {
      debugLog('❌ [LiveKit] Error getting stats: $e');
    }
    return stats;
  }

  Future<bool> toggleBackgroundBlur() async {
    final videoPub = _room?.localParticipant?.videoTrackPublications.firstOrNull;
    final videoTrack = videoPub?.track as lk.LocalVideoTrack?;
    if (videoTrack == null) return false;

    try {
      if (_blurProcessor != null) {
        await videoTrack.stopProcessor();
        _blurProcessor = null;
        return false;
      } else {
        _blurProcessor = BackgroundBlurProcessor();
        await videoTrack.setProcessor(_blurProcessor);
        return true;
      }
    } catch (e) {
      debugLog('❌ [LiveKit] Error toggling background blur: $e');
      _blurProcessor = null;
      return false;
    }
  }

  Future<bool> kickParticipant(String room, String targetIdentity) async {
    if (!_isOwner) return false;
    final localIdentity = _room?.localParticipant?.identity;
    if (localIdentity == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/admin/kick'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room': room, 'identity': localIdentity, 'targetIdentity': targetIdentity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugLog('❌ [LiveKit] Error kicking participant: $e');
      return false;
    }
  }

  Future<bool> banParticipant(String room, String targetIdentity) async {
    if (!_isOwner) return false;
    final localIdentity = _room?.localParticipant?.identity;
    if (localIdentity == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/admin/ban'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room': room, 'identity': localIdentity, 'targetIdentity': targetIdentity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugLog('❌ [LiveKit] Error banning participant: $e');
      return false;
    }
  }

  Future<List<String>> listBans(String room) async {
    if (!_isOwner) return [];
    try {
      final response = await http.get(
        Uri.parse('$_baseEndpoint/admin/bans?room=$room'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['bans'] as List?)?.cast<String>() ?? [];
      }
    } catch (e) {
      debugLog('❌ [LiveKit] Error listing bans: $e');
    }
    return [];
  }

  Future<bool> unbanParticipant(String room, String targetIdentity) async {
    if (!_isOwner) return false;
    final localIdentity = _room?.localParticipant?.identity;
    if (localIdentity == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/admin/unban'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'room': room, 'identity': localIdentity, 'targetIdentity': targetIdentity}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugLog('❌ [LiveKit] Error unbanning participant: $e');
      return false;
    }
  }

  Future<bool> muteParticipant(String room, String targetIdentity, String trackSid, {bool muted = true}) async {
    if (!_isOwner) return false;
    final localIdentity = _room?.localParticipant?.identity;
    if (localIdentity == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$_baseEndpoint/admin/mute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room': room,
          'identity': localIdentity,
          'targetIdentity': targetIdentity,
          'trackSid': trackSid,
          'muted': muted,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugLog('❌ [LiveKit] Error muting participant: $e');
      return false;
    }
  }

  @override
  UserVideoStatus? getUserVideoStatus(String nick) {
    if (_room?.localParticipant?.identity == nick) {
      return UserVideoStatus(
        nick: nick,
        type: ConferenceType.channel,
        conferenceId: _room!.name ?? '',
      );
    }
    final participant = _room?.remoteParticipants.values
        .where((p) => p.identity == nick)
        .firstOrNull;
    if (participant != null) {
      return UserVideoStatus(
        nick: nick,
        type: ConferenceType.channel,
        conferenceId: _room!.name ?? '',
      );
    }
    return null;
  }

  @override
  bool isUserInVideo(String nick) =>
      getUserVideoStatus(nick) != null || super.isUserInVideo(nick);

  @override
  Future<void> dispose() async {
    await disconnectFromRoom();
    await conferenceStartedController.close();
    await conferenceEndedController.close();
    await reportCreatedController.close();
    await usersVideoStatusController.close();
  }
}
