import 'dart:async';
import '../models/video_report.dart';
import '../models/user_role.dart';

enum ConferenceType { channel, private }

class UserVideoStatus {
  final String nick;
  final ConferenceType type;
  final String conferenceId;
  final DateTime joinedAt;

  UserVideoStatus({
    required this.nick,
    required this.type,
    required this.conferenceId,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();

  String get emoji {
    switch (type) {
      case ConferenceType.channel:
        return '🎥';
      case ConferenceType.private:
        return '📹';
    }
  }
}

class ConferenceInfo {
  final String id;
  final String channel;
  final String roomName;
  final List<String> participants;
  final DateTime startTime;
  final bool isModerated;
  final String? moderatorNick;

  ConferenceInfo({
    required this.id,
    required this.channel,
    required this.roomName,
    this.participants = const [],
    DateTime? startTime,
    this.isModerated = false,
    this.moderatorNick,
  }) : startTime = startTime ?? DateTime.now();

  ConferenceInfo copyWith({
    List<String>? participants,
    bool? isModerated,
    String? moderatorNick,
  }) {
    return ConferenceInfo(
      id: id,
      channel: channel,
      roomName: roomName,
      participants: participants ?? this.participants,
      startTime: startTime,
      isModerated: isModerated ?? this.isModerated,
      moderatorNick: moderatorNick ?? this.moderatorNick,
    );
  }
}

class VideoConferenceService {
  static final VideoConferenceService _instance =
      VideoConferenceService.internal();
  factory VideoConferenceService() => _instance;
  VideoConferenceService.internal();

  final Map<String, ConferenceInfo> _activeConferences = {};
  final Map<String, UserVideoStatus> _usersInVideo = {};
  final List<VideoReport> _reports = [];
  final List<ModerationAction> _moderationActions = [];

  final StreamController<ConferenceInfo> conferenceStartedController =
      StreamController<ConferenceInfo>.broadcast();
  final StreamController<String> conferenceEndedController =
      StreamController<String>.broadcast();
  final StreamController<VideoReport> reportCreatedController =
      StreamController<VideoReport>.broadcast();
  final StreamController<Map<String, UserVideoStatus>>
      usersVideoStatusController =
      StreamController<Map<String, UserVideoStatus>>.broadcast();

  Stream<ConferenceInfo> get onConferenceStarted =>
      conferenceStartedController.stream;
  Stream<String> get onConferenceEnded => conferenceEndedController.stream;
  Stream<VideoReport> get onReportCreated => reportCreatedController.stream;
  Stream<Map<String, UserVideoStatus>> get onUsersVideoStatusChanged =>
      usersVideoStatusController.stream;

  List<ConferenceInfo> get activeConferences =>
      _activeConferences.values.toList();
  List<VideoReport> get pendingReports =>
      _reports.where((r) => r.status == ReportStatus.pending).toList();

  UserVideoStatus? getUserVideoStatus(String nick) => _usersInVideo[nick];
  bool isUserInVideo(String nick) => _usersInVideo.containsKey(nick);
  Map<String, UserVideoStatus> get usersInVideo =>
      Map.unmodifiable(_usersInVideo);

  Map<String, ConferenceInfo> get activeConferencesMap => _activeConferences;
  Map<String, UserVideoStatus> get usersInVideoMap => _usersInVideo;
  List<VideoReport> get reports => _reports;

  void addUserToVideo(String nick, ConferenceType type, String conferenceId) {
    _usersInVideo[nick] = UserVideoStatus(
      nick: nick,
      type: type,
      conferenceId: conferenceId,
    );
    usersVideoStatusController.add(Map.from(_usersInVideo));
  }

  void removeUserFromVideo(String nick) {
    if (_usersInVideo.remove(nick) != null) {
      usersVideoStatusController.add(Map.from(_usersInVideo));
    }
  }

  Future<String?> startChannelConference({
    required String channel,
    required String userNick,
    dynamic userProfile,
    bool? audioOnly,
    bool isOwner = false,
    String? password,
    String? roomName,
  }) async => null;

  Future<void> joinConference({
    required String roomName,
    required String userNick,
    required ConferenceType type,
    dynamic userProfile,
    bool? audioOnly,
  }) async {}

  Future<void> leaveConference() async {}
  Future<void> dispose() async {}
}
