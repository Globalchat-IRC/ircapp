# 🔧 Habilitar Modo de Desarrollador en Windows

## ⚠️ Problema

Al intentar ejecutar la aplicación IRC App aparece un mensaje como:

```
"Para usar esta función, activa el Modo de desarrollador"
```

o

```
"Esta aplicación requiere el Modo de desarrollador"
```

o Windows SmartScreen bloquea la aplicación.

## 🎯 Soluciones

### Solución 1: Habilitar Modo de Desarrollador (Recomendado para desarrollo)

Esta solución es útil si estás desarrollando o probando la aplicación.

#### Windows 11:

1. **Abrir Configuración**:
   - Presiona `Windows + I`
   - O busca "Configuración" en el menú inicio

2. **Ir a Privacidad y seguridad**:
   - En el menú izquierdo, haz clic en **"Privacidad y seguridad"**
   - Haz clic en **"Para desarrolladores"**

3. **Activar Modo de desarrollador**:
   - Activa el interruptor de **"Modo de desarrollador"**
   - Aparecerá un mensaje de advertencia, haz clic en **"Sí"**

4. **Esperar instalación**:
   - Windows instalará los componentes necesarios
   - Puede tardar unos minutos
   - Reinicia si te lo pide

#### Windows 10:

1. **Abrir Configuración**:
   - Presiona `Windows + I`
   - O busca "Configuración" en el menú inicio

2. **Ir a Actualización y seguridad**:
   - Haz clic en **"Actualización y seguridad"**
   - En el menú izquierdo, selecciona **"Para desarrolladores"**

3. **Activar Modo de desarrollador**:
   - Selecciona **"Modo de desarrollador"**
   - Aparecerá un mensaje de advertencia, haz clic en **"Sí"**

4. **Esperar instalación**:
   - Windows instalará los componentes necesarios
   - Puede tardar unos minutos

---

### Solución 2: Bypass de Windows SmartScreen (Para instalador sin firmar)

Si el problema es que Windows SmartScreen bloquea el instalador o la aplicación:

#### Al ejecutar el instalador:

1. **Aparece "Windows protegió tu PC"**:
   - Haz clic en **"Más información"**
   - Haz clic en **"Ejecutar de todas formas"**

2. **Si no aparece el botón**:
   - Clic derecho en el archivo `.exe`
   - Selecciona **"Propiedades"**
   - En la pestaña **"General"**
   - Marca la casilla **"Desbloquear"**
   - Haz clic en **"Aceptar"**
   - Intenta ejecutar de nuevo

#### Al ejecutar la aplicación después de instalar:

1. **Clic derecho** en el ejecutable `irc_app.exe`
2. Selecciona **"Propiedades"**
3. En la pestaña **"General"**
4. Marca **"Desbloquear"** (si aparece)
5. Haz clic en **"Aceptar"**

---

### Solución 3: Deshabilitar SmartScreen temporalmente (No recomendado)

**⚠️ Advertencia**: Esto reduce la seguridad de tu sistema. Úsalo solo temporalmente.

#### Windows 11/10:

1. **Abrir Seguridad de Windows**:
   - Busca "Seguridad de Windows" en el menú inicio
   - O presiona `Windows + I` → "Privacidad y seguridad" → "Seguridad de Windows"

2. **Ir a Control de aplicaciones y navegador**:
   - Haz clic en **"Control de aplicaciones y navegador"**

3. **Configurar SmartScreen**:
   - En **"Comprobar aplicaciones y archivos"**
   - Selecciona **"Desactivado"** (temporalmente)

4. **Después de instalar**:
   - **IMPORTANTE**: Vuelve a activar SmartScreen
   - Selecciona **"Advertir"** o **"Bloquear"**

---

### Solución 4: Firma digital del instalador (Solución profesional)

Para evitar estos problemas en tus usuarios:

#### Obtener certificado de firma de código:

1. **Comprar certificado**:
   - **DigiCert**: https://www.digicert.com/code-signing/
   - **Sectigo**: https://sectigo.com/ssl-certificates-tls/code-signing
   - **GlobalSign**: https://www.globalsign.com/en/code-signing-certificate
   - Costo: $100-$500 USD/año

2. **Firmar el instalador**:
   ```batch
   signtool sign /f "certificado.pfx" /p "contraseña" /t http://timestamp.digicert.com "installers\irc_app_setup_1.0.0_x64.exe"
   ```

3. **Ventajas**:
   - ✅ Windows no mostrará advertencias
   - ✅ Los usuarios confiarán más en tu aplicación
   - ✅ Aspecto más profesional

---

## 🔍 ¿Qué es el Modo de Desarrollador?

El Modo de Desarrollador en Windows permite:

