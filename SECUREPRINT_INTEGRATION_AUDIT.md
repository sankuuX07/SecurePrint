# SecurePrint System Integration & Architectural Audit Report

**Audit Date**: October 12, 2026  
**Auditor**: Senior Software Architect & Lead Integration-Testing Engineer  
**Audit Scope**: End-to-End Integration across Android Customer Application, FastAPI Backend, SQLite Database, Windows Shop Desktop Software, Secure Document Access Subsystem, and Windows Physical Printing Subsystem.  
**Mode**: Audit-Only Inspection (Non-destructive, zero code modifications, zero mock generation).

---

## Executive Summary

An architectural and integration-testing audit of the **SecurePrint** ecosystem was conducted to evaluate the viability of the complete end-to-end printing workflow:
$$\text{Android Document Upload} \longrightarrow \text{FastAPI Document Storage} \longrightarrow \text{Print Job Creation} \longrightarrow \text{Shop Job Fetch} \longrightarrow \text{Secure QR Authorization} \longrightarrow \text{Document Download} \longrightarrow \text{PDF Preview} \longrightarrow \text{Windows Spooler Print} \longrightarrow \text{Status Sync}$$

### High-Level Audit Findings
1. **Strong Core Backend Foundations**: The FastAPI backend is structurally sound, featuring Argon2id password hashing, JWT authorization, SQLAlchemy models, Alembic migrations, granular audit logging, and cryptographic access token exchange with SHA-256 hashing.
2. **Critical Client-Server Contract Gaps**:
   - **Android Client**: Several Retrofit interfaces (`PrintJobApi.kt`, `ShopApi.kt`) omit the mandatory `api/v1/` route prefix, resulting in HTTP `404 Not Found` errors when attempting to create jobs, browse shops, fetch job histories, or generate secure access tokens.
   - **Windows Desktop Client**: A severe schema mismatch exists in the Secure Access Authorization endpoint (`/api/v1/shop/document-access/authorize`). The backend responds with `{ "access_id": "...", "status": "AUTHORIZED" }`, whereas the desktop Dart model strictly expects `{ "id": "...", "status": "active" }`. This triggers a runtime `TypeError` (`Null is not a subtype of String`), preventing authorized document downloading and physical printing.
3. **Database Portability Hazard**: The SQLite database connection string is configured as a relative path (`sqlite:///./secureprint.db`). The database file accessed depends entirely on the process Working Directory (`CWD`), risking silent database splitting.
4. **Desktop Default Configuration**: The Windows desktop application defaults to `Local Development Mode (Offline)` with an empty backend URL, and the Login screen lacks an interface to switch to `Production Backend Mode` prior to authentication.
5. **Print Spooler Translation Limitations**: The desktop printing implementation dispatches raw PDF bytes directly to the Windows Spooler via `Printing.directPrintPdf()`. It does not slice custom page ranges or configure color mode/orientation in the printer driver settings.

---

## 1. Architecture and Data-Flow Summary

