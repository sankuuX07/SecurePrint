# SecurePrint Android Data Preservation & Reinstallation Audit Report

**Date:** 2026-10-13  
**Auditor:** Senior Software Integration Engineer  
**Scope:** Android Local Persistence Audit, Data Authority Mapping, Account & Document Preservation Analysis, and Safe Reinstallation Assessment.  
**Constraint Adherence:** No files modified, no apps uninstalled, no storage cleared, no APK installed, and no secrets or private tokens printed.

---

## 1. Executive Summary

This audit evaluated the Android Customer & Shop Application (`com.example.secureprint`) to determine whether any private on-device data must be preserved before resolving the `INSTALL_FAILED_UPDATE_INCOMPATIBLE` signature mismatch.

### Verdict:
- **Zero Local Authoritative Data:** The Android application maintains **no** local Room/SQLite database, **no** Jetpack DataStore, and **no** permanent offline file storage.
- **Stateless Client Architecture:** The Android app functions strictly as a reactive presentation layer for the FastAPI backend. All user credentials (hashes), profiles, document metadata, document binaries, print jobs, pricing tables, payments, and QR tokens reside authoritatively in the backend SQLite database (`backend/secureprint.db`) and backend file store (`backend/uploads/`).
- **Safe Reinstallation:** Uninstalling the existing app and reinstalling the newly built debug APK (`app-debug.apk`) will **not** cause data loss. Existing users can immediately sign back in using their backend credentials; upon login, their documents and print jobs will seamlessly repopulate via API.

---

## 2. Android Local Persistence Inventory

We audited the entire Android codebase for storage mechanisms:

