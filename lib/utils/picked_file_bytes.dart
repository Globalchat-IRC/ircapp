import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'picked_file_bytes_stub.dart'
    if (dart.library.io) 'picked_file_bytes_io.dart';

/// bytes de FilePicker: en iOS suele venir null y hay que leer [PlatformFile.path].
Future<Uint8List?> bytesFromPlatformFile(PlatformFile file) async {
  if (file.bytes != null && file.bytes!.isNotEmpty) return file.bytes;
  final path = file.path;
  if (path == null || path.isEmpty) return null;
  return readBytesFromPath(path);
}
