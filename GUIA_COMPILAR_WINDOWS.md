# 🪟 Guía Rápida: Compilar y Empaquetar para Windows

## 📋 Requisitos Previos

1. **Windows 10 o superior**
2. **Flutter SDK** instalado y en el PATH
3. **Visual Studio 2022** (Community es gratis) con:
   - Carga de trabajo: "Desarrollo para el escritorio con C++"
   - Componente: "Windows 10/11 SDK"
4. **Inno Setup 6** (gratis): https://jrsoftware.org/isdl.php

## 🚀 Método Rápido (Recomendado)

### Opción 1: Script Automático (Batch)

```batch
build_installer.bat
```

Este script hace todo automáticamente:
1. ✅ Limpia builds anteriores
2. ✅ Obtiene dependencias
3. ✅ Compila la aplicación (Release)
4. ✅ Crea el instalador con Inno Setup
5. ✅ Te muestra dónde está el instalador

### Opción 2: Script PowerShell (Más moderno)

```powershell
.\build_installer.ps1
```

Si PowerShell te da error de ejecución, ejecuta primero:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 📝 Método Manual (Paso a Paso)

### 1. Compilar la aplicación

```bash
# Limpiar builds anteriores
flutter clean

# Obtener dependencias
flutter pub get

# Compilar para Windows (Release)
flutter build windows --release
```

El ejecutable estará en: `build\windows\x64\runner\Release\irc_app.exe`

### 2. Crear el instalador

**Opción A: Usar Inno Setup Compiler (GUI)**
1. Abre **Inno Setup Compiler**
2. Abre el archivo `installer.iss`
3. Presiona `Ctrl+F9` o ve a **Build → Compile**
4. El instalador se creará en `installers\`

**Opción B: Usar línea de comandos**
```batch
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

## 📦 Resultado

Después de compilar, tendrás:

```
installers/
└── irc_app_setup_3.0.4_x64.exe  ← Este es tu instalador
```

Este archivo `.exe` es todo lo que necesitas para distribuir la aplicación.

## 🔧 Solución de Problemas

### Error: "Flutter no encontrado"
- Asegúrate de que Flutter esté en el PATH del sistema
- Reinicia la terminal después de instalar Flutter

### Error: "Inno Setup no encontrado"
- Instala Inno Setup 6 desde: https://jrsoftware.org/isdl.php
- El script busca en: `C:\Program Files (x86)\Inno Setup 6\ISCC.exe`
- Si lo instalaste en otra ubicación, edita `build_installer.bat` o `build_installer.ps1`

### Error: "Visual Studio no encontrado"
- Instala Visual Studio 2022 Community (gratis)
- Durante la instalación, selecciona: "Desarrollo para el escritorio con C++"
- Reinicia la computadora después de instalar

### Error de TLS/SSL al ejecutar `flutter pub get`
```bash
git config --global http.sslBackend schannel
flutter pub get
```

### El instalador es muy grande
- Esto es normal, incluye todas las DLLs necesarias
- Puedes comprimirlo con 7-Zip o WinRAR para distribución

## 📊 Verificar la Compilación

Después de compilar, verifica que existan estos archivos:

```
build\windows\x64\runner\Release\
├── irc_app.exe          ← Ejecutable principal
├── flutter_windows.dll  ← DLL de Flutter
├── data\               ← Assets y recursos
└── ... (otras DLLs)
```

## 🎯 Personalizar el Instalador

Edita `installer.iss` para cambiar:
- **Versión**: Línea 7 (`#define MyAppVersion`)
- **Nombre**: Línea 6 (`#define MyAppName`)
- **Icono**: Línea 36 (`SetupIconFile`)
- **Compresión**: Línea 37 (`Compression`)

## 📤 Distribuir

Una vez creado el instalador:

1. **Probar en una máquina limpia** (o máquina virtual)
2. **Verificar que instale correctamente**
3. **Verificar que desinstale correctamente**
4. **Subir a tu sitio web o GitHub Releases**

## 🔐 Firma Digital (Opcional)

Para evitar advertencias de Windows Defender:

1. Compra un certificado de firma de código (DigiCert, Sectigo, etc.)
2. Firma el instalador:
```batch
signtool sign /f certificado.pfx /p password /t http://timestamp.digicert.com installers\irc_app_setup_3.0.4_x64.exe
```

## 📚 Recursos Adicionales

- **Documentación Flutter Windows**: https://docs.flutter.dev/deployment/windows
- **Inno Setup Docs**: https://jrsoftware.org/ishelp/
- **Visual Studio**: https://visualstudio.microsoft.com/downloads/

## ✅ Checklist Final

Antes de distribuir, verifica:

- [ ] El instalador se crea sin errores
- [ ] El instalador funciona en Windows 10
- [ ] El instalador funciona en Windows 11
- [ ] La aplicación se ejecuta después de instalar
- [ ] Los iconos aparecen en el escritorio y menú inicio
- [ ] La desinstalación funciona correctamente
- [ ] No hay errores de DLLs faltantes
- [ ] El tamaño del instalador es razonable

---

**¿Problemas?** Revisa `COMPILAR_WINDOWS.md` para más detalles o `INSTALADOR_INNOSETUP.md` para personalización avanzada.
