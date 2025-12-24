import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_conference_service.dart';
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

