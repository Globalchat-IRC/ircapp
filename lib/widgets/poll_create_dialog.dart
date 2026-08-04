import 'package:flutter/material.dart';
import '../models/app_theme.dart';

class PollCreateDialog extends StatefulWidget {
  final AppTheme appTheme;

  const PollCreateDialog({super.key, required this.appTheme});

  static Future<Map<String, dynamic>?> show(BuildContext context, AppTheme appTheme) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: appTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PollCreateDialog(appTheme: appTheme),
    );
  }

  @override
  State<PollCreateDialog> createState() => _PollCreateDialogState();
}

class _PollCreateDialogState extends State<PollCreateDialog> {
  final _questionController = TextEditingController();
  final _optionControllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 6) return;
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _submit() {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (options.length < 2) return;

    Navigator.pop(context, {
      'question': question,
      'options': options,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.appTheme;
    final mq = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: mq.viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '📊 Crear encuesta',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _questionController,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '¿Pregunta?',
                hintStyle: TextStyle(color: theme.textSecondary),
                filled: true,
                fillColor: theme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _optionControllers.length,
                itemBuilder: (_, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _optionControllers[i],
                            style: TextStyle(color: theme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Opción ${i + 1}',
                              hintStyle: TextStyle(color: theme.textSecondary),
                              filled: true,
                              fillColor: theme.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) {
                              if (i == _optionControllers.length - 1) _addOption();
                            },
                          ),
                        ),
                        if (_optionControllers.length > 2)
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade300, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28),
                            onPressed: () => _removeOption(i),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_optionControllers.length < 6)
              TextButton.icon(
                onPressed: _addOption,
                icon: Icon(Icons.add, size: 16, color: theme.primary),
                label: Text(
                  'Agregar opción',
                  style: TextStyle(color: theme.primary, fontSize: 13),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Crear encuesta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
