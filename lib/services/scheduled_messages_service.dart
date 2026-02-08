import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Modelo para un mensaje programado
class ScheduledMessage {
  final String id;
  final String channel;
  final String message;
  final DateTime scheduledTime;
  final bool isRecurring;
  final Duration? recurrenceInterval; // Para mensajes recurrentes
  final int? maxRecurrences; // Máximo de repeticiones (null = infinito)
  int currentRecurrences; // Contador de repeticiones actuales

  ScheduledMessage({
    required this.id,
    required this.channel,
    required this.message,
    required this.scheduledTime,
    this.isRecurring = false,
    this.recurrenceInterval,
    this.maxRecurrences,
    this.currentRecurrences = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channel': channel,
      'message': message,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'isRecurring': isRecurring,
      'recurrenceInterval': recurrenceInterval?.inSeconds,
      'maxRecurrences': maxRecurrences,
      'currentRecurrences': currentRecurrences,
    };
  }

  factory ScheduledMessage.fromJson(Map<String, dynamic> json) {
    return ScheduledMessage(
      id: json['id'] as String,
      channel: json['channel'] as String,
      message: json['message'] as String,
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(json['scheduledTime'] as int),
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrenceInterval: json['recurrenceInterval'] != null
          ? Duration(seconds: json['recurrenceInterval'] as int)
          : null,
      maxRecurrences: json['maxRecurrences'] as int?,
      currentRecurrences: json['currentRecurrences'] as int? ?? 0,
    );
  }

  ScheduledMessage copyWith({
    String? id,
    String? channel,
    String? message,
    DateTime? scheduledTime,
    bool? isRecurring,
    Duration? recurrenceInterval,
    int? maxRecurrences,
    int? currentRecurrences,
  }) {
    return ScheduledMessage(
      id: id ?? this.id,
      channel: channel ?? this.channel,
      message: message ?? this.message,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      maxRecurrences: maxRecurrences ?? this.maxRecurrences,
      currentRecurrences: currentRecurrences ?? this.currentRecurrences,
    );
  }
}

/// Servicio para gestionar mensajes programados
class ScheduledMessagesService {
  final List<ScheduledMessage> _scheduledMessages = [];
  final Map<String, Timer> _messageTimers = {};
  final String _storageKey = 'scheduled_messages';
  
  Function(String channel, String message)? onSendMessage;

  ScheduledMessagesService() {
    _loadMessages();
    _scheduleAllMessages();
  }

