// Solo en web: maneja drag & drop de archivos sobre la página
import 'dart:html' as html;
import 'dart:typed_data' show ByteBuffer, Uint8List;

typedef RemoveListener = void Function();

RemoveListener? setupWebDropListener(void Function(Uint8List bytes, String name) onFileDropped) {
  void handleDrop(html.Event e) {
    e.preventDefault();
    e.stopPropagation();
    final de = e as dynamic;
    final dt = de.dataTransfer;
    if (dt == null || dt.files == null || dt.files.length == 0) return;
    final file = dt.files[0];
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result != null) {
        try {
          final bytes = Uint8List.view(result is ByteBuffer ? result : (result as dynamic));
          onFileDropped(bytes, file.name as String);
        } catch (_) {}
      }
    });
    reader.readAsArrayBuffer(file);
  }

  void handleDragOver(html.Event e) {
    e.preventDefault();
    (e as dynamic).dataTransfer?.dropEffect = 'copy';
  }

  html.document.body?.addEventListener('drop', handleDrop);
  html.document.body?.addEventListener('dragover', handleDragOver);

  return () {
    html.document.body?.removeEventListener('drop', handleDrop);
    html.document.body?.removeEventListener('dragover', handleDragOver);
  };
}