- ✅ Instalar aplicaciones desde cualquier fuente
- ✅ Ejecutar scripts y aplicaciones sin firmar
- ✅ Acceder a funciones avanzadas de desarrollo
- ✅ Instalar aplicaciones UWP en modo de desarrollo
- ✅ Usar PowerShell sin restricciones adicionales

### ¿Es seguro activarlo?

**Para desarrollo**: Sí, es seguro si estás desarrollando o probando aplicaciones.

**Para uso normal**: No es necesario para usuarios finales. Los usuarios finales solo necesitan hacer clic en "Ejecutar de todas formas" cuando aparezca la advertencia de SmartScreen.

---

## 📦 Para distribuir tu aplicación a usuarios

Si vas a distribuir tu aplicación a otros usuarios, considera:

### Opción 1: Advertir a los usuarios

Crea un archivo `INSTALACION.txt` con instrucciones:

```
IMPORTANTE: Al instalar puede aparecer "Windows protegió tu PC"

Esto es normal porque la aplicación no tiene firma digital.

Pasos:
1. Haz clic en "Más información"
2. Haz clic en "Ejecutar de todas formas"
3. Sigue el asistente de instalación

La aplicación es segura y no contiene virus.
```

### Opción 2: Firmar digitalmente (Profesional)

- Compra un certificado de firma de código
- Firma el instalador
- Los usuarios no verán advertencias

### Opción 3: Distribuir como aplicación portable

En lugar de un instalador:

```
irc_app_portable_1.0.0.zip
├── irc_app.exe
├── (todas las DLLs)
└── LEEME.txt
```

Los usuarios solo extraen el ZIP y ejecutan directamente.

---

## ❓ Preguntas frecuentes

### ¿Por qué Windows bloquea mi aplicación?

Windows SmartScreen bloquea aplicaciones que:
- No tienen firma digital
- Son nuevas (sin "reputación")
- Fueron descargadas de internet

### ¿Necesito el Modo de desarrollador para usar IRC App?

**No**, solo necesitas:
- Hacer clic en "Más información" → "Ejecutar de todas formas" al instalar
- O desbloquear el archivo desde Propiedades

El Modo de desarrollador solo es útil si estás desarrollando.

### ¿Puedo desactivar el Modo de desarrollador después de instalar?

**Sí**, puedes desactivarlo cuando quieras. No afectará a las aplicaciones ya instaladas.

### ¿Cómo evito que mis usuarios vean estas advertencias?

La única forma es **firmar digitalmente** tu instalador con un certificado de código válido.

---

## 🛡️ Verificar que la aplicación es segura

Si descargaste IRC App de una fuente desconocida y quieres verificar que es segura:

### Escanear con Windows Defender:

1. Clic derecho en el archivo `.exe`
2. Selecciona **"Examinar con Microsoft Defender"**
3. Espera el resultado

### Escanear con VirusTotal (online):

1. Ve a: https://www.virustotal.com
2. Sube el archivo `.exe`
3. Revisa los resultados de 70+ antivirus

---

## 🔄 Revertir cambios

### Desactivar Modo de desarrollador:

**Windows 11**:
1. `Windows + I` → "Privacidad y seguridad" → "Para desarrolladores"
2. Desactiva el interruptor

**Windows 10**:
1. `Windows + I` → "Actualización y seguridad" → "Para desarrolladores"
2. Selecciona **"Aplicaciones de la Tienda"** o **"Transferir aplicaciones localmente"**

### Reactivar SmartScreen:

1. "Seguridad de Windows" → "Control de aplicaciones y navegador"
2. En "Comprobar aplicaciones y archivos" → Selecciona **"Advertir"**

---

## 📋 Checklist para desarrolladores

Antes de distribuir tu aplicación:

- [ ] Probar en Windows limpio (sin Modo de desarrollador)
- [ ] Documentar el proceso de instalación
- [ ] Considerar firma digital si es aplicación profesional
- [ ] Crear un `LEEME.txt` con instrucciones
- [ ] Advertir sobre mensajes de SmartScreen
- [ ] Ofrecer versión portable alternativa

---

## 💡 Mejores prácticas

### Para desarrollo (tú):
- ✅ Activa el Modo de desarrollador
- ✅ Te ahorrará tiempo y molestias

### Para distribución (tus usuarios):
- ✅ Documenta el proceso de instalación
- ✅ Explica que las advertencias son normales
- ✅ Considera firmar la aplicación si es comercial
- ✅ Ofrece checksums (MD5/SHA256) para verificar integridad

---

## 📞 Recursos adicionales

- **Modo de desarrollador Microsoft**: https://learn.microsoft.com/es-es/windows/apps/get-started/enable-your-device-for-development
- **Windows SmartScreen**: https://support.microsoft.com/es-es/windows/smartscreen
- **Firma de código**: https://learn.microsoft.com/es-es/windows/win32/seccrypto/signtool

---

**Creado por**: Fran Naveira  
**Última actualización**: Diciembre 2025

