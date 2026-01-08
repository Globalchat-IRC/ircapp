import 'package:equatable/equatable.dart';

/// Modelo para contactos/favoritos
class Contact extends Equatable {
  final String nick;
  final String? realName;
  final String? host;
  final DateTime? lastSeen;
  final DateTime? firstMet;
  final int messageCount;
  final List<String> tags;
  final String? notes;
  final bool isFavorite;
  final bool isBlocked;
  final String? group; // Grupo al que pertenece el contacto

  const Contact({
    required this.nick,
    this.realName,
    this.host,
    this.lastSeen,
    this.firstMet,
    this.messageCount = 0,
    this.tags = const [],
    this.notes,
    this.isFavorite = false,
    this.isBlocked = false,
    this.group,
  });

  Contact copyWith({
    String? nick,
    String? realName,
    String? host,
    DateTime? lastSeen,
    DateTime? firstMet,
    int? messageCount,
    List<String>? tags,
    String? notes,
    bool? isFavorite,
    bool? isBlocked,
    String? group,
  }) {
    return Contact(
      nick: nick ?? this.nick,
      realName: realName ?? this.realName,
      host: host ?? this.host,
      lastSeen: lastSeen ?? this.lastSeen,
      firstMet: firstMet ?? this.firstMet,
      messageCount: messageCount ?? this.messageCount,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      isFavorite: isFavorite ?? this.isFavorite,
      isBlocked: isBlocked ?? this.isBlocked,
      group: group ?? this.group,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nick': nick,
      'realName': realName,
      'host': host,
      'lastSeen': lastSeen?.toIso8601String(),
      'firstMet': firstMet?.toIso8601String(),
      'messageCount': messageCount,
      'tags': tags,
      'notes': notes,
      'isFavorite': isFavorite,
      'isBlocked': isBlocked,
      'group': group,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      nick: json['nick'] as String,
      realName: json['realName'] as String?,
      host: json['host'] as String?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
      firstMet: json['firstMet'] != null
          ? DateTime.parse(json['firstMet'] as String)
          : null,
      messageCount: json['messageCount'] as int? ?? 0,
      tags: List<String>.from(json['tags'] as List? ?? []),
      notes: json['notes'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isBlocked: json['blocked'] as bool? ?? false,
      group: json['group'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        nick,
        realName,
        host,
        lastSeen,
        firstMet,
        messageCount,
        tags,
        notes,
        isFavorite,
        isBlocked,
        group,
      ];
}




