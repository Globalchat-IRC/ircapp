import 'dart:async';
import 'dart:convert';
// Web-only: uses dart:html for file upload. Not compilable on non-web platforms.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/debug_config.dart';
import '../utils/platform_utils.dart';

class AvatarService {
  static const String _baseUrl = 'https://avatar.globalchat.org';
  static const String _gifUploadUrl = 'https://xmlrpc.globalchat.org';
  static const String _defaultAvatarUrl =
      'https://xmlrpc.globalchat.org/avatar/generate-default-avatar.php';
  static const String _webUploadProxyPath = '/api/avatar_upload_proxy.php';

  // TTL de la caché de avatares: 5 minutos. Evita que resultados null
  // obstruyan avatares recién generados.
  static const Duration _cacheTtl = Duration(minutes: 5);

  // Caché para evitar repetir peticiones al servidor de avatares.
  static final Map<String, bool> _customAvatarCache = {};
  static final Map<String, bool> _gifAvatarCache = {};
  static final Map<String, String?> _bestAvatarCache = {};

  // Timestamps para TTL de la caché de avatares.
  static final Map<String, DateTime> _bestAvatarTimestamps = {};

  // Peticiones en curso: si alguien pide el mismo cacheKey mientras ya hay
  // una petición activa, reutiliza el Future en vez de lanzar otra.
  static final Map<String, Future<String?>> _inflight = {};

  // Logs de depuración (activados temporalmente para debug)
  static void _log(String message) {
    debugLog('[AVATAR] $message');
  }

  // Generar hash MD5 del nick (usando nick exacto case-sensitive como el plugin)
  static String _generateAvatarHash(String nick) {
    // Asegurar que el nick no esté vacío
    if (nick.isEmpty) {
      _log('⚠️ Hash: nick vacío');
      return '';
    }

    // IMPORTANTE: Usar el nick exacto de la red IRC (case-sensitive) como el plugin
    // No convertir a minúsculas, solo trim
    final normalized = nick.trim();
    final bytes = utf8.encode(normalized);
    final digest = md5.convert(bytes);
    final hash = digest.toString();
    _log('🔑 Hash: "$nick" -> "$normalized" -> $hash');

    // Validar que el hash tenga el formato correcto (32 caracteres hexadecimales)
    if (hash.length != 32) {
      _log('⚠️ Hash inválido (longitud ${hash.length}): $hash');
    }

    return hash;
  }

  /// Hash público para reutilizar en otros servicios (GIF, etc.)
  static String getAvatarHash(String nick) => _generateAvatarHash(nick);

  /// Almacena un valor en la caché de avatares con timestamp para TTL.
  static void _setCache(String key, String? value) {
    _bestAvatarCache[key] = value;
    _bestAvatarTimestamps[key] = DateTime.now();
  }

  /// Invalida la caché de avatar para un nick específico.
  /// Llamar después de subir un avatar o volver del generador SVG.
  static void invalidateCache(String nick) {
    final lower = nick.toLowerCase();
    _bestAvatarCache.removeWhere((k, _) => k.startsWith(lower));
    _bestAvatarTimestamps.removeWhere((k, _) => k.startsWith(lower));
    _gifAvatarCache.remove(lower);
    _customAvatarCache.remove(lower);
    _log('🗑️ Caché invalidada para "$nick"');
  }

  /// Invalida toda la caché de avatares.
  static void invalidateAllCache() {
    _bestAvatarCache.clear();
    _bestAvatarTimestamps.clear();
    _gifAvatarCache.clear();
    _customAvatarCache.clear();
    _log('🗑️ Toda la caché de avatares invalidada');
  }

  // Obtener URL del avatar de un usuario desde el generador SVG de GlobalChat
  static String getAvatarUrl(String nick) {
    final hash = _generateAvatarHash(nick);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = '$_baseUrl/avatars/default/$hash.png?t=$timestamp';
    _log('🔗 URL default PNG para "$nick": $url');
    return _proxifyIfNeeded(url);
  }

  /// URL del avatar GIF animado (si existe) basado en el mismo hash MD5 del nick.
  /// Los GIFs se almacenan en xmlrpc (upload-custom-avatar.php).
  static String getAvatarGifUrl(String nick) {
    final hash = _generateAvatarHash(nick);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = '$_gifUploadUrl/avatar/avatars/custom/$hash.gif?t=$timestamp';
    _log('🔗 URL custom GIF para "$nick": $url');
    return _proxifyIfNeeded(url);
  }

