import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../services/backup_service.dart';
import '../services/cache_service.dart';
import 'privacy_settings_screen.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 16),
          
          // Sección de Privacidad
          Card(
            color: appTheme.surface,
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.privacy_tip, color: appTheme.primary),
              title: const Text('Privacidad'),
              subtitle: const Text('Configurar privacidad y modo incógnito'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacySettingsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Sección de Backup
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
                          onPressed: () => _createBackup(context),
                          icon: const Icon(Icons.save),
                          label: const Text('Crear Backup'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _restoreBackup(context),
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
          const SizedBox(height: 16),
          
          // Sección de Cache
          Card(
            color: appTheme.surface,
            elevation: 2,
            child: FutureBuilder<int>(
              future: _getCacheSize(),
              builder: (context, snapshot) {
                final cacheSize = snapshot.data ?? 0;
                final cacheSizeMB = (cacheSize / (1024 * 1024)).toStringAsFixed(2);
                
                return Column(
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
                              onPressed: () => _clearCache(context),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Limpiar Cache'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Future<int> _getCacheSize() async {
    final cacheService = CacheService();
    await cacheService.initialize();
    return await cacheService.getCacheSize();
  }
  
  Future<void> _createBackup(BuildContext context) async {
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
  
  Future<void> _restoreBackup(BuildContext context) async {
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
  
  Future<void> _clearCache(BuildContext context) async {
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
        setState(() {}); // Refrescar para actualizar el tamaño
      }
    }
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

