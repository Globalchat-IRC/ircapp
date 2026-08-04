import 'dart:html' as html;

/// Devuelve la URL de videollamada usando el dominio actual en web.
/// Incluye guest=1 para que los invitados puedan entrar sin login del webchat.
String getWebVideoRoomUrl(String roomName) {
  final base = html.window.location.href
      .split('#')
      .firstOrNull
      ?.replaceAll(RegExp(r'/+$'), '')
      ?? 'https://mobilev1.globalchat.org';
  return '$base/?guest=1#/video?room=$roomName';
}