```
+-----------------------------------------------------------------------------------------------------------------+
|                                              SECUREPRINT ECOSYSTEM                                              |
+-----------------------------------------------------------------------------------------------------------------+

  [ Android Customer App ]                                                  [ Windows Shop Desktop App ]
  +----------------------+                                                  +--------------------------+
  |  Jetpack Compose UI  |                                                  |    Flutter Desktop UI    |
  |  Retrofit HTTP Client|                                                  |    ApiClient (http.dart) |
  |  ML Kit / ZXing QR   |                                                  |    Syncfusion PDF Viewer |
  +----------+-----------+                                                  |    Printing Plugin (GDI) |
             |                                                              +-------------+------------+
             | (1) Upload PDF / Image                                                     |
             |     POST /api/v1/documents/                                                | (4) Fetch Jobs
             |                                                                            |     GET /api/v1/print-jobs/shop
             | (3) Create Print Job                                                       |
             |     POST /api/v1/print-jobs/                                               | (5) Scan Secure QR
             |                                                                            |     POST /api/v1/shop/document-access/authorize
             | (6) Show Secure QR                                                         |
             |     POST /api/v1/print-jobs/{id}/secure-access                             | (7) Stream Document
             |                                                                            |     GET /api/v1/shop/document-access/{id}/download
             |                                                                            |
             |                                                                            | (8) Spool to Windows Driver
             |                                                                            |     Printing.directPrintPdf()
             |                                                                            |
             v                                                                            v
  +---------------------------------------------------------------------------------------------------------------+
  |                                        FastAPI Backend (Python 3.12)                                          |
  |  - Entry Point: app.main:app (Port 8000)                                                                      |
  |  - Security: JWT (HS256) Bearer, Argon2id, SHA-256 Token Hashing, Audit Logging                               |
  |  - Document Management: Multi-part Streaming, File Type & Size Validation (Max 10 MB)                         |
  |  - Storage Engine: Local UUID File System (backend/uploads/)                                                  |
  +---------------------------------------+-----------------------------------------------------------------------+
                                          |
                                          | SQLAlchemy ORM / WAL Mode
                                          v
                         +---------------------------------+
                         |      SQLite Engine & DB         |
                         |  backend/secureprint.db         |
                         |  - users (19)                   |
                         |  - shops (8)                    |
                         |  - shop_pricing (65)            |
                         |  - documents (23)               |
                         |  - print_jobs (10)              |
                         |  - temporary_document_access (2)|
                         |  - secure_access_tokens (6)     |
                         |  - audit_logs (18)              |
                         +---------------------------------+
```

### Data Flow Execution Sequence
1. **Document Upload**: Customer selects a PDF/image on Android. Android streams the file via multipart form-data to `POST /api/v1/documents/`. Backend calculates page count and stores the binary payload in `backend/uploads/{uuid}.pdf`, recording metadata in the `documents` table.
2. **Shop Selection & Quote Calculation**: Customer browses shops via `GET /api/v1/shops/`. Android submits job specifications (copies, paper size, color, double-sided, page range) to `POST /api/v1/print-jobs/`. Backend calculates authoritative pricing from `shop_pricing`, inserts a record into `print_jobs` in `CREATED` status, and creates an `UNPAID` record in `payments`.
3. **Shop Order Acceptance**: Shop Desktop receives the job via `GET /api/v1/print-jobs/shop`. Shop clicks **Accept Job**, transitioning the state to `ACCEPTED` via `POST /api/v1/print-jobs/{job_id}/accept`.
4. **Secure Handshake Generation**: Once the job is `ACCEPTED`, the customer generates a temporary access token via `POST /api/v1/print-jobs/{job_id}/secure-access`. Backend generates a cryptographically random token (`SP-ACCESS-...`, 15-minute TTL), hashes it with SHA-256 in `secure_access_tokens`, and returns the raw token. Android renders this token as a high-density QR code.
5. **Physical QR Scan & Verification**: Customer presents the QR code to the shop counter. The Windows app scans the QR and submits the raw token to `POST /api/v1/shop/document-access/authorize`. Backend validates the token hash, enforces shop ownership, verifies document availability, and creates a `TemporaryDocumentAccess` grant (15-minute TTL).
6. **Encrypted/Isolated File Download**: The shop desktop software streams the raw file via `GET /api/v1/shop/document-access/{access_id}/download` into a sandboxed temporary directory (`%TEMP%\<timestamp>_<filename>`).
7. **Preview & Verification**: Syncfusion PDF Viewer renders the sandboxed file. Shop verifies pages and formatting against customer order details.
8. **Physical Spooling & Printing**: Shop confirms printer selection. The software invokes `Printing.directPrintPdf()`, transmitting the binary stream to the selected Windows print driver queue.
9. **Status Transition & Token Revocation**: The software updates backend status to `PRINTING` via `POST /api/v1/print-jobs/{job_id}/start`, spools copies, and calls `POST /api/v1/print-jobs/{job_id}/complete`. Upon completion, backend triggers `revoke_access()` and `revoke_tokens_for_job()`, ensuring the document cannot be re-downloaded.

---

## 2. End-to-End Integration Trace Table

