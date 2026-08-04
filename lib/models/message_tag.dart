import 'package:equatable/equatable.dart';

/// Modelo para etiquetas de mensajes
class MessageTag extends Equatable {
  final String id;
  final String name;
  final String color; // Color en formato hex
  final String? description;
  final DateTime createdAt;
  final int usageCount;

  const MessageTag({
    required this.id,
    required this.name,
    required this.color,
    this.description,
    required this.createdAt,
    this.usageCount = 0,
  });

  MessageTag copyWith({
    String? id,
    String? name,
    String? color,
    String? description,
    DateTime? createdAt,
    int? usageCount,
  }) {
    return MessageTag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'usageCount': usageCount,
    };
  }

  factory MessageTag.fromJson(Map<String, dynamic> json) {
    return MessageTag(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      usageCount: json['usageCount'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, color, description, createdAt, usageCount];
}






