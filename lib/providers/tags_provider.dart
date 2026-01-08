import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/message_tag.dart';
import '../models/irc_message.dart';

class TagsState {
  final List<MessageTag> tags;
  final Map<String, List<String>> messageTags; // messageId -> [tagIds]
  final bool isLoading;

  const TagsState({
    this.tags = const [],
    this.messageTags = const {},
    this.isLoading = false,
  });

  TagsState copyWith({
    List<MessageTag>? tags,
    Map<String, List<String>>? messageTags,
    bool? isLoading,
  }) {
    return TagsState(
      tags: tags ?? this.tags,
      messageTags: messageTags ?? this.messageTags,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TagsNotifier extends StateNotifier<TagsState> {
  TagsNotifier() : super(const TagsState()) {
    _loadTags();
  }

  Future<void> _loadTags() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final tagsJson = prefs.getString('message_tags');
      final messageTagsJson = prefs.getString('message_tag_assignments');

      List<MessageTag> tags = [];
      if (tagsJson != null) {
        final List<dynamic> decoded = jsonDecode(tagsJson);
        tags = decoded.map((json) => MessageTag.fromJson(json as Map<String, dynamic>)).toList();
      }

      Map<String, List<String>> messageTags = {};
      if (messageTagsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(messageTagsJson);
        decoded.forEach((key, value) {
          messageTags[key] = List<String>.from(value as List);
        });
      }

      state = state.copyWith(
        tags: tags,
        messageTags: messageTags,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    final tagsJson = jsonEncode(state.tags.map((t) => t.toJson()).toList());
    await prefs.setString('message_tags', tagsJson);
  }

  Future<void> _saveMessageTags() async {
    final prefs = await SharedPreferences.getInstance();
    final messageTagsJson = jsonEncode(state.messageTags);
    await prefs.setString('message_tag_assignments', messageTagsJson);
  }

  String _generateMessageId(IRCMessage message) {
    return '${message.channel}_${message.nick}_${message.timestamp.millisecondsSinceEpoch}';
  }

  Future<void> createTag(MessageTag tag) async {
    final tags = List<MessageTag>.from(state.tags);
    if (!tags.any((t) => t.id == tag.id)) {
      tags.add(tag);
      state = state.copyWith(tags: tags);
      await _saveTags();
    }
  }

  Future<void> updateTag(MessageTag tag) async {
    final tags = List<MessageTag>.from(state.tags);
    final index = tags.indexWhere((t) => t.id == tag.id);
    if (index != -1) {
      tags[index] = tag;
      state = state.copyWith(tags: tags);
      await _saveTags();
    }
  }

  Future<void> deleteTag(String tagId) async {
    final tags = List<MessageTag>.from(state.tags);
    tags.removeWhere((t) => t.id == tagId);
    
    // Remover el tag de todos los mensajes
    final messageTags = Map<String, List<String>>.from(state.messageTags);
    messageTags.forEach((messageId, tagIds) {
      tagIds.remove(tagId);
    });
    messageTags.removeWhere((key, value) => value.isEmpty);

    state = state.copyWith(tags: tags, messageTags: messageTags);
    await _saveTags();
    await _saveMessageTags();
  }

  Future<void> tagMessage(IRCMessage message, String tagId) async {
    final messageId = _generateMessageId(message);
    final messageTags = Map<String, List<String>>.from(state.messageTags);
    
    if (!messageTags.containsKey(messageId)) {
      messageTags[messageId] = [];
    }
    
    if (!messageTags[messageId]!.contains(tagId)) {
      messageTags[messageId]!.add(tagId);
      
      // Incrementar contador de uso del tag
      final tags = List<MessageTag>.from(state.tags);
      final tagIndex = tags.indexWhere((t) => t.id == tagId);
      if (tagIndex != -1) {
        tags[tagIndex] = tags[tagIndex].copyWith(
          usageCount: tags[tagIndex].usageCount + 1,
        );
        state = state.copyWith(tags: tags);
        await _saveTags();
      }
    }

    state = state.copyWith(messageTags: messageTags);
    await _saveMessageTags();
  }

  Future<void> untagMessage(IRCMessage message, String tagId) async {
    final messageId = _generateMessageId(message);
    final messageTags = Map<String, List<String>>.from(state.messageTags);
    
    if (messageTags.containsKey(messageId)) {
      messageTags[messageId]!.remove(tagId);
      if (messageTags[messageId]!.isEmpty) {
        messageTags.remove(messageId);
      }
      
      state = state.copyWith(messageTags: messageTags);
      await _saveMessageTags();
    }
  }

  List<String> getMessageTags(IRCMessage message) {
    final messageId = _generateMessageId(message);
    return state.messageTags[messageId] ?? [];
  }

  List<IRCMessage> getMessagesByTag(String tagId) {
    // Esto requeriría acceso a todos los mensajes, se implementaría en el provider de mensajes
    return [];
  }
}

final tagsProvider = StateNotifierProvider<TagsNotifier, TagsState>((ref) {
  return TagsNotifier();
});





