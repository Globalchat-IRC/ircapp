import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../models/custom_robot.dart';
import 'icon_selector_screen.dart';

/// Pantalla para gestionar robots personalizados
class RobotsSettingsScreen extends ConsumerStatefulWidget {
  const RobotsSettingsScreen({super.key});

  @override
  ConsumerState<RobotsSettingsScreen> createState() => _RobotsSettingsScreenState();
}

class _RobotsSettingsScreenState extends ConsumerState<RobotsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final robots = ref.watch(customRobotsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Robots'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      backgroundColor: appTheme.background,
      body: Column(
        children: [
          // Información sobre robots por defecto
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: appTheme.primary.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: appTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Robots por defecto',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: appTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Los usuarios con "Robot.GlobalChat.Org" en su IP/host se detectan automáticamente como robots. Puedes añadirlos aquí para asignarles un icono personalizado.',
                  style: TextStyle(
                    fontSize: 14,
                    color: appTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: robots.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 64,
                          color: appTheme.textSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay robots configurados',
                          style: TextStyle(
                            fontSize: 18,
                            color: appTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Añade robots para asignarles iconos personalizados',
                          style: TextStyle(
                            fontSize: 14,
                            color: appTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: robots.length,
                    itemBuilder: (context, index) {
                      final robot = robots[index];
                      return _buildRobotItem(context, appTheme, robot);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRobotDialog(context, appTheme),
        backgroundColor: appTheme.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildRobotItem(BuildContext context, AppTheme appTheme, CustomRobot robot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: appTheme.surface,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFD700),
                const Color(0xFFFFA500),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              robot.icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          robot.nick,
          style: TextStyle(
            color: appTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (robot.host != null)
              Text(
                'Host: ${robot.host}',
                style: TextStyle(
                  color: appTheme.textSecondary,
                  fontSize: 12,
                ),
              )
            else
              Text(
                'Detección por nick',
                style: TextStyle(
                  color: appTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: appTheme.primary),
              onPressed: () => _showEditRobotDialog(context, appTheme, robot),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(context, appTheme, robot),
            ),
          ],
        ),
        onTap: () => _showEditRobotDialog(context, appTheme, robot),
      ),
    );
  }

  Future<void> _showAddRobotDialog(BuildContext context, AppTheme appTheme) async {
    final nickController = TextEditingController();
    final hostController = TextEditingController();
    String selectedIcon = '🤖';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Añadir Robot'),
          backgroundColor: appTheme.surface,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nickController,
                  decoration: InputDecoration(
                    labelText: 'Nick del robot',
                    hintText: 'Ej: RadioSoundMusic',
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
                  controller: hostController,
                  decoration: InputDecoration(
                    labelText: 'Host/IP (opcional)',
                    hintText: 'Ej: Robot.GlobalChat.Org',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: appTheme.background,
                    helperText: 'Si se especifica, solo se detectará si el host contiene este texto',
                  ),
                  style: TextStyle(color: appTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Icono:',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final icon = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IconSelectorScreen(
                          nick: nickController.text,
                        ),
                      ),
                    );
                    if (icon != null) {
                      setDialogState(() {
                        selectedIcon = icon;
                      });
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700),
                          const Color(0xFFFFA500),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        selectedIcon,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final icon = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IconSelectorScreen(
                          nick: nickController.text,
                        ),
                      ),
                    );
                    if (icon != null) {
                      setDialogState(() {
                        selectedIcon = icon;
                      });
                    }
                  },
                  child: const Text('Seleccionar icono'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nick = nickController.text.trim();
                if (nick.isNotEmpty) {
                  final robot = CustomRobot(
                    nick: nick,
                    icon: selectedIcon,
                    host: hostController.text.trim().isEmpty 
                        ? null 
                        : hostController.text.trim(),
                  );
                  ref.read(customRobotsProvider.notifier).addRobot(robot);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Robot "$nick" añadido'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditRobotDialog(
    BuildContext context,
    AppTheme appTheme,
    CustomRobot robot,
  ) async {
    final nickController = TextEditingController(text: robot.nick);
    final hostController = TextEditingController(text: robot.host ?? '');
    String selectedIcon = robot.icon;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Editar Robot: ${robot.nick}'),
          backgroundColor: appTheme.surface,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nickController,
                  decoration: InputDecoration(
                    labelText: 'Nick del robot',
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
                  controller: hostController,
                  decoration: InputDecoration(
                    labelText: 'Host/IP (opcional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: appTheme.background,
                    helperText: 'Si se especifica, solo se detectará si el host contiene este texto',
                  ),
                  style: TextStyle(color: appTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Icono:',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final icon = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IconSelectorScreen(
                          nick: nickController.text,
                        ),
                      ),
                    );
                    if (icon != null) {
                      setDialogState(() {
                        selectedIcon = icon;
                      });
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700),
                          const Color(0xFFFFA500),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        selectedIcon,
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    final icon = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IconSelectorScreen(
                          nick: nickController.text,
                        ),
                      ),
                    );
                    if (icon != null) {
                      setDialogState(() {
                        selectedIcon = icon;
                      });
                    }
                  },
                  child: const Text('Seleccionar icono'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nick = nickController.text.trim();
                if (nick.isNotEmpty) {
                  final updatedRobot = CustomRobot(
                    nick: nick,
                    icon: selectedIcon,
                    host: hostController.text.trim().isEmpty 
                        ? null 
                        : hostController.text.trim(),
                  );
                  ref.read(customRobotsProvider.notifier).updateRobot(robot.nick, updatedRobot);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Robot "$nick" actualizado'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    AppTheme appTheme,
    CustomRobot robot,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Robot'),
        content: Text('¿Eliminar el robot "${robot.nick}"?'),
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
      if (!context.mounted) return;
      ref.read(customRobotsProvider.notifier).removeRobot(robot.nick);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Robot "${robot.nick}" eliminado'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

