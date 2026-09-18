# SecurePrint Shop Desktop Setup

This guide provides instructions for setting up and running the SecurePrint Shop Windows desktop application.

## 1. Selected Framework
**Flutter (Windows Desktop)**
Flutter natively compiles to Windows desktop and aligns well with the existing declarative UI approach (Jetpack Compose) used in the Android application.

## 2. Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) (Stable channel, version 3.x+)
*   Visual Studio 2022 (with "Desktop development with C++" workload)
*   Git

## 3. Project Location
The Windows desktop application is located in the `shop_desktop/` directory of the repository root.

## 4. How to Run in Development
To run the application locally during development:
1. Open a terminal and navigate to the project directory:
   ```bash
   cd shop_desktop
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run -d windows
   ```

## 5. Backend URL Configuration
The application uses a centralized configuration system. 
You can find the configuration in `shop_desktop/lib/core/config/app_config.dart`.

To change the backend URL, modify the `backendUrl` getter or the `currentEnvironment` static variable.
Currently, it supports three environments:
*   `Environment.development` -> `http://127.0.0.1:8000`
*   `Environment.lanTesting` -> `http://<your-lan-ip>:8000`
*   `Environment.production` -> `https://api.secureprint.example.com`

**Development Backend Example:**
```dart
static Environment currentEnvironment = Environment.development;
```

## 6. Application Version
The current application version is **1.0.0**. This is configured in:
* `shop_desktop/lib/core/config/app_config.dart`
* `shop_desktop/windows/runner/Runner.rc`
* `shop_desktop/windows/CMakeLists.txt`

## 7. Windows Release Build
To build the application for release (without debugging overlays):
1. Navigate to the project directory:
   ```bash
   cd shop_desktop
   ```
2. Run the build command:
   ```bash
   flutter build windows --release
   ```

### 7.1 Generated Release Output
The built executable and required DLLs will be located at:
```
shop_desktop/build/windows/x64/runner/Release/secureprint_shop.exe
```

## 8. Authentication & Session (M2)

### Shop Login
The application provides a secure login screen connected to the FastAPI backend at `/api/v1/auth/login`. 
- **Roles**: Only accounts with the `SHOP` role are permitted to log in. `CUSTOMER` and `ADMIN` accounts will be rejected.
- **Tokens**: Upon successful authentication, a JWT `access_token` is returned.
- **Storage**: The token is securely stored using Windows DPAPI (via `flutter_secure_storage`). Passwords and tokens are never saved to plaintext configuration files or logged.

### Session Behavior
On application startup, the application checks the secure storage for an existing token:
- If a token is found, the application restores the session and routes the user directly to the Dashboard.
- If no token is found, the application routes the user to the Login screen.
- If an API request returns a `401 Unauthorized` or `403 Forbidden` response, the session will be cleared locally and the user will be returned to the Login screen.

### Logout
Logging out removes the authentication session from local secure storage and returns the user to the Login screen. 

## 9. Dashboard (M3)
The Windows Shop Dashboard connects to the FastAPI backend to display real-time shop data:
- **Shop Profile**: Displays shop information fetched from `/api/v1/users/me`.
- **Job Statistics**: Computes statistics for Pending, Accepted, Printing, Completed, and Cancelled jobs. To avoid fabricating non-existent backend APIs, these statistics are derived from the most recent fetched page of jobs.
- **Recent Jobs**: Displays a real-time table of recent print jobs fetched from `/api/v1/print-jobs/shop`.
- **Refresh**: The dashboard includes a manual refresh button to fetch the latest data from the server.
- **Security**: The dashboard respects backend-enforced roles and automatically redirects to the Login screen if the session expires (401 Unauthorized).

