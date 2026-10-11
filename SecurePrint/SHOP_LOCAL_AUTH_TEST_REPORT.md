# SecurePrint Shop — Local Authentication Test Report

## 1. Executive Summary

This report documents the implementation of the temporary local authentication subsystem, the redesigned Login screen, the newly created Sign Up registration screen, cryptographic password storage using salted PBKDF2-HMAC-SHA256, and mode separation in the SecurePrint Shop Windows desktop application.

All 68 unit, widget, and cryptographic tests passed with zero regressions. The production Windows executable has been compiled and verified.

---

## 2. Root Cause of the Initial Login Issue

### Identified Root Causes:
1. **Unconditional Backend Network Calls on Startup/Login**:
   - The original `AuthService.login()` directly issued HTTP POST requests to `${AppConfig.backendUrl}/api/v1/auth/login`.
   - When running the desktop application in offline or standalone test environments where no FastAPI backend process was running or `backendUrl` was empty, the `http.Client` encountered socket connection refusals or format exceptions.
   - The catch block in `AuthService` swallowed all socket exceptions and rethrew a generic `AuthServiceException('Unable to connect to SecurePrint server.')`.
2. **Persistent Error Banner**:
   - `AuthProvider._errorMessage` was retained and displayed on the initial login screen, presenting a permanent red error banner before the user could even attempt local credentials.
3. **Missing Sign Up & Navigation**:
   - The UI completely lacked a Sign Up route, registration screen, and local development account store.

---

## 3. Login Screen Changes

The Login screen (`lib/features/auth/login_screen.dart`) has been enhanced to match the SecurePrint Shop design specifications:
- **Branding & Header**:
  - Displays the SecurePrint Shop icon (`Icons.print_rounded`, 64px, themed blue).
  - Heading: `Welcome Back`.
  - Subtitle: `Sign in to your shop account`.
- **Mode Badge**:
  - Visual indicator chip displaying `Local Development Mode (Offline)` or `Production Backend Mode`.
- **Input Fields & Visibility Toggle**:
  - Email textfield with email-specific keyboard type and outline border.
  - Password textfield with interactive visibility toggle (eye icon button).
- **Client-Side Validation**:
  - Immediate field-specific validation:
    - Empty email: `"Please enter your email."`
    - Invalid email regex (`^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$`): `"Please enter a valid email address."`
    - Empty password: `"Please enter your password."`
  - Inline error text below fields that clears as the user types.
- **Session & Email Options**:
  - `Remember email` checkbox: saves/removes remembered email in `SecureStorage`.
  - `Stay signed in` checkbox: controls safe session persistence. When unchecked, tokens are held in-memory and app restarts open directly to the login screen.
- **Duplicate Submission Prevention**:
  - Submit button is disabled while authenticating.
  - Displays an inline `CircularProgressIndicator` while authentication is processing.
- **Navigation**:
  - Text link: `Don't have an account? Sign Up`.
  - Seamlessly pushes `SignUpScreen` and receives the newly registered email to pre-fill the email field.
- **Removed Hardcoded Error**:
  - `context.read<AuthProvider>().clearError()` is invoked in `initState` to ensure the screen starts clean.
  - Local authentication mode never issues network requests to the server, eliminating false backend error banners.

---

## 4. Sign Up Screen Implementation

A complete registration screen has been created at `lib/features/auth/sign_up_screen.dart`:
- **Heading & Subtitle**:
  - Heading: `Create Shop Account`.
  - Subtitle: `Register a local test account for development`.
- **Registration Fields**:
  1. `Owner / Full Name *` (`_ownerNameController`)
  2. `Shop Name *` (`_shopNameController`)
  3. `Email Address *` (`_emailController`)
  4. `Phone Number *` (`_phoneController`)
  5. `Password *` (`_passwordController` with visibility toggle)
  6. `Confirm Password *` (`_confirmPasswordController` with visibility toggle)
  7. `Shop Address *` (`_addressController`)
  8. `City *` (`_cityController`)
