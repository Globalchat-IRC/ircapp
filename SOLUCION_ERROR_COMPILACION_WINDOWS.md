# 🔧 Solución: Error MSB8066 al Compilar en Windows

## 🔍 Error

```
error MSB8066: Custom build for '...flutter_windows.dll.rule...' exited with code 1.
```

## ✅ Soluciones (en orden)

### Solución 1: Limpiar completamente y recompilar

```batch
# Limpiar todo
flutter clean
cd windows
if exist CMakeFiles rmdir /s /q CMakeFiles
if exist CMakeCache.txt del CMakeCache.txt
cd ..

# Limpiar build
if exist build\windows rmdir /s /q build\windows

# Recompilar
flutter pub get
flutter build windows --release
```

### Solución 2: Verificar Visual Studio

Asegúrate de que Visual Studio 2022 tenga instalado:
- **C++ CMake tools for Windows**
- **Windows 10/11 SDK**
- **Desktop development with C++**

### Solución 3: Reinstalar dependencias de Flutter

```batch
flutter doctor -v
flutter pub cache repair
flutter clean
flutter pub get
flutter build windows --release
```

### Solución 4: Compilar sin release primero

```batch
flutter clean
flutter build windows
```

Si funciona, luego intenta release:
```batch
flutter build windows --release
```

### Solución 5: Usar Visual Studio directamente

1. Abre Visual Studio 2022
2. Abre la carpeta: `C:\src\irc_app\windows`
3. Selecciona "Release" y "x64"
4. Build → Build Solution

### Solución 6: Verificar permisos

Asegúrate de tener permisos de escritura en:
- `C:\src\irc_app\build\`
- `C:\src\irc_app\windows\`

### Solución 7: Verificar espacio en disco

Asegúrate de tener al menos 5 GB libres en el disco.

## 🚀 Script de Limpieza Completa

Crea un archivo `limpiar_y_compilar.bat`:

```batch
@echo off
echo Limpiando proyecto...

flutter clean
if exist build rmdir /s /q build
if exist windows\CMakeFiles rmdir /s /q windows\CMakeFiles
if exist windows\CMakeCache.txt del windows\CMakeCache.txt

echo Obteniendo dependencias...
flutter pub get

echo Compilando...
flutter build windows --release

pause
```

## 📝 Verificar Instalación

Ejecuta:
```batch
flutter doctor -v
```

Debe mostrar:
- ✅ Flutter
- ✅ Windows toolchain
- ✅ Visual Studio

Si falta algo, instálalo.
