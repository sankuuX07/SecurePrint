# SecurePrint Android Release Signing Readiness Audit Report

**Date:** 2026-10-13  
**Auditor:** Senior Android & Security Integration Engineer  
**Scope:** Android Release Signing Architecture, Keystore Status, Gradle Configuration, Git Protection (.gitignore), SDK Verification Procedures, and Safe Path to Signed Release Delivery.  
**Strict Safety Constraints Enforced:**
- Zero secrets printed, displayed, or exported.
- No keystores generated, replaced, exported, or modified.
- No APK signed.
- No apps installed or uninstalled.
- No physical devices connected or runtime execution claimed.
- No backend files, migrations, or database modified.

---

## 1. Executive Summary & Audit Findings

| Component | Current Status | Finding & Analysis |
| :--- | :---: | :--- |
| **Existing Release Keystore** | **ABSENT** | Comprehensive filesystem scans found **no** `.jks`, `.keystore`, or `.p12` release signing files in the repository, parent workspace, or developer environment. |
| **Gradle Signing Configuration** | **UNCONFIGURED** | [`app/build.gradle.kts`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/build.gradle.kts) does not define any `signingConfigs` block. `buildTypes.release` has no `signingConfig` property. |
| **Release Artifact Status** | **UNSIGNED** | Gradle task `assembleRelease` produces [`app-release-unsigned.apk`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/build/outputs/apk/release/app-release-unsigned.apk). `apksigner` reports `DOES NOT VERIFY. ERROR: Missing META-INF/MANIFEST.MF`. |
| **Debug Keystore Assumption** | **DISQUALIFIED** | Debug keystore (`%USERPROFILE%\.android\debug.keystore`) uses known public credentials (`CN=Android Debug`, password `android`). It is strictly prohibited for production release distribution. |
| **Git Protection (.gitignore)** | **HARDENED** | [`SecurePrint/.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/.gitignore) previously lacked rules for keystore and credential files. Protected with non-destructive patterns (`*.jks`, `*.keystore`, `*.p12`, `*signing.properties`, `*keystore.properties`). |
| **Environment Variables** | **NONE FOUND** | No system or Gradle environment variables referencing release keystores or passwords exist on the machine. |

---

## 2. Detailed Inspection of Files

The following files and configurations were inspected:

1. **[`app/build.gradle.kts`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/build.gradle.kts):**
   - Lines 22-29: `buildTypes.release` specifies `isMinifyEnabled = false` and Proguard rules, but omits `signingConfig`.
   - AGP automatically defaults release builds to unsigned when no signing configuration is attached.
2. **[`SecurePrint/gradle.properties`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/gradle.properties):**
   - Contains JVM options and configuration flags; no properties for `storeFile`, `keyAlias`, or signing passwords.
3. **[`SecurePrint/local.properties`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/local.properties):**
   - Contains only `sdk.dir=C\:\\Users\\sansk\\AppData\\Local\\Android\\Sdk`. Ignored by Git.
4. **[`SecurePrint/.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/.gitignore):**
   - Initially ignored `local.properties`, `.gradle`, `/build`, and `.idea/`. Lacked explicit rules for keystores or properties files containing secrets.
5. **[`SecurePrint/app/.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/.gitignore):**
   - Contains only `/build`.
6. **Previous Integration & Security Reports:**
   - [`SECUREPRINT_ANDROID_RELEASE_READINESS_REPORT.md`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SECUREPRINT_ANDROID_RELEASE_READINESS_REPORT.md) confirmed that `assembleRelease` compiles cleanly, but produces an unsigned artifact.
   - [`SECUREPRINT_ANDROID_RELEASE_SECURITY_FIX_REPORT.md`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SECUREPRINT_ANDROID_RELEASE_SECURITY_FIX_REPORT.md) confirmed that Logcat sensitive body logging is completely omitted in release builds via `BuildConfig.DEBUG`.

---

## 3. Keystore Absence & Debug Keystore Disqualification

### Keystore Presence Audit
Scans across the entire project structure (`c:\Users\sansk\OneDrive\Desktop\SecurePrint`) confirmed that no release signing key has ever been stored in this repository:
- `Get-ChildItem -Include *.jks, *.keystore, *.p12 -Recurse`: 0 matches.
- Grep for `storePassword`, `keyPassword`, `signingConfig`: 0 matches.

### Why Debug Keystore Cannot Be Used For Release
The debug keystore is located at `%USERPROFILE%\.android\debug.keystore`:
- **Subject / Signer:** `C=US, O=Android, CN=Android Debug`
- **Known Credentials:** Public default alias (`androiddebugkey`) and public password (`android`).
- **Cryptographic Security:** Any third party can sign an APK with the standard Android debug keystore. It carries zero authenticity or integrity assurance.
- **Store Policies:** Google Play Store, F-Droid, and enterprise MDMs strictly reject APKs/AABs signed with `CN=Android Debug`.
- **Update Compatibility:** Debug keystores vary across developer machines. Using a debug keystore for release would break app updates for users if built from any other machine.

---

## 4. Git Security & Secrets Protection

To guarantee that private keys and passwords are never accidentally committed or exposed in version control:

### Added .gitignore Patterns
In [`SecurePrint/.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/.gitignore), non-destructive protection rules were added:
```gitignore
# Android keystores and signing credentials
*.jks
*.keystore
*.p12
*signing.properties
*keystore.properties
```

