# SecurePrint Windows Release Package Verification Report

**Date:** 2026-10-13  
**Status:** Verification Complete (Packaging Deficiencies & Stale Binaries Identified)  
**Scope:** Windows Shop Desktop release packaging configuration (`setup.iss`), existing installer artifact (`SecurePrint-Shop-Setup.exe`), runtime dependency bundling, data isolation, and release documentation.

---

## 1. Executive Summary

This audit evaluated the Windows release packaging configuration and existing installer for the SecurePrint Shop desktop application.

**Key Findings:**
1. **Packaging Isolation is Secure:** The installer configuration packages **only** the Flutter client runtime (`shop_desktop\build\windows\x64\runner\Release\*`). It does **not** bundle the authoritative backend database (`secureprint.db`), customer documents (`uploads/`), environment secrets (`.env`), or local test accounts.
2. **Uninstaller Safety Confirmed:** The Inno Setup uninstaller targets only `{app}` files created during installation. It does not touch or delete backend data, customer files, or `%APPDATA%` local accounts.
3. **Existing Installer Artifact is Stale (Blocker):** The installer executable currently located at `installers\SecurePrint-Shop-Setup.exe` is dated **September 24, 2026**, predating all October bugfixes (including backend connection defaults, PDF page-range extraction, and native Win32 duplex/color method channels).
4. **Release Build Directory is Stale (Blocker):** The `setup.iss` script draws files from `shop_desktop\build\windows\x64\runner\Release\*`. That folder is dated **October 11, 2026**, predating the latest native Win32 method channel and page-range engine (which were compiled and verified today in the `Debug` build output). A fresh `flutter build windows --release` is required before recompiling the installer.
5. **Installer Script Configuration Defects:** `setup.iss` contains hardcoded user-specific paths (`C:\Users\sansk\SecurePrintShopInstall` and absolute OneDrive paths) and lacks a standard GUID `AppId`.
6. **Documentation Gaps:** Existing release guides (`WINDOWS_RELEASE.md` and `SHOP_DESKTOP_SETUP.md`) do not explain that the FastAPI backend must be running, nor do they clarify that `127.0.0.1` is valid only when running the backend on the same PC.

---

## 2. Existing Installer & Packaging Configuration

### A. Artifact Locations
- **Installer Executable:**  
  `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\installers\SecurePrint-Shop-Setup.exe`
  - File Size: `14,645,197` bytes (~14.6 MB)
  - Last Modified: `2026-09-24 22:27:27`
- **Packaging Script:**  
  `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\setup.iss`
  - File Size: `874` bytes (22 lines)
  - Script Format: Inno Setup 6 Script
- **Inno Setup Compiler:**  
  `C:\Users\sansk\AppData\Local\Programs\Inno Setup 6\iscc.exe` (Installed and operational)

### B. Current Script Content (`setup.iss`)
```iss
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
```

---

## 3. Bundled Files & Dependency Analysis

### A. What the Installer Includes
When compiled against `shop_desktop\build\windows\x64\runner\Release\*`, the installer packages:
- `SecurePrint-Shop.exe` (Main desktop binary)
- `flutter_windows.dll` (Flutter Engine)
- `WebView2Loader.dll` (Microsoft Edge WebView2 loader)
- `dartjni.dll` (Dart JNI runtime)
- `pdfium.dll` (PDF rendering engine)
- Native Plugin DLLs:
  - `flutter_secure_storage_windows_plugin.dll`
  - `permission_handler_windows_plugin.dll`
  - `printing_plugin.dll`
  - `syncfusion_pdfviewer_windows_plugin.dll`
  - `url_launcher_windows_plugin.dll`
  - `webview_windows_plugin.dll`
- `data/` Directory (Flutter asset bundle, ICU data, fonts, compiled application kernel `app.so`)

### B. Timestamp & Stale Binary Analysis
| Component | Location | Timestamp | Status |
|---|---|---|---|
| **Existing Installer** | `installers\SecurePrint-Shop-Setup.exe` | 2026-09-24 22:27 | **STALE** (Predates all fixes) |
| **Release Folder Binary** | `build\windows\x64\runner\Release\SecurePrint-Shop.exe` | 2026-10-11 23:12 | **STALE** (Predates page-range & Win32 duplex/color fix) |
| **Debug Folder Binary (Current)** | `build\windows\x64\runner\Debug\SecurePrint-Shop.exe` | 2026-10-13 21:14 | **UP-TO-DATE** (Passed launch smoke test) |

