import 'dart:io';
import 'package:flutter/services.dart';

/// Servicio para notificaciones nativas de macOS
class MacOSNotificationService {
  static final MacOSNotificationService _instance = MacOSNotificationService._internal();
  factory MacOSNotificationService() => _instance;
  MacOSNotificationService._internal();

  final MethodChannel _channel = const MethodChannel('macos_notifications');
  int _unreadCount = 0;

  /// Inicializa el servicio de notificaciones
  Future<void> initialize() async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('initialize');
    } catch (e) {
      // print('Error inicializando notificaciones: $e');
    }
  }

  /// Muestra una notificación
  Future<void> showNotification({
    required String title,
    required String body,
    String? subtitle,
  }) async {
    if (!Platform.isMacOS) return;
    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'body': body,
        'subtitle': subtitle,
      });
    } catch (e) {
      // print('Error mostrando notificación: $e');
    }
  }

  /// Actualiza el badge del dock con el número de mensajes no leídos
  Future<void> updateBadge(int count) async {
    if (!Platform.isMacOS) return;
    _unreadCount = count;
    try {
      await _channel.invokeMethod('updateBadge', {'count': count});
    } catch (e) {
      // print('Error actualizando badge: $e');
    }
  }

  /// Incrementa el contador de no leídos
  void incrementUnread() {
    updateBadge(_unreadCount + 1);
  }

  /// Resetea el contador de no leídos
  void resetUnread() {
    updateBadge(0);
  }
}


