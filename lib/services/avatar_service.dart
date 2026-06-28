import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/platform_utils.dart';

class AvatarService {
  static const String _baseUrl = 'https://xmlrpc.globalchat.org';
  static const String _defaultAvatarUrl =
      'https://xmlrpc.globalchat.org/avatar/generate-default-avatar.php';
  static const int _customAvatarMinBytes = 10000;
  static const String _webUploadProxyPath = '/api/avatar_upload_proxy.php';

  // Generar hash MD5 del nick (usando nick exacto case-sensitive como el plugin)
  static String _generateAvatarHash(String nick) {
    // Asegurar que el nick no esté vacío
    if (nick.isEmpty) {
      // print('🔍 [AVATAR HASH] Warning: Empty nick provided');
      return '';
    }

    // IMPORTANTE: Usar el nick exacto de la red IRC (case-sensitive) como el plugin
    // No convertir a minúsculas, solo trim
    final normalized = nick.trim();
    final bytes = utf8.encode(normalized);
    final digest = md5.convert(bytes);
    final hash = digest.toString();
    // print('🔍 [AVATAR HASH] Nick: "$nick" -> Normalized: "$normalized" -> Hash: $hash');

    // Validar que el hash tenga el formato correcto (32 caracteres hexadecimales)
    if (hash.length != 32) {
      // print('🔍 [AVATAR HASH] Warning: Invalid hash length: ${hash.length}');
    }

    return hash;
  }

  /// Hash público para reutilizar en otros servicios (GIF, etc.)
  static String getAvatarHash(String nick) => _generateAvatarHash(nick);

  // Obtener URL del avatar de un usuario desde el panel de GlobalChat
  // Basado en la estructura del plugin: https://xmlrpc.globalchat.org/avatar/avatars/default/{hash}.png?t={timestamp}
  static String getAvatarUrl(String nick) {
    final hash = _generateAvatarHash(nick);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Formato: /avatar/avatars/default/{hash}.png?t={timestamp}
    final url = '$_baseUrl/avatar/avatars/default/$hash.png?t=$timestamp';
    // print('🔍 [AVATAR] Generated URL for "$nick": $url (hash: $hash)');
    return url;
  }

  /// URL del avatar GIF animado (si existe) basado en el mismo hash MD5 del nick.
  /// Formato: https://xmlrpc.globalchat.org/avatar/avatars/custom/{hash}.gif?t={timestamp}
  static String getAvatarGifUrl(String nick) {
    final hash = _generateAvatarHash(nick);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$_baseUrl/avatar/avatars/custom/$hash.gif?t=$timestamp';
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
    // print('🔍 [AVATAR] Generated default avatar URL for "$nick": $url');
    return url;
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
    try {
      final url = getAvatarGifUrl(nick);
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Heurística para distinguir un PNG hash realmente personalizado del PNG
  /// "por defecto" pequeño generado por xmlrpc.
  static Future<bool> hasLikelyCustomStaticAvatar(String nick) async {
    try {
      final url = getAvatarUrl(nick);
      final response = await http
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) {
        return false;
      }

      final contentLengthHeader = response.headers['content-length'];
      final contentLength = contentLengthHeader != null
          ? int.tryParse(contentLengthHeader)
          : null;

      if (contentLength == null) {
        return true;
      }

      return contentLength >= _customAvatarMinBytes;
    } catch (_) {
      return false;
    }
  }

  // Obtener la URL correcta del avatar (siguiendo la lógica del plugin)
  // 1. Intenta con el avatar personalizado usando hash MD5 del nick exacto
  // 2. Si no existe, usa el generador de avatares por defecto
  // En web, siempre intenta primero el avatar personalizado debido a restricciones CORS
  static Future<String?> getCorrectAvatarUrl(String nick) async {
    if (nick.isEmpty) {
      return null;
    }

    // Limpiar el nick (solo trim, mantener case-sensitive)
    final cleanNick = nick.trim();

    try {
      // En web, siempre intentar primero el avatar personalizado
      // porque http.head puede fallar por CORS pero el avatar puede existir
      // El widget Image.network manejará el error si no existe
      if (PlatformUtils.isWeb) {
        // En web, siempre intentar el avatar personalizado primero
        // Si no existe, Image.network mostrará el errorBuilder con el fallback
        return getAvatarUrl(cleanNick);
      }

      // En otras plataformas, verificar primero si existe
      final customAvatarExists = await avatarExists(cleanNick);

      if (customAvatarExists) {
        // Si existe el avatar personalizado, usarlo
        return getAvatarUrl(cleanNick);
      } else {
        // Si no existe, usar el generador por defecto
        return getDefaultAvatarUrl(cleanNick);
      }
    } catch (e) {
      // Si hay algún error al verificar, intentar primero el avatar personalizado
      // y dejar que el widget maneje el fallback si falla
      return getAvatarUrl(cleanNick);
    }
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
          : Uri.parse('$_baseUrl/avatar/upload-custom-avatar.php');
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
