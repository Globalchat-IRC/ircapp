// Solo en web: maneja drag & drop de archivos sobre la página
import 'dart:js_interop';
import 'dart:typed_data' show Uint8List;
import 'package:web/web.dart' as web;

typedef RemoveListener = void Function();

RemoveListener? setupWebDropListener(
  void Function(Uint8List bytes, String name) onFileDropped,
) {
  final body = web.document.body;
  if (body == null) return null;

  final dropListener = ((web.Event e) {
    e.preventDefault();
    e.stopPropagation();
    final dragEvent = e as web.DragEvent;
    final file = dragEvent.dataTransfer?.files.item(0);
    if (file == null) return;
    final reader = web.FileReader();
    reader.onloadend = ((web.Event _) {
      final result = reader.result;
      if (result != null) {
        try {
          final bytes = Uint8List.view((result as JSArrayBuffer).toDart);
          onFileDropped(bytes, file.name);
        } catch (_) {}
      }
    }).toJS;
    reader.readAsArrayBuffer(file);
  }).toJS;

  final dragOverListener = ((web.Event e) {
    e.preventDefault();
    final dragEvent = e as web.DragEvent;
    dragEvent.dataTransfer?.dropEffect = 'copy';
  }).toJS;

  body.addEventListener('drop', dropListener);
  body.addEventListener('dragover', dragOverListener);

  return () {
    body.removeEventListener('drop', dropListener);
    body.removeEventListener('dragover', dragOverListener);
  };
}
