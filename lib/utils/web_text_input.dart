import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform_utils.dart';

/// Atajos de pegado en web/escritorio.
/// En web, NO interceptamos Ctrl+V — dejamos que el browser/TextField lo maneje
/// nativamente (el Clipboard API requiere permisos que el usuario puede bloquear).
/// Solo interceptamos Shift+Insert como fallback.
class WebTextInput {
  static bool get _explicitPaste =>
      PlatformUtils.isWeb || PlatformUtils.isDesktop;

  static bool isPasteShortcut(KeyEvent event) {
    if (!_explicitPaste || event is! KeyDownEvent) return false;
    // En web, NO interceptar Ctrl+V/Cmd+V — el browser lo maneja nativamente
    if (PlatformUtils.isWeb) return false;
    final kb = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.insert && kb.isShiftPressed) {
      return true;
    }
    return false;
  }

  static void insertAtSelection(TextEditingController controller, String text) {
    if (text.isEmpty) return;
    final value = controller.value;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, text);
    controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
      composing: TextRange.empty,
    );
  }

  static KeyEventResult handlePasteKey(
    KeyEvent event,
    TextEditingController controller, {
    required bool hasFocus,
  }) {
    if (!hasFocus || !isPasteShortcut(event)) return KeyEventResult.ignored;
    // Solo Shift+Insert en desktop (no web)
    _pasteFromClipboard(controller);
    return KeyEventResult.handled;
  }

  static Future<void> _pasteFromClipboard(TextEditingController controller) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        insertAtSelection(controller, data.text!);
      }
    } catch (_) {}
  }
}
