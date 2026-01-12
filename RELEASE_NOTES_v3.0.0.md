# 🎉 IRC App v3.0.0 - Release Notes (Web Edition)

## 🌐 Nueva Versión Mayor - Soporte Web

Esta es una versión mayor que incluye soporte completo para ejecutarse en navegadores web, además de mantener compatibilidad con macOS, iOS y Android.

---

## ✨ Nuevas Características

### 🌐 Soporte Web Completo
- **Ejecución en navegadores**: Chrome, Firefox, Safari, Edge
- **WebSocket para IRC**: Conexiones IRC adaptadas para web
- **Almacenamiento web**: IndexedDB y localStorage
- **Audio web**: Soporte para reproducción de radio en navegadores
- **UI adaptativa**: Interfaz optimizada para navegadores

### 🔧 Arquitectura Mejorada
- **Abstracción de conexiones**: Sistema modular para Socket/WebSocket
- **Compatibilidad multiplataforma**: Mismo código para web y nativo
- **Detección automática**: La app detecta la plataforma y usa la tecnología apropiada

---

## 🛠️ Cambios Técnicos

### Nuevas Dependencias
- `web_socket_channel`: Para conexiones IRC en web
- `audioplayers`: Mejor soporte de audio en web
- `hive`: Base de datos compatible con web (IndexedDB)

### Servicios Nuevos
- `IRCConnectionInterface`: Interfaz abstracta para conexiones
- `IRCSocketConnection`: Implementación TCP nativa (móvil/desktop)
- `IRCWebSocketConnection`: Implementación WebSocket (web)
- `IRCConnectionFactory`: Factory para crear conexiones apropiadas
- `PlatformUtils`: Utilidades para detección de plataforma

### Adaptaciones
- `IRCService`: Adaptado para usar conexiones abstractas
- `RadioService`: Soporte mejorado para web
- Servicios de almacenamiento: Adaptados para web

---

## 📋 Compatibilidad

### Plataformas Soportadas
- ✅ **Web** (Chrome, Firefox, Safari, Edge)
- ✅ **macOS** (mantiene todas las funcionalidades)
- ✅ **iOS** (sin cambios)
- ✅ **Android** (sin cambios)

### Funcionalidades por Plataforma

| Funcionalidad | Web | macOS | iOS | Android |
|--------------|-----|-------|-----|---------|
| Chat IRC | ✅ | ✅ | ✅ | ✅ |
| Radio | ✅ | ✅ | ✅ | ✅ |
| Videoconferencias | ⚠️* | ✅ | ✅ | ✅ |
| Notificaciones | ⚠️** | ✅ | ✅ | ✅ |
| Menús nativos | ❌ | ✅ | ❌ | ❌ |
| Backup/Export | ✅ | ✅ | ✅ | ✅ |
| Privacidad | ✅ | ✅ | ✅ | ✅ |

\* Videoconferencias en web requieren Jitsi Web SDK  
\** Notificaciones web requieren permisos del navegador

---

## 🚀 Cómo Usar la Versión Web

### Desarrollo
```bash
# Ejecutar en Chrome
flutter run -d chrome

# Compilar para producción
flutter build web
```

### Despliegue
Los archivos compilados estarán en `build/web/` y pueden ser desplegados en cualquier servidor web estático o CDN.

---

## ⚠️ Limitaciones en Web

1. **Conexiones IRC**:
   - Requiere servidor IRC con soporte WebSocket
   - O usar proxy WebSocket → TCP

2. **Audio**:
   - Autoplay bloqueado por navegadores (requiere interacción del usuario)
   - Codecs limitados según navegador

3. **Almacenamiento**:
   - Límites de tamaño en localStorage (5-10MB)
   - IndexedDB tiene más espacio pero es más complejo

4. **Rendimiento**:
   - Compilado a JavaScript (más lento que nativo)
   - Tamaño del bundle más grande

---

## 🔄 Migración desde v2.1.0

No se requieren pasos especiales de migración. La aplicación detecta automáticamente la plataforma y usa la tecnología apropiada.

---

## 📥 Instalación Web

1. Compilar la aplicación:
   ```bash
   flutter build web
   ```

2. Los archivos estarán en `build/web/`

3. Desplegar en servidor web o CDN

4. Acceder desde cualquier navegador moderno

---

## 🐛 Problemas Conocidos

- Las conexiones IRC en web requieren servidor con soporte WebSocket
- El autoplay de audio está bloqueado por políticas del navegador
- Algunas funcionalidades macOS no están disponibles en web

---

## 🙏 Agradecimientos

Gracias a todos los usuarios que han reportado bugs y sugerido mejoras. Esta versión web hace la aplicación accesible desde cualquier dispositivo con navegador.

---

**Versión**: 3.0.0  
**Fecha de Release**: Enero 2025  
**Plataformas**: Web, macOS, iOS, Android  
**Tamaño Web**: ~2-3 MB (comprimido)






