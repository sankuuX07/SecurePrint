# SecurePrint PC Integration Test & Audit Report

**Date:** 2026-10-13  
**Auditor:** Senior Software Integration Engineer  
**Scope:** Android Customer App, FastAPI Backend, SQLite Database, Flutter Windows Shop Desktop Software, Secure Document Access, and Printing Workflow.  
**Authoritative Database Status:** `backend/secureprint.db` (245,760 bytes) preserved untouched without alteration, migration, or deletion. All tests executed using isolated in-memory or temporary test SQLite databases.

---

## 1. Executive Summary

This integration audit evaluated the entire SecurePrint ecosystem to verify cross-platform communication, database integrity, access-control policies, and print execution workflows without requiring a physical Android phone.

### Key Audit Findings:
- **FastAPI Backend & SQLite Database:** Fully functional and robust. All 29 existing pytest cases passed (`29 passed, 0 failed`). In independent isolated runtime testing, all 7 core backend integration areas passed (registration, authentication, document storage, state machines, page/pricing validation, secure QR authorization, token revocation on completion, and role-based access control).
- **Windows Shop Desktop App (Flutter):** Passes all 73 automated tests (`73 passed, 0 failed`). Static analysis reported 35 lint issues (7 warnings, 28 info). However, critical architectural and runtime gaps were uncovered: the Windows app does **not** slice PDFs by page range before printing, does not transmit color or duplex flags to the printer driver, and defaults to a local offline authentication mode with an empty backend URL.
- **Android Customer App:** Compiles successfully and passes debug unit tests. However, automated test coverage is minimal (only 2 basic tests). A contract mismatch was identified in `TemporaryDocumentAccessResponse` where Android expects `id` while the backend returns `access_id`. Additionally, Retrofit is hardcoded to `127.0.0.1:8000` for physical devices with ADB reverse, which fails on an Android emulator without configuration adjustments.

---

## 2. Environment and Component Inventory

| Component | Path / Location | Version / Toolchain | Runtime & Network Configuration |
| :--- | :--- | :--- | :--- |
| **FastAPI Backend** | `SecurePrint/backend` | Python 3.12.10 (Virtualenv `venv`), FastAPI 0.111.0, Uvicorn 0.30.1, SQLAlchemy 2.0.30 | Port `8000`. Default `.env` binds `DATABASE_URL=sqlite:///./secureprint.db`. System python is 3.14.7 (incompatible without venv). |
| **Authoritative DB** | `SecurePrint/backend/secureprint.db` | SQLite 3 WAL Mode | Size: 245,760 bytes. Pristine and untouched during audit. |
| **Document Storage** | `SecurePrint/backend/uploads` | Local filesystem storage | UUID-keyed files (`.pdf`, `.png`, `.jpg`). Page counter uses `pypdf 4.2.0`. |
| **Windows Shop Client** | `SecurePrint/shop_desktop` | Flutter 3.47.2, Dart 3.13.2 | Built for Windows Desktop (Win32/C++ runner). Uses `printing 5.15.0`. |
| **Android Client** | `SecurePrint/app` | Gradle 9.5.0, Android SDK API 34+, OpenJDK 25.0.3 (Android Studio JBR) | `RetrofitClient` configured with `USE_PHYSICAL_DEVICE = true` (`http://127.0.0.1:8000/`). `usesCleartextTraffic="true"`. |
| **Android Emulation / Devices** | Host machine platform tools | Android SDK `platform-tools/adb.exe`, `emulator.exe` | Device attached: `R9ZXB04NXBW` (`adb reverse tcp:8000 tcp:8000` active). Available AVD: `Pixel_7`. |

---

## 3. Commands Executed & Actual Results

### 3.1 Automated Tests

