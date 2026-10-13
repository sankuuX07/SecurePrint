# SecurePrint Android Signing Secret Git Protection Audit Report

**Date:** 2026-10-13  
**Auditor:** Senior Android & Security Integration Engineer  
**Scope:** Read-Only Git Audit of Tracked Files, Historical Commits, Ignore Rule Hierarchy, and Keystore Credential Protection.  
**Strict Safety Constraints Enforced:**
- Zero passwords, private keys, keystore contents, or secret values printed or exposed.
- Read-only Git commands used for tracking and history verification.
- No Git history rewritten, no tracked files removed.
- No keystores generated, modified, or exported; no APKs signed.
- No apps installed/uninstalled, no device connected, no backend files/database touched.

---

## 1. Executive Summary & Audit Verdict

| Inspection Dimension | Status | Finding & Audit Result |
| :--- | :---: | :--- |
| **Tracked Signing Keys** | **CLEAN** | Read-only check `git ls-files "*keystore*" "*signing*" "*.jks" "*.p12"` confirmed **0** signing files or private keys are tracked. |
| **Tracked Properties Files** | **CLEAN** | Only standard non-sensitive Gradle properties (`gradle.properties`, wrapper, daemon) are tracked. **Zero** signing or keystore properties files are tracked. |
| **Git Commit History** | **CLEAN** | Full historical query `git log --all --full-history -- "*.jks" "*.keystore" "*.p12" "*keystore.properties" "*signing.properties"` confirmed no signing asset has **ever** been committed to the repository history. |
| **Subdirectory Ignore Rules** | **PROTECTED** | [`SecurePrint/.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/.gitignore) contains explicit rules for `*.jks`, `*.keystore`, `*.p12`, `*signing.properties`, and `*keystore.properties`. |
| **Root Ignore Coverage Gap** | **CORRECTED** | The Git root (`c:\Users\sansk\OneDrive\Desktop\SecurePrint`) previously lacked a top-level `.gitignore`. Created minimal, non-destructive root [`.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/.gitignore). |
| **Ignore Rule Verification** | **VERIFIED** | `git check-ignore -v` confirms all documented signing filenames (`keystore.properties`, `signing.properties`, `release.jks`) are strictly ignored at both root and nested levels. |

---

## 2. Ignore File Hierarchy & Inventory

The repository is structured with its Git root (`.git`) at `c:\Users\sansk\OneDrive\Desktop\SecurePrint`.

### 1. Root Level: [`c:\Users\sansk\OneDrive\Desktop\SecurePrint\.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/.gitignore)
- **Initial Status:** **ABSENT**. Because Git evaluates ignore files from the working root downward, files placed directly in the top-level directory (`keystore.properties`, `release.jks`) were unignored.
- **Correction Applied:** Created minimal root `.gitignore` specifying:
  ```gitignore
  # Android keystores and signing credentials
  *.jks
  *.keystore
  *.p12
  *signing.properties
  *keystore.properties
  ```

### 2. Module Root Level: [`c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/.gitignore)
- **Status:** **PRESENT & CONFIGURED**.
- **Rules Protecting Signing Assets:**
  - Line 18: `*.jks`
  - Line 19: `*.keystore`
  - Line 20: `*.p12`
  - Line 21: `*signing.properties`
  - Line 22: `*keystore.properties`
- Also protects local developer configuration via `local.properties`.

### 3. Android App Module Level: [`c:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\app\.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/app/.gitignore)
- **Status:** Contains `/build`. Inherits all wildcard rules from parent `.gitignore` files.

---

## 3. Read-Only Git Tracking Verification

All inspections utilized read-only commands without modifying repository objects or staging index.

### Command 1: Inspect Tracked Files for Keystores & Signing Credential Names
```powershell
git ls-files "*keystore*" "*signing*" "*.jks" "*.p12" "*secret*" "*credential*"
```
- **Output:** *(Empty - 0 matches)*
- **Finding:** No signing keys, keystores, or credential property files are currently tracked by Git.

### Command 2: Inspect All Tracked `.properties` and Key Files
```powershell
git ls-files | Select-String -Pattern "\.(jks|keystore|p12|pk8|properties)$"
```
- **Output:**
  ```text
  SecurePrint/gradle.properties
  SecurePrint/gradle/gradle-daemon-jvm.properties
  SecurePrint/gradle/wrapper/gradle-wrapper.properties
  ```
- **Finding:** No private credential properties are tracked. Tracked property files are strictly standard build system configuration and JVM memory arguments.

### Command 3: Full Git History Scan for Past Leaks
```powershell
git log --all --full-history -- "*.jks" "*.keystore" "*.p12" "*keystore.properties" "*signing.properties"
```
- **Output:** *(Empty - 0 commits found)*
- **Finding:** No signing certificates, keys, or password property files have ever been committed in previous commits on any branch.

---

## 4. Verification with `git check-ignore`

To confirm that the documented configuration filenames (`keystore.properties`, `signing.properties`, etc.) are effectively blocked across all directories, `git check-ignore -v` was executed against multiple prospective paths:

```powershell
git check-ignore -v "keystore.properties" "signing.properties" "release.jks" "release.keystore" "SecurePrint/keystore.properties" "SecurePrint/app/keystore.properties" "SecurePrint/app/release.jks"
```

### Exact Results Matrix:
| Target Path Tested | Matching Ignore Rule | Ignore File | Result |
| :--- | :--- | :--- | :---: |
| `keystore.properties` (Root) | `*keystore.properties` (Line 6) | `.gitignore` | **IGNORED** |
| `signing.properties` (Root) | `*signing.properties` (Line 5) | `.gitignore` | **IGNORED** |
| `release.jks` (Root) | `*.jks` (Line 2) | `.gitignore` | **IGNORED** |
| `release.keystore` (Root) | `*.keystore` (Line 3) | `.gitignore` | **IGNORED** |
| `SecurePrint/keystore.properties` | `*keystore.properties` (Line 22) | `SecurePrint/.gitignore` | **IGNORED** |
| `SecurePrint/app/keystore.properties` | `*keystore.properties` (Line 22) | `SecurePrint/.gitignore` | **IGNORED** |
| `SecurePrint/app/release.jks` | `*.jks` (Line 18) | `SecurePrint/.gitignore` | **IGNORED** |

---

## 5. Non-Destructive Correction Summary

- **File Created:** [`.gitignore`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/.gitignore) at the repository root.
- **Exact Content Added:**
  ```gitignore
  # Android keystores and signing credentials
  *.jks
  *.keystore
  *.p12
  *signing.properties
  *keystore.properties
  ```
- **Impact:** Ensures that even if a developer inadvertently creates `keystore.properties` or drops a `.jks` file in the root workspace folder rather than the `SecurePrint/` subfolder, Git will ignore it, preventing `git add .` from staging private credentials.

---

## 6. Remaining Risks & Ongoing Best Practices

1. **Forced Staging (`git add -f`):**
   - `.gitignore` prevents inadvertent staging via `git add .` or `git commit -a`. However, developers must never use `git add -f` or `git add --force` on ignored files.
2. **Template Files:**
   - When providing templates for local development (e.g., `keystore.properties.example`), ensure the file contains only placeholder dummy values (`YOUR_STORE_PASSWORD`) and is explicitly named with `.example`.
3. **CI/CD Best Practice:**
   - In automated build environments (such as GitHub Actions or GitLab CI), prefer passing keystores as base64-encoded environment secrets rather than saving raw `.jks` files on disk, or decode them into a transient runner directory outside the repository checkout tree.
