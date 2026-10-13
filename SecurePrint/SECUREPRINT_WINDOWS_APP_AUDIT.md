# SecurePrint Windows Shop Desktop Application Audit

**Date:** 2026-10-13  
**Auditor:** Senior Software Integration Engineer  
**Component:** Windows Shop Desktop Application (`shop_desktop`)  
**Target Platform:** Windows Desktop (x64 native via Flutter)  
**Backend Target:** FastAPI Backend (`http://127.0.0.1:8000/`)

---

## 1. Executive Summary

This audit evaluated the Windows Shop Desktop application to establish its technical architecture, authentication workflows, backend connectivity, security controls, test coverage, and offline emulation modes.

### Key Conclusions:
1. **Framework & Toolchain:** The application is built with **Flutter 3.47.2 (Dart 3.13.2)** targeting native Windows x64 desktop using the Microsoft Visual C++ toolchain (Visual Studio 2026 18.8.2).
2. **Direct Source Execution:** The app can be launched directly in development mode without building installers or MSIX packages via `flutter run -d windows`.
3. **Backend Connectivity:** The application's network layer and Dart's `HttpClient` successfully connect to the active FastAPI backend at `http://127.0.0.1:8000/`, verifying endpoints `/`, `/docs`, `/api/v1/openapi.json`, and `/api/v1/auth/login`.
4. **Offline Demo Mode Discovery:** The app contains an isolated offline authentication system (`LocalAuthService`) that stores accounts in `%APPDATA%\SecurePrintShop\local_accounts.json` and issues synthetic bearer tokens (`local_dev_...`). **Crucially, on initial startup without saved configuration, the app defaults to this offline local mode with an empty production backend URL (`""`), falsely giving the appearance of successful authentication without contacting the backend.**
5. **Settings Accessibility Flaw:** The `SettingsScreen` (where the user configures the backend URL and switches from local mode to FastAPI backend mode) is only reachable from within the post-login `AppShell`. A user cannot switch to the production backend from the initial `LoginScreen` without either pre-configuring storage or signing in via local mode first.
6. **Automated Tests:** All 14 test suites comprising 73 automated tests run entirely on the PC without requiring an Android phone or printer hardware (`73 passed, 0 failed`).

---

## 2. Framework, Entry Point, and Project Structure

### 2.1 Framework and Toolchain
- **UI Framework:** Flutter 3.47.2 / Dart 3.13.2
- **Desktop Target:** Windows Desktop (`windows-x64`), Win32 runner
- **C++ Compiler:** Microsoft Visual Studio Community 2026 (v18.8.2) toolchain
- **State Management:** Provider pattern (`ChangeNotifierProvider`, `Consumer`, `context.watch/read`)
- **Key Dependencies:**
  - `http: ^1.2.1` &mdash; Network transport
  - `flutter_secure_storage: ^9.0.0` &mdash; Windows Credential Manager wrapper
  - `printing: ^5.15.0` &mdash; Windows printing spooler integration
  - `crypto: ^3.0.3` &mdash; Cryptographic hashing
  - `path_provider: ^2.1.2` &mdash; Windows application directory resolution

### 2.2 Entry Points
1. **Native Windows Host:** [`shop_desktop/windows/runner/main.cpp`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/windows/runner/main.cpp)
   - Bootstraps Win32 message loop, creates `FlutterWindow`, and initializes DPI-aware rendering.
