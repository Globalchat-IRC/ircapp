import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de cifrado E2E real usando RSA + AES.
///
/// Flujo:
/// 1. Cada usuario genera un par de claves RSA (2048-bit)
/// 2. La clave pública se comparte con contactos
/// 3. Los mensajes se cifran con AES-256-CBC
/// 4. La clave AES se cifra con la clave pública RSA del destinatario
///
/// IMPORTANTE: Las claves privadas NUNCA salen del dispositivo.
class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>? _keyPair;
  final Map<String, RSAPublicKey> _contactPublicKeys = {};

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    final pubModulus = prefs.getString('enc_pub_modulus');
    final pubExponent = prefs.getString('enc_pub_exponent');
    final privModulus = prefs.getString('enc_priv_modulus');
    final privExponent = prefs.getString('enc_priv_exponent');
    final privP = prefs.getString('enc_priv_p');
    final privQ = prefs.getString('enc_priv_q');

    if (pubModulus != null && privModulus != null) {
      _keyPair = AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(
        RSAPublicKey(BigInt.parse(pubModulus), BigInt.parse(pubExponent!)),
        RSAPrivateKey(
          BigInt.parse(privModulus),
          BigInt.parse(privExponent!),
          BigInt.parse(privP!),
          BigInt.parse(privQ!),
        ),
      );
    } else {
      await _generateKeyPair();
    }

    final keysJson = prefs.getString('enc_contact_keys');
    if (keysJson != null) {
      final keys = jsonDecode(keysJson) as Map<String, dynamic>;
      for (final entry in keys.entries) {
        _contactPublicKeys[entry.key] = RSAPublicKey(
          BigInt.parse(entry.value['modulus']),
          BigInt.parse(entry.value['exponent']),
        );
      }
    }
  }

  Future<void> _generateKeyPair() async {
    final secureRandom = _createSecureRandom();
    final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64);
    final generator = RSAKeyGenerator();
    generator.init(ParametersWithRandom(keyParams, secureRandom));
    _keyPair = generator.generateKeyPair();

    final pub = _keyPair!.publicKey as RSAPublicKey;
    final priv = _keyPair!.privateKey as RSAPrivateKey;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('enc_pub_modulus', pub.modulus.toString());
    await prefs.setString('enc_pub_exponent', pub.exponent.toString());
    await prefs.setString('enc_priv_modulus', priv.modulus.toString());
    await prefs.setString('enc_priv_exponent', priv.exponent.toString());
    await prefs.setString('enc_priv_p', priv.p.toString());
    await prefs.setString('enc_priv_q', priv.q.toString());
  }

  SecureRandom _createSecureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seeds = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  String? getMyPublicKeyString() {
    if (_keyPair == null) return null;
    final pub = _keyPair!.publicKey as RSAPublicKey;
    return jsonEncode({
      'modulus': pub.modulus.toString(),
      'exponent': pub.exponent.toString(),
    });
  }

  Future<void> savePublicKey(String nick, String publicKeyJson) async {
    final data = jsonDecode(publicKeyJson) as Map<String, dynamic>;
    _contactPublicKeys[nick] = RSAPublicKey(
      BigInt.parse(data['modulus']),
      BigInt.parse(data['exponent']),
    );
    await _saveContactKeys();
  }

  Future<void> _saveContactKeys() async {
    final map = <String, dynamic>{};
    for (final entry in _contactPublicKeys.entries) {
      map[entry.key] = {
        'modulus': entry.value.modulus.toString(),
        'exponent': entry.value.exponent.toString(),
      };
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('enc_contact_keys', jsonEncode(map));
  }

  String? encryptMessage(String message, String recipientNick) {
    final recipientKey = _contactPublicKeys[recipientNick];
    if (recipientKey == null || _keyPair == null) return null;

    try {
      final aesKey = _generateRandomBytes(32);
      final iv = _generateRandomBytes(16);

      final encryptedMessage = _aesEncrypt(
        Uint8List.fromList(utf8.encode(message)),
        aesKey,
        iv,
      );

      final encryptedAesKey = _rsaEncrypt(aesKey, recipientKey);

      return 'E2E:${jsonEncode({
        'key': base64Encode(encryptedAesKey),
        'iv': base64Encode(iv),
        'msg': base64Encode(encryptedMessage),
      })}';
    } catch (e) {
      return null;
    }
  }

  String? decryptMessage(String encryptedPayload, String senderNick) {
    if (!encryptedPayload.startsWith('E2E:')) return null;
    if (_keyPair == null) return null;

    try {
      final jsonStr = encryptedPayload.substring(4);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final encryptedAesKey = base64Decode(data['key']);
      final iv = base64Decode(data['iv']);
      final encryptedMessage = base64Decode(data['msg']);

      final aesKey = _rsaDecrypt(encryptedAesKey);
      final decrypted = _aesDecrypt(encryptedMessage, aesKey, iv);

      return utf8.decode(decrypted);
    } catch (e) {
      return null;
    }
  }

  bool isEncrypted(String message) => message.startsWith('E2E:');

  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => random.nextInt(256)));
  }

  Uint8List _aesEncrypt(Uint8List data, Uint8List key, Uint8List iv) {
    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(true, ParametersWithIV(KeyParameter(key), iv));
    final paddedData = _pkcs7Pad(data, 16);
    final output = Uint8List(paddedData.length);
    for (var i = 0; i < paddedData.length; i += 16) {
      cipher.processBlock(paddedData, i, output, i);
    }
    return output;
  }

  Uint8List _aesDecrypt(Uint8List data, Uint8List key, Uint8List iv) {
    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(key), iv));
    final output = Uint8List(data.length);
    for (var i = 0; i < data.length; i += 16) {
      cipher.processBlock(data, i, output, i);
    }
    return _pkcs7Unpad(output);
  }

  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLen);
    padded.setAll(0, data);
    padded.fillRange(data.length, padded.length, padLen);
    return padded;
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    final padLen = data.last;
    return data.sublist(0, data.length - padLen);
  }

  Uint8List _rsaEncrypt(Uint8List data, RSAPublicKey publicKey) {
    final cipher = RSAEngine()
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return cipher.process(data);
  }

  Uint8List _rsaDecrypt(Uint8List data) {
    final priv = _keyPair!.privateKey as RSAPrivateKey;
    final cipher = RSAEngine()
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(priv));
    return cipher.process(data);
  }
}
