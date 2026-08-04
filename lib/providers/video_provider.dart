import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart' show StateProvider;
import '../services/video_conference_service.dart';
import '../services/livekit_service.dart';
import '../services/moderation_server.dart';
import '../services/video_database_service.dart';
import '../services/unrealircd_reputation_sync.dart';
import '../models/user_role.dart';
import '../models/video_report.dart';
import 'irc_provider.dart';
import '../utils/platform_utils.dart';

/// Provider del servicio de videoconferencias (LiveKit)
final videoConferenceServiceProvider = Provider<VideoConferenceService>((ref) {
  final livekit = LiveKitService();
  final serverUrl = const String.fromEnvironment(
    'LIVEKIT_WS_URL',
    defaultValue: 'wss://livekit.globalchat.org',
  );
  final tokenEndpoint = const String.fromEnvironment(
    'LIVEKIT_TOKEN_URL',
    defaultValue: 'https://livekit.globalchat.org/token',
  );
  livekit.configure(serverUrl: serverUrl, tokenEndpoint: tokenEndpoint);
  return livekit;
});

/// Provider del perfil de usuario actual
final currentUserProfileProvider = StateProvider<UserProfile?>((ref) => null);

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

/// Provider de version para forzar rebuild de badges en user list
final videoStatusVersionProvider = StateProvider<int>((ref) => 0);

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
  // No iniciar servidor en web (no soporta ServerSocket)
  if (PlatformUtils.isWeb) {
    // Retornar un servidor dummy que no hace nada
    return ModerationServer(ref.watch(videoConferenceServiceProvider), port: 8765);
  }
  
  final videoService = ref.watch(videoConferenceServiceProvider);
  final server = ModerationServer(videoService, port: 8765);
  
  // Iniciar servidor automáticamente (solo en nativo)
  server.start().then((_) {
    // print('✅ [MOD-SERVER] Servidor iniciado automáticamente');
  }).catchError((error) {
    // print('❌ [MOD-SERVER] Error al iniciar servidor: $error');
  });
  
  // Detener al dispose
  ref.onDispose(() {
    server.stop();
  });
  
  return server;
});

/// Provider del servicio de base de datos
final videoDatabaseProvider = Provider<VideoDatabaseService>((ref) {
  final db = VideoDatabaseService.instance;
  
  // Inicializar base de datos solo en nativo (sqflite no funciona en web)
  if (!PlatformUtils.isWeb) {
    db.database.then((_) {
      // print('✅ [VIDEO-DB] Base de datos inicializada');
    }).catchError((error) {
      // print('❌ [VIDEO-DB] Error al inicializar: $error');
    });
  } else {
    // print('ℹ️ [VIDEO-DB] Base de datos deshabilitada en web');
  }
  
  // Cerrar al dispose
  ref.onDispose(() {
    if (!PlatformUtils.isWeb) {
      db.close();
    }
  });
  
  return db;
});

/// Provider para video room pendiente desde deep link
final pendingVideoRoomProvider = StateProvider<String?>((ref) => null);

/// Provider del servicio de sincronización con UnrealIRCd
final unrealircdReputationSyncProvider = Provider<UnrealIRCdReputationSync>((ref) {
  final ircService = ref.watch(ircServiceProvider);
  final dbService = ref.watch(videoDatabaseProvider);
  
  final sync = UnrealIRCdReputationSync(ircService, dbService);
  
  // Iniciar sincronización automática cada 5 minutos
  sync.startAutoSync(interval: const Duration(minutes: 5));
  
  // print('✅ [REP-SYNC] Servicio de sincronización IRC iniciado');
  
  // Detener al dispose
  ref.onDispose(() {
    sync.dispose();
  });
  
  return sync;
});