| Target Subsystem | Command Executed | Exit Code | Result Summary | Status |
| :--- | :--- | :---: | :--- | :---: |
| **Backend (pytest with venv)** | `& ".\venv\Scripts\python.exe" -m pytest -v` in `backend` | **0** | **29 passed**, 94 warnings (19.27s) | **PASS** |
| **Backend (system python check)** | `python -m pytest -v` in `backend` | **1** | Failed: `No module named pytest` (System python is Python 3.14; project requires venv Python 3.12) | **FAIL** |
| **Flutter Windows Analysis** | `flutter analyze` in `shop_desktop` | **1** | **35 issues found** (7 warnings for unused imports, 28 info warnings) | **FAIL** (Lints) |
| **Flutter Windows Tests** | `flutter test` in `shop_desktop` | **0** | **73 passed** in 7.0s | **PASS** |
| **Android Compilation** | `.\gradlew.bat compileDebugKotlin` in `SecurePrint` | **0** | BUILD SUCCESSFUL in 4s | **PASS** |
| **Android Unit Tests** | `.\gradlew.bat testDebugUnitTest` in `SecurePrint` | **0** | BUILD SUCCESSFUL in 9s (2 unit tests passed) | **PASS** |

### 3.2 Backend Runtime & HTTP Endpoints

Tested by starting Uvicorn against an isolated runtime test database:
- `GET http://127.0.0.1:8000/` &rarr; HTTP 200 OK (`{"message":"Welcome to SecurePrint API"}`)
- `GET http://127.0.0.1:8000/docs` &rarr; HTTP 200 OK (Swagger UI documentation rendered)
- `GET http://127.0.0.1:8000/api/v1/openapi.json` &rarr; HTTP 200 OK (OpenAPI specification retrieved)

---

## 4. Backend and Database Integration Verification (Phase 3)

All Phase 3 integration checks were executed on an isolated test SQLite database using FastAPI's TestClient and real database models.

| Test ID | Area | Verification Details | Result |
| :---: | :--- | :--- | :---: |
| **3.1** | Customer Registration & Login | Tested `/api/v1/auth/register` with customer role. Verified that invalid credentials return HTTP 400. Verified that valid credentials return HTTP 200 with JWT access token. | **PASS** |
| **3.2** | Document Upload & Persistence | Uploaded multi-page PDF via `/api/v1/documents/`. Verified `pypdf` calculated page count = 3, file size was persisted, status was `ACTIVE`, and storage file was created on disk. | **PASS** |
| **3.3** | Print-Job Lifecycle & State Transitions | Created print job; verified customer and shop retrieval. Executed valid state machine sequence: `CREATED` &rarr; `ACCEPTED` &rarr; `PRINTING` &rarr; `COMPLETED`. Verified invalid jumps (e.g., `ACCEPTED` directly to `COMPLETED`) are rejected with HTTP 400. | **PASS** |
| **3.4** | Page-Range & Pricing Validation | Tested single-sided pricing (2 pages &times; 2 copies &times; ₹2.00 = ₹8.00) and double-sided pricing (3 pages = 2 sheets &times; 1 copy &times; ₹3.00 = ₹6.00). Verified that page ranges exceeding document pages (e.g., "1-10" on a 3-page doc) and malformed strings are rejected with HTTP 400. | **PASS** |
| **3.5** | Secure QR Access, Download, & Revocation | Generated secure token (`POST /api/v1/print-jobs/{job_id}/secure-access`). Authorized access via shop (`POST /api/v1/shop/document-access/authorize`). Downloaded PDF stream (`GET /api/v1/shop/document-access/{access_id}/download`). Completed print job and verified subsequent download requests return HTTP 410 (Gone). | **PASS** |
| **3.6** | SQLite Metadata & File Integrity | Confirmed that `users`, `print_jobs`, and `temporary_document_access` tables in SQLite stored exact status values (`COMPLETED`, `REVOKED`) and that storage paths remained valid. | **PASS** |
| **3.7** | Access Controls & Protection | Verified that unauthenticated requests to `/documents/` and `/print-jobs/customer` return HTTP 401. Verified role protection: customer accessing shop routes returns HTTP 403; customer accessing admin routes returns HTTP 403; shop creating print jobs returns HTTP 403. | **PASS** |

---

## 5. Android and Windows Client Contracts Audit (Phase 4)

### 5.1 Endpoint and Contract Comparison Matrix

