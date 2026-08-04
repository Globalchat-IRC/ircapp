import 'package:flutter/material.dart';
import '../models/app_theme.dart';

class KeyboardShortcutsHelpDialog extends StatelessWidget {
  final AppTheme appTheme;

  const KeyboardShortcutsHelpDialog({super.key, required this.appTheme});

  static final List<_ShortcutGroup> _groups = [
    _ShortcutGroup(
      title: 'Navegación',
      shortcuts: [
        _Shortcut('⌘K / Ctrl+K', 'Unirse a canal'),
        _Shortcut('⌘N / Ctrl+N', 'Nuevo mensaje privado'),
        _Shortcut('⌘W / Ctrl+W', 'Cerrar pestaña'),
        _Shortcut('⌘L / Ctrl+L', 'Lista de canales'),
      ],
    ),
    _ShortcutGroup(
      title: 'Búsqueda',
      shortcuts: [
        _Shortcut('⌘F / Ctrl+F', 'Buscar en el chat'),
        _Shortcut('⌘G / Ctrl+G', 'Buscar siguiente'),
        _Shortcut('⇧⌘G / ⇧Ctrl+G', 'Buscar anterior'),
      ],
    ),
    _ShortcutGroup(
      title: 'General',
      shortcuts: [
        _Shortcut('⌘, / Ctrl+,', 'Ajustes'),
        _Shortcut('⌘E / Ctrl+E', 'Exportar logs'),
        _Shortcut('⌘/ / Ctrl+/', 'Ayuda de atajos'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              appTheme.surface,
              appTheme.surface.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: appTheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [appTheme.primary, appTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.keyboard,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Atajos de teclado',
                    style: TextStyle(
                      color: appTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: appTheme.textPrimary.withValues(alpha: 0.7),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final group in _groups) ...[
                      if (_groups.first != group) const SizedBox(height: 16),
                      Text(
                        group.title,
                        style: TextStyle(
                          color: appTheme.textPrimary.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final shortcut in group.shortcuts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: appTheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: appTheme.textPrimary.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  shortcut.keys,
                                  style: TextStyle(
                                    color: appTheme.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  shortcut.description,
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appTheme.surface.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: appTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pulsa ⌘/ o Ctrl+/ para abrir esta ayuda',
                    style: TextStyle(
                      color: appTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutGroup {
  final String title;
  final List<_Shortcut> shortcuts;
  const _ShortcutGroup({required this.title, required this.shortcuts});
}

class _Shortcut {
  final String keys;
  final String description;
  const _Shortcut(this.keys, this.description);
}
