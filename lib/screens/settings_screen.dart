import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/channel_background_provider.dart';
import '../providers/history_provider.dart';
import '../models/app_theme.dart';
import '../services/backup_service.dart';
import '../services/cache_service.dart';
import 'privacy_settings_screen.dart';
import 'robots_settings_screen.dart';
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
                  const SizedBox(height: 24),
                  // Opción para mostrar/ocultar hora
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: appTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Mostrar hora en mensajes',
                            style: TextStyle(
                              color: appTheme.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: formatPrefs.showTimestamp,
                        onChanged: (value) {
                          ref
                              .read(messageFormatPreferencesProvider.notifier)
                              .setShowTimestamp(value);
                        },
                        activeColor: appTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Tamaño de fuente para canales
                  Text(
                    'Tamaño de fuente en Canales',
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
                        child: Slider(
                          value: formatPrefs.channelFontSize,
                          min: 10.0,
                          max: 30.0,
                          divisions: 20,
                          label: '${formatPrefs.channelFontSize.toStringAsFixed(0)}px',
                          onChanged: (value) {
                            ref
                                .read(messageFormatPreferencesProvider.notifier)
                                .setChannelFontSize(value);
                          },
                          activeColor: appTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: appTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: appTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${formatPrefs.channelFontSize.toStringAsFixed(0)}px',
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
                  const SizedBox(height: 24),
                  // Tipo de fuente para canales
                  Text(
                    'Tipo de fuente en Canales',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: appTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: formatPrefs.channelFontFamily,
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
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(messageFormatPreferencesProvider.notifier)
                            .setChannelFontFamily(value);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  // Tamaño de fuente para privados
                  Text(
                    'Tamaño de fuente en Privados',
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
                        child: Slider(
                          value: formatPrefs.privateFontSize,
                          min: 10.0,
                          max: 30.0,
                          divisions: 20,
                          label: '${formatPrefs.privateFontSize.toStringAsFixed(0)}px',
                          onChanged: (value) {
                            ref
                                .read(messageFormatPreferencesProvider.notifier)
                                .setPrivateFontSize(value);
                          },
                          activeColor: appTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: appTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: appTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${formatPrefs.privateFontSize.toStringAsFixed(0)}px',
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
                  const SizedBox(height: 24),
                  // Tipo de fuente para privados
                  Text(
                    'Tipo de fuente en Privados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: appTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: formatPrefs.privateFontFamily,
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
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(messageFormatPreferencesProvider.notifier)
                            .setPrivateFontFamily(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Sección de Imágenes de Fondo por Canal
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
                        Icons.image,
                        color: appTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Imágenes de Fondo por Canal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: appTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
          
          // Sección de Historial de Mensajes
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
                        Icons.history,
                        color: appTheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Historial de Mensajes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: appTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Mantener historial de chats y privados'),
                    subtitle: const Text('Si está activado, los mensajes se guardarán y se mantendrán entre sesiones'),
                    value: ref.watch(historyEnabledProvider),
                    onChanged: (value) {
                      ref.read(historyEnabledProvider.notifier).setEnabled(value);
                    },
                    activeColor: appTheme.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Sección de Gestión de Robots
          Card(
            color: appTheme.surface,
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.smart_toy, color: appTheme.primary),
              title: const Text('Gestión de Robots'),
              subtitle: const Text('Añadir robots y asignarles iconos personalizados'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const RobotsSettingsScreen(),
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
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: NetworkImage(imageUrl),
              fit: BoxFit.cover,
              onError: (exception, stackTrace) {},
            ),
            color: appTheme.primary.withOpacity(0.1),
          ),
          child: imageUrl.isEmpty
              ? Icon(Icons.image, color: appTheme.primary)
              : null,
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
}

