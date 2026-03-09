import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color error;

  AppTheme({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.error,
  });

  ThemeData toThemeData() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        error: error,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(color: surface, elevation: 2),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: textPrimary,
      ),
    );
  }

  ThemeData toDarkThemeData() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        error: error,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(color: surface, elevation: 2),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        hintStyle: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: textPrimary,
      ),
    );
  }

  /// Tema "Sistema": sigue preferencia claro/oscuro del SO (estilo plugin auto-dark de mlite2).
  static const String kSystemThemeName = 'Sistema';

  static final List<AppTheme> themes = [
    AppTheme(
      name: 'GlobalChat',
      primary: const Color(0xFFFF8C00), // Naranja oscuro
      secondary: const Color(0xFFFFA500), // Naranja
      accent: const Color(0xFFFFD700), // Amarillo dorado
      background: const Color(0xFF1A1A1A), // Fondo oscuro
      surface: const Color(0xFF2B2B2B), // Superficie oscura
      textPrimary: Colors.white,
      textSecondary: Colors.white70,
      error: Colors.redAccent,
    ),
    AppTheme(
      name: kSystemThemeName,
      primary: Colors.blue[700]!,
      secondary: Colors.blue[400]!,
      accent: Colors.orange,
      background: const Color(0xFFF5F5F5), // Gris muy claro
      surface: Colors.grey[200]!,
      textPrimary: Colors.black87,
      textSecondary: Colors.grey[700]!,
      error: Colors.red,
    ),
    AppTheme(
      name: 'Oscuro',
      primary: const Color(0xFF4A90E2), // Azul moderno
      secondary: const Color(0xFF6BB3FF), // Azul claro
      accent: const Color(0xFF00D4FF), // Cyan brillante
      background: const Color(0xFF121212), // Fondo oscuro Material Design
      surface: const Color(0xFF1E1E1E), // Superficie oscura con buen contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFB0B0B0), // Gris claro legible
      error: const Color(0xFFFF5252), // Rojo Material Design
    ),
    AppTheme(
      name: 'Claro',
      primary: Colors.blue[700]!,
      secondary: Colors.blue[400]!,
      accent: Colors.orange,
      background: Colors.white,
      surface: Colors.grey[100]!,
      textPrimary: Colors.black87,
      textSecondary: Colors.grey[700]!,
      error: Colors.red,
    ),
    AppTheme(
      name: 'Azul',
      primary: const Color(0xFF3B82F6), // Azul moderno vibrante
      secondary: const Color(0xFF60A5FA), // Azul medio
      accent: const Color(0xFF93C5FD), // Azul claro
      background: const Color(0xFF0F172A), // Azul oscuro profundo
      surface: const Color(0xFF1E293B), // Superficie azul oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFCBD5E1), // Gris azulado claro
      error: const Color(0xFFEF4444), // Rojo moderno
    ),
    AppTheme(
      name: 'Verde',
      primary: const Color(0xFF10B981), // Verde esmeralda moderno
      secondary: const Color(0xFF34D399), // Verde medio
      accent: const Color(0xFF6EE7B7), // Verde claro
      background: const Color(0xFF064E3B), // Verde oscuro profundo
      surface: const Color(0xFF065F46), // Superficie verde oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFA7F3D0), // Verde claro legible
      error: const Color(0xFFEF4444), // Rojo moderno
    ),
    AppTheme(
      name: 'Púrpura',
      primary: const Color(0xFF8B5CF6), // Púrpura moderno vibrante
      secondary: const Color(0xFFA78BFA), // Púrpura medio
      accent: const Color(0xFFC4B5FD), // Púrpura claro
      background: const Color(0xFF1E1B4B), // Púrpura oscuro profundo
      surface: const Color(
        0xFF312E81,
      ), // Superficie púrpura oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFDDD6FE), // Púrpura claro legible
      error: const Color(0xFFEF4444), // Rojo moderno
    ),
    AppTheme(
      name: 'Rojo',
      primary: const Color(0xFFEF4444), // Rojo moderno vibrante
      secondary: const Color(0xFFF87171), // Rojo medio
      accent: const Color(0xFFFCA5A5), // Rojo claro
      background: const Color(0xFF7F1D1D), // Rojo oscuro profundo
      surface: const Color(0xFF991B1B), // Superficie roja oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFFEE2E2), // Rojo claro legible
      error: const Color(0xFFDC2626), // Rojo más oscuro para errores
    ),
    AppTheme(
      name: 'Rosa',
      primary: const Color(0xFFEC4899), // Rosa moderno vibrante
      secondary: const Color(0xFFF472B6), // Rosa medio
      accent: const Color(0xFFF9A8D4), // Rosa claro
      background: const Color(0xFF831843), // Rosa oscuro profundo
      surface: const Color(0xFF9F1239), // Superficie rosa oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFFCE7F3), // Rosa claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Amarillo',
      primary: const Color(0xFFF59E0B), // Amarillo dorado
      secondary: const Color(0xFFFBBF24), // Amarillo medio
      accent: const Color(0xFFFCD34D), // Amarillo claro
      background: const Color(0xFF78350F), // Amarillo oscuro profundo
      surface: const Color(
        0xFF92400E,
      ), // Superficie amarilla oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFFEF3C7), // Amarillo claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Cyan',
      primary: const Color(0xFF06B6D4), // Cyan moderno
      secondary: const Color(0xFF22D3EE), // Cyan medio
      accent: const Color(0xFF67E8F9), // Cyan claro
      background: const Color(0xFF164E63), // Cyan oscuro profundo
      surface: const Color(0xFF155E75), // Superficie cyan oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFCFFAFE), // Cyan claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Naranja',
      primary: const Color(0xFFF97316), // Naranja moderno
      secondary: const Color(0xFFFB923C), // Naranja medio
      accent: const Color(0xFFFDBA74), // Naranja claro
      background: const Color(0xFF7C2D12), // Naranja oscuro profundo
      surface: const Color(
        0xFF9A3412,
      ), // Superficie naranja oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFFFEDD5), // Naranja claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Índigo',
      primary: const Color(0xFF6366F1), // Índigo moderno
      secondary: const Color(0xFF818CF8), // Índigo medio
      accent: const Color(0xFFA5B4FC), // Índigo claro
      background: const Color(0xFF312E81), // Índigo oscuro profundo
      surface: const Color(
        0xFF3730A3,
      ), // Superficie índigo oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFE0E7FF), // Índigo claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Esmeralda',
      primary: const Color(0xFF059669), // Esmeralda moderno
      secondary: const Color(0xFF10B981), // Esmeralda medio
      accent: const Color(0xFF34D399), // Esmeralda claro
      background: const Color(0xFF064E3B), // Esmeralda oscuro profundo
      surface: const Color(
        0xFF065F46,
      ), // Superficie esmeralda oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFD1FAE5), // Esmeralda claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Teal',
      primary: const Color(0xFF14B8A6), // Teal moderno
      secondary: const Color(0xFF2DD4BF), // Teal medio
      accent: const Color(0xFF5EEAD4), // Teal claro
      background: const Color(0xFF134E4A), // Teal oscuro profundo
      surface: const Color(0xFF0F766E), // Superficie teal oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFCCFBF1), // Teal claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Fucsia',
      primary: const Color(0xFFD946EF), // Fucsia moderno
      secondary: const Color(0xFFE879F9), // Fucsia medio
      accent: const Color(0xFFF0ABFC), // Fucsia claro
      background: const Color(0xFF701A75), // Fucsia oscuro profundo
      surface: const Color(
        0xFF86198F,
      ), // Superficie fucsia oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFFAE8FF), // Fucsia claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Lima',
      primary: const Color(0xFF84CC16), // Lima moderno
      secondary: const Color(0xFFA3E635), // Lima medio
      accent: const Color(0xFFD9F99D), // Lima claro
      background: const Color(0xFF365314), // Lima oscuro profundo
      surface: const Color(0xFF3F6212), // Superficie lima oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFF7FEE7), // Lima claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Ámbar',
      primary: const Color(0xFFF59E0B), // Ámbar moderno
      secondary: const Color(0xFFFBBF24), // Ámbar medio
      accent: const Color(0xFFFDE047), // Ámbar claro
      background: const Color(0xFF78350F), // Ámbar oscuro profundo
      surface: const Color(0xFF92400E), // Superficie ámbar oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFFEF9C3), // Ámbar claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Violeta',
      primary: const Color(0xFF8B5CF6), // Violeta moderno
      secondary: const Color(0xFFA78BFA), // Violeta medio
      accent: const Color(0xFFC4B5FD), // Violeta claro
      background: const Color(0xFF4C1D95), // Violeta oscuro profundo
      surface: const Color(
        0xFF5B21B6,
      ), // Superficie violeta oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFEDE9FE), // Violeta claro legible
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'Radioactive',
      primary: const Color(0xFF39FF14), // Verde neón brillante (radioactivo)
      secondary: const Color(0xFF7FFF00), // Verde chartreuse
      accent: const Color(0xFFADFF2F), // Verde amarillento
      background: const Color(0xFF0A0A0A), // Negro profundo
      surface: const Color(0xFF1A1A1A), // Gris muy oscuro
      textPrimary: const Color(0xFF39FF14), // Verde neón para texto
      textSecondary: const Color(
        0xFF7FFF00,
      ), // Verde chartreuse para texto secundario
      error: const Color(0xFFFF1744), // Rojo neón para errores
    ),
    AppTheme(
      name: 'Semana Santa Sevilla',
      primary: const Color(0xFF6A1B9A), // Morado litúrgico profundo
      secondary: const Color(0xFF8E24AA), // Morado medio
      accent: const Color(0xFFFFD700), // Dorado (oro de los pasos)
      background: const Color(0xFF1A0A1A), // Fondo oscuro con tinte morado
      surface: const Color(0xFF2D1B2D), // Superficie morada oscura
      textPrimary: const Color(0xFFFFD700), // Texto dorado (como los detalles)
      textSecondary: const Color(
        0xFFD1C4E9,
      ), // Morado claro para texto secundario
      error: const Color(
        0xFFC62828,
      ), // Rojo oscuro (como las túnicas de algunas cofradías)
    ),
    AppTheme(
      name: 'Canal Sur',
      primary: const Color(0xFF00A859), // Verde Canal Sur
      secondary: const Color(0xFF00C96A), // Verde claro
      accent: const Color(0xFF00FF88), // Verde brillante
      background: const Color(0xFF0A1F0F), // Fondo verde oscuro
      surface: const Color(0xFF1A3F2A), // Superficie verde oscura
      textPrimary: Colors.white, // Texto blanco
      textSecondary: const Color(
        0xFFB8E6D1,
      ), // Verde claro para texto secundario
      error: const Color(0xFFDC2626), // Rojo para errores
    ),
    AppTheme(
      name: 'NuestrasVoces',
      primary: const Color(
        0xFF1E3A8A,
      ), // Azul oscuro elegante (como el fondo del sitio)
      secondary: const Color(0xFF3B82F6), // Azul vibrante (acento principal)
      accent: const Color(0xFF60A5FA), // Azul claro brillante (para destacar)
      background: const Color(
        0xFF0F172A,
      ), // Fondo azul muy oscuro (negro azulado)
      surface: const Color(0xFF1E293B), // Superficie azul oscura con contraste
      textPrimary: Colors.white, // Texto blanco (legible y elegante)
      textSecondary: const Color(
        0xFFCBD5E1,
      ), // Gris azulado claro (texto secundario)
      error: const Color(0xFFEF4444), // Rojo moderno para errores
    ),
    AppTheme(
      name: 'mIRC',
      primary: const Color(
        0xFFC0C0C0,
      ), // Gris claro para barras de herramientas (estilo mIRC clásico)
      secondary: const Color(
        0xFF808080,
      ), // Gris medio para elementos secundarios
      accent: const Color(0xFF0000FF), // Azul IRC clásico para links y acentos
      background: const Color(0xFFFFFFFF), // Fondo blanco (estilo mIRC clásico)
      surface: const Color(
        0xFFF0F0F0,
      ), // Gris muy claro para superficies (paneles)
      textPrimary: const Color(0xFF000000), // Texto negro (estilo mIRC clásico)
      textSecondary: const Color(
        0xFF404040,
      ), // Gris oscuro para texto secundario
      error: const Color(0xFFFF0000), // Rojo clásico para errores
    ),
  ];
}