## 10. Print Jobs Screen (M4)
The Windows Shop application features a dedicated Print Jobs screen to list incoming and existing jobs:
- **Incoming Jobs**: Lists all print jobs associated with the authenticated Shop.
- **Filtering**: Shops can filter print jobs by their status (`CREATED`, `SENT_TO_SHOP`, `ACCEPTED`, `PRINTING`, `COMPLETED`, `CANCELLED`).
- **Data Display**: Shows `Job ID`, `Date`, `Copies`, `Paper Size`, `Color Mode`, `Print Side`, `Price`, and `Status`. 
- **Pagination**: Supports server-side pagination to efficiently fetch large lists of jobs.
- **Refresh**: Includes a manual refresh action to update the job list.
- **Security**: Ensures jobs can only be viewed by the authenticated Shop that owns them. Backend prevents unauthorized access and cross-shop data leaks. No sensitive documents or credentials are computationally exposed.

## 11. Job Actions (M5)
The Windows Shop application allows Shops to manage the lifecycle of print jobs:
- **Accept**: Moves a job from `SENT_TO_SHOP` to `ACCEPTED`.
- **Start Printing**: Moves a job from `ACCEPTED` to `PRINTING`.
- **Complete**: Moves a job from `PRINTING` to `COMPLETED`.
- **Cancel**: (Optional/Reserved for future M-modules).
- **Security**: Actions are securely verified on the backend. Only the assigned Shop can transition job states.

## 12. Secure QR Scanner (M6) & Document Access (M7)
The application includes a Secure QR Scanner to authenticate customer presence and authorize access to their documents:
- **QR Scanning**: Opens a webcam scanner to capture the customer's Secure Access Token.
- **Backend Validation**: The token is sent to the backend (`/api/v1/shop/document-access/authorize`) for validation. The backend ensures the token is valid, unexpired, and matches the Shop and Job.
- **Temporary Access**: If valid, the backend grants a `TemporaryDocumentAccess` record. The Windows client receives an access identifier but never the direct document storage key.
- **Authorized Document Retrieval**: The Windows client requests the secure document via `/api/v1/shop/document-access/{access_id}/download` using the authenticated Shop session.
- **Temporary Storage**: The downloaded PDF is stored in a secure, temporary local working directory.
- **Document Preview (M8)**: Automatically launches `DocumentPreviewScreen` using `syncfusion_flutter_pdfviewer` to safely render the PDF. The temporary file is released when the preview is closed.
- **Windows Printer Selection (M9)**: Uses the `printing` package to natively discover Windows printers. Highlights the default printer and persists the shop's preferred printer across sessions using SecureStorage. Validates printer availability before printing.
- **Actual Printing & Spooling (M10)**: Sends the authorized document directly to the Windows Spooler. Supports multi-copy jobs via sequential spooling. Implements robust status synchronization to the backend (`PRINTING -> COMPLETED`) and locking to prevent accidental double prints.
- **Error Handling**: Handles scenarios like expired tokens, revoked access, wrong Shop, corrupted downloads, missing documents, or backend synchronization network failures.
- **Cleanup**: Temporary files are rigorously wiped when the print execution completes, the dialogue is dismissed, or the M8 preview closes. No permanent public document URL or file path is exposed.

## 13. Troubleshooting
### Common Login Errors
* **Invalid credentials**: Make sure the email and password are correct.
* **Account unauthorized**: Indicates that the account is not a Shop, is pending approval, or is rejected. Ensure you are logging in with an active Shop account.
* **Unable to connect**: The application could not reach the backend server.

### Backend Connectivity
If the application cannot connect to the backend:
1. Ensure the backend FastAPI server is running (`uvicorn app.main:app --reload`).
2. Verify that the configured `backendUrl` in `shop_desktop/lib/core/config/app_config.dart` matches the address where your backend is hosted (e.g., `http://127.0.0.1:8000`).
3. For LAN testing, change `currentEnvironment` to `Environment.lanTesting` and update the IP address appropriately. Ensure the backend is bound to `0.0.0.0` to accept external network traffic.

## 14. Current Limitations (M10 Complete)
*   No final installer (`setup.exe`) is created yet.
*   Backend tests cannot be run natively due to python environment configuration.
