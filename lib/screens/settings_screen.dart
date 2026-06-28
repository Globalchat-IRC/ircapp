import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/channel_background_provider.dart';
import '../providers/history_provider.dart';
import '../models/app_theme.dart';
import '../services/backup_service.dart';
import '../services/cache_service.dart';
import '../services/chat_history_service.dart';
import '../services/avatar_service.dart';
import '../utils/platform_utils.dart';
import 'privacy_settings_screen.dart';
import 'robots_settings_screen.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Previsualización del avatar: soporta data URL (base64) y URL remota (http/https).
  Widget _buildAvatarPreview(String urlOrDataUrl, AppTheme appTheme) {
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

  Widget _buildBackgroundPreview(String urlOrDataUrl, AppTheme appTheme) {
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
                  const SizedBox(height: 24),
                  // NOTICE en mensajes privados
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Usar NOTICE en privados',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: appTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Si está activado, los mensajes privados se envían como NOTICE (el otro usuario no puede responder automáticamente).',
                              style: TextStyle(
                                fontSize: 12,
                                color: appTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: ref.watch(useNoticeForPrivateProvider),
                        onChanged: (value) {
                          ref.read(useNoticeForPrivateProvider.notifier).setValue(value);
                        },
                        activeThumbColor: appTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Tamaño global de emoticonos
                  Text(
                    'Tamaño de emoticonos',
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
                          value: formatPrefs.emojiSize,
                          min: 16.0,
                          max: 80.0,
                          divisions: 64,
                          label: '${formatPrefs.emojiSize.toStringAsFixed(0)}px',
                          onChanged: (value) {
                            ref
                                .read(messageFormatPreferencesProvider.notifier)
                                .setEmojiSize(value);
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
                            color: appTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${formatPrefs.emojiSize.toStringAsFixed(0)}px',
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
                  // Tamaño global de avatares
                  Text(
                    'Tamaño de avatares',
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
                          value: formatPrefs.avatarScale,
                          min: 0.6,
                          max: 1.6,
                          divisions: 20,
                          label: '${(formatPrefs.avatarScale * 100).toStringAsFixed(0)}%',
                          onChanged: (value) {
                            ref
                                .read(messageFormatPreferencesProvider.notifier)
                                .setAvatarScale(value);
                          },
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
                          '${(formatPrefs.avatarScale * 100).toStringAsFixed(0)}%',
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
                  // Opción para activar/desactivar hilos en canales
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.reply,
                            color: appTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hilos de conversación en canales',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Permite responder a mensajes y crear hilos de conversación',
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
                      Switch(
                        value: formatPrefs.enableThreadsInChannels,
                        onChanged: (value) {
                          ref
                              .read(messageFormatPreferencesProvider.notifier)
                              .setEnableThreadsInChannels(value);
                        },
                        activeThumbColor: appTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Opción para activar/desactivar reacciones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.add_reaction,
                            color: appTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reacciones en mensajes',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Permite reaccionar a mensajes con emojis',
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
                      Switch(
                        value: formatPrefs.enableReactions,
                        onChanged: (value) {
                          ref
                              .read(messageFormatPreferencesProvider.notifier)
                              .setEnableReactions(value);
                        },
                        activeThumbColor: appTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Opción para activar/desactivar avatares animados
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.motion_photos_auto,
                            color: appTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Avatares animados',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Permite usar avatares GIF animados en los nicks (puede consumir más CPU/RAM).',
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
                      Switch(
                        value: formatPrefs.enableAnimatedAvatars,
                        onChanged: (value) {
                          ref
                              .read(messageFormatPreferencesProvider.notifier)
                              .setEnableAnimatedAvatars(value);
                        },
                        activeThumbColor: appTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Avatar global (GIF)
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
                              child: _buildAvatarPreview(globalGif, appTheme),
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
                              await ref.read(globalAvatarGifProvider.notifier).setGlobalAvatarGif(dataUrl);
                              final currentNick = ref.read(currentNicknameProvider);
                              if (currentNick != null && currentNick.trim().isNotEmpty) {
                                // Subir a xmlrpc en cuanto el usuario elige el GIF; sin que tenga que hacer nada más
                                var result = await AvatarService.uploadAvatarGif(currentNick, bytes);
                                if (!result.success) {
                                  await Future.delayed(const Duration(seconds: 2));
                                  result = await AvatarService.uploadAvatarGif(currentNick, bytes);
                                }
                                // Si la subida ha tenido éxito, actualizar el valor guardado a la URL remota
                                if (result.success) {
                                  final remoteUrl = result.url ?? AvatarService.getAvatarGifUrl(currentNick);
                                  if (!PlatformUtils.isWeb) {
                                    await ref.read(globalAvatarGifProvider.notifier).setGlobalAvatarGif(remoteUrl);
                                  }
                                }
                                if (!context.mounted) return;
                                final String msg = result.success
                                    ? 'Avatar subido a xmlrpc. Los demás usuarios lo verán animado.'
                                    : 'Avatar guardado aquí. No se pudo subir: ${result.errorMessage ?? "error"}. Se reintentará al conectar.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(msg),
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Avatar guardado. Se subirá a xmlrpc automáticamente cuando te conectes.')),
                                );
                              }
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
                  // Mensaje de away por defecto
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
                        activeThumbColor: appTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                          Icon(
                            Icons.account_circle_outlined,
                            color: appTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mostrar avatar junto al nick en canales',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Activa o desactiva el avatar pequeno que aparece antes del nick en los mensajes del canal.',
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
                      ),
                      Switch(
                        value: formatPrefs.showInlineChannelAvatar,
                        onChanged: (value) {
                          ref
                              .read(messageFormatPreferencesProvider.notifier)
                              .setShowInlineChannelAvatar(value);
                        },
                        activeThumbColor: appTheme.primary,
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
                            color: appTheme.primary.withValues(alpha: 0.3),
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
                    initialValue: formatPrefs.channelFontFamily,
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
                            color: appTheme.primary.withValues(alpha: 0.3),
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
                  // Escala global de texto del chat (accesibilidad)
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: appTheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                          ],
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 24),
                  // Reducir animaciones (accesibilidad)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.motion_photos_off, color: appTheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reducir animaciones',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Menos movimiento en la interfaz (accesibilidad)',
                                  style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          return Switch(
                            value: ref.watch(reduceMotionProvider),
                            onChanged: (v) {
                              ref.read(reduceMotionProvider.notifier).setReduceMotion(v);
                            },
                            activeThumbColor: appTheme.primary,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // No molestar (notificaciones)
                  Consumer(
                    builder: (context, ref, _) {
                      final doNotDisturb = ref.watch(notificationSettingsProvider).doNotDisturb;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications_off, color: appTheme.primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No molestar',
                                      style: TextStyle(
                                        color: appTheme.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Desactiva sonidos y notificaciones',
                                      style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: doNotDisturb,
                            onChanged: (v) {
                              ref.read(notificationSettingsProvider.notifier).setDoNotDisturb(v);
                            },
                            activeThumbColor: appTheme.primary,
                          ),
                        ],
                      );
                    },
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
                    initialValue: formatPrefs.privateFontFamily,
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
          // Estadísticas de sesión (mensajes enviados)
          Consumer(
            builder: (context, ref, _) {
              final messages = ref.watch(messagesProvider);
              final currentNick = ref.watch(currentNicknameProvider);
              final sentCount = currentNick == null
                  ? 0
                  : messages.where((m) => m.nick == currentNick && !m.isSystem).length;
              return Card(
                color: appTheme.surface,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bar_chart, color: appTheme.primary, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            'Estadísticas de sesión',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: appTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mensajes enviados en esta sesión: $sentCount',
                        style: TextStyle(fontSize: 14, color: appTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Respuestas rápidas (plantillas)
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
                      Icon(Icons.quickreply, color: appTheme.primary, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Respuestas rápidas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: appTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                          const SizedBox(height: 8),
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
                    activeThumbColor: appTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Botón para borrar todo el historial de privados
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
          child: _buildBackgroundPreview(imageUrl, appTheme),
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
}

