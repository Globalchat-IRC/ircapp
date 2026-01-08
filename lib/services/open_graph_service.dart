import 'package:http/http.dart' as http;

/// Metadata de Open Graph para preview de enlaces
class OpenGraphData {
  final String? title;
  final String? description;
  final String? image;
  final String? url;
  final String? siteName;

  OpenGraphData({
    this.title,
    this.description,
    this.image,
    this.url,
    this.siteName,
  });

  bool get isEmpty => title == null && description == null && image == null;
}

/// Servicio para obtener metadata Open Graph de URLs
class OpenGraphService {
  static final OpenGraphService _instance = OpenGraphService._internal();
  factory OpenGraphService() => _instance;
  OpenGraphService._internal();

  final Map<String, OpenGraphData> _cache = {};

  /// Obtiene metadata Open Graph de una URL
  Future<OpenGraphData> fetchMetadata(String url) async {
    // Normalizar URL
    final normalizedUrl = _normalizeUrl(url);
    
    // Verificar cache
    if (_cache.containsKey(normalizedUrl)) {
      return _cache[normalizedUrl]!;
    }

    try {
      final uri = Uri.parse(normalizedUrl);
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; IRC App)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final html = response.body;
        final metadata = _parseOpenGraph(html, normalizedUrl);
        
        // Guardar en cache
        _cache[normalizedUrl] = metadata;
        
        return metadata;
      }
    } catch (e) {
      // print('Error obteniendo Open Graph metadata: $e');
    }

    return OpenGraphData();
  }

  /// Normaliza una URL
  String _normalizeUrl(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }

  /// Parsea metadata Open Graph del HTML
  OpenGraphData _parseOpenGraph(String html, String url) {
    String? title;
    String? description;
    String? image;
    String? siteName;

    // Buscar og:title
    final titleMatch = RegExp(
      '<meta\\s+property=["\']og:title["\']\\s+content=["\'](.*?)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null) {
      title = titleMatch.group(1);
    } else {
      // Fallback a <title>
      final titleTagMatch = RegExp(
        r'<title[^>]*>([^<]+)</title>',
        caseSensitive: false,
      ).firstMatch(html);
      if (titleTagMatch != null) {
        title = titleTagMatch.group(1)?.trim();
      }
    }

    // Buscar og:description
    final descMatch = RegExp(
      '<meta\\s+property=["\']og:description["\']\\s+content=["\'](.*?)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (descMatch != null) {
      description = descMatch.group(1);
    } else {
      // Fallback a meta description
      final metaDescMatch = RegExp(
        '<meta\\s+name=["\']description["\']\\s+content=["\'](.*?)["\']',
        caseSensitive: false,
      ).firstMatch(html);
      if (metaDescMatch != null) {
        description = metaDescMatch.group(1);
      }
    }

    // Buscar og:image
    final imageMatch = RegExp(
      '<meta\\s+property=["\']og:image["\']\\s+content=["\'](.*?)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (imageMatch != null) {
      image = imageMatch.group(1);
      // Convertir URL relativa a absoluta
      if (image != null && !image!.startsWith('http')) {
        final baseUri = Uri.parse(url);
        image = baseUri.resolve(image).toString();
      }
    }

    // Buscar og:site_name
    final siteNameMatch = RegExp(
      '<meta\\s+property=["\']og:site_name["\']\\s+content=["\'](.*?)["\']',
      caseSensitive: false,
    ).firstMatch(html);
    if (siteNameMatch != null) {
      siteName = siteNameMatch.group(1);
    }

    return OpenGraphData(
      title: title,
      description: description,
      image: image,
      url: url,
      siteName: siteName,
    );
  }

  /// Limpia el cache
  void clearCache() {
    _cache.clear();
  }
}

