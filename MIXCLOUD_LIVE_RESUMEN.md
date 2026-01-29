# 🎵 Mixcloud Live - Integración Automática

## ¿Qué hace?

La radio **UrbanFlow** en la app GlobalChat ahora **detecta y reproduce automáticamente** el stream en vivo cuando **djsonic_vlc** está emitiendo en Mixcloud.

## ✨ Características

- ✅ **100% Automático** - Sin configuración manual
- ✅ **Detección en tiempo real** - Verifica cada 2 minutos
- ✅ **Indicador visual** - Muestra "🔴 EN VIVO" cuando hay emisión
- ✅ **Fallback inteligente** - Usa URL por defecto si no hay stream
- ✅ **Compatible** - Funciona en web, iOS, Android, macOS, Windows, Linux

## 🚀 ¿Cómo funciona?

### Para el usuario (sin hacer nada)

1. Abre la app GlobalChat
2. Ve a la sección de Radio
3. Si djsonic_vlc está en vivo, verá: **"UrbanFlow 🔴 EN VIVO"**
4. Presiona Play y escucha el stream en vivo
5. Si no está en vivo, reproduce la URL por defecto de Mixcloud

### Para el DJ (sin hacer nada)

1. djsonic_vlc emite en Mixcloud como siempre
2. La app detecta automáticamente la emisión (máx 2 min)
3. Todos los usuarios ven "🔴 EN VIVO" automáticamente
4. Cuando termina la emisión, la app lo detecta y quita el indicador

### Técnicamente (en segundo plano)

```
App → Verifica cada 2 min → Backend PHP → Extrae stream de Mixcloud
                                ↓
                         Actualiza URL automáticamente
                                ↓
                         Usuario presiona Play
                                ↓
                         Reproduce stream en vivo
```

## 📦 Archivos creados

### Backend
- `gateway/mixcloud_stream_extractor.php` - Extrae URL del stream HLS

### Frontend (Dart/Flutter)
- `lib/services/mixcloud_live_service.dart` - Cliente para consultar backend
- Modificaciones en `lib/services/radio_service.dart` - Soporte HLS
- Modificaciones en `lib/providers/radio_provider.dart` - Detección automática

### Scripts
- `tool/extract_mixcloud_stream.sh` - Script manual para extraer streams
- `tool/test_mixcloud_integration.sh` - Test de integración completo
- `deploy_mixcloud_extractor.sh` - Desplegar backend al servidor

### Documentación
- `INTEGRACION_MIXCLOUD_LIVE.md` - Documentación técnica completa
- `MIXCLOUD_LIVE_RESUMEN.md` - Este archivo (resumen ejecutivo)

## 🔧 Despliegue

### 1. Desplegar backend PHP

```bash
cd /Users/fnaveira/mobile/irc_app
./deploy_mixcloud_extractor.sh
```

### 2. Probar que funciona

```bash
cd tool
./test_mixcloud_integration.sh
```

### 3. Compilar y desplegar la app

```bash
# Web
flutter build web --release
./deploy_to_ceres.sh

# Otras plataformas
flutter build [platform]
```

## ✅ Verificación

### Probar manualmente el backend

```bash
curl "https://webchat.globalchat.org/gateway/mixcloud_stream_extractor.php?username=djsonic_vlc"
```

**Respuesta si hay stream en vivo:**
```json
{
  "success": true,
  "is_live": true,
  "stream_url": "https://live-lon2-ovh.mixcloud.com/hls/.../master.m3u8"
}
```

**Respuesta si NO hay stream:**
```json
{
  "success": false,
  "is_live": false,
  "message": "No hay emisión en directo actualmente"
}
```

## 📊 Logs

### En la app (consola)

```
🔴 [RadioProvider] UrbanFlow está EN VIVO
🎵 [RadioProvider] URL del stream: https://live-lon2-ovh.mixcloud.com/...
🎵 [RadioService] Reproduciendo: UrbanFlow
```

### En el servidor

```bash
ssh root@webchat.globalchat.org
tail -f /var/log/apache2/access.log | grep mixcloud_stream_extractor
```

## 🎯 Estado Actual

- ✅ Backend PHP creado y listo para desplegar
- ✅ Servicio Dart implementado con cache
- ✅ RadioService actualizado para HLS
- ✅ RadioProvider con detección automática cada 2 min
- ✅ Scripts de despliegue y testing creados
- ✅ Documentación completa

## 📝 Próximos Pasos

1. **Desplegar backend**: `./deploy_mixcloud_extractor.sh`
2. **Probar**: `./tool/test_mixcloud_integration.sh`
3. **Compilar app**: `flutter build web --release`
4. **Desplegar app**: `./deploy_to_ceres.sh`
5. **Verificar en producción**: Abrir app y verificar UrbanFlow

## 🎉 Resultado Final

**El usuario simplemente abre la app, ve "UrbanFlow 🔴 EN VIVO", presiona Play y escucha el stream. Todo automático, sin configuración.**
