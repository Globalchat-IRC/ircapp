import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_theme.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';

/// Diálogo para gestionar los modos del canal (editor gráfico estilo KiwiIRC).
/// Muestra interruptores para los modos más comunes (+i, +m, +n, +t, +s, +k, +l)
/// y los aplica en tiempo real contra el servidor.
class ChannelModesDialog extends ConsumerStatefulWidget {
  final String channel;

  const ChannelModesDialog({super.key, required this.channel});

  @override
  ConsumerState<ChannelModesDialog> createState() =>
      _ChannelModesDialogState();
}

class _ChannelModesDialogState extends ConsumerState<ChannelModesDialog> {
  static final Map<String, (String, IconData, String)> _modeInfo = {
    'i': ('Solo invitados', Icons.person_add_alt_1, 'Solo pueden entrar usuarios invitados (+i).'),
    'm': ('Moderado', Icons.record_voice_over, 'Solo los usuarios con voz (+v) pueden hablar.'),
    'n': ('Sin externos', Icons.volume_off, 'Bloquea mensajes de usuarios que no están en el canal.'),
    't': ('Topic protegido', Icons.policy, 'Solo operadores pueden cambiar el tema.'),
    's': ('Canal secreto', Icons.visibility_off, 'El canal no aparece en la lista (/list).'),
    'k': ('Clave', Icons.key, 'Requiere una clave para entrar.'),
    'l': ('Límite', Icons.numbers, 'Máximo de usuarios simultáneos.'),
  };

  String get _normalized => widget.channel.toLowerCase();

  @override
  void initState() {
    super.initState();
    // Solicitar los modos actuales al abrir (respuesta: numerico 324)
    ref.read(ircServiceProvider).requestChannelModes(widget.channel);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final channelData = ref.watch(channelsProvider)[_normalized];

    return AlertDialog(
      backgroundColor: appTheme.surface,
      title: Row(
        children: [
          Icon(Icons.shield_outlined, color: appTheme.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modos del canal',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.channel,
                      style: TextStyle(
                        color: appTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    channelData?.modeString.isNotEmpty == true
                        ? channelData!.modeString
                        : 'Sin modos especiales',
                    style: TextStyle(
                      color: appTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: appTheme.textSecondary),
                    tooltip: 'Recargar modos',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () => ref
                        .read(ircServiceProvider)
                        .requestChannelModes(widget.channel),
                  ),
                ],
              ),
              const Divider(height: 8),
              ..._modeInfo.entries.map(
                (entry) => _buildModeTile(
                  appTheme,
                  entry.key,
                  entry.value.$1,
                  entry.value.$2,
                  entry.value.$3,
                  channelData?.hasChannelMode(entry.key) ?? false,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Los cambios se aplican de inmediato.',
                style: TextStyle(
                  color: appTheme.textSecondary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar', style: TextStyle(color: appTheme.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildModeTile(
    AppTheme appTheme,
    String mode,
    String label,
    IconData icon,
    String description,
    bool enabled,
  ) {
    return Tooltip(
      message: description,
      child: SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeThumbColor: appTheme.primary,
        activeTrackColor: appTheme.primary.withValues(alpha: 0.4),
        title: Row(
          children: [
            Icon(icon, size: 20, color: appTheme.primary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: appTheme.textPrimary)),
          ],
        ),
        secondary: Container(
          width: 34,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: enabled
                ? appTheme.primary.withValues(alpha: 0.2)
                : appTheme.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: enabled ? appTheme.primary : appTheme.textSecondary,
              width: 1,
            ),
          ),
          child: Text(
            '+$mode',
            style: TextStyle(
              color: enabled ? appTheme.primary : appTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        value: enabled,
        onChanged: (value) => _onToggle(mode, value),
      ),
    );
  }

  Future<void> _onToggle(String mode, bool enable) async {
    final ircService = ref.read(ircServiceProvider);
    final context = this.context;

    if (mode == 'k') {
      if (enable) {
        final key = await _promptText(
          context,
          'Establecer clave del canal',
          'Escribe la clave (dejar vacío para cancelar)',
          isPassword: true,
        );
        if (key == null || key.isEmpty || !context.mounted) return;
        ircService.setChannelKey(widget.channel, key);
        _showSnackBar(context, 'Clave establecida');
      } else {
        ircService.setChannelKey(widget.channel, null);
        _showSnackBar(context, 'Clave eliminada');
      }
      return;
    }

    if (mode == 'l') {
      if (enable) {
        final limit = await _promptNumber(
          context,
          'Establecer límite de usuarios',
          'Máximo de usuarios simultáneos',
        );
        if (limit == null || !context.mounted) return;
        ircService.setChannelLimit(widget.channel, limit);
        _showSnackBar(context, 'Límite fijado a $limit');
      } else {
        ircService.setChannelLimit(widget.channel, null);
        _showSnackBar(context, 'Límite eliminado');
      }
      return;
    }

    ircService.toggleChannelMode(widget.channel, mode, enable);
  }

  Future<String?> _promptText(
    BuildContext context,
    String title,
    String label, {
    bool isPassword = false,
  }) {
    final appTheme = ref.read(themeProvider);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(title, style: TextStyle(color: appTheme.textPrimary)),
        content: TextField(
          controller: controller,
          obscureText: isPassword,
          autofocus: true,
          style: TextStyle(color: appTheme.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: appTheme.textSecondary),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: appTheme.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: appTheme.primary, width: 2),
            ),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(color: appTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<int?> _promptNumber(
    BuildContext context,
    String title,
    String label,
  ) {
    final appTheme = ref.read(themeProvider);
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(title, style: TextStyle(color: appTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: TextStyle(color: appTheme.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: appTheme.textSecondary),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: appTheme.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: appTheme.primary, width: 2),
            ),
          ),
          onSubmitted: (value) =>
              Navigator.pop(dialogContext, int.tryParse(value)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: TextStyle(color: appTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text)),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