The existing installer and the `Release\` folder binary do **not** reflect the current codebase.

---

## 4. Data Isolation & Security Verification

### A. Authoritative Database & Uploads
- The `[Files]` section of `setup.iss` specifies exclusively:
  `Source: "...\shop_desktop\build\windows\x64\runner\Release\*"`
- The installer does **not** include:
  - `backend/` source tree
  - Authoritative database (`backend/secureprint.db`)
  - Customer uploaded documents (`backend/uploads/`)
  - Server secrets or configuration (`backend/.env`)
  - Local test accounts or development credentials
- **Verdict:** Data isolation is verified. No sensitive backend or customer files are distributed with the client.

### B. Uninstaller Behavior
- Inno Setup records an installation log (`unins000.dat`) and removes only the files placed into `{app}`.
- Because `{app}` is isolated from the backend (`backend/` and `secureprint.db`), running the uninstaller will remove only the client binaries and plugins.
- It will **not** delete or corrupt the database, uploaded documents, or user data.

---

## 5. Packaging Defects & Proposed Safe Fixes

### Defect 1: Hardcoded Single-User Install Path
- **Issue:** `DefaultDirName=C:\Users\sansk\SecurePrintShopInstall` forces installation into a hardcoded path belonging to user `sansk`. On any other machine or user profile, this fails or creates an irregular directory.
- **Proposed Fix:** Use standard Inno Setup path constants:
  - For per-user install (`PrivilegesRequired=lowest`):  
    `DefaultDirName={localappdata}\Programs\SecurePrint Shop`
  - For system-wide install (`PrivilegesRequired=admin`):  
    `DefaultDirName={autopf}\SecurePrint Shop`

### Defect 2: Hardcoded Absolute Developer Paths
- **Issue:** `Source: "C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop\build\windows\x64\runner\Release\*"` and `OutputDir=C:\Users\sansk\OneDrive\Desktop\...` break on any machine where the repository path differs.
- **Proposed Fix:** Use relative paths anchored to the repository root:
  - `Source: "shop_desktop\build\windows\x64\runner\Release\*"`
  - `OutputDir=installers`

### Defect 3: Missing `AppId`
- **Issue:** `setup.iss` does not define an `AppId`. Without a unique GUID `AppId`, Inno Setup cannot safely detect existing installations or handle in-place upgrades.
- **Proposed Fix:** Add a dedicated GUID:
  `AppId={{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}}`

### Defect 4: Stale Binaries in `Release\` and `installers\`
- **Issue:** The installer executable has not been rebuilt with the latest code.
- **Proposed Fix:**
  1. In `shop_desktop`: execute `flutter build windows --release`.
  2. Compile the updated `setup.iss` with `iscc.exe`:
     ```powershell
     & "$env:LOCALAPPDATA\Programs\Inno Setup 6\iscc.exe" setup.iss
     ```

---

## 6. Backend Configuration & Setup Documentation Gaps

### A. Current Documentation Flaws
- In `WINDOWS_RELEASE.md` (lines 45-47), the guide claims the app ships targeting `https://api.secureprint.com`. This is obsolete; the application was updated to default to `http://127.0.0.1:8000` (FastAPI backend).
- In `SHOP_DESKTOP_SETUP.md` (line 12), Local Development Mode is described as "(Default)". This is obsolete; the application now defaults to `Production Backend Mode`.
- Neither document explains that:
  1. The **FastAPI backend must be actively running** for shop desktop operations.
  2. `127.0.0.1` (localhost) is appropriate **only when the backend runs on the exact same PC** as the desktop application.
  3. If the shop operates in a multi-PC environment (e.g. backend running on a main store counter PC or dedicated server), the desktop application's Backend URL must be configured to the host's LAN IP (e.g. `http://192.168.1.50:8000`) or public domain.

### B. Recommended Documentation Addition for `WINDOWS_RELEASE.md`
```markdown
## Backend Server Prerequisites
The SecurePrint Shop desktop application requires an active connection to the SecurePrint FastAPI backend service.

1. **Local Single-PC Deployment (Default)**:
   - If the backend runs on the same PC as the shop software:
   - Ensure the backend service is started:
     `uvicorn app.main:app --host 127.0.0.1 --port 8000`
   - The desktop app defaults to `http://127.0.0.1:8000` and connects automatically.

2. **LAN / Multi-PC Deployment**:
   - If the backend runs on a separate PC or dedicated store server:
   - Start the backend listening on all interfaces:
     `uvicorn app.main:app --host 0.0.0.0 --port 8000`
   - On the shop client desktop, open the login screen and click the Settings icon.
   - Set the Backend URL to the server's LAN address (e.g., `http://192.168.1.100:8000`).
   - Click "Test Connection" to confirm network reachability before signing in.
   - Note: `127.0.0.1` refers to the local machine and will NOT connect to a backend running on a different computer.
```

---

## 7. Remaining Release Blockers Summary

| Blocker | Description | Resolution Path |
|---|---|---|
| **Stale Installer Artifact** | `SecurePrint-Shop-Setup.exe` is from 2026-09-24 and lacks October fixes. | Rebuild release binary (`flutter build windows --release`) and recompile Inno Setup script. |
| **Hardcoded Paths in `setup.iss`** | Hardcodes user `sansk` specific directories and absolute paths. | Update `setup.iss` with relative source paths and `{localappdata}` / `{autopf}` destination. |
| **Documentation Inaccuracy** | Guides do not mention FastAPI runtime requirement or `127.0.0.1` network boundaries. | Update `WINDOWS_RELEASE.md` and `SHOP_DESKTOP_SETUP.md` with accurate connection instructions. |
| **Code Signing Certificate** | Windows SmartScreen warns "Unknown Publisher" on unsigned EXEs. | Apply an Authenticode code-signing certificate (commercial release requirement). |
| **Hardware-Dependent Checks** | Physical printer duplex/color output and physical Android USB device connection. | Perform when hardware/devices are available. |
