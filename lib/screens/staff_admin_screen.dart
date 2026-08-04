import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/staff_access.dart';
import '../models/app_theme.dart';
import '../models/whois_info.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../services/irc_service.dart';

class StaffAdminScreen extends ConsumerStatefulWidget {
  const StaffAdminScreen({super.key});

  @override
  ConsumerState<StaffAdminScreen> createState() => _StaffAdminScreenState();
}

class _StaffAdminScreenState extends ConsumerState<StaffAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  IRCService? _ircService;
  WhoisInfo? _lastWhois;
  bool _searching = false;
  String? _searchError;
  Function(WhoisInfo)? _whoisListener;
  final List<_ModAction> _actionLog = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ircService = ref.read(ircServiceProvider);
      if (!_checkAccess()) return;
    });
  }

  @override
  void dispose() {
    _removeWhoisListener();
    _searchController.dispose();
    super.dispose();
  }

  bool _checkAccess() {
    final nick = ref.read(currentNicknameProvider);
    if (!isAuthorizedStaffNick(nick)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
      return false;
    }
    return true;
  }

  void _removeWhoisListener() {
    final listener = _whoisListener;
    if (listener != null && _ircService != null) {
      _ircService!.removeWhoisListener(listener);
    }
    _whoisListener = null;
  }

  Future<void> _searchUser() async {
    final nick = _searchController.text.trim();
    if (nick.isEmpty || _ircService == null) return;

    _removeWhoisListener();
    setState(() {
      _searching = true;
      _searchError = null;
      _lastWhois = null;
    });

    final completer = Completer<void>();
    final listener = (WhoisInfo info) {
      if (info.nick.toLowerCase() == nick.toLowerCase() && !completer.isCompleted) {
        completer.complete();
      }
    };
    _whoisListener = listener;
    _ircService!.addWhoisListener(listener);

    _ircService!.sendWhois(nick);

    try {
      await completer.future.timeout(const Duration(seconds: 5));
      final cached = _ircService!.getWhoisInfo(nick);
      setState(() {
        _lastWhois = cached;
        _searching = false;
        if (cached == null) _searchError = 'No se encontró información para $nick';
      });
    } on TimeoutException {
      setState(() {
        _searching = false;
        _searchError = 'Tiempo de espera agotado para $nick';
      });
    }
  }

  void _logAction(String type, String target, String? reason) {
    _actionLog.insert(0, _ModAction(
      type: type,
      target: target,
      reason: reason,
      timestamp: DateTime.now(),
    ));
    if (mounted) setState(() {});
  }

  void _showKillDialog() {
    final appTheme = ref.read(themeProvider);
    final nick = _lastWhois?.nick ?? _searchController.text.trim();
    final reasonController = TextEditingController();
    final nickController = TextEditingController(text: nick);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: const Text('KILL - Desconectar usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nickController,
              decoration: InputDecoration(
                labelText: 'Nick',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (obligatorio)',
                hintText: 'Ej: Spam, incumplimiento de normas',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final target = nickController.text.trim();
              final reason = reasonController.text.trim();
              if (target.isEmpty) return;
              _ircService?.killUser(target, reason.isNotEmpty ? reason : null);
              _logAction('KILL', target, reason);
              Navigator.pop(ctx);
            },
            child: const Text('Ejecutar KILL'),
          ),
        ],
      ),
    );
  }

  void _showBanDialog(String banType) {
    final appTheme = ref.read(themeProvider);
    final target = _lastWhois != null
        ? '${_lastWhois!.username ?? '*' }@${_lastWhois!.host ?? '*'}'
        : _searchController.text.trim();
    final targetController = TextEditingController(text: target);
    final durationController = TextEditingController(text: '30d');
    final reasonController = TextEditingController();

    final titles = {
      'GLINE': 'GLINE - Prohibición global',
      'KLINE': 'KLINE - Prohibición local',
      'ZLINE': 'ZLINE - Ban por IP',
      'SHUN': 'SHUN - Silenciar usuario',
    };
    final hints = {
      'GLINE': 'user@host (ej: *@*.malicious.net)',
      'KLINE': 'user@host (ej: *@*.malicious.net)',
      'ZLINE': 'IP (ej: 192.168.1.*)',
      'SHUN': 'user@host (ej: *@*.malicious.net)',
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: Text(titles[banType] ?? banType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: targetController,
              decoration: InputDecoration(
                labelText: banType == 'ZLINE' ? 'IP/Máscara' : 'Usuario@Host',
                hintText: hints[banType],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: durationController,
              decoration: InputDecoration(
                labelText: 'Duración',
                hintText: '30d, 1h, 10m, 0 para permanente',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Razón (obligatorio)',
                hintText: 'Ej: Spam repetido, Flood',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final t = targetController.text.trim();
              final d = durationController.text.trim();
              final r = reasonController.text.trim();
              if (t.isEmpty || r.isEmpty) return;
              switch (banType) {
                case 'GLINE':
                  _ircService?.glineUser(t, d.isNotEmpty ? d : null, r);
                  break;
                case 'KLINE':
                  _ircService?.klineUser(t, d.isNotEmpty ? d : null, r);
                  break;
                case 'ZLINE':
                  _ircService?.zlineIP(t, d.isNotEmpty ? d : null, r);
                  break;
                case 'SHUN':
                  _ircService?.shunUser(t, d.isNotEmpty ? d : null, r);
                  break;
              }
              _logAction(banType, t, r);
              Navigator.pop(ctx);
            },
            child: Text('Ejecutar $banType'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final currentNick = ref.watch(currentNicknameProvider);
    final isStaff = isAuthorizedStaffNick(currentNick);

    if (!isStaff) {
      return Scaffold(
        backgroundColor: appTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: appTheme.textSecondary),
              const SizedBox(height: 16),
              Text('Acceso restringido', style: TextStyle(color: appTheme.textPrimary, fontSize: 20)),
              const SizedBox(height: 8),
              Text('Solo personal autorizado', style: TextStyle(color: appTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: appTheme.background,
      appBar: AppBar(
        title: const Text('Administración Staff'),
        backgroundColor: appTheme.surface,
        actions: [
          if (_actionLog.isNotEmpty)
            IconButton(
              icon: Icon(Icons.history, color: appTheme.textPrimary),
              tooltip: 'Historial de acciones',
              onPressed: () => _showActionLog(appTheme),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWhoisSection(appTheme),
            const SizedBox(height: 24),
            if (_lastWhois != null) _buildUserInfo(appTheme),
            const SizedBox(height: 24),
            _buildQuickActions(appTheme),
            const SizedBox(height: 24),
            _buildDirectBanForms(appTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildWhoisSection(AppTheme appTheme) {
    return Card(
      color: appTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buscar Usuario', style: TextStyle(color: appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: appTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nick del usuario...',
                      hintStyle: TextStyle(color: appTheme.textSecondary),
                      filled: true,
                      fillColor: appTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: appTheme.primary.withValues(alpha: 0.3)),
                      ),
                      prefixIcon: Icon(Icons.search, color: appTheme.textSecondary),
                    ),
                    onSubmitted: (_) => _searchUser(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _searching ? null : _searchUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _searching
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: appTheme.textPrimary))
                        : Icon(Icons.search, color: appTheme.textPrimary),
                  ),
                ),
              ],
            ),
            if (_searchError != null) ...[
              const SizedBox(height: 8),
              Text(_searchError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(AppTheme appTheme) {
    final info = _lastWhois!;
    return Card(
      color: appTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: appTheme.primary),
                const SizedBox(width: 8),
                Text(info.nick, style: TextStyle(color: appTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                if (info.isStaff) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.shield, color: Colors.amber, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(appTheme, 'Usuario@Host', '${info.username ?? '?'}@${info.host ?? '?'}'),
            _infoRow(appTheme, 'Nombre real', info.realName ?? '?'),
            _infoRow(appTheme, 'Servidor', info.server ?? '?'),
            if (info.serverInfo != null) _infoRow(appTheme, 'Info servidor', info.serverInfo!),
            _infoRow(appTheme, 'Canales', info.channels.isEmpty ? 'Ninguno' : info.channels.join(', ')),
            if (info.signonTime != null) _infoRow(appTheme, 'Conectado desde', _formatDate(info.signonTime!)),
            if (info.idleSeconds != null) _infoRow(appTheme, 'Inactivo', _formatDuration(info.idleSeconds!)),
            if (info.isAway) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_off, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Ausente: ${info.awayMessage ?? 'Sin mensaje'}', style: const TextStyle(color: Colors.orange, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Acciones', style: TextStyle(color: appTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionChip(appTheme, 'KILL', Icons.person_off, Colors.red, _showKillDialog),
                _actionChip(appTheme, 'GLINE', Icons.block, Colors.red, () => _showBanDialog('GLINE')),
                _actionChip(appTheme, 'KLINE', Icons.block, Colors.orange, () => _showBanDialog('KLINE')),
                _actionChip(appTheme, 'ZLINE', Icons.network_check, Colors.red, () => _showBanDialog('ZLINE')),
                _actionChip(appTheme, 'SHUN', Icons.volume_off, Colors.purple, () => _showBanDialog('SHUN')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(AppTheme appTheme) {
    return Card(
      color: appTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Acciones Rápidas', style: TextStyle(color: appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickActionBtn(appTheme, 'REHASH', Icons.refresh, Colors.blue, () {
                  _ircService?.rehashServer();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recargando configuración del servidor...')));
                }),
                _quickActionBtn(appTheme, 'LINKS', Icons.link, Colors.green, () {
                  _ircService?.linksCommand();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitando lista de servidores...')));
                }),
                _quickActionBtn(appTheme, 'MAP', Icons.map, Colors.teal, () {
                  _ircService?.mapCommand();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitando mapa de red...')));
                }),
                _quickActionBtn(appTheme, 'LUSERS', Icons.people, Colors.blue, () {
                  _ircService?.lusersCommand();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitando estadísticas...')));
                }),
                _quickActionBtn(appTheme, 'KILL', Icons.person_off, Colors.red, _showKillDialog),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectBanForms(AppTheme appTheme) {
    return Card(
      color: appTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prohibiciones Directas', style: TextStyle(color: appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Sin necesidad de buscar usuario primero', style: TextStyle(color: appTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickActionBtn(appTheme, 'GLINE', Icons.block, Colors.red, () => _showBanDialog('GLINE')),
                _quickActionBtn(appTheme, 'KLINE', Icons.block, Colors.orange, () => _showBanDialog('KLINE')),
                _quickActionBtn(appTheme, 'ZLINE', Icons.network_check, Colors.red, () => _showBanDialog('ZLINE')),
                _quickActionBtn(appTheme, 'SHUN', Icons.volume_off, Colors.purple, () => _showBanDialog('SHUN')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(AppTheme appTheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: appTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: appTheme.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(AppTheme appTheme, String label, IconData icon, Color color, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text(label, style: TextStyle(color: appTheme.textPrimary, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.15),
      onPressed: onTap,
    );
  }

  Widget _quickActionBtn(AppTheme appTheme, String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showActionLog(AppTheme appTheme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appTheme.surface,
        title: const Text('Historial de Acciones'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _actionLog.isEmpty
              ? Center(child: Text('Sin acciones registradas', style: TextStyle(color: appTheme.textSecondary)))
              : ListView.builder(
                  itemCount: _actionLog.length,
                  itemBuilder: (_, i) {
                    final action = _actionLog[i];
                    final color = _actionColor(action.type);
                    return ListTile(
                      leading: Icon(_actionIcon(action.type), color: color),
                      title: Text('${action.type} ${action.target}', style: TextStyle(color: appTheme.textPrimary, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${action.reason ?? "Sin razón"} • ${_formatDate(action.timestamp)}',
                        style: TextStyle(color: appTheme.textSecondary, fontSize: 12),
                      ),
                      dense: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  IconData _actionIcon(String type) {
    switch (type) {
      case 'KILL': return Icons.person_off;
      case 'GLINE': return Icons.block;
      case 'KLINE': return Icons.block;
      case 'ZLINE': return Icons.network_check;
      case 'SHUN': return Icons.volume_off;
      default: return Icons.gavel;
    }
  }

  Color _actionColor(String type) {
    switch (type) {
      case 'KILL': return Colors.red;
      case 'GLINE': return Colors.red;
      case 'KLINE': return Colors.orange;
      case 'ZLINE': return Colors.red;
      case 'SHUN': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }
}

class _ModAction {
  final String type;
  final String target;
  final String? reason;
  final DateTime timestamp;
  _ModAction({required this.type, required this.target, this.reason, required this.timestamp});
}
