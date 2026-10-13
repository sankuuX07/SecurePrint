# SecurePrint Windows Shop App - Backend Connection Fix Report

**Date:** October 13, 2026  
**Auditor / Engineer:** Senior Integration Engineer  
**Target Repository:** `SecurePrint/shop_desktop`  
**Reference Document:** `SECUREPRINT_WINDOWS_APP_AUDIT.md`  

---

## 1. Executive Summary

In the initial implementation, the Windows Shop desktop application (`shop_desktop`) was configured with offline local-development authentication (`AuthenticationMode.localDevelopment`) and an unconfigured backend URL (`""` from `Environment.production`) as its initial defaults. In this state:
1. Fresh launches bypassed the FastAPI backend entirely, routing authentication to a local JSON file (`%APPDATA%\SecurePrintShop\local_accounts.json`).
2. Operators were given no pre-login indication or controls regarding the active backend server or authentication mode.
3. If users attempted to sign in with their authoritative FastAPI database credentials, the local authentication service rejected them or, conversely, local demo logins gave a false illusion of cloud connectivity.
4. Connection settings could only be modified from `SettingsScreen` *after* a successful login, locking operators out if they could not authenticate.

### Resolution Overview:
- Changed the default environment to `Environment.development`, resolving `AppConfig.backendUrl` to `http://127.0.0.1:8000`.
- Changed the default authentication mode to `AuthenticationMode.productionBackend`.
- Added a non-intrusive, responsive **Connection & Mode Status Card** directly on [LoginScreen](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/features/auth/login_screen.dart) displaying active backend URL, server status, real-time "Test Connection" button, and pre-login server settings modal dialog.
- Guarded `AuthService.login` and `BackendAuthService.register` to prevent requests when the backend URL is unconfigured, throwing clear exceptions rather than unhandled socket crashes.
- Ensured offline local-development mode remains strictly an explicit, clearly labelled opt-in option with prominent disclaimers and an instant "Switch to Backend" control.
- Preserved existing `SHOP` role validation, JWT handling, secure token storage, remember-session logic, and all backend API contracts.
- Expanded automated test coverage from 73 to **84 tests**, with **0 test failures** and **0 analyzer errors in modified code**.

---

## 2. Changed Files & Architectural Rationale

| File | Type | Changes & Architectural Rationale |
|---|---|---|
| [lib/core/config/app_config.dart](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/core/config/app_config.dart) | Core Config | Initialized `currentEnvironment = Environment.development` (evaluates to `http://127.0.0.1:8000`) and `authMode = AuthenticationMode.productionBackend`. Preserved existing enum definitions. |
| [lib/providers/settings_provider.dart](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/providers/settings_provider.dart) | State / Settings | In `init()`, fallback defaults when secure storage has no saved preferences are now `Environment.development` and `AuthenticationMode.productionBackend`. Injected optional `http.Client`. Added `checkBackendConnection()` (pings `${AppConfig.backendUrl}/` with 4s timeout) and `resetToDefaults()`. Preserves existing saved user preferences safely. |
| [lib/services/auth_service.dart](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/auth_service.dart) | Network Service | Added guard in `login()`: validates `AppConfig.backendUrl.trim().isNotEmpty`, throwing clear `AuthServiceException('Backend URL is not configured. Please check connection settings.')` instead of failing URI parsing. Preserved SHOP role check, JWT extraction, and error handling. |
| [lib/services/backend_auth_service.dart](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/backend_auth_service.dart) | Service Adapter | Added guard in `register()`: validates `AppConfig.backendUrl.trim().isNotEmpty`, throwing clear `AuthServiceException` if empty. |
| [lib/features/auth/login_screen.dart](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/features/auth/login_screen.dart) | Presentation | Added top AppBar with Settings action icon; added responsive Connection Status Card with active mode badge, URL indicator, real-time "Test Connection" button, and Configure dialog trigger. Added modal `_showConnectionDialog` allowing operators to switch Auth Mode, Environment, Custom URL, and test reachability before signing in. Added explicit "Switch to Backend" shortcut when in local offline mode. |
| [test/settings_provider_test.dart](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/settings_provider_test.dart) | Automated Tests | Updated tests to assert default `Environment.development`, `AuthenticationMode.productionBackend`, and `http://127.0.0.1:8000`. Added tests for `setAuthMode`, `checkBackendConnection` (success & network failure), and `resetToDefaults`. (8 passing tests). |
| [test/auth_test.dart](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/auth_test.dart) | Automated Tests | Added tests verifying: (1) default mode is `BackendAuthService` with `http://127.0.0.1:8000`, (2) unavailable backend handling prevents false success and reports clear connection error, (3) empty backend URL guard, (4) explicit offline mode selection routes to `LocalAuthService`, (5) non-SHOP role rejection, (6) session preservation and logout. (14 passing tests). |
| [test/auth_screens_test.dart](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/auth_screens_test.dart) | Widget Tests | Updated widget tests to verify default `Production Backend Mode (FastAPI)` with `http://127.0.0.1:8000` on `LoginScreen`; verified opening connection settings dialog; verified explicit offline mode shows disclaimer and "Switch to Backend" button; verified signup navigation in backend mode. (9 passing tests). |

