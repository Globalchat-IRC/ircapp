# 🔧 Solución: Problemas de Conexión IRC en Windows

## 🔍 Problema

La aplicación en Windows solo funciona cuando se conecta a través de ceres (WebSocket), pero no funciona con conexiones IRC directas (Socket TCP).

## 🎯 Causas Posibles

### 1. Firewall de Windows bloqueando conexiones salientes

Windows Firewall puede estar bloqueando las conexiones TCP salientes de la aplicación.

**Solución:**
1. Abre **Windows Defender Firewall**
2. Ve a **Configuración avanzada**
3. Haz clic en **Reglas de salida** → **Nueva regla**
4. Selecciona **Programa** → Busca `irc_app.exe` en `build\windows\x64\runner\Release\`
5. Permite la conexión
6. Aplica a todos los perfiles (Dominio, Privada, Pública)

### 2. Permisos de red en el manifest

El archivo `runner.exe.manifest` puede necesitar permisos de red explícitos.

**Solución:** Ya está actualizado con permisos de red.

### 3. Certificados SSL/TLS

Windows puede estar rechazando certificados SSL de servidores IRC.

**Solución:** El código ya acepta certificados con problemas de validación, pero puedes verificar:
- Abre PowerShell como Administrador
- Ejecuta: `certutil -generateSSTFromWU roots.sst`

### 4. Timeout muy corto

El timeout de conexión puede ser muy corto para algunas redes.

**Solución:** Ya está configurado a 20 segundos para SSL y 10 segundos para TCP.

## 🔍 Diagnóstico

### Verificar qué tipo de conexión se está usando

Abre la consola de la aplicación (si hay logs) y busca:
```
📡 [IRCService] Connection type: IRCSocketConnection
```

Si ves `IRCWebSocketConnection`, significa que está usando WebSocket (ceres) en lugar de TCP nativo.

### Verificar si el firewall está bloqueando

1. Abre PowerShell como Administrador
2. Ejecuta:
```powershell
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*irc*"} | Format-Table DisplayName, Enabled, Direction
```

### Probar conexión manual

Abre PowerShell y prueba:
```powershell
Test-NetConnection -ComputerName irc.tu-servidor.com -Port 6697
```

Si falla, el firewall o la red está bloqueando.

## ✅ Soluciones Implementadas

1. **Fallback automático a WebSocket:** Si la conexión TCP nativa falla, automáticamente intenta WebSocket
2. **Mejor logging:** Ahora muestra qué tipo de conexión se está usando
3. **Manejo de errores mejorado:** Captura y muestra errores de conexión

## 🚀 Pasos para Solucionar

### Paso 1: Permitir en Firewall

```powershell
# Ejecutar como Administrador
New-NetFirewallRule -DisplayName "IRC App - Outbound" -Direction Outbound -Program "C:\ruta\a\irc_app.exe" -Action Allow
```

### Paso 2: Verificar permisos de red

Asegúrate de que el manifest tenga permisos de red (ya está actualizado).

### Paso 3: Recompilar

```batch
flutter clean
flutter build windows --release
```

### Paso 4: Probar

1. Ejecuta la aplicación
2. Intenta conectarte a un servidor IRC
3. Revisa los logs en la consola para ver qué tipo de conexión se usa

## 📝 Logs de Diagnóstico

La aplicación ahora muestra logs como:
```
📡 [IRCService] Connection type: IRCSocketConnection
📡 [IRCService] PlatformUtils.canUseNativeSockets: true
📡 [IRCService] PlatformUtils.mustUseWebSocket: false
✅ [IRCService] Connection established to irc.example.com:6697
```

Si ves un error seguido de:
```
⚠️ [IRCService] Native socket failed, trying WebSocket fallback...
✅ [IRCService] WebSocket fallback connection established
```

Significa que el firewall está bloqueando y se está usando WebSocket como fallback.

## 🔐 Configuración del Firewall Manual

1. **Windows Defender Firewall** → **Configuración avanzada**
2. **Reglas de salida** → **Nueva regla**
3. **Programa** → Ruta: `C:\ruta\a\build\windows\x64\runner\Release\irc_app.exe`
4. **Acción:** Permitir la conexión
5. **Perfiles:** Marcar todos (Dominio, Privada, Pública)
6. **Nombre:** "IRC App - Conexiones salientes"

## ⚠️ Nota Importante

Si después de permitir en el firewall sigue usando WebSocket, puede ser que:
- El servidor IRC esté bloqueado por el ISP
- Haya un proxy corporativo bloqueando
- El servidor IRC requiera autenticación especial

En ese caso, usar ceres (WebSocket) es la solución correcta.
