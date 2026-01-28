# 🪟 Cómo compilar IRC App en Windows - Guía Simple

## 📋 Requisitos (instalar primero)

1. **Flutter SDK** - https://docs.flutter.dev/get-started/install/windows
2. **Visual Studio 2022** (Community es gratis) con:
   - Carga de trabajo: "Desarrollo para el escritorio con C++"
   - Componente: "Windows 10/11 SDK"
3. **Inno Setup 6** (gratis) - https://jrsoftware.org/isdl.php

## 🚀 Pasos para compilar

### Paso 1: Abrir PowerShell o CMD

Abre PowerShell o CMD en la carpeta del proyecto:
```batch
cd C:\ruta\a\tu\proyecto\irc_app
```

### Paso 2: Obtener dependencias

```batch
flutter pub get
```

### Paso 3: Compilar la aplicación

```batch
flutter build windows --release
```

**Esto creará los archivos en:** `build\windows\x64\runner\Release\`

### Paso 4: Verificar que se compiló

```batch
dir build\windows\x64\runner\Release\irc_app.exe
```

Si ves el archivo `irc_app.exe`, ¡la compilación fue exitosa!

## 📦 Crear el instalador (opcional)

### Opción A: Usar el script automático

```batch
.\build_installer.bat
```

### Opción B: Crear instalador manualmente

1. Abre **Inno Setup Compiler**
2. Abre el archivo `installer.iss`
3. Presiona `Ctrl+F9` o ve a **Build → Compile**
4. El instalador estará en: `installers\irc_app_setup_3.0.4_x64.exe`

### Opción C: Línea de comandos

```batch
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

## ✅ Resultado

Después de compilar tendrás:

- **Ejecutable:** `build\windows\x64\runner\Release\irc_app.exe`
- **Instalador (si usaste Inno Setup):** `installers\irc_app_setup_3.0.4_x64.exe`

## 🔍 Si algo falla

### Error: "Flutter no encontrado"
- Añade Flutter al PATH del sistema
- Reinicia la terminal

### Error: "Visual Studio no encontrado"
- Instala Visual Studio 2022 Community
- Selecciona "Desarrollo para el escritorio con C++" durante la instalación

### Error: "No se encuentra irc_app.exe"
- Verifica que la compilación terminó sin errores
- Busca manualmente: `dir /s build\windows\*.exe`

### La carpeta Release no existe
- Ejecuta: `flutter clean`
- Luego: `flutter build windows --release`
- Verifica: `dir build\windows\x64\runner\Release\`

## 📝 Resumen rápido

```batch
# 1. Ir a la carpeta del proyecto
cd C:\src\irc_app

# 2. Obtener dependencias
flutter pub get

# 3. Compilar
flutter build windows --release

# 4. Verificar
dir build\windows\x64\runner\Release\irc_app.exe

# 5. Crear instalador (opcional)
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

¡Eso es todo! 🎉
