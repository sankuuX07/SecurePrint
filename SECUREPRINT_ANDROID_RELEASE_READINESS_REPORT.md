# SecurePrint Android Release Readiness Report

**Date:** 2026-10-13  
**Auditor:** Senior Android & Security Integration Engineer  
**Scope:** Android Build Configuration, Application Identity, Signing Architecture, API Base URL, Permissions, Token/Document Privacy & Logging Hygiene, Compilation & Test Verification.  
**Strict Safety Constraints Enforced:**
- Physical device is unavailable; no physical-device networking, runtime login, camera QR scanning, or device execution was claimed or performed.
- No app installed or uninstalled.
- No device storage cleared.
- No signing keystores generated or replaced.
- Backend database and uploaded customer files completely untouched.
- Existing Android data-preservation report ([`SECUREPRINT_ANDROID_DATA_PRESERVATION_REPORT.md`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SECUREPRINT_ANDROID_DATA_PRESERVATION_REPORT.md)) reused without repeating full audits.

---

## 1. Executive Summary & Readiness Verdict

| Item | Status | Finding Summary |
| :--- | :---: | :--- |
| **Debug Build Compilation** | **READY** | Verified compiled `app-debug.apk` (45,182,776 bytes) signed with Android Debug keystore (RSA 2048, APK Signature Scheme v2). |
| **Release Build Compilation** | **VERIFIED (COMPILING)** | `./gradlew.bat assembleRelease` executes cleanly (47 tasks, `BUILD SUCCESSFUL in 2m 3s`), producing `app-release-unsigned.apk` (37,329,376 bytes). |
| **Release Signing Configuration** | **NOT CONFIGURED** | `buildTypes.release` has **no `signingConfig`**. The generated release APK is **unsigned** (`DOES NOT VERIFY`, Missing `META-INF/MANIFEST.MF`) and cannot be installed on any device or emulator. |
| **API Base URL** | **DEVELOPMENT ONLY** | Hardcoded to `http://127.0.0.1:8000/` (for USB ADB reverse tethering) and `http://10.0.2.2:8000/` (for emulator). Neither is suitable for production. |
| **Cleartext HTTP Traffic** | **ENABLED** | `android:usesCleartextTraffic="true"` is enabled in [`AndroidManifest.xml`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/AndroidManifest.xml#L18). Required for local development HTTP, but unacceptable for production HTTPS. |
| **Credential Storage at Rest** | **SECURE** | Uses `EncryptedSharedPreferences` with `MasterKeys.AES256_GCM_SPEC` in [`SessionManager.kt`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/java/com/example/secureprint/data/auth/SessionManager.kt#L31-L47). No hardcoded secrets or passwords found in codebase or manifest. |
| **Logcat Exposure Risk** | **ACTION REQUIRED** | [`RetrofitClient.kt`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/java/com/example/secureprint/data/api/RetrofitClient.kt#L28-L34) runs `HttpLoggingInterceptor` at `Level.BODY` unconditionally across all build types. While headers redact `Authorization`, response/request bodies expose plain-text passwords and JWT tokens in Logcat. |
| **Physical Phone State** | **DEVICE UNAVAILABLE** | Phone is unavailable; previous signature conflict (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) remains pending safe resolution once hardware is connected. |

---

## 2. Android Build Configuration & Identity Audit

Inspection of [`app/build.gradle.kts`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/build.gradle.kts) and `aapt2 dump badging`:

- **Application ID / Package Name:** `com.example.secureprint`
- **Namespace:** `com.example.secureprint`
- **Compile SDK:** `37` (Android 15+)
- **Target SDK:** `37`
- **Min SDK:** `24` (Android 7.0 Nougat)
- **Version Code:** `1`
- **Version Name:** `1.0`
- **Native ABIs Merged:** `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`
- **Launcher Activity:** `com.example.secureprint.MainActivity` (Exported: `true`, Category: `LAUNCHER`)
- **FileProvider Authority:** `com.example.secureprint.fileprovider` mapping `@xml/file_paths` (`<cache-path name="secure_docs" path="secure_docs/" />`)

### Declared & Merged Permissions
From [`AndroidManifest.xml`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/AndroidManifest.xml) and package badging:
1. `android.permission.INTERNET`: Core networking for FastAPI communication.
2. `android.permission.CAMERA`: Hardware camera permission for scanning QR codes via CameraX and ML Kit / ZXing.
3. `android.permission.ACCESS_NETWORK_STATE`: Merged from AndroidX libraries for network connectivity status.
4. `com.example.secureprint.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`: Merged security permission for internal broadcasts.

No dangerous unneeded permissions (such as `READ_EXTERNAL_STORAGE` or `WRITE_EXTERNAL_STORAGE`) are requested; file picking is handled securely via the system `ActivityResultContracts.GetContent()` picker.

---

## 3. Signing Configuration Audit: Debug vs. Release

### Debug Build Type
- **Configuration:** Handled implicitly by Android Gradle Plugin (AGP).
- **Keystore:** Default Android debug keystore (`%USERPROFILE%\.android\debug.keystore`).
- **Signature Verification:**
  ```text
  apksigner verify --verbose --print-certs app-debug.apk
  Verifies: true
  Scheme v1: false | Scheme v2: true | Scheme v3: false
  Signer: C=US, O=Android, CN=Android Debug
  Certificate SHA-256: 3e0f72303054e53fb9abae8115b2c96f3961977d33c492b7e614c5ebd1aa2244
  Key Algorithm: RSA 2048
  ```

### Release Build Type
- **Current `buildTypes.release` in `app/build.gradle.kts`:**
  ```kotlin
  buildTypes {
      release {
          isMinifyEnabled = false
          proguardFiles(
              getDefaultProguardFile("proguard-android-optimize.txt"),
              "proguard-rules.pro"
          )
      }
  }
  ```
- **Signing Status:** **MISSING / UNSIGNED**.
- **Verification Result:**
  ```text
  apksigner verify --verbose app-release-unsigned.apk
  DOES NOT VERIFY
  ERROR: Missing META-INF/MANIFEST.MF
  ```
- **Constraint Adherence:** In accordance with instructions, **no keystore was generated or replaced**. Release signing must be configured only when the organization's official release keystore and credentials are provided.

---

## 4. API Base URL & Networking Architecture Audit

### Current Networking Implementation
From [`RetrofitClient.kt`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/java/com/example/secureprint/data/api/RetrofitClient.kt#L10-L21):
```kotlin
object RetrofitClient {
    private const val USE_PHYSICAL_DEVICE = true
    private const val PHYSICAL_DEVICE_IP = "127.0.0.1"

    private val BASE_URL = if (USE_PHYSICAL_DEVICE) {
        "http://$PHYSICAL_DEVICE_IP:8000/"
    } else {
        "http://10.0.2.2:8000/"
    }
```

### Confirmation: ADB Reverse is NOT a Production Server URL
1. **Mechanism of `127.0.0.1:8000`:** Over USB ADB tethering, the command `adb reverse tcp:8000 tcp:8000` binds the Android device's local loopback port 8000 to the developer PC's host port 8000.
2. **Failure in Production:** On a standalone device not connected via USB with `adb reverse` active, `127.0.0.1:8000` refers strictly to the mobile phone itself. Because the phone does not run the FastAPI backend, every HTTP request immediately fails with `java.net.ConnectException: Connection refused`.
3. **Protocol Insecurity:** The current URL uses cleartext `http://` instead of encrypted `https://`. In production, Android enforces TLS encryption by default unless `android:usesCleartextTraffic="true"` is set.
4. **Resolution Requirement:** Before any public or staging release, `BASE_URL` must be parameterized (via Gradle `buildConfigField` or `flavorDimensions`) to point to a production HTTPS domain (e.g., `https://api.secureprint.com/`), and `android:usesCleartextTraffic` should be disabled or restricted via `network_security_config.xml`.

---

## 5. Sensitive Data Exposure & Logging Hygiene Audit

### Storage & Codebase Inspection
1. **Hardcoded Secrets & API Keys:**
   - Grep scans across `app/src/main/` for `password`, `secret`, and `api_key` yielded 0 hardcoded credentials or backdoor tokens.
2. **Storage at Rest:**
   - Session tokens and user roles are stored in `secureprint_prefs` using Jetpack `EncryptedSharedPreferences` backed by Android Keystore (`MasterKeys.AES256_GCM_SPEC`).
   - Customer document binaries are never stored long-term in app internal files. The temporary cache in `context.cacheDir/secure_docs` is transient and purgeable via `clearSecureCache()`.

### Critical Finding: OkHttp Logcat Leakage
In [`RetrofitClient.kt`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/java/com/example/secureprint/data/api/RetrofitClient.kt#L28-L34):
```kotlin
    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
            redactHeader("Authorization")
        })
        .addInterceptor(com.example.secureprint.data.auth.AuthInterceptor())
        .build()
```
- **Positive:** `redactHeader("Authorization")` prevents the `Authorization: Bearer <jwt>` HTTP header from appearing in system logs.
- **Vulnerability:** `HttpLoggingInterceptor` is configured with `Level.BODY` **unconditionally** across all builds (including Release).
- **Impact:**
  - `POST /api/v1/auth/login` and `POST /api/v1/auth/register`: The request JSON body containing raw user passwords is printed to Android Logcat.
  - Authentication responses: The response JSON body containing `access_token` and `refresh_token` is printed to Logcat.
  - Document uploads / responses: Raw payload data and sensitive metadata may be dumped into logs.
- **Remediation for Release:** For release readiness, HTTP logging must be guarded by build type (e.g., `if (BuildConfig.DEBUG) Level.BODY else Level.NONE`) and sensitive body payloads should never be logged in production.

---

## 6. Compilation & Test Verification Results

### 1. JVM Unit Tests
Command executed:
```powershell
.\gradlew.bat testDebugUnitTest
```
- **Result:** `BUILD SUCCESSFUL in 2s`
- **Tasks:** 24 actionable tasks (24 up-to-date)
- **Test Classes Evaluated:** `AuthInterceptorTest`, `ExampleUnitTest`.

### 2. Release Assembly Compilation
Command executed:
```powershell
.\gradlew.bat assembleRelease
```
- **Result:** `BUILD SUCCESSFUL in 2m 3s`
- **Tasks:** 47 actionable tasks (46 executed, 1 up-to-date)
- **Compiler Warnings:** Noted standard Jetpack Compose icon deprecation warnings (`Icons.Filled.ArrowBack`, `ReceiptLong`) and `statusBarColor` deprecation; 0 fatal errors.
- **Lint Vital Analysis:** `:app:lintVitalAnalyzeRelease` and `:app:lintVitalReportRelease` completed with 0 blocking release-stopping issues.

### 3. Generated Artifact Comparison

| Metric / Attribute | Debug Artifact (`app-debug.apk`) | Release Artifact (`app-release-unsigned.apk`) |
| :--- | :--- | :--- |
| **Full File Path** | [`app/build/outputs/apk/debug/app-debug.apk`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/build/outputs/apk/debug/app-debug.apk) | [`app/build/outputs/apk/release/app-release-unsigned.apk`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/build/outputs/apk/release/app-release-unsigned.apk) |
| **File Size** | 45,182,776 bytes (~43.09 MB) | 37,329,376 bytes (~35.60 MB) |
| **Last Compiled** | 2026-10-12 22:45:05 | 2026-10-13 21:56:40 |
| **SHA-256 Hash** | `8733E6096E697255A5FD495B32694664125A8A5C8883FB7A8AD9366DD0D94650` | `D50A8C826F4979B67255BC4048DB72CEBEDD18FD61D57F14742A8FFE33190708` |
| **Signing Status** | Signed (`CN=Android Debug`, Scheme v2) | **Unsigned** (`ERROR: Missing META-INF/MANIFEST.MF`) |
| **Installability** | Installable on debug targets via ADB | **Uninstallable** (Android OS rejects unsigned APKs) |

---

## 7. Safest Way to Create a Final Test APK & Preserve Installed App

### Constraint Analysis
1. **Existing Installed Package:** The physical phone currently has `com.example.secureprint` installed with an older/different certificate.
2. **Android Signature Constraint:** Android OS strictly forbids updating an installed app (`adb install -r`) when the signing certificate of the new APK differs from the installed APK, returning `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.
3. **Data Loss Safety:** As proven in [`SECUREPRINT_ANDROID_DATA_PRESERVATION_REPORT.md`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SECUREPRINT_ANDROID_DATA_PRESERVATION_REPORT.md), the Android app contains **zero** local database tables or persistent files. Reinstalling with a clean package incurs zero data loss—all user accounts, document metadata, and print jobs reside safely in the FastAPI SQLite database (`backend/secureprint.db`).

### Comparison of Final Test APK Strategies

| Strategy | Signing Method | Package ID | Preservation of Existing Installed App | Overwrite Conflict Risk |
| :--- | :--- | :--- | :--- | :--- |
| **Option A: Side-by-Side Test Build** | Signed with debug keystore | `com.example.secureprint.test` (via `applicationIdSuffix = ".test"`) | **100% Preserved** (Both apps exist on phone simultaneously) | **None** (Unique package ID bypasses signature check) |
| **Option B: Clean Debug Installation** | Signed with debug keystore (`app-debug.apk`) | `com.example.secureprint` | Uninstalls old app; re-logs into backend | **None** (`adb uninstall` resolves signature mismatch; data is 100% backend-backed) |
| **Option C: Unsigned Release Build** | None | `com.example.secureprint` | Cannot be installed | **Fails immediately** (OS rejects unsigned APK) |

---

## 8. The Single Safest Next Step

When the physical phone becomes available, the **single safest next step** is:

> **Execute a clean reinstallation of the verified debug build (`app-debug.apk`) after establishing the USB ADB reverse port forward:**
> 1. Connect phone via USB and enable USB Debugging.
> 2. Run `adb reverse tcp:8000 tcp:8000` to bind device loopback to PC FastAPI host.
> 3. Run `adb uninstall com.example.secureprint` to cleanly clear the legacy signature conflict (safe: zero local data loss).
> 4. Run `adb install -r "c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\app\build\outputs\apk\debug\app-debug.apk"`.
> 5. Launch app, log in with existing backend credentials, and verify live end-to-end communication.

*(If release distribution without ADB reverse is later desired, the team must provision an official release keystore and define production HTTPS endpoint parameters in `build.gradle.kts`.)*
