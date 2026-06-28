# 📋 Cómo Ver los Logs en Windows

## 🔍 Dónde Ver los Logs

### Opción 1: Ejecutar desde Terminal (Recomendado)

**Los logs aparecen en la terminal cuando ejecutas desde PowerShell o CMD:**

```batch
# Abre PowerShell o CMD
cd C:\src\irc_app\build\windows\x64\runner\Release
.\irc_app.exe
```

**Los logs aparecerán directamente en la terminal.**

### Opción 2: Guardar Logs en Archivo

Si quieres guardar los logs en un archivo:

```batch
cd C:\src\irc_app\build\windows\x64\runner\Release
.\irc_app.exe > logs.txt 2>&1
```

Esto guardará todos los logs (incluyendo errores) en `logs.txt` en la misma carpeta.

### Opción 3: Ver Logs en Tiempo Real y Guardar

```batch
cd C:\src\irc_app\build\windows\x64\runner\Release
.\irc_app.exe | Tee-Object -FilePath logs.txt
```

Esto muestra los logs en la terminal Y los guarda en `logs.txt`.

## 📝 Ejemplo de Salida

Cuando ejecutes la app e intentes conectarte, deberías ver:

```
📡 [IRCService.connect] Connecting to ceres.globalchat.org:6697 as Usuario (SSL: true)
📡 [IRCService.connect] Platform: Native
📡 [IRCService] Connection type: IRCSocketConnection
📡 [IRCService] PlatformUtils.canUseNativeSockets: true
📡 [IRCService] PlatformUtils.mustUseWebSocket: false
🔌 [IRCSocketConnection] Attempting TCP connection to ceres.globalchat.org:6697 (SSL: true)
🔌 [IRCSocketConnection] Connecting with SSL...
✅ [IRCSocketConnection] SSL connection established
✅ [IRCService] Connection established to ceres.globalchat.org:6697 using IRCSocketConnection
```

O si hay un error:

```
🔌 [IRCSocketConnection] Attempting TCP connection to ceres.globalchat.org:6697 (SSL: true)
🔌 [IRCSocketConnection] Connecting with SSL...
❌ [IRCSocketConnection] Connection error: SocketException: Connection refused
❌ [IRCSocketConnection] Error type: SocketException
❌ [IRCService] Connection failed: SocketException: Connection refused
```

## ⚠️ Importante

**Si ejecutas la aplicación haciendo doble clic en el `.exe`, los logs NO se mostrarán** porque no hay una consola asociada.

**Siempre ejecuta desde terminal para ver los logs.**

## 🚀 Pasos Rápidos

1. **Abre PowerShell** (o CMD)
2. **Navega a la carpeta:**
   ```powershell
   cd C:\src\irc_app\build\windows\x64\runner\Release
   ```
3. **Ejecuta la app:**
   ```powershell
   .\irc_app.exe
   ```
4. **Intenta conectarte a un servidor IRC**
5. **Copia los logs que aparecen en la terminal**

## 💡 Consejo

Si quieres ver los logs Y guardarlos al mismo tiempo:

```powershell
cd C:\src\irc_app\build\windows\x64\runner\Release
.\irc_app.exe *> logs.txt
```

Luego abre `logs.txt` en un editor de texto para ver todos los logs.

## 🔧 Si No Ves Nada

Si no ves logs, puede ser que:
1. La aplicación no esté intentando conectarse
2. Los logs estén siendo silenciados

En ese caso, guarda los logs en archivo:
```batch
.\irc_app.exe > logs.txt 2>&1
```

Y luego revisa `logs.txt`.
