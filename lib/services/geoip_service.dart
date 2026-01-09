import 'package:http/http.dart' as http;
import 'dart:convert';

/// Servicio para detectar la ubicación geográfica del usuario usando GeoIP
class GeoIPService {
  static const String _apiUrl = 'https://ipapi.co/json/';
  
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
        final countryCode = data['country_code'] as String?;
        
        if (countryCode != null) {
          final isAmericas = _americasCountries.contains(countryCode.toUpperCase());
          return isAmericas;
        }
      }
      
      return null;
    } catch (e) {
      // Si hay error, retornar null para usar servidor por defecto
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
}

