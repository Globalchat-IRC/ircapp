import 'package:flutter/material.dart';
import '../models/poll.dart';
import '../models/app_theme.dart';

class PollWidget extends StatefulWidget {
  final Poll poll;
  final AppTheme appTheme;
  final String? currentNick;
  final void Function(String pollId, int optionIndex)? onVote;
  final void Function(String pollId)? onClose;

  const PollWidget({
    super.key,
    required this.poll,
    required this.appTheme,
    this.currentNick,
    this.onVote,
    this.onClose,
  });

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  int? _selectedOption;

  @override
  void initState() {
    super.initState();
    if (widget.currentNick != null) {
      final existing = widget.poll.getOptionForNick(widget.currentNick!);
      if (existing != null) {
        _selectedOption = widget.poll.options.indexOf(existing);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final theme = widget.appTheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📊',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  poll.question,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (poll.closed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'CERRADA',
                    style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(poll.options.length, (i) {
            final option = poll.options[i];
            final pct = poll.totalVotes > 0
                ? (option.votes / poll.totalVotes * 100)
                : 0.0;
            final isSelected = _selectedOption == i;
            final canVote = !poll.closed && widget.currentNick != null && !poll.hasVoted(widget.currentNick!);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                onTap: canVote
                    ? () {
                        setState(() => _selectedOption = i);
                        widget.onVote?.call(poll.id, i);
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primary.withValues(alpha: 0.15)
                        : theme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? theme.primary
                          : theme.textSecondary.withValues(alpha: 0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.text,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (poll.totalVotes > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: pct / 100,
                                        backgroundColor: theme.textSecondary.withValues(alpha: 0.1),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isSelected ? theme.primary : theme.primary.withValues(alpha: 0.5),
                                        ),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${option.votes} (${pct.toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle, color: theme.primary, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.how_to_vote, size: 12, color: theme.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${poll.totalVotes} voto${poll.totalVotes == 1 ? '' : 's'}',
                style: TextStyle(color: theme.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              if (poll.creator.isNotEmpty)
                Text(
                  'por ${poll.creator}',
                  style: TextStyle(color: theme.textSecondary, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
