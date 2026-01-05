# 📱 Plan de Migración a Web - IRC App

## ✅ Viabilidad: **SÍ, ES POSIBLE** con modificaciones

Flutter Web soporta la aplicación, pero requiere adaptar código específico de plataforma.

---

## 🔴 Dependencias Problemáticas para Web

### 1. **Conexiones TCP (Socket)**
- **Problema**: `dart:io` Socket/SecureSocket no funciona en web
- **Solución**: Usar WebSocket (`web_socket_channel`) para conexiones IRC
- **Impacto**: ALTO - Requiere reescribir `IRCService`

### 2. **Audio/Radio**
- **Problema**: `just_audio` y `audio_session` tienen limitaciones en web
- **Solución**: Usar `audioplayers` (mejor soporte web) o HTML5 Audio API
- **Impacto**: MEDIO - Requiere cambios en `RadioService`

### 3. **Base de Datos**
- **Problema**: `sqflite` no funciona en web
- **Solución**: Usar `shared_preferences` (localStorage) o `hive` (IndexedDB)
- **Impacto**: MEDIO - Cambios en `VideoDatabaseService` y `ChatHistoryService`

### 4. **Sistema de Archivos**
- **Problema**: `path_provider` y `File`/`Directory` limitados en web
- **Solución**: Usar `shared_preferences` para datos pequeños, IndexedDB para grandes
- **Impacto**: MEDIO - Cambios en `CacheService` y `BackupService`

### 5. **Videoconferencias**
- **Problema**: `jitsi_meet_flutter_sdk` puede tener problemas en web
- **Solución**: Usar Jitsi Meet Web SDK directamente o iframe
- **Impacto**: MEDIO - Cambios en `VideoConferenceService`

### 6. **Permisos**
- **Problema**: `permission_handler` limitado en web
- **Solución**: Usar APIs nativas del navegador (getUserMedia, etc.)
- **Impacto**: BAJO - Solo afecta videoconferencias

### 7. **Funcionalidades macOS**
- **Problema**: Menús nativos, notificaciones macOS no aplican
- **Solución**: Ocultar/deshabilitar en web o usar alternativas web
- **Impacto**: BAJO - Solo afecta UI específica de macOS

---

## ✅ Dependencias Compatibles con Web

- ✅ `flutter_riverpod` - Funciona perfectamente
- ✅ `http` - Funciona perfectamente
- ✅ `shared_preferences` - Funciona (usa localStorage)
- ✅ `url_launcher` - Funciona perfectamente
- ✅ `crypto` - Funciona perfectamente
- ✅ `file_picker` - Funciona en web
- ✅ `image_picker` - Funciona (con limitaciones)
- ✅ `flutter_markdown` - Funciona perfectamente
- ✅ `cached_network_image` - Funciona perfectamente
- ✅ `photo_view` - Funciona perfectamente
- ✅ `video_player` - Funciona perfectamente
- ✅ `shelf` - Funciona (solo como cliente, no servidor)
- ✅ `uuid` - Funciona perfectamente
- ✅ `equatable` - Funciona perfectamente

---

## 🛠️ Cambios Necesarios

### 1. **IRCService - Conexión WebSocket**

```dart
// Antes (dart:io)
import 'dart:io';
Socket? _socket;

// Después (web_socket_channel)
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

WebSocketChannel? _channel;

// Adaptar métodos de conexión
Future<void> connect(String host, int port) async {
  if (kIsWeb) {
    // WebSocket para web
    final uri = Uri.parse('ws://$host:$port');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(_onWebSocketMessage);
  } else {
    // Socket TCP para móvil/desktop
    _socket = await Socket.connect(host, port);
    _socket!.listen(_onSocketMessage);
  }
}
```

### 2. **RadioService - Audio Web**

```dart
// Opción 1: audioplayers (mejor soporte web)
import 'package:audioplayers/audioplayers.dart';

// Opción 2: HTML5 Audio directo
import 'dart:html' as html;

class RadioService {
  html.AudioElement? _audioElement;
  
  Future<void> playStation(RadioStation station) async {
    if (kIsWeb) {
      _audioElement = html.AudioElement(station.source);
      _audioElement!.play();
    } else {
      // Código existente para móvil/desktop
    }
  }
}
```

