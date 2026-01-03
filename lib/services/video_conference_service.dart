import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:uuid/uuid.dart';
import '../models/user_role.dart';
import '../models/video_report.dart';

/// Tipo de conferencia
enum ConferenceType {
  channel,  // Conferencia de canal (grupal)
  private,  // Videollamada privada (1 a 1)
}

/// Estado de usuario en videoconferencia
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
        return '🎥'; // Conferencia grupal
      case ConferenceType.private:
        return '📹'; // Videollamada privada
    }
  }
}

/// Información de conferencia activa
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

/// Servicio de videoconferencias
class VideoConferenceService {
  final JitsiMeet _jitsiMeet = JitsiMeet();
  
  // Conferencias activas
  final Map<String, ConferenceInfo> _activeConferences = {};
  
  // Estado de usuarios en videoconferencia (nick -> UserVideoStatus)
  final Map<String, UserVideoStatus> _usersInVideo = {};
  
  // Reportes pendientes
  final List<VideoReport> _reports = [];
  
  // Acciones de moderación
  final List<ModerationAction> _moderationActions = [];
  
  // Listeners
  final StreamController<ConferenceInfo> _conferenceStartedController = 
      StreamController<ConferenceInfo>.broadcast();
  final StreamController<String> _conferenceEndedController = 
      StreamController<String>.broadcast();
  final StreamController<VideoReport> _reportCreatedController = 
      StreamController<VideoReport>.broadcast();
  final StreamController<Map<String, UserVideoStatus>> _usersVideoStatusController =
      StreamController<Map<String, UserVideoStatus>>.broadcast();
      
  Stream<ConferenceInfo> get onConferenceStarted => _conferenceStartedController.stream;
  Stream<String> get onConferenceEnded => _conferenceEndedController.stream;
  Stream<VideoReport> get onReportCreated => _reportCreatedController.stream;
  Stream<Map<String, UserVideoStatus>> get onUsersVideoStatusChanged => _usersVideoStatusController.stream;
  
  /// Obtener conferencias activas
  List<ConferenceInfo> get activeConferences => _activeConferences.values.toList();
  
  /// Obtener reportes pendientes
  List<VideoReport> get pendingReports => 
      _reports.where((r) => r.status == ReportStatus.pending).toList();
  
  /// Obtener estado de video de un usuario
  UserVideoStatus? getUserVideoStatus(String nick) => _usersInVideo[nick];
  
  /// Verificar si un usuario está en videoconferencia
  bool isUserInVideo(String nick) => _usersInVideo.containsKey(nick);
  
  /// Obtener todos los usuarios en video
  Map<String, UserVideoStatus> get usersInVideo => Map.unmodifiable(_usersInVideo);
  
  /// Agregar usuario a videoconferencia
  void _addUserToVideo(String nick, ConferenceType type, String conferenceId) {
    _usersInVideo[nick] = UserVideoStatus(
      nick: nick,
      type: type,
      conferenceId: conferenceId,
    );
    _usersVideoStatusController.add(Map.from(_usersInVideo));
    print('🎥 [VIDEO] Usuario $nick entró en conferencia ${type == ConferenceType.channel ? 'grupal' : 'privada'}');
  }
  
  /// Remover usuario de videoconferencia
  void _removeUserFromVideo(String nick) {
    if (_usersInVideo.remove(nick) != null) {
      _usersVideoStatusController.add(Map.from(_usersInVideo));
      print('🎥 [VIDEO] Usuario $nick salió de conferencia');
    }
  }
  
  /// Generar nombre de sala único
  String _generateRoomName(String channel, {bool isPrivate = false}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (isPrivate) {
      return 'globalchat-private-$timestamp';
    }
    final cleanChannel = channel.replaceAll('#', '').replaceAll(' ', '-');
    return 'globalchat-$cleanChannel-$timestamp';
  }
  
