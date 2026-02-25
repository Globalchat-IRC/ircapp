import 'package:http/http.dart' as http;
import 'dart:convert';

/// Servicio para detectar la ubicación geográfica del usuario usando GeoIP
class GeoIPService {
  // Usar geojs.io que permite CORS y es gratuito
  static const String _apiUrl = 'https://get.geojs.io/v1/ip/country.json';
  
  /// Códigos de países de América (Norte, Centro y Sur)
  static const Set<String> _americasCountries = {
    'US', // Estados Unidos
    'CA', // Canadá
    'MX', // México
    'GT', // Guatemala
    'BZ', // Belice
    'SV', // El Salvador
    'HN', // Honduras
    'NI', // Nicaragua
    'CR', // Costa Rica
    'PA', // Panamá
    'CU', // Cuba
    'JM', // Jamaica
    'HT', // Haití
    'DO', // República Dominicana
    'PR', // Puerto Rico
    'TT', // Trinidad y Tobago
    'BB', // Barbados
    'BS', // Bahamas
    'CO', // Colombia
    'VE', // Venezuela
    'GY', // Guyana
    'SR', // Surinam
    'GF', // Guayana Francesa
    'BR', // Brasil
    'EC', // Ecuador
    'PE', // Perú
    'BO', // Bolivia
    'PY', // Paraguay
    'UY', // Uruguay
    'AR', // Argentina
    'CL', // Chile
    'FK', // Islas Malvinas
  };

  /// Detectar si el usuario está en América
  /// Retorna true si está en América, false si está en otro lugar
  /// Retorna null si no se puede determinar
  static Future<bool?> isInAmericas() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
      ).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // geojs.io devuelve el código de país directamente como string
        final countryCode = data['country'] as String?;
        
        if (countryCode != null) {
          final isAmericas = _americasCountries.contains(countryCode.toUpperCase());
          return isAmericas;
        }
      }
      
      return null;
    } catch (e) {
      // Si hay error, retornar null para usar servidor por defecto
      print('🌎 [GEOIP] Error al obtener GeoIP: $e');
      return null;
    }
  }

  /// Obtener información completa de la ubicación (opcional, para debug)
  static Future<Map<String, dynamic>?> getLocationInfo() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
      ).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// URL para geo con ciudad/región (geojs.io)
  static const String _geoUrl = 'https://get.geojs.io/v1/ip/geo.json';

  /// Obtener ciudad y región por IP (para canal de ciudad/región en login web).
  /// Retorna map con 'city', 'region', 'country' o null si falla.
  static Future<Map<String, String>?> getCityRegion() async {
    try {
      final response = await http.get(
        Uri.parse(_geoUrl),
      ).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null) return null;
      final city = data['city']?.toString().trim();
      final region = data['region']?.toString().trim();
      final country = data['country']?.toString().trim();
      return {
        if (city != null && city.isNotEmpty) 'city': city,
        if (region != null && region.isNotEmpty) 'region': region,
        if (country != null && country.isNotEmpty) 'country': country,
      };
    } catch (e) {
      return null;
    }
  }

  /// Convierte nombre de ciudad o región a nombre de canal IRC: #NombreSinAcentos.
  /// Máximo ~200 caracteres y solo caracteres válidos para canal.
  static String cityRegionToChannelName(String? city, String? region) {
    String raw = (city ?? region ?? 'local').trim();
    if (raw.isEmpty) raw = 'local';
    // Normalizar: quitar acentos, dejar solo letras/números/espacios/guiones
    const accented = 'àáâãäåèéêëìíîïòóôõöùúûüñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÑÇ';
    const plain   = 'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC';
    for (int i = 0; i < accented.length; i++) {
      raw = raw.replaceAll(accented[i], plain[i]);
    }
    final allowed = RegExp(r'[a-zA-Z0-9\s\-]');
    final sb = StringBuffer();
    for (int i = 0; i < raw.length && sb.length < 200; i++) {
      if (allowed.hasMatch(raw[i])) sb.write(raw[i]);
    }
    String name = sb.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) name = 'local';
    name = name.length > 50 ? name.substring(0, 50).trim() : name;
    final capitalized = name.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase()).join('');
    return '#$capitalized';
  }

  /// Convierte nombre de país a nombre de canal IRC (misma lógica que ciudad/región).
  static String countryToChannelName(String? country) {
    return cityRegionToChannelName(null, country);
  }
}

