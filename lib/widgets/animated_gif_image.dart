import 'dart:ui_web' if (dart.library.io) '../utils/ui_web_stub.dart' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Widget que muestra GIFs animados en Flutter web usando un elemento <img> nativo.
/// En mobile usa Image.network que también soporta GIFs animados.
class AnimatedGifImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  static final Set<String> _registeredViewTypes = {};

  const AnimatedGifImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.loadingWidget,
    this.errorWidget,
    this.borderRadius,
  });

  static bool _isGifUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.gif') || lower.contains('format=gif');
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_isGifUrl(url)) {
      return _buildFlutterImage();
    }
    return _buildHtmlImage();
  }

  Widget _buildFlutterImage() {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: loadingWidget != null
          ? (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return loadingWidget!;
            }
          : null,
      errorBuilder: errorWidget != null
          ? (context, error, stackTrace) => errorWidget!
          : null,
    );
  }

  Widget _buildHtmlImage() {
    final viewType = 'animated-gif-${url.hashCode}';

    if (!_registeredViewTypes.contains(viewType)) {
      _registeredViewTypes.add(viewType);
      ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final img = web.document.createElement('img') as web.HTMLImageElement;
        img.src = url;
        img.style
          ..objectFit = _cssFit
          ..width = '100%'
          ..height = '100%'
          ..pointerEvents = 'none';
        return img;
      });
    }

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: HtmlElementView(viewType: viewType),
      ),
    );
  }

  String get _cssFit {
    switch (fit) {
      case BoxFit.fill:
        return 'fill';
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fitWidth:
        return 'scale-down';
      case BoxFit.fitHeight:
        return 'scale-down';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
    }
  }
}
