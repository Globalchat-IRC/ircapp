import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/emoji_config.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';

class EmojiConfigScreen extends ConsumerStatefulWidget {
  const EmojiConfigScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EmojiConfigScreen> createState() => _EmojiConfigScreenState();
}

class _EmojiConfigScreenState extends ConsumerState<EmojiConfigScreen> {
  // Emojis populares de JoyPixels con sus códigos Unicode
  final List<Map<String, String>> _popularEmojis = [
    {'name': 'Corona', 'unicode': '1f451', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f451.png'},
    {'name': 'Estrella', 'unicode': '2b50', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/2b50.png'},
    {'name': 'Micrófono', 'unicode': '1f3a4', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f3a4.png'},
    {'name': 'Persona', 'unicode': '1f464', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f464.png'},
    {'name': 'Robot', 'unicode': '1f916', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f916.png'},
    {'name': 'Escudo', 'unicode': '1f6e1', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f6e1.png'},
    {'name': 'Medalla', 'unicode': '1f3c5', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f3c5.png'},
    {'name': 'Trofeo', 'unicode': '1f3c6', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f3c6.png'},
    {'name': 'Llave', 'unicode': '1f511', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f511.png'},
    {'name': 'Candado', 'unicode': '1f512', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f512.png'},
    {'name': 'Faro', 'unicode': '1f6a8', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f6a8.png'},
    {'name': 'Bandera', 'unicode': '1f3f4', 'url': 'https://cdn.jsdelivr.net/joypixels/assets/9.0/png/unicode/64/1f3f4.png'},
  ];

  String? _selectedOwnerEmoji;
  String? _selectedOperatorEmoji;
  String? _selectedHalfopEmoji;
  String? _selectedVoiceEmoji;
  String? _selectedUserEmoji;
  String? _selectedRobotEmoji;

  @override
  void initState() {
    super.initState();
    final currentConfig = ref.read(emojiConfigProvider);
    _selectedOwnerEmoji = currentConfig.ownerEmoji;
    _selectedOperatorEmoji = currentConfig.operatorEmoji;
    _selectedHalfopEmoji = currentConfig.halfopEmoji;
    _selectedVoiceEmoji = currentConfig.voiceEmoji;
    _selectedUserEmoji = currentConfig.userEmoji;
    _selectedRobotEmoji = currentConfig.robotEmoji;
  }

  void _showEmojiPicker(BuildContext context, String role, Function(String) onSelect) {
    final appTheme = ref.read(themeProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              appTheme.surface,
              appTheme.surface.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      appTheme.primary,
                      appTheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_emotions, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Seleccionar Emoji para $role',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: _popularEmojis.length,
                  itemBuilder: (context, index) {
                    final emoji = _popularEmojis[index];
                    final isSelected = _getSelectedEmojiForRole(role) == emoji['url'];
                    
                    return GestureDetector(
                      onTap: () {
                        onSelect(emoji['url']!);
                        Navigator.pop(context);
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
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              emoji['url']!,
                              width: 40,
                              height: 40,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error, size: 40);
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              emoji['name']!,
                              style: TextStyle(
                                fontSize: 10,
                                color: appTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'O ingresar código Unicode (ej: 1f451)',
                    hintText: '1f451',
                    filled: true,
                    fillColor: appTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: appTheme.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: appTheme.accent, width: 2),
                    ),
                  ),
                  style: TextStyle(color: appTheme.textPrimary),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      final url = EmojiConfig.getEmojiFromUrl(value);
                      onSelect(url);
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getSelectedEmojiForRole(String role) {
    switch (role) {
      case 'Dueño':
        return _selectedOwnerEmoji;
      case 'Operador':
        return _selectedOperatorEmoji;
      case 'Halfop':
        return _selectedHalfopEmoji;
      case 'Voz':
        return _selectedVoiceEmoji;
      case 'Usuario':
        return _selectedUserEmoji;
      case 'Robot':
        return _selectedRobotEmoji;
      default:
        return null;
    }
  }

  Widget _buildEmojiSelector(
    BuildContext context,
    String title,
    String role,
    String? currentEmoji,
    Function(String) onSelect,
  ) {
    final appTheme = ref.read(themeProvider);
    final isUrl = currentEmoji != null && 
        (currentEmoji.startsWith('http://') || currentEmoji.startsWith('https://'));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appTheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    color: appTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEmojiPicker(context, role, onSelect),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: appTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: appTheme.primary.withOpacity(0.3),
                ),
              ),
              child: currentEmoji != null
                  ? (isUrl
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            currentEmoji,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  '?',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 24,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Text(
                            currentEmoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ))
                  : Icon(
                      Icons.add,
                      color: appTheme.primary,
                      size: 32,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final emojiConfig = ref.watch(emojiConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Emoticonos'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              appTheme.primary.withOpacity(0.1),
              appTheme.secondary.withOpacity(0.08),
              appTheme.background,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: appTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: appTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Selecciona emoticonos de JoyPixels para cada rol de usuario. Puedes usar emojis Unicode o imágenes desde JoyPixels.',
                        style: TextStyle(
                          color: appTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildEmojiSelector(
                context,
                'Dueño del Canal',
                'Dueño',
                _selectedOwnerEmoji ?? emojiConfig.ownerEmoji,
                (emoji) {
                  setState(() => _selectedOwnerEmoji = emoji);
                  ref.read(emojiConfigProvider.notifier).updateOwnerEmoji(emoji);
                },
              ),
              _buildEmojiSelector(
                context,
                'Operador',
                'Operador',
                _selectedOperatorEmoji ?? emojiConfig.operatorEmoji,
                (emoji) {
                  setState(() => _selectedOperatorEmoji = emoji);
                  ref.read(emojiConfigProvider.notifier).updateOperatorEmoji(emoji);
                },
              ),
              _buildEmojiSelector(
                context,
                'Halfop',
                'Halfop',
                _selectedHalfopEmoji ?? emojiConfig.halfopEmoji,
                (emoji) {
                  setState(() => _selectedHalfopEmoji = emoji);
                  ref.read(emojiConfigProvider.notifier).updateHalfopEmoji(emoji);
                },
              ),
              _buildEmojiSelector(
                context,
                'Voz',
                'Voz',
                _selectedVoiceEmoji ?? emojiConfig.voiceEmoji,
                (emoji) {
                  setState(() => _selectedVoiceEmoji = emoji);
                  ref.read(emojiConfigProvider.notifier).updateVoiceEmoji(emoji);
                },
              ),
              _buildEmojiSelector(
                context,
                'Usuario Normal',
                'Usuario',
                _selectedUserEmoji ?? emojiConfig.userEmoji,
                (emoji) {
                  setState(() => _selectedUserEmoji = emoji);
                  ref.read(emojiConfigProvider.notifier).updateUserEmoji(emoji);
                },
              ),
              _buildEmojiSelector(
                context,
                'Robot',
                'Robot',
                _selectedRobotEmoji ?? emojiConfig.robotEmoji,
                (emoji) {
                  setState(() => _selectedRobotEmoji = emoji);
                  ref.read(emojiConfigProvider.notifier).updateRobotEmoji(emoji);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Emoticonos guardados correctamente'),
                        backgroundColor: appTheme.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appTheme.primary,
                    foregroundColor: appTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Guardar Cambios',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