- **Validation**:
  - All 8 fields require non-empty input.
  - Email format validation.
  - Phone number length validation (at least 7 digits).
  - Password confirmation check: verifies `password == confirmPassword`.
  - Real-time password strength indicator: checks length (>= 8, >= 12), digits, letters, and special symbols with animated strength meter and guidance.
  - Duplicate email detection: checks for existing account case-insensitively and returns `"An account with this email address already exists."`.
- **Disclaimers & Safety**:
  - Explicit development disclaimer:
    `Notice: Local test accounts are stored securely on this computer only. Live server synchronization, admin approval, and cloud printing will be activated when connecting to the production backend.`
  - Does NOT claim account has been approved by an administrator.
- **Navigation & Submission**:
  - `Create Account` button with loading state.
  - Link: `Already have an account? Sign In` (pops back to Login screen).

---

## 5. Local Storage & Password Hashing Architecture

### Local Account Storage
- **Location**:
  - Windows User Application Data directory: `%APPDATA%\SecurePrintShop\local_accounts.json`
  - Resolves via `getApplicationSupportDirectory()` with fallback to `Platform.environment['APPDATA']`.
  - Restricts access to the operating system user profile. Does **NOT** store data in the application installation directory.
- **Persistence Method**:
  - JSON format with versioning and UTC timestamp metadata.
  - Atomic disk writing via `.tmp` write and rename to prevent file corruption during write interruptions.
  - Safe error recovery: corrupted files are backed up to `.bak` and storage resets safely without leaking file paths or stack traces.

