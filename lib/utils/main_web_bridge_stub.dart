import 'package:flutter/foundation.dart';

void reloadWebWindow() {}

String getWebLocationHref() => '';

void setWebLocationHref(String href) {}

void setupWebUnloadListeners(VoidCallback onUnload) {}

void registerPwaInstallPrompt(void Function(Object event) onPrompt) {}

Future<void> promptPwaInstall(Object event) async {}

String? getWebLocalStorage(String key) => null;

void setWebLocalStorage(String key, String value) {}

Future<void> clearAllClientStorage() async {}
