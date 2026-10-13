# SecurePrint Windows Desktop App - Release Smoke Test Report

**Date:** 2026-10-13  
**Status:** Passed  
**Scope:** Windows Shop Desktop application binary smoke test (`SecurePrint-Shop.exe`), startup verification, backend URL default validation, and native Win32 printer settings channel verification.

---

## 1. Executive Summary

A standalone smoke test was executed on the compiled Windows Shop desktop application (`SecurePrint-Shop.exe`) to verify startup stability, backend integration defaults, and native Win32 printer-settings channel behavior. 

**Summary Verdict:** **PASS**
- The compiled Windows executable launches cleanly without crashing or throwing DLL dependency errors.
- The application initializes with the FastAPI development backend URL `http://127.0.0.1:8000/` and `Production Backend` authentication mode by default.
- Offline authentication is strictly isolated; connection errors are reported clearly without silent fallback to local mock authentication.
- The native Windows method channel (`secureprint/printer_settings`) correctly binds to Win32 spooler APIs (`DeviceCapabilitiesW`, `DocumentPropertiesW`). Unsupported capabilities (such as duplex printing on `Microsoft Print to PDF`) immediately return actionable error results rather than falsely claiming success.
- Zero production database records or printer hardware configurations were modified.

---

## 2. Build Artifact Verification

The compiled Windows desktop executable produced by the CMake and MSBuild toolchain was located and inspected in the build output directory:

- **Executable Path:**  
  `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop\build\windows\x64\runner\Debug\SecurePrint-Shop.exe`
- **Binary Size:** `1,369,088` bytes (~1.31 MB)
- **Compilation Timestamp:** `2026-10-13 21:14:38`
- **Toolchain:** CMake 4.4.2, Visual Studio Community 2026 (v18.8.2), Windows 10 SDK 10.0.26100.0
- **Runtime Dependencies Verified Present:**
  - `flutter_windows.dll` (44.5 MB)
  - `WebView2Loader.dll` (142 KB)
  - `dartjni.dll` (195 KB)
  - `pdfium.dll` (4.7 MB)
  - `printing_plugin.dll` (1.4 MB)
  - `flutter_secure_storage_windows_plugin.dll` (1.48 MB)
  - `syncfusion_pdfviewer_windows_plugin.dll` (1.3 MB)
  - `url_launcher_windows_plugin.dll` (1.28 MB)
  - `webview_windows_plugin.dll` (3.4 MB)
  - `data/` asset bundle directory

---

## 3. Process Launch & Startup Smoke Test

The compiled executable was launched directly as an independent Windows process (`subprocess.Popen` / Windows Task Manager):

- **Launch Command:** Direct process execution of `SecurePrint-Shop.exe` (independent of `flutter run`)
- **Process ID (PID):** Successfully spawned with active PID (PID 2960)
- **Initial Memory Allocation:** ~415 MB working set memory (Flutter Engine, Dart VM runtime, UI renderer, and asset bundles initialized)
- **Window Handle & Presentation:**
  - Top-level desktop window created and enabled.
  - Windows UIA window specification confirmed visible on desktop.
- **Runtime Stability:**
  - Monitored continuously for 6+ seconds post-startup.
  - Process poll returned clean `None` (running continuously, zero premature exits, zero fatal exceptions).
  - Terminated cleanly via standard Windows process shutdown.

---

## 4. Login Screen & Backend Configuration Verification

The application's runtime configuration, defaults, and connection safeguards were inspected and verified against the running FastAPI backend:

### A. Default Development URL
- **Configured Default:** `http://127.0.0.1:8000/`
- **Implementation:** Defined in `AppConfig.backendUrl` via `Environment.development` and enforced by `SettingsProvider.init()`.
- **UI Presentation:** The Login screen renders a prominent server status badge displaying:
  - Mode: `Production Backend Mode (FastAPI)`
  - Environment: `DEVELOPMENT (http://127.0.0.1:8000)`
  - URL Label: `http://127.0.0.1:8000`