  /// Construye una URL de avatar PNG con cache-buster (en avatar.globalchat.org).
  static String _avatarPathUrl(String hash, String folder, String ext) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final directUrl = '$_baseUrl/avatars/$folder/$hash.$ext?t=$timestamp';
    return _proxifyIfNeeded(directUrl);
  }

  /// Construye una URL de avatar GIF con cache-buster (en xmlrpc.globalchat.org).
  static String _gifAvatarPathUrl(String hash, String folder, String ext) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final directUrl = '$_gifUploadUrl/avatar/avatars/$folder/$hash.$ext?t=$timestamp';
    return _proxifyIfNeeded(directUrl);
  }

  /// En web, envuelve la URL a través del proxy para evitar problemas de CORS.
  /// En nativo, devuelve la URL original sin cambios.
  static String _proxifyIfNeeded(String url) {
    if (!PlatformUtils.isWeb) return url;
    return '/api/avatar_image_proxy.php?url=${Uri.encodeComponent(url)}';
  }

  /// Devuelve la mejor URL de avatar personalizado disponible para el nick,
  /// o `null` si no tiene avatar personalizado.
  ///
  /// [preferAnimated] controla la preferencia entre GIFs animados y PNGs estáticos:
  /// - `true` (por defecto): busca primero GIFs en `custom/`, en las subcarpetas
  ///   de tamaño y en `default/`. Solo si no hay GIF usa PNGs estáticos.
  /// - `false`: ignora los GIFs y busca solo PNGs estáticos (`custom/`, tamaño y `default/`).
  static Future<String?> getBestAvatarUrl(
    String nick, {
    bool preferAnimated = true,
  }) async {
    final cacheKey = '${nick.toLowerCase()}#${preferAnimated ? 'anim' : 'static'}';
    if (_bestAvatarCache.containsKey(cacheKey)) {
      final timestamp = _bestAvatarTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheTtl) {
        _log('💾 Cache hit para "$nick" (anim=$preferAnimated) -> ${_bestAvatarCache[cacheKey]}');
        return _bestAvatarCache[cacheKey];
      }
      _log('⏰ Cache expirada para "$nick", recalculando...');
      _bestAvatarCache.remove(cacheKey);
      _bestAvatarTimestamps.remove(cacheKey);
    }

    // Si ya hay una petición en curso para el mismo nick, reutilizarla.
    if (_inflight.containsKey(cacheKey)) {
      _log('🔄 Reutilizando petición en curso para "$nick"');
      return _inflight[cacheKey]!;
    }

    final hash = _generateAvatarHash(nick);
    if (hash.isEmpty) {
      _setCache(cacheKey, null);
      return null;
    }

    _log('🔍 Buscando avatar personalizado para "$nick" (hash: $hash, animado=$preferAnimated)');

    // Crear future compartida para que otros callers esperen la misma petición.
    final future = _doGetBestAvatar(cacheKey, nick, hash, preferAnimated);
    _inflight[cacheKey] = future;
    try {
      final result = await future;
      return result;
    } finally {
      _inflight.remove(cacheKey);
    }
  }

  static Future<String?> _doGetBestAvatar(
    String cacheKey,
    String nick,
    String hash,
    bool preferAnimated,
  ) async {

    // 1. Buscar GIF animado (solo custom/ y default/ — las subcarpetas de
    //    tamaño 400/80/40 casi nunca se usan y añaden ~6 peticiones extra).
    if (preferAnimated) {
      final customGifUrl = _gifAvatarPathUrl(hash, 'custom', 'gif');
      _log('➡️ Probando GIF custom: $customGifUrl');
      if (await _resourceExists(customGifUrl)) {
        _setCache(cacheKey, customGifUrl);
        _log('✅ Encontrado GIF custom: $customGifUrl');
        return customGifUrl;
      }

      final defaultGifUrl = _gifAvatarPathUrl(hash, 'default', 'gif');
      _log('➡️ Probando GIF default: $defaultGifUrl');
      if (await _resourceExists(defaultGifUrl)) {
        _setCache(cacheKey, defaultGifUrl);
        _log('✅ Encontrado GIF default: $defaultGifUrl');
        return defaultGifUrl;
      }

      // GIF generado por el editor SVG (avatar.globalchat.org). El generador
      // guarda el GIF animado junto al PNG; si la copia en xmlrpc fallara,
      // esta es la ruta de respaldo.
      final svgGifUrl = _avatarPathUrl(hash, 'default', 'gif');
      _log('➡️ Probando GIF SVG (avatar): $svgGifUrl');
      if (await _resourceExists(svgGifUrl)) {
        _setCache(cacheKey, svgGifUrl);
        _log('✅ Encontrado GIF SVG (avatar): $svgGifUrl');
        return svgGifUrl;
      }
    }

    // 2. PNGs estáticos: solo custom/ y default/ (SVG generator).
    final customPngUrl = _avatarPathUrl(hash, 'custom', 'png');
    _log('➡️ Probando PNG custom: $customPngUrl');
    if (await _resourceExists(customPngUrl)) {
      _setCache(cacheKey, customPngUrl);
      _log('✅ Encontrado PNG custom: $customPngUrl');
      return customPngUrl;
    }

    final defaultPngUrl = _avatarPathUrl(hash, 'default', 'png');
    _log('➡️ Probando PNG default: $defaultPngUrl');
    if (await _resourceExists(defaultPngUrl)) {
      _setCache(cacheKey, defaultPngUrl);
      _log('✅ PNG default existe en avatar.globalchat.org (personalizado SVG)');
      return defaultPngUrl;
    }

    _log('❌ No se encontró avatar personalizado para "$nick"');
    _setCache(cacheKey, null);
    return null;
  }

  /// Comprueba si un recurso remoto (imagen) existe.
  ///
  /// En web usa un `<img>` HTML para evitar problemas de CORS con `HEAD`.
  /// En nativo sigue usando `http.head`.
  static Future<bool> _resourceExists(String url) async {
    if (PlatformUtils.isWeb) {
      return _imageExistsWeb(url);
    }
    try {
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      _log('   error HEAD: $e');
      return false;
    }
  }

  static Future<bool> _imageExistsWeb(String url) async {
    final img = html.ImageElement();
    final loadFuture = img.onLoad.first.then((_) => true);
    final errorFuture = img.onError.first.then((_) => false);
    img.src = url;
    return Future.any([loadFuture, errorFuture]).timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  }

  /// Gravatar (portado de mlite2): URL del avatar por email o cuenta IRC.
  /// Usar cuando se disponga de cuenta (p. ej. WHOIS account).
  /// [emailOrAccount] email o identificador (se hashea con MD5).
  /// [size] tamaño en píxeles (por defecto 80). [d] tipo de default: identicon, retro, etc.
  static String getGravatarUrl(
    String emailOrAccount, {
    int size = 80,
    String d = 'identicon',
  }) {
    if (emailOrAccount.isEmpty) return getDefaultAvatarUrl('');
    final normalized = emailOrAccount.trim().toLowerCase();
    final bytes = utf8.encode(normalized);
    final hash = md5.convert(bytes).toString();
    return 'https://www.gravatar.com/avatar/$hash?s=$size&d=$d';
  }

  // Obtener URL del avatar generado por defecto (fallback)
  // En web, este también puede tener problemas de CORS, pero el widget manejará el fallback
  static String getDefaultAvatarUrl(String nick) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final encodedNick = Uri.encodeComponent(nick);
    final url =
        '$_defaultAvatarUrl?username=$encodedNick&size=400&format=png&t=$timestamp';
    _log('🔗 URL generada por defecto para "$nick": $url');
    return _proxifyIfNeeded(url);
  }

  // Nota: Los avatares pueden fallar por CORS en web, pero el widget UserAvatar
  // usa WebHtmlElementStrategy.prefer que intenta usar elementos HTML <img>
  // que no tienen las mismas restricciones CORS estrictas.

  // Verificar si un avatar existe (usando nick exacto case-sensitive)
  // En web, http.head puede fallar por CORS, así que siempre asumimos que puede existir
  // y dejamos que el widget Image.network maneje el error si no existe
  static Future<bool> avatarExists(String nick) async {
    if (PlatformUtils.isWeb) {
      // En web, no podemos verificar con http.head debido a CORS
      // Asumimos que el avatar puede existir y dejamos que Image.network lo maneje
      // Esto permite que los avatares personalizados se carguen correctamente
      return true; // Siempre intentar cargar el avatar personalizado primero
    }

    try {
      final url = getAvatarUrl(nick);
      // print('🔍 [AVATAR] Checking if avatar exists for "$nick": $url');
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      final exists = response.statusCode == 200;
      // print('🔍 [AVATAR] Avatar exists for "$nick": $exists (status: ${response.statusCode})');
      return exists;
    } catch (e) {
      // print('🔍 [AVATAR] Error checking avatar for "$nick": $e');
      // En caso de error, asumir que puede existir para intentar cargarlo
      return true;
    }
  }

  /// Comprueba si existe un GIF personalizado para el nick.
  static Future<bool> avatarGifExists(String nick) async {
    final cacheKey = nick.toLowerCase();
    if (_gifAvatarCache.containsKey(cacheKey)) {
      return _gifAvatarCache[cacheKey]!;
    }
    try {
      final url = getAvatarGifUrl(nick);
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      final exists = response.statusCode == 200;
      _gifAvatarCache[cacheKey] = exists;
      return exists;
    } catch (_) {
      _gifAvatarCache[cacheKey] = false;
      return false;
    }
  }

  /// Comprueba si existe un avatar SVG personalizado para el nick.
  /// En avatar.globalchat.org, si el PNG existe en `default/`, es del generador SVG.
  static Future<bool> hasLikelyCustomStaticAvatar(String nick) async {
    final cacheKey = nick.toLowerCase();
    if (_customAvatarCache.containsKey(cacheKey)) {
      return _customAvatarCache[cacheKey]!;
    }

    final hash = _generateAvatarHash(nick);
    if (hash.isEmpty) {
      _customAvatarCache[cacheKey] = false;
      return false;
    }

    final exists = await _resourceExists(_avatarPathUrl(hash, 'default', 'png'));
    _customAvatarCache[cacheKey] = exists;
    return exists;
  }

  // Obtener la URL correcta del avatar personalizado, o null si no tiene.
  // El widget pintará las iniciales como fallback cuando esto devuelva null.
  static Future<String?> getCorrectAvatarUrl(
    String nick, {
    bool preferAnimated = true,
  }) async {
    if (nick.isEmpty) {
      return null;
    }
    return getBestAvatarUrl(nick.trim(), preferAnimated: preferAnimated);
  }

  /// Subir avatar GIF al servidor para que sea visible por otros clientes.
  /// Usa el endpoint PHP `avatar/upload-custom-avatar.php`, que acepta:
  /// - método: POST (multipart/form-data)
  /// - campos: avatar (archivo), hash (MD5 del nick), username (nick)
  static Future<UploadAvatarResult> uploadAvatarGif(
    String nick,
    List<int> bytes,
  ) async {
    final cleanNick = nick.trim();
    if (cleanNick.isEmpty || bytes.isEmpty) {
      return const UploadAvatarResult(
        success: false,
        errorMessage: 'Nick o datos vacíos',
      );
    }

    try {
      final hash = _generateAvatarHash(cleanNick);
      if (hash.isEmpty) {
        return const UploadAvatarResult(
          success: false,
          errorMessage: 'Hash de avatar inválido',
        );
      }

      final uri = PlatformUtils.isWeb
          ? Uri.base.resolve(_webUploadProxyPath)
          : Uri.parse('$_gifUploadUrl/avatar/upload-custom-avatar.php');
      final request = http.MultipartRequest('POST', uri);

      request.fields['hash'] = hash;
      request.fields['username'] = cleanNick;

      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: '$hash.gif',
          contentType: MediaType('image', 'gif'),
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        return UploadAvatarResult(
          success: false,
          errorMessage: 'HTTP ${response.statusCode}: $body',
          url: null,
        );
      }

      bool success = true;
      String? message;
      String? url;

      try {
        final decoded = json.decode(body);
        if (decoded is Map<String, dynamic>) {
          success = decoded['success'] == true;
          message = decoded['message']?.toString();
          url = decoded['url']?.toString();
        }
      } catch (_) {
        // Si la respuesta no es JSON válido pero el HTTP fue 200, consideramos éxito básico
      }

      if (!success) {
        return UploadAvatarResult(
          success: false,
          errorMessage: message ?? 'Error en servidor al subir avatar GIF',
          url: url,
        );
      }

      // Invalidar caché para que otros usuarios vean el avatar actualizado
      invalidateCache(cleanNick);

      return UploadAvatarResult(
        success: true,
        errorMessage: message,
        url: url ?? getAvatarGifUrl(cleanNick),
      );
    } catch (e) {
      return UploadAvatarResult(
        success: false,
        errorMessage: e.toString(),
        url: null,
      );
    }
  }
}

/// Resultado de subida de avatar GIF.
class UploadAvatarResult {
  final bool success;
  final String? errorMessage;
  final String? url;

  const UploadAvatarResult({
    required this.success,
    this.errorMessage,
    this.url,
  });
}
