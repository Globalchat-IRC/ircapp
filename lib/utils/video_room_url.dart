import 'package:flutter/foundation.dart';

import 'video_room_url_stub.dart'
    if (dart.library.html) 'video_room_url_web.dart' as impl;

/// Devuelve la URL pública para unirse a una sala de videollamada.
/// En web intenta usar el dominio actual; en otras plataformas usa
/// el dominio por defecto desplegado.
String getVideoRoomUrl(String roomName) {
  if (kIsWeb) {
    return impl.getWebVideoRoomUrl(roomName);
  }
  return 'https://mobilev1.globalchat.org/?guest=1#/video?room=$roomName';
}
