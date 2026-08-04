import 'dart:convert';
import 'dart:typed_data';
import '../models/irc_message.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';
import 'package:pointycastle/export.dart';
import '../config/debug_config.dart';
import '../utils/export_web_bridge_stub.dart'
    if (dart.library.html) '../utils/export_web_bridge_web.dart';

class ExportService {
  static Future<String?> exportToText(
    List<IRCMessage> messages,
    String channelName,
  ) async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'irc_${channelName.replaceAll('#', '')}_$timestamp.txt';
      final buffer = StringBuffer();
      buffer.writeln('IRC Chat Export - $channelName');
      buffer.writeln('Exported: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('=' * 80);
      buffer.writeln();

      for (final message in messages) {
        final time = DateFormat('HH:mm:ss').format(message.timestamp);
        buffer.writeln('[$time] <${message.nick}> ${message.message}');
      }

      final bytes = utf8.encode(buffer.toString());
      downloadBytesOnWeb(bytes, fileName);
      return fileName;
    } catch (e) {
      debugLog('❌ [ExportService] Error exportando a texto: $e');
      return null;
    }
  }

  static Future<String?> exportToHTML(
    List<IRCMessage> messages,
    String channelName,
  ) async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'irc_${channelName.replaceAll('#', '')}_$timestamp.html';
      final buffer = StringBuffer();
      buffer.writeln('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>IRC Chat Export - $channelName</title></head><body>');
      buffer.writeln('<h1>IRC Chat Export - $channelName</h1>');
      buffer.writeln('<p>Exported: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}</p><hr>');

      for (final message in messages) {
        final time = DateFormat('HH:mm:ss').format(message.timestamp);
        buffer.writeln('<p><strong>[$time]</strong> &lt;${message.nick}&gt; ${_escapeHtml(message.message)}</p>');
      }

      buffer.writeln('</body></html>');
      final bytes = utf8.encode(buffer.toString());
      downloadBytesOnWeb(bytes, fileName);
      return fileName;
    } catch (e) {
      debugLog('❌ [ExportService] Error exportando a HTML: $e');
      return null;
    }
  }

  static Future<String?> exportEncryptedLogs({
    required List<IRCMessage> messages,
    required String channelName,
    required String server,
    required String encryptionKey,
  }) async {
    try {
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final fileName = 'irc_${channelName.replaceAll('#', '')}_$timestamp.enc';
      final buffer = StringBuffer();
      buffer.writeln('IRC Chat Export - $channelName');
      buffer.writeln('Exported: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('=' * 80);
      buffer.writeln();

      for (final message in messages) {
        final time = DateFormat('HH:mm:ss').format(message.timestamp);
        buffer.writeln('[$time] <${message.nick}> ${message.message}');
      }

      final plaintext = utf8.encode(buffer.toString());
      final encrypted = await _encryptAES(plaintext, encryptionKey);
      downloadBytesOnWeb(encrypted, fileName);
      return fileName;
    } catch (e) {
      debugLog('❌ [ExportService] Error exportando encriptado: $e');
      return null;
    }
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static Future<Uint8List> _encryptAES(Uint8List plaintext, String password) async {
    final key = _deriveKey(password);
    final cipher = CBCBlockCipher(AESEngine());
    final iv = Uint8List(16);
    final secureRandom = FortunaRandom();
    secureRandom.seed(KeyParameter(key));
    for (var i = 0; i < iv.length; i++) {
      iv[i] = secureRandom.nextUint8();
    }
    cipher.init(true, ParametersWithIV(KeyParameter(key), iv));
    final padded = _pad(plaintext, 16);
    final output = Uint8List(padded.length);
    var offset = 0;
    while (offset < padded.length) {
      offset += cipher.processBlock(padded, offset, output, offset);
    }
    final result = Uint8List(16 + output.length);
    result.setAll(0, iv);
    result.setAll(16, output);
    return result;
  }

  static Uint8List _deriveKey(String password) {
    final digest = SHA256Digest();
    final key = digest.process(utf8.encode(password) as Uint8List);
    return Uint8List.fromList(key);
  }

  static Uint8List _pad(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLength);
    padded.setAll(0, data);
    for (var i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }
}
