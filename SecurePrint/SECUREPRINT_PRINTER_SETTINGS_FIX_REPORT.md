# SecurePrint Windows Desktop App - Printer Duplex & Color Settings Fix Report

**Date:** 2026-10-13  
**Status:** Complete  
**Scope:** Windows Shop Desktop (`SecurePrint/shop_desktop`)

---

## 1. Executive Summary & Root Cause Analysis

### Problem Statement
In the Windows Shop desktop application, customer-selected print options (duplex/simplex and color/grayscale) were not reliably transmitted to the actual Windows printing subsystem. Print jobs executed through `PrintExecutionProvider` sent documents to `Printing.directPrintPdf`, but the underlying Windows printer driver ignored duplex and color preferences, potentially printing two-sided jobs as single-sided or printing color pages when monochrome was requested (or failing silently).

### Root Cause Analysis in `package:printing` (v5.15.0)
Investigation of `package:printing`'s native Windows implementation (`windows/print_job.cpp`) revealed two critical architectural limitations:
1. **Dart API Omission:** `Printing.directPrintPdf` exposes parameters for `printer`, `doc`, `name`, `format`, `dynamicLayout`, and `usePrinterSettings`. It does **not** provide parameters for `duplex`, `colorMode`, or `grayscale`.
2. **Hardcoded C++ Win32 DEVMODE:** In `print_job.cpp`, when `usePrinterSettings: false` (the default), the native code allocates a minimal `DEVMODE` and hardcodes:
   ```cpp
   dm->dmFields = DM_ORIENTATION | DM_PAPERSIZE | DM_PAPERLENGTH | DM_PAPERWIDTH;
   ```
   Crucially, `DM_DUPLEX` and `DM_COLOR` are completely omitted from `dmFields`, and `dmDuplex`/`dmColor` fields are never populated.
3. **Behavior with `usePrinterSettings: true`:** When `usePrinterSettings: true` is passed, `print_job.cpp` passes `dm = nullptr` to `CreateDCW`, causing the Windows GDI print engine to fall back directly to the printer's current default `DEVMODE` configuration.

### Solution Architecture
To ensure selected duplex and color settings are reliably applied without introducing external 3rd-party dependencies:
1. **Native Method Channel via Windows Runner:** Created a lightweight Win32 printing channel (`windows/runner/printer_settings_channel.cpp`) hooked into the existing Flutter runner window.
2. **Win32 Spooler Integration (`winspool.drv`):**
   - Queries hardware capabilities via `DeviceCapabilitiesW(..., DC_DUPLEX, ...)` and `DeviceCapabilitiesW(..., DC_COLORDEVICE, ...)`.
   - Fetches and modifies the driver's `DEVMODE` structure using `DocumentPropertiesW`.
   - Sets `dmDuplex` (`DMDUP_SIMPLEX` = 1, `DMDUP_VERTICAL` = 2) and `dmColor` (`DMCOLOR_MONOCHROME` = 1, `DMCOLOR_COLOR` = 2).
   - Validates driver acceptance (`DocumentPropertiesW` with `DM_IN_BUFFER | DM_OUT_BUFFER`).
   - Persists the configuration as the per-user default `DEVMODE` for the printer via `SetPrinterW` with `PRINTER_INFO_9W` (Level 9 requires no administrative privileges).
3. **Safe Dart Service & Provider Integration:**
   - Introduced domain models (`PrintDuplexMode`, `PrintColorMode`, `PrinterCapabilities`, `PrinterSettingsApplicationResult`, `UnsupportedPrinterSettingException`).
   - `PrintExecutionProvider` queries capabilities, safely maps and applies settings before print execution, and passes `usePrinterSettings: true` to `Printing.directPrintPdf`.
   - If a printer does not support a requested setting (e.g., duplex on a single-sided printer), execution halts immediately with a clear, actionable `UnsupportedPrinterSettingException`. Never silently claims success.