| Operation | FastAPI Route | Android Retrofit Method | Flutter Shop Method | Contract Compatibility Status |
| :--- | :--- | :--- | :--- | :--- |
| **Registration** | `POST /api/v1/auth/register` | `AuthApi.register` | `BackendAuthService.register` | **PASS** (Both send uppercase roles `CUSTOMER`/`SHOP`) |
| **Login** | `POST /api/v1/auth/login` | `AuthApi.login` | `AuthService.login` | **PASS** (Both use `application/x-www-form-urlencoded` with `username` & `password`) |
| **Document Upload** | `POST /api/v1/documents/` | `DocumentApi.uploadDocument` | N/A (Shop client does not upload) | **PASS** |
| **Document Delete** | `DELETE /api/v1/documents/{document_id}` | `DocumentApi.deleteDocument` | N/A | **PASS** |
| **Create Print Job** | `POST /api/v1/print-jobs/` | `PrintJobApi.createPrintJob` | N/A | **PASS** |
| **List Shop Jobs** | `GET /api/v1/print-jobs/shop` | `PrintJobApi.getShopPrintJobs` | `ShopService.getPrintJobs` | **PASS** |
| **Accept Print Job** | `POST /api/v1/print-jobs/{jobId}/accept` | `PrintJobApi.acceptPrintJob` | `ShopService.acceptJob` | **PASS** |
| **Start Printing** | `POST /api/v1/print-jobs/{jobId}/start` | `PrintJobApi.startPrintJob` | `ShopService.startJob` | **PASS** |
| **Complete Job** | `POST /api/v1/print-jobs/{jobId}/complete` | `PrintJobApi.completePrintJob` | `ShopService.completeJob` | **PASS** |
| **Gen Secure Token** | `POST /api/v1/print-jobs/{jobId}/secure-access` | `PrintJobApi.createSecureAccessToken` | N/A (Customer feature) | **PASS** (Returns `{"token": "SP-ACCESS-..."}`) |
| **Authorize Token** | `POST /api/v1/shop/document-access/authorize` | `ShopDocumentAccessApi.authorizeSecureAccess` | `ShopService.authorizeDocumentAccess` | **FAIL (Android)** / **PASS (Flutter)** (See 5.2 below) |
| **Download PDF** | `GET /api/v1/shop/document-access/{access_id}/download` | `ShopDocumentAccessApi.downloadDocument` | `DocumentAccessService.downloadDocument` | **PASS** (Both stream file bytes safely) |
| **Resolve Shop QR** | `GET /api/v1/shops/qr/{qr_identifier}` | `ShopQrApi.resolveShopQr` | N/A (Customer scan) | **PASS** |
| **Get Shop QR** | `GET /api/v1/shop/qr` | `ShopQrApi.getMyShopQr` | `ShopService.getShopQr` | **PASS** |

### 5.2 Confirmed Schema & Contract Discrepancies

1. **`TemporaryDocumentAccessResponse` Field Mismatch (Android &rarr; FastAPI)**
   - **File:** `app/src/main/java/com/example/secureprint/data/model/DocumentModels.kt:L20`
   - **FastAPI Code:** `backend/app/services/secure_token_service.py:L146`
   - **Detail:** FastAPI returns `{"access_id": "...", "status": "AUTHORIZED", ...}`. Android's data class expects `val id: String` as a non-nullable required field without default. Kotlinx Serialization throws a missing field exception when parsing this response in the Android app. In contrast, Flutter's `temporary_document_access_model.dart:L17` properly falls back (`json['access_id'] ?? json['id']`).

2. **Android Network Configuration (Emulator vs Physical Device)**
   - **File:** `app/src/main/java/com/example/secureprint/data/api/RetrofitClient.kt:L12-21`
   - **Detail:** `USE_PHYSICAL_DEVICE = true` is hardcoded. On an Android Emulator, `127.0.0.1:8000` points to the emulator itself, failing with `ECONNREFUSED`. To test in the emulator, either `USE_PHYSICAL_DEVICE` must be set to `false` (routing to `10.0.2.2:8000`), or `adb -e reverse tcp:8000 tcp:8000` must be executed.

