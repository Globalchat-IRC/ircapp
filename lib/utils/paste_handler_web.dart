import 'dart:js_interop';
import 'dart:typed_data' show Uint8List;
import 'package:web/web.dart' as web;

typedef PasteFileCallback = void Function(Uint8List bytes, String name);
typedef PasteTextCallback = void Function(String text);
typedef PasteRemoveListener = void Function();

PasteRemoveListener? setupWebPasteListener({
  PasteFileCallback? onFilePasted,
  PasteTextCallback? onTextPasted,
}) {
  final doc = web.document;

  final pasteListener = ((web.Event e) {
    final pasteEvent = e as web.ClipboardEvent;
    final data = pasteEvent.clipboardData;
    if (data == null) return;

    // 1. Buscar archivos (imágenes, videos) en el portapapeles
    final items = data.items;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.kind == 'file') {
        final file = item.getAsFile();
        if (file == null) continue;
        e.preventDefault();
        final reader = web.FileReader();
        reader.onloadend = ((web.Event _) {
          final result = reader.result;
          if (result != null) {
            try {
              final bytes = Uint8List.view((result as JSArrayBuffer).toDart);
              final name =
                  file.name.isNotEmpty ? file.name : 'clipboard_image.png';
              onFilePasted?.call(bytes, name);
            } catch (_) {}
          }
        }).toJS;
        reader.readAsArrayBuffer(file);
        return;
      }
    }

    // 2. Texto: leer vía getData (no requiere permiso Clipboard API)
    final text = data.getData('text/plain');
    if (text.isNotEmpty && onTextPasted != null) {
      e.preventDefault();
      onTextPasted(text);
    }
  }).toJS;

  doc.addEventListener('paste', pasteListener, true.toJS);

  return () {
    doc.removeEventListener('paste', pasteListener, true.toJS);
  };
}
