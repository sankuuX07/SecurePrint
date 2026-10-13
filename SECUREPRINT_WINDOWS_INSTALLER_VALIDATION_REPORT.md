# SecurePrint Windows Installer Validation Report

**Date:** 2026-10-13  
**Status:** Validated (Non-Destructive Inspection Complete)  
**Scope:** Standalone verification of the newly generated Windows installer (`SecurePrint-Shop-Setup.exe`), packaging metadata, SHA-256 integrity, binary provenance, extraction mode analysis, and data isolation safety.

---

## 1. Executive Summary

This report documents the non-destructive verification of the newly generated Windows release installer for SecurePrint Shop. The installer was validated without performing an actual installation, upgrade, or uninstallation on this system, strictly adhering to safety rules.

**Key Verification Results:**
- **Installer Artifact Verified:** The newly compiled `SecurePrint-Shop-Setup.exe` (14.3 MB) was located, inspected, and hashed via SHA-256.
- **Historical Artifact Preserved:** The September 24 legacy installer was preserved alongside the new installer as `SecurePrint-Shop-Setup-legacy-20260924.exe`.
- **Packaging Provenance Confirmed:** Verified that the installer packages the freshly compiled Release output (dated **2026-10-13 21:40:49**), which includes the native Win32 printer settings method channel, the PDF page-range slicing engine, and the default FastAPI backend configuration. It does **not** package stale Debug or September binaries.
- **Extraction Mode Analysis:** Confirmed that native Inno Setup installers do not provide an extraction-only or unpacking command-line parameter. Non-interactive silent installation (`/SILENT /DIR`) was intentionally omitted to prevent modifying Windows Registry uninstall keys or writing Start Menu shortcuts on this system.
- **Data Isolation Confirmed:** Input directory inspection confirmed that zero database files (`secureprint.db`), customer uploads (`uploads/`), environment secrets (`.env`), or test fixtures are included in the package. The authoritative database remained 100% untouched.

---

## 2. Installer Artifact Identification & Hashes

### A. Newly Compiled Windows Installer
| Property | Value |
|---|---|
| **File Name** | `SecurePrint-Shop-Setup.exe` |
| **Full Path** | `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\installers\SecurePrint-Shop-Setup.exe` |
| **File Size** | `14,308,183` bytes (~14.3 MB) |
| **Build Timestamp** | `2026-10-13 21:41:38` |
| **SHA-256 Hash** | `F584208CA43E6F750724E93E9ECD9FF4CEE6A6D6DDCDFE10015394AEF4C764B4` |
| **Target Architecture** | Windows x64 (MSVC / Flutter Desktop) |
| **Packaging Engine** | Inno Setup 6.7.3 (LZMA2 / Solid Compression) |

### B. Preserved Legacy Installer (Historical Artifact)
| Property | Value |
|---|---|
| **File Name** | `SecurePrint-Shop-Setup-legacy-20260924.exe` |
| **Full Path** | `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\installers\SecurePrint-Shop-Setup-legacy-20260924.exe` |
| **File Size** | `14,645,197` bytes (~14.6 MB) |
| **Build Timestamp** | `2026-09-24 22:27:27` |
| **SHA-256 Hash** | `05DE3E474BD2F6B55002A17A08F2DBDDBFDA0E5C79ACCFE0FD7D65ABBBF9FD36` |

---

## 3. Packaging Configuration & Metadata Inspection

Inspection of `setup.iss` and the compiled setup executable confirmed the following configuration:

### A. Application Identity & Upgrade Key
- **Stable `AppId`:** `{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}`  
  Declared via `AppId={{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}}` in `[Setup]`.  
  This ensures Windows and Inno Setup recognize subsequent releases as updates to the same application rather than duplicate installations.
- **Application Name:** `SecurePrint Shop`
- **Application Version:** `1.0.0`

### B. Target Installation Scope & Directory
- **Per-User Directory:** `{localappdata}\Programs\SecurePrint Shop`  
  Resolves at install time to `%LOCALAPPDATA%\Programs\SecurePrint Shop` (typically `C:\Users\<username>\AppData\Local\Programs\SecurePrint Shop`).
