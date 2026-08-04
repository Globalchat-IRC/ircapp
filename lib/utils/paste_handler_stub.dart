PasteRemoveListener? setupWebPasteListener({
  PasteFileCallback? onFilePasted,
  PasteTextCallback? onTextPasted,
}) {
  return null;
}

typedef PasteFileCallback = void Function(List<int> bytes, String name);
typedef PasteTextCallback = void Function(String text);
typedef PasteRemoveListener = void Function();