| # | Workflow Step | Source File & Function / Endpoint | Actual Implementation Found | Verification Evidence | Status | Exact Remaining Work / Gaps |
|---|---|---|---|---|---|---|
| **1** | **Customer Auth & Document Upload** | Android: `DocumentApi.kt` (`uploadDocument`)<br>Backend: `routes/documents.py` (`upload_document`) | Multipart file upload; backend computes page count with PyPDF/Pillow; generates UUID storage key. | Backend `test_documents.py` passes; upload files validated on disk; schema verified. | **CODE PRESENT BUT UNTESTED** | Run manual integration test from Android device; verify multipart streaming over LAN. |
| **2** | **Document Storage & Metadata Persistence** | Backend: `services/storage.py` (`save_upload_file`) | Writes binary to `backend/uploads/{uuid}.{ext}`; validates size (<=10MB), checks path traversal; saves metadata in `documents` table. | 207 files present in `uploads/`; 23 records in `documents` SQLite table; read-only inspection confirmed. | **VERIFIED BY TEST** | None. Storage subsystem is fully functional. |
| **3** | **Print Job Creation** | Android: `PrintJobApi.kt` (`createPrintJob`)<br>Backend: `routes/print_jobs.py` (`create_print_job`) | Price calculated dynamically from `shop_pricing`; creates `print_jobs` in `CREATED` status; creates `Payment` record; sets doc to `IN_PRINT_JOB`. | Backend route verified in `test_print_jobs.py` and `e2e_print_test.py`. Android `PrintJobApi.kt` specifies `@POST("print-jobs/")` without `api/v1/`. | **PARTIALLY IMPLEMENTED (BLOCKED)** | Add missing `"api/v1/"` prefix to `PrintJobApi.kt` and `ShopApi.kt` in Android. |
| **4** | **Windows Shop Job Retrieval** | Windows: `ShopService.dart` (`getRecentJobs`)<br>Backend: `routes/print_jobs.py` (`get_shop_print_jobs`) | Queries `/api/v1/print-jobs/shop` with pagination & status filters; parses `PrintJobModel`. | `ShopService.dart` lines 19-29 match backend route `/api/v1/print-jobs/shop`. Mock tests in `job_details_test.dart` pass. | **CODE PRESENT BUT UNTESTED** | Verify live JSON deserialization against real backend database records. |
| **5** | **Secure Token Generation** | Android: `PrintJobApi.kt` (`createSecureAccessToken`)<br>Backend: `routes/print_jobs.py` (`generate_secure_access_token`) | Generates `SP-ACCESS-...`, stores SHA-256 hash in `secure_access_tokens` (15m TTL), requires `ACCEPTED`/`PRINTING` status. | Verified in `e2e_secure_access_test.py`. Android `PrintJobApi.kt` missing `"api/v1/"` prefix. | **PARTIALLY IMPLEMENTED (BLOCKED)** | Fix Android Retrofit endpoint path to `api/v1/print-jobs/{jobId}/secure-access`. |
| **6** | **Secure QR Authorization (Shop Scan)** | Windows: `ShopService.dart` (`authorizeDocumentAccess`)<br>Backend: `routes/shop_document_access.py` (`authorize_secure_access`) | Backend validates hash, shop ownership, and returns temporary access grant. Windows posts `{ "token": token }`. | Backend route verified in `e2e_secure_access_test.py`. **CRITICAL MISMATCH**: Backend returns `access_id` and `"AUTHORIZED"`, desktop model expects `id` and `"active"`. | **PARTIALLY IMPLEMENTED (BLOCKED)** | Update `TemporaryDocumentAccessModel.fromJson` to parse `access_id` / `id` and accept status `"AUTHORIZED"`. |
| **7** | **Authorized Document Download** | Windows: `DocumentAccessService.dart` (`downloadDocument`)<br>Backend: `routes/shop_document_access.py` (`download_temporary_document`) | Validates access token, streams raw file via `FileResponse` to sandboxed temporary directory. | Route verified in `e2e_secure_access_test.py`. Blocked on desktop due to Step 6 failure. | **CODE PRESENT BUT UNTESTED** | Unblock Step 6; test file transfer and sanitization over HTTP. |
| **8** | **Document Preview (PDF)** | Windows: `DocumentPreviewScreen.dart`<br>Plugin: `syncfusion_flutter_pdfviewer` | Loads downloaded file via `SfPdfViewer.file()`, renders zoom controls, sidebar metadata, and Print button. | Verified in widget tests (`document_preview_test.dart`). Component compiled in release build. | **CODE PRESENT BUT UNTESTED** | Perform visual verification with multi-page test PDF. |
| **9** | **Physical Print Spooling** | Windows: `PrintExecutionProvider.dart`<br>Plugin: `Printing.directPrintPdf()` | Dispatches raw PDF bytes to selected Windows printer queue via Windows GDI spooler driver. | Plugin present in `Release/` bundle (`printing_plugin.dll`). Loop for `job.copies` implemented. Unit tests mock print call. | **PARTIALLY IMPLEMENTED** | Implement page-range extraction before sending bytes to `Printing.directPrintPdf()`. Perform controlled physical print test. |
| **10** | **Status Transition & Token Revocation** | Windows: `PrintExecutionProvider.dart`<br>Backend: `routes/print_jobs.py` (`start`, `complete`) | Calls `/start` then `/complete`. Backend revokes tokens, updates history, sets doc to `PRINTED`. | State machine logic and automatic token revocation verified in `test_temporary_access.py` and `test_print_jobs.py`. | **CODE PRESENT BUT UNTESTED** | Validate end-to-end status sync between Windows app and live backend. |
| **11** | **Customer Status Refresh** | Android: `CustomerPrintJobDetailScreen.kt`<br>Backend: `routes/print_jobs.py` (`get_customer_print_job_detail`) | Customer polls or navigates to job detail to view `PRINTING` and `COMPLETED` timestamps. | UI exists; blocked by missing `api/v1/` prefix in `PrintJobApi.kt`. | **PARTIALLY IMPLEMENTED (BLOCKED)** | Fix endpoint URL prefix in Android Retrofit interface. |

