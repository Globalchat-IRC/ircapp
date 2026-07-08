import 'dart:typed_data';

/// MIME y tipo media para subidas a Cloudinary (iPhone suele devolver HEIC o sin extensión).
({String mimeType, bool isVideo}) resolveUploadMediaType(
  String fileName,
  Uint8List bytes, {
  String? declaredMime,
}) {
  final lower = fileName.toLowerCase();
  final mime = declaredMime?.split(';').first.trim();

  if (mime != null && mime.startsWith('video/')) {
    return (mimeType: mime, isVideo: true);
  }
  if (mime != null && mime.startsWith('image/')) {
    return (mimeType: mime, isVideo: false);
  }

  if (lower.endsWith('.mp4')) {
    return (mimeType: 'video/mp4', isVideo: true);
  }
  if (lower.endsWith('.webm')) {
    return (mimeType: 'video/webm', isVideo: true);
  }
  if (lower.endsWith('.mov')) {
    return (mimeType: 'video/quicktime', isVideo: true);
  }
  if (lower.endsWith('.png')) {
    return (mimeType: 'image/png', isVideo: false);
  }
  if (lower.endsWith('.gif')) {
    return (mimeType: 'image/gif', isVideo: false);
  }
  if (lower.endsWith('.webp')) {
    return (mimeType: 'image/webp', isVideo: false);
  }
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
    return (mimeType: 'image/heic', isVideo: false);
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return (mimeType: 'image/jpeg', isVideo: false);
  }

  if (bytes.length >= 12) {
    final ftyp = String.fromCharCodes(bytes.sublist(4, 8));
    if (ftyp == 'ftyp') {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if (brand.startsWith('heic') ||
          brand.startsWith('heix') ||
          brand.startsWith('mif1')) {
        return (mimeType: 'image/heic', isVideo: false);
      }
      if (brand.startsWith('qt')) {
        return (mimeType: 'video/quicktime', isVideo: true);
      }
      if (brand.startsWith('mp4') || brand.startsWith('isom')) {
        return (mimeType: 'video/mp4', isVideo: true);
      }
    }
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return (mimeType: 'image/jpeg', isVideo: false);
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return (mimeType: 'image/png', isVideo: false);
  }

  return (mimeType: 'image/jpeg', isVideo: false);
}

void assertImageUploadMimeSelfCheck() {
  assert(
    resolveUploadMediaType('x.heic', Uint8List.fromList([0, 0, 0, 0])).mimeType ==
        'image/heic',
  );
}
