import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/privacy_service.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';

/// Pantalla de configuración de privacidad
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  final PrivacyService _privacyService = PrivacyService();
  bool _isIncognitoMode = false;
  bool _hidePresence = false;
  bool _hideTyping = false;
  bool _allowWhois = true;
  bool _saveHistory = true;
  List<String> _blockedUsers = [];
  List<String> _allowedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _privacyService.initialize();
    setState(() {
      _isIncognitoMode = _privacyService.isIncognitoMode;
      _hidePresence = _privacyService.hidePresence;
      _hideTyping = _privacyService.hideTyping;
      _allowWhois = _privacyService.allowWhois;
      _saveHistory = _privacyService.saveHistory;
      _blockedUsers = List.from(_privacyService.blockedUsers);
      _allowedUsers = List.from(_privacyService.allowedUsers);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Privacidad'),
          backgroundColor: appTheme.primary,
          foregroundColor: appTheme.textPrimary,
        ),
        backgroundColor: appTheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidad'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      backgroundColor: appTheme.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Modo Incógnito
          Card(
            color: appTheme.surface,
            child: SwitchListTile(
              title: const Text('Modo Incógnito'),
              subtitle: const Text('No guarda historial ni datos de sesión'),
              value: _isIncognitoMode,
              onChanged: (value) async {
                await _privacyService.setIncognitoMode(value);
                setState(() {
                  _isIncognitoMode = value;
                  if (value) _saveHistory = false;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Ocultar Presencia
          Card(
            color: appTheme.surface,
            child: SwitchListTile(
              title: const Text('Ocultar Estado de Presencia'),
              subtitle: const Text('Otros usuarios no verán tu estado'),
              value: _hidePresence,
              onChanged: _isIncognitoMode ? null : (value) async {
                await _privacyService.setHidePresence(value);
                setState(() => _hidePresence = value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Ocultar Typing
          Card(
            color: appTheme.surface,
            child: SwitchListTile(
              title: const Text('Ocultar Indicador de Escritura'),
              subtitle: const Text('No mostrar cuando estás escribiendo'),
              value: _hideTyping,
              onChanged: (value) async {
                await _privacyService.setHideTyping(value);
                setState(() => _hideTyping = value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Permitir WHOIS
          Card(
            color: appTheme.surface,
            child: SwitchListTile(
              title: const Text('Permitir WHOIS'),
              subtitle: const Text('Permitir que otros usuarios vean tu información'),
              value: _allowWhois,
              onChanged: (value) async {
                await _privacyService.setAllowWhois(value);
                setState(() => _allowWhois = value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Guardar Historial
          Card(
            color: appTheme.surface,
            child: SwitchListTile(
              title: const Text('Guardar Historial'),
              subtitle: const Text('Guardar mensajes en el historial local'),
              value: _saveHistory,
              onChanged: _isIncognitoMode ? null : (value) async {
                await _privacyService.setSaveHistory(value);
                setState(() => _saveHistory = value);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Usuarios Bloqueados
          Card(
            color: appTheme.surface,
            child: ExpansionTile(
              title: const Text('Usuarios Bloqueados'),
              subtitle: Text('${_blockedUsers.length} usuarios'),
              children: [
                ..._blockedUsers.map((nick) => ListTile(
                  title: Text(nick),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () async {
                      await _privacyService.unblockUser(nick);
                      setState(() => _blockedUsers.remove(nick));
                    },
                  ),
                )),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Bloquear Usuario'),
                  onTap: () => _showBlockUserDialog(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Usuarios Permitidos
          Card(
            color: appTheme.surface,
            child: ExpansionTile(
              title: const Text('Usuarios Permitidos'),
              subtitle: Text(_allowedUsers.isEmpty
                  ? 'Todos pueden ver tu estado'
                  : '${_allowedUsers.length} usuarios'),
              children: [
                ..._allowedUsers.map((nick) => ListTile(
                  title: Text(nick),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle),
                    onPressed: () async {
                      await _privacyService.disallowUser(nick);
                      setState(() => _allowedUsers.remove(nick));
                    },
                  ),
                )),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Agregar Usuario'),
                  onTap: () => _showAllowUserDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bloquear Usuario'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nick del usuario',
            hintText: 'ejemplo: usuario123',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _privacyService.blockUser(controller.text);
                setState(() {
                  if (!_blockedUsers.contains(controller.text.toLowerCase())) {
                    _blockedUsers.add(controller.text.toLowerCase());
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
  }

  void _showAllowUserDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Usuario Permitido'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nick del usuario',
            hintText: 'ejemplo: usuario123',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _privacyService.allowUser(controller.text);
                setState(() {
                  if (!_allowedUsers.contains(controller.text.toLowerCase())) {
                    _allowedUsers.add(controller.text.toLowerCase());
                  }
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

