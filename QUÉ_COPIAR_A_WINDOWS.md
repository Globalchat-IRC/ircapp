# 📋 Qué copiar a Windows para compilar

## ✅ ARCHIVOS ESENCIALES (SÍ copiar)

### 1. Archivos de configuración del proyecto
```
✓ pubspec.yaml          ← Configuración del proyecto y dependencias
✓ pubspec.lock          ← Versiones exactas de dependencias
✓ .gitignore            ← Archivos a ignorar
✓ analysis_options.yaml ← Configuración del linter
```

### 2. Código fuente
```
✓ lib/                  ← TODO EL CÓDIGO DE TU APP (carpeta completa)
```

### 3. Recursos y assets
```
✓ assets/               ← Imágenes, iconos, sonidos, etc. (carpeta completa)
```

### 4. Configuración de Windows
```
✓ windows/              ← Configuración específica de Windows (carpeta completa)
```

### 5. Scripts de compilación para Windows
```
✓ build_installer.bat   ← Script para compilar y crear instalador
✓ build_installer.ps1   ← Script PowerShell (alternativa)
✓ installer.iss         ← Script de Inno Setup para crear el instalador
```

### 6. Documentación (opcional pero útil)
```
✓ README.md
✓ GUIA_COMPILAR_WINDOWS.md
✓ COMPILAR_WINDOWS.md
```

## ❌ ARCHIVOS QUE NO NECESITAS (NO copiar)

### Carpetas de build (se generan al compilar)
```
✗ build/                ← Se genera al compilar, no es necesario
✗ build 2/              ← Carpeta de build antigua
✗ .dart_tool/           ← Se genera automáticamente
```

### Otras plataformas (no necesarias para Windows)
```
✗ android/              ← Solo para Android
✗ ios/                  ← Solo para iOS
✗ macos/                ← Solo para macOS
✗ linux/                ← Solo para Linux
```

### Scripts de otras plataformas
```
✗ *.sh                  ← Scripts de shell (solo Mac/Linux)
✗ build_ios.sh
✗ build_dmg.sh
✗ build_web_secure.sh
✗ copiar_*.sh
✗ deploy_*.sh
✗ diagnostico_*.sh
✗ verificar_*.sh
✗ configurar_*.sh
✗ limpiar_*.sh
✗ solucion_*.sh
✗ inicio_rapido.sh
✗ run.sh
```

### Archivos compilados y grandes
```
✗ *.apk                 ← Instalador de Android
✗ *.dmg                 ← Instalador de macOS
✗ *.exe                 ← Instaladores ya compilados
✗ installers/           ← Instaladores generados
✗ instalador_windows/   ← Archivos temporales
✗ releases/             ← Releases antiguos
```

### Archivos temporales y de desarrollo
```
✗ .DS_Store              ← Archivos del sistema Mac
✗ *.log                 ← Logs
✗ cuac_ircap.mp3        ← Archivos de prueba
✗ portafolio-globalchat.html
```

### Documentación excesiva (opcional)
```
✗ *.md                  ← Puedes copiar solo los esenciales
  (excepto README.md y GUIA_COMPILAR_WINDOWS.md)
```

## 📦 RESUMEN: Estructura mínima necesaria

```
irc_app/
├── lib/                    ← TODO (código fuente)
├── assets/                 ← TODO (recursos)
├── windows/                ← TODO (configuración Windows)
├── test/                   ← TODO (tests, opcional)
├── pubspec.yaml            ← ESENCIAL
├── pubspec.lock            ← ESENCIAL
├── .gitignore              ← Útil
├── analysis_options.yaml   ← Útil
├── build_installer.bat     ← ESENCIAL
├── build_installer.ps1     ← ESENCIAL
├── installer.iss           ← ESENCIAL
└── README.md               ← Útil
```

## 🚀 Método rápido: Crear carpeta limpia

### Opción 1: Copiar manualmente
1. Crea una carpeta nueva en Windows: `irc_app`
2. Copia SOLO estas carpetas y archivos:
   - `lib/`
   - `assets/`
   - `windows/`
   - `test/` (opcional)
   - `pubspec.yaml`
   - `pubspec.lock`
   - `build_installer.bat`
   - `build_installer.ps1`
   - `installer.iss`
   - `.gitignore`
   - `analysis_options.yaml`
   - `README.md`

### Opción 2: Usar Git (recomendado)
Si tienes el proyecto en Git:
```bash
# En Windows:
git clone <url-del-repositorio>
cd irc_app
flutter pub get
```

### Opción 3: Comprimir solo lo necesario
```bash
# En Mac, crea un ZIP con solo lo esencial:
cd /Users/fnaveira/mobile
zip -r irc_app_para_windows.zip irc_app/lib irc_app/assets irc_app/windows irc_app/test irc_app/pubspec.yaml irc_app/pubspec.lock irc_app/build_installer.bat irc_app/build_installer.ps1 irc_app/installer.iss irc_app/.gitignore irc_app/analysis_options.yaml irc_app/README.md
```

## ⚠️ IMPORTANTE

1. **NO necesitas la carpeta `build/`** - Se genera al compilar
2. **NO necesitas `.dart_tool/`** - Se genera automáticamente
3. **SÍ necesitas `pubspec.yaml` y `pubspec.lock`** - Son esenciales
4. **SÍ necesitas `lib/` completo** - Es todo tu código
5. **SÍ necesitas `assets/` completo** - Son tus recursos

## ✅ Después de copiar a Windows

1. Abre PowerShell en la carpeta del proyecto
2. Ejecuta: `flutter pub get` (para descargar dependencias)
3. Ejecuta: `.\build_installer.bat` (para compilar y crear instalador)