---

## 3. Behavior Changes

### 3.1 Default Launch State
- **Before:** Fresh application start set `currentEnvironment = Environment.production` (empty string URL `""`) and `authMode = AuthenticationMode.localDevelopment`. The app silently verified logins against local files.
- **After:** Fresh application start sets `currentEnvironment = Environment.development` (`http://127.0.0.1:8000`) and `authMode = AuthenticationMode.productionBackend`. Launching the app connects to the live FastAPI backend by default.

### 3.2 Pre-Login Connection Visibility & Diagnostics
- **Before:** No way to know or test backend connectivity prior to logging in.
- **After:**
  - `LoginScreen` displays a **Production Backend Mode (FastAPI)** card indicating the target host (`http://127.0.0.1:8000`) and environment badge (`DEVELOPMENT`).
  - An interactive **Test** button sends an unauthenticated HTTP GET probe to `${AppConfig.backendUrl}/` with immediate visual feedback (green check with "Connected to FastAPI backend" or red error with "Cannot reach backend").
  - An interactive **Settings / Configure** button opens the `Server & Auth Settings` modal, allowing operators to adjust the environment, configure a custom host/IP (e.g., LAN testing), or test the connection before attempting to sign in.

### 3.3 Prevention of False Backend-Login Success
- **Before:** A user could enter credentials, succeed locally in demo mode, and believe they had authenticated to FastAPI.
- **After:** 
  - In backend mode, all authentication requests are directed exclusively to `${AppConfig.backendUrl}/api/v1/auth/login`.
  - If the FastAPI server is unreachable, `AuthService` throws an `AuthServiceException` and `AuthProvider` sets `errorMessage = 'Unable to connect to SecurePrint server.'`.
  - The application **never** falls back silently to `LocalAuthService` upon backend failure.
  - The login screen renders a red alert banner, preserving unauthenticated state.

### 3.4 Explicit Offline Mode Selection
- Offline local development remains fully supported for offline kiosk testing and UI preview, but **only via explicit operator choice**:
  1. The operator selects "Local Development (Offline Demo)" in the settings dialog.
  2. The `LoginScreen` immediately updates with an amber notice card: `"Local Development Mode (Offline)"` with the disclaimer: `"Offline Dev Demo - FastAPI connection disabled"`.
  3. A 1-click `"Switch to Backend"` button is displayed right on the card to return to live backend mode.

### 3.5 Safe Settings Persistence
- Preferences saved in `SecureStorage` (environment, backend URL, auth mode) are respected and not overwritten if an operator has explicitly set them.
- Defaults apply cleanly when storage keys are absent (fresh installs).
- No passwords, tokens, or private secrets are exposed in logs or dialogs.

---

## 4. Test Evidence & Verification Results

### 4.1 Full Test Suite Execution (`flutter test`)
Executed from `c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop`:

```text
00:13 +84: All tests passed!
```
**Result:** **84 passed, 0 failed** across all 14 test suites in `shop_desktop`.

### 4.2 Key Focused Test Suites

1. **`test/settings_provider_test.dart` (8 tests):**
   - `Initializes with defaults when storage is empty` — PASSED (verifies `Environment.development`, `AuthenticationMode.productionBackend`, and `http://127.0.0.1:8000`).
   - `Loads saved environment and URL` — PASSED.
   - `setEnvironment saves value and clears URL` — PASSED.
   - `setAuthMode saves and updates AppConfig` — PASSED.
   - `setBackendUrl formats and saves URL` — PASSED.
   - `checkBackendConnection returns true on HTTP 200` — PASSED.
   - `checkBackendConnection returns false on HTTP error or client exception` — PASSED.
   - `resetToDefaults restores development and productionBackend defaults` — PASSED.

