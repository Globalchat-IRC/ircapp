import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_conference_service.dart';
import '../services/moderation_server.dart';
import '../models/user_role.dart';
import '../models/video_report.dart';

/// Provider del servicio de videoconferencias
final videoConferenceServiceProvider = Provider<VideoConferenceService>((ref) {
  return VideoConferenceService();
});

/// Provider del perfil de usuario actual
final currentUserProfileProvider = StateProvider<UserProfile?>((ref) {
  return null;
});

/// Provider de conferencias activas
final activeConferencesProvider = StreamProvider<List<ConferenceInfo>>((ref) {
  final service = ref.watch(videoConferenceServiceProvider);
  return service.onConferenceStarted.map((_) => service.activeConferences);
});

/// Provider de reportes pendientes
final pendingReportsProvider = StreamProvider<List<VideoReport>>((ref) {
  final service = ref.watch(videoConferenceServiceProvider);
  return service.onReportCreated.map((_) => service.pendingReports);
});

/// Provider para verificar si el usuario aceptó los términos
final hasAcceptedVideoTermsProvider = StateProvider<bool>((ref) {
  final userProfile = ref.watch(currentUserProfileProvider);
  return userProfile?.hasAcceptedVideoTerms ?? false;
});

/// Provider de usuarios en videoconferencia
final usersVideoStatusProvider = StreamProvider<Map<String, UserVideoStatus>>((ref) {
  final service = ref.watch(videoConferenceServiceProvider);
  return service.onUsersVideoStatusChanged;
});

/// Provider para obtener el emoji de video de un usuario
final userVideoEmojiProvider = Provider.family<String?, String>((ref, nick) {
  final service = ref.watch(videoConferenceServiceProvider);
  final status = service.getUserVideoStatus(nick);
  return status?.emoji;
});

/// Provider del servidor de moderación
final moderationServerProvider = Provider<ModerationServer>((ref) {
  final videoService = ref.watch(videoConferenceServiceProvider);
  final server = ModerationServer(videoService, port: 8765);
  
  // Iniciar servidor automáticamente
  server.start().then((_) {
    print('✅ [MOD-SERVER] Servidor iniciado automáticamente');
  }).catchError((error) {
    print('❌ [MOD-SERVER] Error al iniciar servidor: $error');
  });
  
  // Detener al dispose
  ref.onDispose(() {
    server.stop();
  });
  
  return server;
});

