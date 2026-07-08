# GlobalChat - Build Windows

## Requisitos (PC o VM Windows)

1. **Flutter** estable (canal stable): https://docs.flutter.dev/get-started/install/windows
2. **Visual Studio 2022** con workload **Desktop development with C++**
3. **Git**
4. **Inno Setup 6** (instalador `.exe`): https://jrsoftware.org/isinfo.php

Comprobar entorno:

```powershell
flutter doctor -v
```

Debe aparecer `[√] Visual Studio` y `[√] Windows Version`.

## Obtener el codigo

```powershell
git clone <url-del-repo> irc_app
cd irc_app
flutter pub get
```

## Compilar la app

```powershell
flutter build windows --release
```

Salida:

```text
build\windows\x64\runner\Release\GlobalChat.exe
```

La carpeta `Release` completa es necesaria (DLLs, `data\`, etc.). No copies solo el `.exe`.

## Probar sin instalar

```powershell
.\build\windows\x64\runner\Release\GlobalChat.exe
```

## Crear instalador `.exe`

Opcion A - script automatico:

```powershell
.\installer\windows\build.ps1
```

Opcion B - manual:

```powershell
flutter build windows --release
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\windows\GlobalChat.iss
```

Instalador generado:

```text
build\windows\installer\GlobalChat-Setup-5.0.50.exe
```

## Validacion

- Instalar en un usuario limpio o otra VM
- Probar login, chat, radio, imagenes, historial y ajustes
- Si Windows Firewall pregunta, permitir conexiones salientes (IRC)
- La UI debe ser de **escritorio** (columnas laterales), no la version movil

## Notas

- El build Windows **no se puede hacer desde macOS**; usa PC/VM Windows
- Actualiza la version en `pubspec.yaml` y en `installer/windows/GlobalChat.iss` antes de publicar
- Ejecutable y metadatos: `GlobalChat` / `GlobalChat.exe`
- Icono Windows: `windows/runner/resources/app_icon.ico` (generado desde `macos/.../app_icon_1024.png`)
