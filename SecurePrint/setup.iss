[Setup]
AppName=SecurePrint Shop
AppVersion=1.0.0
DefaultDirName=C:\Users\sansk\SecurePrintShopInstall
DefaultGroupName=SecurePrint Shop
UninstallDisplayIcon={app}\SecurePrint-Shop.exe
Compression=lzma2
SolidCompression=yes
OutputDir=C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\installers
OutputBaseFilename=SecurePrint-Shop-Setup
PrivilegesRequired=lowest

[Files]
Source: "C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SecurePrint Shop"; Filename: "{app}\SecurePrint-Shop.exe"
Name: "{autodesktop}\SecurePrint Shop"; Filename: "{app}\SecurePrint-Shop.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked
