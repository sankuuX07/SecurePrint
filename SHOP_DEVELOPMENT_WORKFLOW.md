# SecurePrint Shop — Fast Development & Testing Workflow

This guide details how to develop, test, and debug the **SecurePrint Shop Windows Desktop application** rapidly without repeatedly compiling or installing setup files.

---

## 1. Detected Framework & Architecture

- **Desktop Framework**: **Flutter Desktop for Windows (MSVC x64)**
- **Language / SDK**: Dart SDK `^3.13.2` / Flutter SDK (Target: Windows Desktop)
- **Application Directory**: `SecurePrint/shop_desktop`
- **Entry Point**: `lib/main.dart`
- **Output Architecture**: Portable Windows runtime folder containing `SecurePrint-Shop.exe`, `flutter_windows.dll`, `data/app.so`, and plugin dynamic libraries (`*.dll`).
- **Packaging System**: Inno Setup (`setup.iss`) targeting `build\windows\x64\runner\Release\*`.

> [!IMPORTANT]
> The compiled outputs in `build\windows\x64\runner\Release\` and `Debug\` are **fully portable standalone binaries**. You do **not** need to package or install an Inno Setup `.exe` to run, test, or inspect code changes.

---

## 2. Required Prerequisites

Ensure the following tools are installed and present in your system `PATH`:
1. **Flutter SDK**: Verify by running `flutter --version` in PowerShell.
2. **Visual Studio 2022 / Build Tools**: With the **"Desktop development with C++"** workload enabled.
3. **PowerShell**: Standard Windows terminal.

Verify your environment anytime:
```powershell
flutter doctor -v
```

---

## 3. Fast Development Workflow with Hot Reload

Flutter Desktop natively supports **Stateful Hot Reload** (`r`) and **Hot Restart** (`R`). This allows you to apply code changes to a running desktop app in **less than 1 second** without restarting the application or rebuilding binaries.

### Option A: Command Line Launch (Recommended)

1. Open PowerShell and navigate to the `shop_desktop` directory:
   ```powershell
   cd C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop
   ```
2. Launch the application in interactive development mode:
   ```powershell
   flutter run -d windows
   ```
3. While the application is running:
   - Press **`r`** to trigger **Hot Reload** (injects code updates immediately, preserves UI form state).
   - Press **`R`** to trigger **Hot Restart** (resets application state in ~1-2 seconds).
   - Press **`p`** to toggle the debug rendering overlay.
   - Press **`q`** to quit the session.

### Option B: Visual Studio Code / IDE (One-Key Debugging)

A launch configuration is configured at `.vscode/launch.json`:
1. Open the project root in VS Code / Antigravity IDE.
2. Press **`F5`** (or select **Run -> Start Debugging**).
3. The IDE attaches the Flutter debugger directly to `SecurePrint-Shop.exe`.
4. Saving any file (`Ctrl + S`) automatically applies Hot Reload.

---

## 4. Rebuild & Launch Without Installing

If you prefer to compile a standalone executable and launch it directly without an active debug console:

### Debug Build (Fastest compilation)
```powershell
cd C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop
flutter build windows --debug
& "build\windows\x64\runner\Debug\SecurePrint-Shop.exe"
```

### Release Build (Production-optimized binary)
```powershell
cd C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop
flutter build windows --release
& "build\windows\x64\runner\Release\SecurePrint-Shop.exe"
```

### Direct Execution of the Existing Release Binary
You can run the existing Release binary at any time with a single command:
```powershell
& "C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop\build\windows\x64\runner\Release\SecurePrint-Shop.exe"
```

---

## 5. Build Output Locations

| Build Type | Executable Location | Compiled AOT Code |
|---|---|---|
| **Debug** | `shop_desktop\build\windows\x64\runner\Debug\SecurePrint-Shop.exe` | `Debug\data\app.so` |
| **Release** | `shop_desktop\build\windows\x64\runner\Release\SecurePrint-Shop.exe` | `Release\data\app.so` |

Both folders contain all necessary supporting libraries (`flutter_windows.dll`, `flutter_secure_storage_windows_plugin.dll`, `pdfium.dll`, etc.). You can run `SecurePrint-Shop.exe` directly from either directory.

---

## 6. How to Test Login & Sign Up in Development

The application is preconfigured with **Local Development Mode** enabled by default.

### Step 1: Launch Application
```powershell
cd C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop
flutter run -d windows
```

### Step 2: Verify Initial Login Screen
- Screen opens to **Welcome Back** with the SecurePrint Shop icon.
- Shows the badge: `Local Development Mode (Offline)`.
- No server error banner is shown.

### Step 3: Test Sign Up
1. Click the text link: **`Don't have an account? Sign Up`**.
2. Enter valid test details:
   - **Owner / Full Name**: `Alice Tester`
   - **Shop Name**: `Alice Fast Print`
   - **Email Address**: `alice@test.local`
   - **Phone Number**: `9876543210`
   - **Password**: `TestPass123!` *(Notice the real-time strength bar updating)*
   - **Confirm Password**: `TestPass123!`
   - **Shop Address**: `42 Tech Park`
   - **City**: `Bengaluru`