  /// Iniciar conferencia en canal
  /// Retorna el nombre de la sala (roomName) para construir la URL
  Future<String> startChannelConference({
    required String channel,
    required String userNick,
    required UserProfile userProfile,
    bool audioOnly = false,
  }) async {
    try {
      print('🎥 [VIDEO] Iniciando conferencia en canal: $channel');
      
      // Verificar permisos básicos (los moderadores del canal ya fueron verificados en chat_screen)
      // Solo verificar que no esté baneado o restringido
      if (userProfile.role == UserRole.banned || userProfile.role == UserRole.restricted) {
        throw Exception('No tienes permisos para iniciar conferencias');
      }
      
      // Verificar términos aceptados
      if (!userProfile.hasAcceptedVideoTerms) {
        throw Exception('Debes aceptar los términos de videoconferencia primero');
      }
      
      // Generar sala
      final roomName = _generateRoomName(channel);
      
      // Crear info de conferencia
      final conferenceInfo = ConferenceInfo(
        id: roomName,
        channel: channel,
        roomName: roomName,
        participants: [userNick],
        isModerated: true, // Siempre moderadas por defecto
        moderatorNick: userProfile.role.canModerate ? userNick : null,
      );
      
      // Guardar conferencia activa
      _activeConferences[roomName] = conferenceInfo;
      _conferenceStartedController.add(conferenceInfo);
      
      // Agregar usuario al estado de video
      _addUserToVideo(userNick, ConferenceType.channel, roomName);
      
      // Configurar opciones
      final options = JitsiMeetConferenceOptions(
        serverURL: 'https://meet.jit.si',
        room: roomName,
        configOverrides: {
          'startWithAudioMuted': false,
          'startWithVideoMuted': audioOnly, // Desactivar video si es solo audio
          'subject': audioOnly ? 'Audioconferencia: $channel' : 'Conferencia: $channel',
          'hideConferenceSubject': false,
        },
        featureFlags: {
          // Características básicas
          'chat.enabled': true,
          'invite.enabled': false,
          'calendar.enabled': false,
          'call-integration.enabled': false,
          
          // Seguridad y moderación
          'security-options.enabled': true,
          'lobby-mode.enabled': true,  // Sala de espera activada
          'prejoinpage.enabled': true, // Página de pre-unión
          
          // Moderación (si es moderador)
          'kick-out.enabled': userProfile.role.canModerate,
          'mute-everyone.enabled': userProfile.role.canModerate,
          'video-mute.enabled': userProfile.role.canModerate,
          'recording.enabled': userProfile.role.canRecord,
          
          // Restricciones de video para usuarios nuevos
          'video-share.enabled': userProfile.canEnableVideo,
          
          // UI
          'tile-view.enabled': true,
          'toolbox.alwaysVisible': false,
          'filmstrip.enabled': true,
          'raise-hand.enabled': true,
          'reactions.enabled': true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: userNick,
          email: '', // Opcional
        ),
      );
      
      // Listener de eventos de Jitsi
      var listener = JitsiMeetEventListener(
        conferenceJoined: (url) {
          print('🎥 [VIDEO] Usuario unido a conferencia: $url');
        },
        conferenceTerminated: (url, error) {
          print('🎥 [VIDEO] Conferencia terminada: $url');
          _activeConferences.remove(roomName);
          _conferenceEndedController.add(roomName);
          // Remover usuario del estado de video
          _removeUserFromVideo(userNick);
        },
        participantJoined: (email, name, role, participantId) {
          final participantName = name ?? 'Unknown';
          print('🎥 [VIDEO] Participante unido: $participantName');
          // Actualizar lista de participantes
          if (!conferenceInfo.participants.contains(participantName)) {
            final updated = conferenceInfo.copyWith(
              participants: [...conferenceInfo.participants, participantName],
            );
            _activeConferences[roomName] = updated;
          }
        },
        participantLeft: (participantId) {
          print('🎥 [VIDEO] Participante salió: $participantId');
        },
      );
      
      // Nota: addEventListeners no disponible en esta versión del SDK
      // Los eventos se manejan directamente en las opciones de configuración
      
      // Unirse a la conferencia
      await _jitsiMeet.join(options);
      
      print('✅ [VIDEO] Conferencia iniciada exitosamente');
      
      // Devolver el roomName para construir la URL
      return roomName;
      
    } catch (e) {
      print('❌ [VIDEO] Error al iniciar conferencia: $e');
      rethrow;
    }
  }
  
