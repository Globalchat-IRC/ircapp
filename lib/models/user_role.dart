/// Roles de usuario para control de permisos
enum UserRole {
  admin,      // Control total del sistema
  moderator,  // Puede moderar conferencias y expulsar usuarios
  ircop,      // Privilegios IRC estándar
  verified,   // Usuario verificado (sin restricciones en video)
  user,       // Usuario normal (con restricciones iniciales)
  restricted, // Usuario con historial negativo
  banned,     // Baneado del sistema
}

/// Extensión para verificar permisos
extension UserRoleExtension on UserRole {
  /// Puede moderar videoconferencias
  bool get canModerate {
    return this == UserRole.admin || 
           this == UserRole.moderator || 
           this == UserRole.ircop;
  }
  
  /// Puede usar video sin restricciones
  bool get canUseVideo {
    return this == UserRole.admin || 
           this == UserRole.moderator || 
           this == UserRole.ircop || 
           this == UserRole.verified ||
           this == UserRole.user;
  }
  
  /// Puede iniciar conferencias
  bool get canStartConference {
    return this != UserRole.banned && this != UserRole.restricted;
  }
  
  /// Puede grabar conferencias
  bool get canRecord {
    return this == UserRole.admin || this == UserRole.moderator;
  }
  
  /// Descripción del rol
  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.moderator:
        return 'Moderador';
      case UserRole.ircop:
        return 'IRCop';
      case UserRole.verified:
        return 'Verificado';
      case UserRole.user:
        return 'Usuario';
      case UserRole.restricted:
        return 'Restringido';
      case UserRole.banned:
        return 'Baneado';
    }
  }
  
  /// Color asociado al rol
  int get color {
    switch (this) {
      case UserRole.admin:
        return 0xFFFF0000; // Rojo
      case UserRole.moderator:
        return 0xFF00AA00; // Verde
      case UserRole.ircop:
        return 0xFF0000FF; // Azul
      case UserRole.verified:
        return 0xFF00AAAA; // Cyan
      case UserRole.user:
        return 0xFF888888; // Gris
      case UserRole.restricted:
        return 0xFFFF8800; // Naranja
      case UserRole.banned:
        return 0xFF444444; // Gris oscuro
    }
  }
}

/// Perfil de usuario con información de moderación
class UserProfile {
  final String nick;
  final UserRole role;
  final bool emailVerified;
  final bool phoneVerified;
  final int reputation; // 0-100
  final DateTime registrationDate;
  final bool hasAcceptedVideoTerms;
  final int videoReportsCount;
  final List<String> videoWarnings;
  
  UserProfile({
    required this.nick,
    this.role = UserRole.user,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.reputation = 50,
    DateTime? registrationDate,
    this.hasAcceptedVideoTerms = false,
    this.videoReportsCount = 0,
    this.videoWarnings = const [],
  }) : registrationDate = registrationDate ?? DateTime.now();
  
  /// Días desde el registro
  int get daysRegistered {
    return DateTime.now().difference(registrationDate).inDays;
  }
  
  /// Puede activar video
  bool get canEnableVideo {
    // Usuarios baneados o con muchos reportes no pueden
    if (role == UserRole.banned || videoReportsCount >= 3) {
      return false;
    }
    
    // Usuarios restringidos necesitan esperar
    if (role == UserRole.restricted && daysRegistered < 30) {
      return false;
    }
    
    // Nuevos usuarios sin verificar: solo después de 7 días
    if (!emailVerified && daysRegistered < 7) {
      return false;
    }
    
    return role.canUseVideo;
  }
  
  /// Razón por la que no puede usar video
  String? get videoRestrictionReason {
    if (!canEnableVideo) {
      if (role == UserRole.banned) {
        return 'Has sido baneado del sistema de videoconferencias';
      }
      if (videoReportsCount >= 3) {
        return 'Has recibido múltiples reportes. Contacta con un moderador.';
      }
      if (role == UserRole.restricted) {
        final daysLeft = 30 - daysRegistered;
        return 'Cuenta restringida. Espera $daysLeft días más.';
      }
      if (!emailVerified && daysRegistered < 7) {
        final daysLeft = 7 - daysRegistered;
        return 'Verifica tu email o espera $daysLeft días más.';
      }
    }
    return null;
  }
  
  /// Copia con modificaciones
  UserProfile copyWith({
    String? nick,
    UserRole? role,
    bool? emailVerified,
    bool? phoneVerified,
    int? reputation,
    DateTime? registrationDate,
    bool? hasAcceptedVideoTerms,
    int? videoReportsCount,
    List<String>? videoWarnings,
  }) {
    return UserProfile(
      nick: nick ?? this.nick,
      role: role ?? this.role,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      reputation: reputation ?? this.reputation,
      registrationDate: registrationDate ?? this.registrationDate,
      hasAcceptedVideoTerms: hasAcceptedVideoTerms ?? this.hasAcceptedVideoTerms,
      videoReportsCount: videoReportsCount ?? this.videoReportsCount,
      videoWarnings: videoWarnings ?? this.videoWarnings,
    );
  }
  
  /// Convertir a mapa para guardar
  Map<String, dynamic> toMap() {
    return {
      'nick': nick,
      'role': role.name,
      'emailVerified': emailVerified ? 1 : 0,
      'phoneVerified': phoneVerified ? 1 : 0,
      'reputation': reputation,
      'registrationDate': registrationDate.toIso8601String(),
      'hasAcceptedVideoTerms': hasAcceptedVideoTerms ? 1 : 0,
      'videoReportsCount': videoReportsCount,
      'videoWarnings': videoWarnings.join('|'),
    };
  }
  
  /// Crear desde mapa
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      nick: map['nick'],
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.user,
      ),
      emailVerified: map['emailVerified'] == 1,
      phoneVerified: map['phoneVerified'] == 1,
      reputation: map['reputation'] ?? 50,
      registrationDate: DateTime.parse(map['registrationDate']),
      hasAcceptedVideoTerms: map['hasAcceptedVideoTerms'] == 1,
      videoReportsCount: map['videoReportsCount'] ?? 0,
      videoWarnings: (map['videoWarnings'] as String?)?.split('|') ?? [],
    );
  }
}