4. **UI Capability Warnings:**
   - `PrinterProvider` queries capabilities whenever a printer is selected.
   - `PrinterSelectionScreen` displays clear warning banners if the selected printer lacks duplex or color capabilities for the pending job.

---

## 2. Changed and Created Files

| File | Change Type | Purpose |
|---|---|---|
| `windows/runner/CMakeLists.txt` | Modified | Added `printer_settings_channel.cpp` and `printer_settings_channel.h` to executable sources; linked `winspool.lib`. |
| `windows/runner/flutter_window.cpp` | Modified | Registered `RegisterPrinterSettingsChannel(flutter_controller_->engine()->messenger())` upon engine initialization. |
| `windows/runner/printer_settings_channel.h` | **Created** | Declares `RegisterPrinterSettingsChannel`. |
| `windows/runner/printer_settings_channel.cpp` | **Created** | Win32 native implementation: `getPrinterCapabilities` and `applyPrinterSettings` using `winspool` APIs (`DeviceCapabilitiesW`, `DocumentPropertiesW`, `SetPrinterW`). |
| `lib/models/print_settings.dart` | **Created** | Domain enums and models: `PrintDuplexMode`, `PrintColorMode`, `PrinterCapabilities`, `PrinterSettingsApplicationResult`, `UnsupportedPrinterSettingException`. |
| `lib/services/printer_settings_service.dart` | **Created** | Abstract interface `PrinterSettingsService` and concrete `WindowsPrinterSettingsService` communicating with the platform method channel. |
| `lib/providers/print_execution_provider.dart` | Modified | Injected `PrinterSettingsService`; resolves duplex/color from job; validates and applies settings before print; passes `usePrinterSettings: true` to `Printing.directPrintPdf`. |
| `lib/providers/printer_provider.dart` | Modified | Injected `PrinterSettingsService`; queries and caches `selectedPrinterCapabilities` on printer selection. |
| `lib/features/print_jobs/printer_selection_screen.dart` | Modified | Added warning banners if selected printer does not support job's duplex or color requirements. |
| `test/printer_settings_test.dart` | **Created** | 12 focused unit tests covering duplex parsing, color parsing, settings propagation, fallback defaults, error rejection, and capability caching. |
| `test/print_execution_test.dart` | Modified | Updated mock execution tests with stubbed `PrinterSettingsService` and verified page range + settings integration. |

---

## 3. Data Flow: How Each Setting Reaches the Printer

```
┌────────────────────────────────────────────────────────┐
│   PrintJobDetailModel (Backend API / Local Job State)  │
│   job.printSide: "DOUBLE_SIDED"                        │
│   job.colorMode: "COLOR"                               │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│             PrintExecutionProvider.dart                │
│  1. Parse/normalize PrintDuplexMode & PrintColorMode   │
│  2. Calls PrinterSettingsService.applySettings(...)    │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│           WindowsPrinterSettingsService                │
│  MethodChannel("secureprint/printer_settings")         │
│  .invokeMethod("applyPrinterSettings", args)           │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│        Win32 Native Runner (printer_settings_channel)  │
│  1. OpenPrinterW(printerName, &hPrinter, ...)          │
│  2. DeviceCapabilitiesW (DC_DUPLEX & DC_COLORDEVICE)   │
│     * If unsupported by hardware -> returns error      │
│  3. DocumentPropertiesW (Fetch driver DEVMODE)         │
│  4. Set dmDuplex = DMDUP_VERTICAL (or SIMPLEX)         │
│     Set dmColor  = DMCOLOR_COLOR (or MONOCHROME)       │
│  5. DocumentPropertiesW (Validate driver acceptance)   │
│  6. SetPrinterW (Level 9 / PRINTER_INFO_9W)            │
│     * Writes per-user default DEVMODE to Spooler       │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│             Printing.directPrintPdf(...)               │
│  usePrinterSettings: true                              │
│  -> CreateDCW(..., dm = nullptr) in package:printing   │
│  -> Windows GDI initializes DC using updated DEVMODE   │
│  -> Spooler transmits duplex & color bytes to Driver   │
└────────────────────────────────────────────────────────┘
```

