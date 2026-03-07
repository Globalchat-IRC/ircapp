import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';

class IconSelectorScreen extends ConsumerStatefulWidget {
  final String nick;
  
  const IconSelectorScreen({
    super.key,
    required this.nick,
  });

  @override
  ConsumerState<IconSelectorScreen> createState() => _IconSelectorScreenState();
}

class _IconSelectorScreenState extends ConsumerState<IconSelectorScreen> {
  /// Avatares de imagen (asset) que el usuario puede elegir
  static const List<Map<String, String>> assetAvatars = [
    {'path': 'assets/avatars/avatar_llorando.png', 'label': 'Llorando'},
  ];

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
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _selectedIcon != null && _selectedIcon!.startsWith('asset:')
                        ? Image.asset(
                            _selectedIcon!.substring(6),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) => Center(
                              child: Text(
                                widget.nick[0].toUpperCase(),
                                style: const TextStyle(fontSize: 60, color: Colors.white),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              _selectedIcon ?? widget.nick[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 60,
                                color: Colors.white,
                              ),
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
          // Título avatares de imagen
          if (assetAvatars.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Avatares',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: appTheme.textPrimary,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: assetAvatars.length,
                itemBuilder: (context, index) {
                  final entry = assetAvatars[index];
                  final path = entry['path']!;
                  final value = 'asset:$path';
                  final isSelected = _selectedIcon == value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = value;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? appTheme.primary.withValues(alpha: 0.3)
                                  : appTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? appTheme.primary
                                    : appTheme.surface.withValues(alpha: 0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                path,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stackTrace) =>
                                    const Icon(Icons.image_not_supported, size: 32),
                              ),
                            ),
                          ),
                          if (entry['label'] != null && entry['label']!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              entry['label']!,
                              style: TextStyle(
                                fontSize: 11,
                                color: appTheme.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Grid de emojis
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
                          ? appTheme.primary.withValues(alpha: 0.3)
                          : appTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? appTheme.primary
                            : appTheme.surface.withValues(alpha: 0.3),
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