3. **Flutter Windows Shop Default Environment & Auth Mode Isolation**
   - **File:** `shop_desktop/lib/core/config/app_config.dart:L16-34`
   - **Detail:** On clean launch, `AppConfig.currentEnvironment` defaults to `Environment.production` (which resolves to an empty backend URL `""`), and `authMode` defaults to `AuthenticationMode.localDevelopment`. In this default mode, the desktop app stores users in a local file (`local_accounts.json`) and never connects to the FastAPI backend unless the operator navigates to Settings and switches to `Development` or enters a custom URL.

---

## 6. Printing Workflow Analysis (Phase 5)

We traced the complete implementation from customer upload to printer spooling:

```mermaid
sequenceDiagram
    autonumber
    actor Customer as Android Customer
    participant Backend as FastAPI Backend
    participant DB as SQLite DB
    actor Shop as Windows Shop Client
    participant Printer as Windows Spooler / Driver

    Customer->>Backend: POST /api/v1/documents/ (Upload PDF)
    Backend->>Backend: pypdf counts pages & saves to uploads/
    Backend->>DB: INSERT into documents (ACTIVE)
    Customer->>Backend: POST /api/v1/print-jobs/ (Shop, pages="1-2", copies=2)
    Backend->>DB: INSERT into print_jobs (CREATED, price calculated)
    Shop->>Backend: GET /api/v1/print-jobs/shop
    Shop->>Backend: POST /api/v1/print-jobs/{id}/accept
    Backend->>DB: UPDATE status=ACCEPTED
    Customer->>Backend: POST /api/v1/print-jobs/{id}/secure-access
    Backend-->>Customer: Returns token ("SP-ACCESS-...")
    Customer->>Shop: Displays QR Code; Shop scans QR
    Shop->>Backend: POST /api/v1/shop/document-access/authorize
    Backend->>DB: INSERT into temporary_document_access (ACTIVE, 15 min TTL)
    Shop->>Backend: GET /api/v1/shop/document-access/{access_id}/download
    Backend-->>Shop: Streams PDF bytes
    Note over Shop,Printer: PRINT EXECUTION STEP
    Shop->>Backend: POST /api/v1/print-jobs/{id}/start (status=PRINTING)
    loop For each copy
        Shop->>Printer: Printing.directPrintPdf(pdfBytes)
    end
    Shop->>Backend: POST /api/v1/print-jobs/{id}/complete (status=COMPLETED)
    Backend->>DB: Auto-revokes access & tokens (REVOKED)
```

### Verification of Printing Parameters:

| Printing Parameter | Specified by Customer | Honored by Windows Desktop Spooler? | Technical Reason / Source Trace |
| :--- | :---: | :---: | :--- |
| **Copies** | **Yes** | **YES** | `PrintExecutionProvider.dart:L83`: loops `for (int i = 0; i < job.copies; i++)` and issues multiple print jobs. |
| **Page Range (e.g., "1-2")** | **Yes** | <span style="color:red; font-weight:bold;">NO (CRITICAL)</span> | `PrintExecutionProvider.dart:L81-89`: passes `pdfBytes` (entire raw file) directly to `Printing.directPrintPdf`. There is **no page extraction or PDF slicing** performed. `page_range` is omitted from `PrintJobModel`. |
| **Color Mode (B/W vs Color)** | **Yes** | <span style="color:red; font-weight:bold;">NO</span> | `Printing.directPrintPdf` is invoked without monochrome/color page format flags (`usePrinterSettings: false`). Relies entirely on the printer driver's default setting. |
| **Duplex (Single vs Double)** | **Yes** | <span style="color:red; font-weight:bold;">NO</span> | `Printing.directPrintPdf` does not specify duplex printer settings. Relies entirely on hardware default. |
| **Completion & Token Revocation** | **Yes** | **YES** | Upon print completion, `_shopService.completeJob` triggers backend `revoke_access` and `revoke_tokens_for_job`. Download URL immediately returns HTTP 410. |

> [!WARNING]  
> **Physical Printing Notice:** Physical paper output was **not** claimed or executed during this audit. Only virtual printer and software spooling tracing was performed.

---

## 7. Automated Tests vs Real Runtime Verification

