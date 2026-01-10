import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/platform_utils.dart';

// Import condicional de dart:html solo para web
import '../utils/html_stub.dart' as html;

/// Servicio para notificaciones web usando la Web Notifications API
class WebNotificationService {
  static final WebNotificationService _instance = WebNotificationService._internal();
  factory WebNotificationService() => _instance;
  WebNotificationService._internal();

  bool _permissionGranted = false;
  bool _isInitialized = false;
  bool _isTabVisible = true;

  /// Verifica si las notificaciones están soportadas
  bool get isSupported {
    if (!kIsWeb) return false;
    return html.window.navigator.permissions != null &&
           html.Notification.supported;
  }

  /// Inicializa el servicio de notificaciones
  /// NO solicita permisos automáticamente (requiere gesto del usuario)
  Future<void> initialize() async {
    if (!kIsWeb || !isSupported || _isInitialized) return;
    
    try {
      // NO solicitar permisos automáticamente - solo escuchar cambios de visibilidad
      // Los permisos se solicitarán cuando sea necesario (después de interacción del usuario)
      
      // Escuchar cambios de visibilidad de la pestaña
      html.document.onVisibilityChange.listen((event) {
        _isTabVisible = !(html.document.hidden ?? false);
      });
      
      // Inicializar estado de visibilidad
      _isTabVisible = !(html.document.hidden ?? false);
      
      _isInitialized = true;
    } catch (e) {
      // print('Error inicializando notificaciones web: $e');
    }
  }

  /// Solicita permiso para mostrar notificaciones
  Future<bool> requestPermission() async {
    if (!kIsWeb || !isSupported) return false;
    
    try {
      final permission = await html.Notification.requestPermission();
      _permissionGranted = permission == 'granted';
      return _permissionGranted;
    } catch (e) {
      // print('Error solicitando permiso de notificaciones: $e');
      return false;
    }
  }

  /// Verifica si tenemos permiso para mostrar notificaciones
  bool get hasPermission {
    if (!kIsWeb || !isSupported) return false;
    return html.Notification.permission == 'granted';
  }

  /// Verifica si la pestaña está visible
  bool get isTabVisible {
    if (!kIsWeb) return true;
    return !(html.document.hidden ?? false);
  }

  /// Muestra una notificación
  Future<void> showNotification({
    required String title,
    required String body,
    String? subtitle,
    String? tag,
    void Function()? onClick,
  }) async {
    if (!kIsWeb || !isSupported) return;
    
    // Solo mostrar notificación si la pestaña no está visible
    if (_isTabVisible) return;
    
    // Verificar permisos
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) return;
    }
    
    try {
      // Crear notificación usando el constructor correcto de dart:html
      // El constructor acepta título y opciones como parámetro opcional
      final bodyText = subtitle != null ? '$subtitle: $body' : body;
      
      // Crear la notificación con icono
      // El icono ahora está disponible en mobilev1.globalchat.org (Apache2 configurado)
      // Usar ruta relativa que funciona desde cualquier dominio
      final iconPath = 'icons/Icon-192.png';
      
      final notification = html.Notification(
        title,
        body: bodyText,
        icon: iconPath,
      );
      
      // Manejar clic en la notificación
      if (onClick != null) {
        notification.onClick.listen((event) {
          // Ejecutar el callback cuando se hace clic
          onClick();
        });
      }
      
      // Cerrar automáticamente después de 5 segundos
      Future.delayed(const Duration(seconds: 5), () {
        notification.close();
      });
    } catch (e) {
      // print('Error mostrando notificación web: $e');
    }
  }

  /// Cierra todas las notificaciones con un tag específico
  void closeNotifications(String tag) {
    if (!kIsWeb || !isSupported) return;
    // Las notificaciones se cierran automáticamente o manualmente
    // No hay API directa para cerrar todas las notificaciones de un tag
  }
}

