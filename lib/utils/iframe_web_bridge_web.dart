import 'package:web/web.dart' as web;

Object createIframeElement(String url, {String? allow}) {
  final iframe = web.HTMLIFrameElement()
    ..src = url
    ..style.border = 'none'
    ..style.width = '100%'
    ..style.height = '100%';
  if (allow != null) {
    iframe.allow = allow;
  }
  return iframe;
}
