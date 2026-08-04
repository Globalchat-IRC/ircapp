import '../models/irc_message.dart';

class ChatHistoryService {
  static final ChatHistoryService _instance = ChatHistoryService._internal();
  factory ChatHistoryService() => _instance;
  ChatHistoryService._internal();

  Future<void> saveMessage({String? server, IRCMessage? message}) async {}

  Future<List<IRCMessage>> getMessages({
    required String server,
    String? channel,
    int limit = 100,
  }) async => [];

  Future<List<IRCMessage>> searchMessages({
    required String server,
    String? channel,
    String? nick,
    String? text,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async => [];

  Future<void> deletePrivateMessages({String? server}) async {}

  Future<void> deleteChannelHistory({
    required String server,
    required String channel,
  }) async {}

  Future<void> deletePrivateHistory({
    required String server,
    required String nick,
  }) async {}

  Future<List<IRCMessage>> loadRecentMessages({
    required String server,
    required String channel,
    int limit = 100,
  }) async => [];

  Future<void> clearAll() async {}
}