  /// Cargar mensajes programados desde almacenamiento
  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString(_storageKey);
      if (messagesJson != null) {
        final List<dynamic> messagesList = json.decode(messagesJson);
        _scheduledMessages.clear();
        _scheduledMessages.addAll(
          messagesList.map((json) => ScheduledMessage.fromJson(json as Map<String, dynamic>))
        );
      }
    } catch (e) {
      print('⚠️ [ScheduledMessagesService] Error cargando mensajes: $e');
    }
  }

  /// Guardar mensajes programados en almacenamiento
  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = json.encode(
        _scheduledMessages.map((msg) => msg.toJson()).toList()
      );
      await prefs.setString(_storageKey, messagesJson);
    } catch (e) {
      print('⚠️ [ScheduledMessagesService] Error guardando mensajes: $e');
    }
  }

  /// Programar un nuevo mensaje
  Future<String> scheduleMessage({
    required String channel,
    required String message,
    required DateTime scheduledTime,
    bool isRecurring = false,
    Duration? recurrenceInterval,
    int? maxRecurrences,
  }) async {
    final id = 'scheduled_${DateTime.now().millisecondsSinceEpoch}';
    final scheduledMessage = ScheduledMessage(
      id: id,
      channel: channel,
      message: message,
      scheduledTime: scheduledTime,
      isRecurring: isRecurring,
      recurrenceInterval: recurrenceInterval,
      maxRecurrences: maxRecurrences,
    );

    _scheduledMessages.add(scheduledMessage);
    await _saveMessages();
    _scheduleMessage(scheduledMessage);

    return id;
  }

  /// Programar un mensaje individual
  void _scheduleMessage(ScheduledMessage scheduledMessage) {
    final now = DateTime.now();
    final scheduledTime = scheduledMessage.scheduledTime;
    
    if (scheduledTime.isBefore(now)) {
      // Si el tiempo ya pasó, enviar inmediatamente (o no hacer nada)
      if (scheduledMessage.isRecurring) {
        // Para mensajes recurrentes, calcular el próximo tiempo
        final nextTime = _calculateNextRecurrence(scheduledMessage);
        if (nextTime != null) {
          final updatedMessage = scheduledMessage.copyWith(scheduledTime: nextTime);
          final index = _scheduledMessages.indexWhere((m) => m.id == scheduledMessage.id);
          if (index != -1) {
            _scheduledMessages[index] = updatedMessage;
            _scheduleMessage(updatedMessage);
          }
        }
      }
      return;
    }

    final duration = scheduledTime.difference(now);
    final timer = Timer(duration, () {
      _sendScheduledMessage(scheduledMessage);
    });

    _messageTimers[scheduledMessage.id] = timer;
  }

  /// Calcular el próximo tiempo de recurrencia
  DateTime? _calculateNextRecurrence(ScheduledMessage message) {
    if (!message.isRecurring || message.recurrenceInterval == null) {
      return null;
    }

    if (message.maxRecurrences != null && 
        message.currentRecurrences >= message.maxRecurrences!) {
      return null; // Se alcanzó el máximo de repeticiones
    }

    return DateTime.now().add(message.recurrenceInterval!);
  }

  /// Enviar un mensaje programado
  void _sendScheduledMessage(ScheduledMessage scheduledMessage) {
    // Enviar el mensaje
    if (onSendMessage != null) {
      onSendMessage!(scheduledMessage.channel, scheduledMessage.message);
    }

    // Si es recurrente, programar el siguiente
    if (scheduledMessage.isRecurring) {
      final nextTime = _calculateNextRecurrence(scheduledMessage);
      if (nextTime != null) {
        final updatedMessage = scheduledMessage.copyWith(
          scheduledTime: nextTime,
          currentRecurrences: scheduledMessage.currentRecurrences + 1,
        );
        final index = _scheduledMessages.indexWhere((m) => m.id == scheduledMessage.id);
        if (index != -1) {
          _scheduledMessages[index] = updatedMessage;
          _saveMessages();
          _scheduleMessage(updatedMessage);
        }
      } else {
        // Se alcanzó el máximo, eliminar
        cancelScheduledMessage(scheduledMessage.id);
      }
    } else {
      // No es recurrente, eliminar después de enviar
      cancelScheduledMessage(scheduledMessage.id);
    }
  }

  /// Programar todos los mensajes pendientes
  void _scheduleAllMessages() {
    for (var message in _scheduledMessages) {
      _scheduleMessage(message);
    }
  }

  /// Cancelar un mensaje programado
  Future<bool> cancelScheduledMessage(String id) async {
    final timer = _messageTimers.remove(id);
    timer?.cancel();

    final initialLength = _scheduledMessages.length;
    _scheduledMessages.removeWhere((msg) => msg.id == id);
    final removed = initialLength - _scheduledMessages.length;
    if (removed > 0) {
      await _saveMessages();
      return true;
    }
    return false;
  }

  /// Obtener todos los mensajes programados
  List<ScheduledMessage> getScheduledMessages() {
    return List.unmodifiable(_scheduledMessages);
  }

  /// Obtener mensajes programados para un canal específico
  List<ScheduledMessage> getScheduledMessagesForChannel(String channel) {
    return _scheduledMessages.where((msg) => msg.channel == channel).toList();
  }

  /// Limpiar todos los mensajes programados
  Future<void> clearAllScheduledMessages() async {
    for (var timer in _messageTimers.values) {
      timer.cancel();
    }
    _messageTimers.clear();
    _scheduledMessages.clear();
    await _saveMessages();
  }

  /// Limpiar recursos
  void dispose() {
    for (var timer in _messageTimers.values) {
      timer.cancel();
    }
    _messageTimers.clear();
  }
}
