import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

/// Servicio para backup y sincronización
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  /// Crea un backup completo de la aplicación
  Future<String?> createBackup() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupData = <String, dynamic>{};

      // 1. Backup de preferencias
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = <String, dynamic>{};
      final keys = prefs.getKeys();
      for (final key in keys) {
        final value = prefs.get(key);
        if (value != null) {
          prefsMap[key] = value;
        }
      }
      backupData['preferences'] = prefsMap;

      // 2. Backup de base de datos
      final dbPath = await getDatabasesPath();
      final dbFile = File(path.join(dbPath, 'video_conferences.db'));
      if (await dbFile.exists()) {
        final dbBytes = await dbFile.readAsBytes();
        backupData['database'] = base64Encode(dbBytes);
      }

      // 3. Backup de historial de chat (si existe)
      final historyDir = Directory('${appDir.path}/chat_history');
      if (await historyDir.exists()) {
        final historyFiles = <String, String>{};
        await for (final entity in historyDir.list()) {
          if (entity is File) {
            final content = await entity.readAsString();
            historyFiles[entity.path.split('/').last] = content;
          }
        }
        backupData['chat_history'] = historyFiles;
      }

      // 4. Backup de contactos y configuración
      final contactsFile = File('${appDir.path}/contacts.json');
      if (await contactsFile.exists()) {
        backupData['contacts'] = await contactsFile.readAsString();
      }

      // 5. Metadata del backup
      backupData['metadata'] = {
        'version': '2.1.0',
        'createdAt': DateTime.now().toIso8601String(),
        'platform': Platform.operatingSystem,
      };

      // Guardar backup
      final backupJson = jsonEncode(backupData);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupFile = File('${appDir.path}/backup_$timestamp.json');

      await backupFile.writeAsString(backupJson);

      // Abrir diálogo para guardar
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar backup como...',
        fileName: 'irc_app_backup_$timestamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (savePath != null) {
        final saveFile = File(savePath);
        await saveFile.writeAsString(backupJson);
        return savePath;
      }

      return backupFile.path;
    } catch (e) {
      print('Error creando backup: $e');
      return null;
    }
  }

  /// Restaura desde un backup
  Future<bool> restoreFromBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return false;
      }

      final backupJson = await backupFile.readAsString();
      final backupData = jsonDecode(backupJson) as Map<String, dynamic>;

      // 1. Restaurar preferencias
      if (backupData.containsKey('preferences')) {
        final prefs = await SharedPreferences.getInstance();
        final prefsMap = backupData['preferences'] as Map<String, dynamic>;
        for (final entry in prefsMap.entries) {
          final value = entry.value;
          if (value is String) {
            await prefs.setString(entry.key, value);
          } else if (value is int) {
            await prefs.setInt(entry.key, value);
          } else if (value is bool) {
            await prefs.setBool(entry.key, value);
          } else if (value is double) {
            await prefs.setDouble(entry.key, value);
          } else if (value is List) {
            await prefs.setStringList(entry.key, List<String>.from(value));
          }
        }
      }

      // 2. Restaurar base de datos
      if (backupData.containsKey('database')) {
        final dbPath = await getDatabasesPath();
        final dbFile = File(path.join(dbPath, 'video_conferences.db'));
        final dbBytes = base64Decode(backupData['database'] as String);
        await dbFile.writeAsBytes(dbBytes);
      }

      // 3. Restaurar historial de chat
      if (backupData.containsKey('chat_history')) {
        final appDir = await getApplicationDocumentsDirectory();
        final historyDir = Directory('${appDir.path}/chat_history');
        if (!await historyDir.exists()) {
          await historyDir.create(recursive: true);
        }

        final historyFiles = backupData['chat_history'] as Map<String, dynamic>;
        for (final entry in historyFiles.entries) {
          final file = File('${historyDir.path}/${entry.key}');
          await file.writeAsString(entry.value as String);
        }
      }

      // 4. Restaurar contactos
      if (backupData.containsKey('contacts')) {
        final appDir = await getApplicationDocumentsDirectory();
        final contactsFile = File('${appDir.path}/contacts.json');
        await contactsFile.writeAsString(backupData['contacts'] as String);
      }

      return true;
    } catch (e) {
      print('Error restaurando backup: $e');
      return false;
    }
  }

  /// Exporta solo la configuración (sin datos sensibles)
  Future<String?> exportConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final config = <String, dynamic>{};

      // Solo exportar configuraciones no sensibles
      final safeKeys = [
        'theme',
        'message_format',
        'notification_settings',
        'radio_volume',
        'radio_starred',
      ];

      for (final key in safeKeys) {
        final value = prefs.get(key);
        if (value != null) {
          config[key] = value;
        }
      }

      final configJson = jsonEncode(config);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Exportar configuración...',
        fileName: 'irc_app_config_$timestamp.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (savePath != null) {
        final saveFile = File(savePath);
        await saveFile.writeAsString(configJson);
        return savePath;
      }

      return null;
    } catch (e) {
      print('Error exportando configuración: $e');
      return null;
    }
  }
}

