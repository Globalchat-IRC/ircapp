import 'dart:async';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/user_role.dart';
import '../models/video_report.dart';

/// Servicio de base de datos para videoconferencias
class VideoDatabaseService {
  static Database? _database;
  static final VideoDatabaseService instance = VideoDatabaseService._internal();
  
  VideoDatabaseService._internal();
  
  /// Obtener instancia de base de datos
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Inicializar base de datos
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'video_moderation.db');
    
    print('📁 [VIDEO-DB] Inicializando base de datos en: $path');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }
  
  /// Crear tablas
  Future<void> _createTables(Database db, int version) async {
    print('📊 [VIDEO-DB] Creando tablas...');
    
    // Tabla de perfiles de usuario
    await db.execute('''
      CREATE TABLE user_profiles (
        nick TEXT PRIMARY KEY,
        role TEXT NOT NULL,
        reputation INTEGER NOT NULL DEFAULT 50,
        has_accepted_video_terms INTEGER NOT NULL DEFAULT 0,
        email_verified INTEGER NOT NULL DEFAULT 0,
        phone_verified INTEGER NOT NULL DEFAULT 0,
        id_verified INTEGER NOT NULL DEFAULT 0,
        email TEXT,
        phone TEXT,
        registration_date TEXT NOT NULL,
        last_seen TEXT,
        total_conferences INTEGER NOT NULL DEFAULT 0,
        total_reports_received INTEGER NOT NULL DEFAULT 0,
        total_reports_made INTEGER NOT NULL DEFAULT 0,
        is_banned INTEGER NOT NULL DEFAULT 0,
        ban_reason TEXT,
        ban_expires_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Tabla de historial de reputación
    await db.execute('''
      CREATE TABLE reputation_history (
        id TEXT PRIMARY KEY,
        nick TEXT NOT NULL,
        old_reputation INTEGER NOT NULL,
        new_reputation INTEGER NOT NULL,
        change_amount INTEGER NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (nick) REFERENCES user_profiles (nick)
      )
    ''');
    
    // Tabla de verificaciones de email
    await db.execute('''
      CREATE TABLE email_verifications (
        id TEXT PRIMARY KEY,
        nick TEXT NOT NULL,
        email TEXT NOT NULL,
        verification_code TEXT NOT NULL,
        verified INTEGER NOT NULL DEFAULT 0,
        expires_at TEXT NOT NULL,
        verified_at TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (nick) REFERENCES user_profiles (nick)
      )
    ''');
    
    // Tabla de historial de conferencias
    await db.execute('''
      CREATE TABLE conferences_log (
        id TEXT PRIMARY KEY,
        channel TEXT NOT NULL,
        room_name TEXT NOT NULL,
        started_by TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        duration_seconds INTEGER,
        total_participants INTEGER NOT NULL DEFAULT 0,
        participants TEXT NOT NULL,
        was_moderated INTEGER NOT NULL DEFAULT 0,
        moderator_nick TEXT,
        total_kicks INTEGER NOT NULL DEFAULT 0,
        total_bans INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Tabla de acciones de moderación
    await db.execute('''
      CREATE TABLE moderation_actions (
        id TEXT PRIMARY KEY,
        moderator_nick TEXT NOT NULL,
        target_nick TEXT NOT NULL,
        conference_id TEXT,
        action TEXT NOT NULL,
        reason TEXT NOT NULL,
        evidence_url TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Tabla de reportes
    await db.execute('''
      CREATE TABLE video_reports (
        id TEXT PRIMARY KEY,
        reporter_nick TEXT NOT NULL,
        reported_nick TEXT NOT NULL,
        conference_id TEXT NOT NULL,
        report_type TEXT NOT NULL,
        description TEXT,
        evidence_url TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        resolved_by TEXT,
        resolved_at TEXT,
        resolution_notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Índices para mejorar rendimiento
    await db.execute('CREATE INDEX idx_user_nick ON user_profiles (nick)');
    await db.execute('CREATE INDEX idx_reputation ON user_profiles (reputation)');
    await db.execute('CREATE INDEX idx_conferences_channel ON conferences_log (channel)');
    await db.execute('CREATE INDEX idx_moderation_target ON moderation_actions (target_nick)');
    await db.execute('CREATE INDEX idx_reports_status ON video_reports (status)');
    
    print('✅ [VIDEO-DB] Tablas creadas exitosamente');
  }
  
  /// Actualizar tablas (para futuras versiones)
  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    print('🔄 [VIDEO-DB] Actualizando base de datos de v$oldVersion a v$newVersion');
    // Aquí se agregarían migraciones futuras
  }
  
  // ==================== PERFILES DE USUARIO ====================
  
  /// Crear o actualizar perfil de usuario
  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert(
      'user_profiles',
      {
        'nick': profile.nick,
        'role': profile.role.name,
        'reputation': profile.reputation,
        'has_accepted_video_terms': profile.hasAcceptedVideoTerms ? 1 : 0,
        'email_verified': profile.emailVerified ? 1 : 0,
        'phone_verified': profile.phoneVerified ? 1 : 0,
        'id_verified': profile.idVerified ? 1 : 0,
        'registration_date': profile.registrationDate?.toIso8601String() ?? now,
        'last_seen': now,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('💾 [VIDEO-DB] Perfil guardado: ${profile.nick} (Rep: ${profile.reputation})');
  }
  
  /// Obtener perfil de usuario
  Future<UserProfile?> getUserProfile(String nick) async {
    final db = await database;
    final results = await db.query(
      'user_profiles',
      where: 'nick = ?',
      whereArgs: [nick],
    );
    
    if (results.isEmpty) return null;
    
    final map = results.first;
    return UserProfile(
      nick: map['nick'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.user,
      ),
      reputation: map['reputation'] as int,
      hasAcceptedVideoTerms: (map['has_accepted_video_terms'] as int) == 1,
      emailVerified: (map['email_verified'] as int) == 1,
      phoneVerified: (map['phone_verified'] as int) == 1,
      idVerified: (map['id_verified'] as int) == 1,
      registrationDate: map['registration_date'] != null
          ? DateTime.parse(map['registration_date'] as String)
          : null,
    );
  }
  
  /// Actualizar reputación
  Future<void> updateReputation(String nick, int newReputation, String reason) async {
    final db = await database;
    final profile = await getUserProfile(nick);
    
    if (profile == null) {
      print('⚠️ [VIDEO-DB] No se encontró perfil para $nick');
      return;
    }
    
    final oldReputation = profile.reputation;
    final change = newReputation - oldReputation;
    
    // Limitar reputación entre 0 y 100
    final clampedReputation = newReputation.clamp(0, 100);
    
    // Actualizar perfil
    await db.update(
      'user_profiles',
      {
        'reputation': clampedReputation,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'nick = ?',
      whereArgs: [nick],
    );
    
    // Guardar en historial
    await db.insert('reputation_history', {
      'id': const Uuid().v4(),
      'nick': nick,
      'old_reputation': oldReputation,
      'new_reputation': clampedReputation,
      'change_amount': change,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    print('📊 [VIDEO-DB] Reputación actualizada: $nick $oldReputation → $clampedReputation ($reason)');
  }
  
  /// Incrementar reputación (buena acción)
  Future<void> increaseReputation(String nick, int amount, String reason) async {
    final profile = await getUserProfile(nick);
    if (profile != null) {
      await updateReputation(nick, profile.reputation + amount, reason);
    }
  }
  
  /// Decrementar reputación (mala acción)
  Future<void> decreaseReputation(String nick, int amount, String reason) async {
    final profile = await getUserProfile(nick);
    if (profile != null) {
      await updateReputation(nick, profile.reputation - amount, reason);
    }
  }
  
  /// Obtener historial de reputación
  Future<List<Map<String, dynamic>>> getReputationHistory(String nick, {int limit = 50}) async {
    final db = await database;
    return await db.query(
      'reputation_history',
      where: 'nick = ?',
      whereArgs: [nick],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
  
  /// Banear usuario
  Future<void> banUser(String nick, String reason, {DateTime? expiresAt}) async {
    final db = await database;
    await db.update(
      'user_profiles',
      {
        'is_banned': 1,
        'ban_reason': reason,
        'ban_expires_at': expiresAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'nick = ?',
      whereArgs: [nick],
    );
    
    // Bajar reputación a 0
    await updateReputation(nick, 0, 'Baneado: $reason');
    
    print('🚫 [VIDEO-DB] Usuario baneado: $nick (${expiresAt != null ? "temporal" : "permanente"})');
  }
  
  /// Desbanear usuario
  Future<void> unbanUser(String nick) async {
    final db = await database;
    await db.update(
      'user_profiles',
      {
        'is_banned': 0,
        'ban_reason': null,
        'ban_expires_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'nick = ?',
      whereArgs: [nick],
    );
    
    // Restaurar reputación a 50
    await updateReputation(nick, 50, 'Desbaneado');
    
    print('✅ [VIDEO-DB] Usuario desbaneado: $nick');
  }
  
  // ==================== VERIFICACIÓN DE EMAIL ====================
  
  /// Generar código de verificación
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); // 6 dígitos
  }
  
  /// Enviar código de verificación de email
  Future<String> sendEmailVerification(String nick, String email) async {
    final db = await database;
    final code = _generateVerificationCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));
    
    await db.insert('email_verifications', {
      'id': const Uuid().v4(),
      'nick': nick,
      'email': email,
      'verification_code': code,
      'verified': 0,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
    
    // TODO: Aquí se enviaría el email real
    print('📧 [VIDEO-DB] Código de verificación generado para $nick: $code');
    print('   Email: $email');
    print('   Expira: ${expiresAt.toLocal()}');
    
    return code;
  }
  
  /// Verificar código de email
  Future<bool> verifyEmailCode(String nick, String code) async {
    final db = await database;
    final now = DateTime.now();
    
    final results = await db.query(
      'email_verifications',
      where: 'nick = ? AND verification_code = ? AND verified = 0',
      whereArgs: [nick, code],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    
    if (results.isEmpty) {
      print('❌ [VIDEO-DB] Código inválido para $nick');
      return false;
    }
    
    final verification = results.first;
    final expiresAt = DateTime.parse(verification['expires_at'] as String);
    
    if (now.isAfter(expiresAt)) {
      print('⏰ [VIDEO-DB] Código expirado para $nick');
      return false;
    }
    
    // Marcar como verificado
    await db.update(
      'email_verifications',
      {
        'verified': 1,
        'verified_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [verification['id']],
    );
    
    // Actualizar perfil de usuario
    await db.update(
      'user_profiles',
      {
        'email_verified': 1,
        'email': verification['email'],
        'updated_at': now.toIso8601String(),
      },
      where: 'nick = ?',
      whereArgs: [nick],
    );
    
    // Aumentar reputación por verificar email
    await increaseReputation(nick, 10, 'Email verificado');
    
    print('✅ [VIDEO-DB] Email verificado para $nick');
    return true;
  }
  
  // ==================== CONFERENCIAS ====================
  
  /// Guardar conferencia
  Future<void> saveConference(Map<String, dynamic> conferenceData) async {
    final db = await database;
    await db.insert(
      'conferences_log',
      {
        ...conferenceData,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('💾 [VIDEO-DB] Conferencia guardada: ${conferenceData['id']}');
  }
  
  /// Finalizar conferencia
  Future<void> endConference(String conferenceId, DateTime endTime) async {
    final db = await database;
    final conference = await db.query(
      'conferences_log',
      where: 'id = ?',
      whereArgs: [conferenceId],
    );
    
    if (conference.isEmpty) return;
    
    final startTime = DateTime.parse(conference.first['start_time'] as String);
    final duration = endTime.difference(startTime).inSeconds;
    
    await db.update(
      'conferences_log',
      {
        'end_time': endTime.toIso8601String(),
        'duration_seconds': duration,
      },
      where: 'id = ?',
      whereArgs: [conferenceId],
    );
    
    print('⏱️ [VIDEO-DB] Conferencia finalizada: $conferenceId (${duration}s)');
  }
  
  /// Obtener historial de conferencias
  Future<List<Map<String, dynamic>>> getConferencesHistory({
    String? channel,
    String? nick,
    int limit = 50,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (channel != null) {
      whereClause = 'channel = ?';
      whereArgs.add(channel);
    } else if (nick != null) {
      whereClause = 'started_by = ? OR participants LIKE ?';
      whereArgs.addAll([nick, '%$nick%']);
    }
    
    return await db.query(
      'conferences_log',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'start_time DESC',
      limit: limit,
    );
  }
  
  // ==================== MODERACIÓN ====================
  
  /// Guardar acción de moderación
  Future<void> saveModerationAction(ModerationAction action) async {
    final db = await database;
    await db.insert('moderation_actions', {
      'id': action.id,
      'moderator_nick': action.moderatorNick,
      'target_nick': action.targetNick,
      'conference_id': action.conferenceId,
      'action': action.action,
      'reason': action.reason,
      'evidence_url': null, // Campo legacy, mantener para compatibilidad
      'created_at': action.timestamp.toIso8601String(),
    });
    
    print('💾 [VIDEO-DB] Acción de moderación guardada: ${action.action} por ${action.moderatorNick}');
  }
  
  /// Obtener historial de moderación
  Future<List<Map<String, dynamic>>> getModerationHistory({
    String? moderator,
    String? target,
    int limit = 100,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (moderator != null) {
      whereClause = 'moderator_nick = ?';
      whereArgs.add(moderator);
    } else if (target != null) {
      whereClause = 'target_nick = ?';
      whereArgs.add(target);
    }
    
    return await db.query(
      'moderation_actions',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
  
  // ==================== REPORTES ====================
  
  /// Guardar reporte
  Future<void> saveReport(VideoReport report) async {
    final db = await database;
    await db.insert('video_reports', {
      'id': report.id,
      'reporter_nick': report.reporterNick,
      'reported_nick': report.reportedNick,
      'conference_id': report.conferenceId,
      'report_type': report.type.name,
      'description': report.description,
      'evidence_url': null, // Campo legacy para compatibilidad
      'status': report.status.name,
      'created_at': report.timestamp.toIso8601String(),
    });
    
    // Decrementar reputación del reportado
    await decreaseReputation(report.reportedNick, 5, 'Reportado por ${report.type.name}');
    
    // Incrementar contador de reportes
    final dbUpdate = await database;
    await dbUpdate.execute('''
      UPDATE user_profiles 
      SET total_reports_received = total_reports_received + 1 
      WHERE nick = ?
    ''', [report.reportedNick]);
    
    await dbUpdate.execute('''
      UPDATE user_profiles 
      SET total_reports_made = total_reports_made + 1 
      WHERE nick = ?
    ''', [report.reporterNick]);
    
    print('💾 [VIDEO-DB] Reporte guardado: ${report.reportedNick} por ${report.type.name}');
  }
  
  /// Resolver reporte
  Future<void> resolveReport(String reportId, String resolvedBy, String notes) async {
    final db = await database;
    await db.update(
      'video_reports',
      {
        'status': ReportStatus.resolved.name,
        'resolved_by': resolvedBy,
        'resolved_at': DateTime.now().toIso8601String(),
        'resolution_notes': notes,
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
    
    print('✅ [VIDEO-DB] Reporte resuelto: $reportId por $resolvedBy');
  }
  
  /// Obtener reportes
  Future<List<Map<String, dynamic>>> getReports({
    ReportStatus? status,
    String? reportedNick,
    int limit = 100,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (status != null) {
      whereClause = 'status = ?';
      whereArgs.add(status.name);
    }
    
    if (reportedNick != null) {
      whereClause += whereClause.isNotEmpty ? ' AND ' : '';
      whereClause += 'reported_nick = ?';
      whereArgs.add(reportedNick);
    }
    
    return await db.query(
      'video_reports',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }
  
  // ==================== ESTADÍSTICAS ====================
  
  /// Obtener estadísticas globales
  Future<Map<String, dynamic>> getGlobalStats() async {
    final db = await database;
    
    final totalUsers = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM user_profiles'),
    ) ?? 0;
    
    final totalConferences = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM conferences_log'),
    ) ?? 0;
    
    final totalReports = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM video_reports'),
    ) ?? 0;
    
    final totalActions = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM moderation_actions'),
    ) ?? 0;
    
    final avgReputation = Sqflite.firstIntValue(
      await db.rawQuery('SELECT AVG(reputation) FROM user_profiles'),
    ) ?? 50;
    
    return {
      'totalUsers': totalUsers,
      'totalConferences': totalConferences,
      'totalReports': totalReports,
      'totalActions': totalActions,
      'avgReputation': avgReputation,
    };
  }
  
  /// Obtener top usuarios por reputación
  Future<List<Map<String, dynamic>>> getTopUsers({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'user_profiles',
      orderBy: 'reputation DESC',
      limit: limit,
    );
  }
  
  /// Limpiar base de datos (solo para testing)
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('user_profiles');
    await db.delete('reputation_history');
    await db.delete('email_verifications');
    await db.delete('conferences_log');
    await db.delete('moderation_actions');
    await db.delete('video_reports');
    print('🗑️ [VIDEO-DB] Base de datos limpiada');
  }
  
  /// Cerrar base de datos
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      print('🔒 [VIDEO-DB] Base de datos cerrada');
    }
  }
}

