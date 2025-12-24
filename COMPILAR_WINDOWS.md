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

### 2. Verificar instalación (Opcional)

```bash
flutter doctor
```

**NOTA:** Si `flutter doctor` da error de TLS, no te preocupes. Puedes saltar este paso y continuar directamente a compilar. El error de TLS no impide la compilación.

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

**Si da error de TLS aquí también:**
```bash
# Opción 1: Configurar SSL
git config --global http.sslBackend schannel
inno
# Opción 2: Si falla, deshabilitar SSL temporalmente
set PUB_HOSTED_URL=http://pub.dartlang.org
set FLUTTER_STORAGE_BASE_URL=http://storage.flutter-io.cn
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

### Error de TLS al ejecutar flutter doctor

Si ves el error: `Got TLS error trying to find package coverage at https://pub.dev`

**Solución 1: Configurar Git para usar certificados de Windows**
```bash
git config --global http.sslBackend schannel
```

**Solución 2: Deshabilitar verificación SSL temporalmente (solo para testing)**
```bash
git config --global http.sslVerify false
flutter doctor
# Después de que funcione, vuelve a habilitar:
git config --global http.sslVerify true
```

**Solución 3: Actualizar certificados de Windows**
1. Abre PowerShell como Administrador
2. Ejecuta:
```powershell
certutil -generateSSTFromWU roots.sst
```
3. Reinicia y vuelve a intentar `flutter doctor`

**Solución 4: Configurar proxy (si estás detrás de un firewall corporativo)**
```bash
set HTTP_PROXY=http://tu-proxy:puerto
set HTTPS_PROXY=http://tu-proxy:puerto
flutter doctor
```

**Solución 5: Usar una VPN o cambiar de red**
A veces el problema es con la red. Prueba conectarte a una red diferente o usar tu hotspot móvil.

### Errores de compilación

Si encuentras errores de compilación:
1. Ejecuta `flutter clean`
2. Ejecuta `flutter pub get`
3. Ejecuta `flutter build windows --release` de nuevo

### Si falta Visual Studio:
- Instala Visual Studio 2022 Community (gratis)
- Durante la instalación, selecciona "Desarrollo para el escritorio con C++"

