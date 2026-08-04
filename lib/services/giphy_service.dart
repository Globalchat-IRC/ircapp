import 'dart:convert';
import 'package:http/http.dart' as http;

class GiphyService {
  static const String _apiKey = 'UK7VMquaUFqlzzaZulRxetBHpZL02aZo';
  static const String _baseUrl = 'https://api.giphy.com/v1/gifs/search';

  static Future<List<GiphyResult>> search(String query, {int limit = 24}) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(
        '$_baseUrl?api_key=$_apiKey&q=${Uri.encodeComponent(query)}&limit=$limit&rating=pg-13',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      final list = data['data'] as List<dynamic>? ?? [];
      return list.map((item) {
        final images = item['images'] as Map<String, dynamic>;
        final fixedHeight = images['fixed_height'] as Map<String, dynamic>;
        final original = images['original'] as Map<String, dynamic>;
        return GiphyResult(
          id: item['id'] as String,
          url: fixedHeight['url'] as String,
          width: int.tryParse(fixedHeight['width']?.toString() ?? '') ?? 200,
          height: int.tryParse(fixedHeight['height']?.toString() ?? '') ?? 200,
          originalUrl: original['url'] as String,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

class GiphyResult {
  final String id;
  final String url;
  final int width;
  final int height;
  final String originalUrl;

  const GiphyResult({
    required this.id,
    required this.url,
    required this.width,
    required this.height,
    required this.originalUrl,
  });
}
