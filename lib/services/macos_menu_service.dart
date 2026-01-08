import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Servicio para gestionar los menús nativos de macOS
class MacOSMenuService {
  static final MacOSMenuService _instance = MacOSMenuService._internal();
  factory MacOSMenuService() => _instance;
  MacOSMenuService._internal();

  final MethodChannel _channel = const MethodChannel('macos_menu');

  /// Configura los menús nativos de macOS
  Future<void> setupMenus({
    VoidCallback? onAbout,
    VoidCallback? onPreferences,
    VoidCallback? onQuit,
    VoidCallback? onNewConnection,
    VoidCallback? onExportLogs,
    VoidCallback? onFind,
    VoidCallback? onFindNext,
    VoidCallback? onNewWindow,
  }) async {
    if (!Platform.isMacOS) return;

    try {
      await _channel.invokeMethod('setupMenus', {
        'hasAbout': onAbout != null,
        'hasPreferences': onPreferences != null,
        'hasQuit': onQuit != null,
        'hasNewConnection': onNewConnection != null,
        'hasExportLogs': onExportLogs != null,
        'hasFind': onFind != null,
        'hasFindNext': onFindNext != null,
        'hasNewWindow': onNewWindow != null,
      });

      // Configurar callbacks
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'about':
            onAbout?.call();
            break;
          case 'preferences':
            onPreferences?.call();
            break;
          case 'quit':
            onQuit?.call();
            break;
          case 'newConnection':
            onNewConnection?.call();
            break;
          case 'exportLogs':
            onExportLogs?.call();
            break;
          case 'find':
            onFind?.call();
            break;
          case 'findNext':
            onFindNext?.call();
            break;
          case 'newWindow':
            onNewWindow?.call();
            break;
        }
      });
    } catch (e) {
      // debugPrint('Error configurando menús macOS: $e');
    }
  }
}




