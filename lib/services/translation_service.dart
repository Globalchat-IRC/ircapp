import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/platform_utils.dart';

/// Servicio de traducción (estilo AutoTraductor IRC).
/// Usa MyMemory API (gratuita, sin clave). En web se usa proxy CORS para evitar bloqueos.
class TranslationService {
  static const String _baseUrl = 'https://api.mymemory.translated.net/get';
  /// Proxy CORS principal: allorigins devuelve el body raw (sin envoltorio).
  static const String _corsProxyUrl = 'https://api.allorigins.win/raw?url=';
  /// Fallback si el principal falla.
  static const String _corsProxyFallback = 'https://corsproxy.org/?';
  static const String targetLangEs = 'es';
  static const String targetLangEn = 'en';
  static const int minChars = 3;
  static const int cacheLimit = 200;
  static const Duration requestDelay = Duration(milliseconds: 500);

  final Map<String, String?> _cache = {};
  DateTime? _lastRequestTime;

  String _buildRequestUrl(String path, {bool useFallback = false}) {
    final url = '$_baseUrl$path';
    if (!PlatformUtils.isWeb) return url;
    if (useFallback) {
      return _corsProxyFallback + Uri.encodeComponent(url);
    }
    return _corsProxyUrl + Uri.encodeComponent(url);
  }

  /// En web: intenta con proxy principal; si falla (no 200 o excepción), reintenta con fallback.
  Future<http.Response> _getWithProxy(String path) async {
    try {
      final primary = Uri.parse(_buildRequestUrl(path));
      final res = await http.get(primary).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && res.body.trim().startsWith('{')) return res;
      final fallback = Uri.parse(_buildRequestUrl(path, useFallback: true));
      return http.get(fallback).timeout(const Duration(seconds: 15));
    } catch (_) {
      final fallback = Uri.parse(_buildRequestUrl(path, useFallback: true));
      return http.get(fallback).timeout(const Duration(seconds: 15));
    }
  }

  /// Traduce texto al español (detección automática del idioma).
  Future<String?> translateToSpanish(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || clean.length < minChars) return null;
    if (_cache.containsKey(clean)) return _cache[clean];
    await _rateLimit();
    try {
      final path = '?q=${Uri.encodeComponent(clean)}&langpair=en|$targetLangEs';
      final res = await (PlatformUtils.isWeb ? _getWithProxy(path) : http.get(Uri.parse(_buildRequestUrl(path))).timeout(const Duration(seconds: 15)));
      if (res.statusCode != 200) return _cacheAndReturn(clean, null);
      final body = res.body.trim();
      if (body.isEmpty || !body.startsWith('{')) return _cacheAndReturn(clean, null);
      final data = jsonDecode(body) as Map<String, dynamic>?;
      final translated = data?['responseData']?['translatedText'] as String?;
      if (translated == null || translated.trim().isEmpty) return _cacheAndReturn(clean, null);
      final t = translated.trim();
      if (t.toLowerCase() == clean.toLowerCase()) return _cacheAndReturn(clean, null);
      return _cacheAndReturn(clean, t);
    } catch (_) {
      return _cacheAndReturn(clean, null);
    }
  }

  /// Traduce texto del español al inglés (para /t enviar).
  Future<String?> translateToEnglish(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    await _rateLimit();
    try {
      final path = '?q=${Uri.encodeComponent(clean)}&langpair=es|$targetLangEn';
      final res = await (PlatformUtils.isWeb ? _getWithProxy(path) : http.get(Uri.parse(_buildRequestUrl(path))).timeout(const Duration(seconds: 15)));
      if (res.statusCode != 200) return null;
      final body = res.body.trim();
      if (body.isEmpty || !body.startsWith('{')) return null;
      final data = jsonDecode(body) as Map<String, dynamic>?;
      final translated = data?['responseData']?['translatedText'] as String?;
      return translated?.trim();
    } catch (_) {
      return null;
    }
  }

  String? _cacheAndReturn(String original, String? translated) {
    while (_cache.length >= cacheLimit && _cache.isNotEmpty) {
      _cache.remove(_cache.keys.first);
    }
    _cache[original] = translated;
    return translated;
  }

  Future<void> _rateLimit() async {
    if (_lastRequestTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < requestDelay) {
        await Future.delayed(requestDelay - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  void clearCache() {
    _cache.clear();
  }

  int get cacheSize => _cache.length;
}
