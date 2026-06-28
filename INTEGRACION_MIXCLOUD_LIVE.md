# Integración Automática de Mixcloud Live en UrbanFlow

## 📋 Descripción

Sistema **100% automático** que permite que la radio **UrbanFlow** en la aplicación GlobalChat reproduzca el stream en vivo de Mixcloud cuando **djsonic_vlc** esté emitiendo en directo.

**No requiere configuración manual ni intervención del usuario.** Todo funciona automáticamente en segundo plano.

## 🏗️ Arquitectura

### Diagrama de flujo automático

```
┌─────────────────────────────────────────────────────────────┐
│                    USUARIO ABRE LA APP                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  RadioProvider: Verificar stream cada 2 minutos (Timer)     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  MixcloudLiveService: Consultar backend PHP                 │
│  GET /gateway/mixcloud_stream_extractor.php                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Backend PHP: Extraer URL del stream HLS de Mixcloud        │
│  Analiza HTML → Encuentra .m3u8 → Devuelve URL              │
└────────────────────────┬────────────────────────────────────┘
                         │
                ┌────────┴────────┐
                │                 │
                ▼                 ▼
    ┌──────────────────┐  ┌──────────────────┐
    │  HAY STREAM      │  │  NO HAY STREAM   │
    │  EN VIVO         │  │  EN VIVO         │
    └────────┬─────────┘  └────────┬─────────┘
             │                     │
             ▼                     ▼
┌──────────────────────┐  ┌──────────────────────┐
│ RadioProvider:       │  │ RadioProvider:       │
│ - Actualiza URL      │  │ - Restaura URL       │
│ - Muestra 🔴 EN VIVO │  │   por defecto        │
│ - Bitrate del stream │  │ - Quita 🔴 EN VIVO   │
└──────────┬───────────┘  └──────────┬───────────┘
           │                         │
           └────────┬────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│         USUARIO PRESIONA PLAY EN URBANFLOW                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  RadioService: Reproduce la URL (ya actualizada)            │
│  - Si hay stream en vivo: reproduce HLS                     │
│  - Si no hay stream: reproduce URL por defecto              │
└─────────────────────────────────────────────────────────────┘
```

### Componentes

1. **Backend PHP** (`gateway/mixcloud_stream_extractor.php`)
   - Extrae la URL del stream HLS (.m3u8) de Mixcloud Live
   - Proporciona información sobre el estado del stream
   - Cachea las peticiones para optimizar rendimiento

2. **Servicio Dart** (`lib/services/mixcloud_live_service.dart`)
   - Cliente para consultar el backend PHP
   - Cachea los streams obtenidos (válidos por 5 minutos)
   - Proporciona métodos simples para verificar si hay stream en vivo

3. **RadioService** (`lib/services/radio_service.dart`)
   - Reproduce la URL que le proporciona el RadioProvider
   - Soporta streams HLS directamente (sin proxy)
   - Compatible con web y plataformas nativas

4. **RadioProvider** (`lib/providers/radio_provider.dart`)
   - **Componente principal**: Gestiona todo automáticamente
   - Verifica cada 2 minutos si hay stream en vivo
   - Actualiza automáticamente la URL de UrbanFlow con el stream en vivo
   - Muestra/oculta el indicador "🔴 EN VIVO" automáticamente
   - Restaura la URL por defecto cuando termina la emisión

## 🚀 Funcionamiento Automático

### Flujo completamente automático (sin intervención del usuario)

1. **Al iniciar la app** (después de 5 segundos):
   - El sistema verifica automáticamente si djsonic_vlc está en vivo
   - Si está en vivo, extrae la URL del stream HLS
   - Actualiza la URL de UrbanFlow con el stream en vivo
   - Muestra el indicador "🔴 EN VIVO" en la UI

2. **Cada 2 minutos** (en segundo plano):
   - Verifica automáticamente si hay stream en vivo
   - Si detecta que empezó una emisión: actualiza la URL automáticamente
   - Si detecta que terminó la emisión: restaura la URL por defecto
   - Todo sin que el usuario tenga que hacer nada

3. **Al reproducir UrbanFlow**:
   - El usuario simplemente presiona "Play"
   - La app reproduce automáticamente la URL correcta (stream en vivo o por defecto)
   - No hay configuración ni pasos adicionales

### Ejemplo práctico

**Escenario 1: djsonic_vlc empieza a emitir**
```
1. Usuario abre la app → Sistema detecta stream en vivo
2. UrbanFlow muestra "🔴 EN VIVO" automáticamente
3. Usuario presiona Play → Escucha el stream en vivo
```

**Escenario 2: djsonic_vlc termina la emisión**
```
1. Sistema detecta que terminó la emisión (cada 2 min)
2. Quita el indicador "🔴 EN VIVO" automáticamente
3. Restaura la URL por defecto de Mixcloud
4. Todo sin intervención del usuario
```

**Escenario 3: Usuario ya está escuchando**
```
1. Usuario está escuchando UrbanFlow
2. djsonic_vlc empieza a emitir en vivo
3. En máximo 2 minutos, el sistema detecta el stream
4. La próxima vez que reproduzca, usará el stream en vivo
```

## 📡 API Backend

### Endpoint

```
GET https://webchat.globalchat.org/gateway/mixcloud_stream_extractor.php?username=djsonic_vlc
```

### Respuesta cuando hay stream en vivo

```json
{
  "success": true,
  "stream_url": "https://live-lon2-ovh.mixcloud.com/hls/.../master.m3u8",
  "username": "djsonic_vlc",
  "is_live": true,
  "timestamp": 1738281600,
  "info": {
    "format": "HLS",
    "type": "m3u8",
    "bitrate": "128 kbps",
    "qualities": 3
  }
}
```

