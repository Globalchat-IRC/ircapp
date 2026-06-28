class QualiaRadioStatus {
  const QualiaRadioStatus({
    required this.ok,
    required this.fetchedAt,
    this.error,
    this.channel = '#QualiaRadio',
    this.djRoom = '#QualiaRadio-dj',
    this.stationName = 'Qualia Radio',
    this.stationDescription = '',
    this.listenUrl = '',
    this.publicPlayerUrl = '',
    this.requestsEnabled = false,
    this.isLive = false,
    this.liveLabel = 'Música automatizada',
    this.streamerName = '',
    this.nowPlayingDisplay = '',
    this.nowPlayingArtist = '',
    this.nowPlayingTitle = '',
    this.artUrl = '',
    this.playlist = '',
    this.isRequest = false,
    this.elapsedLabel,
    this.remainingLabel,
    this.nextDisplay,
    this.listenersCurrent = 0,
    this.listenersUnique = 0,
    this.bitrate,
    this.streamFormat = '',
    this.orionCommands = const [],
  });

  final bool ok;
  final int fetchedAt;
  final String? error;
  final String channel;
  final String djRoom;
  final String stationName;
  final String stationDescription;
  final String listenUrl;
  final String publicPlayerUrl;
  final bool requestsEnabled;
  final bool isLive;
  final String liveLabel;
  final String streamerName;
  final String nowPlayingDisplay;
  final String nowPlayingArtist;
  final String nowPlayingTitle;
  final String artUrl;
  final String playlist;
  final bool isRequest;
  final String? elapsedLabel;
  final String? remainingLabel;
  final String? nextDisplay;
  final int listenersCurrent;
  final int listenersUnique;
  final int? bitrate;
  final String streamFormat;
  final List<QualiaOrionCommand> orionCommands;

  factory QualiaRadioStatus.fromJson(Map<String, dynamic> json) {
    final station = json['station'] as Map<String, dynamic>? ?? {};
    final live = json['live'] as Map<String, dynamic>? ?? {};
    final now = json['now_playing'] as Map<String, dynamic>? ?? {};
    final next = json['playing_next'] as Map<String, dynamic>?;
    final listeners = json['listeners'] as Map<String, dynamic>? ?? {};
    final stream = json['stream'] as Map<String, dynamic>? ?? {};
    final orion = json['orion'] as Map<String, dynamic>? ?? {};
    final commands = (orion['commands'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(QualiaOrionCommand.fromJson)
        .toList();

    return QualiaRadioStatus(
      ok: json['ok'] == true,
      fetchedAt: (json['fetched_at'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
      channel: json['channel'] as String? ?? '#QualiaRadio',
      djRoom: json['dj_room'] as String? ?? '#QualiaRadio-dj',
      stationName: station['name'] as String? ?? 'Qualia Radio',
      stationDescription: station['description'] as String? ?? '',
      listenUrl: station['listen_url'] as String? ?? '',
      publicPlayerUrl: station['public_player_url'] as String? ?? '',
      requestsEnabled: station['requests_enabled'] == true,
      isLive: live['is_live'] == true,
      liveLabel: live['label'] as String? ?? 'Música automatizada',
      streamerName: live['streamer_name'] as String? ?? '',
      nowPlayingDisplay: now['display'] as String? ?? '',
      nowPlayingArtist: now['artist'] as String? ?? '',
      nowPlayingTitle: now['title'] as String? ?? '',
      artUrl: now['art_url'] as String? ?? '',
      playlist: now['playlist'] as String? ?? '',
      isRequest: now['is_request'] == true,
      elapsedLabel: now['elapsed_label'] as String?,
      remainingLabel: now['remaining_label'] as String?,
      nextDisplay: next?['display'] as String?,
      listenersCurrent: (listeners['current'] as num?)?.toInt() ?? 0,
      listenersUnique: (listeners['unique'] as num?)?.toInt() ?? 0,
      bitrate: (stream['bitrate'] as num?)?.toInt(),
      streamFormat: stream['format'] as String? ?? '',
      orionCommands: commands,
    );
  }
}

class QualiaOrionCommand {
  const QualiaOrionCommand({
    required this.command,
    required this.description,
  });

  final String command;
  final String description;

  factory QualiaOrionCommand.fromJson(Map<String, dynamic> json) {
    return QualiaOrionCommand(
      command: json['command'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}
