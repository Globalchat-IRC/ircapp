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
    return s;
  }

  /// Alias del parámetro URL -> nombre exacto del tema en AppTheme.themes.
  static const Map<String, String> _themeParamAliases = {
    'oscuro': 'Oscuro',
    'dark': 'Oscuro',
    'claro': 'Claro',
    'light': 'Claro',
    'globalchat': 'GlobalChat',
    'naranja': 'Naranja',
    'orange': 'Naranja',
    'azul': 'Azul',
    'blue': 'Azul',
    'verde': 'Verde',
    'green': 'Verde',
    'sistema': 'Sistema',
    'system': 'Sistema',
  };

  @override
  AppTheme build() {
    _initializeTheme();
    return AppTheme.themes[0]; // Default to GlobalChat theme
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

  Future<void> _loadTheme() async {
    if (_themeLoaded) return; // Ya se cargó un tema, no sobrescribir
    
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('appTheme') ?? 'GlobalChat';
    state = AppTheme.themes.firstWhere(
      (theme) => theme.name == themeName,
      orElse: () => AppTheme.themes[0], // Fallback to default
    );
    _themeLoaded = true;
  }

  Future<void> setTheme(AppTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appTheme', theme.name);
    _themeLoaded = true;
  }
}
