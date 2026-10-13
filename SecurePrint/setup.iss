[Setup]
AppId={{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}}
AppName=SecurePrint Shop
AppVersion=1.0.0
DefaultDirName={localappdata}\Programs\SecurePrint Shop
DefaultGroupName=SecurePrint Shop
UninstallDisplayIcon={app}\SecurePrint-Shop.exe
Compression=lzma2
SolidCompression=yes
OutputDir=installers
OutputBaseFilename=SecurePrint-Shop-Setup
PrivilegesRequired=lowest

[Files]
Source: "shop_desktop\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SecurePrint Shop"; Filename: "{app}\SecurePrint-Shop.exe"
Name: "{autodesktop}\SecurePrint Shop"; Filename: "{app}\SecurePrint-Shop.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked
