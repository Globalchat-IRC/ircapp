# Integración de Mixcloud Live con UrbanFlow Radio

## 📋 Resumen

La aplicación IRC App ahora detecta automáticamente cuando la radio UrbanFlow (djsonic_vlc) está emitiendo en directo en Mixcloud y cambia automáticamente al stream en vivo.

## 🏗️ Arquitectura

### Componentes

1. **Backend Extractor** (`/api/mixcloud_stream_extractor.php`)
   - Detecta si hay emisión en directo en Mixcloud
   - Extrae la URL del stream HLS (.m3u8)
   - Devuelve JSON con información del stream

2. **Proxy CORS** (`/api/mixcloud_stream_proxy.php`)
   - Soluciona problemas de CORS del navegador
   - Descarga el stream de Mixcloud y lo sirve con headers correctos
   - Valida que las URLs sean de Mixcloud (seguridad)

3. **Servicio Frontend** (`lib/services/mixcloud_live_service.dart`)
   - Consulta el backend cada 2 minutos
   - Cachea resultados para optimizar
   - Convierte URLs de Mixcloud a URLs del proxy

4. **Provider de Radio** (`lib/providers/radio_provider.dart`)
   - Actualiza automáticamente la URL de UrbanFlow
   - Verifica stream en vivo antes de reproducir
   - Muestra indicador visual cuando está en vivo

## 🔄 Flujo de Funcionamiento

```
Usuario selecciona UrbanFlow
         ↓
RadioProvider verifica si hay stream en vivo
         ↓
MixcloudLiveService consulta backend
         ↓
Backend extrae URL del stream HLS de Mixcloud
         ↓
MixcloudLiveService convierte URL a proxy
         ↓
RadioService reproduce desde el proxy
         ↓
Proxy descarga de Mixcloud y sirve con CORS
         ↓
¡Usuario escucha el stream en vivo! 🎵
```

## 🚀 Despliegue

### Backend (mobilev1.globalchat.org)

```bash
# Archivos en el servidor:
/var/www/mobilev1.globalchat.org/api/
├── mixcloud_stream_extractor.php
├── mixcloud_stream_extractor.sh
└── mixcloud_stream_proxy.php
```

### Frontend (mobilev1.globalchat.org)

```bash
# Compilar y desplegar
cd /Users/fnaveira/mobile/irc_app
flutter build web --release
./deploy_simple.sh
```

## 🧪 Pruebas

### Verificar Backend

```bash
# Verificar extractor
curl "https://mobilev1.globalchat.org/api/mixcloud_stream_extractor.php?username=djsonic_vlc" | jq

# Verificar proxy
curl -I "https://mobilev1.globalchat.org/api/mixcloud_stream_proxy.php"
```

### Verificar Integración Completa

```bash
cd /Users/fnaveira/mobile/irc_app
./tool/test_proxy_integration.sh
```

### Probar en la Aplicación

1. Abrir https://mobilev1.globalchat.org
2. Ir a la sección de Radio
3. Seleccionar "UrbanFlow"
4. Si hay emisión en vivo, verás el indicador "🔴 EN VIVO"
5. El stream debería reproducirse automáticamente

## 🔧 Solución de Problemas

### El stream no se detecta

1. Verificar que djsonic_vlc esté realmente en vivo:
   ```bash
   curl -s "https://www.mixcloud.com/live/djsonic_vlc/" | grep -o 'https://live-[^"]*\.m3u8'
   ```

2. Verificar el backend:
   ```bash
   ssh root@mobilev1.globalchat.org
   bash /var/www/mobilev1.globalchat.org/api/mixcloud_stream_extractor.sh djsonic_vlc
   ```

### Error de CORS

- El proxy debería resolver todos los problemas de CORS
- Verificar que los headers estén correctos:
  ```bash
  curl -I "https://mobilev1.globalchat.org/api/mixcloud_stream_proxy.php" | grep Access-Control
  ```

### El stream no se reproduce

1. Abrir la consola del navegador (F12)
2. Buscar errores relacionados con:
   - CORS
   - MEDIA_ELEMENT_ERROR
   - Network errors
3. Verificar que la URL del proxy sea correcta en los logs:
   ```
   🎵 [RadioProvider] Usuario seleccionó UrbanFlow, verificando stream en vivo...
   ✅ [MixcloudLive] Stream en vivo encontrado (via proxy): https://...
   ```

## 📝 Logs Útiles

La aplicación genera logs detallados en la consola del navegador:

- `🎵 [RadioProvider]` - Estado del provider de radio
- `🎵 [MixcloudLive]` - Detección de streams en vivo
- `📻 [RadioService]` - Reproducción de audio
- `🎵 [RadioControls]` - Controles de la interfaz

## 🔐 Seguridad

El proxy incluye validación de seguridad:

- Solo permite URLs de dominios `*.mixcloud.com`
- Valida que las URLs sean válidas antes de procesarlas
- Previene ataques SSRF (Server-Side Request Forgery)

## 📊 Rendimiento

- Cache de 2 minutos para reducir consultas al backend
- Timeout de 10 segundos en las peticiones
- Verificación automática cada 2 minutos cuando UrbanFlow está activo

## 🎯 Próximas Mejoras

- [ ] Notificaciones push cuando UrbanFlow entre en vivo
- [ ] Historial de emisiones en vivo
- [ ] Soporte para otros DJs de Mixcloud
- [ ] Estadísticas de reproducción

## 📞 Contacto

Para reportar problemas o sugerencias, contactar al equipo de desarrollo de GlobalChat.

---

**Última actualización:** 31 de enero de 2026
**Versión:** 3.0.90
