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
      // globalLog('[StreamProxy] Proxy ya está corriendo en puerto $_port');
      // Verificar que el servidor siga activo haciendo una pequeña espera
      await Future.delayed(const Duration(milliseconds: 50));
      return;
    }

    try {
      // globalLog('[StreamProxy] Iniciando servidor proxy...');
      // Intentar puertos desde 8888 hasta 8892
      for (int port = 8888; port <= 8892; port++) {
        try {
          // globalLog('[StreamProxy] Intentando puerto $port...');
          _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
          _port = port;
          // globalLog('[StreamProxy] ✅ Proxy iniciado en http://localhost:$port');
          _server!.listen(_handleRequest);
          
          // Esperar un momento para asegurar que el servidor esté completamente listo
          // Esto es especialmente importante en release donde el código se optimiza
          await Future.delayed(const Duration(milliseconds: 100));
          
          // globalLog('[StreamProxy] ✅ Proxy completamente listo y aceptando conexiones en puerto $_port');
          return;
        } catch (e) {
          // globalLog('[StreamProxy] ⚠️ Error en puerto $port: $e');
          if (port == 8892) rethrow;
          continue;
        }
      }
    } catch (e) {
      // globalLog('[StreamProxy] ❌ Error iniciando proxy: $e');
      rethrow;
    }
  }

  /// Detiene el servidor proxy
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _port = null;
      // print('🛑 Proxy detenido');
    }
  }

  /// Obtiene la URL proxy para una URL de stream
  String? getProxyUrl(String originalUrl) {
    if (_port == null) {
      // globalLog('[StreamProxy] getProxyUrl: _port es null, proxy no está iniciado');
      return null;
    }
    if (_server == null) {
      // globalLog('[StreamProxy] getProxyUrl: _server es null, proxy no está iniciado');
      return null;
    }
    final encodedUrl = Uri.encodeComponent(originalUrl);
    final proxyUrl = 'http://localhost:$_port/stream?url=$encodedUrl';
    // globalLog('[StreamProxy] getProxyUrl: retornando $proxyUrl');
    return proxyUrl;
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
        // globalLog('[StreamProxy] Removed trailing semicolon from URL');
      }
      
      // globalLog('[StreamProxy] Proxying request to $originalUrl');

        // Manejar Range requests de AVPlayer
        final rangeHeader = request.headers.value('range');
        // print('🔄 Proxy: Range header: $rangeHeader');

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
          
          // Para listen2myradio.com, NO pasar el Range header en la primera petición
          // Algunos servidores pueden rechazar peticiones con Range si no soportan range requests
          if (rangeHeader != null && !originalUrl.contains('listen2myradio.com')) {
            httpRequest.headers.set('Range', rangeHeader);
            // print('🔄 Proxy: Forwarding Range header: $rangeHeader');
          } else if (rangeHeader != null && originalUrl.contains('listen2myradio.com')) {
            // print('🔄 Proxy: Omitiendo Range header para listen2myradio.com (puede causar problemas)');
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
        } else if (originalUrl.contains('listen2myradio.com')) {
          // Headers específicos para listen2myradio.com - hacer que parezca un navegador real
          httpRequest.headers.set('Referer', 'https://listen2myradio.com/');
          httpRequest.headers.set('Origin', 'https://listen2myradio.com');
          httpRequest.headers.set('Accept-Encoding', 'identity'); // Sin compresión para streams
          httpRequest.headers.set('Accept', 'audio/webm,audio/ogg,audio/*;q=0.9,application/ogg;q=0.7,video/*;q=0.6,*/*;q=0.5');
          httpRequest.headers.set('Cache-Control', 'no-cache');
          httpRequest.headers.set('Pragma', 'no-cache');
          // Intentar con cookies simuladas
          httpRequest.headers.set('Cookie', 'PHPSESSID=listen2myradio');
          // print('🔄 Proxy: Aplicando headers específicos para listen2myradio.com');
          
          // Si la URL contiene parámetros, intentar también sin ellos
          if (originalUrl.contains('?')) {
            // print('🔄 Proxy: URL contiene parámetros de query');
          }
        }

        final response = await httpRequest.close();
        
        // print('🔄 Proxy: Response status ${response.statusCode}');
        // print('🔄 Proxy: Content-Type: ${response.headers.value('content-type')}');
        // print('🔄 Proxy: URL original: $originalUrl');
        
        // Verificar si la respuesta es un error
        if (response.statusCode >= 400) {
          // print('❌ Proxy: Error HTTP ${response.statusCode} desde el servidor');
          request.response.statusCode = response.statusCode;
          try {
            final errorBody = await response.transform(utf8.decoder).join();
            // print('❌ Proxy: Error body: ${errorBody.substring(0, errorBody.length > 200 ? 200 : errorBody.length)}');
            request.response.write('HTTP Error ${response.statusCode}: $errorBody');
          } catch (e) {
            request.response.write('HTTP Error ${response.statusCode}');
          }
          await request.response.close();
          return;
        }
        
        // Si el servidor devuelve HTML en lugar de audio, es un error
        final contentType = response.headers.value('content-type');
        bool isHtmlResponse = contentType != null && contentType.contains('text/html');
        
        if (isHtmlResponse && originalUrl.contains('listen2myradio.com')) {
          // print('⚠️ Proxy: El servidor listen2myradio.com devolvió HTML en lugar de audio.');
          // print('⚠️ Proxy: Esto puede indicar que la URL necesita autenticación o que el servidor está bloqueando la petición.');
          // print('⚠️ Proxy: Forzando Content-Type a audio/mpeg y continuando...');
          // No leer el stream aquí, solo forzar el Content-Type
        } else if (isHtmlResponse) {
          // print('⚠️ Proxy: El servidor devolvió HTML en lugar de audio.');
          // print('⚠️ Proxy: URL problemática: $originalUrl');
          request.response.statusCode = HttpStatus.badGateway;
          request.response.write('Server returned HTML instead of audio stream');
          await request.response.close();
          return;
        }

        // Establecer headers CORS primero
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        request.response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
        request.response.headers.set('Access-Control-Allow-Headers', '*');

        // Copiar headers importantes de la respuesta (solo si no es HTML)
        if (contentType != null && !contentType.contains('text/html')) {
          request.response.headers.set('Content-Type', contentType);
          // print('🔄 Proxy: Setting Content-Type to $contentType');
        } else if (originalUrl.contains('listen2myradio.com') || originalUrl.contains('.mp3')) {
          // Para listen2myradio.com o URLs .mp3, forzar audio/mpeg
          request.response.headers.set('Content-Type', 'audio/mpeg');
          // print('🔄 Proxy: Setting Content-Type to audio/mpeg (forced for listen2myradio.com)');
        } else {
          // Si no hay Content-Type, intentar detectarlo o usar uno por defecto
          if (originalUrl.contains('.mp3') || originalUrl.contains('streamtheworld') || originalUrl.contains('mdstrm')) {
            request.response.headers.set('Content-Type', 'audio/mpeg');
            // print('🔄 Proxy: Setting Content-Type to audio/mpeg (default)');
          } else {
            request.response.headers.set('Content-Type', 'audio/mpeg');
            // print('🔄 Proxy: Setting Content-Type to audio/mpeg (fallback)');
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
              // print('🔄 Proxy: Copied header $key: ${values.join(", ")}');
            } else {
              request.response.headers.set(key, values.join(', '));
            }
          }
        });
        
        // Asegurar que Accept-Ranges esté presente para streaming
        if (response.headers.value('accept-ranges') == null) {
          request.response.headers.set('Accept-Ranges', 'bytes');
          // print('🔄 Proxy: Added Accept-Ranges: bytes');
        }

        request.response.statusCode = response.statusCode;
        
        // Stream el contenido usando await for para mejor control
        // print('🔄 Proxy: Iniciando streaming de datos...');
        
        try {
          await for (final data in response) {
            if (responseClosed) {
              // print('🔄 Proxy: Stream cerrado, deteniendo...');
              break;
            }
            try {
              request.response.add(data);
            } catch (e) {
              // print('⚠️ Error escribiendo datos: $e');
              responseClosed = true;
              break;
            }
          }
          
          if (!responseClosed) {
            await request.response.close();
            responseClosed = true;
            // print('🔄 Proxy: Stream completado normalmente');
          }
        } catch (e) {
          // print('❌ Error en stream loop: $e');
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
    } catch (e) {
      // print('❌ Error en proxy: $e');
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

