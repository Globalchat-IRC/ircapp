import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../utils/platform_utils.dart';

class AvatarService {
  static const String _baseUrl = 'https://xmlrpc.globalchat.org';
  static const String _defaultAvatarUrl = 'https://xmlrpc.globalchat.org/avatar/generate-default-avatar.php';
  
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
  
  // Obtener URL del avatar generado por defecto (fallback)
  // En web, este también puede tener problemas de CORS, pero el widget manejará el fallback
  static String getDefaultAvatarUrl(String nick) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final encodedNick = Uri.encodeComponent(nick);
    final url = '$_defaultAvatarUrl?username=$encodedNick&size=400&format=png&t=$timestamp';
    // print('🔍 [AVATAR] Generated default avatar URL for "$nick": $url');
    return url;
  }
  
  // Nota: Los avatares pueden fallar por CORS en web, pero el widget UserAvatar
  // usa WebHtmlElementStrategy.prefer que intenta usar elementos HTML <img>
  // que no tienen las mismas restricciones CORS estrictas.
  
  // Verificar si un avatar existe (usando nick exacto case-sensitive)
  static Future<bool> avatarExists(String nick) async {
    try {
      final url = getAvatarUrl(nick);
      // print('🔍 [AVATAR] Checking if avatar exists for "$nick": $url');
      final response = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 3),
      );
      final exists = response.statusCode == 200;
      // print('🔍 [AVATAR] Avatar exists for "$nick": $exists (status: ${response.statusCode})');
      return exists;
    } catch (e) {
      // print('🔍 [AVATAR] Error checking avatar for "$nick": $e');
      return false;
    }
  }
  
  // Obtener la URL correcta del avatar (siguiendo la lógica del plugin)
  // 1. Intenta con el avatar personalizado usando hash MD5 del nick exacto
  // 2. Si no existe, usa el generador de avatares por defecto
  static Future<String?> getCorrectAvatarUrl(String nick) async {
    if (nick.isEmpty) {
      return null;
    }
    
    // Limpiar el nick (solo trim, mantener case-sensitive)
    final cleanNick = nick.trim();
    
    // En web, usar directamente el generador de avatares por defecto para evitar:
    // 1. Errores 404 que causan problemas de CORB (Cross-Origin Read Blocking)
    // 2. El servidor devuelve HTML con Content-Type: text/html en lugar de image/png
    // 3. Esto causa que el navegador bloquee las respuestas por seguridad
    // El generador por defecto debería tener mejor soporte CORS y siempre devolver una imagen
    try {
      // En web, usar directamente el generador por defecto para evitar errores CORB
      // En otras plataformas, intentar primero el avatar personalizado
      if (PlatformUtils.isWeb) {
        // Usar el generador por defecto que siempre devuelve una imagen válida
        // Esto evita intentar cargar avatares que no existen (404) que causan CORB
        return getDefaultAvatarUrl(cleanNick);
      } else {
        // En plataformas nativas, intentar primero el avatar personalizado
        return getAvatarUrl(cleanNick);
      }
    } catch (e) {
      // Si hay algún error, usar el generador por defecto como fallback
      return getDefaultAvatarUrl(cleanNick);
    }
  }
}