2. **`test/auth_test.dart` (14 tests):**
   - `Valid Shop login returns token` — PASSED.
   - `Customer account attempting Shop login throws error` — PASSED.
   - `Admin account attempting Shop login throws error` — PASSED.
   - `Invalid credentials returns 400 error` — PASSED.
   - `Backend unavailable throws error` — PASSED.
   - `Empty backend URL throws configuration exception` — PASSED.
   - `Backend authentication is the default mode with http://127.0.0.1:8000` — PASSED.
   - `Missing username or password sets error message` — PASSED.
   - `Successful backend login sets state to authenticated with token` — PASSED.
   - `Unavailable backend prevents false success and reports clear connection error` — PASSED.
   - `Explicit offline mode selection routes to LocalAuthService` — PASSED.
   - `Non-SHOP role rejected and prevents authentication` — PASSED.
   - `Successful logout removes token and sets state to unauthenticated` — PASSED.
   - `Existing authenticated session restoration` — PASSED.

3. **`test/auth_screens_test.dart` (9 tests):**
   - `LoginScreen displays default backend mode with 127.0.0.1:8000 and connection controls` — PASSED.
   - `Tapping configure connection opens settings dialog` — PASSED.
   - `Explicit offline mode shows clear disclaimer and switch to backend button` — PASSED.
   - `Empty fields show field-specific validation errors` — PASSED.
   - `Invalid email format shows validation error` — PASSED.
   - `Tapping Sign Up opens SignUpScreen and back returns to LoginScreen` — PASSED.
   - `SignUpScreen displays all 8 fields and disclaimers` — PASSED.
   - `SignUp validation detects empty fields` — PASSED.
   - `SignUp validation detects password mismatch` — PASSED.

4. **`test/local_auth_test.dart` (20 tests):**
   - All PBKDF2 cryptography, salted hashing, local account file isolation, corruption recovery, and local persistence tests continue to pass (20/20 PASSED).

### 4.3 Static Analysis (`flutter analyze`)
Executed from `c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop`:
- **Errors in modified code:** **0**
- **Warnings in modified code:** **0**
- **Existing project warnings/infos:** 39 pre-existing framework deprecation notices and infos in unchanged files (e.g. `WillPopScope`, `SimpleBarcodeScannerPage`, `use_super_parameters` in print execution and profile screens).

### 4.4 Live Backend Probe
Verified live FastAPI backend response at `http://127.0.0.1:8000/`:
```json
{"message":"Welcome to SecurePrint API"}
```
Confirmed HTTP 200 OK with instantaneous response.

---

## 5. Remaining Issues & Next Steps

1. **Pre-existing Framework Deprecations:**
   - Flutter 3.47+ deprecation warnings in untouched files (`WillPopScope` -> `PopScope` in `print_execution_dialog.dart`, `SimpleBarcodeScannerPage` in `secure_qr_scanner_screen.dart`, `RadioListTile` group value in Flutter 3.32+). These do not affect functionality or tests.
2. **Subsequent Feature Tasks (As Stated in System Requirements):**
   - Do not begin PDF page slicing or duplex/color printer driver integration until the current connection fix is accepted.

---

## 6. Exact Instructions to Run the Windows App

### Step 1: Ensure FastAPI Backend is Running
Open a terminal and start the FastAPI server:
```powershell
cd "c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\backend"
venv\Scripts\activate
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```
Verify the server is running by opening `http://127.0.0.1:8000/docs` in your browser or running:
```powershell
powershell -Command "(Invoke-WebRequest -Uri 'http://127.0.0.1:8000/' -UseBasicParsing).Content"
```
Output must be: `{"message":"Welcome to SecurePrint API"}`.

### Step 2: Run the Windows Shop Desktop App in Development Mode
Open a new terminal in the `shop_desktop` directory:
```powershell
cd "c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop"
flutter run -d windows
```

### Step 3: Verify the Connection on Launch
1. On startup, the Login Screen displays:
   - Status Badge: **Production Backend Mode (FastAPI)**
   - Target Host: **http://127.0.0.1:8000**
   - Environment: **DEVELOPMENT**
2. Click **Test** to immediately verify connectivity against the live backend (returns green check: *"Connected to FastAPI backend"*).
3. Sign in using an existing shop account in `secureprint.db` (e.g. `shop@test.com` or registered shop owner).
4. If the server is stopped, attempting to sign in displays a clear red alert: *"Unable to connect to SecurePrint server."* with zero false logins.
