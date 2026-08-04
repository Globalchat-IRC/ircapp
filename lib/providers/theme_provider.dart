import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_theme.dart';
import '../utils/platform_utils.dart';
// Conditional import for web
import '../utils/html_stub.dart' as html;

final themeProvider = NotifierProvider<ThemeNotifier, AppTheme>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<AppTheme> {
  bool _themeLoaded = false;

  /// Normaliza nombre para comparar: minúsculas, sin acentos, trim.
  static String _normalizeThemeName(String name) {
    String s = name.trim().toLowerCase();
    const withAccents = 'áéíóúüñàèìòù';
    const withoutAccents = 'aeiouunaeiou';
    for (int i = 0; i < withAccents.length; i++) {
      s = s.replaceAll(withAccents[i], withoutAccents[i]);
    }
    // Permitir parámetros más cómodos en URL: sin espacios, guiones o underscores.
    s = s.replaceAll(RegExp(r'[\s\-_]+'), '');
    return s;
  }

  /// Alias del parámetro URL -> nombre exacto del tema en AppTheme.themes.
  static const Map<String, String> _themeParamAliases = {
    'oscuro': 'Oscuro',
    'dark': 'Oscuro',
    'claro': 'Claro',
    'light': 'Claro',
    'globalchat': 'GlobalChat',
    'sistema': 'Sistema',
    'system': 'Sistema',
    'naranja': 'Naranja',
    'orange': 'Naranja',
    'azul': 'Azul',
    'blue': 'Azul',
    'verde': 'Verde',
    'green': 'Verde',
    'purpura': 'Púrpura',
    'purple': 'Púrpura',
    'rojo': 'Rojo',
    'red': 'Rojo',
    'rosa': 'Rosa',
    'pink': 'Rosa',
    'amarillo': 'Amarillo',
    'yellow': 'Amarillo',
    'cyan': 'Cyan',
    'indigo': 'Índigo',
    'esmeralda': 'Esmeralda',
    'emerald': 'Esmeralda',
    'teal': 'Teal',
    'fucsia': 'Fucsia',
    'fuchsia': 'Fucsia',
    'lima': 'Lima',
    'lime': 'Lima',
    'ambar': 'Ámbar',
    'amber': 'Ámbar',
    'violeta': 'Violeta',
    'violet': 'Violeta',
    'radioactive': 'Radioactive',
    'semanasantasevilla': 'Semana Santa Sevilla',
    'holyweeksevilla': 'Semana Santa Sevilla',
    'canalsur': 'Canal Sur',
    'nuestrasvoces': 'NuestrasVoces',
    'mirc': 'mIRC',
    'qualia': 'Qualia Radio',
    'qualiaradio': 'Qualia Radio',
    'qualia_radio': 'Qualia Radio',
  };

  @override
  AppTheme build() {
    _initializeTheme();
    return AppTheme.themes[2]; // Default to Oscuro theme
  }

  Future<void> _initializeTheme() async {
    // Primero intentar leer el tema de la URL (solo en web)
    if (PlatformUtils.isWeb) {
      try {
        final window = html.window;
        final location = window.location;
        final fullUrl = location.href ?? '';
        
        String? themeParam;
        if (fullUrl.isNotEmpty) {
          final fullUri = Uri.parse(fullUrl);
          themeParam = fullUri.queryParameters['theme'];
        }
        if (themeParam == null || themeParam.trim().isEmpty) {
          final uri = Uri.base;
          themeParam = uri.queryParameters['theme'];
        }
        
        if (themeParam != null && themeParam.trim().isNotEmpty) {
          final themeName = themeParam.trim();
          final normalizedInput = _normalizeThemeName(themeName);
          
          // Resolver alias (ej. "dark" -> "Oscuro") o buscar por nombre normalizado
          String? canonicalName = _themeParamAliases[normalizedInput];
          if (canonicalName == null) {
            for (final t in AppTheme.themes) {
              if (_normalizeThemeName(t.name) == normalizedInput) {
                canonicalName = t.name;
                break;
              }
            }
          }
          
          if (canonicalName != null) {
            AppTheme? foundTheme;
            for (final t in AppTheme.themes) {
              if (t.name == canonicalName) {
                foundTheme = t;
                break;
              }
            }
            if (foundTheme != null) {
              state = foundTheme;
              _themeLoaded = true;
              return;
            }
          }
        }
      } catch (e) {
        // Si hay error leyendo la URL, continuar con la carga normal
      }
    }
    
    // Si no hay tema en la URL o no estamos en web, cargar desde SharedPreferences
    await _loadTheme();
  }

  /// Aplica un tema recibido por parámetro URL sin guardarlo en preferencias.
  /// Devuelve true si se reconoció y aplicó correctamente.
  bool applyThemeParam(String? themeParam) {
    if (themeParam == null || themeParam.trim().isEmpty) return false;

    final normalizedInput = _normalizeThemeName(themeParam);

    String? canonicalName = _themeParamAliases[normalizedInput];
    if (canonicalName == null) {
      for (final t in AppTheme.themes) {
        if (_normalizeThemeName(t.name) == normalizedInput) {
          canonicalName = t.name;
          break;
        }
      }
    }

    if (canonicalName == null) return false;

    for (final t in AppTheme.themes) {
      if (t.name == canonicalName) {
        state = t;
        _themeLoaded = true;
        return true;
      }
    }

    return false;
  }

  Future<void> _loadTheme() async {
    if (_themeLoaded) return; // Ya se cargó un tema, no sobrescribir
    
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('appTheme') ?? 'Oscuro';
    if (themeName == 'Personalizado') {
      final raw = prefs.getString('customTheme');
      if (raw != null && raw.isNotEmpty) {
        try {
          final custom = AppTheme.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          state = custom;
          _themeLoaded = true;
          return;
        } catch (_) {
          // Si el JSON es inválido, caer al tema por defecto
        }
      }
    }
    state = AppTheme.themes.firstWhere(
      (theme) => theme.name == themeName,
      orElse: () => AppTheme.themes[2], // Fallback to Oscuro
    );
    _themeLoaded = true;
  }

  Future<void> setTheme(AppTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTheme', theme.name);
    _themeLoaded = true;
  }

  /// Guarda un tema personalizado en JSON y lo aplica.
  Future<void> setCustomTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customTheme', jsonEncode(theme.toJson()));
    await prefs.setString('appTheme', 'Personalizado');
    state = theme;
    _themeLoaded = true;
  }
}