---

## 3. API Contract & Endpoint Mapping

### FastAPI Backend Endpoints (Total: 37 Routes)

| Category | HTTP Method | Backend Route | Android Retrofit Interface | Windows Shop Desktop Interface | Contract Alignment Status |
|---|---|---|---|---|---|
| **Auth** | `POST` | `/api/v1/auth/register` | `AuthApi.kt` (`api/v1/auth/register`) | `BackendAuthService.dart` (`/api/v1/auth/register`) | **MATCHED** |
| **Auth** | `POST` | `/api/v1/auth/login` | `AuthApi.kt` (`api/v1/auth/login`) | `AuthService.dart` (`/api/v1/auth/login`) | **MATCHED** |
| **Users** | `GET` | `/api/v1/users/me` | `UserApi.kt` (`api/v1/users/me`) | `ShopService.dart` (`/api/v1/users/me`) | **MATCHED** |
| **Documents** | `POST` | `/api/v1/documents/` | `DocumentApi.kt` (`api/v1/documents/`) | N/A (Customer only) | **MATCHED** |
| **Documents** | `GET` | `/api/v1/documents/` | `DocumentApi.kt` (`api/v1/documents/`) | N/A (Customer only) | **MATCHED** |
| **Documents** | `GET` | `/api/v1/documents/{document_id}` | `DocumentApi.kt` (`api/v1/documents/{id}`) | N/A (Customer only) | **MATCHED** |
| **Documents** | `DELETE` | `/api/v1/documents/{document_id}` | `DocumentApi.kt` (`api/v1/documents/{id}`) | N/A (Customer only) | **MATCHED** |
| **Shops** | `GET` | `/api/v1/shops/` | `ShopApi.kt` (`shops/`) | N/A | **MISMATCH (Android missing `api/v1/`)** |
| **Shops** | `GET` | `/api/v1/shops/qr/{qr_identifier}` | `ShopQrApi.kt` (`api/v1/shops/qr/{qr_identifier}`) | N/A | **MATCHED** |
| **Shops** | `GET` | `/api/v1/shop/qr` | `ShopQrApi.kt` (`api/v1/shop/qr`) | `ShopService.dart` (`/api/v1/shop/qr`) | **MATCHED** |
| **Shops** | `POST` | `/api/v1/shop/qr/regenerate` | `ShopQrApi.kt` (`api/v1/shop/qr/regenerate`) | `ShopService.dart` (`/api/v1/shop/qr/regenerate`) | **MATCHED** |
| **Jobs** | `POST` | `/api/v1/print-jobs/` | `PrintJobApi.kt` (`print-jobs/`) | N/A | **MISMATCH (Android missing `api/v1/`)** |
| **Jobs** | `GET` | `/api/v1/print-jobs/customer` | `PrintJobApi.kt` (`print-jobs/customer`) | N/A | **MISMATCH (Android missing `api/v1/`)** |
| **Jobs** | `GET` | `/api/v1/print-jobs/customer/{job_id}` | `PrintJobApi.kt` (`print-jobs/customer/{jobId}`) | N/A | **MISMATCH (Android missing `api/v1/`)** |
| **Jobs** | `GET` | `/api/v1/print-jobs/shop` | `PrintJobApi.kt` (`print-jobs/shop`) | `ShopService.dart` (`/api/v1/print-jobs/shop`) | **Android MISMATCH / Windows MATCHED** |
| **Jobs** | `GET` | `/api/v1/print-jobs/shop/{job_id}` | `PrintJobApi.kt` (`print-jobs/shop/{jobId}`) | `ShopService.dart` (`/api/v1/print-jobs/shop/$jobId`) | **Android MISMATCH / Windows MATCHED** |
| **Jobs** | `POST` | `/api/v1/print-jobs/{job_id}/accept` | `PrintJobApi.kt` (`print-jobs/{jobId}/accept`) | `ShopService.dart` (`/api/v1/print-jobs/$jobId/accept`) | **Android MISMATCH / Windows MATCHED** |
| **Jobs** | `POST` | `/api/v1/print-jobs/{job_id}/start` | `PrintJobApi.kt` (`print-jobs/{jobId}/start`) | `ShopService.dart` (`/api/v1/print-jobs/$jobId/start`) | **Android MISMATCH / Windows MATCHED** |
| **Jobs** | `POST` | `/api/v1/print-jobs/{job_id}/complete` | `PrintJobApi.kt` (`print-jobs/{jobId}/complete`) | `ShopService.dart` (`/api/v1/print-jobs/$jobId/complete`) | **Android MISMATCH / Windows MATCHED** |
| **Jobs** | `POST` | `/api/v1/print-jobs/{job_id}/cancel` | `PrintJobApi.kt` (`print-jobs/{jobId}/cancel`) | N/A | **MISMATCH (Android missing `api/v1/`)** |
| **Security** | `POST` | `/api/v1/print-jobs/{job_id}/secure-access` | `PrintJobApi.kt` (`print-jobs/{jobId}/secure-access`) | N/A | **MISMATCH (Android missing `api/v1/`)** |
| **Security** | `POST` | `/api/v1/shop/document-access/authorize` | `ShopDocumentAccessApi.kt` (`api/v1/...`) | `ShopService.dart` (`/api/v1/...`) | **MISMATCH (Windows payload keys)** |
| **Security** | `GET` | `/api/v1/shop/document-access/{access_id}/download` | `ShopDocumentAccessApi.kt` (`api/v1/...`) | `DocumentAccessService.dart` (`/api/v1/...`) | **MATCHED** |
| **Payment** | `GET` | `/api/v1/shop/print-jobs/{job_id}/payment` | `PaymentApi.kt` (`api/v1/...`) | `ShopService.dart` (`/api/v1/...`) | **MATCHED** |
| **Payment** | `POST` | `/api/v1/shop/print-jobs/{job_id}/payment/mark-paid` | `PaymentApi.kt` (`api/v1/...`) | `ShopService.dart` (`/api/v1/...`) | **MATCHED** |
| **Admin** | `GET` | `/api/v1/admin/shops/pending` | `UserApi.kt` (`api/v1/...`) | N/A | **MATCHED** |
| **Admin** | `POST` | `/api/v1/admin/shops/{shop_id}/approve` | `UserApi.kt` (`api/v1/...`) | N/A | **MATCHED** |
| **Admin** | `POST` | `/api/v1/admin/shops/{shop_id}/reject` | `UserApi.kt` (`api/v1/...`) | N/A | **MATCHED** |
| **Docs** | `GET` | `/docs`, `/redoc`, `/api/v1/openapi.json` | N/A | N/A | **MATCHED** |

