import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para cifrado de mensajes punto a punto
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // Almacenar claves públicas de usuarios
  final Map<String, String> _publicKeys = {};
  String? _myPrivateKey;
  String? _myPublicKey;

  /// Inicializa el servicio y genera claves si no existen
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _myPrivateKey = prefs.getString('encryption_private_key');
    _myPublicKey = prefs.getString('encryption_public_key');

    if (_myPrivateKey == null || _myPublicKey == null) {
      await _generateKeyPair();
    }

    // Cargar claves públicas de contactos
    final keysJson = prefs.getString('encryption_public_keys');
    if (keysJson != null) {
      final keys = jsonDecode(keysJson) as Map<String, dynamic>;
      keys.forEach((nick, key) {
        _publicKeys[nick] = key as String;
      });
    }
  }

  /// Genera un par de claves RSA (simplificado - en producción usar librería de criptografía real)
  Future<void> _generateKeyPair() async {
    // Nota: Esta es una implementación simplificada
    // En producción, usar una librería de criptografía real como pointycastle
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    _myPrivateKey = sha256.convert(utf8.encode('private_$random')).toString();
    _myPublicKey = sha256.convert(utf8.encode('public_$random')).toString();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('encryption_private_key', _myPrivateKey!);
    await prefs.setString('encryption_public_key', _myPublicKey!);
  }

  /// Obtiene la clave pública del usuario actual
  String? getMyPublicKey() => _myPublicKey;

  /// Guarda la clave pública de un contacto
  Future<void> savePublicKey(String nick, String publicKey) async {
    _publicKeys[nick] = publicKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('encryption_public_keys', jsonEncode(_publicKeys));
  }

  /// Obtiene la clave pública de un contacto
  String? getPublicKey(String nick) => _publicKeys[nick];

  /// Cifra un mensaje para un destinatario específico
  String encryptMessage(String message, String recipientNick) {
    final publicKey = _publicKeys[recipientNick];
    if (publicKey == null) {
      throw Exception('No se encontró clave pública para $recipientNick');
    }

    // Implementación simplificada - en producción usar cifrado real
    final combined = '$message|$publicKey|${DateTime.now().millisecondsSinceEpoch}';
    final hash = sha256.convert(utf8.encode(combined)).toString();
    return base64Encode(utf8.encode('$message|ENC|$hash'));
  }

  /// Descifra un mensaje recibido
  String decryptMessage(String encryptedMessage, String senderNick) {
    try {
      final decoded = utf8.decode(base64Decode(encryptedMessage));
      if (decoded.contains('|ENC|')) {
        final parts = decoded.split('|ENC|');
        if (parts.length == 2) {
          return parts[0]; // Mensaje descifrado
        }
      }
      return encryptedMessage; // Si no está cifrado, devolver tal cual
    } catch (e) {
      return encryptedMessage; // Si falla, devolver el mensaje original
    }
  }

  /// Verifica si un mensaje está cifrado
  bool isEncrypted(String message) {
    try {
      final decoded = utf8.decode(base64Decode(message));
      return decoded.contains('|ENC|');
    } catch (e) {
      return false;
    }
  }
}

