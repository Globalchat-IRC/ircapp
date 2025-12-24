/// Tipo de reporte de videoconferencia
enum ReportType {
  inappropriateContent,  // Contenido sexual/desnudos
  harassment,            // Acoso
  spam,                  // Spam
  violence,              // Violencia
  other,                 // Otro
}

extension ReportTypeExtension on ReportType {
  String get description {
    switch (this) {
      case ReportType.inappropriateContent:
        return 'Contenido inapropiado (sexual/desnudos)';
      case ReportType.harassment:
        return 'Acoso o comportamiento abusivo';
      case ReportType.spam:
        return 'Spam o publicidad no deseada';
      case ReportType.violence:
        return 'Violencia o amenazas';
      case ReportType.other:
        return 'Otro';
    }
  }
  
  String get emoji {
    switch (this) {
      case ReportType.inappropriateContent:
        return '🔞';
      case ReportType.harassment:
        return '⚠️';
      case ReportType.spam:
        return '📢';
      case ReportType.violence:
        return '⚔️';
      case ReportType.other:
        return '❓';
    }
  }
}

/// Estado del reporte
enum ReportStatus {
  pending,    // Pendiente de revisión
  reviewing,  // En revisión
  resolved,   // Resuelto (acción tomada)
  dismissed,  // Descartado (falso positivo)
}

/// Reporte de comportamiento inapropiado en videoconferencia
class VideoReport {
  final String id;
  final String conferenceId;
  final String channel;
  final String reporterNick;
  final String reportedNick;
  final ReportType type;
  final String description;
  final DateTime timestamp;
  final ReportStatus status;
  final String? reviewerNick;
  final String? actionTaken;
  final DateTime? reviewedAt;
  
  VideoReport({
    String? id,
    required this.conferenceId,
    required this.channel,
    required this.reporterNick,
    required this.reportedNick,
    required this.type,
    required this.description,
    DateTime? timestamp,
    this.status = ReportStatus.pending,
    this.reviewerNick,
    this.actionTaken,
    this.reviewedAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       timestamp = timestamp ?? DateTime.now();
  
  /// Copia con modificaciones
  VideoReport copyWith({
    String? id,
    String? conferenceId,
    String? channel,
    String? reporterNick,
    String? reportedNick,
    ReportType? type,
    String? description,
    DateTime? timestamp,
    ReportStatus? status,
    String? reviewerNick,
    String? actionTaken,
    DateTime? reviewedAt,
  }) {
    return VideoReport(
      id: id ?? this.id,
      conferenceId: conferenceId ?? this.conferenceId,
      channel: channel ?? this.channel,
      reporterNick: reporterNick ?? this.reporterNick,
      reportedNick: reportedNick ?? this.reportedNick,
      type: type ?? this.type,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      reviewerNick: reviewerNick ?? this.reviewerNick,
      actionTaken: actionTaken ?? this.actionTaken,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
  
  /// Convertir a mapa
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conferenceId': conferenceId,
      'channel': channel,
      'reporterNick': reporterNick,
      'reportedNick': reportedNick,
      'type': type.name,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'reviewerNick': reviewerNick,
      'actionTaken': actionTaken,
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }
  
  /// Crear desde mapa
  factory VideoReport.fromMap(Map<String, dynamic> map) {
    return VideoReport(
      id: map['id'],
      conferenceId: map['conferenceId'],
      channel: map['channel'],
      reporterNick: map['reporterNick'],
      reportedNick: map['reportedNick'],
      type: ReportType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ReportType.other,
      ),
      description: map['description'],
      timestamp: DateTime.parse(map['timestamp']),
      status: ReportStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ReportStatus.pending,
      ),
      reviewerNick: map['reviewerNick'],
      actionTaken: map['actionTaken'],
      reviewedAt: map['reviewedAt'] != null 
          ? DateTime.parse(map['reviewedAt']) 
          : null,
    );
  }
}

/// Log de acción de moderación
class ModerationAction {
  final String id;
  final String conferenceId;
  final String channel;
  final String moderatorNick;
  final String targetNick;
  final String action; // 'kick', 'ban', 'mute_video', 'mute_audio', 'warning'
  final String reason;
  final DateTime timestamp;
  final String? relatedReportId;
  
  ModerationAction({
    String? id,
    required this.conferenceId,
    required this.channel,
    required this.moderatorNick,
    required this.targetNick,
    required this.action,
    required this.reason,
    DateTime? timestamp,
    this.relatedReportId,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       timestamp = timestamp ?? DateTime.now();
  
  /// Convertir a mapa
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conferenceId': conferenceId,
      'channel': channel,
      'moderatorNick': moderatorNick,
      'targetNick': targetNick,
      'action': action,
      'reason': reason,
      'timestamp': timestamp.toIso8601String(),
      'relatedReportId': relatedReportId,
    };
  }
  
  /// Crear desde mapa
  factory ModerationAction.fromMap(Map<String, dynamic> map) {
    return ModerationAction(
      id: map['id'],
      conferenceId: map['conferenceId'],
      channel: map['channel'],
      moderatorNick: map['moderatorNick'],
      targetNick: map['targetNick'],
      action: map['action'],
      reason: map['reason'],
      timestamp: DateTime.parse(map['timestamp']),
      relatedReportId: map['relatedReportId'],
    );
  }
}

