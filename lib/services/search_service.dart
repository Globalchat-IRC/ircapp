import 'package:flutter/material.dart';
import '../models/irc_message.dart';

/// Servicio para búsqueda y filtrado de mensajes
class SearchService {
  /// Busca mensajes en una lista según un término de búsqueda
  static List<IRCMessage> searchMessages(
    List<IRCMessage> messages,
    String searchTerm, {
    String? userFilter,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    if (searchTerm.isEmpty && userFilter == null && dateFrom == null && dateTo == null) {
      return messages;
    }

    final lowerSearchTerm = searchTerm.toLowerCase();
    final lowerUserFilter = userFilter?.toLowerCase();

    return messages.where((message) {
      // Filtro por término de búsqueda
      if (searchTerm.isNotEmpty) {
        final matchesSearch = message.message.toLowerCase().contains(lowerSearchTerm) ||
            message.nick.toLowerCase().contains(lowerSearchTerm) ||
            message.channel.toLowerCase().contains(lowerSearchTerm);
        if (!matchesSearch) return false;
      }

      // Filtro por usuario
      if (lowerUserFilter != null && lowerUserFilter.isNotEmpty) {
        if (!message.nick.toLowerCase().contains(lowerUserFilter)) {
          return false;
        }
      }

      // Filtro por fecha
      if (dateFrom != null && message.timestamp.isBefore(dateFrom)) {
        return false;
      }
      if (dateTo != null && message.timestamp.isAfter(dateTo)) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Resalta el término de búsqueda en un texto
  static List<TextSpan> highlightText(String text, String searchTerm, TextStyle baseStyle, TextStyle highlightStyle) {
    if (searchTerm.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final lowerText = text.toLowerCase();
    final lowerSearchTerm = searchTerm.toLowerCase();
    final spans = <TextSpan>[];
    int lastIndex = 0;

    while (true) {
      final index = lowerText.indexOf(lowerSearchTerm, lastIndex);
      if (index == -1) break;

      // Texto antes del match
      if (index > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, index),
          style: baseStyle,
        ));
      }

      // Texto resaltado
      spans.add(TextSpan(
        text: text.substring(index, index + searchTerm.length),
        style: highlightStyle,
      ));

      lastIndex = index + searchTerm.length;
    }

    // Texto restante
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans.isEmpty ? [TextSpan(text: text, style: baseStyle)] : spans;
  }
}