---

## 4. SQLite Database Path & Persistence Details

### Runtime Database File Locations
- **Active Authoritative Database**:
  - File: `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\backend\secureprint.db`
  - Size: `245,760 bytes` (Main DB) + `32,768 bytes` (`.db-shm`) + `2,274,272 bytes` (`.db-wal`)
  - Journal Mode: `WAL` (Write-Ahead Logging)
- **Extraneous Empty Databases**:
  - File: `C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\test.db` (Size: `0 bytes`, created previously by test scripts).

### Working Directory Relative Path Vulnerability
In `backend/.env`:
```ini
DATABASE_URL=sqlite:///./secureprint.db
```
Because the path starts with `./`, the SQLite driver resolves the file against the process's **Current Working Directory** (`os.getcwd()`):
- If the server is started from `SecurePrint\backend`: Connects to `SecurePrint\backend\secureprint.db` (correct).
- If started from `SecurePrint` root (`uvicorn backend.app.main:app`): Connects to `SecurePrint\secureprint.db` (creates a new empty database).
- If started from tests or another folder: Creates another separate database.

### Schema & Entity Verification (Read-Only Direct Inspection)
A read-only inspection (`mode=ro`) confirmed that all 11 core tables are provisioned and contain production test data:

```json
{
  "alembic_version": { "current_revision": "bb8ff055357d", "rows": 1 },
  "users": { "rows": 19, "roles": ["ADMIN", "CUSTOMER", "SHOP"] },
  "shops": { "rows": 8, "fk": "owner_id -> users.id" },
  "shop_pricing": { "rows": 65, "fk": "shop_id -> shops.id" },
  "shop_qr_codes": { "rows": 6, "fk": "shop_id -> shops.id" },
  "documents": { "rows": 23, "fk": "owner_id -> users.id" },
  "print_jobs": { "rows": 10, "fk": "customer_id, shop_id, document_id" },
  "print_job_status_history": { "rows": 15, "fk": "print_job_id, changed_by" },
  "payments": { "rows": 10, "fk": "print_job_id, customer_id, shop_id" },
  "temporary_document_access": { "rows": 2, "fk": "print_job_id, document_id, shop_id" },
  "secure_access_tokens": { "rows": 6, "fk": "print_job_id, document_id, shop_id" },
  "audit_logs": { "rows": 18, "fk": "user_id, document_id, print_job_id" }
}
```