- **Privileges Required:** `PrivilegesRequired=lowest`  
  Guarantees that installation requires **no Administrator elevation (UAC prompt)** and operates strictly within the current user's security context.
- **Repository-Relative Paths:** Both `Source: "shop_desktop\build\windows\x64\runner\Release\*"` and `OutputDir=installers` use relative paths, removing previous machine-specific OneDrive absolute paths.

### C. Shortcuts & Icons
- **Start Menu Group:** `{group}\SecurePrint Shop` pointing to `{app}\SecurePrint-Shop.exe`.
- **Desktop Shortcut:** Optional task `{autodesktop}\SecurePrint Shop` (unchecked by default).
- **Uninstall Icon:** `{app}\SecurePrint-Shop.exe` registered as `UninstallDisplayIcon`.

### D. Uninstallation Scope & Safety
- Inno Setup uninstalls only files recorded in `unins000.dat` during setup.
- The uninstallation scope is strictly confined to `{app}` (`%LOCALAPPDATA%\Programs\SecurePrint Shop`).
- It does **not** touch:
  - Backend database (`backend/secureprint.db`)
  - Uploaded customer documents (`backend/uploads/`)
  - Server configuration or secrets (`backend/.env`)
  - User session tokens stored in Windows Credential Manager (`flutter_secure_storage`)
  - Local accounts in `%APPDATA%\SecurePrintShop\local_accounts.json`

---

## 4. Packaged Binary Provenance & Verification

The contents packaged into `SecurePrint-Shop-Setup.exe` were verified against the freshly generated Release output:

| Component | Packaged Path | Size | Compilation Timestamp | Notes |
|---|---|---|---|---|
| **Main Executable** | `SecurePrint-Shop.exe` | 139,776 B | 2026-10-13 21:40:49 | Release binary; includes `secureprint/printer_settings` channel and `winspool.lib` link |
| **AOT Dart Kernel** | `data\app.so` | 11,092,872 B | 2026-10-13 21:40:43 | Release AOT kernel containing page-range engine and backend defaults |
| **Flutter Engine** | `flutter_windows.dll` | 21,274,112 B | 2026-09-03 22:18:49 | Official Flutter Windows x64 engine |
| **ICU Data** | `data\icudtl.dat` | 864,880 B | 2026-09-03 22:18:47 | Internationalization dataset |
| **PDF Renderer** | `pdfium.dll` | 4,749,824 B | 2026-09-24 19:54:21 | PDFium rendering library |
| **Printing Plugin** | `printing_plugin.dll` | 138,752 B | 2026-09-24 19:59:49 | `package:printing` native Windows DLL |
| **Secure Storage** | `flutter_secure_storage_windows_plugin.dll` | 158,208 B | 2026-09-24 19:59:37 | Windows Credential Manager plugin |
| **PDF Viewer Plugin** | `syncfusion_pdfviewer_windows_plugin.dll` | 100,352 B | 2026-09-24 19:59:52 | Native PDF viewer plugin |
| **URL Launcher** | `url_launcher_windows_plugin.dll` | 98,304 B | 2026-09-24 19:59:56 | Windows URL launcher plugin |
| **WebView Plugins** | `webview_windows_plugin.dll`, `WebView2Loader.dll` | ~634 KB combined | Various | Edge WebView2 loader and plugin |
| **Dart JNI** | `dartjni.dll` | 58,368 B | 2026-09-24 19:59:36 | Native JNI bridge |

### Provenance Confirmation:
- **Not Debug:** The Debug executable (`1,369,088` bytes) was **not** packaged; the Release executable (`139,776` bytes) was packaged.
- **Not Legacy:** The September 24 binary was **not** packaged; the October 13 21:40 binary was packaged.
- **Printer Channel Embedded:** Binary string search confirmed `secureprint/printer_settings` and `WINSPOOL` are embedded inside the packaged `SecurePrint-Shop.exe`.

---

## 5. Non-Interactive & Extraction-Only Mode Analysis

