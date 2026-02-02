import 'package:flutter/material.dart';
import '../services/emoji_service.dart';
import '../models/app_theme.dart';

class EmojiPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;
  final AppTheme appTheme;

  const EmojiPicker({
    Key? key,
    required this.onEmojiSelected,
    required this.appTheme,
  }) : super(key: key);

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final emojisByCategory = EmojiService.getEmojisByCategory();
    if (emojisByCategory.keys.isNotEmpty) {
      _selectedCategory = emojisByCategory.keys.first;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emojisByCategory = EmojiService.getEmojisByCategory();
    final appTheme = widget.appTheme;
    
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: appTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tabs de categorías
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: appTheme.background,
              border: Border(
                bottom: BorderSide(
                  color: appTheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: emojisByCategory.keys.map((category) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                      // Mantener el foco en el campo de texto al cambiar de categoría
                      // Esto se maneja desde el callback del padre
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: _selectedCategory == null || _selectedCategory == category
                            ? appTheme.primary
                            : appTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: _selectedCategory == null || _selectedCategory == category
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Grid de emoticonos
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: emojisByCategory.entries
                  .where((entry) =>
                      _selectedCategory == null || entry.key == _selectedCategory)
                  .map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: appTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: entry.value.map<Widget>((emojiCode) {
                        final isAnimated = EmojiService.isAnimated(emojiCode);
                        final emojiUrl = EmojiService.getEmojiUrl(emojiCode);
                        final unicode = EmojiService.getEmojiUnicode(emojiCode);
                        
                        if (!isAnimated) {
                          // Emoticonos normales: intentar primero Noto 512.gif (más "moderno"), y si falla, PNG/Unicode.
                          final notoGifUrl = EmojiService.getNotoGifUrlForEmojiCode(emojiCode);
                          if (emojiUrl == null && notoGifUrl == null) {
                            return const SizedBox.shrink();
                          }
                          return InkWell(
                            onTap: () {
                              widget.onEmojiSelected(emojiCode);
                              // El foco se manejará desde el callback del padre
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(4),
                              child: (notoGifUrl != null
                                  ? Image.network(
                                      notoGifUrl,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        if (emojiUrl != null) {
                                          return Image.network(
                                            emojiUrl,
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) {
                                              if (unicode != null) {
                                                return Center(
                                                  child: Text(
                                                    unicode,
                                                    style: const TextStyle(fontSize: 24),
                                                  ),
                                                );
                                              }
                                              return Center(
                                                child: Text(
                                                  emojiCode,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: appTheme.textSecondary,
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        }
                                        if (unicode != null) {
                                          return Center(
                                            child: Text(
                                              unicode,
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                          );
                                        }
                                        return Center(
                                          child: Text(
                                            emojiCode,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: appTheme.textSecondary,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Image.network(
                                      emojiUrl!,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        if (unicode != null) {
                                          return Center(
                                            child: Text(
                                              unicode,
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                          );
                                        }
                                        return Center(
                                          child: Text(
                                            emojiCode,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: appTheme.textSecondary,
                                            ),
                                          ),
                                        );
                                      },
                                    )),
                            ),
                          );
                        }
                        
                        // Emoticonos animados: GIFs animados desde emoji-api.com
                        if (emojiUrl == null) {
                          return const SizedBox.shrink();
                        }
                        
                        return InkWell(
                          onTap: () {
                            widget.onEmojiSelected(emojiCode);
                            // El foco se manejará desde el callback del padre
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: appTheme.accent.withOpacity(0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: (EmojiService.isAssetPath(emojiUrl)
                                          ? Image.asset(
                                              emojiUrl,
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                final fallbackUrl =
                                                    EmojiService.getAnimatedFallbackNetworkUrl(emojiCode);
                                                if (fallbackUrl != null) {
                                                  return Image.network(
                                                    fallbackUrl,
                                                    width: 32,
                                                    height: 32,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      if (unicode != null) {
                                                        return Center(
                                                          child: Text(
                                                            unicode,
                                                            style: const TextStyle(fontSize: 24),
                                                          ),
                                                        );
                                                      }
                                                      return Center(
                                                        child: Text(
                                                          emojiCode,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: appTheme.textSecondary,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                }
                                                if (unicode != null) {
                                                  return Center(
                                                    child: Text(
                                                      unicode,
                                                      style: const TextStyle(fontSize: 24),
                                                    ),
                                                  );
                                                }
                                                return Center(
                                                  child: Text(
                                                    emojiCode,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: appTheme.textSecondary,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Image.network(
                                              emojiUrl,
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                if (unicode != null) {
                                                  return Center(
                                                    child: Text(
                                                      unicode,
                                                      style: const TextStyle(fontSize: 24),
                                                    ),
                                                  );
                                                }
                                                return Center(
                                                  child: Text(
                                                    emojiCode,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: appTheme.textSecondary,
                                                    ),
                                                  ),
                                                );
                                              },
                                            )),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: appTheme.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: appTheme.surface,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Emoji que “late” / hace bounce suavemente para simular animación
class _BouncingEmoji extends StatefulWidget {
  final String text;
  final double size;
  final Color color;
  
  const _BouncingEmoji({
    Key? key,
    required this.text,
    required this.size,
    required this.color,
  }) : super(key: key);
  
  @override
  State<_BouncingEmoji> createState() => _BouncingEmojiState();
}

class _BouncingEmojiState extends State<_BouncingEmoji> {
  bool _shrink = false;
  
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: 1.0,
        end: _shrink ? 0.9 : 1.15,
      ),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) {
          setState(() {
            _shrink = !_shrink;
          });
        }
      },
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Text(
        widget.text,
        style: TextStyle(
          fontSize: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}










