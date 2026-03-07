import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:markdown/markdown.dart' as md;

/// Widget para renderizar mensajes con Markdown avanzado
class MarkdownMessage extends StatelessWidget {
  final String content;
  final bool isDarkMode;
  final TextStyle? baseStyle;

  const MarkdownMessage({
    super.key,
    required this.content,
    this.isDarkMode = false,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = baseStyle ?? theme.textTheme.bodyMedium ?? const TextStyle();

    return MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: textStyle,
        h1: textStyle.copyWith(
          fontSize: textStyle.fontSize! * 1.5,
          fontWeight: FontWeight.bold,
        ),
        h2: textStyle.copyWith(
          fontSize: textStyle.fontSize! * 1.3,
          fontWeight: FontWeight.bold,
        ),
        h3: textStyle.copyWith(
          fontSize: textStyle.fontSize! * 1.1,
          fontWeight: FontWeight.bold,
        ),
        code: textStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: isDarkMode
              ? Colors.grey.shade800
              : Colors.grey.shade200,
          fontSize: textStyle.fontSize! * 0.9,
        ),
        codeblockDecoration: BoxDecoration(
          color: isDarkMode
              ? Colors.grey.shade900
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        blockquote: textStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.primaryColor,
        ),
        listBullet: textStyle,
        strong: textStyle.copyWith(fontWeight: FontWeight.bold),
        em: textStyle.copyWith(fontStyle: FontStyle.italic),
        a: textStyle.copyWith(
          color: theme.primaryColor,
          decoration: TextDecoration.underline,
        ),
      ),
      builders: {
        'code': CodeElementBuilder(),
      },
    );
  }
}

/// Builder personalizado para bloques de código con syntax highlighting
class CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class']?.replaceAll('language-', '') ?? '';
    final code = element.textContent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(4),
      ),
      child: HighlightView(
        code,
        language: language.isEmpty ? 'plaintext' : language,
        theme: draculaTheme,
        padding: EdgeInsets.zero,
        textStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}