  /// Unirse a conferencia existente
  Future<void> joinConference({
    required String roomName,
    required String userNick,
    required UserProfile userProfile,
    ConferenceType type = ConferenceType.channel, // Por defecto canal
    bool audioOnly = false,
  }) async {
    try {
      print('🎥 [VIDEO] Uniéndose a conferencia: $roomName');
      
      // Verificar permisos
      if (!userProfile.canEnableVideo) {
        final reason = userProfile.videoRestrictionReason;
        throw Exception(reason ?? 'No puedes usar videoconferencias');
      }
      
      // Verificar términos aceptados
      if (!userProfile.hasAcceptedVideoTerms) {
        throw Exception('Debes aceptar los términos de videoconferencia primero');
      }
      
      // Agregar usuario al estado de video
      _addUserToVideo(userNick, type, roomName);
      
      // Configurar opciones (similar a startChannelConference)
      final options = JitsiMeetConferenceOptions(
        serverURL: 'https://meet.jit.si',
        room: roomName,
        configOverrides: {
          'startWithAudioMuted': false,
          'startWithVideoMuted': audioOnly || !userProfile.canEnableVideo, // Desactivar video si es solo audio
          'hideConferenceSubject': false,
        },
        featureFlags: {
          'chat.enabled': true,
          'security-options.enabled': true,
          'lobby-mode.enabled': true,
          'video-share.enabled': userProfile.canEnableVideo,
          'tile-view.enabled': true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: userNick,
        ),
      );
      
      // Nota: Event listeners no disponibles en esta versión del SDK
      // La limpieza de usuarios se hará de forma diferente
      
      // Unirse
      await _jitsiMeet.join(options);
      
      print('✅ [VIDEO] Unido a conferencia exitosamente');
      
    } catch (e) {
      print('❌ [VIDEO] Error al unirse a conferencia: $e');
      _removeUserFromVideo(userNick); // Remover en caso de error
      rethrow;
    }
  }
  
  /// Crear reporte de comportamiento inapropiado
  Future<VideoReport> createReport({
    required String conferenceId,
    required String channel,
    required String reporterNick,
    required String reportedNick,
    required ReportType type,
    required String description,
  }) async {
    try {
      final report = VideoReport(
        conferenceId: conferenceId,
        channel: channel,
        reporterNick: reporterNick,
        reportedNick: reportedNick,
        type: type,
        description: description,
      );
      
      _reports.add(report);
      _reportCreatedController.add(report);
      
      print('⚠️ [VIDEO] Reporte creado: ${report.id}');
      print('   Reportado: $reportedNick');
      print('   Tipo: ${type.description}');
      
      // Si tiene 3 o más reportes, acción automática
      final userReports = _reports.where((r) => r.reportedNick == reportedNick).length;
      if (userReports >= 3) {
        print('🚫 [VIDEO] Usuario $reportedNick tiene $userReports reportes - Acción automática requerida');
        // TODO: Implementar acción automática (expulsión)
      }
      
      return report;
      
    } catch (e) {
      print('❌ [VIDEO] Error al crear reporte: $e');
      rethrow;
    }
  }
  
  /// Revisar reporte (moderador)
  Future<void> reviewReport({
    required String reportId,
    required String reviewerNick,
    required String actionTaken,
    required ReportStatus newStatus,
  }) async {
    try {
      final reportIndex = _reports.indexWhere((r) => r.id == reportId);
      if (reportIndex == -1) {
        throw Exception('Reporte no encontrado');
      }
      
      final report = _reports[reportIndex];
      final updatedReport = report.copyWith(
        status: newStatus,
        reviewerNick: reviewerNick,
        actionTaken: actionTaken,
        reviewedAt: DateTime.now(),
      );
      
      _reports[reportIndex] = updatedReport;
      
      print('✅ [VIDEO] Reporte revisado: $reportId');
      print('   Acción: $actionTaken');
      
    } catch (e) {
      print('❌ [VIDEO] Error al revisar reporte: $e');
      rethrow;
    }
  }
  
  /// Obtener estadísticas de reportes de un usuario
  Map<String, dynamic> getUserReportStats(String nick) {
    final userReports = _reports.where((r) => r.reportedNick == nick).toList();
    final pendingReports = userReports.where((r) => r.status == ReportStatus.pending).length;
    final resolvedReports = userReports.where((r) => r.status == ReportStatus.resolved).length;
    
    return {
      'total': userReports.length,
      'pending': pendingReports,
      'resolved': resolvedReports,
      'dismissed': userReports.length - pendingReports - resolvedReports,
    };
  }
  
  /// Registrar acción de moderación
  void logModerationAction({
    required String moderatorNick,
    required String targetNick,
    required String conferenceId,
    required String action,
    required String reason,
    String channel = 'N/A',
  }) {
    final moderationAction = ModerationAction(
      id: const Uuid().v4(),
      moderatorNick: moderatorNick,
      targetNick: targetNick,
      conferenceId: conferenceId,
      channel: channel,
      action: action,
      reason: reason,
      timestamp: DateTime.now(),
    );
    
    _moderationActions.add(moderationAction);
    print('👮 [VIDEO] Acción de moderación: $action por $moderatorNick a $targetNick');
  }
  
  /// Obtener acciones de moderación
  List<ModerationAction> get moderationActions => List.unmodifiable(_moderationActions);
  
  /// Limpiar recursos
  void dispose() {
    _conferenceStartedController.close();
    _conferenceEndedController.close();
    _reportCreatedController.close();
    _usersVideoStatusController.close();
  }
}