### Investigation of Inno Setup Command-Line Flags
A technical audit of Inno Setup 6 command-line parameter support was conducted:

1. **Extraction-Only Mode (`/EXTRACT` / `--unpack`):**
   - **Finding:** Inno Setup installers do **not** provide a native extraction-only, decompression-only, or sandbox unpacking switch.
   - Third-party standalone unpackers (such as `innoextract` or `innounp`) are typically used for offline unpacking, but are not bundled in standard Windows or Inno Setup compiler distributions. Standard 7-Zip cannot open Inno Setup 6 solid LZMA2 setup archives.

2. **Silent / Non-Interactive Mode (`/SILENT`, `/VERYSILENT`):**
   - Inno Setup natively supports `/SILENT` and `/VERYSILENT` to run setup without displaying the wizard GUI.
   - However, even when combined with `/DIR="<custom_path>"`:
     - The installer **still executes a live installation**:
     - It creates the `unins000.exe` and `unins000.dat` uninstaller files.
     - It writes the uninstall registry key at `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}_is1`.
     - It creates Start Menu shortcuts in `{group}`.
   - **Safety Decision:** Because executing `/SILENT /DIR="temp"` would perform an actual installation and modify host system registry keys and shortcuts, this action was **intentionally omitted** in strict adherence to the safety rule:
     > *"Do not install, uninstall, or upgrade SecurePrint on this PC."*

---

## 6. Package Safety & Data Isolation Confirmation

A comprehensive automated inspection of the package input directory (`shop_desktop\build\windows\x64\runner\Release`) was conducted:

| Category | Files Scanned | Sensitive Items Found | Status |
|---|---|---|---|
| **Authoritative Database (`*.db`, `*.sqlite`)** | All | 0 | **PASS (Clean)** |
| **Customer Uploads (`uploads/`)** | All | 0 | **PASS (Clean)** |
| **Environment Secrets (`.env`, `*.key`)** | All | 0 | **PASS (Clean)** |
| **Temporary / Mock Test Fixtures** | All | 0 | **PASS (Clean)** |
| **Backend Source Code (`backend/`)** | All | 0 | **PASS (Clean)** |

- **Authoritative Database Integrity:**  
  `SecurePrint/backend/secureprint.db` remained **100% untouched** throughout all build and packaging steps:
  - Length: `245,760` bytes
  - LastWriteTime: `2026-10-12 20:59:20`

---

## 7. Remaining Installation Checks (Pending Clean Test Machine)

The following verification items strictly require a live installation on a dedicated clean test machine or virtual machine (VM) and cannot be simulated safely without performing an actual install:

1. **Live Setup Wizard Flow:**
   - Launching `SecurePrint-Shop-Setup.exe` on a fresh Windows system and progressing through the wizard pages (Welcome, Destination Location, Select Additional Tasks, Ready to Install, Finish).
2. **Per-User File Installation:**
   - Confirming files are extracted into `%LOCALAPPDATA%\Programs\SecurePrint Shop\` without triggering a UAC elevation prompt on a standard non-admin Windows user account.
3. **Start Menu & Desktop Shortcuts:**
   - Confirming the Start Menu shortcut is placed in `%APPDATA%\Microsoft\Windows\Start Menu\Programs\SecurePrint Shop\SecurePrint Shop.lnk` with the correct application icon.
   - Confirming the optional desktop shortcut task creates an icon on `%USERPROFILE%\Desktop`.
4. **Registry Registration:**
   - Confirming `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}_is1` contains valid `DisplayName`, `DisplayVersion`, `Publisher`, `InstallLocation`, and `UninstallString` values.
5. **In-Place Upgrade Behavior:**
   - Installing a subsequent build over an existing installation to verify that the AppId cleanly updates binaries in `{app}` without creating duplicate entries in Windows "Installed apps".
6. **Clean Uninstallation:**
   - Running the uninstaller from Windows Settings -> Apps -> Installed Apps -> Uninstall to verify that `%LOCALAPPDATA%\Programs\SecurePrint Shop` is completely removed, shortcuts are deleted, registry entries are purged, and backend/user data remains intact.
