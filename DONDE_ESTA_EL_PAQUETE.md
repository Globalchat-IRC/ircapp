# 📦 Dónde está el paquete después de compilar

## 🪟 Para Windows

### Después de ejecutar `build_installer.bat` o `build_installer.ps1`:

El instalador estará en:

```
irc_app/
└── installers/
    └── irc_app_setup_3.0.4_x64.exe  ← ESTE ES TU PAQUETE FINAL
```

**Ruta completa:**
```
C:\ruta\a\tu\proyecto\irc_app\installers\irc_app_setup_3.0.4_x64.exe
```

### Archivos intermedios (antes del instalador):

Después de `flutter build windows --release`, los archivos compilados estarán en:

```
irc_app/
└── build/
    └── windows/
        └── x64/
            └── runner/
                └── Release/
                    ├── irc_app.exe          ← Ejecutable principal
                    ├── flutter_windows.dll
                    ├── data/                ← Assets y recursos
                    └── ... (otras DLLs)
```

**Ruta completa:**
```
C:\ruta\a\tu\proyecto\irc_app\build\windows\x64\runner\Release\
```

## 📝 Pasos para compilar (en Windows):

1. Abre PowerShell o CMD en la carpeta del proyecto
2. Ejecuta: `.\build_installer.bat` (o `.\build_installer.ps1`)
3. Espera a que termine (puede tardar varios minutos)
4. El instalador estará en: `installers\irc_app_setup_3.0.4_x64.exe`

## ⚠️ Importante:

- **No puedes compilar para Windows desde macOS** - necesitas una máquina Windows
- El instalador `.exe` es todo lo que necesitas para distribuir
- Tamaño aproximado: 50-150 MB (depende de los assets)

## 🔍 Verificar que se creó:

Después de compilar, verifica que exista:

```batch
dir installers\*.exe
```

O en PowerShell:
```powershell
Get-ChildItem installers\*.exe
```
