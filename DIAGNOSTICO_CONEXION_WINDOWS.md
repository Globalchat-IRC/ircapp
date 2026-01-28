# 🔍 Diagnóstico: Problemas de Conexión IRC en Windows

## 🎯 Problema

La aplicación en Windows solo funciona a través de ceres (WebSocket), pero no con conexiones IRC directas (Socket TCP).

## 🔍 Diagnóstico

### 1. Verificar qué tipo de conexión se está usando

Cuando ejecutes la aplicación, busca en los logs:

```
📡 [IRCService] Connection type: IRCSocketConnection
```

Si ves `IRCSocketConnection`, está intentando usar TCP nativo (correcto).
Si ves `IRCWebSocketConnection`, está usando WebSocket (solo para web).

### 2. Verificar errores de conexión

Si la conexión TCP falla, verás:

```
❌ [IRCSocketConnection] Connection error: [error específico]
❌ [IRCSocketConnection] Error type: [tipo de error]
```

**Errores comunes:**

- **`SocketException: Connection refused`**
  - El servidor rechazó la conexión
  - Verifica que el servidor esté disponible
  - Verifica el puerto (6697 para SSL, 6667 para no SSL)

- **`SocketException: Connection timed out`**
  - Timeout de conexión
  - Puede ser firewall, red lenta, o servidor no disponible
  - El timeout ahora es de 30 segundos

- **`TlsException: Handshake error`**
  - Error en el handshake SSL/TLS
  - Puede ser problema de certificado o configuración SSL

- **`OSError: No route to host`**
  - No hay ruta de red al servidor
  - Verifica conectividad de red

### 3. Verificar si el problema es de red

Abre PowerShell y prueba:

```powershell
# Probar conectividad básica
Test-NetConnection -ComputerName irc.servidor.com -Port 6697

# Probar con telnet (si está instalado)
telnet irc.servidor.com 6697
```

### 4. Verificar logs completos

La aplicación ahora muestra logs detallados:

```
🔌 [IRCSocketConnection] Attempting TCP connection to irc.servidor.com:6697 (SSL: true)
🔌 [IRCSocketConnection] Connecting with SSL...
✅ [IRCSocketConnection] SSL connection established
✅ [IRCService] Connection established to irc.servidor.com:6697 using IRCSocketConnection
```

O si falla:

```
🔌 [IRCSocketConnection] Attempting TCP connection to irc.servidor.com:6697 (SSL: true)
🔌 [IRCSocketConnection] Connecting with SSL...
❌ [IRCSocketConnection] Connection error: SocketException: Connection refused
❌ [IRCSocketConnection] Error type: SocketException
❌ [IRCService] Connection failed: SocketException: Connection refused
```

## ✅ Cambios Realizados

1. **Eliminado fallback automático a WebSocket**
   - Ahora el error se propaga correctamente
   - El usuario verá el error real

2. **Logging mejorado**
   - Muestra cada paso de la conexión
   - Muestra el tipo de error específico
   - Muestra stack trace completo

3. **Timeout aumentado**
   - De 20 a 30 segundos para SSL
   - De 10 a 30 segundos para TCP sin SSL

## 🔧 Soluciones según el Error

### Si ves "Connection refused"

1. Verifica que el servidor IRC esté disponible
2. Verifica el puerto (6697 para SSL, 6667 para no SSL)
3. Prueba con otro cliente IRC (mIRC, HexChat) para verificar

### Si ves "Connection timed out"

1. Verifica firewall (aunque dijiste que no parece ser)
2. Verifica que no haya proxy corporativo bloqueando
3. Prueba desde otra red
4. Verifica que el servidor acepte conexiones desde tu IP

### Si ves "Handshake error"

1. Prueba desactivando SSL (puerto 6667)
2. Verifica que el servidor soporte TLS 1.2 o superior
3. Revisa los certificados del servidor

### Si ves "No route to host"

1. Verifica conectividad de red básica
2. Verifica DNS: `nslookup irc.servidor.com`
3. Verifica que no haya bloqueo de ISP

## 📝 Próximos Pasos

1. **Ejecuta la aplicación y copia los logs completos**
2. **Busca las líneas que empiezan con:**
   - `🔌 [IRCSocketConnection]`
   - `❌ [IRCSocketConnection]`
   - `❌ [IRCService]`

3. **Comparte los logs** para identificar el error específico

## 🚨 Nota Importante

El fallback automático a WebSocket ha sido **deshabilitado**. Ahora verás el error real de la conexión TCP, lo que nos permitirá diagnosticar el problema específico.

Si necesitas usar WebSocket (ceres) como solución temporal, puedes modificar el código para forzar WebSocket, pero primero necesitamos ver qué error específico está dando la conexión TCP.
