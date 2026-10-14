# SecurePrint Windows Shop: Existing Installation Pre-Update Verification Report

**Date:** 2026-10-13  
**Auditor / Engineer:** Senior Windows Desktop Release Engineer  
**Scope:** Read-Only Verification of Existing Windows Installation, Installer Artifacts, Upgrade Mechanics, Process Status, and Data Isolation.  
**Strict Safety Constraints Enforced:**
- Zero files modified; zero registry keys altered.
- No installer or uninstaller executed.
- No running processes terminated.
- Authoritative backend database (`secureprint.db`) and uploaded customer documents (`backend/uploads/`) unaccessed and untouched.
- Read-only inspection commands only; no claims of physical upgrade execution.

---

## 1. Executive Summary & Verification Findings

| Inspection Dimension | Status | Detailed Finding |
| :--- | :---: | :--- |
| **New Release Installer** | **VERIFIED** | Located at [`installers\SecurePrint-Shop-Setup.exe`](file:///C:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/installers/SecurePrint-Shop-Setup.exe) (14,308,183 bytes, compiled 2026-10-13 21:41:38, SHA-256: `F584208CA43E6F750724E93E9ECD9FF4CEE6A6D6DDCDFE10015394AEF4C764B4`). |
| **Compiled Release Output** | **VERIFIED (NEW)** | Fresh binary at [`shop_desktop\build\windows\x64\runner\Release\SecurePrint-Shop.exe`](file:///C:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/build/windows/x64/runner/Release/SecurePrint-Shop.exe) (139,776 bytes, compiled 2026-10-13 21:40:49, SHA-256: `024BF292E07A595930B42D2E63AD2FFFD1224BB1272C16C4435DF33E082CA344`). |
| **Installed Executable Status** | **DATED (LEGACY)** | Installed at `C:\Users\sansk\SecurePrintShopInstall\SecurePrint-Shop.exe` (93,184 bytes, compiled 2026-09-24 20:00:44, SHA-256: `0062B1339D310628FFC728C452E29F5900227EAA2073BC7D993C674C97C2B7B4`). Current release binary is **19 days newer**. |
| **Running Application State** | **STOPPED** | `SecurePrint-Shop.exe` process is **not running**. Only the FastAPI backend Python service (PID 19028) is active. |
| **Installed Registry Identity** | **APPID MISMATCH** | Registered under `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\SecurePrint Shop_is1` (implicit AppId from legacy September setup). New installer targets explicit `AppId={D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}`. |
| **Target Install Directory** | **ISOLATED** | Target directory is `{localappdata}\Programs\SecurePrint Shop` (`C:\Users\sansk\AppData\Local\Programs\SecurePrint Shop`). Directory does not yet exist on disk. |
| **Backend & User Data Isolation** | **100% SAFE** | Authoritative database (`backend/secureprint.db`), uploads (`backend/uploads/`), and user credentials (`AppData\Roaming\SecurePrint`) are completely outside all installation paths. |

---

## 2. Installer Artifact & Configuration Inspection

### A. Existing Installer Binary
- **Full Path:** `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\installers\SecurePrint-Shop-Setup.exe`
- **File Size:** `14,308,183` bytes (~13.65 MB)
- **Last Write Timestamp (Local):** `2026-10-13 21:41:38` (UTC: `2026-10-13 16:11:38`)
- **SHA-256 Digest:** `F584208CA43E6F750724E93E9ECD9FF4CEE6A6D6DDCDFE10015394AEF4C764B4`
- **Installer Engine:** Inno Setup 6.7.3 (LZMA2 / Solid Compression)

### B. `setup.iss` Packaging Specification
Inspection of [`C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\setup.iss`](file:///C:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/setup.iss):
- **`AppId`:** `{{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}}` (Escaped for Inno Setup; registers `{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}`).
- **`AppName`:** `SecurePrint Shop` (Version `1.0.0`).
- **`DefaultDirName`:** `{localappdata}\Programs\SecurePrint Shop`.
- **`PrivilegesRequired`:** `lowest` (Non-elevated per-user installation into user profile).
- **`Files` Directive:** `Source: "shop_desktop\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs`.
- **`Icons` Directive:** `{group}\SecurePrint Shop` and optional `{autodesktop}\SecurePrint Shop` pointing to `{app}\SecurePrint-Shop.exe`.
- **`UninstallDisplayIcon`:** `{app}\SecurePrint-Shop.exe`.
- **Uninstall Scope:** Confined strictly to files recorded in `{app}\unins000.dat`.

---

## 3. Existing Installation & Process State Audit

### A. Windows Registry Uninstall Inspection
Query command executed:
```powershell
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.PSChildName -match "D37F8E21" -or $_.DisplayName -match "SecurePrint" }
```
**Actual Result:**
- **Registry Key:** `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SecurePrint Shop_is1`
- **`DisplayName`:** `SecurePrint Shop version 1.0.0`
- **`DisplayVersion`:** `1.0.0`
- **`InstallLocation`:** `C:\Users\sansk\SecurePrintShopInstall\`
- **`InstallDate`:** `20260924` (Installed September 24, 2026)
- **`UninstallString`:** `"C:\Users\sansk\SecurePrintShopInstall\unins000.exe"`
- **`QuietUninstallString`:** `"C:\Users\sansk\SecurePrintShopInstall\unins000.exe" /SILENT`

### B. Installed Executable Verification
- **Path:** `C:\Users\sansk\SecurePrintShopInstall\SecurePrint-Shop.exe`
- **Size:** `93,184` bytes
- **Timestamp:** `2026-09-24 20:00:44`
- **SHA-256 Digest:** `0062B1339D310628FFC728C452E29F5900227EAA2073BC7D993C674C97C2B7B4`
- **Status:** Stale legacy September build. Lacks native Win32 duplex/color print channel and recent page-range extracted logic.

### C. Process Activity Check
Query command executed:
```powershell
Get-Process | Where-Object { $_.ProcessName -match "SecurePrint" -or $_.Path -match "SecurePrint" }
```
**Actual Result:**
- **`SecurePrint-Shop.exe`:** **NOT RUNNING** (0 instances).
- **Backend Service:** `python.exe` (PID 19028, running `uvicorn app.main:app` from `backend\venv312`) is active on port 8000.

---

## 4. Release Build Output vs. Installed Binary Comparison

| Attribute | Legacy Installed Executable | Fresh Release Build Output |
| :--- | :--- | :--- |
| **Location** | `C:\Users\sansk\SecurePrintShopInstall\SecurePrint-Shop.exe` | `shop_desktop\build\windows\x64\runner\Release\SecurePrint-Shop.exe` |
| **File Size** | `93,184` bytes (~91 KB) | `139,776` bytes (~136.5 KB) |
| **Last Write Time** | `2026-09-24 20:00:44` | `2026-10-13 21:40:49` |
| **SHA-256 Hash** | `0062B1339D310628FFC728C452E29F5900227EAA2073BC7D993C674C97C2B7B4` | `024BF292E07A595930B42D2E63AD2FFFD1224BB1272C16C4435DF33E082CA344` |
| **Native Channels** | Basic Flutter channels | Includes `secureprint/printer_settings` Win32 `DEVMODE` channel |
| **Page Range Engine** | Missing (sends entire PDF bytes) | Fully integrated `PdfPageExtractor` |
| **Backend Defaults** | Offline demo mode fallback | Defaults to live FastAPI backend at `http://127.0.0.1:8000/` |
| **Age Difference** | Baseline (24-Sep-2026) | **19 days newer (13-Oct-2026)** |

---

## 5. Data Separation & Isolation Confirmation

To verify zero data loss risk during update or uninstallation:

| Data Category | Absolute File System Path | Separation Confirmation |
| :--- | :--- | :--- |
| **FastAPI SQLite Database** | `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\backend\secureprint.db` | **100% Isolated** (Completely outside all installation directories) |
| **Uploaded Customer Documents** | `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\backend\uploads\` | **100% Isolated** (Managed exclusively by backend Uvicorn service) |
| **Shop Credential & Session Store** | `C:\Users\sansk\AppData\Roaming\SecurePrint\SecurePrint Shop\flutter_secure_storage.dat` | **100% Isolated** (Located in user's Roaming profile; never deleted by Inno Setup) |
| **Local Account Caches** | `C:\Users\sansk\AppData\Roaming\SecurePrint\SecurePrint Shop\SecurePrintShop\local_accounts.json` | **100% Isolated** (Preserved in Roaming profile) |
| **Legacy Install Path** | `C:\Users\sansk\SecurePrintShopInstall\` | Contains only Flutter binaries and DLLs |
| **New Target Install Path** | `C:\Users\sansk\AppData\Local\Programs\SecurePrint Shop` | Contains only newly deployed binaries |

---

## 6. Upgrade Mechanics & Identified Inno Setup Risks

### Analysis of AppId Transition:
1. **How Inno Setup Upgrades Work:**
   - Inno Setup detects an existing installation by querying the registry key `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\<AppId>_is1`.
   - If an existing key with the **exact same AppId** is found, Inno Setup enters "Update Mode": it automatically selects the previous installation path and overwrites older files with newer ones.
2. **The Disparity:**
   - The legacy September installation was compiled **without** an `AppId` directive. Inno Setup defaulted to using `AppName`, registering `SecurePrint Shop_is1`.
   - The new installer was compiled **with** `AppId={{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}}`, registering `{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}_is1`.
3. **Behavior if New Installer is Run Directly:**
   - Inno Setup will **not recognize** `SecurePrint Shop_is1` as the same application.
   - It will install fresh binaries to `C:\Users\sansk\AppData\Local\Programs\SecurePrint Shop`.
   - It will **not remove or overwrite** `C:\Users\sansk\SecurePrintShopInstall\`.
   - Windows Settings ("Installed Apps") will display **two separate installations** of "SecurePrint Shop".
   - Start Menu shortcuts may collide or duplicate.
4. **Future Upgrades:**
   - Once `{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}` is established, all future releases sharing this AppId will upgrade in-place automatically.

---

## 7. Recommended Safe Next Steps

Because data authority resides 100% in `backend\secureprint.db` and user session tokens reside safely in `AppData\Roaming`, the cleanest, safest, and industry-standard deployment path is:

### Option A: Clean Transition (Recommended)
1. **Uninstall the legacy September build:**
   Execute the silent uninstaller for the legacy installation:
   ```powershell
   & "C:\Users\sansk\SecurePrintShopInstall\unins000.exe" /SILENT
   ```
   *Result:* Removes stale DLLs and deletes the `SecurePrint Shop_is1` registry key. Backend database and session tokens remain 100% intact.
2. **Run the new installer:**
   ```powershell
   & "C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\installers\SecurePrint-Shop-Setup.exe"
   ```
   *Result:* Cleanly establishes the production app at `%LOCALAPPDATA%\Programs\SecurePrint Shop` under the stable AppId `{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}`.
3. **Launch and Verify:**
   Launch the newly deployed executable from `%LOCALAPPDATA%\Programs\SecurePrint Shop\SecurePrint-Shop.exe` and verify connectivity to the running FastAPI backend (`http://127.0.0.1:8000/`).

### Option B: Side-by-Side Coexistence
If the team wishes to keep the September installation for comparison:
1. Run `SecurePrint-Shop-Setup.exe` directly without uninstalling the old version.
2. The new application will install to `%LOCALAPPDATA%\Programs\SecurePrint Shop`, leaving `C:\Users\sansk\SecurePrintShopInstall\` fully operational alongside it.
