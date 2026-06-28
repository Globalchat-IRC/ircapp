# 🚀 Quick Start - Mixcloud Live Automático

## ¿Qué es esto?

Sistema **100% automático** que hace que UrbanFlow reproduzca el stream en vivo de djsonic_vlc cuando esté emitiendo en Mixcloud.

**El usuario no hace nada. Todo es automático.**

## 🎯 Desplegar en 3 pasos

### Paso 1: Desplegar el backend PHP

```bash
cd /Users/fnaveira/mobile/irc_app
./deploy_mixcloud_extractor.sh
```

Esto copia el archivo PHP al servidor y lo configura.

### Paso 2: Verificar que funciona

```bash
cd tool
./test_mixcloud_integration.sh
```

Verás si djsonic_vlc está en vivo o no.

### Paso 3: Compilar y desplegar la app

```bash
# Para web
flutter build web --release
./deploy_to_ceres.sh
```

## ✅ ¡Listo!

Ahora cuando djsonic_vlc emita en Mixcloud:

1. La app detecta automáticamente el stream (cada 2 min)
2. Muestra "🔴 EN VIVO" en UrbanFlow
3. Reproduce el stream en vivo cuando el usuario presiona Play
4. Todo sin configuración ni intervención

## 🧪 Probar manualmente

```bash
# Ver si hay stream en vivo ahora
curl "https://webchat.globalchat.org/gateway/mixcloud_stream_extractor.php?username=djsonic_vlc"

# Extraer stream con el script
cd tool
./extract_mixcloud_stream.sh https://www.mixcloud.com/live/djsonic_vlc/
```

## 📚 Documentación completa

- `MIXCLOUD_LIVE_RESUMEN.md` - Resumen ejecutivo
- `INTEGRACION_MIXCLOUD_LIVE.md` - Documentación técnica completa

---

**¡Eso es todo! Sistema completamente automático sin configuración manual.**
