import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_theme.dart';
import '../models/irc_message.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';

/// Diálogo con la lista de baneados del canal (modo +b).
/// Permite ver las máscaras baneadas, quién las puso y cuándo, desbanearlas
/// y añadir nuevos bans. La lista se rellena con los numerics 367/368.
class ChannelBanListDialog extends ConsumerStatefulWidget {
  final String channel;

  const ChannelBanListDialog({super.key, required this.channel});

  @override
  ConsumerState<ChannelBanListDialog> createState() =>
      _ChannelBanListDialogState();
}

class _ChannelBanListDialogState extends ConsumerState<ChannelBanListDialog> {
  String get _normalized => widget.channel.toLowerCase();

  @override
  void initState() {
    super.initState();
    // Solicitar la lista de bans al abrir (respuestas: 367/368)
    ref.read(ircServiceProvider).requestBanList(widget.channel);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final channelData = ref.watch(channelsProvider)[_normalized];
    final bans = channelData?.bans ?? const <ChannelBan>[];

    return AlertDialog(
      backgroundColor: appTheme.surface,
      title: Row(
        children: [
          Icon(Icons.gavel_outlined, color: appTheme.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lista de baneados',
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
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
                  '${bans.length} ban(s)',
                  style: TextStyle(
                    color: appTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: appTheme.textSecondary),
                  tooltip: 'Recargar lista de bans',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => ref
                      .read(ircServiceProvider)
                      .requestBanList(widget.channel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: bans.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: appTheme.textSecondary,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay usuarios baneados',
                            style: TextStyle(color: appTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: bans.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: appTheme.textSecondary.withValues(alpha: 0.2),
                      ),
                      itemBuilder: (context, index) {
                        final ban = bans[index];
                        return _buildBanTile(appTheme, ban);
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _showAddBanDialog(context),
          child: Text('Añadir ban', style: TextStyle(color: appTheme.primary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar', style: TextStyle(color: appTheme.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildBanTile(AppTheme appTheme, ChannelBan ban) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.block, color: Colors.redAccent, size: 22),
      title: Text(
        ban.mask,
        style: TextStyle(
          color: appTheme.textPrimary,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        _banSubtitle(ban),
        style: TextStyle(color: appTheme.textSecondary, fontSize: 11),
      ),
      trailing: IconButton(
        icon: Icon(Icons.remove_circle_outline, color: Colors.redAccent),
        tooltip: 'Desbanear ${ban.mask}',
        onPressed: () => _unban(ban.mask),
      ),
    );
  }

  String _banSubtitle(ChannelBan ban) {
    final parts = <String>[];
    if (ban.setter.isNotEmpty) parts.add('por ${ban.setter}');
    if (ban.time != null) {
      final local = ban.time!.toLocal();
      parts.add(
        '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}',
      );
    }
    return parts.join(' · ');
  }

  void _unban(String mask) {
    final ircService = ref.read(ircServiceProvider);
    ircService.unbanMask(widget.channel, mask);
    _showSnackBar(context, 'Ban eliminado: $mask');
  }

  void _showAddBanDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Banear usuario o máscara',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: appTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Nick o máscara (p. ej. nick!*@host)',
            labelStyle: TextStyle(color: appTheme.textSecondary),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: appTheme.primary),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: appTheme.primary, width: 2),
            ),
          ),
          onSubmitted: (value) => _submitBan(value),
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
            onPressed: () => _submitBan(controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Banear'),
          ),
        ],
      ),
    );
  }

  void _submitBan(String mask) {
    if (mask.isEmpty) return;
    final ircService = ref.read(ircServiceProvider);
    ircService.banUser(widget.channel, mask);
    _showSnackBar(context, 'Ban enviado para: $mask');
    Navigator.pop(context);
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
