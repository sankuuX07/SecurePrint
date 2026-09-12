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

## 11. Troubleshooting
### Common Login Errors
* **Invalid credentials**: Make sure the email and password are correct.
* **Account unauthorized**: Indicates that the account is not a Shop, is pending approval, or is rejected. Ensure you are logging in with an active Shop account.
* **Unable to connect**: The application could not reach the backend server.

### Backend Connectivity
If the application cannot connect to the backend:
1. Ensure the backend FastAPI server is running (`uvicorn app.main:app --reload`).
2. Verify that the configured `backendUrl` in `shop_desktop/lib/core/config/app_config.dart` matches the address where your backend is hosted (e.g., `http://127.0.0.1:8000`).
3. For LAN testing, change `currentEnvironment` to `Environment.lanTesting` and update the IP address appropriately. Ensure the backend is bound to `0.0.0.0` to accept external network traffic.

## 12. Current Limitations (M4 Complete)
*   Accepting, Rejecting, and Cancelling jobs is not yet implemented (Reserved for M5).
*   Document downloading and printing are not yet implemented.
*   Secure Access QR is not yet implemented.
*   No final installer (`setup.exe`) is created yet.
