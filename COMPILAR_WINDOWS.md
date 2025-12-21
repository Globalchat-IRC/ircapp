# Instrucciones para compilar IRC App para Windows

## Requisitos previos

1. **Windows 10 o superior**
2. **Flutter SDK** instalado en Windows
3. **Visual Studio 2022** (Community, Professional o Enterprise) con:
   - Carga de trabajo "Desarrollo para el escritorio con C++"
   - Componente "Windows 10/11 SDK"

## Pasos para compilar

### 1. Instalar Flutter en Windows

```bash
# Descargar Flutter desde https://docs.flutter.dev/get-started/install/windows
# Extraer a una carpeta (ej: C:\src\flutter)
# Añadir Flutter al PATH del sistema
```

### 2. Verificar instalación

```bash
flutter doctor
```

Asegúrate de que aparezca:
- ✓ Flutter
- ✓ Windows toolchain
- ✓ Visual Studio

### 3. Clonar o copiar el proyecto

Si tienes el proyecto en Git:
```bash
git clone <url-del-repositorio>
cd irc_app
```

O copia la carpeta completa del proyecto a Windows.

### 4. Obtener dependencias

```bash
flutter pub get
```

### 5. Compilar para Windows (Release)

```bash
flutter build windows --release
```

El ejecutable estará en: `build\windows\x64\runner\Release\irc_app.exe`

### 6. Crear un instalador (Opcional)

Para crear un instalador MSI o EXE, puedes usar herramientas como:
- **Inno Setup** (gratis): https://jrsoftware.org/isinfo.php
- **NSIS** (gratis): https://nsis.sourceforge.io/
- **WiX Toolset** (gratis): https://wixtoolset.org/

## Distribución

El ejecutable y todas las DLLs necesarias estarán en:
```
build\windows\x64\runner\Release\
```

Puedes:
1. **Comprimir la carpeta completa** en un ZIP para distribución
2. **Crear un instalador** usando las herramientas mencionadas arriba
3. **Distribuir solo el .exe** (pero necesitará las DLLs en la misma carpeta)

## Notas importantes

- El ejecutable necesita todas las DLLs en la misma carpeta
- La primera vez que alguien ejecute el .exe, Windows Defender puede mostrar una advertencia (es normal para aplicaciones no firmadas)
- Para distribuir sin advertencias, necesitarías un certificado de código firmado (costoso)

## Solución de problemas

Si encuentras errores de compilación:
1. Ejecuta `flutter clean`
2. Ejecuta `flutter pub get`
3. Ejecuta `flutter build windows --release` de nuevo

Si falta Visual Studio:
- Instala Visual Studio 2022 Community (gratis)
- Durante la instalación, selecciona "Desarrollo para el escritorio con C++"

