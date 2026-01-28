import 'package:flutter/material.dart';
import '../services/emoji_service.dart';
import '../models/app_theme.dart';

class EmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final AppTheme appTheme;

  const EmojiPicker({
    Key? key,
    required this.onEmojiSelected,
    required this.appTheme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final emojisByCategory = EmojiService.getEmojisByCategory();
    
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
                      // Scroll a la categoría (implementación simple)
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: appTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
              children: emojisByCategory.entries.map((entry) {
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
                      children: entry.value.map((emojiCode) {
                        final isAnimated = EmojiService.isAnimated(emojiCode);
                        final emojiUrl = EmojiService.getEmojiUrl(emojiCode);
                        
                        if (emojiUrl == null) {
                          return const SizedBox.shrink();
                        }
                        
                        return InkWell(
                          onTap: () => onEmojiSelected(emojiCode),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(4),
                            decoration: isAnimated
                                ? BoxDecoration(
                                    border: Border.all(
                                      color: appTheme.accent.withOpacity(0.3),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: Stack(
                              children: [
                                // Mostrar imagen (GIF para animados, PNG para estáticos)
                                Image.network(
                                  emojiUrl,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                    if (wasSynchronouslyLoaded || frame != null) {
                                      return child;
                                    }
                                    return Container(
                                      width: 32,
                                      height: 32,
                                      color: appTheme.surface.withOpacity(0.3),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    // Si falla la imagen, intentar mostrar Unicode como fallback
                                    final fallbackUnicode = EmojiService.getEmojiUnicode(emojiCode);
                                    if (fallbackUnicode != null) {
                                      return Center(
                                        child: Text(
                                          fallbackUnicode,
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
                                ),
                                // Indicador de animado
                                if (isAnimated)
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










