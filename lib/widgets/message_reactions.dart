import 'package:flutter/material.dart';
import '../models/app_theme.dart';

/// Widget para mostrar reacciones rápidas a mensajes
class MessageReactions extends StatefulWidget {
  final String messageId;
  final AppTheme appTheme;
  final Map<String, List<String>> reactions; // emoji -> lista de nicks
  final Function(String emoji)? onReactionTap;

  const MessageReactions({
    super.key,
    required this.messageId,
    required this.appTheme,
    this.reactions = const {},
    this.onReactionTap,
  });

  @override
  State<MessageReactions> createState() => _MessageReactionsState();
}

class _MessageReactionsState extends State<MessageReactions> {
  bool _showPicker = false;

  // Emojis rápidos más comunes
  static const List<String> _quickEmojis = [
    '👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🎉',
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.reactions.isEmpty && !_showPicker) {
      return GestureDetector(
        onLongPress: () {
          setState(() {
            _showPicker = true;
          });
        },
        child: Icon(
          Icons.add_reaction_outlined,
          size: 16,
          color: widget.appTheme.textSecondary.withValues(alpha: 0.5),
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        // Mostrar reacciones existentes
        ...widget.reactions.entries.map((entry) {
          final emoji = entry.key;
          final nicks = entry.value;
          return GestureDetector(
            onTap: () => widget.onReactionTap?.call(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: widget.appTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.appTheme.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (nicks.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${nicks.length}',
                      style: TextStyle(
                        color: widget.appTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        // Botón para añadir reacción
        GestureDetector(
          onTap: () {
            setState(() {
              _showPicker = !_showPicker;
            });
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: widget.appTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.appTheme.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              _showPicker ? Icons.close : Icons.add_reaction_outlined,
              size: 14,
              color: widget.appTheme.textSecondary,
            ),
          ),
        ),
        // Picker de emojis rápidos
        if (_showPicker)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.appTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.appTheme.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Wrap(
              spacing: 8,
              children: _quickEmojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    widget.onReactionTap?.call(emoji);
                    setState(() {
                      _showPicker = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}


