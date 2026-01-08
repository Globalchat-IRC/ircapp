import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Servicio para gestión de privacidad y modo incógnito
class PrivacyService {
  static final PrivacyService _instance = PrivacyService._internal();
  factory PrivacyService() => _instance;
  PrivacyService._internal();

  bool _isIncognitoMode = false;
  bool _hidePresence = false;
  bool _hideTyping = false;
  bool _allowWhois = true;
  bool _saveHistory = true;
  List<String> _blockedUsers = [];
  List<String> _allowedUsers = []; // Usuarios que pueden ver el estado

  /// Inicializa el servicio cargando preferencias
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isIncognitoMode = prefs.getBool('privacy_incognito') ?? false;
    _hidePresence = prefs.getBool('privacy_hide_presence') ?? false;
    _hideTyping = prefs.getBool('privacy_hide_typing') ?? false;
    _allowWhois = prefs.getBool('privacy_allow_whois') ?? true;
    _saveHistory = prefs.getBool('privacy_save_history') ?? true;
    _blockedUsers = prefs.getStringList('privacy_blocked_users') ?? [];
    _allowedUsers = prefs.getStringList('privacy_allowed_users') ?? [];
  }

  /// Modo incógnito activado
  bool get isIncognitoMode => _isIncognitoMode;
  
  /// Ocultar estado de presencia
  bool get hidePresence => _hidePresence;
  
  /// Ocultar indicador de typing
  bool get hideTyping => _hideTyping;
  
  /// Permitir WHOIS
  bool get allowWhois => _allowWhois;
  
  /// Guardar historial
  bool get saveHistory => _saveHistory;
  
  /// Lista de usuarios bloqueados
  List<String> get blockedUsers => List.unmodifiable(_blockedUsers);
  
  /// Lista de usuarios permitidos
  List<String> get allowedUsers => List.unmodifiable(_allowedUsers);

  /// Activar/desactivar modo incógnito
  Future<void> setIncognitoMode(bool enabled) async {
    _isIncognitoMode = enabled;
    if (enabled) {
      // En modo incógnito, desactivar guardado de historial
      _saveHistory = false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_incognito', enabled);
    await prefs.setBool('privacy_save_history', _saveHistory);
  }

  /// Configurar ocultar presencia
  Future<void> setHidePresence(bool hide) async {
    _hidePresence = hide;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_hide_presence', hide);
  }

  /// Configurar ocultar typing
  Future<void> setHideTyping(bool hide) async {
    _hideTyping = hide;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_hide_typing', hide);
  }

  /// Configurar permitir WHOIS
  Future<void> setAllowWhois(bool allow) async {
    _allowWhois = allow;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_allow_whois', allow);
  }

  /// Configurar guardar historial
  Future<void> setSaveHistory(bool save) async {
    if (!_isIncognitoMode) {
      _saveHistory = save;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('privacy_save_history', save);
    }
  }

  /// Bloquear un usuario
  Future<void> blockUser(String nick) async {
    if (!_blockedUsers.contains(nick.toLowerCase())) {
      _blockedUsers.add(nick.toLowerCase());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('privacy_blocked_users', _blockedUsers);
    }
  }

  /// Desbloquear un usuario
  Future<void> unblockUser(String nick) async {
    _blockedUsers.remove(nick.toLowerCase());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('privacy_blocked_users', _blockedUsers);
  }

  /// Agregar usuario a lista de permitidos
  Future<void> allowUser(String nick) async {
    if (!_allowedUsers.contains(nick.toLowerCase())) {
      _allowedUsers.add(nick.toLowerCase());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('privacy_allowed_users', _allowedUsers);
    }
  }

  /// Remover usuario de lista de permitidos
  Future<void> disallowUser(String nick) async {
    _allowedUsers.remove(nick.toLowerCase());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('privacy_allowed_users', _allowedUsers);
  }

  /// Verificar si un usuario está bloqueado
  bool isUserBlocked(String nick) {
    return _blockedUsers.contains(nick.toLowerCase());
  }

  /// Verificar si un usuario puede ver el estado
  bool canUserSeePresence(String nick) {
    if (_allowedUsers.isEmpty) return true; // Si no hay lista, todos pueden ver
    return _allowedUsers.contains(nick.toLowerCase());
  }
}





