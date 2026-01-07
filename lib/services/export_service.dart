import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/irc_message.dart';
import 'package:intl/intl.dart';

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
      final savePath = await FilePicker.platform.saveFile(
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
      // print('Error exportando a texto: $e');
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
      final savePath = await FilePicker.platform.saveFile(
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
      // print('Error exportando a HTML: $e');
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
}


