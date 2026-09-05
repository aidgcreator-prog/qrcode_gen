; Inno Setup script for QR Code Generator (self-contained single-file build)
; 1. Build the app first:   pyinstaller --noconfirm build.spec
; 2. Build the installer:   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss

#define MyAppName "QR Code Generator"
#define MyAppVersion "0.5.1"
#define MyAppPublisher "LocalAiLab"
#define MyAppExe "QRCodeGenerator.exe"

[Setup]
AppId={{A8F63C9D-2E4B-4F1A-9C7E-5D0B6A1E8F42}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=installer\Output
OutputBaseFilename=QR-Code-Generator-Setup-{#MyAppVersion}
SetupIconFile=image\logo.ico
UninstallDisplayIcon={app}\logo.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

; Clean up leftovers from the older .venv-based and folder-based packaging
[InstallDelete]
Type: filesandordirs; Name: "{app}\.venv"
Type: filesandordirs; Name: "{app}\_internal"
Type: files; Name: "{app}\app_launcher.py"

[Files]
Source: "dist\QRCodeGenerator.exe"; DestDir: "{app}"
Source: "image\logo.ico"; DestDir: "{app}"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; IconFilename: "{app}\logo.ico"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"; IconFilename: "{app}\logo.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; IconFilename: "{app}\logo.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
