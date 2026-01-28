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
        
        if (fullUrl.isNotEmpty) {
          // Usar Uri.parse para decodificar correctamente los parámetros
          final fullUri = Uri.parse(fullUrl);
          final themeParam = fullUri.queryParameters['theme'];
          
          if (themeParam != null && themeParam.trim().isNotEmpty) {
            final themeName = themeParam.trim();
            
            // Buscar el tema por nombre (case-insensitive y sin espacios extra)
            AppTheme? foundTheme;
            final normalizedThemeName = themeName.toLowerCase().trim();
            
            // Buscar en todos los temas
            for (final theme in AppTheme.themes) {
              if (theme.name.toLowerCase().trim() == normalizedThemeName) {
                foundTheme = theme;
                break;
              }
            }
            
            if (foundTheme != null) {
              state = foundTheme;
              _themeLoaded = true;
              // No guardar en SharedPreferences el tema de URL para no sobrescribir la preferencia del usuario
              return;
            }
          }
        } else {
          // Fallback a Uri.base si location.href está vacío
          final uri = Uri.base;
          final themeParam = uri.queryParameters['theme'];
          
          if (themeParam != null && themeParam.trim().isNotEmpty) {
            final themeName = themeParam.trim();
            
            AppTheme? foundTheme;
            final normalizedThemeName = themeName.toLowerCase().trim();
            
            // Buscar en todos los temas
            for (final theme in AppTheme.themes) {
              if (theme.name.toLowerCase().trim() == normalizedThemeName) {
                foundTheme = theme;
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