### Git Policy Requirements
1. **Never commit `.jks`, `.keystore`, or `.p12` files to any Git branch.**
2. **Never hardcode passwords or aliases in `build.gradle.kts`.**
3. **Never commit properties files containing credentials.** Always use `.gitignore` and supply template files (e.g., `keystore.properties.example` with empty dummy values).

---

## 5. Recommended Architecture for Future Release Signing

To allow release builds to be signed seamlessly both on developer PCs and in automated CI/CD pipelines without hardcoding secrets, the following hybrid configuration is recommended for [`app/build.gradle.kts`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/build.gradle.kts):

### 1. Hybrid Signing Configuration (CI Environment Variables + Local Properties)

```kotlin
import java.io.FileInputStream
import java.util.Properties

// Optional untracked local keystore.properties file
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    ...
    signingConfigs {
        create("release") {
            // Priority 1: CI/CD Environment Variables
            val envKeystorePath = System.getenv("SECUREPRINT_RELEASE_KEYSTORE_PATH")
            val envStorePassword = System.getenv("SECUREPRINT_RELEASE_STORE_PASSWORD")
            val envKeyAlias = System.getenv("SECUREPRINT_RELEASE_KEY_ALIAS")
            val envKeyPassword = System.getenv("SECUREPRINT_RELEASE_KEY_PASSWORD")

            if (!envKeystorePath.isNullOrBlank() && file(envKeystorePath).exists()) {
                storeFile = file(envKeystorePath)
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            } else if (keystorePropertiesFile.exists()) {
                // Priority 2: Untracked local keystore.properties file
                val propStorePath = keystoreProperties.getProperty("storeFile")
                if (!propStorePath.isNullOrBlank()) {
                    storeFile = rootProject.file(propStorePath)
                    storePassword = keystoreProperties.getProperty("storePassword")
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                }
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Only bind signingConfig if a valid storeFile is configured
            val releaseSigning = signingConfigs.findByName("release")
            if (releaseSigning?.storeFile != null && releaseSigning.storeFile!!.exists()) {
                signingConfig = releaseSigning
            }
        }
    }
}
```

### 2. Local Developer Template (`keystore.properties.example`)
Create a committed documentation template `keystore.properties.example` (without secrets):
```properties
# Template for local release signing. Copy to keystore.properties and fill in.
# keystore.properties is untracked by Git.
storeFile=../release-keys/secureprint-release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=secureprint-release
keyPassword=YOUR_KEY_PASSWORD
```

### 3. Graceful Fallback
If neither environment variables nor `keystore.properties` is present, `releaseSigning.storeFile` remains `null`. Gradle continues to assemble an unsigned release APK without breaking normal builds or unit tests.

---

## 6. How to Verify a Signed APK with Android SDK Tools

Once a signed release APK is built, the integrity, signature scheme, and certificate identity must be verified before distribution.

### 1. Verifying Signature with `apksigner`
The official Android SDK verification tool is `apksigner` (available at `C:\Users\sansk\AppData\Local\Android\Sdk\build-tools\36.0.0\apksigner.bat`):

```powershell
& "C:\Users\sansk\AppData\Local\Android\Sdk\build-tools\36.0.0\apksigner.bat" verify --verbose --print-certs "c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\app\build\outputs\apk\release\app-release.apk"
```

#### What to Inspect in the Output:
- **Verification Status:** `Verifies: true`
- **Signature Schemes:**
  - `Verified using v2 scheme (APK Signature Scheme v2): true` (Required for modern Android)
  - `Verified using v3 scheme (APK Signature Scheme v3): true` (Recommended)
  - `Verified using v1 scheme (JAR signing): true` (Required for compatibility with Android 6 and older)
- **Signer Identity:**
  - Look at `Signer #1 certificate DN`:
    - **MUST NOT** be `CN=Android Debug`.
    - Must match official organizational identity (e.g., `CN=SecurePrint Release, O=SecurePrint, C=IN`).
- **Certificate Fingerprints:** Record and store the SHA-256 fingerprint for Google Play / OAuth / Backend certificate pinning.

### 2. Verifying Keystore Parameters with `keytool`
Before building, inspect the provisioned keystore file:
```powershell
keytool -list -v -keystore "<path-to-keystore>.jks"
```
Verify that:
- Algorithm is RSA (>= 2048-bit) or EC.
- Validity is at least 25 years (Google Play requirement for application signing).
- Alias name matches the configured `keyAlias`.

---

## 7. Safest Next Steps

To produce an official signed release APK without compromising security:

1. **Keystore Generation (Off-Repository / Secure Machine):**
   The project owner generates the official production keystore on a secure machine using `keytool`:
   ```powershell
   keytool -genkeypair -v -keystore secureprint-release.jks -alias secureprint -keyalg RSA -keysize 2048 -validity 10000
   ```
   *(Store the `.jks` file in a secure password manager or encrypted enterprise vault. Never commit to Git.)*

2. **Configure CI Secrets or Local Properties:**
   - For CI/CD: Define secrets `SECUREPRINT_RELEASE_KEYSTORE_PATH`, `SECUREPRINT_RELEASE_STORE_PASSWORD`, `SECUREPRINT_RELEASE_KEY_ALIAS`, `SECUREPRINT_RELEASE_KEY_PASSWORD`.
   - For Local Testing: Copy `keystore.properties.example` to `keystore.properties` (ignored by Git) and point to the keystore.

3. **Update `app/build.gradle.kts`:**
   Implement the hybrid signing configuration documented in Section 5.

4. **Build and Verify:**
   Run `./gradlew.bat assembleRelease` and verify the output with `apksigner verify --verbose --print-certs`.