### Data Storage Boundary
- **SQLite Engine**: Stores purely structural metadata (user identities, shop addresses, print job configurations, pricing rules, SHA-256 token hashes, payment status, and audit logs).
- **Disk File System**: Stores the actual binary documents in `backend/uploads/` with UUID-based keys. Binaries are never saved directly in SQLite `BLOB` columns, preserving database performance.

---

## 5. Missing Connections, Vulnerabilities & Likely Failure Points

### Failure Point 1: Android Retrofit URL Prefix Omissions (Critical Blocker)
- **Location**: `app/src/main/java/com/example/secureprint/data/api/PrintJobApi.kt` and `ShopApi.kt`
- **Issue**: Retrofit's `BASE_URL` is set to `http://<host>:8000/`. Endpoints in `PrintJobApi.kt` use `@POST("print-jobs/")` and `@GET("print-jobs/customer")`, while `ShopApi.kt` uses `@GET("shops/")`.
- **Impact**: All print job creation, shop browsing, job history, and customer secure QR token requests fail with **HTTP 404 Not Found**.

### Failure Point 2: Secure QR Authorization Schema Mismatch (Critical Blocker)
- **Location**: Backend `routes/shop_document_access.py` / `services/secure_token_service.py` vs. Desktop `models/temporary_document_access_model.dart` / `providers/document_access_provider.dart`
- **Issue**:
  - Backend `/authorize` returns:
    ```json
    {
      "access_id": "900609b5-f485-4dbb-8ff5-cb86e88ca80e",
      "status": "AUTHORIZED",
      "expires_at": "...",
      "print_job_id": 1,
      "document_id": "..."
    }
    ```
  - Desktop `TemporaryDocumentAccessModel.fromJson` expects:
    ```dart
    id: json['id'] as String // Null value causes runtime TypeError crash!
    ```
  - Desktop `DocumentAccessProvider.dart` checks:
    ```dart
    if (_accessModel!.status == 'active') // Evaluates false because status is 'AUTHORIZED'
    ```
