#define MyAppName "IRC App"
#define MyAppVersion "3.0.7"
#define MyAppPublisher "Fran Naveira"
#define MyAppExeName "irc_app.exe"

[Setup]
AppId={{A7B8C9D0-E1F2-3456-7890-ABCDEF123456}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=installers
OutputBaseFilename=irc_app_setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
