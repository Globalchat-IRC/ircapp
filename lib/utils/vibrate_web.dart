import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

void vibratePattern() {
  try {
    // Convert each int to JS, then create a JS array
    final jsArray = [200, 100, 200, 100, 300]
        .map((e) => e.toJS)
        .toList()
        .toJS;
    // Vibration API: navigator.vibrate(pattern)
    web.window.navigator.callMethodVarArgs('vibrate'.toJS, [jsArray]);
  } catch (_) {}
}
