// Stub para plataformas no web (no hay drag & drop de archivos desde el SO)
import 'dart:typed_data';

typedef RemoveListener = void Function();

RemoveListener? setupWebDropListener(void Function(Uint8List bytes, String name) onFileDropped) {
  return null;
}