| Persistence Mechanism | Status in Android App | Implementation Details & Source Trace |
| :--- | :---: | :--- |
| **Room Database** | **ABSENT** | Grep scan for `@Database`, `@Dao`, `@Entity` yielded 0 occurrences. `build.gradle.kts` does not include Room dependencies. |
| **Local SQLite** | **ABSENT** | No `SQLiteOpenHelper`, SQLite drivers, or custom SQLite wrappers exist in the Android project. |
| **Jetpack DataStore** | **ABSENT** | No DataStore dependencies or preferences DataStore references exist. |
| **SharedPreferences** | **PRESENT (Transient Only)** | Implemented via `EncryptedSharedPreferences` in [`SessionManager.kt`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/java/com/example/secureprint/data/auth/SessionManager.kt#L18-L47) under file `secureprint_prefs`. Stores strictly two keys: `auth_token` (active JWT) and `user_role` ("CUSTOMER" / "SHOP" / "ADMIN"). |
| **Internal Files (`filesDir`)** | **ABSENT** | Grep scan for `filesDir` yielded 0 occurrences. No local files are stored in private internal storage. |
| **Cache Storage (`cacheDir`)** | **TRANSIENT ONLY** | [`SecureFileDownloader.kt`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/java/com/example/secureprint/util/SecureFileDownloader.kt#L22) writes temporarily to `context.cacheDir/secure_docs` only while streaming a document for shop inspection. Includes `clearSecureCache()`. |
| **External / Media Storage** | **ABSENT** | App uses Android's system file picker contract (`ActivityResultContracts.GetContent()`) in [`CustomerDashboardScreen.kt`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/src/main/java/com/example/secureprint/screens/CustomerDashboardScreen.kt#L44-L61) to stream files directly from device storage to the network multipart body without retaining local copies. |

---

## 3. Data Authority Mapping: Backend vs. Phone

| Entity / Information | Authoritative Location | Phone Role / Local Retention | Data Loss Risk on App Uninstall |
| :--- | :--- | :--- | :---: |
| **User Accounts & Credentials** | **FastAPI / `backend/secureprint.db`** (`users` table) | None. Passwords are password-hashed (Argon2) on backend. Phone never persists passwords. | **ZERO** |
| **Active Auth Session (JWT)** | **FastAPI / JWT Validation** (State in backend token validation) | Phone stores active access token in `secureprint_prefs` for HTTP `Authorization: Bearer` header. | **SESSION ONLY** (Requires re-login) |
| **Customer Uploaded Documents** | **FastAPI / `backend/uploads/`** (Metadata in `documents` table) | None. Documents are streamed over HTTP on upload and fetched dynamically via `GET /api/v1/documents/`. | **ZERO** |
| **Print Jobs & History** | **FastAPI / `backend/secureprint.db`** (`print_jobs`, `print_job_status_history`) | None. Fetched dynamically via `GET /api/v1/print-jobs/customer` or `GET /api/v1/print-jobs/shop`. | **ZERO** |
| **Payment Records** | **FastAPI / `backend/secureprint.db`** (`payments` table) | None. Queried dynamically via `GET /api/v1/shop/print-jobs/{job_id}/payment`. | **ZERO** |
| **Shop Pricing & Approval** | **FastAPI / `backend/secureprint.db`** (`shops`, `shop_pricing` tables) | None. Loaded dynamically over REST API. | **ZERO** |
| **Secure Access & QR Tokens** | **FastAPI / `backend/secureprint.db`** (`secure_access_tokens`, `shop_qr_codes`) | Rendered in memory into a dynamic Bitmap via ZXing/MLKit on demand. No local persistence. | **ZERO** |

---

## 4. Why `INSTALL_FAILED_UPDATE_INCOMPATIBLE` Occurs

When attempting `adb install -r app-debug.apk` over an existing package:
1. Android checks the signature of the installed package `com.example.secureprint` against the signature of the new incoming APK.
2. The installed app was signed with a previous or different keystore certificate (e.g. from an earlier machine state or clean IDE setup).
3. The newly generated debug APK located at [`app/build/outputs/apk/debug/app-debug.apk`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/build/outputs/apk/debug/app-debug.apk) is signed with the current local debug keystore (`%USERPROFILE%\.android\debug.keystore`).
4. Because the cryptographic certificates differ, the Android OS package manager rejects the update with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` to prevent unauthorized binary overwrites.

---

## 5. Account Preservation & Reinstallation Safety Confirmation

### Key Confirmation Points:
1. **Can existing users sign back in?**  
   **YES.** All registered accounts (customers, shop owners, admins) are securely stored in the authoritative SQLite database on the PC. Upon launching the reinstalled app, users can input their email and password into the login screen.
2. **Will previously uploaded documents still be there?**  
   **YES.** All documents previously uploaded remain in `backend/uploads/` and are listed in the `documents` table. As soon as the customer logs in, `DocumentViewModel.loadDocuments()` issues `GET /api/v1/documents/`, restoring the full document list.
3. **Will print jobs still be intact?**  
   **YES.** All print jobs and state-history records remain in `backend/secureprint.db`. As soon as the user navigates to the dashboard, `PrintJobViewModel` retrieves all existing print jobs via `GET /api/v1/print-jobs/customer`.
4. **What is the consequence of uninstalling the app?**  
   The only consequence is that the cached JWT session is discarded. The user will see the initial `Welcome / Login` screen upon opening the freshly installed app.

---

## 6. Safest Next Steps

Because private local data preservation is **not** required, the cleanest, safest, and standard development procedure to resolve the signature conflict is:

1. **Verify ADB reverse is active for port 8000:**
   ```powershell
   adb reverse tcp:8000 tcp:8000
   ```
2. **Uninstall the old build with the mismatched certificate:**
   ```powershell
   adb uninstall com.example.secureprint
   ```
3. **Install the new debug APK built with the current environment URL (`http://127.0.0.1:8000/`):**
   ```powershell
   adb install -r "c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\app\build\outputs\apk\debug\app-debug.apk"
   ```
4. **Launch the application on the physical device:**
   ```powershell
   adb shell am start -n com.example.secureprint/.MainActivity
   ```
5. **Log in with existing backend credentials and verify live end-to-end communication.**
