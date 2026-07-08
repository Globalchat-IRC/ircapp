import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

void reloadWebWindow() {
  web.window.location.reload();
}

String getWebLocationHref() => web.window.location.href;

void setWebLocationHref(String href) {
  web.window.location.href = href;
}

void setupWebUnloadListeners(VoidCallback onUnload) {
  void listen(String eventName) {
    web.window.addEventListener(
      eventName,
      ((web.Event _) {
        onUnload();
      }).toJS,
    );
  }

  listen('beforeunload');
  listen('pagehide');
  listen('unload');
}

void registerPwaInstallPrompt(void Function(Object event) onPrompt) {
  web.window.addEventListener(
    'beforeinstallprompt',
    ((web.Event e) {
      onPrompt(e as Object);
    }).toJS,
  );
}

Future<void> promptPwaInstall(Object event) async {
  final e = event as JSObject;
  if (e.has('prompt')) {
    e.callMethodVarArgs<JSAny?>('prompt'.toJS);
  }
}

String? getWebLocalStorage(String key) => web.window.localStorage.getItem(key);

void setWebLocalStorage(String key, String value) {
  web.window.localStorage.setItem(key, value);
}
