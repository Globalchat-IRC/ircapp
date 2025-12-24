import 'dart:async';
import 'dart:math';
import '../services/irc_service.dart';
import '../services/video_database_service.dart';
import '../models/user_role.dart';

/// Servicio de sincronización de reputación con UnrealIRCd
class UnrealIRCdReputationSync {
  final IRCService _ircService;
  final VideoDatabaseService _dbService;
  
  // Cache de reputaciones IRC (nick -> reputation score)
  final Map<String, int> _ircReputations = {};
  
  // Timer para sincronización periódica
  Timer? _syncTimer;
  
  UnrealIRCdReputationSync(this._ircService, this._dbService);
  
  /// Iniciar sincronización automática
  void startAutoSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      syncAllUsers();
    });
    print('🔄 [REP-SYNC] Sincronización automática iniciada (cada ${interval.inMinutes} min)');
  }
  
  /// Detener sincronización automática
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('🛑 [REP-SYNC] Sincronización automática detenida');
  }
  
  /// Obtener reputación IRC de un usuario via WHOIS
  Future<int?> getIRCReputation(String nick) async {
    try {
      // Enviar comando WHOIS
      _ircService.sendWhois(nick);
      
      // Esperar respuesta (simplificado, en producción usar listeners)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Buscar en cache (se actualizaría desde el parser de mensajes IRC)
      return _ircReputations[nick];
      
    } catch (e) {
      print('❌ [REP-SYNC] Error al obtener reputación IRC de $nick: $e');
      return null;
    }
  }
  
  /// Actualizar cache de reputación IRC desde respuesta WHOIS
  void updateIRCReputationFromWHOIS(String nick, Map<String, dynamic> whoisData) {
    // UnrealIRCd envía reputation score en WHOIS extendido
    // Formato: :server 320 yournick targetnick :reputation score is 5000
    
    if (whoisData.containsKey('reputation')) {
      final repScore = whoisData['reputation'] as int;
      _ircReputations[nick] = repScore;
      print('📊 [REP-SYNC] Reputación IRC de $nick: $repScore/10000');
    }
  }
  
  /// Convertir reputación IRC (0-10000) a escala app (0-100)
  int convertIRCToAppReputation(int ircReputation) {
    // UnrealIRCd: 0-10000
    // App: 0-100
    // Fórmula: (ircRep / 10000) * 100
    return (ircReputation / 100).round().clamp(0, 100);
  }
  
  /// Convertir reputación app (0-100) a escala IRC (0-10000)
  int convertAppToIRCReputation(int appReputation) {
    // App: 0-100
    // UnrealIRCd: 0-10000
    // Fórmula: (appRep / 100) * 10000
    return (appReputation * 100).clamp(0, 10000);
  }
  
  /// Calcular reputación híbrida (IRC + Video)
  int calculateHybridReputation({
    required int ircReputation,
    required int videoReputation,
    double ircWeight = 0.4,
    double videoWeight = 0.6,
  }) {
    // Convertir IRC a escala 0-100
    final ircNormalized = convertIRCToAppReputation(ircReputation);
    
    // Calcular promedio ponderado
    final hybrid = (ircNormalized * ircWeight) + (videoReputation * videoWeight);
    
    return hybrid.round().clamp(0, 100);
  }
  
  /// Sincronizar reputación de un usuario específico
  Future<UserProfile?> syncUserReputation(String nick) async {
    try {
      // 1. Obtener reputación IRC
      final ircRep = await getIRCReputation(nick);
      
      // 2. Obtener perfil actual de la BD
      final profile = await _dbService.getUserProfile(nick);
      
      if (profile == null) {
        print('⚠️ [REP-SYNC] Perfil no encontrado para $nick');
        return null;
      }
      
      if (ircRep == null) {
        print('⚠️ [REP-SYNC] No se pudo obtener reputación IRC de $nick');
        return profile;
      }
      
      // 3. Calcular reputación híbrida
      final videoRep = profile.reputation;
      final hybridRep = calculateHybridReputation(
        ircReputation: ircRep,
        videoReputation: videoRep,
        ircWeight: 0.4,  // 40% peso IRC
        videoWeight: 0.6, // 60% peso Video (más importante)
      );
      
      // 4. Actualizar si hay cambio significativo (>5 puntos)
      if ((hybridRep - videoRep).abs() >= 5) {
        final reason = 'Sincronización con IRC (IRC: ${convertIRCToAppReputation(ircRep)}, Video: $videoRep)';
        await _dbService.updateReputation(nick, hybridRep, reason);
        
        print('✅ [REP-SYNC] $nick: $videoRep → $hybridRep (IRC: ${convertIRCToAppReputation(ircRep)})');
        
        // Devolver perfil actualizado
        return await _dbService.getUserProfile(nick);
      }
      
      return profile;
      
    } catch (e) {
      print('❌ [REP-SYNC] Error al sincronizar $nick: $e');
      return null;
    }
  }
  
  /// Sincronizar todos los usuarios del canal actual
  Future<void> syncAllUsers() async {
    try {
      // Obtener usuarios del canal actual
      final currentChannel = _ircService.currentChannel;
      if (currentChannel == null) {
        print('⚠️ [REP-SYNC] No hay canal actual');
        return;
      }
      
      final users = _ircService.channels[currentChannel]?.users ?? <String>[];
      print('🔄 [REP-SYNC] Sincronizando ${users.length} usuarios...');
      
      int synced = 0;
      for (final user in users) {
        final profile = await syncUserReputation(user);
        if (profile != null) {
          synced++;
        }
        
        // Pequeña pausa para no saturar el servidor
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      print('✅ [REP-SYNC] Sincronizados $synced/${users.length} usuarios');
      
    } catch (e) {
      print('❌ [REP-SYNC] Error en sincronización masiva: $e');
    }
  }
  
  /// Analizar factores IRC del usuario
  Future<Map<String, dynamic>> analyzeIRCFactors(String nick) async {
    try {
      // Enviar WHOIS para obtener información completa
      _ircService.sendWhois(nick); // Info completa
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // En producción, esto vendría del parser de WHOIS
      // Por ahora, retornar estructura de ejemplo
      return {
        'connected_time': 0, // Segundos conectado
        'idle_time': 0, // Segundos idle
        'channels': 0, // Número de canales
        'kicks_received': 0, // Kicks recibidos
        'is_ircop': false, // Es IRCop
        'is_registered': false, // Nick registrado
        'reputation_score': 0, // Score de UnrealIRCd
      };
      
    } catch (e) {
      print('❌ [REP-SYNC] Error al analizar factores IRC: $e');
      return {};
    }
  }
  
  /// Calcular bonificación/penalización basada en factores IRC
  int calculateIRCBonus(Map<String, dynamic> factors) {
    int bonus = 0;
    
    // Tiempo conectado (max +10)
    final connectedHours = (factors['connected_time'] ?? 0) / 3600;
    if (connectedHours > 100) {
      bonus += 10;
    } else if (connectedHours > 50) {
      bonus += 5;
    } else if (connectedHours > 10) {
      bonus += 2;
    }
    
    // Nick registrado (+5)
    if (factors['is_registered'] == true) {
      bonus += 5;
    }
    
    // IRCop (+15)
    if (factors['is_ircop'] == true) {
      bonus += 15;
    }
    
    // Muchos canales (+3)
    if ((factors['channels'] ?? 0) >= 5) {
      bonus += 3;
    }
    
    // Kicks recibidos (penalización)
    final kicks = factors['kicks_received'] ?? 0;
    if (kicks > 10) {
      bonus -= 20;
    } else if (kicks > 5) {
      bonus -= 10;
    } else if (kicks > 0) {
      bonus -= (kicks * 2) as int;
    }
    
    return bonus;
  }
  
  /// Aplicar bonificación IRC a la reputación actual
  Future<void> applyIRCBonus(String nick) async {
    try {
      final factors = await analyzeIRCFactors(nick);
      final bonus = calculateIRCBonus(factors);
      
      if (bonus != 0) {
        final profile = await _dbService.getUserProfile(nick);
        if (profile != null) {
          final newRep = (profile.reputation + bonus).clamp(0, 100);
          
          await _dbService.updateReputation(
            nick,
            newRep,
            'Bonificación IRC: ${bonus > 0 ? "+" : ""}$bonus puntos',
          );
          
          print('🎁 [REP-SYNC] Bonificación IRC para $nick: ${bonus > 0 ? "+" : ""}$bonus');
        }
      }
      
    } catch (e) {
      print('❌ [REP-SYNC] Error al aplicar bonificación IRC: $e');
    }
  }
  
  /// Obtener estadísticas de sincronización
  Map<String, dynamic> getSyncStats() {
    return {
      'cached_reputations': _ircReputations.length,
      'auto_sync_active': _syncTimer?.isActive ?? false,
      'irc_users': _ircReputations.keys.toList(),
    };
  }
  
  /// Limpiar cache
  void clearCache() {
    _ircReputations.clear();
    print('🗑️ [REP-SYNC] Cache limpiado');
  }
  
  /// Dispose
  void dispose() {
    stopAutoSync();
    clearCache();
  }
}

/// Extensión para IRCService para procesar reputación en WHOIS
extension IRCServiceReputationExtension on IRCService {
  /// Parser simulado de respuesta WHOIS con reputación
  /// En producción, esto iría en el parser principal de mensajes IRC
  Map<String, dynamic>? parseWHOISReputation(String rawMessage) {
    // Formato UnrealIRCd: :server 320 nick target :reputation score is 5000
    if (rawMessage.contains('320') && rawMessage.contains('reputation')) {
      final parts = rawMessage.split(':');
      if (parts.length >= 3) {
        final reputationPart = parts[2];
        final match = RegExp(r'reputation score is (\d+)').firstMatch(reputationPart);
        
        if (match != null) {
          final score = int.parse(match.group(1)!);
          return {
            'reputation': score,
            'timestamp': DateTime.now(),
          };
        }
      }
    }
    
    return null;
  }
}

