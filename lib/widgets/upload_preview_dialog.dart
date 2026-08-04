import 'dart:typed_data';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/material.dart';
import '../models/app_theme.dart';

class UploadPreviewResult {
  final bool confirmed;
  final String? caption;

  const UploadPreviewResult({required this.confirmed, this.caption});
}

class UploadPreviewDialog extends StatefulWidget {
  final Uint8List bytes;
  final String fileName;
  final bool isVideo;
  final AppTheme appTheme;

  const UploadPreviewDialog({
    super.key,
    required this.bytes,
    required this.fileName,
    required this.appTheme,
    this.isVideo = false,
  });

  static Future<UploadPreviewResult?> show(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    required AppTheme appTheme,
    bool isVideo = false,
  }) {
    return showModalBottomSheet<UploadPreviewResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: appTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => UploadPreviewDialog(
        bytes: bytes,
        fileName: fileName,
        appTheme: appTheme,
        isVideo: isVideo,
      ),
    );
  }

  @override
  State<UploadPreviewDialog> createState() => _UploadPreviewDialogState();
}

class _UploadPreviewDialogState extends State<UploadPreviewDialog> {
  final _captionController = TextEditingController();

  String get _fileSize {
    final bytes = widget.bytes.length;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxH = mq.size.height * 0.65;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: mq.viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.appTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isVideo ? 'Enviar video' : 'Enviar imagen',
              style: TextStyle(
                color: widget.appTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.fileName}  ($_fileSize)',
              style: TextStyle(
                color: widget.appTheme.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxH * 0.55,
                  minWidth: double.infinity,
                ),
                child: widget.isVideo
                    ? Container(
                        color: Colors.black,
                        child: const Center(
                          child: Icon(Icons.videocam, color: Colors.white70, size: 48),
                        ),
                      )
                    : Image.memory(
                        widget.bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              style: TextStyle(color: widget.appTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Agregar caption (opcional)',
                hintStyle: TextStyle(color: widget.appTheme.textSecondary),
                filled: true,
                fillColor: widget.appTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      const UploadPreviewResult(confirmed: false),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.appTheme.textSecondary,
                      side: BorderSide(color: widget.appTheme.textSecondary.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final caption = _captionController.text.trim();
                      Navigator.pop(
                        context,
                        UploadPreviewResult(
                          confirmed: true,
                          caption: caption.isNotEmpty ? caption : null,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.appTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Enviar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