### Respuesta cuando NO hay stream en vivo

```json
{
  "success": false,
  "is_live": false,
  "username": "djsonic_vlc",
  "message": "No hay emisión en directo actualmente",
  "timestamp": 1738281600
}
```

## ✨ Ventajas del Sistema Automático

### Para el usuario
- ✅ **Cero configuración**: Solo presiona Play y funciona
- ✅ **Detección automática**: Siempre reproduce el stream correcto
- ✅ **Indicador visual**: Sabe cuándo hay emisión en vivo sin buscar
- ✅ **Experiencia fluida**: No hay pasos manuales ni configuraciones

### Para el DJ (djsonic_vlc)
- ✅ **Sin configuración**: Solo emite en Mixcloud como siempre
- ✅ **Automático**: La app detecta y usa el stream automáticamente
- ✅ **Sin mantenimiento**: No necesita actualizar URLs ni configurar nada
- ✅ **Alcance inmediato**: Todos los usuarios ven "🔴 EN VIVO" automáticamente

### Para el desarrollador
- ✅ **Mantenimiento cero**: Una vez desplegado, funciona solo
- ✅ **Escalable**: Fácil agregar más DJs o plataformas
- ✅ **Robusto**: Cache y fallback automático a URL por defecto
- ✅ **Monitoreable**: Logs claros en cada paso del proceso

## 🔧 Despliegue

### 1. Desplegar el backend PHP

```bash
cd /Users/fnaveira/mobile/irc_app
./deploy_mixcloud_extractor.sh
```

Este script:
- Copia el archivo PHP al servidor
- Establece los permisos correctos
- Prueba el endpoint

### 2. Compilar y desplegar la app

```bash
# Para web
flutter build web --release
./deploy_to_ceres.sh

# Para otras plataformas
flutter build [platform]
```

## 🧪 Pruebas

### Probar el backend manualmente

```bash
# Con curl
curl "https://webchat.globalchat.org/gateway/mixcloud_stream_extractor.php?username=djsonic_vlc"

# Con el script de extracción
cd tool
./extract_mixcloud_stream.sh https://www.mixcloud.com/live/djsonic_vlc/
```

### Probar en la app

1. Abrir la app GlobalChat
2. Ir a la sección de Radio
3. Seleccionar "UrbanFlow"
4. Si hay stream en vivo, verás "🔴 EN VIVO" en la descripción
5. Reproducir y verificar que se escucha el stream

## 📝 Logs

### Backend PHP

Los logs se pueden ver en el servidor:

```bash
ssh root@webchat.globalchat.org
tail -f /var/log/apache2/error.log | grep mixcloud
```

### App Flutter

Los logs se muestran en la consola:

```
🎵 [RadioService] Verificando stream en vivo de Mixcloud...
✅ [RadioService] Stream en vivo encontrado, usando: https://...
🔴 [RadioProvider] UrbanFlow está EN VIVO
```

## 🔒 Seguridad

- El backend PHP valida las URLs antes de devolverlas
- Se usa HTTPS para todas las comunicaciones
- Las URLs de stream expiran automáticamente (Mixcloud las rota)
- El cache evita sobrecarga del servidor de Mixcloud

## ⚙️ Configuración

### Cambiar el usuario de Mixcloud

En `lib/services/mixcloud_live_service.dart`:

```dart
Future<MixcloudLiveStream?> getUrbanFlowLiveStream() async {
  return await getLiveStream('otro_usuario'); // Cambiar aquí
}
```

### Cambiar la frecuencia de verificación

En `lib/providers/radio_provider.dart`:

```dart
void _startLiveStreamCheck() {
  _liveStreamCheckTimer = Timer.periodic(
    const Duration(minutes: 5), // Cambiar aquí (actualmente 2 minutos)
    (_) => _checkLiveStreams(),
  );
}
```

### Cambiar el tiempo de cache

En `lib/services/mixcloud_live_service.dart`:

```dart
bool get isExpired {
  final now = DateTime.now();
  final diff = now.difference(timestamp);
  return diff.inMinutes > 10; // Cambiar aquí (actualmente 5 minutos)
}
```

## 🐛 Troubleshooting

### El stream no se detecta

1. Verificar que el backend está funcionando:
   ```bash
   curl "https://webchat.globalchat.org/gateway/mixcloud_stream_extractor.php?username=djsonic_vlc"
   ```

2. Verificar los logs de la app (buscar errores de MixcloudLive)

3. Verificar que djsonic_vlc está realmente en vivo en Mixcloud

### El stream no se reproduce

1. Verificar que la URL del stream es válida (copiarla y probar en VLC)
2. Verificar problemas de CORS en web
3. Verificar los logs del reproductor de audio

### El indicador "EN VIVO" no aparece

1. Verificar que el timer de verificación está funcionando
2. Esperar hasta 2 minutos para la próxima verificación
3. Forzar una actualización reproduciendo la estación

## 📚 Referencias

- [Mixcloud Live](https://www.mixcloud.com/live/)
- [HLS Streaming](https://developer.apple.com/streaming/)
- [audioplayers package](https://pub.dev/packages/audioplayers)
- [just_audio package](https://pub.dev/packages/just_audio)

## 🎯 Mejoras Futuras

- [ ] Notificación push cuando UrbanFlow empiece a emitir
- [ ] Historial de emisiones en vivo
- [ ] Grabación automática de emisiones
- [ ] Integración con otros servicios de streaming (YouTube Live, Twitch, etc.)
- [ ] Panel de control para DJ (iniciar/detener stream desde la app)
