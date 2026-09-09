# SecurePrint M3 Final Report

## 1. M2 Verification
M2 was successfully verified. The Shop Login correctly handles secure authentication. Token storage, session restoration, and logout functionality act as expected. The application correctly routes authenticated users to the Shop Dashboard.

## 2. Backend APIs Used
### A. Shop Profile
*   **Method**: `GET`
*   **Exact Endpoint**: `/api/v1/users/me`
*   **Request**: None.
*   **Response**: `UserResponse` (JSON containing ID, name, email, phone, role, shop_name, address, city).
*   **Authentication**: Bearer Token.
*   **Purpose**: Retrieve the active shop's profile information to display in the Dashboard header and info card.

### B. Recent Jobs
*   **Method**: `GET`
*   **Exact Endpoint**: `/api/v1/print-jobs/shop?page=1&page_size=100`
*   **Request**: Query parameters for `page` and `page_size`.
*   **Response**: `List[PrintJobResponse]` (JSON array of PrintJob objects including status, price, copies, paper_size, etc.).
*   **Authentication**: Bearer Token.
*   **Purpose**: Retrieve the shop's recent jobs to display in the Recent Jobs table and compute the Dashboard job statistics.

## 3. Dashboard UI
A professional, responsive dashboard layout was built in `dashboard_screen.dart`:
*   **Header**: Displays "Welcome, <Shop Name>" and a Refresh button.
*   **Statistics Cards**: A horizontal row of 5 visually distinct cards showing counts for Pending (Orange), Accepted (Blue), Printing (Purple), Completed (Green), and Cancelled (Red) jobs.
*   **Shop Information Card**: Displays the shop's Email, Phone, Address, and City.
*   **Recent Jobs Table**: A list displaying the Job ID, Date, Print Options (e.g., A4 COLOR), and a styled Status Chip. Displays "No print jobs yet." if empty.

## 4. Shop Information
Real Shop data is fetched directly from the authenticated backend token. Values displayed include the Shop Name (in the welcome header), Email, Phone, Address, and City. No IDs are hardcoded; everything depends on the authenticated user.

## 5. Job Information
*   **Statistics**: Computed locally from the first 100 recent jobs. Because the backend does NOT provide a dedicated aggregate statistics endpoint, fabricating one was avoided to strictly adhere to the M3 rules.
*   **Recent Jobs**: Displays real job data including ID, created time, copies, paper size, and color mode.
*   **Statuses**: Exactly matches the backend enums: `CREATED`, `SENT_TO_SHOP`, `ACCEPTED`, `PRINTING`, `COMPLETED`, `CANCELLED`.
*   **Pagination**: Uses a single page fetch of size 100 to populate the recent jobs and stats. Advanced pagination is deferred until a dedicated Job List page is built.

## 6. Refresh
A manual refresh button is located in the dashboard header. Clicking it triggers `DashboardProvider.refresh()`, which re-fetches the shop profile and recent jobs from the APIs and automatically updates the UI and stats.

## 7. Error Handling
*   **Network Errors / 500s**: Caught by `ApiClient` and converted to `ApiException`. The dashboard displays a friendly error message with a "Retry" button.
*   **401 / 403**: A token expiration or unauthorized response immediately sets the state to `unauthorized`. The UI catches this state and automatically triggers `AuthProvider.logout()`, returning the user to the Login screen.

## 8. Security
*   The dashboard relies strictly on the injected JWT from `SecureStorage`.
*   Shop ID is never passed directly by the client to bypass authorization; the backend uses `get_current_user` to identify the shop.
*   Tokens and Authorization headers are securely managed by `ApiClient` and are never printed to the debug console or written to local logs.
*   No customer documents or sensitive keys are retrieved.

## 9. New Files
*   `shop_desktop/lib/models/user_model.dart`
*   `shop_desktop/lib/models/print_job_model.dart`
*   `shop_desktop/lib/services/shop_service.dart`
*   `shop_desktop/lib/providers/dashboard_provider.dart`
*   `shop_desktop/test/dashboard_test.dart`

## 10. Modified Files
*   `shop_desktop/lib/core/networking/api_client.dart`
*   `shop_desktop/lib/features/dashboard/dashboard_screen.dart`
*   `shop_desktop/lib/main.dart`
*   `shop_desktop/pubspec.yaml` (Added `intl` package)
*   `SHOP_DESKTOP_SETUP.md`

## 11. Backend Changes
NONE. The existing APIs were strictly adhered to.

## 12. Android Changes
NONE. Android codebase remains untouched.

## 13. Tests
**Desktop Tests**: 
Command: `flutter test`
Result: **All tests passed!** Tests covered valid dashboard loading, statistical aggregation, 401 handling, and 500 error handling. (`test/widget_test.dart` was removed as it was an outdated M1 scaffold incompatible with the new auth tree).

**Backend Tests**:
As observed in M2, backend tests cannot be locally run due to Python 3.14/pydantic-core environment incompatibilities on the local machine.

**Android Verification**:
As observed in M2, missing Android SDK prevents local execution of Android regression tests.

## 14. Build
**Windows Development Build**: `flutter run -d windows`
**Windows Release Build**: `flutter build windows --release`

## 15. Errors/Warnings
*   **Backend Environment**: Python 3.14 remains incompatible with `pydantic-core`.
*   **Android Environment**: Missing `sdk.dir` prevents Android regression tests.

## 16. Documentation
Updated: `SHOP_DESKTOP_SETUP.md` to document the Dashboard (M3) features, including data sources and computed statistics limitations.

## 17. M3 Status
**M3 COMPLETE**

## 18. Next Milestone
**M4 — Incoming Print Jobs**