### Detailed Setting Traversal

#### A. Duplex Mode
1. **Input:** `job.printSide` (e.g. `'DOUBLE'`, `'DOUBLE_SIDED'`, `'TWO_SIDED'`, `'DUPLEX'`).
2. **Parsing & Normalization:** `PrintDuplexMode.fromJobString(job.printSide)` normalizes to `PrintDuplexMode.duplex`. Default fallback for null or empty strings is `PrintDuplexMode.simplex`. Malformed or unrecognized values throw a `FormatException`.
3. **Hardware Capability Check:** `DeviceCapabilitiesW(printerName, port, DC_DUPLEX, nullptr, nullptr)`. If return is `<= 0`, the driver/hardware lacks duplex hardware. An `UnsupportedPrinterSettingException` is returned:
   `"Printer '<name>' does not support two-sided (duplex) printing."`
4. **DEVMODE Mutation:** `dm->dmDuplex = DMDUP_VERTICAL` (or `DMDUP_SIMPLEX`) and `dm->dmFields |= DM_DUPLEX`.
5. **Driver Acceptance Verification:** `DocumentPropertiesW` processes the in/out DEVMODE buffer. If the driver clears `DM_DUPLEX` from `dmFields`, the setting is rejected.

#### B. Color Mode
1. **Input:** `job.colorMode` (e.g. `'COLOR'`, `'COLOUR'`, `'MONOCHROME'`, `'BW'`, `'BLACK_AND_WHITE'`).
2. **Parsing & Normalization:** `PrintColorMode.fromJobString(job.colorMode)` normalizes to `PrintColorMode.color` or `PrintColorMode.monochrome`. Default fallback for null or empty strings is `PrintColorMode.color`. Malformed strings throw a `FormatException`.
3. **Hardware Capability Check:** `DeviceCapabilitiesW(printerName, port, DC_COLORDEVICE, nullptr, nullptr)`. If return is `<= 0` and color is requested, an `UnsupportedPrinterSettingException` is returned:
   `"Printer '<name>' does not support color printing."`
4. **DEVMODE Mutation:** `dm->dmColor = DMCOLOR_COLOR` (or `DMCOLOR_MONOCHROME`) and `dm->dmFields |= DM_COLOR`.
5. **Driver Acceptance Verification:** `DocumentPropertiesW` verifies that `DM_COLOR` remains set in `dmFields`.

#### C. Persistence & Print Invocation
- `SetPrinterW` with `PRINTER_INFO_9W` updates the per-user default `DEVMODE` for the printer in the Windows spooler.
- When `Printing.directPrintPdf` is invoked with `usePrinterSettings: true`, `windows/print_job.cpp` calls `CreateDCW(L"WINSPOOL", printer_name, nullptr, nullptr)`. GDI loads the per-user default `DEVMODE` configured in the previous step, ensuring the driver receives the correct duplex and color parameters.

---

## 4. Error Handling and Guardrails

1. **No Silent Ignorance:** If a requested duplex or color setting cannot be applied (either because the printer hardware lacks support or the driver rejects the `DEVMODE` field), the system never silently proceeds. Execution halts immediately with a clear error:
   ```
   UnsupportedPrinterSettingException: Printer 'Microsoft Print to PDF' does not support two-sided (duplex) printing.
   ```
2. **UI Proactive Warning:** When selecting a printer in `PrinterSelectionScreen`, capabilities are retrieved asynchronously. If the selected printer lacks duplex support for a two-sided job, or color support for a color job, prominent warning banners are displayed with instructions to the shop operator before print execution is triggered.
3. **Preservation of Page Range & PDF Integrity:** The extracted page-range logic implemented in the previous fix is fully preserved. Settings validation occurs immediately before PDF page extraction, preserving original PDF bytes and avoiding unnecessary extraction overhead if settings are invalid.