- **Impact**: When the shop scans the customer's QR code, the desktop app encounters an unhandled null exception or displays "Unknown authorization status: AUTHORIZED", preventing document download.

### Failure Point 3: Shop Desktop Defaulting to Local Offline Mode (UX/Workflow Trap)
- **Location**: `shop_desktop/lib/core/config/app_config.dart` and `providers/settings_provider.dart`
- **Issue**: Fresh installs default to `AuthenticationMode.localDevelopment` and `Environment.production` (which has an empty `backendUrl: ""`). The Login screen does not provide a button or dropdown to toggle authentication mode or configure the backend URL.
- **Impact**: A new operator cannot connect to the live FastAPI backend on initial startup without first creating a dummy local account, logging in, navigating to Settings, switching the mode, and logging out.

### Failure Point 4: Android Hardcoded Physical LAN IP
- **Location**: `app/src/main/java/com/example/secureprint/data/api/RetrofitClient.kt`
- **Issue**: `USE_PHYSICAL_DEVICE = true` with hardcoded `PHYSICAL_DEVICE_IP = "10.232.3.122"`.
- **Impact**: If the development PC's IP address changes via DHCP or if tested inside an Android Virtual Device (which requires `10.0.2.2`), network calls immediately time out.

### Failure Point 5: Windows Printing Page Range & Orientation Bypass
- **Location**: `shop_desktop/lib/providers/print_execution_provider.dart`
- **Issue**: `Printing.directPrintPdf(printer: printer, onLayout: (_) => pdfBytes, usePrinterSettings: false)` dispatches the entire un-sliced PDF byte array to the Windows Spooler.
- **Impact**: If a customer requests pages `1-3` of a 50-page document, all 50 pages are sent to the printer. Color and duplex/simplex driver settings are also not injected into the print job.

---

## 6. Safe Manual Testing Instructions for Next Phase

Once the prioritized fixes are applied, execute the following controlled manual validation steps:

### Phase 1: Launch Backend with Absolute DB Path
1. Open PowerShell and navigate to the backend directory:
   ```powershell
   cd C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\backend
   ```
2. Activate virtual environment and start FastAPI bound to `0.0.0.0`:
   ```powershell
   .\venv\Scripts\Activate.ps1
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
3. Verify documentation is accessible in a web browser:
   - [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
   - [http://127.0.0.1:8000/api/v1/openapi.json](http://127.0.0.1:8000/api/v1/openapi.json)

### Phase 2: Configure and Connect Windows Shop Software
1. Launch `SecurePrint-Shop.exe`:
   ```powershell
   & "C:\Users\sansk\OneDrive\Desktop\SecurePrint\SecurePrint\shop_desktop\build\windows\x64\runner\Release\SecurePrint-Shop.exe"
   ```
2. In Settings:
   - Set **Environment** to `Development`.
   - Set **Authentication Mode** to `PRODUCTION BACKEND (FASTAPI)`.
   - Confirm **Backend URL** is `http://127.0.0.1:8000`.
   - Set **Preferred Printer** to `Microsoft Print to PDF` (to avoid wasting paper/ink during initial testing).
3. Log in with approved shop credentials:
   - Email: `sbbe29104@t.com`
   - Password: `ShopPass123!`
4. Verify the dashboard loads live orders from SQLite.

### Phase 3: Android Customer Order Submission
1. Verify host IP in Windows terminal:
   ```powershell
   Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*","Ethernet*" | Select-Object IPAddress
   ```
