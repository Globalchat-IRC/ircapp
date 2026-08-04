import 'dart:js_interop';
import 'package:web/web.dart' as web;

void updateBrowserTabTitle(int unreadCount) {
  if (unreadCount > 0) {
    web.document.title = '($unreadCount) GlobalChat';
  } else {
    web.document.title = 'GlobalChat';
  }
}
