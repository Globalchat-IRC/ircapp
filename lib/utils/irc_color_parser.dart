import 'package:flutter/material.dart';

class IRCColorParser {
  // Colores mIRC estándar (16 colores)
  static const List<Color> mircColors = [
    Color(0xFFFFFFFF), // 0 - Blanco
    Color(0xFF000000), // 1 - Negro
    Color(0xFF00007F), // 2 - Azul oscuro
    Color(0xFF009300), // 3 - Verde
    Color(0xFFFC0000), // 4 - Rojo
    Color(0xFF7F0000), // 5 - Marrón
    Color(0xFF9C009C), // 6 - Púrpura
    Color(0xFFFC7F00), // 7 - Naranja
    Color(0xFFFFFC00), // 8 - Amarillo
    Color(0xFF00FC00), // 9 - Verde claro
    Color(0xFF009393), // 10 - Cian
    Color(0xFF00FFFF), // 11 - Azul claro
    Color(0xFF0000FC), // 12 - Azul
    Color(0xFFFF00FF), // 13 - Magenta
    Color(0xFF7F7F7F), // 14 - Gris
    Color(0xFFD2D2D2), // 15 - Gris claro
  ];

  // Parsear mensaje IRC con códigos de color y formato
  static List<TextSpan> parseIRCMessage(String message, {Color? defaultColor}) {
    final spans = <TextSpan>[];
    final defaultTextColor = defaultColor ?? Colors.white;
    
    int i = 0;
    Color? currentColor;
    Color? currentBackground;
    bool bold = false;
    bool italic = false;
    bool underline = false;
    
    StringBuffer currentText = StringBuffer();
    
    while (i < message.length) {
      final char = message[i];
      
      // Código de color: \x03[foreground][,background]
      if (char == '\x03') {
        // Guardar texto acumulado antes del código de color
        if (currentText.isNotEmpty) {
          spans.add(TextSpan(
            text: currentText.toString(),
            style: TextStyle(
              color: currentColor ?? defaultTextColor,
              backgroundColor: currentBackground,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ));
          currentText.clear();
        }
        
        i++; // Saltar \x03
        
        // Si \x03 está al final o seguido de un carácter no numérico, resetear colores
        if (i >= message.length) {
          currentColor = null;
          currentBackground = null;
          continue;
        }
        
        // Leer código de color de foreground
        String? colorCode;
        if (i < message.length && message[i].codeUnitAt(0) >= 48 && message[i].codeUnitAt(0) <= 57) {
          colorCode = message[i];
          i++;
          // Puede ser de 2 dígitos
          if (i < message.length && message[i].codeUnitAt(0) >= 48 && message[i].codeUnitAt(0) <= 57) {
            colorCode += message[i];
            i++;
          }
          
          final colorIndex = int.tryParse(colorCode);
          if (colorIndex != null && colorIndex >= 0 && colorIndex < mircColors.length) {
            currentColor = mircColors[colorIndex];
          } else {
            // Si el código de color no es válido, resetear
            currentColor = null;
          }
        } else {
          // Si no hay código numérico después de \x03, resetear colores
          currentColor = null;
          currentBackground = null;
          continue;
        }
        
        // Leer código de color de background (después de coma)
        if (i < message.length && message[i] == ',') {
          i++;
          String? bgCode;
          if (i < message.length && message[i].codeUnitAt(0) >= 48 && message[i].codeUnitAt(0) <= 57) {
            bgCode = message[i];
            i++;
            if (i < message.length && message[i].codeUnitAt(0) >= 48 && message[i].codeUnitAt(0) <= 57) {
              bgCode += message[i];
              i++;
            }
            
            final bgIndex = int.tryParse(bgCode);
            if (bgIndex != null && bgIndex >= 0 && bgIndex < mircColors.length) {
              currentBackground = mircColors[bgIndex];
            } else {
              currentBackground = null;
            }
          }
        } else {
          // Si no hay coma, no hay background
          currentBackground = null;
        }
        
        continue;
      }
      
      // Reset formato: \x0F
      if (char == '\x0F') {
        if (currentText.isNotEmpty) {
          spans.add(TextSpan(
            text: currentText.toString(),
            style: TextStyle(
              color: currentColor ?? defaultTextColor,
              backgroundColor: currentBackground,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ));
          currentText.clear();
        }
        currentColor = null;
        currentBackground = null;
        bold = false;
        italic = false;
        underline = false;
        i++;
        continue;
      }
      
      // Bold: \x02
      if (char == '\x02') {
        if (currentText.isNotEmpty) {
          spans.add(TextSpan(
            text: currentText.toString(),
            style: TextStyle(
              color: currentColor ?? defaultTextColor,
              backgroundColor: currentBackground,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ));
          currentText.clear();
        }
        bold = !bold;
        i++;
        continue;
      }
      
      // Underline: \x1F
      if (char == '\x1F') {
        if (currentText.isNotEmpty) {
          spans.add(TextSpan(
            text: currentText.toString(),
            style: TextStyle(
              color: currentColor ?? defaultTextColor,
              backgroundColor: currentBackground,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ));
          currentText.clear();
        }
        underline = !underline;
        i++;
        continue;
      }
      
      // Italic: \x1D
      if (char == '\x1D') {
        if (currentText.isNotEmpty) {
          spans.add(TextSpan(
            text: currentText.toString(),
            style: TextStyle(
              color: currentColor ?? defaultTextColor,
              backgroundColor: currentBackground,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ));
          currentText.clear();
        }
        italic = !italic;
        i++;
        continue;
      }
      
      // Carácter normal
      currentText.write(char);
      i++;
    }
    
    // Agregar texto restante
    if (currentText.isNotEmpty) {
      spans.add(TextSpan(
        text: currentText.toString(),
        style: TextStyle(
          color: currentColor ?? defaultTextColor,
          backgroundColor: currentBackground,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          decoration: underline ? TextDecoration.underline : null,
        ),
      ));
    }
    
    return spans.isEmpty 
        ? [TextSpan(text: message, style: TextStyle(color: defaultTextColor))]
        : spans;
  }
  
  // Limpiar códigos IRC de un mensaje (para búsqueda, etc.)
  static String stripIRCFormatting(String message, {bool aggressive = false}) {
    // Primero, limpiar códigos de color con formato completo: \x03[0-15][,0-15]?
    var cleaned = message.replaceAll(RegExp(r'\x03\d{1,2}(,\d{1,2})?'), '');
    // Luego, limpiar \x03 sueltos (sin código numérico)
    cleaned = cleaned.replaceAll('\x03', '');
    // Limpiar otros códigos de formato
    cleaned = cleaned
        .replaceAll('\x0F', '') // Reset
        .replaceAll('\x02', '') // Bold
        .replaceAll('\x1F', '') // Underline
        .replaceAll('\x1D', ''); // Italic
    
    // Limpiar caracteres de control adicionales que puedan aparecer
    // Limpiar caracteres de control no imprimibles (0x00-0x1F excepto los ya manejados)
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1A\x1C\x1E]'), '');
    
    // Limpiar el carácter ≡ (U+2261) que puede aparecer como código de formato mal formado
    cleaned = cleaned.replaceAll('≡', '');
    
    // Limpieza agresiva para bots: eliminar dígitos sueltos que aparecen antes de palabras
    // Esto elimina patrones como "4Emitiendo" -> "Emitiendo"
    if (aggressive) {
      // Eliminar dígitos sueltos al inicio de palabras (pero no números completos)
      cleaned = cleaned.replaceAll(RegExp(r'\b(\d)([A-Za-zÁÉÍÓÚáéíóúÑñ])'), r'$2');
      // Eliminar múltiples espacios y símbolos ≡ repetidos
      cleaned = cleaned.replaceAll(RegExp(r'≡+'), ' ');
      // Limpiar espacios múltiples
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    }
    
    return cleaned.trim();
  }
}

