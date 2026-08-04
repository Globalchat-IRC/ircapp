import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/debug_config.dart';

/// Información del stream en vivo de Mixcloud
class MixcloudLiveStream {
  final String streamUrl;
  final String username;
  final bool isLive;
  final DateTime timestamp;
  final Map<String, dynamic>? info;

  MixcloudLiveStream({
    required this.streamUrl,
    required this.username,
    required this.isLive,
    required this.timestamp,
    this.info,
  });

  factory MixcloudLiveStream.fromJson(Map<String, dynamic> json) {
    return MixcloudLiveStream(
      streamUrl: json['stream_url'] ?? '',
      username: json['username'] ?? '',
      isLive: json['is_live'] ?? false,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['timestamp'] ?? 0) * 1000,
      ),
      info: json['info'],
    );
  }

  /// Verificar si el stream está expirado (más de 30 segundos)
  /// Las URLs de Mixcloud cambian frecuentemente en cada sesión
  bool get isExpired {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    return diff.inSeconds > 30;
  }
}

/// Servicio para obtener streams en vivo de Mixcloud
class MixcloudLiveService {
  static const String _baseUrl = 'https://mobilev1.globalchat.org/api';
  
  // Cache del último stream obtenido
  MixcloudLiveStream? _cachedStream;
  DateTime? _lastCheck;
  
  static final MixcloudLiveService _instance = MixcloudLiveService._internal();
  factory MixcloudLiveService() => _instance;
  MixcloudLiveService._internal();

  /// Obtener el stream en vivo de un usuario de Mixcloud
  Future<MixcloudLiveStream?> getLiveStream(String username) async {
    try {
      // Si tenemos un stream en cache y no ha expirado, devolverlo
      // NOTA: Reducido a 30 segundos porque las URLs cambian en cada sesión
      if (_cachedStream != null && 
          _cachedStream!.username == username && 
          !_cachedStream!.isExpired &&
          _lastCheck != null &&
          DateTime.now().difference(_lastCheck!).inSeconds < 30) {
        debugLog('🎵 [MixcloudLive] Usando stream en cache para $username (menos de 30 segundos)');
        return _cachedStream;
      }

      debugLog('🎵 [MixcloudLive] Obteniendo stream en vivo para $username...');
      
      final url = Uri.parse('$_baseUrl/mixcloud_stream_extractor.php?username=$username');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 120), // Aumentado a 120 segundos para dar tiempo a Playwright
        onTimeout: () {
          throw TimeoutException('Timeout al obtener stream de Mixcloud (120s)');
        },
      );

      if (response.statusCode != 200) {
        debugLog('⚠️ [MixcloudLive] Error HTTP ${response.statusCode}');
        debugLog('⚠️ [MixcloudLive] Response body: ${response.body}');
        return null;
      }

      debugLog('🎵 [MixcloudLive] Response recibida (${response.body.length} bytes): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugLog('❌ [MixcloudLive] Error parseando JSON: $e');
        debugLog('❌ [MixcloudLive] Response body completo: ${response.body}');
        return null;
      }
      
      debugLog('🎵 [MixcloudLive] JSON parseado - success: ${json['success']}, is_live: ${json['is_live']}, stream_url: ${json['stream_url'] ?? 'N/A'}, error: ${json['error'] ?? 'N/A'}');
      
      // Aceptar tanto streams en vivo como sesiones grabadas (el proxy maneja el fallback)
      if (json['success'] == true && json['stream_url'] != null && (json['stream_url'] as String).isNotEmpty) {
        // Usar la URL directa del stream (los streams HLS se reproducen directamente sin proxy)
        String originalUrl = json['stream_url'] ?? '';
        
        // Asegurar que la URL termine en .m3u8 (no .m3u)
        // Mixcloud siempre usa .m3u8, pero por si acaso viene .m3u, lo convertimos
        if (originalUrl.isNotEmpty && originalUrl.endsWith('.m3u') && !originalUrl.endsWith('.m3u8')) {
          originalUrl = originalUrl.replaceAll(RegExp(r'\.m3u$'), '.m3u8');
          debugLog('🎵 [MixcloudLive] URL convertida de .m3u a .m3u8: $originalUrl');
          // Actualizar el JSON con la URL corregida
          json['stream_url'] = originalUrl;
        }
        
        // Crear el stream con la URL directa (no usar proxy para HLS)
        final stream = MixcloudLiveStream.fromJson(json);
        
        // Guardar en cache
        _cachedStream = stream;
        _lastCheck = DateTime.now();
        
        if (stream.isLive) {
          debugLog('✅ [MixcloudLive] Stream en vivo encontrado: $originalUrl');
        } else {
          debugLog('✅ [MixcloudLive] Sesión grabada encontrada: $originalUrl');
          if (json['cloudcast'] != null) {
            final cloudcast = json['cloudcast'] as Map<String, dynamic>;
            debugLog('🎵 [MixcloudLive] Nombre: ${cloudcast['name'] ?? 'N/A'}');
          }
        }
        debugLog('🎵 [MixcloudLive] Info: ${stream.info}');
        
        return stream;
      } else {
        debugLog('ℹ️ [MixcloudLive] No hay stream disponible (ni en vivo ni grabado) para $username');
        debugLog('ℹ️ [MixcloudLive] Razón: success=${json['success']}, is_live=${json['is_live']}, stream_url=${json['stream_url'] ?? 'N/A'}');
        if (json['error'] != null) {
          debugLog('⚠️ [MixcloudLive] Error del backend: ${json['error']}');
        }
        if (json['message'] != null) {
          debugLog('ℹ️ [MixcloudLive] Mensaje del backend: ${json['message']}');
        }
        _cachedStream = null;
        _lastCheck = DateTime.now();
        return null;
      }
      
    } catch (e, stackTrace) {
      debugLog('❌ [MixcloudLive] Error obteniendo stream: $e');
      debugLog('❌ [MixcloudLive] Stack: $stackTrace');
      return null;
    }
  }

  /// Verificar si hay stream en vivo (sin devolver la URL)
  Future<bool> isLive(String username) async {
    final stream = await getLiveStream(username);
    return stream != null && stream.isLive;
  }

  /// Limpiar cache
  void clearCache() {
    _cachedStream = null;
    _lastCheck = null;
  }
}
