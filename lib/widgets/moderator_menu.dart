import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import 'channel_ban_list_dialog.dart';

class ModeratorMenu extends ConsumerWidget {
  final String channel;
  final String targetNick;

  const ModeratorMenu({
    super.key,
    required this.channel,
    required this.targetNick,
  });

  // Verificar si el usuario actual es moderador/fundador
  bool _isModerator(WidgetRef ref, String channel) {
    final ircService = ref.read(ircServiceProvider);
    final currentNick = ircService.nickname;
    if (currentNick == null) return false;

    final channelData = ircService.allChannels[channel];
    if (channelData == null) return false;

    final userMode = channelData.userModes[currentNick];
    // @ = op, & = founder/owner, % = halfop, ! = admin
    return userMode == '@' || userMode == '&' || userMode == '%' || userMode == '!';
  }

  // Verificar si el usuario actual es fundador
  bool _isFounder(WidgetRef ref, String channel) {
    final ircService = ref.read(ircServiceProvider);
    final currentNick = ircService.nickname;
    if (currentNick == null) return false;

    final channelData = ircService.allChannels[channel];
    if (channelData == null) return false;

    final userMode = channelData.userModes[currentNick];
    return userMode == '&' || userMode == '!';
  }

  // Detectar si un nick es un bot antes de hacer WHOIS
  bool _isBotNick(WidgetRef ref, String nick) {
    final nickLower = nick.toLowerCase().trim();
    
    // Verificación básica por nick
    final isBotByNick = nickLower.endsWith('bot') ||
                        nickLower.startsWith('radio') ||
                        nickLower == 'robot' ||
                        nickLower == 'bot' ||
                        nickLower == 'globalchat';
    
    if (isBotByNick) {
      return true;
    }
    
    // Verificar usando información del canal si está disponible
    final ircService = ref.read(ircServiceProvider);
    final channelData = ircService.allChannels[channel];
    
    if (channelData != null) {
      // Verificar modo +b (bot mode)
      final userMode = channelData.userModes[nickLower];
      if (userMode == '+b' && nickLower.endsWith('bot')) {
        return true;
      }
      
      // Verificar host
      final host = channelData.userHosts[nickLower]?.toLowerCase() ?? '';
      if (host.isNotEmpty) {
        final isBotByHost = host == 'robot.globalchat.org' ||
                            host.endsWith('.robot.globalchat.org') ||
                            (host.startsWith('robot.') && host.contains('globalchat.org') && !host.contains('netadmin') && !host.contains('admin'));
        if (isBotByHost) {
          return true;
        }
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    final ircService = ref.read(ircServiceProvider);

    if (!_isModerator(ref, channel)) {
      return const SizedBox.shrink();
    }

    final isFounder = _isFounder(ref, channel);
    final channelData = ircService.allChannels[channel];
    final targetMode = channelData?.userModes[targetNick];

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.admin_panel_settings,
        color: appTheme.textPrimary,
        size: 20,
      ),
      tooltip: 'Menú de Moderador',
      color: appTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: appTheme.primary, width: 1),
      ),
      onSelected: (value) => _handleAction(ref, value, context),
      itemBuilder: (context) => [
        // === ACCIONES BÁSICAS ===
        PopupMenuItem<String>(
          value: 'kick',
          child: Row(
            children: [
              Icon(Icons.person_remove, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('Expulsar', style: TextStyle(color: appTheme.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'ban',
          child: Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text('Banear', style: TextStyle(color: appTheme.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'unban',
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text('Desbanear', style: TextStyle(color: appTheme.textPrimary)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // === PERMISOS DE CANAL ===
        PopupMenuItem<String>(
          value: targetMode == '@' ? 'deop' : 'op',
          enabled: isFounder || targetMode != '@',
          child: Row(
            children: [
              Icon(
                targetMode == '@' ? Icons.remove_moderator : Icons.admin_panel_settings,
                color: targetMode == '@' ? Colors.orange : appTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                targetMode == '@' ? 'Quitar OP' : 'Dar OP',
                style: TextStyle(
                  color: targetMode == '@' 
                      ? Colors.orange 
                      : (isFounder || targetMode != '@' ? appTheme.textPrimary : appTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: targetMode == '+' ? 'devoice' : 'voice',
          child: Row(
            children: [
              Icon(
                targetMode == '+' ? Icons.mic_off : Icons.mic,
                color: targetMode == '+' ? Colors.orange : appTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                targetMode == '+' ? 'Quitar Voz' : 'Dar Voz',
                style: TextStyle(color: appTheme.textPrimary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        // === COMANDOS CHANSERV (ANOPE) ===
        if (isFounder) ...[
          PopupMenuItem<String>(
            value: 'chanserv_set',
            child: Row(
              children: [
                Icon(Icons.settings, color: appTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('ChanServ SET', style: TextStyle(color: appTheme.textPrimary)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'chanserv_access',
            child: Row(
              children: [
                Icon(Icons.security, color: appTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('ChanServ ACCESS', style: TextStyle(color: appTheme.textPrimary)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'chanserv_flags',
            child: Row(
              children: [
                Icon(Icons.flag, color: appTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('ChanServ FLAGS', style: TextStyle(color: appTheme.textPrimary)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'chanserv_topic',
            child: Row(
              children: [
                Icon(Icons.topic, color: appTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('ChanServ TOPIC', style: TextStyle(color: appTheme.textPrimary)),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        // === OTRAS ACCIONES ===
        PopupMenuItem<String>(
          value: 'banlist',
          child: Row(
            children: [
              Icon(Icons.gavel, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text('Lista de baneados', style: TextStyle(color: appTheme.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'whois',
          child: Row(
            children: [
              Icon(Icons.info, color: appTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('WHOIS', style: TextStyle(color: appTheme.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'ignore',
          child: Row(
            children: [
              Icon(Icons.visibility_off, color: appTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Ignorar', style: TextStyle(color: appTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  void _handleAction(WidgetRef ref, String action, BuildContext context) {
    final ircService = ref.read(ircServiceProvider);

    switch (action) {
      case 'kick':
        _showKickDialog(ref, context);
        break;
      case 'ban':
        ircService.banUser(channel, targetNick);
        _showSnackBar(
          context,
          'Usuario baneado: $targetNick',
          actionLabel: 'Ver bans',
          onAction: () => _openBanList(ref, context),
        );
        break;
      case 'unban':
        // El baneado suele estar fuera del canal: además de intentar el -b,
        // ofrecemos abrir la lista de bans para quitar la máscara exacta.
        ircService.unbanUser(channel, targetNick);
        _showSnackBar(
          context,
          'Desbaneando $targetNick… si estaba baneado por máscara, usa la lista de bans',
          actionLabel: 'Ver bans',
          onAction: () => _openBanList(ref, context),
        );
        break;
      case 'op':
        ircService.setChannelMode(channel, '+o', targetNick);
        _showSnackBar(context, 'OP dado a: $targetNick');
        break;
      case 'deop':
        ircService.setChannelMode(channel, '-o', targetNick);
        _showSnackBar(context, 'OP quitado a: $targetNick');
        break;
      case 'voice':
        ircService.setChannelMode(channel, '+v', targetNick);
        _showSnackBar(context, 'Voz dada a: $targetNick');
        break;
      case 'devoice':
        ircService.setChannelMode(channel, '-v', targetNick);
        _showSnackBar(context, 'Voz quitada a: $targetNick');
        break;
      case 'chanserv_set':
        _showChanServDialog(ref, context, 'SET');
        break;
      case 'chanserv_access':
        _showChanServDialog(ref, context, 'ACCESS');
        break;
      case 'chanserv_flags':
        _showChanServDialog(ref, context, 'FLAGS');
        break;
      case 'chanserv_topic':
        _showChanServDialog(ref, context, 'TOPIC');
        break;
      case 'whois':
        // Verificar si es un bot antes de hacer WHOIS
        if (_isBotNick(ref, targetNick)) {
          _showSnackBar(context, 'Los bots no responden a WHOIS. No se realizará la consulta para $targetNick.');
        } else {
          ircService.sendWhois(targetNick);
          _showSnackBar(context, 'WHOIS enviado para: $targetNick');
        }
        break;
      case 'ignore':
        ircService.sendIgnore(targetNick);
        _showSnackBar(context, 'Usuario ignorado: $targetNick');
        break;
      case 'banlist':
        _openBanList(ref, context);
        break;
    }
  }

  void _openBanList(WidgetRef ref, BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => ChannelBanListDialog(channel: channel),
    );
  }

  void _showKickDialog(WidgetRef ref, BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          'Expulsar usuario',
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Usuario: $targetNick',
              style: TextStyle(color: appTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (opcional)',
                labelStyle: TextStyle(color: appTheme.textSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: appTheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: appTheme.primary, width: 2),
                ),
              ),
              style: TextStyle(color: appTheme.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final ircService = ref.read(ircServiceProvider);
              final reason = reasonController.text.trim();
              ircService.kickUser(channel, targetNick, reason.isEmpty ? null : reason);
              Navigator.pop(context);
              _showSnackBar(context, 'Usuario expulsado: $targetNick');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );
  }

  void _showChanServDialog(WidgetRef ref, BuildContext context, String command) {
    final appTheme = ref.read(themeProvider);
    final inputController = TextEditingController();

    String dialogTitle;
    String hintText;
    String exampleText;

    switch (command) {
      case 'SET':
        dialogTitle = 'ChanServ SET';
        hintText = 'Ej: FOUNDER nick, SECURE ON, KEEPTOPIC ON';
        exampleText = 'FOUNDER $targetNick';
        break;
      case 'ACCESS':
        dialogTitle = 'ChanServ ACCESS';
        hintText = 'Ej: LIST, ADD nick flags, DEL nick';
        exampleText = 'LIST';
        break;
      case 'FLAGS':
        dialogTitle = 'ChanServ FLAGS';
        hintText = 'Ej: LIST, SET nick +flags';
        exampleText = 'SET $targetNick +AOV';
        break;
      case 'TOPIC':
        dialogTitle = 'ChanServ TOPIC';
        hintText = 'Ej: SET #canal :tema, LOCK, UNLOCK';
        exampleText = 'SET $channel :Nuevo tema';
        break;
      default:
        dialogTitle = 'ChanServ $command';
        hintText = 'Ingrese los parámetros';
        exampleText = '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(
          dialogTitle,
          style: TextStyle(color: appTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hintText,
              style: TextStyle(
                color: appTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ejemplo: $exampleText',
              style: TextStyle(
                color: appTheme.primary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: inputController,
              decoration: InputDecoration(
                labelText: 'Parámetros',
                labelStyle: TextStyle(color: appTheme.textSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: appTheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: appTheme.primary, width: 2),
                ),
              ),
              style: TextStyle(color: appTheme.textPrimary),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: appTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final ircService = ref.read(ircServiceProvider);
              final params = inputController.text.trim();
              // Enviar comando a ChanServ
              ircService.sendChanServCommand(channel, command, params.isNotEmpty ? params : null);
              Navigator.pop(context);
              _showSnackBar(context, 'Comando ChanServ $command enviado');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.primary,
            ),
            child: Text('Enviar', style: TextStyle(color: appTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }
}

