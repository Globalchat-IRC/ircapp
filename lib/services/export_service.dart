import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/irc_message.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import '../utils/platform_utils.dart';
import 'dart:html' if (dart.library.io) 'package:irc_app/utils/html_stub.dart' as html;
import '../config/debug_config.dart';

/// Servicio para exportar conversaciones y logs
class ExportService {
  /// Exporta mensajes a formato de texto plano
  static Future<String?> exportToText(
    List<IRCMessage> messages,
    String channelName,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'irc_${channelName.replaceAll('#', '')}_$timestamp.txt';
      final file = File('${directory.path}/$fileName');

      final buffer = StringBuffer();
      buffer.writeln('IRC Chat Export - $channelName');
      buffer.writeln('Exported: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('=' * 80);
      buffer.writeln();

      for (final message in messages) {
        final time = DateFormat('HH:mm:ss').format(message.timestamp);
        buffer.writeln('[$time] <${message.nick}> ${message.message}');
      }

      await file.writeAsString(buffer.toString());

      // Abrir diálogo para guardar
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Guardar conversación como...',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (savePath != null) {
        final saveFile = File(savePath);
        await saveFile.writeAsString(buffer.toString());
        return savePath;
      }

      return file.path;
    } catch (e) {
      // debugLog('Error exportando a texto: $e');
      return null;
    }
  }

  /// Exporta mensajes a formato HTML
  static Future<String?> exportToHTML(
    List<IRCMessage> messages,
    String channelName,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'irc_${channelName.replaceAll('#', '')}_$timestamp.html';
      final file = File('${directory.path}/$fileName');

      final buffer = StringBuffer();
      buffer.writeln('<!DOCTYPE html>');
      buffer.writeln('<html>');
      buffer.writeln('<head>');
      buffer.writeln('<meta charset="UTF-8">');
      buffer.writeln('<title>IRC Chat Export - $channelName</title>');
      buffer.writeln('''
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 20px; background: #f5f5f5; }
          .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          h1 { color: #333; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
          .meta { color: #666; margin-bottom: 20px; }
          .message { margin: 8px 0; padding: 8px; border-left: 3px solid #007AFF; background: #f9f9f9; }
          .timestamp { color: #999; font-size: 0.9em; }
          .nick { font-weight: bold; color: #007AFF; }
          .content { margin-top: 4px; }
        </style>
      ''');
      buffer.writeln('</head>');
      buffer.writeln('<body>');
      buffer.writeln('<div class="container">');
      buffer.writeln('<h1>IRC Chat Export - $channelName</h1>');
      buffer.writeln('<div class="meta">Exported: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}</div>');

      for (final message in messages) {
        final time = DateFormat('HH:mm:ss').format(message.timestamp);
        buffer.writeln('<div class="message">');
        buffer.writeln('<span class="timestamp">[$time]</span> ');
        buffer.writeln('<span class="nick">&lt;${message.nick}&gt;</span> ');
        buffer.writeln('<span class="content">${_escapeHtml(message.message)}</span>');
        buffer.writeln('</div>');
      }

      buffer.writeln('</div>');
      buffer.writeln('</body>');
      buffer.writeln('</html>');

      await file.writeAsString(buffer.toString());

      // Abrir diálogo para guardar
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Guardar conversación como...',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['html'],
      );

      if (savePath != null) {
        final saveFile = File(savePath);
        await saveFile.writeAsString(buffer.toString());
        return savePath;
      }

      return file.path;
    } catch (e) {
      // debugLog('Error exportando a HTML: $e');
      return null;
    }
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Exporta logs de un canal, los comprime en ZIP y los encripta
  /// La clave de encriptación debe ser proporcionada por el usuario
  static Future<String?> exportEncryptedLogs({
    required List<IRCMessage> messages,
    required String channelName,
    required String server,
    required String encryptionKey,
  }) async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final channelClean = channelName.replaceAll('#', '');
      
      // Crear contenido de texto
      final textBuffer = StringBuffer();
      textBuffer.writeln('IRC Chat Logs - $channelName');
      textBuffer.writeln('Server: $server');
      textBuffer.writeln('Exported: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      textBuffer.writeln('Total messages: ${messages.length}');
      textBuffer.writeln('=' * 80);
      textBuffer.writeln();

      for (final message in messages) {
        final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(message.timestamp);
        textBuffer.writeln('[$time] <${message.nick}> ${message.message}');
      }

      // Crear contenido HTML
      final htmlBuffer = StringBuffer();
      htmlBuffer.writeln('<!DOCTYPE html>');
      htmlBuffer.writeln('<html>');
      htmlBuffer.writeln('<head>');
      htmlBuffer.writeln('<meta charset="UTF-8">');
      htmlBuffer.writeln('<title>IRC Chat Logs - $channelName</title>');
      htmlBuffer.writeln('''
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 20px; background: #f5f5f5; }
          .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
          h1 { color: #333; border-bottom: 2px solid #007AFF; padding-bottom: 10px; }
          .meta { color: #666; margin-bottom: 20px; }
          .message { margin: 8px 0; padding: 8px; border-left: 3px solid #007AFF; background: #f9f9f9; }
          .timestamp { color: #999; font-size: 0.9em; }
          .nick { font-weight: bold; color: #007AFF; }
          .content { margin-top: 4px; }
        </style>
      ''');
      htmlBuffer.writeln('</head>');
      htmlBuffer.writeln('<body>');
      htmlBuffer.writeln('<div class="container">');
      htmlBuffer.writeln('<h1>IRC Chat Logs - $channelName</h1>');
      htmlBuffer.writeln('<div class="meta">');
      htmlBuffer.writeln('Server: $server<br>');
      htmlBuffer.writeln('Exported: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}<br>');
      htmlBuffer.writeln('Total messages: ${messages.length}');
      htmlBuffer.writeln('</div>');

      for (final message in messages) {
        final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(message.timestamp);
        htmlBuffer.writeln('<div class="message">');
        htmlBuffer.writeln('<span class="timestamp">[$time]</span> ');
        htmlBuffer.writeln('<span class="nick">&lt;${message.nick}&gt;</span> ');
        htmlBuffer.writeln('<span class="content">${_escapeHtml(message.message)}</span>');
        htmlBuffer.writeln('</div>');
      }

      htmlBuffer.writeln('</div>');
      htmlBuffer.writeln('</body>');
      htmlBuffer.writeln('</html>');

      // Crear archivo JSON con metadata
      final metadata = {
        'channel': channelName,
        'server': server,
        'exportDate': DateTime.now().toIso8601String(),
        'messageCount': messages.length,
        'version': '1.0',
      };

      // Crear ZIP
      final archive = Archive();
      
      // Agregar archivos al ZIP
      archive.addFile(ArchiveFile(
        '${channelClean}_logs.txt',
        utf8.encode(textBuffer.toString()).length,
        utf8.encode(textBuffer.toString()),
      ));
      
      archive.addFile(ArchiveFile(
        '${channelClean}_logs.html',
        utf8.encode(htmlBuffer.toString()).length,
        utf8.encode(htmlBuffer.toString()),
      ));
      
      archive.addFile(ArchiveFile(
        'metadata.json',
        utf8.encode(jsonEncode(metadata)).length,
        utf8.encode(jsonEncode(metadata)),
      ));

      // Comprimir ZIP
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      if (zipData == null) {
        throw Exception('Error al crear el archivo ZIP');
      }

      // Encriptar el ZIP con AES-256
      final encryptedData = _encryptAES(Uint8List.fromList(zipData), encryptionKey);

      // Guardar archivo encriptado
      if (PlatformUtils.isWeb) {
        // Para web, usar descarga directa
        final blob = html.Blob([encryptedData]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', '${channelClean}_logs_encrypted_$timestamp.enc')
          ..click();
        html.Url.revokeObjectUrl(url);
        return 'Descargado';
      } else {
        // Para nativo, guardar en disco
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${channelClean}_logs_encrypted_$timestamp.enc';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(encryptedData);

        // Abrir diálogo para guardar
        final savePath = await FilePicker.saveFile(
          dialogTitle: 'Guardar logs encriptados como...',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['enc'],
        );

        if (savePath != null) {
          final saveFile = File(savePath);
          await saveFile.writeAsBytes(encryptedData);
          return savePath;
        }

        return file.path;
      }
    } catch (e) {
      debugLog('Error exportando logs encriptados: $e');
      return null;
    }
  }

  /// Encripta datos usando AES-256-CBC
  static Uint8List _encryptAES(Uint8List data, String password) {
    // Generar salt aleatorio
    final salt = Uint8List.fromList('IRC_APP_SALT_2024'.codeUnits);
    
    // Derivar clave usando PBKDF2
    final key = _deriveKey(password, salt, 32); // 256 bits
    
    // Generar IV desde la clave (para consistencia)
    final ivBytes = _deriveKey(password, salt, 16); // 128 bits para IV
    final iv = Uint8List(16);
    iv.setRange(0, 16, ivBytes);

    // Crear cipher AES-256-CBC
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    final keyParam = KeyParameter(key);
    final params = ParametersWithIV(keyParam, iv);
    cipher.init(true, params);

    // Encriptar
    final encrypted = cipher.process(data);

    // Agregar salt al inicio para poder derivar la clave al desencriptar
    final result = Uint8List(salt.length + encrypted.length);
    result.setRange(0, salt.length, salt);
    result.setRange(salt.length, result.length, encrypted);

    return result;
  }

  /// Deriva una clave usando PBKDF2
  static Uint8List _deriveKey(String password, Uint8List salt, int keyLength) {
    final passwordBytes = utf8.encode(password);
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 10000, keyLength));
    final derived = pbkdf2.process(passwordBytes);
    // Asegurar que tenga la longitud correcta
    if (derived.length >= keyLength) {
      return derived.sublist(0, keyLength);
    }
    // Si es más corto, extender con padding
    final result = Uint8List(keyLength);
    result.setRange(0, derived.length, derived);
    return result;
  }

  /// Desencripta datos encriptados (para uso externo)
  /// Esta función puede ser usada fuera de la app para desencriptar los logs
  static Uint8List? decryptAES(Uint8List encryptedData, String password) {
    try {
      // Extraer salt (primeros 16 bytes)
      final salt = encryptedData.sublist(0, 16);
      final encrypted = encryptedData.sublist(16);

      // Derivar clave
      final key = _deriveKey(password, salt, 32);
      final ivBytes = _deriveKey(password, salt, 16);
      final iv = Uint8List(16);
      iv.setRange(0, 16, ivBytes);

      // Desencriptar
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
      final keyParam = KeyParameter(key);
      final params = ParametersWithIV(keyParam, iv);
      cipher.init(false, params);

      return cipher.process(encrypted);
    } catch (e) {
      debugLog('Error desencriptando: $e');
      return null;
    }
  }
}






