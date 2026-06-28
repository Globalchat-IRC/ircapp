# Solución: Cámaras no se ven en Jitsi Meet

## Problema
Las cámaras de video no se muestran en las videoconferencias de Jitsi Meet en el servidor caliope.

## Diagnóstico

### 1. Ejecutar script de diagnóstico
En el servidor caliope, ejecuta:
```bash
bash diagnostico_jitsi_camaras.sh
```

### 2. Revisar archivos de configuración manualmente

#### Archivo principal: `/etc/jitsi/meet/video.globalchat.org-config.js`

Busca y verifica estas configuraciones:

```javascript
// ❌ PROBLEMAS - Estas configuraciones DESACTIVAN el video:
startWithVideoMuted: true,     // ← Esto inicia con video desactivado
disableVideo: true,            // ← Esto deshabilita completamente el video

// ✅ SOLUCIÓN - Configuraciones correctas:
startWithVideoMuted: false,    // ← Iniciar con video activado
disableVideo: false,           // ← Video habilitado (o no incluir esta opción)

// NOTA: defaultLocalVideoMuted puede no existir en todas las versiones
// Si existe, debe ser: defaultLocalVideoMuted: false
```

#### Archivo de interfaz: `/etc/jitsi/meet/video.globalchat.org-interface_config.js`

Verifica que los botones de cámara estén habilitados:
```javascript
TOOLBAR_BUTTONS: [
    'microphone', 
    'camera',        // ← Debe estar presente
    // ... otros botones
]
```

## Soluciones

### Solución 1: Modificar configuración del servidor

1. **Editar el archivo de configuración:**
```bash
nano /etc/jitsi/meet/video.globalchat.org-config.js
```

2. **Buscar y modificar estas líneas:**
```javascript
// Si existe startWithVideoMuted, cambiar de:
startWithVideoMuted: true,

// A:
startWithVideoMuted: false,

// Si existe disableVideo, cambiar de:
disableVideo: true,

// A:
disableVideo: false,

// Si NO existe startWithVideoMuted, agregarlo:
startWithVideoMuted: false,
```

3. **Guardar y reiniciar servicios:**
```bash
systemctl restart jitsi-videobridge2
systemctl restart jicofo
systemctl restart prosody
```

### Solución 2: Verificar configuración de TURN/STUN

El video puede no funcionar si TURN/STUN no está configurado correctamente.

1. **Revisar configuración de ICE servers en config.js:**
```javascript
iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    // Si tienes servidor TURN, agregarlo aquí
]
```

2. **Si no hay servidor TURN, considerar configurar uno** para usuarios detrás de NAT/firewall.

### Solución 3: Verificar permisos del navegador

Asegúrate de que los usuarios:
1. Den permisos de cámara al navegador
2. Usen HTTPS (no HTTP)
3. Usen un navegador moderno (Chrome, Firefox, Edge)

### Solución 4: Revisar logs

```bash
# Logs de Jicofo (coordinador)
tail -f /var/log/jitsi/jicofo.log

# Logs de JVB (puente de video)
tail -f /var/log/jitsi/jvb.log

# Buscar errores relacionados con video
grep -i "video\|camera\|webrtc" /var/log/jitsi/jicofo.log
```

## Configuración recomendada

### En `config.js`:
```javascript
var config = {
    // ... otras configuraciones ...
    
    // Video activado por defecto (importante)
    startWithVideoMuted: false,  // ← Iniciar con video activado
    
    // Permitir video (si existe esta opción)
    disableVideo: false,        // ← Video habilitado
    
    // NOTA: defaultLocalVideoMuted puede no existir en todas las versiones
    // Si tu versión lo soporta, agregar: defaultLocalVideoMuted: false,
    
    // Configuración de calidad de video
    videoQuality: {
        maxBitrate: 2500000,  // 2.5 Mbps
        minBitrate: 500000,   // 500 Kbps
    },
    
    // ICE servers para WebRTC
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
    ],
    
    // ... resto de configuraciones ...
};
```

### En `interface_config.js`:
```javascript
var interfaceConfig = {
    // ... otras configuraciones ...
    
    // Botones de la barra de herramientas (incluir 'camera')
    TOOLBAR_BUTTONS: [
        'microphone', 
        'camera',           // ← Importante: debe estar presente
        'closedcaptions',
        'desktop',
        'fullscreen',
        'fodeviceselection',
        'hangup',
        'profile',
        'chat',
        'recording',
        'livestreaming',
        'settings',
        'raisehand',
        'videoquality',
        'filmstrip',
        'tileview',
        'videobackgroundblur',
        'download',
        'help',
        'mute-everyone',
        'security'
    ],
    
    // ... resto de configuraciones ...
};
```

## Verificación

Después de hacer cambios:

1. **Reiniciar servicios:**
```bash
systemctl restart jitsi-videobridge2
systemctl restart jicofo
systemctl restart prosody
```

2. **Probar en el navegador:**
   - Abrir `https://video.globalchat.org/test-room`
   - Verificar que la cámara se active automáticamente
   - Verificar que el botón de cámara esté disponible

3. **Revisar consola del navegador (F12):**
   - Buscar errores relacionados con WebRTC
   - Verificar que los permisos de cámara estén otorgados

## Problemas comunes

### Error: "Camera not found"
- Verificar que la cámara esté conectada
- Verificar permisos del navegador
- Probar en otro navegador

### Error: "WebRTC connection failed"
- Verificar configuración de TURN/STUN
- Verificar firewall (puertos UDP 10000-20000)
- Verificar que el servidor tenga IP pública

### Video se congela o es de baja calidad
- Verificar ancho de banda
- Ajustar `maxBitrate` en config.js
- Verificar recursos del servidor (CPU, RAM)

## Contacto

Si el problema persiste después de seguir estos pasos, revisar:
- Logs completos del sistema
- Configuración de red/firewall
- Versión de Jitsi Meet instalada

