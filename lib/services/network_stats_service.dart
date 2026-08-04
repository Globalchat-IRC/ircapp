import 'dart:convert';
import 'package:http/http.dart' as http;

/// Estadísticas de red desde UnrealIRCd (usuarios por país).
/// Fuente: API en ceres que llama a JSON-RPC user.list del ircd.
class NetworkStatsService {
  static const String defaultBaseUrl = 'https://ceres.globalchat.org';

  final String baseUrl;

  NetworkStatsService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  /// Lista de países con recuento: [{ code, name, count }, ...].
  /// Incluye entrada "No data" si hay usuarios sin país.
  Future<List<CountryCount>> getUsersByCountry() async {
    final uri = Uri.parse('$baseUrl/api/countries_unreal.php');
    try {
      final r = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout'),
      );
      if (r.statusCode != 200) return [];
      final data = json.decode(r.body) as Map<String, dynamic>?;
      final list = data?['list'] as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => CountryCount(
                code: (e['code'] as String?) ?? '',
                name: (e['name'] as String?) ?? '',
                count: (e['count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class CountryCount {
  final String code;
  final String name;
  final int count;

  CountryCount({required this.code, required this.name, required this.count});
}