### Password Hashing Algorithm
- **Algorithm**: Standard PBKDF2 with PRF = HMAC-SHA256 (RFC 2898 / PKCS #5 v2.0).
- **Salt**: 16 bytes of cryptographically secure random data from `Random.secure()`.
- **Iterations**: 100,000 iterations (OWASP recommendation).
- **Derived Key Length**: 32 bytes (256 bits).
- **Format**: `pbkdf2_sha256$100000$<base64_salt>$<base64_hash>`.
- **Verification**: Constant-time byte-by-byte comparison (`constantTimeEquals`) to prevent timing side-channel attacks.
- **Security Constraints Enforced**:
  - Passwords are never stored in plaintext.
  - Passwords, hashes, and session tokens are never printed or logged.
  - No credentials in source code or installer configs.

---

## 6. Authentication Mode Separation & Service Abstraction

### Clean Interface
Defined in `lib/services/auth_service_interface.dart`:
```dart
abstract class IAuthService {
  Future<AuthResult> login(String email, String password);
  Future<void> register(ShopRegistrationData data);
}
```

### Implementations:
1. `LocalAuthService` (`lib/services/local_auth_service.dart`):
   - Handles local test accounts in `%APPDATA%\SecurePrintShop\local_accounts.json`.
   - Never accesses backend networks.
   - Generates local tokens prefixed with `local_dev_`.
2. `BackendAuthService` (`lib/services/backend_auth_service.dart`):
   - Connects to authoritative FastAPI endpoints (`POST /api/v1/auth/login`, `POST /api/v1/auth/register`).
3. `AuthService` (`lib/services/auth_service.dart`):
   - Preserved for full backward compatibility with existing tests.

### Separation Enforcement:
- Configured via `AppConfig.authMode`:
  - `AuthenticationMode.localDevelopment`
  - `AuthenticationMode.productionBackend`
- Configurable and switchable in the UI via **Settings -> General Configuration -> Authentication Mode**.
- Local authentication accounts are tagged `isLocal = true`.
- In local development mode:
  - Protected live operational features (live print job sync, document downloads, QR scanner verification) display an informational preview banner and are safely disabled.
  - No backend connection errors appear when operating offline.
  - Production backend failures **never** silently fall back to local authentication.

---

## 7. Test Results (All 18 Requirements Verified)

All 18 required test points were executed and verified:

| # | Requirement | Verification Method | Result |
|---|---|---|---|
| 1 | App opens to Sign In | `auth_screens_test.dart` (Finds Welcome Back & branding) | **PASSED** |
| 2 | Sign Up link opens registration screen | `auth_screens_test.dart` (Taps Sign Up, checks SignUpScreen) | **PASSED** |
| 3 | Sign In link returns to login screen | `auth_screens_test.dart` (Taps Sign In link, verifies pop) | **PASSED** |
| 4 | Empty fields are rejected | `auth_screens_test.dart` (Checks field-specific error messages) | **PASSED** |
| 5 | Invalid email is rejected | `auth_screens_test.dart` (Checks email regex validation) | **PASSED** |
| 6 | Password mismatch is rejected | `auth_screens_test.dart` (Tests mismatch between password fields) | **PASSED** |
| 7 | New local test account is created | `local_auth_test.dart` (Tests registration in local file store) | **PASSED** |
| 8 | Duplicate email is rejected | `local_auth_test.dart` (Tests duplicate check with case insensitivity) | **PASSED** |
| 9 | Correct credentials sign in | `local_auth_test.dart` (Verifies valid login and session token) | **PASSED** |
| 10 | Incorrect password is rejected | `local_auth_test.dart` (Verifies rejection with generic error) | **PASSED** |
| 11 | Unknown email is rejected | `local_auth_test.dart` (Verifies rejection with generic error) | **PASSED** |
| 12 | Logout works | `local_auth_test.dart` (Verifies session clearing and token wiping) | **PASSED** |
| 13 | Restart preserves registered local account | `local_auth_test.dart` (Verifies file persistence across reloads) | **PASSED** |
| 14 | Restart does not silently restore session unless configured | `local_auth_test.dart` (Verifies `rememberSession = false` behavior) | **PASSED** |
| 15 | Local account storage contains no plaintext passwords | `local_auth_test.dart` (Inspects JSON content for PBKDF2 hash prefix) | **PASSED** |
| 16 | Backend-unavailable errors do not appear in local mode | `local_auth_test.dart` & UI tests | **PASSED** |
| 17 | Local authentication cannot access protected backend ops | Tested in `DashboardProvider`, `PrintJobsProvider`, `ShopQrProvider` | **PASSED** |
| 18 | Existing dashboard and other modules have no regressions | Ran complete project test suite (46 existing tests + 22 new) | **PASSED (68/68)** |

---

## 8. Build Result and Executable Path

The application was built and linked using Flutter MSVC Windows toolchain.

- **Build Target**: Windows x64 Release
- **Runner Executable**:
  `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop\build\windows\x64\runner\Release\SecurePrint-Shop.exe`
- **Runner Size**: `93,184 bytes`
- **Runner Re-link Timestamp**: `11-10-2026 23:12:04`
- **AOT Compiled Dart Payload**:
  `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop\build\windows\x64\runner\Release\data\app.so`
- **AOT Size**: `11,010,952 bytes`
- **AOT Timestamp**: `11-10-2026 23:02:06`

---

## 9. Security Limitations & Production Transition Steps

### Security Limitations in Current Development Phase
- Local test accounts are stored on the local filesystem (`%APPDATA%\SecurePrintShop\local_accounts.json`). While securely hashed, this store is intended strictly for local development and offline workflow testing.
- Local test accounts do not possess server-side authorization or JWT validation from the FastAPI backend.
- Local tokens (`local_dev_*`) are not recognized by the backend and cannot be used against `/api/v1/*` endpoints.

### Steps for Future FastAPI Integration
1. Configure backend URL in Settings or `.env` (`http://127.0.0.1:8000` or production URL).
2. Toggle Authentication Mode in Settings to `PRODUCTION BACKEND (FASTAPI)`.
3. In production mode, registration calls `POST /api/v1/auth/register` with shop pricing parameters, creating a pending shop user in SQLite/PostgreSQL.
4. Administrator logs in and activates the shop profile.
5. Shop owner signs in via `POST /api/v1/auth/login`, receiving a valid backend JWT.
6. The backend JWT authorizes full cloud operations (document downloads, print job polling, and identity QR generation).
