import 'dart:io';
import 'dart:convert';

/// Servicio proxy local que agrega headers HTTP necesarios para streams de radio
class StreamProxyService {
  static StreamProxyService? _instance;
  HttpServer? _server;
  int? _port;
  
  static StreamProxyService get instance {
    _instance ??= StreamProxyService._();
    return _instance!;
  }
  
  StreamProxyService._();

  /// Inicia el servidor proxy local
  Future<void> start() async {
    if (_server != null) {
      print('🔄 Proxy ya está corriendo en puerto $_port');
      return;
    }

    try {
      // Intentar puertos desde 8888 hasta 8892
      for (int port = 8888; port <= 8892; port++) {
        try {
          _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
          _port = port;
          print('✅ Proxy iniciado en http://localhost:$port');
          _server!.listen(_handleRequest);
          return;
        } catch (e) {
          if (port == 8892) rethrow;
          continue;
        }
      }
    } catch (e) {
      print('❌ Error iniciando proxy: $e');
      rethrow;
    }
  }

  /// Detiene el servidor proxy
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _port = null;
      print('🛑 Proxy detenido');
    }
  }

  /// Obtiene la URL proxy para una URL de stream
  String? getProxyUrl(String originalUrl) {
    if (_port == null) return null;
    final encodedUrl = Uri.encodeComponent(originalUrl);
    return 'http://localhost:$_port/stream?url=$encodedUrl';
  }

  /// Maneja las peticiones al proxy
  Future<void> _handleRequest(HttpRequest request) async {
    bool responseClosed = false;
    
    try {
      // Solo manejar GET requests a /stream
      if (request.method != 'GET' || !request.uri.path.startsWith('/stream')) {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        responseClosed = true;
        return;
      }

      // Extraer la URL original del parámetro
      final urlParam = request.uri.queryParameters['url'];
      if (urlParam == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Missing url parameter');
        await request.response.close();
        responseClosed = true;
        return;
      }

      String originalUrl = Uri.decodeComponent(urlParam);
      
      // Limpiar caracteres problemáticos al final de la URL
      originalUrl = originalUrl.trim();
      if (originalUrl.endsWith(';')) {
        originalUrl = originalUrl.substring(0, originalUrl.length - 1);
        print('🔄 Proxy: Removed trailing semicolon from URL');
      }
      
      print('🔄 Proxy: Proxying request to $originalUrl');

      // Manejar Range requests de AVPlayer
      final rangeHeader = request.headers.value('range');
      print('🔄 Proxy: Range header: $rangeHeader');

      // Crear cliente HTTP con headers personalizados
      final client = HttpClient();
      
      try {
        final uri = Uri.parse(originalUrl);
        final httpRequest = await client.openUrl('GET', uri);
        
        // Agregar headers necesarios para streams de radio
        httpRequest.headers.set('User-Agent', 
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
        httpRequest.headers.set('Accept', '*/*');
        httpRequest.headers.set('Accept-Language', 'es-ES,es;q=0.9,en;q=0.8');
        httpRequest.headers.set('Accept-Encoding', 'identity');
        httpRequest.headers.set('Connection', 'keep-alive');
        httpRequest.headers.set('Cache-Control', 'no-cache');
        
        // Pasar el Range header si existe (para streaming)
        if (rangeHeader != null) {
          httpRequest.headers.set('Range', rangeHeader);
          print('🔄 Proxy: Forwarding Range header: $rangeHeader');
        }
        
        // Headers específicos para ciertos servidores
        if (originalUrl.contains('streamtheworld.com')) {
          httpRequest.headers.set('Referer', 'https://www.streamtheworld.com/');
          httpRequest.headers.set('Origin', 'https://www.streamtheworld.com');
        } else if (originalUrl.contains('mdstrm.com')) {
          httpRequest.headers.set('Referer', 'https://radiodisney.disneylatino.com/');
          httpRequest.headers.set('Origin', 'https://radiodisney.disneylatino.com');
        } else if (originalUrl.contains('radioplayer.com.ar')) {
          httpRequest.headers.set('Referer', 'https://www.radiolaplata.com.ar/');
        }

        final response = await httpRequest.close();
        
        print('🔄 Proxy: Response status ${response.statusCode}');
        print('🔄 Proxy: Content-Type: ${response.headers.value('content-type')}');

        // Establecer headers CORS primero
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        request.response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
        request.response.headers.set('Access-Control-Allow-Headers', '*');

        // Copiar headers importantes de la respuesta
        final contentType = response.headers.value('content-type');
        if (contentType != null) {
          request.response.headers.set('Content-Type', contentType);
          print('🔄 Proxy: Setting Content-Type to $contentType');
        } else {
          // Si no hay Content-Type, intentar detectarlo o usar uno por defecto
          if (originalUrl.contains('.mp3') || originalUrl.contains('streamtheworld') || originalUrl.contains('mdstrm')) {
            request.response.headers.set('Content-Type', 'audio/mpeg');
            print('🔄 Proxy: Setting Content-Type to audio/mpeg (default)');
          } else {
            request.response.headers.set('Content-Type', 'audio/mpeg');
            print('🔄 Proxy: Setting Content-Type to audio/mpeg (fallback)');
          }
        }

        // Copiar otros headers importantes (excepto algunos que pueden causar problemas)
        // Mantener headers de Range para streaming
        final headersToSkip = ['content-length', 'transfer-encoding', 'connection', 'content-type'];
        response.headers.forEach((key, values) {
          final lowerKey = key.toLowerCase();
          if (!headersToSkip.contains(lowerKey)) {
            // Copiar headers importantes como Accept-Ranges, Content-Range, etc.
            if (lowerKey == 'accept-ranges' || lowerKey == 'content-range') {
              request.response.headers.set(key, values.join(', '));
              print('🔄 Proxy: Copied header $key: ${values.join(", ")}');
            } else {
              request.response.headers.set(key, values.join(', '));
            }
          }
        });
        
        // Asegurar que Accept-Ranges esté presente para streaming
        if (response.headers.value('accept-ranges') == null) {
          request.response.headers.set('Accept-Ranges', 'bytes');
          print('🔄 Proxy: Added Accept-Ranges: bytes');
        }

        request.response.statusCode = response.statusCode;
        
        // Stream el contenido usando await for para mejor control
        print('🔄 Proxy: Iniciando streaming de datos...');
        
        try {
          await for (final data in response) {
            if (responseClosed) {
              print('🔄 Proxy: Stream cerrado, deteniendo...');
              break;
            }
            try {
              request.response.add(data);
            } catch (e) {
              print('⚠️ Error escribiendo datos: $e');
              responseClosed = true;
              break;
            }
          }
          
          if (!responseClosed) {
            await request.response.close();
            responseClosed = true;
            print('🔄 Proxy: Stream completado normalmente');
          }
        } catch (e) {
          print('❌ Error en stream loop: $e');
          if (!responseClosed) {
            try {
              await request.response.close();
              responseClosed = true;
            } catch (_) {}
          }
        }
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      print('❌ Error en proxy: $e');
      print('❌ Stack trace: $stackTrace');
      try {
        if (!responseClosed) {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('Proxy error: $e');
          await request.response.close();
          responseClosed = true;
        }
      } catch (_) {
        // La respuesta ya fue cerrada o hay otro error
      }
    }
  }
}