### 3. **Base de Datos - IndexedDB/SharedPreferences**

```dart
// Reemplazar sqflite con hive o shared_preferences
import 'package:hive/hive.dart';
// o
import 'package:shared_preferences/shared_preferences.dart';

// Para datos complejos, usar Hive (IndexedDB en web)
// Para datos simples, usar SharedPreferences (localStorage)
```

### 4. **Sistema de Archivos**

```dart
// Reemplazar File/Directory con almacenamiento web
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:html' as html; // Para descargas

// Cache: usar IndexedDB o localStorage
// Backup: usar descarga de archivos (html.AnchorElement)
```

### 5. **Proxy de Stream (Solo Desktop)**

```dart
// El proxy HTTP local no funciona en web
// Solución: Usar CORS proxy externo o deshabilitar en web
if (!kIsWeb) {
  // Código del proxy
}
```

---

## 📋 Plan de Implementación

### Fase 1: Preparación (1-2 días)
1. ✅ Crear archivo de configuración web (`web/index.html`)
2. ✅ Agregar condicionales `kIsWeb` en código crítico
3. ✅ Crear abstracciones para conexiones (Socket vs WebSocket)

### Fase 2: Conexión IRC (2-3 días)
1. ✅ Implementar WebSocket para IRC en web
2. ✅ Adaptar `IRCService` para soportar ambos
3. ✅ Probar conexión y mensajería básica

### Fase 3: Audio/Radio (1-2 días)
1. ✅ Reemplazar `just_audio` con `audioplayers`
2. ✅ Adaptar `RadioService` para web
3. ✅ Probar reproducción de radio

### Fase 4: Almacenamiento (1-2 días)
1. ✅ Reemplazar `sqflite` con `hive` o `shared_preferences`
2. ✅ Adaptar servicios de base de datos
3. ✅ Migrar datos existentes

### Fase 5: UI/UX Web (1 día)
1. ✅ Ocultar funcionalidades macOS específicas
2. ✅ Adaptar layout para navegadores
3. ✅ Optimizar para diferentes tamaños de pantalla

### Fase 6: Testing (1-2 días)
1. ✅ Probar en Chrome, Firefox, Safari, Edge
2. ✅ Verificar funcionalidades principales
3. ✅ Optimizar rendimiento

**Tiempo total estimado: 7-12 días**

---

## 🚀 Comandos para Compilar Web

```bash
# Habilitar web (si no está habilitado)
flutter config --enable-web

# Compilar para web
flutter build web

# Ejecutar en modo desarrollo
flutter run -d chrome

# El build estará en: build/web/
```

---

## ⚠️ Limitaciones en Web

1. **Conexiones IRC**: 
   - WebSocket requiere servidor IRC con soporte WebSocket
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

5. **Funcionalidades nativas**:
   - Notificaciones del sistema limitadas
   - Acceso a archivos limitado
   - Sin acceso directo al sistema

---

## 💡 Alternativas

### Opción 1: WebSocket Proxy
Usar un servidor proxy que convierta WebSocket → TCP IRC

### Opción 2: WebRTC
Para videoconferencias, usar WebRTC directamente en lugar de Jitsi SDK

### Opción 3: PWA (Progressive Web App)
Convertir en PWA para mejor experiencia móvil

---

## ✅ Conclusión

**SÍ, es totalmente posible portar la aplicación a web**, pero requiere:

1. ✅ Reescribir conexiones IRC (WebSocket)
2. ✅ Adaptar audio/radio
3. ✅ Cambiar sistema de almacenamiento
4. ✅ Ocultar funcionalidades específicas de plataforma
5. ✅ Testing exhaustivo en navegadores

**Esfuerzo estimado: 1-2 semanas de desarrollo**

¿Quieres que comience con la implementación?

