# Guía: Crear instalador Windows con Inno Setup

## 📦 Introducción

Inno Setup es una herramienta gratuita para crear instaladores profesionales de Windows. Esta guía te ayudará a crear un instalador para tu aplicación IRC.

## 1. Descargar e instalar Inno Setup

1. Descarga Inno Setup desde: https://jrsoftware.org/isdl.php
2. Descarga la versión **Unicode** (recomendado)
3. Ejecuta el instalador y sigue el asistente
4. **Opcional**: También puedes descargar **Inno Setup QuickStart Pack** que incluye el compilador de scripts

## 2. Compilar tu aplicación Flutter

Antes de crear el instalador, asegúrate de tener tu aplicación compilada:

```bash
cd irc_app
flutter build windows --release
```

Los archivos estarán en: `build\windows\x64\runner\Release\`

## 3. Crear el script de Inno Setup

### Opción A: Usar el asistente (recomendado para principiantes)

1. Abre **Inno Setup Compiler**
2. Ve a **File → New** → Selecciona **Create a new script file using the Script Wizard**
3. Sigue los pasos del asistente:
   - **Application Information**: Nombre, versión, empresa, URL
   - **Application Folder**: Dónde se instalará
   - **Application Files**: Selecciona todos los archivos de `build\windows\x64\runner\Release\`
   - **Application Icons**: Añade accesos directos
   - **Documentation**: README, licencia, etc.
   - **Setup Languages**: Idiomas del instalador
   - **Compiler Settings**: Nombre del instalador y opciones

### Opción B: Crear el script manualmente (más control)

Crea un archivo `installer.iss` en la raíz de tu proyecto:

```iss
; Script de Inno Setup para IRC App
; Este script crea un instalador profesional para Windows

#define MyAppName "IRC App"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Tu Nombre o Empresa"
#define MyAppURL "https://tu-sitio-web.com"
#define MyAppExeName "irc_app.exe"
#define MyAppAssocName MyAppName + " IRC Link"
#define MyAppAssocExt ".irc"
#define MyAppAssocKey StringChange(MyAppAssocName, " ", "") + MyAppAssocExt

