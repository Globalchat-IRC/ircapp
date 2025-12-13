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
        background: background,
        surface: surface,
        error: error,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onBackground: textPrimary,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
      ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
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
        background: background,
        surface: surface,
        error: error,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onBackground: textPrimary,
        onSurface: textPrimary,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
      ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: textPrimary,
      ),
    );
  }

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
      surface: const Color(0xFF312E81), // Superficie púrpura oscura con contraste
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFDDD6FE), // Púrpura claro legible
      error: const Color(0xFFEF4444), // Rojo moderno
    ),
  ];
}