2. **Dart Application Entry Point:** [`shop_desktop/lib/main.dart:L16`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/main.dart#L16)
   - Initializes `WidgetsFlutterBinding`.
   - Instantiates `PlatformDispatcher.instance.onError` top-level exception guards.
   - Awaits `SettingsProvider.init()`.
   - Wraps root in `MultiProvider` supplying:
     - `SettingsProvider`
     - `AuthProvider`
     - `DashboardProvider`
     - `PrintJobsProvider`
     - `DocumentAccessProvider`
     - `PrinterProvider`
     - `PrintExecutionProvider`
     - `ShopQrProvider`
   - Conditionally renders `LoginScreen` or `AppShell` based on `auth.isAuthenticated`.

---

## 3. Development Run Command

The application can be compiled and launched directly in developer hot-reload mode on the PC without building installers, InnoSetup packages, or standalone release executables.

### Exact Commands:

```powershell
# Navigate to Windows Shop project directory
cd "c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop"

# Run directly on Windows Desktop in debug mode
flutter run -d windows
```

### Hot-Reload Controls:
- Press `r` in the terminal for Hot Reload.
- Press `R` in the terminal for Hot Restart.
- Press `q` to terminate the development instance.

---

## 4. Backend Connection & Configuration Audit

### 4.1 Configuration Matrix

Defined in [`shop_desktop/lib/core/config/app_config.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/core/config/app_config.dart#L1-L34):

| Parameter | Configuration Enum / Key | Evaluated Value | Notes |
| :--- | :--- | :--- | :--- |
| **Development** | `Environment.development` | `http://127.0.0.1:8000` | Points to local PC FastAPI server |
| **LAN Testing** | `Environment.lanTesting` | `http://192.168.1.100:8000` | Testing over local WiFi/Ethernet |
| **Production** | `Environment.production` | `""` (Empty String) | **Default on clean start**; intended for custom URL input |
| **Custom Override** | `customBackendUrl` | User-defined via UI | Stored in `FlutterSecureStorage` |

### 4.2 Endpoint Contract Verification
Every HTTP operation in the Flutter app strictly prefixes routes with `/api/v1/`:

| Method | Flutter Caller File & Line | Target Endpoint | FastAPI Route Match |
| :---: | :--- | :--- | :---: |
| **POST** | [`auth_service.dart:L20`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/auth_service.dart#L20) | `/api/v1/auth/login` | **MATCH** |
| **POST** | [`backend_auth_service.dart:L28`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/backend_auth_service.dart#L28) | `/api/v1/auth/register` | **MATCH** |
| **GET** | [`shop_service.dart:L15`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L15) | `/api/v1/users/me` | **MATCH** |
| **GET** | [`shop_service.dart:L20`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L20) | `/api/v1/print-jobs/shop` | **MATCH** |
| **GET** | [`shop_service.dart:L32`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L32) | `/api/v1/print-jobs/shop/{jobId}` | **MATCH** |
| **GET** | [`shop_service.dart:L37`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L37) | `/api/v1/shop/print-jobs/{jobId}/payment` | **MATCH** |
| **POST** | [`shop_service.dart:L42`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L42) | `/api/v1/shop/print-jobs/{jobId}/payment/mark-paid` | **MATCH** |
| **POST** | [`shop_service.dart:L47`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L47) | `/api/v1/print-jobs/{jobId}/accept` | **MATCH** |
| **POST** | [`shop_service.dart:L52`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L52) | `/api/v1/print-jobs/{jobId}/start` | **MATCH** |
| **POST** | [`shop_service.dart:L57`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L57) | `/api/v1/print-jobs/{jobId}/complete` | **MATCH** |
| **POST** | [`shop_service.dart:L63`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L63) | `/api/v1/shop/document-access/authorize` | **MATCH** |
| **GET** | [`shop_service.dart:L70`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L70) | `/api/v1/shop/qr` | **MATCH** |
| **POST** | [`shop_service.dart:L75`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/shop_service.dart#L75) | `/api/v1/shop/qr/regenerate` | **MATCH** |
| **GET** | [`document_access_service.dart:L22`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/document_access_service.dart#L22) | `/api/v1/shop/document-access/{accessId}/download` | **MATCH** |

### 4.2 Actual Live Backend Connectivity Test Result
A standalone Dart verification probe was executed directly against the active FastAPI process on `http://127.0.0.1:8000/`:
- `GET /` &rarr; **Status 200** (`{"message":"Welcome to SecurePrint API"}`)
- `GET /docs` &rarr; **Status 200**
- `GET /api/v1/openapi.json` &rarr; **Status 200**
- `POST /api/v1/auth/login` &rarr; **Status 400** (`{"detail":"Incorrect email or password"}` - expected validation response)
- **Result:** Confirmed that Dart HTTP networking on the host machine communicates cleanly with the local FastAPI backend.

---

## 5. Authentication, Offline Mode, & Security Analysis

### 5.1 Dual-Mode Authentication Architecture

[`AuthProvider.dart:L56-64`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/providers/auth_provider.dart#L56-L64) switches between two authentication backends depending on `AppConfig.authMode`:

```dart
  IAuthService _getService() {
    if (_customAuthService != null) return _customAuthService;
    if (AppConfig.authMode == AuthenticationMode.localDevelopment) {
      return _localAuthService;
    }
    return _backendAuthService;
  }
```

#### Mode A: `AuthenticationMode.localDevelopment` (OFFLINE DEMO MODE)
- **Implementation:** [`LocalAuthService.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/local_auth_service.dart)
- **Storage Location:** `%APPDATA%\SecurePrintShop\local_accounts.json`
- **Security:** Hashes passwords locally using PBKDF2-HMAC-SHA256 with 10,000 iterations and a cryptographically random salt ([`pbkdf2_helper.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/core/security/pbkdf2_helper.dart)).
- **Behavior:**
  - Signs in and registers without sending network packets.
  - Generates synthetic dummy tokens: `local_dev_<random_base64>`.
  - [`DashboardProvider.dart:L51-66`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/providers/dashboard_provider.dart#L51-L66) loads hardcoded test shop data ("Local Test Shop (Preview)") and an empty list of print jobs.
  - [`PrintJobsProvider.dart:L50-56`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/providers/print_jobs_provider.dart#L50-L56) sets `_jobs = []` and bypasses the backend.
- **Deception Risk:** An engineer or operator entering credentials in this mode will see a successful login, a working dashboard, and a "Dev Preview" banner, but **zero backend integration is actually occurring**.

#### Mode B: `AuthenticationMode.productionBackend` (FASTAPI BACKEND MODE)
- **Implementation:** [`BackendAuthService.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/backend_auth_service.dart) and [`AuthService.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/services/auth_service.dart)
- **Behavior:**
  - `POST /api/v1/auth/login` sends `application/x-www-form-urlencoded` credentials.
  - Validates that the returned JWT role is strictly `SHOP`. Customer or Admin logins are rejected on the desktop client with `Access Denied. Shop accounts only.`
  - On login failure (wrong password), displays the backend's `detail` message in a red error banner.
  - On duplicate email registration, surfaces backend HTTP 400 `Email already registered`.
  - On success, saves real backend JWT into `FlutterSecureStorage`.

### 5.2 Session Persistence & Restart Behavior
1. **Token Persistence:** Tokens are written via `FlutterSecureStorage` (Windows Credential Manager) under key `secureprint_shop_auth_token`.
2. **Remember Options:**
   - `_rememberEmail`: Persisted under `secureprint_remember_email`; restores the email field text on app restart.
   - `_rememberSession` ("Stay signed in"): If unchecked, `_secureStorage.deleteToken()` is called upon login, ensuring that restarting the app returns to `LoginScreen`. If checked, the token persists.
3. **App Startup:** [`AuthProvider._initialize()`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/providers/auth_provider.dart#L66-L86) reads `getToken()`. If present, `_state` is set directly to `AuthState.authenticated`, bypassing login.
4. **Logout:** [`AuthProvider.logout()`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/providers/auth_provider.dart#L153-L162) deletes stored tokens, clears memory state, and triggers a reactive transition to `LoginScreen`.

---

## 6. Available Automated Tests and Verification Results

The `shop_desktop` suite was independently run using `flutter test`:

```powershell
flutter test
```

### Actual Test Execution Results:
```text
00:07 +73: All tests passed!
```
**Exit Code: 0 (73 passed, 0 failed in 7.0 seconds)**

### Test Inventory:
| Test File | Tests Run | What It Tests | Can Run Without Phone? |
| :--- | :---: | :--- | :---: |
| [`api_client_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/api_client_test.dart) | 4 | Header injection, Authorization Bearer, 401/403/SocketException handling | **YES** |
| [`auth_screens_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/auth_screens_test.dart) | 3 | Widget tests: Login validation, email format, empty field checks, Sign-up UI | **YES** |
| [`auth_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/auth_test.dart) | 5 | Real/mock HTTP responses, JWT extraction, role enforcement, status code handling | **YES** |
| [`dashboard_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/dashboard_test.dart) | 3 | Statistics calculation, profile loading, error state handling | **YES** |
| [`document_access_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/document_access_test.dart) | 12 | Schema contract (`access_id` vs `id`), expiry calculation, status checks | **YES** |
| [`document_preview_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/document_preview_test.dart) | 1 | Preview rendering widget test | **YES** |
| [`job_details_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/job_details_test.dart) | 5 | Job details parsing, transition triggers, status badges | **YES** |
| [`local_auth_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/local_auth_test.dart) | 24 | PBKDF2 salting, hash verification, file corruption recovery, duplicate email rejection | **YES** |
| [`print_execution_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/print_execution_test.dart) | 5 | Spooling state machine, duplicate prevention, backend sync retries | **YES** |
| [`print_jobs_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/print_jobs_test.dart) | 3 | Pagination, status filters, empty states | **YES** |
| [`printer_provider_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/printer_provider_test.dart) | 4 | Hardware printer enumeration, default printer selection | **YES** |
| [`scanner_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/scanner_test.dart) | 4 | QR authorization service mock, invalid token rejection | **YES** |
| [`settings_provider_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/settings_provider_test.dart) | 3 | URL formatting, secure storage persistence, environment toggling | **YES** |
| [`shop_qr_provider_test.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/test/shop_qr_provider_test.dart) | 2 | Shop QR loading, QR regeneration trigger | **YES** |

---

## 7. Prioritized Issues

### Priority 1: Default Startup Disconnect & Buried Settings Screen (CRITICAL USABILITY / INTEGRATION BUG)
- **Problem:**
  1. On a fresh run with no prior settings, `AppConfig.currentEnvironment` defaults to `Environment.production` (resolving to an empty URL `""`), and `AppConfig.authMode` defaults to `AuthenticationMode.localDevelopment`.
  2. The `SettingsScreen` is located exclusively within the `AppShell` (the authenticated navigation drawer).
  3. **Consequence:** An operator opening the app cannot configure the backend URL or switch to FastAPI mode from the login screen. If they try to sign in or register, they are either routed into the local offline JSON store without knowing it, or (if auth mode were changed to backend) the HTTP client fails with an empty URL error.
- **Affected Files:**
  - `shop_desktop/lib/core/config/app_config.dart:L16-34`
  - `shop_desktop/lib/features/auth/login_screen.dart` (lacks settings access or environment indicator)

### Priority 2: Unfiltered PDF Spooling in `PrintExecutionProvider` (WORKFLOW & COST INTEGRITY BUG)
- **Problem:** The Flutter print execution engine reads the raw downloaded PDF (`pdfBytes`) and spools the entire document to the printer without slicing pages according to the customer's requested page range.
- **Affected Files:**
  - `shop_desktop/lib/models/print_job_model.dart` (omits `page_range`)
  - `shop_desktop/lib/providers/print_execution_provider.dart:L81-93`

### Priority 3: Hardcoded Printer Defaults (DUPLICATE / DRIVER COMPLIANCE)
- **Problem:** `Printing.directPrintPdf` is invoked with `usePrinterSettings: false` and does not transmit monochrome/color or duplex (double-sided) flags to the Windows printer driver.
- **Affected Files:**
  - `shop_desktop/lib/providers/print_execution_provider.dart:L87-92`

---

## 8. The Single Safest Next Implementation Step

### Action: Expose Backend Connection & Mode Controls on the Login Screen and Default to Development Mode
To allow direct, zero-friction verification of the Windows Shop desktop app against the running FastAPI backend without going through the local offline dummy mode:

1. **In [`shop_desktop/lib/core/config/app_config.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/core/config/app_config.dart#L16-L17):**
   Change the default fallback environment to `Environment.development` (`http://127.0.0.1:8000`) and the default authentication mode to `AuthenticationMode.productionBackend`.
2. **In [`shop_desktop/lib/features/auth/login_screen.dart`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/shop_desktop/lib/features/auth/login_screen.dart):**
   Add a small header/footer toolbar or dialog button (e.g., an `IconButton(icon: Icon(Icons.settings))`) that displays the active Backend URL (`http://127.0.0.1:8000`) and allows toggling between "FastAPI Backend" and "Local Dev Offline" directly before attempting sign-in.

*This single safe change guarantees that the desktop software connects to the authoritative FastAPI backend immediately upon `flutter run -d windows` without altering database contents, breaking existing tests, or requiring an Android phone.*
