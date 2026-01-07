import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/irc_message.dart';
import '../utils/platform_utils.dart';

class ChatHistoryService {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  factory ChatHistoryService() => _instance;
  ChatHistoryService._internal();

  Database? _db;

  Future<Database?> _openDb() async {
    // No usar sqflite en web
    if (PlatformUtils.isWeb) {
      return null;
    }
    
    if (_db != null) return _db!;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docsDir.path, 'irc_history.db');

      _db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE messages(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              server TEXT,
              channel TEXT,
              nick TEXT,
              message TEXT,
              timestamp INTEGER,
              isSystem INTEGER
            )
          ''');
        },
      );

      return _db!;
    } catch (e) {
      // print('⚠️ [ChatHistoryService] Error abriendo BD: $e');
      return null;
    }
  }

  Future<void> saveMessage({
    required String server,
    required IRCMessage message,
  }) async {
    try {
      final db = await _openDb();
      if (db == null) return; // No disponible en web
      
      // No guardar mensajes privados (canales que no empiezan con #)
      if (!message.channel.startsWith('#')) {
        return;
      }
      
      await db.insert(
        'messages',
        {
          'server': server,
          'channel': message.channel,
          'nick': message.nick,
          'message': message.message,
          'timestamp': message.timestamp.millisecondsSinceEpoch,
          'isSystem': message.isSystem ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Evitar romper el cliente por un fallo de BD
      // ignore: avoid_print
      // print('⚠️ [ChatHistoryService] Error guardando mensaje: $e');
    }
  }

  /// Eliminar todos los mensajes privados de la base de datos
  Future<void> deletePrivateMessages({required String server}) async {
    try {
      final db = await _openDb();
      if (db == null) return; // No disponible en web
      
      // Eliminar todos los mensajes donde el canal no empieza con #
      await db.delete(
        'messages',
        where: 'server = ? AND channel NOT LIKE ?',
        whereArgs: [server, '#%'],
      );
    } catch (e) {
      // ignore: avoid_print
      // print('⚠️ [ChatHistoryService] Error eliminando mensajes privados: $e');
    }
  }

  Future<List<IRCMessage>> loadRecentMessages({
    required String server,
    required String channel,
    int limit = 200,
  }) async {
    try {
      final db = await _openDb();
      if (db == null) return []; // No disponible en web
      final rows = await db.query(
        'messages',
        where: 'server = ? AND channel = ?',
        whereArgs: [server, channel],
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      final messages = rows.map((row) {
        return IRCMessage(
          nick: row['nick'] as String,
          channel: row['channel'] as String,
          message: row['message'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int),
          isSystem: (row['isSystem'] as int) == 1,
        );
      }).toList();

      // Devolvemos en orden cronológico ascendente
      return messages.reversed.toList();
    } catch (e) {
      // ignore: avoid_print
      // print('⚠️ [ChatHistoryService] Error cargando historial: $e');
      return [];
    }
  }

  Future<List<IRCMessage>> searchMessages({
    required String server,
    String? channel, // null -> búsqueda global en ese servidor
    String? nick,
    String? text,
    DateTime? from,
    DateTime? to,
    int limit = 300,
  }) async {
    try {
      final db = await _openDb();
      if (db == null) return []; // No disponible en web

      final where = <String>['server = ?'];
      final args = <Object?>[server];

      if (channel != null && channel.isNotEmpty) {
        where.add('channel = ?');
        args.add(channel.toLowerCase());
      }
      if (nick != null && nick.isNotEmpty) {
        where.add('LOWER(nick) = ?');
        args.add(nick.toLowerCase());
      }
      if (text != null && text.isNotEmpty) {
        where.add('message LIKE ?');
        args.add('%$text%');
      }
      if (from != null) {
        where.add('timestamp >= ?');
        args.add(from.millisecondsSinceEpoch);
      }
      if (to != null) {
        where.add('timestamp <= ?');
        args.add(to.millisecondsSinceEpoch);
      }

      final rows = await db.query(
        'messages',
        where: where.join(' AND '),
        whereArgs: args,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      final messages = rows.map((row) {
        return IRCMessage(
          nick: row['nick'] as String,
          channel: row['channel'] as String,
          message: row['message'] as String,
          timestamp:
              DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
          isSystem: (row['isSystem'] as int) == 1,
        );
      }).toList();

      return messages.reversed.toList();
    } catch (e) {
      // ignore: avoid_print
      // print('⚠️ [ChatHistoryService] Error buscando en historial: $e');
      return [];
    }
  }
}


