import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

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
    
    // En web, debido a problemas de CORS, directamente usar el generador por defecto
    // que debería funcionar mejor con elementos HTML <img>
    // En plataformas nativas, intentar primero el avatar personalizado
    // TODO: Verificar si PlatformUtils está disponible aquí
    // Por ahora, intentar siempre el avatar personalizado primero
    // El widget UserAvatar manejará el fallback si falla
    
    // Paso 1: Intentar con el avatar personalizado (hash MD5 del nick exacto)
    final avatarUrl = getAvatarUrl(cleanNick);
    
    // En web, no verificar la existencia del avatar (causa errores de CORS)
    // Dejar que el widget Image.network con WebHtmlElementStrategy.prefer
    // intente cargarlo usando elementos HTML <img>
    // Si falla, el errorBuilder mostrará el fallback
    
    // Retornar la URL del avatar personalizado
    // El widget se encargará de mostrar el fallback si no se puede cargar
    return avatarUrl;
  }
}
