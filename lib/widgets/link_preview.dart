import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/open_graph_service.dart';
import '../models/app_theme.dart';

/// Widget para mostrar preview de enlaces con Open Graph
class LinkPreview extends StatefulWidget {
  final String url;
  final AppTheme appTheme;

  const LinkPreview({
    super.key,
    required this.url,
    required this.appTheme,
  });

  @override
  State<LinkPreview> createState() => _LinkPreviewState();
}

class _LinkPreviewState extends State<LinkPreview> {
  final OpenGraphService _ogService = OpenGraphService();
  OpenGraphData? _metadata;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final metadata = await _ogService.fetchMetadata(widget.url);
      if (mounted) {
        setState(() {
          _metadata = metadata;
          _isLoading = false;
          _hasError = metadata.isEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.appTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.appTheme.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cargando preview...',
                style: TextStyle(
                  color: widget.appTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError || _metadata == null || _metadata!.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () async {
        try {
          final uri = Uri.parse(widget.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          // Ignorar errores
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: widget.appTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.appTheme.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_metadata!.image != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: CachedNetworkImage(
                  imageUrl: _metadata!.image!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_metadata!.siteName != null)
                    Text(
                      _metadata!.siteName!.toUpperCase(),
                      style: TextStyle(
                        color: widget.appTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  if (_metadata!.siteName != null) const SizedBox(height: 4),
                  if (_metadata!.title != null)
                    Text(
                      _metadata!.title!,
                      style: TextStyle(
                        color: widget.appTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (_metadata!.title != null && _metadata!.description != null)
                    const SizedBox(height: 4),
                  if (_metadata!.description != null)
                    Text(
                      _metadata!.description!,
                      style: TextStyle(
                        color: widget.appTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

