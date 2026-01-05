# Release v1.0.5 - Barra de Lag en Tiempo Real

## 🎯 Nuevas Funcionalidades

### 📊 Barra de Lag en Tiempo Real
- **Indicador visual de latencia** en el AppBar junto al estado de conexión
- **Actualización automática cada 3 segundos** mediante PING/PONG del protocolo IRC
- **Colores indicativos** según la calidad de la conexión:
  - 🟢 **Verde** (< 100ms): Excelente conexión
  - 🟡 **Amarillo** (100-300ms): Buena conexión
  - 🟠 **Naranja** (300-500ms): Conexión regular
  - 🔴 **Rojo** (> 500ms): Conexión lenta
- **Medición precisa** usando el protocolo estándar IRC (PING/PONG)
- **Siempre visible** cuando hay conexión activa
- **Muestra el valor exacto** en milisegundos junto a la barra

### ⌨️ Autocompletado Mejorado
- **Navegación con flechas del teclado** restaurada para sugerencias de comandos y nicks
- **Tab para seleccionar** sugerencias activas
- **Sin bloquear el campo de texto** - ahora puedes escribir normalmente mientras navegas sugerencias

## 🐛 Correcciones

### Campo de Texto del Mensaje
- **Corregido problema de foco** que impedía escribir en el campo de texto
- **Mejorada la gestión de eventos de teclado** para evitar conflictos
- **Autocompletado funcional** sin interferir con la escritura normal

### Gestión de Eventos
- **Optimizada la detección de eventos de teclado** para mejor rendimiento
- **Corregidos problemas de sintaxis** en la estructura de widgets

## 🔧 Mejoras Técnicas

- **Medición de lag optimizada**: Envío inmediato de PING al conectar + actualización periódica cada 3 segundos
- **Gestión de estado mejorada**: Provider de lag integrado con Riverpod
- **Limpieza de recursos**: Timer de lag se detiene automáticamente al desconectar
- **Indicador visual mientras calcula**: Barra azul con "..." mientras se obtiene el primer valor de lag

## 📦 Archivos Modificados

- `lib/services/irc_service.dart`: Implementación de medición de lag con PING/PONG
- `lib/providers/irc_provider.dart`: Provider de lag para estado global
- `lib/screens/chat_screen.dart`: Barra visual de lag y correcciones en campo de texto
- `pubspec.yaml`: Versión actualizada a 1.0.5+6

## 🚀 Instalación

Descarga el instalador DMG para macOS desde los assets de este release.

### Requisitos
- macOS 10.14 o superior
- Conexión a Internet para conectarse a servidores IRC

## 📝 Notas

- La barra de lag se muestra automáticamente al conectar al servidor
- El primer valor de lag puede tardar unos segundos en aparecer
- La medición de lag es precisa y usa el protocolo estándar IRC
- El autocompletado con flechas funciona solo cuando hay sugerencias visibles

## 🙏 Agradecimientos

Gracias por usar IRC App. Si encuentras algún problema o tienes sugerencias, no dudes en reportarlo.

**Agradecimientos especiales a la comunidad GlobalChat:**
- **weed** - Por sus valiosas contribuciones y feedback
- **nocturne** - Por sus aportes y sugerencias
- **sonic** - Por su apoyo y contribuciones a esta versión

Gracias a todos por hacer de IRC App una mejor aplicación.

---

**Versión**: 1.0.5+6  
**Fecha**: Enero 2025  
**Plataforma**: macOS

