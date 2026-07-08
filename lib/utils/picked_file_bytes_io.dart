import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readBytesFromPath(String path) => File(path).readAsBytes();