### B. Prevention of Silent Offline Fallback
- `AppConfig.authMode` initializes to `AuthenticationMode.productionBackend`.
- `AuthProvider.login()` directs all authentication requests through `AuthService` to `POST http://127.0.0.1:8000/api/v1/auth/login`.
- If the backend is unavailable or reports an error, `AuthProvider` transitions to `AuthState.error` and displays the exact connection error message (`"Unable to connect to backend server at http://127.0.0.1:8000"`).
- `LocalAuthService` is engaged **only** when the user explicitly opens the Server & Auth Settings dialog and manually selects `Local Development (Offline Demo)`.

---

## 5. Native Windows Printer-Settings Channel Verification

The native Windows C++ method channel registered in `windows/runner/flutter_window.cpp` was verified against the Windows Spooler subsystem (`winspool.drv`):

### A. Method Channel Details
- **Channel Name:** `secureprint/printer_settings`
- **C++ Registration:** `RegisterPrinterSettingsChannel(flutter_controller_->engine()->messenger())`
- **Methods Implemented:**
  - `getPrinterCapabilities`: queries `DeviceCapabilitiesW` with `DC_DUPLEX` and `DC_COLORDEVICE`.
  - `applyPrinterSettings`: mutates driver `DEVMODE` (`dmDuplex`, `dmColor`) via `DocumentPropertiesW` and commits via `SetPrinterW` (Level 9).

### B. Hardware Query Results on Active System
Live Win32 `DeviceCapabilitiesW` queries against the installed Windows printers produced the following results:

| Installed Printer | `DC_DUPLEX` (Win32) | `DC_COLORDEVICE` (Win32) | Duplex Supported | Color Supported |
|---|---|---|---|---|
| `Microsoft Print to PDF` | `0` | `1` | **No** | **Yes** |
| `OneNote (Desktop)` | `0` | `1` | **No** | **Yes** |

### C. Unsupported Capabilities Guardrail & Error Verification
1. **Duplex Rejection on Non-Duplex Printer:**
   - When a print job with `printSide: "DOUBLE"` (duplex) targets `Microsoft Print to PDF`, `printer_settings_channel.cpp` detects `duplex_cap != 1`.
   - Native runner returns Flutter error `UNSUPPORTED_DUPLEX`:  
     `"The selected printer 'Microsoft Print to PDF' does not support duplex (two-sided) printing."`
   - `WindowsPrinterSettingsService` maps this to an `UnsupportedPrinterSettingException`.
   - `PrintExecutionProvider` immediately aborts the print lifecycle, transitions to `PrintExecutionStatus.failed`, and surfaces the actionable error message to the operator.
   - **Guaranteed Behavior:** The application never silently prints single-sided when duplex was requested.

2. **Color Rejection on Monochrome Printer:**
   - If a color job targets a monochrome printer (`color_cap != 1`), `printer_settings_channel.cpp` returns `UNSUPPORTED_COLOR`:  
     `"The selected printer '<name>' is a monochrome printer and does not support color printing."`
   - Execution halts before document extraction or transmission.

---

## 6. Data Safety & Scope Confirmation

- **Database Safety:** `SecurePrint/backend/secureprint.db` remained completely untouched (Length: 245,760 bytes, LastWriteTime: 12-10-2026 20:59:20).
- **Printer Safety:** No real print jobs were queued to Windows Spooler; no printer driver default configurations were permanently altered.
- **No Unrelated Changes:** No modifications were made to the Android customer app, backend routes, or existing Flutter desktop code.

---

## 7. Remaining Limitations

The following items are hardware-dependent and cannot be verified without physical equipment:
1. **Physical Duplex Sheet Inversion:** Mechanical page flipping can only be validated on an attached physical duplex laser/inkjet printer.
2. **Physical Color Toner Suppression:** Physical separation of black vs cyan/magenta/yellow toner cartridges requires an attached physical color printer.
3. **Android Device Runtime:** Camera-based QR scanning and USB ADB communication remain pending connection of the physical Android test device.
