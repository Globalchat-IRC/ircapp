; Script de Inno Setup para IRC App
; Generado para crear un instalador profesional de Windows
; Autor: Fran Naveira
; Última actualización: Diciembre 2025

#define MyAppName "IRC App"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Fran Naveira"
#define MyAppURL "https://github.com/fnaveira/irc_app"
#define MyAppExeName "irc_app.exe"

[Setup]
; INFORMACIÓN DE LA APLICACIÓN
; IMPORTANTE: Genera un GUID único en https://www.guidgenerator.com/ y reemplázalo aquí
AppId={{A7B8C9D0-E1F2-3456-7890-ABCDEF123456}}
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

; PERMISOS (lowest = no requiere admin para instalar en carpeta de usuario)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; SALIDA DEL INSTALADOR
OutputDir=installers
OutputBaseFilename=irc_app_setup_{#MyAppVersion}_x64
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes

; APARIENCIA MODERNA
WizardStyle=modern
; Si tienes imágenes personalizadas, descomenta estas líneas:
; WizardImageFile=installer_assets\installer_image.bmp
; WizardSmallImageFile=installer_assets\installer_small_image.bmp

; REQUISITOS DEL SISTEMA
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

; ARCHIVOS DE INFORMACIÓN (opcional - comenta si no los tienes)
; LicenseFile=LICENSE
; InfoBeforeFile=README.md

; DESINSTALADOR
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; ARCHIVOS PRINCIPALES DE LA APLICACIÓN
; Todos los archivos de la carpeta Release
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; ARCHIVOS ADICIONALES (descomenta si los tienes)
; Source: "README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme
; Source: "LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; ICONO EN MENÚ INICIO
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; ICONO EN ESCRITORIO (opcional)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; EJECUTAR LA APLICACIÓN AL FINALIZAR LA INSTALACIÓN
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// FUNCIONES PERSONALIZADAS EN PASCAL SCRIPT

// Verificar requisitos antes de instalar
function InitializeSetup(): Boolean;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  
  // Verificar que sea Windows 10 o superior
  if Version.Major < 10 then
  begin
    MsgBox('Este programa requiere Windows 10 o superior.' + #13#10 + 
           'Tu versión de Windows no es compatible.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  Result := True;
end;

// Mensaje de bienvenida personalizado
procedure InitializeWizard();
begin
  WizardForm.WelcomeLabel1.Caption := 'Bienvenido al Instalador de ' + '{#MyAppName}';
  WizardForm.WelcomeLabel2.Caption := 
    'Este asistente instalará {#MyAppName} versión {#MyAppVersion} en tu computadora.' + #13#10 + #13#10 +
    '{#MyAppName} es un cliente IRC moderno desarrollado con Flutter.' + #13#10 + #13#10 +
    'Haz clic en Siguiente para continuar.';
end;

// Después de completar la instalación
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Aquí puedes añadir código para ejecutar después de instalar
    // Por ejemplo: crear archivos de configuración predeterminados
  end;
end;

// Antes de desinstalar
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Response: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    Response := MsgBox(
      '¿Deseas conservar tus configuraciones y datos de usuario?' + #13#10 + #13#10 +
      'Si haces clic en "Sí", tus servidores guardados, configuración y logs se mantendrán.' + #13#10 +
      'Si haces clic en "No", todo será eliminado.', 
      mbConfirmation, MB_YESNO);
    
    if Response = IDNO then
    begin
      // Aquí puedes añadir código para eliminar datos de usuario
      // Por ejemplo: archivos en AppData
    end;
  end;
end;

// Mostrar mensaje al finalizar
procedure DeinitializeSetup();
begin
  // Código a ejecutar al cerrar el instalador
end;

