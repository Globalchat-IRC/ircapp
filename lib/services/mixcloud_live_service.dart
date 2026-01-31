import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  /// Verificar si el stream está expirado (más de 5 minutos)
  bool get isExpired {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    return diff.inMinutes > 5;
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
      if (_cachedStream != null && 
          _cachedStream!.username == username && 
          !_cachedStream!.isExpired &&
          _lastCheck != null &&
          DateTime.now().difference(_lastCheck!).inMinutes < 2) {
        print('🎵 [MixcloudLive] Usando stream en cache para $username');
        return _cachedStream;
      }

      print('🎵 [MixcloudLive] Obteniendo stream en vivo para $username...');
      
      final url = Uri.parse('$_baseUrl/mixcloud_stream_extractor.php?username=$username');
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Timeout al obtener stream de Mixcloud');
        },
      );

      if (response.statusCode != 200) {
        print('⚠️ [MixcloudLive] Error HTTP ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      
      if (json['success'] == true && json['is_live'] == true) {
        final stream = MixcloudLiveStream.fromJson(json);
        
        // Guardar en cache
        _cachedStream = stream;
        _lastCheck = DateTime.now();
        
        print('✅ [MixcloudLive] Stream en vivo encontrado: ${stream.streamUrl}');
        print('🎵 [MixcloudLive] Info: ${stream.info}');
        
        return stream;
      } else {
        print('ℹ️ [MixcloudLive] No hay emisión en directo para $username');
        _cachedStream = null;
        _lastCheck = DateTime.now();
        return null;
      }
      
    } catch (e, stackTrace) {
      print('❌ [MixcloudLive] Error obteniendo stream: $e');
      print('❌ [MixcloudLive] Stack: $stackTrace');
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

  /// Obtener stream en vivo de UrbanFlow (djsonic_vlc)
  Future<MixcloudLiveStream?> getUrbanFlowLiveStream() async {
    return await getLiveStream('djsonic_vlc');
  }
}
