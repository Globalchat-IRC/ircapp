import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool registerWebLifecycleListener(void Function(String source) onResume) {
  try {
    final visibilityListener = ((web.Event _) {
      if (web.document.visibilityState == 'visible') {
        onResume('visibility_change');
      }
    }).toJS;

    final focusListener = ((web.Event _) {
      onResume('window_focus');
    }).toJS;

    final onlineListener = ((web.Event _) {
      onResume('browser_online');
    }).toJS;

    web.document.addEventListener('visibilitychange', visibilityListener);
    web.window.addEventListener('focus', focusListener);
    web.window.addEventListener('online', onlineListener);

    return true;
  } catch (_) {
    return false;
  }
}
