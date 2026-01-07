# 🚀 Plan de Implementación de Funcionalidades Web

Este documento describe cómo implementar las funcionalidades que actualmente están deshabilitadas para la versión web.

## ✅ Estado Actual

### Funcionalidades que YA funcionan en web:
- ✅ Conexión IRC vía WebSocket
- ✅ Chat en canales y mensajes privados
- ✅ Lista de usuarios
- ✅ Radios (usando `audioplayers` para web) - **MEJORADO**
- ✅ Interfaz completa del chat
- ✅ Temas y personalización
- ✅ Markdown en mensajes
- ✅ Preview de imágenes/videos desde URLs

### Funcionalidades deshabilitadas temporalmente:
- ❌ Envío de imágenes/videos desde archivos locales
- ❌ Actualizaciones automáticas
- ❌ Configuración de audio session (solo móvil)
- ❌ Proxy local para radios (solo macOS/iOS)

---

## 📻 Radio - IMPLEMENTACIÓN COMPLETA

### Estado: ✅ **FUNCIONAL EN WEB**

La radio ya está implementada usando `audioplayers` para web. Se ha mejorado con:

1. **Inicialización automática**: El `RadioService` se inicializa al arrancar la app
2. **Manejo de errores mejorado**: Logs detallados para debugging
3. **Configuración de player**: Modo `mediaPlayer` para mejor compatibilidad
4. **Verificación de inicialización**: Si el player no está inicializado, se crea automáticamente

### Cómo funciona:
```dart
// En web, usa audioplayers
if (PlatformUtils.isWeb) {
  _webPlayer = web_audio.AudioPlayer();
  await _webPlayer!.play(web_audio.UrlSource(station.source));
}
```

### Posibles problemas y soluciones:

#### 1. **CORS (Cross-Origin Resource Sharing)**
Si una radio no funciona, puede ser por CORS. Soluciones:
- **Opción A**: Usar un proxy CORS (como `cors-anywhere`)
- **Opción B**: Configurar el servidor de la radio para permitir CORS
- **Opción C**: Usar un servidor proxy propio

#### 2. **Autoplay bloqueado por el navegador**
Los navegadores bloquean autoplay sin interacción del usuario. Solución:
- Mostrar un botón "Activar radio" que el usuario debe presionar
- Ya implementado en la UI

---

## 📸 Envío de Imágenes/Videos desde Archivos

### Estado: ❌ **PENDIENTE**

### Implementación propuesta:

#### Opción 1: Usar `file_picker` con bytes (RECOMENDADO)
```dart
Future<void> _pickAndSendImage() async {
  if (PlatformUtils.isWeb) {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // Obtener bytes directamente
    );
    
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      
      // Subir a Cloudinary o servidor propio
      await _uploadToCloudinary(bytes, fileName);
    }
  }
}
```

#### Opción 2: Usar `image_picker` para web
```dart
import 'package:image_picker/image_picker.dart';

Future<void> _pickImage() async {
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  
  if (image != null) {
    final bytes = await image.readAsBytes();
    // Procesar bytes...
  }
}
```

#### Pasos de implementación:
1. ✅ `file_picker` ya está en `pubspec.yaml`
2. ✅ `image_picker` ya está en `pubspec.yaml`
3. ⏳ Modificar `_pickAndSendImage()` para usar bytes en web
4. ⏳ Modificar `_processAndSendImage()` para procesar bytes
5. ⏳ Subir a Cloudinary usando `http` con multipart/form-data

---

## 🔄 Actualizaciones Automáticas

### Estado: ❌ **NO NECESARIO EN WEB**

En web, las actualizaciones se hacen automáticamente cuando el usuario recarga la página. No necesitamos un sistema de actualizaciones como en aplicaciones nativas.

### Alternativa: Notificación de nueva versión
```dart
// Verificar versión en el servidor
Future<void> checkForNewVersion() async {
  final response = await http.get(
    Uri.parse('https://mobilev1.globalchat.org/version.json')
  );
  final serverVersion = jsonDecode(response.body)['version'];
  final currentVersion = '3.0.0';
  
  if (serverVersion != currentVersion) {
    // Mostrar notificación: "Nueva versión disponible. Recarga la página."
    showDialog(...);
  }
}
```

---

## 🎵 Audio Session Configuration

### Estado: ❌ **SOLO PARA MÓVIL**

Esta funcionalidad es específica de iOS/Android y no es necesaria en web. El navegador maneja el audio automáticamente.

**No requiere implementación en web.**

---

## 🔌 Proxy Local para Radios

### Estado: ❌ **SOLO PARA macOS/iOS**

El proxy local se usaba para:
- Bypass CORS en macOS/iOS
- Añadir headers personalizados

### Alternativa para web:
Si hay problemas de CORS con algunas radios, podemos:

1. **Usar un proxy CORS público** (temporal):
```dart
String proxyUrl = 'https://cors-anywhere.herokuapp.com/${station.source}';
```

2. **Crear un proxy propio en el servidor**:
```dart
// En el servidor (Node.js/Python)
app.get('/radio-proxy', async (req, res) => {
  const url = req.query.url;
  const response = await fetch(url);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.send(response.body);
});
```

3. **Configurar CORS en el servidor de la radio** (si es posible)

---

## 📋 Resumen de Tareas

### Prioridad Alta:
- [x] ✅ Radio funcionando en web (COMPLETADO)
- [ ] 📸 Envío de imágenes desde archivos (usando bytes)
- [ ] 📹 Envío de videos desde archivos (usando bytes)

### Prioridad Media:
- [ ] 🔔 Notificación de nueva versión disponible
- [ ] 🔌 Proxy CORS para radios problemáticas

### Prioridad Baja:
- [ ] 📊 Analytics de uso
- [ ] 💾 Cache offline (Service Worker)

---

## 🛠️ Cómo Implementar Cada Funcionalidad

### 1. Envío de Imágenes (Prioridad Alta)

**Archivo**: `lib/screens/chat_screen.dart`

**Cambios necesarios**:
```dart
Future<void> _pickAndSendImage() async {
  if (PlatformUtils.isWeb) {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      final mimeType = _getMimeType(fileName);
      
      // Subir directamente a Cloudinary
      await _uploadAndSendToCloudinary(bytes, mimeType, channel);
    }
  } else {
    // Código existente para nativo
  }
}
```

### 2. Envío de Videos (Prioridad Alta)

Similar a imágenes, pero con validación de tamaño:
```dart
Future<void> _pickAndSendVideo() async {
  if (PlatformUtils.isWeb) {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    
    if (result != null) {
      final file = result.files.single;
      if (file.bytes != null && file.size < 100 * 1024 * 1024) { // 100MB max
        await _uploadAndSendVideoToCloudinary(
          file.bytes!,
          _getMimeType(file.name),
          channel
        );
      }
    }
  }
}
```

---

## 🧪 Testing

Para probar cada funcionalidad:

1. **Radio**: 
   - Abrir la app web
   - Ir a un canal con radio automática
   - Verificar que la radio se reproduce

2. **Imágenes**:
   - Hacer clic en el botón de adjuntar imagen
   - Seleccionar una imagen
   - Verificar que se sube y se envía

3. **Videos**:
   - Similar a imágenes

---

## 📚 Referencias

- [audioplayers package](https://pub.dev/packages/audioplayers)
- [file_picker package](https://pub.dev/packages/file_picker)
- [Cloudinary API](https://cloudinary.com/documentation)
- [CORS en navegadores](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS)


