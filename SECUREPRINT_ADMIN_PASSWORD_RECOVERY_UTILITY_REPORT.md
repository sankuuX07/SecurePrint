# SecurePrint Admin Password Recovery Utility Report

**Document Date:** October 15, 2026  
**Status:** Prepared & Reviewed (Not Executed)  
**Target Utility:** [`backend/reset_admin_password.py`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/reset_admin_password.py)  
**Database State:** Unmodified (0 writes, 0 role changes, 0 shop approvals executed)  

---

## 1. Overview & Purpose

Following the architectural discovery documented in [`SECUREPRINT_PASSWORD_RECOVERY_DISCOVERY_REPORT.md`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SECUREPRINT_PASSWORD_RECOVERY_DISCOVERY_REPORT.md), administrator account self-registration is permanently disabled in application code, and the bootstrap script [`backend/seed_admin.py`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/seed_admin.py) intentionally ignores existing administrator accounts due to an existence guard.

To restore access without modifying application code or corrupting relational dependencies, a dedicated, isolated, and safe command-line utility has been created: [`backend/reset_admin_password.py`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/reset_admin_password.py).

---

## 2. Files Created & Modified

| File | Status | Description |
|---|---|---|
| [`backend/reset_admin_password.py`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/reset_admin_password.py) | **Created** | Standalone CLI utility for interactive administrator password reset. |
| Application Source Code (`backend/app/*`) | **Untouched** | No routes, models, or security configurations were altered. |
| Database (`secureprint.db`) | **Untouched** | No queries were executed that modify, update, or delete records. |

---

## 3. Architecture & Security Integrations

The utility integrates directly with the existing SecurePrint backend architecture:

1. **Database Session Management:**  
   Uses `SessionLocal` from [`backend/app/core/database.py`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/app/core/database.py). This adheres to the application's configured `DATABASE_URL` (SQLite or PostgreSQL) rather than using low-level database drivers.
2. **Cryptographic Algorithm:**  
   Calls [`get_password_hash()`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/app/core/security.py#L21-L22) from `app.core.security`, which hashes using **Argon2id** (`passlib.context.CryptContext(schemes=["argon2"])`). This ensures full compatibility with the existing login route [`POST /api/v1/auth/login`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/app/routes/auth.py#L100-L115).
3. **ORM Model Compliance:**  
   Loads the SQLAlchemy [`User`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/app/models/user.py) model and inspects the `UserRole` enum (`ADMIN`).

---

## 4. Built-in Safeguards & Invariants

| Safeguard | Implementation Details |
|---|---|
| **Role Guard** | Queries the database and strictly verifies `user.role == UserRole.ADMIN`. If a customer or shop account email is specified, the script immediately aborts with `[SECURITY REJECTION]` and makes zero database changes. |
| **Zero Plaintext Exposure** | Uses Python's standard `getpass.getpass()`. Passwords are typed interactively without being printed to the screen, stored in terminal command history, logged, or passed as command-line arguments. |
| **Password Validation** | Enforces minimum length (&ge; 8 characters), non-emptiness, whitespace trimming checks, complexity (letters and digits/symbols), and matching confirmation entry. |
| **Data Preservation** | Updates **only** `user.password_hash`. Preserves `user.id`, `user.name`, `user.email`, `user.phone`, `user.role`, `user.status`, timestamps, and all foreign-key relationships. |
| **Shop Isolation** | Strictly touches the administrator user record. Does not alter, approve, or activate any shop, shop pricing, or QR code record. |
| **Explicit Confirmation Gate** | Displays non-sensitive account metadata (ID, Name, Email, Role, Status, Creation Date) and requires typing `"yes"` before initiating a commit. |
| **Transaction Integrity** | Uses SQLAlchemy session transactions with an explicit `try ... except ... finally` block. Calls `db.rollback()` on any unexpected error and ensures `db.close()`. |

---

## 5. Manual Execution Guide (For Future Invocation)

The utility has been prepared and statically verified (`py_compile`). It **has not been executed** during this task.

When the operator decides to reset the administrator password, execute the following steps in Windows PowerShell:

### Step 1: Open Terminal in the Backend Directory
```powershell
cd C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\backend
```

### Step 2: Activate the Virtual Environment
```powershell
.\venv\Scripts\Activate.ps1
```
*(Or run directly with `.\venv\Scripts\python.exe`)*

### Step 3: Run the Utility
To reset the default administrator account (`admin@secureprint.com`):
```powershell
python reset_admin_password.py
```

To target a specific administrator email (if different from default):
```powershell
python reset_admin_password.py --email admin@secureprint.com
```

### Step 4: Follow the Interactive Prompts
1. The script displays verified administrator metadata.
2. Enter the new password when prompted by `getpass` (input will be hidden).
3. Confirm the password.
4. When prompted: `Type 'yes' to confirm password reset for 'admin@secureprint.com':`, type `yes` and press Enter.

---

## 6. Verification & Post-Reset Workflow

Once the password reset has been manually completed, the administrator can perform account verification and shop approval:

### 1. Authenticate as Administrator
```powershell
$response = Invoke-RestMethod -Method Post `
  -Uri "http://127.0.0.1:8000/api/v1/auth/login" `
  -Headers @{ "Content-Type" = "application/x-www-form-urlencoded" } `
  -Body @{ username = "admin@secureprint.com"; password = "<new_admin_password>" }

$adminToken = $response.access_token
Write-Host "Admin Access Token Acquired"
```

### 2. View Pending Shops
```powershell
Invoke-RestMethod -Method Get `
  -Uri "http://127.0.0.1:8000/api/v1/admin/shops/pending" `
  -Headers @{ "Authorization" = "Bearer $adminToken" }
```

### 3. Approve the Target Shop Account
Using the shop user's ID obtained from the pending list:
```powershell
Invoke-RestMethod -Method Post `
  -Uri "http://127.0.0.1:8000/api/v1/admin/shops/<shop_user_id>/approve" `
  -Headers @{ "Authorization" = "Bearer $adminToken" }
```
This properly triggers the full shop approval lifecycle ([`admin.py:L20-L41`](file:///c:/Users/sansk/OneDrive/Desktop/SecurePrint/SecurePrint/backend/app/routes/admin.py#L20-L41)), activating the shop user, shop entity, and shop QR code in unison.
