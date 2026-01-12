import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';

class IconSelectorScreen extends ConsumerStatefulWidget {
  final String nick;
  
  const IconSelectorScreen({
    Key? key,
    required this.nick,
  }) : super(key: key);

  @override
  ConsumerState<IconSelectorScreen> createState() => _IconSelectorScreenState();
}

class _IconSelectorScreenState extends ConsumerState<IconSelectorScreen> {
  // Lista de iconos predeterminados (emojis)
  static const List<String> defaultIcons = [
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
    '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
    '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
    '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
    '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
    '🤧', '🥵', '🥶', '😶‍🌫️', '😵', '😵‍💫', '🤯', '🤠', '🥳', '😎',
    '🤓', '🧐', '😕', '😟', '🙁', '☹️', '😮', '😯', '😲', '😳',
    '🥺', '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖',
    '😣', '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬',
    '😈', '👿', '💀', '☠️', '💩', '🤡', '👹', '👺', '👻', '👽',
    '👾', '🤖', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿',
    '😾', '🙈', '🙉', '🙊', '💋', '💌', '💘', '💝', '💖', '💗',
    '💓', '💞', '💕', '💟', '❣️', '💔', '❤️‍🔥', '❤️‍🩹', '❤️', '🧡',
    '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💯', '💢', '💥',
    '💫', '💦', '💨', '🕳️', '💣', '💬', '👁️‍🗨️', '🗨️', '🗯️', '💭',
    '💤', '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏', '✌️',
    '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇', '☝️',
    '👍', '👎', '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲',
    '🤝', '🙏', '✍️', '💅', '🤳', '💪', '🦾', '🦿', '🦵', '🦶',
    '👂', '🦻', '👃', '🧠', '🫀', '🫁', '🦷', '🦴', '👀', '👁️',
    '👅', '👄', '💋', '🩸', '👶', '🧒', '👦', '👧', '🧑', '👱',
    '👨', '🧔', '👨‍🦰', '👨‍🦱', '👨‍🦳', '👨‍🦲', '👩', '👩‍🦰', '🧓', '👴',
    '👵', '🙍', '🙎', '🙅', '🙆', '💁', '🙋', '🧏', '🙇', '🤦',
    '🤷', '👮', '🕵️', '💂', '🥷', '👷', '🤴', '👸', '👳', '👲',
    '🧕', '🤵', '👰', '🤰', '🤱', '👼', '🎅', '🤶', '🦸', '🦹',
    '🧙', '🧚', '🧛', '🧜', '🧝', '🧞', '🧟', '💆', '💇', '🚶',
    '🧍', '🧎', '🏃', '💃', '🕺', '🕴️', '👯', '🧘', '🧗', '🤺',
    '🏇', '⛷️', '🏂', '🏌️', '🏄', '🚣', '🏊', '⛹️', '🏋️', '🚴',
    '🚵', '🤸', '🤽', '🤾', '🤹', '🧗', '🤼', '🤹‍♂️', '🤹‍♀️', '🧘‍♂️',
    '🧘‍♀️', '🧘‍♀️', '🧘‍♂️', '🧘‍♀️', '🧘‍♂️', '🧘‍♀️', '🧘‍♂️', '🧘‍♀️', '🧘‍♂️', '🧘‍♀️',
  ];
  
  String? _selectedIcon;
  
  @override
  void initState() {
    super.initState();
    // Cargar el icono actual del usuario si existe
    final currentIcon = ref.read(userIconsProvider)[widget.nick.toLowerCase()];
    _selectedIcon = currentIcon;
  }
  
  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    final userIcons = ref.watch(userIconsProvider);
    final currentIcon = userIcons[widget.nick.toLowerCase()];
    
    return Scaffold(
      backgroundColor: appTheme.background,
      appBar: AppBar(
        title: Text('Seleccionar Icono para ${widget.nick}'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
      ),
      body: Column(
        children: [
          // Vista previa del icono seleccionado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  appTheme.primary,
                  appTheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _selectedIcon ?? widget.nick[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Vista previa',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (currentIcon != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      ref.read(userIconsProvider.notifier).removeIcon(widget.nick);
                      setState(() {
                        _selectedIcon = null;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Icono personalizado eliminado para ${widget.nick}'),
                          backgroundColor: appTheme.primary,
                        ),
                      );
                    },
                    child: const Text('Eliminar icono personalizado'),
                  ),
                ],
              ],
            ),
          ),
          // Grid de iconos
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: defaultIcons.length,
              itemBuilder: (context, index) {
                final icon = defaultIcons[index];
                final isSelected = _selectedIcon == icon;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIcon = icon;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? appTheme.primary.withOpacity(0.3)
                          : appTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? appTheme.primary
                            : appTheme.surface.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        icon,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedIcon != null
            ? () {
                ref.read(userIconsProvider.notifier).setIcon(widget.nick, _selectedIcon!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Icono actualizado para ${widget.nick}'),
                    backgroundColor: appTheme.primary,
                  ),
                );
                Navigator.pop(context);
              }
            : null,
        backgroundColor: appTheme.primary,
        icon: const Icon(Icons.check),
        label: const Text('Guardar'),
      ),
    );
  }
}