2. Update `PHYSICAL_DEVICE_IP` in `RetrofitClient.kt` to match the current IP.
3. Launch Android Customer App, log in, upload a small test PDF, select the shop, configure 1 B/W single-sided copy, and submit the order.
4. Verify backend returns `200 OK` and creates job record.

### Phase 4: Order Acceptance & QR Handshake
1. On Shop Desktop, view the new incoming job in **Print Jobs**.
2. Click **Accept Job**; verify status transitions to `ACCEPTED`.
3. In Android App, open the job detail screen and tap **Generate Secure Access QR**. Verify countdown timer starts.
4. On Shop Desktop, click **Scan QR**, enter/scan the token string, and click Authorize.
5. Verify document downloads to temp sandbox and renders in Syncfusion PDF viewer.

### Phase 5: Controlled Print Spooling Verification
1. Click **Print Document** and select `Microsoft Print to PDF`.
2. Confirm the print dialog prompt.
3. Save the output PDF when prompted by Windows.
4. Verify backend transitions job status to `COMPLETED` and revokes access token.

---

## 7. Prioritized Minimal Fixes Plan

The following minimal, non-breaking fixes are required to achieve full end-to-end integration:

### Priority 1: Fix Android Retrofit Route Prefixes (Critical)
- **Target Files**:
  - `SecurePrint/app/src/main/java/com/example/secureprint/data/api/PrintJobApi.kt`
  - `SecurePrint/app/src/main/java/com/example/secureprint/data/api/ShopApi.kt`
- **Fix**: Prepend `api/v1/` to all `@POST` and `@GET` annotations:
  - `@POST("api/v1/print-jobs/")`
  - `@GET("api/v1/print-jobs/customer")`
  - `@GET("api/v1/print-jobs/customer/{jobId}")`
  - `@POST("api/v1/print-jobs/{jobId}/cancel")`
  - `@POST("api/v1/print-jobs/{jobId}/secure-access")`
  - `@GET("api/v1/shops/")`

### Priority 2: Fix Desktop Document Access Response Parsing (Critical)
- **Target Files**:
  - `SecurePrint/shop_desktop/lib/models/temporary_document_access_model.dart`
  - `SecurePrint/shop_desktop/lib/providers/document_access_provider.dart`
- **Fix**:
  - Update `TemporaryDocumentAccessModel.fromJson` to accept either `access_id` or `id`:
    ```dart
    id: (json['access_id'] ?? json['id']) as String,
    ```
  - In `DocumentAccessProvider.authorize()`, treat status `"AUTHORIZED"` and `"active"` (case-insensitive) as authorized:
    ```dart
    final status = _accessModel!.status.toUpperCase();
    if (status == 'ACTIVE' || status == 'AUTHORIZED') {
      _setState(DocumentAccessState.authorized);
    }
    ```

### Priority 3: Resolve SQLite Relative Database Path Hazard (High)
- **Target File**: `SecurePrint/backend/app/core/config.py`
- **Fix**: Automatically resolve `DATABASE_URL` relative to the backend root directory when using SQLite:
  ```python
  if settings.DATABASE_URL.startswith("sqlite:///./"):
      backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
      db_file = settings.DATABASE_URL.replace("sqlite:///./", "")
      settings.DATABASE_URL = f"sqlite:///{os.path.join(backend_dir, db_file)}"
  ```

### Priority 4: Expose Mode/URL Configuration on Desktop Login Screen (Medium)
- **Target File**: `SecurePrint/shop_desktop/lib/features/auth/login_screen.dart`
- **Fix**: Add a small gear/settings icon button to the top-right of `LoginScreen` allowing operators to configure Backend URL and toggle between Local and Production Backend mode before authenticating.

### Priority 5: Add Page-Range Slicing to Desktop Print Execution (Medium)
- **Target File**: `SecurePrint/shop_desktop/lib/providers/print_execution_provider.dart`
- **Fix**: Integrate a lightweight PDF page extraction step (using `pypdf` on backend or native page range parameters in the Flutter print plugin) so `Printing.directPrintPdf()` only spools requested pages.
