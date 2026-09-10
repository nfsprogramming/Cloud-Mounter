[Setup]
AppId={{YOUR-APP-GUID}
AppName=Cloud Mounter
AppVersion=1.0.0
AppPublisher=nfsprogramming
DefaultDirName={autopf}\Cloud Mounter
DefaultGroupName=Cloud Mounter
OutputBaseFilename=CloudMounter_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
SetupIconFile=windows\runner\resources\app_icon.ico

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\cloudmounter.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Cloud Mounter"; Filename: "{app}\cloudmounter.exe"; IconFilename: "{app}\cloudmounter.exe"
Name: "{autodesktop}\Cloud Mounter"; Filename: "{app}\cloudmounter.exe"; Tasks: desktopicon; IconFilename: "{app}\cloudmounter.exe"

[Run]
Filename: "{app}\cloudmounter.exe"; Description: "{cm:LaunchProgram,Cloud Mounter}"; Flags: nowait postinstall skipifsilent
