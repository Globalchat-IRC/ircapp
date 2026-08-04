import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/channel_background_provider.dart';
import '../providers/history_provider.dart';
import '../models/app_theme.dart';
import '../models/irc_style_preset.dart';
import '../services/backup_service.dart';
import '../services/cache_service.dart';
import '../services/chat_history_service.dart';
import '../services/avatar_service.dart';
import '../utils/platform_utils.dart';
import 'privacy_settings_screen.dart';
import 'robots_settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cuando el usuario vuelve del generador SVG (navegador externo),
    // invalidar caché de avatares para que se detecten los nuevos.
    if (state == AppLifecycleState.resumed) {
      AvatarService.invalidateAllCache();
    }
  }

  void _openSection(
    BuildContext context,
    String title,
    IconData icon,
    Widget Function(BuildContext context, WidgetRef ref) bodyBuilder,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _SettingsSectionScreen(
          title: title,
          icon: icon,
          bodyBuilder: bodyBuilder,
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    AppTheme appTheme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: appTheme.surface,
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, color: appTheme.primary),
        title: Text(
          title,
          style: TextStyle(
            color: appTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: appTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSessionStatsCard(BuildContext context, AppTheme appTheme) {
    return Card(
      color: appTheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Consumer(
          builder: (context, ref, _) {
            final messages = ref.watch(messagesProvider);
            final currentNick = ref.watch(currentNicknameProvider);
            final sentCount = currentNick == null
                ? 0
                : messages.where((m) => m.nick == currentNick && !m.isSystem).length;
            return Row(
              children: [
                Icon(Icons.bar_chart, color: appTheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estadísticas de sesión',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mensajes enviados: $sentCount',
                        style: TextStyle(fontSize: 13, color: appTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes Globales'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      backgroundColor: appTheme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildSessionStatsCard(context, appTheme),
          const SizedBox(height: 16),
          _buildMenuTile(
            appTheme,
            icon: Icons.chat_bubble_outline,
            title: 'Formato de Mensajes',
            subtitle: 'Formato en canales y privados, hora, hilos y reacciones',
            onTap: () => _openSection(context, 'Formato de Mensajes', Icons.chat_bubble_outline, _buildFormatSection),
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.palette_outlined,
            title: 'Apariencia',
            subtitle: 'Tema, colores, fuentes, tamaños y estilo del chat',
            onTap: () => _openSection(context, 'Apariencia', Icons.palette_outlined, _buildAppearanceSection),
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.image_outlined,
            title: 'Avatares y Estado',
            subtitle: 'Avatar GIF global, generador SVG y mensaje de ausencia',
            onTap: () => _openSection(context, 'Avatares y Estado', Icons.image_outlined, _buildAvatarsSection),
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.notifications_active_outlined,
            title: 'Sonidos y Notificaciones',
            subtitle: 'No molestar y sonidos para privados, menciones y entradas',
            onTap: () => _openSection(context, 'Sonidos y Notificaciones', Icons.notifications_active_outlined, _buildSoundsSection),
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.accessibility_new,
            title: 'Accesibilidad',
            subtitle: 'Reducir animaciones y escala de texto',
            onTap: () => _openSection(context, 'Accesibilidad', Icons.accessibility_new, _buildAccessibilitySection),
          ),
          const Divider(height: 32),
          _buildMenuTile(
            appTheme,
            icon: Icons.quickreply,
            title: 'Respuestas rápidas',
            subtitle: 'Frases que puedes insertar con un clic',
            onTap: () => _openSection(context, 'Respuestas rápidas', Icons.quickreply, _buildQuickRepliesSection),
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.image,
            title: 'Imágenes de Fondo por Canal',
            subtitle: 'Fondos personalizados para cada canal',
            onTap: () => _openSection(context, 'Imágenes de Fondo por Canal', Icons.image, _buildBackgroundsSection),
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.history,
            title: 'Historial de Mensajes',
            subtitle: 'Guardar y borrar historial de chats y privados',
            onTap: () => _openSection(context, 'Historial de Mensajes', Icons.history, _buildHistorySection),
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.privacy_tip,
            title: 'Privacidad',
            subtitle: 'Privacidad y modo incógnito',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.smart_toy,
            title: 'Gestión de Robots',
            subtitle: 'Añadir robots y asignarles iconos personalizados',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RobotsSettingsScreen(),
                ),
              );
            },
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.backup,
            title: 'Backup y Restauración',
            subtitle: 'Crear o restaurar backup de la aplicación',
            onTap: () => _openSection(context, 'Backup y Restauración', Icons.backup, _buildBackupSection),
          ),
          _buildMenuTile(
            appTheme,
            icon: Icons.storage,
            title: 'Cache',
            subtitle: 'Ver tamaño y limpiar datos temporales',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const _SettingsSectionScreen(
                    title: 'Cache',
                    icon: Icons.storage,
                    child: _CacheSettingsSection(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionScreen extends ConsumerWidget {
  final String title;
  final IconData icon;
  final Widget Function(BuildContext context, WidgetRef ref)? bodyBuilder;
  final Widget? child;

  const _SettingsSectionScreen({
    required this.title,
    required this.icon,
    this.bodyBuilder,
    this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      backgroundColor: appTheme.background,
      body: child ?? bodyBuilder!(context, ref),
    );
  }
}

class _CacheSettingsSection extends ConsumerStatefulWidget {
  const _CacheSettingsSection();

  @override
  ConsumerState<_CacheSettingsSection> createState() => _CacheSettingsSectionState();
}

class _CacheSettingsSectionState extends ConsumerState<_CacheSettingsSection> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        FutureBuilder<int>(
          key: ValueKey('cache_$_refreshKey'),
          future: _getSettingsCacheSize(),
          builder: (context, snapshot) {
            final cacheSize = snapshot.data ?? 0;
            final cacheSizeMB = (cacheSize / (1024 * 1024)).toStringAsFixed(2);
            return Card(
              color: appTheme.surface,
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.storage, color: appTheme.primary),
                    title: const Text('Cache'),
                    subtitle: Text('Tamaño actual: $cacheSizeMB MB'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final cleared = await _clearSettingsCache(context);
                              if (cleared && mounted) {
                                setState(() => _refreshKey++);
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Limpiar Cache'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<int> _getSettingsCacheSize() async {
  final cacheService = CacheService();
  await cacheService.initialize();
  return await cacheService.getCacheSize();
}

Future<bool> _clearSettingsCache(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Limpiar Cache'),
      content: const Text('¿Estás seguro de que quieres limpiar todo el cache?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Limpiar'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    final cacheService = CacheService();
    await cacheService.initialize();
    await cacheService.clearCache();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache limpiado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return true;
  }
  return false;
}

Future<void> _createSettingsBackup(BuildContext context) async {
  final backupService = BackupService();
  final path = await backupService.createBackup();

  if (path != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Backup creado en: $path'),
        duration: const Duration(seconds: 3),
      ),
    );
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error al crear backup'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _restoreSettingsBackup(BuildContext context) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );

  if (result != null && result.files.single.path != null) {
    final backupService = BackupService();
    final success = await backupService.restoreFromBackup(result.files.single.path!);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Backup restaurado exitosamente' : 'Error al restaurar backup'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

Widget _buildSwitchRow(
  AppTheme appTheme, {
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: appTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: appTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: appTheme.primary,
        ),
      ],
    ),
  );
}

Widget _buildSliderRow(
  AppTheme appTheme, {
  required String title,
  required double value,
  required double min,
  required double max,
  required String display,
  required ValueChanged<double> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: appTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                label: display,
                onChanged: onChanged,
                activeColor: appTheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: appTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: appTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                display,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: appTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildFontFamilyDropdown(
  AppTheme appTheme, {
  required String value,
  required ValueChanged<String?> onChanged,
}) {
  return DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: appTheme.surface,
    ),
    dropdownColor: appTheme.surface,
    style: TextStyle(color: appTheme.textPrimary),
    items: const [
      DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
      DropdownMenuItem(value: 'Arial', child: Text('Arial')),
      DropdownMenuItem(value: 'Courier New', child: Text('Courier New')),
      DropdownMenuItem(value: 'Times New Roman', child: Text('Times New Roman')),
      DropdownMenuItem(value: 'Verdana', child: Text('Verdana')),
      DropdownMenuItem(value: 'Georgia', child: Text('Georgia')),
      DropdownMenuItem(value: 'Comic Sans MS', child: Text('Comic Sans MS')),
    ],
    onChanged: onChanged,
  );
}

Widget _buildDropdownRow<T>(
  AppTheme appTheme, {
  required IconData icon,
  required String title,
  required String subtitle,
  required T value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: appTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: appTheme.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        DropdownButton<T>(
          value: value,
          dropdownColor: appTheme.surface,
          style: TextStyle(color: appTheme.textPrimary),
          underline: const SizedBox(),
          items: items,
          onChanged: onChanged,
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
            ? appTheme.primary.withValues(alpha: 0.2)
            : appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? appTheme.primary
              : appTheme.textPrimary.withValues(alpha: 0.2),
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

Widget _buildFormatSection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  final formatPrefs = ref.watch(messageFormatPreferencesProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
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
              'Texto plano',
              MessageFormat.compact,
              formatPrefs.channelFormat == MessageFormat.compact,
              Icons.notes,
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
              'Tablas',
              MessageFormat.plain,
              formatPrefs.channelFormat == MessageFormat.plain,
              Icons.table_rows,
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
        ],
      ),
      const SizedBox(height: 24),
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
              'Texto plano',
              MessageFormat.compact,
              formatPrefs.privateFormat == MessageFormat.compact,
              Icons.notes,
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
              'Tablas',
              MessageFormat.plain,
              formatPrefs.privateFormat == MessageFormat.plain,
              Icons.table_rows,
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
        ],
      ),
      const SizedBox(height: 16),
      _buildSwitchRow(
        appTheme,
        icon: Icons.campaign,
        title: 'Usar NOTICE en privados',
        subtitle: 'Si está activado, los mensajes privados se envían como NOTICE (el otro usuario no puede responder automáticamente).',
        value: ref.watch(useNoticeForPrivateProvider),
        onChanged: (value) {
          ref.read(useNoticeForPrivateProvider.notifier).setValue(value);
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.block,
        title: 'Ignorar todos los privados',
        subtitle: 'Si está activado, se bloquean todos los mensajes privados entrantes de usuarios que no sean bots. Se responde automáticamente con un aviso de modo +P.',
        value: ref.watch(ignoreAllPrivatesProvider),
        onChanged: (value) {
          ref.read(ignoreAllPrivatesProvider.notifier).toggle();
          final newValue = ref.read(ignoreAllPrivatesProvider);
          ref.read(ircServiceProvider).setIgnoreAllPrivates(newValue);
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.access_time,
        title: 'Mostrar hora en mensajes',
        subtitle: 'Muestra la hora junto a cada mensaje',
        value: formatPrefs.showTimestamp,
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setShowTimestamp(value);
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.reply,
        title: 'Hilos de conversación en canales',
        subtitle: 'Permite responder a mensajes y crear hilos de conversación',
        value: formatPrefs.enableThreadsInChannels,
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setEnableThreadsInChannels(value);
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.add_reaction,
        title: 'Reacciones en mensajes',
        subtitle: 'Permite reaccionar a mensajes con emojis',
        value: formatPrefs.enableReactions,
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setEnableReactions(value);
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.person_outline,
        title: 'Doble tap abre privado',
        subtitle: 'Al hacer doble clic en un usuario de la lista se abre su mensaje privado',
        value: formatPrefs.doubleTapOpensPrivateMessage,
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setDoubleTapOpensPrivateMessage(value);
        },
      ),
    ],
  );
}

Widget _buildAppearanceSection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  final formatPrefs = ref.watch(messageFormatPreferencesProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      Text(
        'Tema por defecto',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: appTheme.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: appTheme.name,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: appTheme.surface,
        ),
        dropdownColor: appTheme.surface,
        style: TextStyle(color: appTheme.textPrimary),
        items: AppTheme.themes.map((theme) {
          return DropdownMenuItem(
            value: theme.name,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(theme.name),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            final theme = AppTheme.themes.firstWhere(
              (t) => t.name == value,
            );
            ref.read(themeProvider.notifier).setTheme(theme);
          }
        },
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        icon: Icon(Icons.palette, color: appTheme.accent, size: 18),
        label: Text(
          'Editar colores...',
          style: TextStyle(color: appTheme.accent, fontSize: 13),
        ),
        onPressed: () => _showCustomThemeEditor(context, ref),
      ),
      const SizedBox(height: 16),
      Consumer(
        builder: (context, ref, _) {
          final currentPreset = ref.watch(notificationSettingsProvider).chatStylePreset;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estilo del chat',
                style: TextStyle(
                  color: appTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Elige un estilo visual para los mensajes',
                style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: IrcStylePreset.presets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = IrcStylePreset.presets[index];
                    final isSelected = currentPreset == preset.id;
                    return GestureDetector(
                      onTap: () {
                        ref.read(notificationSettingsProvider.notifier).state =
                            ref.read(notificationSettingsProvider).copyWith(chatStylePreset: preset.id);
                      },
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: preset.backgroundColor ?? appTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? appTheme.primary : appTheme.textSecondary.withValues(alpha: 0.2),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(preset.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 4),
                            Text(
                              preset.name,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: preset.messageColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
      _buildSliderRow(
        appTheme,
        title: 'Tamaño de fuente en Canales',
        value: formatPrefs.channelFontSize,
        min: 10.0,
        max: 30.0,
        display: '${formatPrefs.channelFontSize.toStringAsFixed(0)}px',
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setChannelFontSize(value);
        },
      ),
      _buildSliderRow(
        appTheme,
        title: 'Tamaño de fuente en Privados',
        value: formatPrefs.privateFontSize,
        min: 10.0,
        max: 30.0,
        display: '${formatPrefs.privateFontSize.toStringAsFixed(0)}px',
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setPrivateFontSize(value);
        },
      ),
      _buildSliderRow(
        appTheme,
        title: 'Tamaño de emoticonos',
        value: formatPrefs.emojiSize,
        min: 16.0,
        max: 80.0,
        display: '${formatPrefs.emojiSize.toStringAsFixed(0)}px',
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setEmojiSize(value);
        },
      ),
      _buildSliderRow(
        appTheme,
        title: 'Tamaño de avatares',
        value: formatPrefs.avatarScale,
        min: 0.6,
        max: 1.6,
        display: '${(formatPrefs.avatarScale * 100).toStringAsFixed(0)}%',
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setAvatarScale(value);
        },
      ),
      Text(
        'Tipo de fuente en Canales',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: appTheme.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      _buildFontFamilyDropdown(
        appTheme,
        value: formatPrefs.channelFontFamily,
        onChanged: (value) {
          if (value != null) {
            ref
                .read(messageFormatPreferencesProvider.notifier)
                .setChannelFontFamily(value);
          }
        },
      ),
      const SizedBox(height: 16),
      Text(
        'Tipo de fuente en Privados',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: appTheme.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      _buildFontFamilyDropdown(
        appTheme,
        value: formatPrefs.privateFontFamily,
        onChanged: (value) {
          if (value != null) {
            ref
                .read(messageFormatPreferencesProvider.notifier)
                .setPrivateFontFamily(value);
          }
        },
      ),
      const SizedBox(height: 16),
      _buildSwitchRow(
        appTheme,
        icon: Icons.motion_photos_auto,
        title: 'Avatares animados',
        subtitle: 'Permite usar avatares GIF animados en los nicks (puede consumir más CPU/RAM).',
        value: formatPrefs.enableAnimatedAvatars,
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setEnableAnimatedAvatars(value);
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.account_circle_outlined,
        title: 'Mostrar avatar junto al nick en canales',
        subtitle: 'Activa o desactiva el avatar pequeno que aparece antes del nick en los mensajes del canal.',
        value: formatPrefs.showInlineChannelAvatar,
        onChanged: (value) {
          ref
              .read(messageFormatPreferencesProvider.notifier)
              .setShowInlineChannelAvatar(value);
        },
      ),
      Consumer(
        builder: (context, ref, _) {
          final avatarPos = ref.watch(notificationSettingsProvider).channelAvatarPosition;
          return _buildDropdownRow(
            appTheme,
            icon: Icons.account_circle,
            title: 'Avatar en canales',
            subtitle: switch (avatarPos) {
              ChannelAvatarPosition.left => 'Izquierda del nick',
              ChannelAvatarPosition.right => 'Derecha del nick',
              ChannelAvatarPosition.hidden => 'Oculto',
            },
            value: avatarPos,
            items: const [
              DropdownMenuItem(value: ChannelAvatarPosition.left, child: Text('Izquierda')),
              DropdownMenuItem(value: ChannelAvatarPosition.right, child: Text('Derecha')),
              DropdownMenuItem(value: ChannelAvatarPosition.hidden, child: Text('Oculto')),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(notificationSettingsProvider.notifier).setChannelAvatarPosition(v);
              }
            },
          );
        },
      ),
      Consumer(
        builder: (context, ref, _) {
          final tsPos = ref.watch(notificationSettingsProvider).timestampPosition;
          return _buildDropdownRow(
            appTheme,
            icon: Icons.access_time,
            title: 'Posición del timestamp',
            subtitle: switch (tsPos) {
              MessageTimestampPosition.beforeNick => 'Antes del nick',
              MessageTimestampPosition.afterNick => 'Después del nick',
              MessageTimestampPosition.afterMessage => 'Después del mensaje',
            },
            value: tsPos,
            items: const [
              DropdownMenuItem(value: MessageTimestampPosition.afterNick, child: Text('Después del nick')),
              DropdownMenuItem(value: MessageTimestampPosition.beforeNick, child: Text('Antes del nick')),
              DropdownMenuItem(value: MessageTimestampPosition.afterMessage, child: Text('Después del mensaje')),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(notificationSettingsProvider.notifier).setTimestampPosition(v);
              }
            },
          );
        },
      ),
    ],
  );
}

Widget _buildAccessibilitySection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      _buildSwitchRow(
        appTheme,
        icon: Icons.motion_photos_off,
        title: 'Reducir animaciones',
        subtitle: 'Menos movimiento en la interfaz (accesibilidad)',
        value: ref.watch(reduceMotionProvider),
        onChanged: (v) {
          ref.read(reduceMotionProvider.notifier).setReduceMotion(v);
        },
      ),
      const SizedBox(height: 16),
      Text(
        'Escala de texto del chat',
        style: TextStyle(
          color: appTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Ajusta el tamaño global del texto en los mensajes',
        style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
      ),
      const SizedBox(height: 12),
      Consumer(
        builder: (context, ref, _) {
          final level = ref.watch(chatFontSizeProvider);
          const labels = ['Pequeño', 'Normal', 'Grande', 'Muy grande'];
          return Row(
            children: List.generate(4, (i) {
              final selected = level == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(labels[i]),
                  selected: selected,
                  onSelected: (_) {
                    ref.read(chatFontSizeProvider.notifier).setFontSize(i);
                  },
                  selectedColor: appTheme.primary.withValues(alpha: 0.3),
                  checkmarkColor: appTheme.primary,
                ),
              );
            }),
          );
        },
      ),
    ],
  );
}

Widget _buildSoundsSection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      _buildSwitchRow(
        appTheme,
        icon: Icons.notifications_off,
        title: 'No molestar',
        subtitle: 'Desactiva sonidos y notificaciones',
        value: ref.watch(notificationSettingsProvider).doNotDisturb,
        onChanged: (v) {
          ref.read(notificationSettingsProvider.notifier).setDoNotDisturb(v);
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.person,
        title: 'Sonido para privados',
        subtitle: 'Sonido al recibir mensaje privado',
        value: ref.watch(notificationSettingsProvider).soundForPrivates,
        onChanged: (_) {
          ref.read(notificationSettingsProvider.notifier).toggleSoundForPrivates();
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.alternate_email,
        title: 'Sonido para menciones',
        subtitle: 'Sonido al ser mencionado',
        value: ref.watch(notificationSettingsProvider).soundForMentions,
        onChanged: (_) {
          ref.read(notificationSettingsProvider.notifier).toggleSoundForMentions();
        },
      ),
      _buildSwitchRow(
        appTheme,
        icon: Icons.login,
        title: 'Sonido para entradas/salidas',
        subtitle: 'Sonido cuando alguien entra o sale del canal',
        value: ref.watch(notificationSettingsProvider).soundForJoinPart,
        onChanged: (_) {
          ref.read(notificationSettingsProvider.notifier).toggleSoundForJoinPart();
        },
      ),
    ],
  );
}

Widget _buildAvatarsSection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      Row(
        children: [
          Icon(
            Icons.image_outlined,
            color: appTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Avatar global (GIF)',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige un GIF como avatar. Se sube automáticamente al servidor (xmlrpc en ceres); los demás lo verán sin entrar en ninguna web.',
                  style: TextStyle(
                    color: appTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Consumer(
        builder: (context, ref, _) {
          final globalGif = ref.watch(globalAvatarGifProvider);
          return Row(
            children: [
              if (globalGif != null && globalGif.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildSettingsAvatarPreview(globalGif, appTheme),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['gif'],
                    withData: true,
                  );
                  if (result == null || result.files.isEmpty) return;
                  final file = result.files.single;
                  final bytes = file.bytes;
                  if (bytes == null || bytes.isEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudieron leer los datos del GIF.')),
                      );
                    }
                    return;
                  }
                  final dataUrl = 'data:image/gif;base64,${base64Encode(bytes)}';
                  if (!context.mounted) return;
                  _showAvatarGifConfirmDialog(context, ref, dataUrl, bytes, file.name);
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Subir GIF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: appTheme.textPrimary,
                ),
              ),
              if (globalGif != null && globalGif.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(globalAvatarGifProvider.notifier).clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Avatar GIF eliminado.')),
                      );
                    }
                  },
                  icon: Icon(Icons.delete_outline, size: 20, color: appTheme.textSecondary),
                  label: Text('Quitar', style: TextStyle(color: appTheme.textSecondary)),
                ),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Icon(Icons.auto_awesome, color: appTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generar Avatar SVG',
                  style: TextStyle(color: appTheme.textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Crea un avatar personalizado con el generador SVG',
                  style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Consumer(
        builder: (context, ref, _) {
          final currentNick = ref.watch(currentNicknameProvider);
          return ElevatedButton.icon(
            onPressed: currentNick != null && currentNick.isNotEmpty
                ? () {
                    launchUrl(
                      Uri.parse('https://avatar.globalchat.org/webchat-avatar.html?nick=$currentNick'),
                      mode: LaunchMode.externalApplication,
                    );
                  }
                : null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generar Avatar SVG'),
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.primary,
              foregroundColor: appTheme.textPrimary,
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      Consumer(
        builder: (context, ref, _) {
          final currentNick = ref.watch(currentNicknameProvider);
          return OutlinedButton.icon(
            onPressed: currentNick != null && currentNick.isNotEmpty
                ? () {
                    AvatarService.invalidateCache(currentNick);
                    AvatarService.invalidateAllCache();
                    ref.read(globalAvatarGifProvider.notifier).clear();
                    ref.read(avatarRefreshProvider.notifier).refreshAvatar(currentNick);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Avatar regenerado. Se actualizará en todos los lugares.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerar avatar (limpia GIF subido)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: appTheme.primary,
              side: BorderSide(color: appTheme.primary),
            ),
          );
        },
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Icon(
            Icons.airplanemode_active,
            color: appTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mensaje de Ausencia por Defecto',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mensaje que se usará cuando actives away sin especificar uno',
                  style: TextStyle(
                    color: appTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Consumer(
        builder: (context, ref, _) {
          final defaultMessage = ref.watch(defaultAwayMessageProvider) ?? '';
          final messageController = TextEditingController(text: defaultMessage);

          return TextField(
            controller: messageController,
            maxLines: 2,
            style: TextStyle(color: appTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ej: Estoy ocupado, volveré pronto',
              hintStyle: TextStyle(color: appTheme.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: appTheme.primary),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: appTheme.primary, width: 2),
              ),
              filled: true,
              fillColor: appTheme.background,
            ),
            onChanged: (value) {
              ref.read(defaultAwayMessageProvider.notifier).setMessage(value.trim().isEmpty ? null : value.trim());
            },
          );
        },
      ),
    ],
  );
}

Widget _buildQuickRepliesSection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      Text(
        'Frases que puedes insertar con un clic junto al campo de mensaje',
        style: TextStyle(fontSize: 14, color: appTheme.textSecondary),
      ),
      const SizedBox(height: 12),
      Consumer(
        builder: (context, ref, _) {
          final list = ref.watch(quickRepliesProvider);
          final notifier = ref.read(quickRepliesProvider.notifier);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Añade frases para usar como plantillas',
                    style: TextStyle(color: appTheme.textSecondary, fontStyle: FontStyle.italic),
                  ),
                )
              else
                ...List.generate(list.length, (i) {
                  return ListTile(
                    dense: true,
                    title: Text(list[i], style: TextStyle(color: appTheme.textPrimary)),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle_outline, color: appTheme.textSecondary, size: 20),
                      onPressed: () => notifier.removeQuickReplyAt(i),
                    ),
                  );
                }),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Nueva frase...',
                        hintStyle: TextStyle(color: appTheme.textSecondary),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      style: TextStyle(color: appTheme.textPrimary),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) {
                          notifier.addQuickReply(v.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.add_circle, color: appTheme.primary),
                    onPressed: () {
                      final c = TextEditingController();
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: appTheme.surface,
                          title: Text('Nueva respuesta rápida', style: TextStyle(color: appTheme.textPrimary)),
                          content: TextField(
                            controller: c,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Ej: ¡Hola!',
                              border: const OutlineInputBorder(),
                            ),
                            style: TextStyle(color: appTheme.textPrimary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
                            ),
                            TextButton(
                              onPressed: () {
                                if (c.text.trim().isNotEmpty) {
                                  notifier.addQuickReply(c.text.trim());
                                  Navigator.pop(ctx);
                                }
                              },
                              child: Text('Añadir', style: TextStyle(color: appTheme.primary)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}

Widget _buildBackgroundsSection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      Text(
        'Configura imágenes de fondo personalizadas para cada canal',
        style: TextStyle(
          fontSize: 14,
          color: appTheme.textSecondary,
        ),
      ),
      const SizedBox(height: 16),
      Consumer(
        builder: (context, ref, child) {
          final backgrounds = ref.watch(channelBackgroundProvider);
          return Column(
            children: [
              if (backgrounds.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No hay imágenes configuradas',
                    style: TextStyle(
                      color: appTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...backgrounds.entries.map((entry) {
                  return _buildBackgroundItem(
                    context,
                    ref,
                    appTheme,
                    entry.key,
                    entry.value,
                  );
                }),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _showAddBackgroundDialog(context, ref, appTheme),
                icon: const Icon(Icons.add),
                label: const Text('Agregar Imagen de Fondo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: appTheme.textPrimary,
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

Widget _buildHistorySection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      SwitchListTile(
        title: const Text('Mantener historial de chats y privados'),
        subtitle: const Text('Si está activado, se guardan las últimas 100 líneas de cada canal y privado entre sesiones'),
        value: ref.watch(historyEnabledProvider),
        onChanged: (value) {
          ref.read(historyEnabledProvider.notifier).setEnabled(value);
        },
        activeThumbColor: appTheme.primary,
      ),
      const SizedBox(height: 16),
      const Divider(),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => _showClearAllPrivateHistoryDialog(context, ref, appTheme),
        icon: const Icon(Icons.delete_sweep, color: Colors.red),
        label: const Text(
          'Borrar Todo el Historial de Privados',
          style: TextStyle(color: Colors.red),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Elimina todos los mensajes privados guardados de todas las conversaciones',
        style: TextStyle(
          fontSize: 12,
          color: appTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

Widget _buildBackupSection(BuildContext context, WidgetRef ref) {
  final appTheme = ref.watch(themeProvider);
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      Card(
        color: appTheme.surface,
        elevation: 2,
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.backup, color: appTheme.primary),
              title: const Text('Backup y Restauración'),
              subtitle: const Text('Crear o restaurar backup de la aplicación'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _createSettingsBackup(context),
                      icon: const Icon(Icons.save),
                      label: const Text('Crear Backup'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _restoreSettingsBackup(context),
                      icon: const Icon(Icons.restore),
                      label: const Text('Restaurar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Previsualización del avatar: soporta data URL (base64) y URL remota (http/https).
Widget _buildSettingsAvatarPreview(String urlOrDataUrl, AppTheme appTheme) {
  const size = 56.0;
  final placeholder = Icon(Icons.broken_image, size: size, color: appTheme.textSecondary);
  if (urlOrDataUrl.startsWith('data:image/gif;base64,')) {
    try {
      final base64Data = urlOrDataUrl.contains(',')
          ? urlOrDataUrl.substring(urlOrDataUrl.indexOf(',') + 1)
          : urlOrDataUrl;
      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) return placeholder;
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => placeholder,
      );
    } catch (_) {
      return placeholder;
    }
  }
  return Image.network(
    urlOrDataUrl,
    width: size,
    height: size,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    webHtmlElementStrategy: PlatformUtils.isWeb
        ? WebHtmlElementStrategy.prefer
        : WebHtmlElementStrategy.never,
    errorBuilder: (_, error, stackTrace) => placeholder,
  );
}

Widget _buildSettingsBackgroundPreview(String urlOrDataUrl, AppTheme appTheme) {
  const size = 50.0;
  final placeholder = Container(
    width: size,
    height: size,
    color: appTheme.primary.withValues(alpha: 0.1),
    alignment: Alignment.center,
    child: Icon(Icons.image, color: appTheme.primary),
  );

  if (urlOrDataUrl.trim().isEmpty) {
    return placeholder;
  }

  if (urlOrDataUrl.startsWith('data:image/')) {
    try {
      final base64Data = urlOrDataUrl.contains(',')
          ? urlOrDataUrl.substring(urlOrDataUrl.indexOf(',') + 1)
          : urlOrDataUrl;
      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) return placeholder;
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, error, stackTrace) => placeholder,
      );
    } catch (_) {
      return placeholder;
    }
  }

  return Image.network(
    urlOrDataUrl,
    width: size,
    height: size,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    webHtmlElementStrategy: PlatformUtils.isWeb
        ? WebHtmlElementStrategy.prefer
        : WebHtmlElementStrategy.never,
    errorBuilder: (_, error, stackTrace) => placeholder,
  );
}

void _showAvatarGifConfirmDialog(BuildContext context, WidgetRef ref, String dataUrl, List<int> bytes, String fileName) {
  final appTheme = ref.read(themeProvider);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: appTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.image, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Usar como avatar',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  fileName,
                  style: TextStyle(
                    color: appTheme.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildSettingsAvatarPreview(dataUrl, appTheme),
          ),
          const SizedBox(height: 12),
          Text(
            'Este GIF se mostrará como tu avatar animado. Los demás usuarios lo verán en los canales.',
            style: TextStyle(
              color: appTheme.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await ref.read(globalAvatarGifProvider.notifier).setGlobalAvatarGif(dataUrl);
            final currentNick = ref.read(currentNicknameProvider);
            if (currentNick != null && currentNick.trim().isNotEmpty) {
              var result = await AvatarService.uploadAvatarGif(currentNick, bytes);
              if (!result.success) {
                await Future.delayed(const Duration(seconds: 2));
                result = await AvatarService.uploadAvatarGif(currentNick, bytes);
              }
              if (result.success) {
                final remoteUrl = result.url ?? AvatarService.getAvatarGifUrl(currentNick);
                AvatarService.invalidateCache(currentNick);
                if (!PlatformUtils.isWeb) {
                  await ref.read(globalAvatarGifProvider.notifier).setGlobalAvatarGif(remoteUrl);
                }
              }
              if (!context.mounted) return;
              final String msg = result.success
                  ? 'Avatar subido. Los demás usuarios lo verán animado.'
                  : 'Avatar guardado aquí. No se pudo subir: ${result.errorMessage ?? "error"}.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
              );
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Avatar guardado. Se subirá cuando te conectes.')),
              );
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('Usar este GIF'),
          style: FilledButton.styleFrom(
            backgroundColor: appTheme.primary,
            foregroundColor: AppTheme.contrastOn(appTheme.primary),
          ),
        ),
      ],
    ),
  );
}

Widget _buildBackgroundItem(
  BuildContext context,
  WidgetRef ref,
  AppTheme appTheme,
  String channel,
  String imageUrl,
) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    color: appTheme.surface,
    child: ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildSettingsBackgroundPreview(imageUrl, appTheme),
      ),
      title: Text(
        channel,
        style: TextStyle(
          color: appTheme.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        imageUrl.length > 50 ? '${imageUrl.substring(0, 50)}...' : imageUrl,
        style: TextStyle(
          color: appTheme.textSecondary,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Eliminar Imagen'),
              content: Text('¿Eliminar la imagen de fondo del canal $channel?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await ref.read(channelBackgroundProvider.notifier).removeBackgroundForChannel(channel);
          }
        },
      ),
      onTap: () => _showEditBackgroundDialog(context, ref, appTheme, channel, imageUrl),
    ),
  );
}

Future<void> _showAddBackgroundDialog(
  BuildContext context,
  WidgetRef ref,
  AppTheme appTheme,
) async {
  final channelController = TextEditingController();
  final urlController = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Agregar Imagen de Fondo'),
      backgroundColor: appTheme.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: channelController,
            decoration: InputDecoration(
              labelText: 'Canal (ej: #nuestrasvoces)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: appTheme.background,
            ),
            style: TextStyle(color: appTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: urlController,
            decoration: InputDecoration(
              labelText: 'URL de la Imagen',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: appTheme.background,
              hintText: 'https://ejemplo.com/imagen.jpg',
            ),
            style: TextStyle(color: appTheme.textPrimary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final channel = channelController.text.trim();
            final url = urlController.text.trim();

            if (channel.isNotEmpty && url.isNotEmpty) {
              await ref.read(channelBackgroundProvider.notifier).setBackgroundForChannel(channel, url);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Imagen de fondo agregada para $channel'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

Future<void> _showEditBackgroundDialog(
  BuildContext context,
  WidgetRef ref,
  AppTheme appTheme,
  String channel,
  String currentUrl,
) async {
  final urlController = TextEditingController(text: currentUrl);

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Editar Imagen de Fondo - $channel'),
      backgroundColor: appTheme.surface,
      content: TextField(
        controller: urlController,
        decoration: InputDecoration(
          labelText: 'URL de la Imagen',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: appTheme.background,
        ),
        style: TextStyle(color: appTheme.textPrimary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final url = urlController.text.trim();
            await ref.read(channelBackgroundProvider.notifier).setBackgroundForChannel(channel, url);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Imagen de fondo actualizada para $channel'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

Future<void> _showClearAllPrivateHistoryDialog(
  BuildContext context,
  WidgetRef ref,
  AppTheme appTheme,
) async {
  await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: appTheme.surface,
      title: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Borrar todo el historial de privados',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ),
        ],
      ),
      content: Text(
        '¿Estás seguro de que quieres eliminar todos los mensajes privados guardados? Esta acción eliminará el historial de todas las conversaciones privadas y no se puede deshacer.',
        style: TextStyle(color: appTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancelar',
            style: TextStyle(color: appTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context, true);

            try {
              // Borrar de memoria
              ref.read(messagesProvider.notifier).clearPrivateMessages();

              // Borrar de base de datos
              final ircService = ref.read(ircServiceProvider);
              final server = ircService.serverHost;
              if (server != null) {
                await ChatHistoryService().deletePrivateMessages(server: server);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Todo el historial de privados ha sido eliminado correctamente'),
                    duration: Duration(seconds: 3),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error al borrar historial: $e'),
                    duration: const Duration(seconds: 3),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: const Text(
            'Borrar Todo',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

void _showCustomThemeEditor(BuildContext context, WidgetRef ref) {
  final appTheme = ref.read(themeProvider);
  final currentTheme = ref.read(themeProvider);
  var editTheme = currentTheme;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text('Tema personalizado',
            style: TextStyle(color: appTheme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildColorField(ctx, ref, editTheme, setDialogState, 'Primary',
                  (c) => editTheme = editTheme.copyWith(primary: c)),
              _buildColorField(ctx, ref, editTheme, setDialogState, 'Secondary',
                  (c) => editTheme = editTheme.copyWith(secondary: c)),
              _buildColorField(ctx, ref, editTheme, setDialogState, 'Accent',
                  (c) => editTheme = editTheme.copyWith(accent: c)),
              _buildColorField(ctx, ref, editTheme, setDialogState, 'Background',
                  (c) => editTheme = editTheme.copyWith(background: c)),
              _buildColorField(ctx, ref, editTheme, setDialogState, 'Surface',
                  (c) => editTheme = editTheme.copyWith(surface: c)),
              _buildColorField(ctx, ref, editTheme, setDialogState, 'Texto principal',
                  (c) => editTheme = editTheme.copyWith(textPrimary: c)),
              _buildColorField(ctx, ref, editTheme, setDialogState, 'Texto secundario',
                  (c) => editTheme = editTheme.copyWith(textSecondary: c)),
              _buildColorField(ctx, ref, editTheme, setDialogState, 'Error',
                  (c) => editTheme = editTheme.copyWith(error: c)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(themeProvider.notifier).setCustomTheme(editTheme);
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

Widget _buildColorField(
  BuildContext context,
  WidgetRef ref,
  AppTheme editTheme,
  void Function(void Function()) setDialogState,
  String label,
  void Function(Color) onChanged,
) {
  final color = _getColorValue(editTheme, label);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => _pickColor(context, ref, color, (c) {
            setDialogState(() => onChanged(c));
          }),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                color: editTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        SizedBox(
          width: 80,
          child: TextField(
            controller: TextEditingController(
              text: '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
            ),
            style: TextStyle(color: editTheme.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: editTheme.background,
            ),
            onSubmitted: (hex) {
              final parsed = _parseHexColor(hex);
              if (parsed != null) setDialogState(() => onChanged(parsed));
            },
          ),
        ),
      ],
    ),
  );
}

Color _getColorValue(AppTheme theme, String label) {
  switch (label) {
    case 'Primary': return theme.primary;
    case 'Secondary': return theme.secondary;
    case 'Accent': return theme.accent;
    case 'Background': return theme.background;
    case 'Surface': return theme.surface;
    case 'Texto principal': return theme.textPrimary;
    case 'Texto secundario': return theme.textSecondary;
    case 'Error': return theme.error;
    default: return theme.primary;
  }
}

Color? _parseHexColor(String hex) {
  try {
    hex = hex.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
  } catch (_) {}
  return null;
}

void _pickColor(BuildContext context, WidgetRef ref, Color current, void Function(Color) onPicked) {
  final appTheme = ref.read(themeProvider);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: appTheme.surface,
      title: Text('Seleccionar color',
          style: TextStyle(color: appTheme.textPrimary)),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
            Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
            Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
            Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
            Colors.brown, Colors.grey, Colors.blueGrey, Colors.white,
            Colors.black, Colors.transparent,
          ].map((c) => GestureDetector(
            onTap: () {
              onPicked(c);
              Navigator.of(ctx).pop();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
          )).toList(),
        ),
      ),
    ),
  );
}
