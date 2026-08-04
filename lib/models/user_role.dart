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
  
  /// Emoji del rol
  String get emoji {
    switch (this) {
      case UserRole.admin:
        return '👑';
      case UserRole.moderator:
        return '👮';
      case UserRole.ircop:
        return '🛡️';
      case UserRole.verified:
        return '✅';
      case UserRole.user:
        return '👤';
      case UserRole.restricted:
        return '⚠️';
      case UserRole.banned:
        return '🚫';
    }
  }
}

/// Perfil de usuario con información de moderación
class UserProfile {
  final String nick;
  final UserRole role;
  final bool emailVerified;
  final bool phoneVerified;
  final bool idVerified;
  final int reputation; // 0-100
  final DateTime? registrationDate;
  final bool hasAcceptedVideoTerms;
  final int videoReportsCount;
  final List<String> videoWarnings;
  final String? gender; // Sexo: 'M', 'F', 'O' (Otro), null
  final int? age; // Edad
  final List<String> interests; // Intereses
  
  UserProfile({
    required this.nick,
    this.role = UserRole.user,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.idVerified = false,
    this.reputation = 50,
    DateTime? registrationDate,
    this.hasAcceptedVideoTerms = false,
    this.videoReportsCount = 0,
    this.videoWarnings = const [],
    this.gender,
    this.age,
    this.interests = const [],
  }) : registrationDate = registrationDate ?? DateTime.now();
  
  /// Días desde el registro
  int get daysRegistered {
    if (registrationDate == null) return 0;
    return DateTime.now().difference(registrationDate!).inDays;
  }
  
  /// Puede activar video
  bool get canEnableVideo {
    return role != UserRole.banned;
  }
  
  /// Razón por la que no puede usar video
  String? get videoRestrictionReason {
    if (role == UserRole.banned) {
      return 'Has sido baneado del sistema de videoconferencias';
    }
    return null;
  }
  
  /// Puede iniciar conferencias
  bool get canStartConference {
    return role != UserRole.banned;
  }
  
  /// Badge de verificación
  String get verificationBadge {
    if (idVerified) return '🆔';
    if (phoneVerified) return '📱';
    if (emailVerified) return '✉️';
    return '';
  }
  
  /// Copia con modificaciones
  UserProfile copyWith({
    String? nick,
    UserRole? role,
    bool? emailVerified,
    bool? phoneVerified,
    bool? idVerified,
    int? reputation,
    DateTime? registrationDate,
    bool? hasAcceptedVideoTerms,
    int? videoReportsCount,
    List<String>? videoWarnings,
    String? gender,
    int? age,
    List<String>? interests,
  }) {
    return UserProfile(
      nick: nick ?? this.nick,
      role: role ?? this.role,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      idVerified: idVerified ?? this.idVerified,
      reputation: reputation ?? this.reputation,
      registrationDate: registrationDate ?? this.registrationDate,
      hasAcceptedVideoTerms: hasAcceptedVideoTerms ?? this.hasAcceptedVideoTerms,
      videoReportsCount: videoReportsCount ?? this.videoReportsCount,
      videoWarnings: videoWarnings ?? this.videoWarnings,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      interests: interests ?? this.interests,
    );
  }
  
  /// Convertir a mapa para guardar
  Map<String, dynamic> toMap() {
    return {
      'nick': nick,
      'role': role.name,
      'emailVerified': emailVerified ? 1 : 0,
      'phoneVerified': phoneVerified ? 1 : 0,
      'idVerified': idVerified ? 1 : 0,
      'reputation': reputation,
      'registrationDate': registrationDate?.toIso8601String(),
      'hasAcceptedVideoTerms': hasAcceptedVideoTerms ? 1 : 0,
      'videoReportsCount': videoReportsCount,
      'videoWarnings': videoWarnings.join('|'),
      'gender': gender,
      'age': age,
      'interests': interests.join('|'),
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
      idVerified: map['idVerified'] == 1,
      reputation: map['reputation'] ?? 50,
      registrationDate: map['registrationDate'] != null 
          ? DateTime.parse(map['registrationDate']) 
          : null,
      hasAcceptedVideoTerms: map['hasAcceptedVideoTerms'] == 1,
      videoReportsCount: map['videoReportsCount'] ?? 0,
      videoWarnings: (map['videoWarnings'] as String?)?.split('|') ?? [],
      gender: map['gender'] as String?,
      age: map['age'] != null ? (map['age'] is int ? map['age'] : int.tryParse(map['age'].toString())) : null,
      interests: (map['interests'] as String?)?.split('|').where((i) => i.isNotEmpty).toList() ?? [],
    );
  }
}