[Setup]
; INFORMACIÓN BÁSICA
AppId={{GENERA-UN-GUID-UNICO-AQUI}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; RUTAS DE INSTALACIÓN
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; PERMISOS Y COMPATIBILIDAD
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; SALIDA DEL INSTALADOR
OutputDir=installers
OutputBaseFilename=irc_app_setup_{#MyAppVersion}
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes

; APARIENCIA
WizardStyle=modern
WizardImageFile=installer_assets\installer_image.bmp
WizardSmallImageFile=installer_assets\installer_small_image.bmp

; SOPORTE PARA WINDOWS
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64

; LICENCIA Y README (opcional)
LicenseFile=LICENSE
InfoBeforeFile=README.md

; DESINSTALADOR
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode
Name: "associatefiles"; Description: "Asociar archivos .irc con {#MyAppName}"; GroupDescription: "Asociaciones de archivos:"; Flags: unchecked

[Files]
; ARCHIVOS PRINCIPALES DE LA APLICACIÓN
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTA: No uses "Flags: ignoreversion" en archivos compartidos del sistema

; ARCHIVOS ADICIONALES (README, licencia, etc.)
Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme
Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; ICONO EN MENÚ INICIO
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; ICONO EN ESCRITORIO
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; ICONO EN BARRA DE TAREAS (Windows 7 y anterior)
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Registry]
; ASOCIACIÓN DE ARCHIVOS .IRC (opcional)
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocExt}\OpenWithProgids"; ValueType: string; ValueName: "{#MyAppAssocKey}"; ValueData: ""; Flags: uninsdeletevalue; Tasks: associatefiles
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}"; ValueType: string; ValueName: ""; ValueData: "{#MyAppAssocName}"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKA; Subkey: "Software\Classes\{#MyAppAssocKey}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles
Root: HKA; Subkey: "Software\Classes\Applications\{#MyAppExeName}\SupportedTypes"; ValueType: string; ValueName: ".irc"; ValueData: ""; Tasks: associatefiles

; PROTOCOLOS URL IRC:// (opcional)
Root: HKCR; Subkey: "irc"; ValueType: string; ValueName: ""; ValueData: "URL:IRC Protocol"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCR; Subkey: "irc"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: associatefiles
Root: HKCR; Subkey: "irc\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCR; Subkey: "irc\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

; IRCS:// (IRC con SSL)
Root: HKCR; Subkey: "ircs"; ValueType: string; ValueName: ""; ValueData: "URL:IRCS Protocol"; Flags: uninsdeletekey; Tasks: associatefiles
Root: HKCR; Subkey: "ircs"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: associatefiles
Root: HKCR; Subkey: "ircs\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#MyAppExeName},0"; Tasks: associatefiles
Root: HKCR; Subkey: "ircs\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#MyAppExeName}"" ""%1"""; Tasks: associatefiles

[Run]
; EJECUTAR LA APLICACIÓN AL FINALIZAR
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// CÓDIGO PASCAL SCRIPT (opcional)
// Puedes añadir lógica personalizada aquí

// Verificar si .NET está instalado (si tu app lo necesita)
function InitializeSetup(): Boolean;
begin
  Result := True;
  // Añade verificaciones personalizadas aquí
end;

// Después de la instalación
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Código a ejecutar después de instalar
  end;
end;

// Antes de desinstalar
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    // Preguntar si desea mantener configuración de usuario
    if MsgBox('¿Deseas conservar tus configuraciones y datos?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      // No eliminar carpeta de datos del usuario
    end;
  end;
end;
```

## 4. Generar un GUID único

Para la línea `AppId={{GENERA-UN-GUID-UNICO-AQUI}}`, necesitas un GUID único:

### En Windows PowerShell:
```powershell
[guid]::NewGuid().ToString().ToUpper()
```

### O usa esta herramienta online:
https://www.guidgenerator.com/

Ejemplo de GUID: `{12345678-1234-1234-1234-123456789ABC}`

## 5. Preparar imágenes para el instalador (opcional)

Crea una carpeta `installer_assets/` en la raíz del proyecto:

### Imágenes necesarias:

1. **installer_image.bmp**
   - Tamaño: 164 x 314 píxeles
   - Formato: BMP (24-bit)
   - Aparece en el lado izquierdo del instalador

2. **installer_small_image.bmp**
   - Tamaño: 55 x 58 píxeles
   - Formato: BMP (24-bit)
   - Aparece en la esquina superior del instalador

3. **app_icon.ico**
   - Ya debería estar en `windows\runner\resources\app_icon.ico`
   - Se usa como icono del instalador y de la aplicación

**Tip**: Puedes usar herramientas como GIMP, Photoshop o Paint.NET para crear estas imágenes.

## 6. Estructura de carpetas recomendada

```
irc_app/
├── build/
│   └── windows/
│       └── x64/
│           └── runner/
│               └── Release/          # ← Archivos compilados
├── installer_assets/
│   ├── installer_image.bmp
│   └── installer_small_image.bmp
├── installers/                        # ← Salida del instalador
│   └── irc_app_setup_1.0.0.exe       # ← Generado por Inno Setup
├── windows/
│   └── runner/
│       └── resources/
│           └── app_icon.ico
├── installer.iss                      # ← Script de Inno Setup
├── LICENSE
└── README.md
```

## 7. Compilar el instalador

### Método 1: Interfaz gráfica

1. Abre **Inno Setup Compiler**
2. Abre tu archivo `installer.iss`
3. Ve a **Build → Compile** (o presiona `Ctrl+F9`)
4. El instalador se creará en la carpeta `installers/`

### Método 2: Línea de comandos

```batch
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
```

O crea un script batch `build_installer.bat`:

```batch
@echo off
echo ========================================
echo Compilando aplicacion Flutter...
echo ========================================
call flutter build windows --release

echo.
echo ========================================
echo Creando instalador con Inno Setup...
echo ========================================
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss

echo.
echo ========================================
echo Instalador creado exitosamente!
echo ========================================
echo Ubicacion: installers\irc_app_setup_1.0.0.exe
pause
```

## 8. Personalización avanzada

### 8.1 Agregar páginas personalizadas

```pascal
[Code]
var
  CustomPage: TWizardPage;
  ServerEdit: TEdit;
  PortEdit: TEdit;

procedure InitializeWizard;
begin
  // Crear página personalizada para configuración inicial
  CustomPage := CreateInputQueryPage(wpSelectDir,
    'Configuración del Servidor IRC',
    'Configura tu servidor IRC predeterminado',
    'Por favor, ingresa la información de tu servidor IRC.');
  
  // Campo para servidor
  ServerEdit := CustomPage.Add('Servidor IRC:', False);
  ServerEdit.Text := 'irc.example.com';
  
  // Campo para puerto
  PortEdit := CustomPage.Add('Puerto:', False);
  PortEdit.Text := '6667';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ConfigFile: String;
begin
  if CurStep = ssPostInstall then
  begin
    // Guardar configuración en un archivo
    ConfigFile := ExpandConstant('{app}\config.ini');
    SaveStringToFile(ConfigFile, '[Server]' + #13#10, False);
    SaveStringToFile(ConfigFile, 'Host=' + ServerEdit.Text + #13#10, True);
    SaveStringToFile(ConfigFile, 'Port=' + PortEdit.Text + #13#10, True);
  end;
end;
```

### 8.2 Verificar requisitos del sistema

```pascal
[Code]
function InitializeSetup(): Boolean;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  
  // Verificar Windows 10 o superior
  if Version.Major < 10 then
  begin
    MsgBox('Este programa requiere Windows 10 o superior.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // Verificar espacio en disco (por ejemplo, 500 MB)
  if GetSpaceOnDisk(ExpandConstant('{app}'), False, nil, nil) < 500*1024*1024 then
  begin
    MsgBox('No hay suficiente espacio en disco. Se requieren al menos 500 MB.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  Result := True;
end;
```

### 8.3 Agregar dependencias (ej: Visual C++ Redistributable)

```iss
[Files]
; Incluir Visual C++ Redistributable si es necesario
Source: "redist\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
; Instalar VC++ Redistributable silenciosamente
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Instalando Visual C++ Redistributable..."; Flags: waituntilterminated
```

### 8.4 Crear instalador multilingüe avanzado

```iss
[CustomMessages]
spanish.WelcomeLabel=Bienvenido al instalador de {#MyAppName}
english.WelcomeLabel=Welcome to {#MyAppName} Setup
portuguese.WelcomeLabel=Bem-vindo ao instalador do {#MyAppName}

spanish.ServerConfig=Configuración del servidor
english.ServerConfig=Server configuration
portuguese.ServerConfig=Configuração do servidor
```

## 9. Firmar digitalmente el instalador (opcional pero recomendado)

Para que Windows no muestre advertencias de "Editor desconocido":

1. **Obtener un certificado de firma de código**
   - Compra uno en: DigiCert, Sectigo, GlobalSign, etc.
   - Costo aproximado: $100-$500 USD/año

2. **Firmar el instalador**

Añade al script `installer.iss`:

```iss
[Setup]
SignTool=signtool
SignedUninstaller=yes

[Code]
// Configurar la firma
```

O firma manualmente después de crear el instalador:

```batch
signtool sign /f "tu_certificado.pfx" /p "password" /t http://timestamp.digicert.com "installers\irc_app_setup_1.0.0.exe"
```

## 10. Probar el instalador

### Checklist de pruebas:

- [ ] Instalación limpia en Windows 10
- [ ] Instalación limpia en Windows 11
- [ ] Actualización sobre versión anterior
- [ ] Instalación en `C:\Program Files` (con permisos de admin)
- [ ] Instalación en carpeta de usuario (sin permisos de admin)
- [ ] Desinstalación completa
- [ ] Iconos en escritorio y menú inicio funcionan
- [ ] Asociaciones de archivos funcionan (si aplica)
- [ ] Protocolos URL funcionan (si aplica)
- [ ] La aplicación se ejecuta correctamente después de instalar
- [ ] No hay errores de DLLs faltantes
- [ ] Windows Defender no bloquea (falso positivo)

### Herramientas de prueba:

1. **Máquinas virtuales** (VMware, VirtualBox, Hyper-V)
2. **Windows Sandbox** (Windows 10 Pro/Enterprise)
3. **Diferentes versiones de Windows**

## 11. Distribución

Una vez creado el instalador:

### Opción 1: Subir a tu sitio web
```
https://tu-sitio.com/downloads/irc_app_setup_1.0.0.exe
```

### Opción 2: GitHub Releases
1. Ve a tu repositorio en GitHub
2. Releases → Create a new release
3. Sube el archivo `.exe`
4. Añade notas de la versión

### Opción 3: Microsoft Store (más complejo)
- Requiere certificado de desarrollador ($19 USD)
- Mejor integración con Windows 10/11
- Actualizaciones automáticas

### Opción 4: Chocolatey (gestor de paquetes)
- Popular entre usuarios técnicos
- Instalación vía: `choco install irc-app`

## 12. Actualizaciones automáticas (avanzado)

Para implementar actualizaciones automáticas en tu aplicación:

```pascal
[Code]
function CheckForUpdates(): Boolean;
var
  HttpClient: Variant;
  LatestVersion: String;
begin
  // Verificar última versión desde tu servidor
  // Comparar con versión actual
  // Descargar e instalar si hay nueva versión
end;
```

O usa herramientas como:
- **WinSparkle**: Framework de actualizaciones automáticas
- **Squirrel.Windows**: Sistema de actualización moderno
- **Omaha**: Sistema de Google Chrome

## 13. Consejos y mejores prácticas

### ✅ Hacer:
- Usar versionado semántico (1.0.0, 1.1.0, 2.0.0)
- Incluir README y LICENSE
- Probar en máquinas limpias
- Firmar digitalmente el instalador (si es posible)
- Usar nombres descriptivos para el instalador
- Incluir notas de la versión
- Ofrecer instalación portable además del instalador

### ❌ No hacer:
- Instalar en `C:\` directamente
- Modificar archivos del sistema sin motivo
- Instalar dependencias innecesarias
- Requerir reinicio a menos que sea absolutamente necesario
- Hacer el instalador muy grande (optimiza assets)
- Olvidar probar la desinstalación

## 14. Script completo de ejemplo (simplificado)

Para empezar rápido, aquí hay un script mínimo que funciona:

```iss
[Setup]
AppName=IRC App
AppVersion=1.0.0
DefaultDirName={autopf}\IRC App
OutputDir=installers
OutputBaseFilename=irc_app_setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{autoprograms}\IRC App"; Filename: "{app}\irc_app.exe"
Name: "{autodesktop}\IRC App"; Filename: "{app}\irc_app.exe"

[Run]
Filename: "{app}\irc_app.exe"; Description: "Ejecutar IRC App"; Flags: nowait postinstall skipifsilent
```

## 15. Recursos adicionales

- **Documentación oficial**: https://jrsoftware.org/ishelp/
- **Ejemplos de scripts**: `C:\Program Files (x86)\Inno Setup 6\Examples\`
- **Foro de Inno Setup**: https://groups.google.com/g/innosetup
- **Generador de scripts online**: https://www.innosetup-script-generator.com/

## 16. Alternativas a Inno Setup

Si necesitas más funcionalidades:

- **WiX Toolset** (gratis, basado en XML, más complejo)
- **Advanced Installer** (comercial, GUI moderna, muy potente)
- **InstallShield** (comercial, estándar de la industria)
- **NSIS** (gratis, scripting más complejo)

