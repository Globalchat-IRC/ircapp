# 🔓 Habilitar ejecución de scripts PowerShell en Windows

## ⚠️ Problema

Al intentar ejecutar archivos `.ps1` (PowerShell) aparece el error:

```
No se puede cargar el archivo *.ps1 porque la cejecución de scripts está deshabilitada en este sistema.
```

o en inglés:

```
*.ps1 cannot be loaded because running scripts is disabled on this system.
```

## ✅ Soluciones

### Solución 1: Habilitar permanentemente (RECOMENDADO)

Esta solución habilita la ejecución de scripts de forma permanente pero segura.

#### Pasos:

1. **Abrir PowerShell como Administrador**:
   - Presiona `Windows + X`
   - Selecciona **"Windows PowerShell (Administrador)"** o **"Terminal (Administrador)"**
   - Si aparece UAC, haz clic en **"Sí"**

2. **Ejecutar el siguiente comando**:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Confirmar**:
   - Escribe `S` y presiona Enter
   - O escribe `Y` si el sistema está en inglés

4. **Verificar**:
   ```powershell
   Get-ExecutionPolicy -List
   ```
   
   Deberías ver:
   ```
   Scope          ExecutionPolicy
   -----          ---------------
   MachinePolicy  Undefined
   UserPolicy     Undefined
   Process        Undefined
   CurrentUser    RemoteSigned    ← Debe decir esto
   LocalMachine   Undefined
   ```

5. **¡Listo!** Ahora puedes cerrar PowerShell y ejecutar los scripts `.ps1`

#### ¿Qué hace `RemoteSigned`?

- ✅ Permite ejecutar scripts locales (los que tú creas)
- ✅ Solo requiere firma digital para scripts descargados de internet
- ✅ Es seguro y recomendado por Microsoft
- ✅ No afecta la seguridad del sistema

---

### Solución 2: Ejecutar una sola vez (sin cambiar configuración)

Si no quieres cambiar la configuración del sistema, puedes ejecutar el script una sola vez con este comando:

1. **Abrir PowerShell normal** (NO como administrador)

2. **Navegar a la carpeta del proyecto**:
   ```powershell
   cd C:\ruta\a\tu\proyecto\irc_app
   ```

3. **Ejecutar con bypass**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\installer_wizard.ps1
   ```

Esto ejecutará el script sin cambiar la configuración del sistema.

---

### Solución 3: Usar el script Batch (.bat) - SIN POWERSHELL

Si prefieres no usar PowerShell, usa el wizard en formato Batch:

1. **Doble clic en**: `installer_wizard.bat`
2. O desde CMD:
   ```batch
   installer_wizard.bat
   ```

**Ventajas:**
- ✅ No requiere permisos especiales
- ✅ Funciona inmediatamente
- ✅ Mismas funcionalidades que el PowerShell

**Desventajas:**
- ❌ Interfaz menos moderna
- ❌ Sin emojis ni colores avanzados

---

### Solución 4: Desbloquear el archivo descargado

Si descargaste el script de internet, Windows lo bloquea por seguridad.

1. **Clic derecho** en el archivo `.ps1`
2. Selecciona **"Propiedades"**
3. En la pestaña **"General"**
4. Marca la casilla **"Desbloquear"** (si aparece)
5. Haz clic en **"Aceptar"**
6. Intenta ejecutar de nuevo

---

## 🎯 Comparación de soluciones

| Solución | Permanente | Requiere Admin | Dificultad |
|----------|------------|----------------|------------|
| **Solución 1** (RemoteSigned) | ✅ Sí | ⚠️ Sí | Fácil |
| **Solución 2** (Bypass) | ❌ No | ❌ No | Muy fácil |
| **Solución 3** (Batch) | N/A | ❌ No | Muy fácil |
| **Solución 4** (Desbloquear) | ❌ No | ❌ No | Muy fácil |

---

## 🔒 Niveles de ExecutionPolicy

Para tu información, estos son los niveles disponibles:

| Política | Descripción |
|----------|-------------|
| **Restricted** | No permite ejecutar ningún script (default en Windows Client) |
| **AllSigned** | Solo scripts firmados digitalmente |
| **RemoteSigned** | Scripts locales OK, descargados requieren firma ⭐ RECOMENDADO |
| **Unrestricted** | Todos los scripts, pero avisa en descargados |
| **Bypass** | Sin restricciones ni avisos |

---

## ❓ Preguntas frecuentes

### ¿Es seguro cambiar a RemoteSigned?

**Sí**, es totalmente seguro. Es la configuración recomendada por Microsoft para desarrolladores.

### ¿Afecta a otros programas?

**No**, solo afecta a la ejecución de scripts PowerShell.

### ¿Puedo revertir el cambio?

**Sí**, ejecuta:
```powershell
Set-ExecutionPolicy Restricted -Scope CurrentUser
```

### ¿Qué pasa si no tengo permisos de administrador?

Usa la **Solución 2** (Bypass) o la **Solución 3** (Batch).

### ¿Funciona en Windows 10 y 11?

**Sí**, funciona en ambos.

---

## 🚀 Inicio rápido (después de habilitar)

Una vez habilitados los scripts:

### Opción A: PowerShell (recomendado)
```powershell
cd C:\ruta\a\tu\proyecto\irc_app
.\installer_wizard.ps1
```

### Opción B: Doble clic
- Doble clic en `installer_wizard.ps1`
- Si aparece "Abrir con", selecciona **"Windows PowerShell"**

---

## 🛡️ Políticas corporativas

Si trabajas en una empresa y no puedes cambiar la política:

1. **Contacta con IT/Sistemas** para solicitar permiso
2. Mientras tanto, usa **installer_wizard.bat** (Solución 3)
3. O pide que te habiliten `RemoteSigned` para tu usuario

---

## 📞 Ayuda adicional

Si ninguna solución funciona:

1. Verifica que Windows está actualizado
2. Verifica que PowerShell está instalado: `$PSVersionTable.PSVersion`
3. Usa el script Batch como alternativa
4. Contacta con el administrador del sistema

---

**Creado por**: Fran Naveira  
**Última actualización**: Diciembre 2025

