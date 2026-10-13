# SecurePrint Shop - Windows Release Documentation

## Application Identity
- **Application Name**: SecurePrint Shop
- **Version**: 1.0.0
- **Desktop Framework**: Flutter (Windows Desktop x64)
- **Installer System**: Inno Setup 6 (`setup.iss`)
- **AppId**: `{D37F8E21-9B5A-4B6E-A71C-84E37A2F0914}`

---

## Production Build & Packaging Instructions

### Prerequisites
1. Flutter SDK (3.47.2 or compatible `3.13.2` channel)
2. Visual Studio Community with "Desktop development with C++" workload (MSVC toolchain, CMake, Windows SDK)
3. Inno Setup 6 compiler (`iscc.exe` at `%LOCALAPPDATA%\Programs\Inno Setup 6\iscc.exe`)

### 1. Build Command (Release Mode)
Navigate to `SecurePrint/shop_desktop` and execute:
```powershell
flutter build windows --release
```

### 2. Output Directory
The release binaries and asset bundle are generated in:
```
shop_desktop/build/windows/x64/runner/Release/
```

### 3. Required Runtime Files
The release folder contains the executable and its adjacent runtime dependencies:
- `SecurePrint-Shop.exe` (Main desktop application binary with native Win32 printer method channel)
- `flutter_windows.dll` (Flutter Engine)
- `data/` directory (Asset bundle, fonts, and compiled application kernel `app.so`)
- Supporting dynamic libraries:
  - `printing_plugin.dll`
  - `pdfium.dll`
  - `flutter_secure_storage_windows_plugin.dll`
  - `syncfusion_pdfviewer_windows_plugin.dll`
  - `url_launcher_windows_plugin.dll`
  - `webview_windows_plugin.dll`
  - `WebView2Loader.dll`
  - `dartjni.dll`

*Note: These files must remain together in the application directory. `SecurePrint-Shop.exe` is not a standalone single-file binary.*

### 4. Installer Compilation Command
From the `SecurePrint` repository root:
```powershell
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\iscc.exe" setup.iss
```
This generates the per-user installer at:
```
installers/SecurePrint-Shop-Setup.exe
```

---

## Backend Server Architecture & Network Configuration

The Windows Shop desktop application is an authenticated client designed to connect to the SecurePrint FastAPI backend service.

### Default Backend Configuration
- **Default Backend URL**: `http://127.0.0.1:8000/`
- **Default Authentication Mode**: `Production Backend Mode` (`AuthenticationMode.productionBackend`)
- The application connects to the FastAPI server by default on startup. It does **not** silently fall back to offline demo mode; if the backend cannot be reached, the application displays a clear connection error banner.

### Deployment Scenarios

#### 1. Single-PC Local Deployment (Same Machine)
- If the shop runs both the FastAPI backend and the Shop desktop software on the same physical PC:
- Start the FastAPI backend:
  ```powershell
  cd SecurePrint/backend
  .\venv312\Scripts\uvicorn.exe app.main:app --host 127.0.0.1 --port 8000
  ```
- The desktop app connects to `http://127.0.0.1:8000` automatically.
- **Important**: `127.0.0.1` (localhost) is valid **only** when the backend is running on the exact same computer as the desktop application.

#### 2. Multi-PC / Store LAN Deployment (Separate Shop PCs)
- If the shop operates with the FastAPI server on a primary counter PC or store server and one or more desktop workstations:
- Start the FastAPI backend bound to the host's local network interface:
  ```powershell
  cd SecurePrint/backend
  .\venv312\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000
  ```
- **Firewall Configuration**: Ensure Windows Firewall on the backend host machine allows inbound TCP connections on port 8000 for the private local network profile.
- **Client Configuration**:
  1. On the client desktop, launch SecurePrint Shop.
  2. On the Login screen, click the **Settings** gear icon in the server status banner.
  3. Enter the server's LAN IP address and port (for example: `http://192.168.1.100:8000`).
  4. Click **Test Connection** to confirm connectivity.
  5. Click **Save** to persist the URL in Windows SecureStorage.
- **Security Warning**: **Never expose the development server directly to the public internet** (e.g., via router port-forwarding without a reverse proxy, TLS termination, and firewall rate limiting).

---

## Testing & Verification Performed
- **Automated Integration & Regression Tests**: 125/125 Flutter tests and 39/39 backend E2E tests passed.
- **Launch Smoke Test**: Compiled binary starts without crashes; window renders visible; memory working set allocates stably.
- **PDF Page Extraction**: Page-range extraction (`PdfPageExtractor`) extracts only requested pages and preserves original document bytes.
- **Native Printer Settings**: Win32 `DeviceCapabilitiesW` and driver `DEVMODE` integration ensures duplex and color settings are verified against printer hardware before execution; unsupported settings fail cleanly and never silently produce wrong prints.
- **Data Safety**: Authoritative SQLite database (`secureprint.db`) and uploaded customer documents are completely isolated and never packaged into the installer.

---

## Known Limitations & Production Readiness
1. **Unsigned Executable**: As this build does not include a purchased Authenticode code-signing certificate, Windows SmartScreen will display an "Unknown Publisher" prompt upon first launch. Users click "More info" -> "Run anyway".
2. **Physical Hardware Verification**: Mechanical sheet inversion on physical duplex printers and hardware toner cartridge suppression remain pending physical hardware availability.
