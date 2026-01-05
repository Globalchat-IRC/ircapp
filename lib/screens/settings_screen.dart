import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    final formatPrefs = ref.watch(messageFormatPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes Globales'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      backgroundColor: appTheme.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de formato de mensajes
          Card(
            color: appTheme.surface,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: appTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Formato de Mensajes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: appTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Formato para canales
                  Text(
                    'Formato en Canales',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: appTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormatOption(
                          context,
                          ref,
                          appTheme,
                          'Burbuja',
                          MessageFormat.bubble,
                          formatPrefs.channelFormat == MessageFormat.bubble,
                          Icons.chat_bubble,
                          (format) {
                            ref
                                .read(messageFormatPreferencesProvider.notifier)
                                .setChannelFormat(format);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormatOption(
                          context,
                          ref,
                          appTheme,
                          'Texto Plano',
                          MessageFormat.plain,
                          formatPrefs.channelFormat == MessageFormat.plain,
                          Icons.text_fields,
                          (format) {
                            ref
                                .read(messageFormatPreferencesProvider.notifier)
                                .setChannelFormat(format);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Formato para privados
                  Text(
                    'Formato en Privados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: appTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormatOption(
                          context,
                          ref,
                          appTheme,
                          'Burbuja',
                          MessageFormat.bubble,
                          formatPrefs.privateFormat == MessageFormat.bubble,
                          Icons.chat_bubble,
                          (format) {
                            ref
                                .read(messageFormatPreferencesProvider.notifier)
                                .setPrivateFormat(format);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormatOption(
                          context,
                          ref,
                          appTheme,
                          'Texto Plano',
                          MessageFormat.plain,
                          formatPrefs.privateFormat == MessageFormat.plain,
                          Icons.text_fields,
                          (format) {
                            ref
                                .read(messageFormatPreferencesProvider.notifier)
                                .setPrivateFormat(format);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(
    BuildContext context,
    WidgetRef ref,
    AppTheme appTheme,
    String label,
    MessageFormat format,
    bool isSelected,
    IconData icon,
    Function(MessageFormat) onTap,
  ) {
    return InkWell(
      onTap: () => onTap(format),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? appTheme.primary.withOpacity(0.2)
              : appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? appTheme.primary
                : appTheme.textPrimary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? appTheme.primary : appTheme.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? appTheme.primary
                    : appTheme.textPrimary,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle,
                size: 20,
                color: appTheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

