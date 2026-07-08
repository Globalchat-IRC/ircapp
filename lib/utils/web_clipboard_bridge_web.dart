import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String?> readWebClipboardText() async {
  try {
    final jsText = await web.window.navigator.clipboard.readText().toDart;
    return jsText.toDart;
  } catch (_) {
    return null;
  }
}