| Subsystem | Automated Test Coverage | Real Runtime Reality | Key Difference / Blind Spot |
| :--- | :--- | :--- | :--- |
| **Android App** | 2 unit tests (`ExampleUnitTest`, `AuthInterceptorTest`) passed. | Retrofit models and network calls are not exercised by Gradle unit tests. | Serialization incompatibilities (such as `access_id` vs `id`) and network loopback constraints (`USE_PHYSICAL_DEVICE`) are completely invisible to automated unit tests. |
| **Windows Shop** | 73 unit/widget tests passed. | Real print execution uses `Printing.directPrintPdf` on a downloaded file. | The 73 Flutter tests mock `ShopService` and `PrinterService` or test local auth. None of them verify whether `pdfBytes` are sliced before spooling or whether printer driver settings match job metadata. |
| **FastAPI Backend** | 29 pytest cases passed. | FastAPI functions identically in real runtime. | Pytest covers backend logic well. However, test fixtures manually define requests and do not validate client-side data serialization libraries. |

---

## 8. The Three Highest-Priority Integration Problems

### 1. Unfiltered PDF Spooling in Windows Shop App (Security & Cost Integrity Issue)
- **Problem:** If a customer uploads a 50-page document and selects pages `1-2`, the backend calculates pricing for 2 pages (e.g., ₹4.00), but `PrintExecutionProvider.dart` spools the entire 50-page document to the physical printer.
- **Affected Files:**
  - `shop_desktop/lib/models/print_job_model.dart` (lacks `page_range` field)
  - `shop_desktop/lib/providers/print_execution_provider.dart:L81-93` (directly prints raw bytes)

### 2. QR Access Authorization Model Mismatch on Android (`access_id` vs `id`)
- **Problem:** When scanning the Customer's Secure Access QR, the backend returns `{"access_id": "...", ...}`, but Android's `TemporaryDocumentAccessResponse` strictly requires `id: String`. This causes a runtime crash or `SerializationException` in Android's `ShopDocumentAccessViewModel`.
- **Affected Files:**
  - `app/src/main/java/com/example/secureprint/data/model/DocumentModels.kt:L19-25`
  - `backend/app/services/secure_token_service.py:L146`

### 3. Client Environment & Network Setup Fragility
- **Problem:** 
  - Android client hardcodes `USE_PHYSICAL_DEVICE = true` (`http://127.0.0.1:8000/`), failing on standard Android Emulators without manual ADB reverse port forwarding.
  - Windows Shop app defaults to `Environment.production` (empty URL `""`) and `AuthenticationMode.localDevelopment`, meaning fresh builds do not talk to the FastAPI backend until manually toggled in settings.
- **Affected Files:**
  - `app/src/main/java/com/example/secureprint/data/api/RetrofitClient.kt:L12`
  - `shop_desktop/lib/core/config/app_config.dart:L16-17`

---

## 9. Smallest Safe Next Steps (Remediation Plan)

1. **Add PDF Page Slicing in Windows Shop App:**
   - In `shop_desktop/lib/models/print_job_model.dart`, add `final String? pageRange;` and parse `json['page_range']`.
   - In `shop_desktop/lib/providers/print_execution_provider.dart`, before printing `pdfBytes`, use `syncfusion_flutter_pdf` (already in `pubspec.yaml`) or `pdf` package to extract only the requested page range into a sliced PDF buffer, and pass that buffer to `Printing.directPrintPdf`.

2. **Harmonize `TemporaryDocumentAccessResponse` Schema:**
   - In `app/src/main/java/com/example/secureprint/data/model/DocumentModels.kt`, add `@kotlinx.serialization.SerialName("access_id") val access_id: String? = null` or make `val id: String = ""` and map both names, mirroring Flutter's resilient fallback.
   - Alternatively, in `backend/app/services/secure_token_service.py:L146`, return both `"id": temp_access.id` and `"access_id": temp_access.id` for dual compatibility.

3. **Make Client Backend URLs Configurable or Dynamically Resolved:**
   - In Android `RetrofitClient.kt`, use `BuildConfig.DEBUG` to select `10.0.2.2:8000` when running under emulator or read from SharedPreferences/build config.
   - In Flutter `shop_desktop/lib/core/config/app_config.dart`, change default `currentEnvironment` to `Environment.development` (`http://127.0.0.1:8000`) and default `authMode` to `AuthenticationMode.productionBackend` for developer builds.