---

## 5. Automated Test Results

### 1. Focused Unit Tests (`test/printer_settings_test.dart`)
Command: `flutter test test/printer_settings_test.dart`
Result: **12 / 12 passed (100%)**
- `PrintDuplexMode parses simplex / single-sided strings correctly`
- `PrintDuplexMode parses duplex / double-sided strings correctly`
- `PrintDuplexMode rejects unrecognized duplex strings with clear exception`
- `PrintColorMode parses color strings correctly`
- `PrintColorMode parses monochrome / black-and-white strings correctly`
- `PrintColorMode rejects unrecognized color strings with clear exception`
- `PrintExecutionProvider propagates duplex and color settings to PrinterSettingsService`
- `PrintExecutionProvider defaults to simplex and color when job settings are blank or single`
- `PrintExecutionProvider fails immediately with actionable error when printer lacks duplex support`
- `PrintExecutionProvider fails immediately with actionable error when printer lacks color support`
- `PrintExecutionProvider fails immediately when printSide setting string is malformed`
- `PrinterProvider loads printer capabilities when printer is selected`

### 2. Print Execution Tests (`test/print_execution_test.dart`)
Command: `flutter test test/print_execution_test.dart`
Result: **4 / 4 passed (100%)**
- `executePrint completes full lifecycle successfully`
- `executePrint fails if startJob throws`
- `executePrint passes requested pageRange to PdfPageExtractor`
- `executePrint fails immediately and does not print when pageRange is invalid`

### 3. Full Suite Test Execution (`flutter test`)
Command: `flutter test`
Result: **125 / 125 passed (100%)**

### 4. Static Code Analysis (`flutter analyze`)
Command: `flutter analyze`
Result:
- **0 errors, 0 warnings, 0 lints** in all newly created and modified files (`lib/models/print_settings.dart`, `lib/services/printer_settings_service.dart`, `lib/providers/print_execution_provider.dart`, `lib/providers/printer_provider.dart`, `test/printer_settings_test.dart`).
- 35 total pre-existing issues in legacy screens (deprecated Flutter widgets like `RadioGroup`/`WillPopScope`, missing super parameters, and unused imports in legacy tests). No new issues introduced.

---

## 6. Limitations & Physical Verification Checklist

### Known Limitations
1. **Virtual Drivers vs Physical Hardware:** Virtual printers (such as `Microsoft Print to PDF`) report `DC_DUPLEX = 0` (no duplex unit) and `DC_COLORDEVICE = 1` (color support). In this environment, requesting duplex correctly triggers `UnsupportedPrinterSettingException`, validating the guardrail, but virtual drivers cannot physically verify two-sided mechanical paper inversion.
2. **Driver Custom Overrides:** Certain proprietary OEM print drivers (e.g. specialized HP/Canon PCL6/PostScript drivers) possess custom vendor dialog hooks that may override standard Windows `DEVMODE` settings if vendor "Eco Mode" or "Secure Print PIN" overlays are enabled. Standard Win32 `DEVMODE` Level 9 is the Windows specification standard.

### What Still Requires Physical-Printer Verification
The following items require physical hardware verification with an attached physical printer:
- [ ] Connect a physical duplex-capable printer (e.g., HP LaserJet Pro Duplex / Brother HL Duplex) over USB or network.
- [ ] Send a two-sided job (`DOUBLE_SIDED`) and verify physical sheet inversion (pages 1 and 2 printed on opposing sides of the same sheet).
- [ ] Send a single-sided job (`SINGLE`) and verify physical output on separate sheets.
- [ ] Send a `MONOCHROME` job to a color laser/inkjet printer and verify that the printer driver utilizes only the black toner/ink cartridge (no composite cyan/magenta/yellow).
- [ ] Send a `COLOR` job to a monochrome-only printer and verify that the application displays the warning banner and halts with `UnsupportedPrinterSettingException`.
