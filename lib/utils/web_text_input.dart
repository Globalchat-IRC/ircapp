import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform_utils.dart';
import 'web_clipboard_bridge_stub.dart'
    if (dart.library.html) 'web_clipboard_bridge_web.dart';

/// Atajos de pegado en web/escritorio (FocusNode/onKeyEvent puede bloquear Ctrl/Cmd+V).
class WebTextInput {
  static bool get _explicitPaste =>
      PlatformUtils.isWeb || PlatformUtils.isDesktop;

  static bool isPasteShortcut(KeyEvent event) {
    if (!_explicitPaste || event is! KeyDownEvent) return false;
    final kb = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        (kb.isControlPressed || kb.isMetaPressed) &&
        !kb.isAltPressed) {
      return true;
    }
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

  static Future<void> pasteInto(TextEditingController controller) async {
    if (!_explicitPaste) return;
    String? pasted;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      pasted = data?.text;
    } catch (_) {}
    pasted ??= await readWebClipboardText();
    if (pasted == null || pasted.isEmpty) return;
    insertAtSelection(controller, pasted);
  }

  static KeyEventResult handlePasteKey(
    KeyEvent event,
    TextEditingController controller, {
    required bool hasFocus,
  }) {
    if (!hasFocus || !isPasteShortcut(event)) return KeyEventResult.ignored;
    pasteInto(controller);
    return KeyEventResult.handled;
  }
}
