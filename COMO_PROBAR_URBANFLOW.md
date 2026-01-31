# 🧪 Cómo Probar la Radio UrbanFlow con Mixcloud Live

## ✅ Estado Actual del Sistema

- **Backend**: `https://ceres.globalchat.org/api/mixcloud_stream_extractor.php`
- **Frontend**: `https://ceres.globalchat.org/static/`
- **Estado**: ✅ **FUNCIONANDO** - djsonic_vlc está EN VIVO 🔴

---

## 📋 Métodos de Prueba

### 1️⃣ Script de Prueba Automático (Recomendado)

```bash
cd /Users/fnaveira/mobile/irc_app
bash tool/test_mixcloud_integration.sh
```

**Este script verifica**:
- ✅ Que el backend responda correctamente
- ✅ Que detecte si hay stream en vivo
- ✅ Que el stream HLS sea accesible
- ✅ Muestra la URL del stream para reproducir con VLC

---

### 2️⃣ Probar en la Aplicación Web

1. **Abre la aplicación**:
   ```
   https://ceres.globalchat.org/static/
   ```

2. **Ve a la sección de Radio** 📻

3. **Busca "UrbanFlow"** en la lista de radios

4. **Observa el indicador**:
   - Si hay stream en vivo: **"🔴 EN VIVO"**
   - Si no hay stream: Muestra la URL normal de Mixcloud

5. **Dale click para reproducir**

6. **Abre la consola del navegador** (F12) para ver logs:
   ```
   🎵 [MixcloudLive] Obteniendo stream en vivo para djsonic_vlc...
   ✅ [MixcloudLive] Stream en vivo encontrado: https://...m3u8
   ```

---

### 3️⃣ Verificar el Backend Manualmente

```bash
# Ver si hay stream en vivo
curl -s "https://ceres.globalchat.org/api/mixcloud_stream_extractor.php?username=djsonic_vlc" | jq '.'

# Ver solo el estado
curl -s "https://ceres.globalchat.org/api/mixcloud_stream_extractor.php?username=djsonic_vlc" | jq '.is_live, .stream_url'
```

**Respuesta esperada cuando HAY stream**:
```json
{
  "success": true,
  "stream_url": "https://live-fsn1-hez.mixcloud.com/hls/.../master.m3u8",
  "username": "djsonic_vlc",
  "is_live": true,
  "timestamp": 1769820377,
  "format": "HLS",
  "type": "m3u8"
}
```

**Respuesta esperada cuando NO HAY stream**:
```json
{
  "success": false,
  "is_live": false,
  "username": "djsonic_vlc",
  "message": "No hay emisión en directo actualmente o no se pudo extraer la URL.",
  "timestamp": 1769820377
}
```

---

### 4️⃣ Reproducir el Stream con VLC

```bash
# Obtener la URL del stream
STREAM_URL=$(curl -s "https://ceres.globalchat.org/api/mixcloud_stream_extractor.php?username=djsonic_vlc" | jq -r '.stream_url')

# Reproducir con VLC
vlc "$STREAM_URL"
```

O directamente:
```bash
vlc "https://live-fsn1-hez.mixcloud.com/hls/10E247A6D167/1769989087/FMhqpxmPzfylLk_zbVAVkA/57060abf-279f-4ff1-a921-19a872b5d8f3/master.m3u8"
```

---

### 5️⃣ Probar con el Script de Extracción Local

```bash
cd /Users/fnaveira/mobile/irc_app
bash tool/extract_mixcloud_stream.sh
```

Este script extrae el stream directamente desde tu Mac (sin usar el backend).

---

## 🔄 Funcionamiento Automático

La aplicación verifica automáticamente cada **2 minutos** si hay un stream en vivo:

1. **Consulta el backend**: `https://ceres.globalchat.org/api/mixcloud_stream_extractor.php`
2. **Si hay stream en vivo**:
   - Actualiza la URL de UrbanFlow con el stream HLS
   - Muestra el indicador "🔴 EN VIVO"
   - Reproduce el stream cuando el usuario da click
3. **Si NO hay stream**:
   - Usa la URL por defecto de Mixcloud
   - No muestra el indicador "EN VIVO"

**Todo es completamente automático**, sin intervención del usuario.

---

## 🐛 Solución de Problemas

### La radio no reproduce

1. **Verifica que el backend esté funcionando**:
   ```bash
   curl -s "https://ceres.globalchat.org/api/mixcloud_stream_extractor.php?username=djsonic_vlc"
   ```

2. **Verifica que el stream HLS sea accesible**:
   ```bash
   STREAM_URL=$(curl -s "https://ceres.globalchat.org/api/mixcloud_stream_extractor.php?username=djsonic_vlc" | jq -r '.stream_url')
   curl -I "$STREAM_URL"
   ```

3. **Abre la consola del navegador** (F12) y busca errores

4. **Espera 2 minutos** para que la app detecte el stream automáticamente

### El backend devuelve 404

Verifica que los archivos estén en la ubicación correcta:
```bash
ssh ceres.globalchat.org "ls -la /var/www/ceres.globalchat.org/api/"
```

Deberías ver:
- `mixcloud_stream_extractor.php`
- `mixcloud_stream_extractor.sh`

---

## 📊 Logs y Monitoreo

### Ver logs en la aplicación web
1. Abre la consola del navegador (F12)
2. Busca mensajes con `[MixcloudLive]`

### Ver logs del backend (en el servidor)
```bash
ssh ceres.globalchat.org "sudo tail -f /var/log/apache2/error.log"
```

---

## 🎯 Checklist de Verificación

- [ ] El backend responde correctamente
- [ ] El backend detecta el stream en vivo
- [ ] El stream HLS es accesible
- [ ] La aplicación web carga correctamente
- [ ] La radio UrbanFlow aparece en la lista
- [ ] El indicador "🔴 EN VIVO" se muestra cuando hay stream
- [ ] La radio reproduce el stream correctamente
- [ ] Los logs en la consola muestran la detección del stream

---

## 📝 Notas

- Los streams HLS de Mixcloud tienen una duración limitada (expiran)
- La aplicación actualiza automáticamente el stream cada 2 minutos
- Si el stream expira, la app obtendrá uno nuevo automáticamente
- El backend usa un script bash para extraer el stream (más robusto que PHP puro)

---

## 🔗 Enlaces Útiles

- **Aplicación Web**: https://ceres.globalchat.org/static/
- **Backend API**: https://ceres.globalchat.org/api/mixcloud_stream_extractor.php
- **Mixcloud Live**: https://www.mixcloud.com/live/djsonic_vlc/
- **Documentación**: `INTEGRACION_MIXCLOUD_LIVE.md`

---

**Última actualización**: 31 de enero de 2026
**Estado**: ✅ Sistema funcionando correctamente