3. Click **`Create Account`**.
4. A green confirmation banner displays, and the screen returns to Login with `alice@test.local` pre-filled.

### Step 4: Test Sign In
1. Enter the password `TestPass123!`.
2. Check `Remember email` and/or `Stay signed in`.
3. Click **`Sign In`**.
4. The application transitions into the main Shop dashboard showing the `Dev Preview` badge in the AppBar and the local development preview banner.

### Step 5: Test Session & Logout
1. In the left navigation rail, click **Settings**.
2. Scroll to the **Session** section.
3. Click **Logout** and confirm the dialog to return to the Login screen.

---

## 7. Local Test Account Storage & Safe Reset

### Storage Location
Local test accounts are stored in the Windows User Application Data directory:
```text
%APPDATA%\SecurePrintShop\local_accounts.json
```
Full path on your machine:
```text
C:\Users\sansk\AppData\Roaming\SecurePrintShop\local_accounts.json
```

### Security Details
- Passwords are encrypted using **salted PBKDF2-HMAC-SHA256** (100,000 iterations).
- No plaintext credentials or session secrets are ever stored in this file.

### How to Reset Test Accounts
To wipe only test accounts without affecting app settings, SQLite databases, or other files:

**Option 1: Delete the file (PowerShell)**
```powershell
Remove-Item "$env:APPDATA\SecurePrintShop\local_accounts.json" -Force -ErrorAction SilentlyContinue
```

**Option 2: Clear accounts to an empty array (PowerShell)**
```powershell
Set-Content -Path "$env:APPDATA\SecurePrintShop\local_accounts.json" -Value '{"version":1,"users":[]}'
```

---

## 8. Running Automated Tests

Run unit, cryptographic, and widget tests without launching any window:

### Run Entire Test Suite (68 Tests)
```powershell
cd C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop
flutter test
```

### Run Only Authentication & Screen Tests
```powershell
flutter test test/local_auth_test.dart test/auth_screens_test.dart test/auth_test.dart
```

---

## 9. When a Full Rebuild or Installer Rebuild is Required

### When Hot Reload / Hot Restart Suffices:
- Modifying UI layouts, screens, widgets, colors, typography.
- Updating business logic, providers, validation rules, or helpers.
- Fixing bug issues in `lib/`.
- **Turnaround time**: < 1 second.

### When a Rebuild (`flutter run` or `flutter build windows`) is Required:
- Updating dependencies in `pubspec.yaml` (`flutter pub get`).
- Modifying C++ runner code (`windows/runner/*`, `CMakeLists.txt`, `Runner.rc`).
- Adding new image/font asset declarations to `pubspec.yaml`.
- **Turnaround time**: ~20-60 seconds.

### When the Installer (`setup.iss`) Needs to be Rebuilt:
- **ONLY** when preparing a final release package for distribution to end-users or clients.
- **NEVER** required during active day-to-day development, bug fixing, or feature testing.
