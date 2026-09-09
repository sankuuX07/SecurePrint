# SecurePrint M2 Final Report

## 1. M1 Verification
M1 was verified. The Windows Desktop foundation (`shop_desktop/`) exists and uses Flutter. It successfully builds and runs on Windows with centralized configuration logic.

## 2. Backend Authentication Contract
The existing backend contract was successfully audited from the FastAPI implementation:
*   **Method**: `POST`
*   **Endpoint**: `/api/v1/auth/login`
*   **Request Structure**: `application/x-www-form-urlencoded`
    *   `username` (email)
    *   `password`
*   **Response Structure**: `application/json`
    ```json
    {
      "access_token": "string",
      "token_type": "bearer",
      "role": "string"
    }
    ```
*   **Authorization Behavior**: 
    *   `400 Bad Request` for incorrect credentials.
    *   `403 Forbidden` for accounts that are pending approval, rejected, or inactive.

## 3. Login UI
A professional Windows Shop Login screen was implemented using Flutter Material components:
*   A clean, centered UI displaying the SecurePrint branding.
*   Email and Password fields with a toggle to show/hide the password.
*   A responsive Login button that shows a loading indicator while authenticating.
*   A visually distinct error container that displays human-readable error messages (e.g., "Invalid credentials", "Access Denied. Shop accounts only.").

## 4. Authentication Architecture
*   **Auth State**: Centralized in `AuthProvider` using Flutter's `ChangeNotifier`. Tracks `uninitialized`, `unauthenticated`, `loggingIn`, and `authenticated`.
*   **Networking**: Added `AuthService` to encapsulate the `/api/v1/auth/login` HTTP request using the `http` package. Checks the `role` property in the token response.
*   **Session Storage**: Handled by `SecureStorage` using `flutter_secure_storage`.
*   **Logout**: `AuthProvider.logout()` deletes the token from secure storage and reverts state to `unauthenticated`.

## 5. Secure Storage
Tokens are securely stored using Windows Data Protection API (DPAPI) via the `flutter_secure_storage` package. This ensures the JWT is never stored in plain text.

## 6. Role Handling
Role enforcement is handled securely:
*   **SHOP**: After successfully receiving a token, the client checks if `role == 'SHOP'`. If so, access is granted.
*   **CUSTOMER**: Rejected by the client. An exception is thrown and the token is not stored.
*   **ADMIN**: Rejected by the client. An exception is thrown and the token is not stored.

## 7. New Files
*   `shop_desktop/lib/services/secure_storage.dart`
*   `shop_desktop/lib/services/auth_service.dart`
*   `shop_desktop/lib/providers/auth_provider.dart`
*   `shop_desktop/lib/features/auth/login_screen.dart`
*   `shop_desktop/test/auth_test.dart`

## 8. Modified Files
*   `shop_desktop/pubspec.yaml`
*   `shop_desktop/lib/main.dart`
*   `shop_desktop/lib/features/dashboard/dashboard_screen.dart`
*   `SHOP_DESKTOP_SETUP.md`

## 9. Backend Changes
NONE. The existing authentication contract was strictly respected.

## 10. Android Changes
NONE. The Android application was not modified.

## 11. Tests
**Desktop Tests**: 
Command: `flutter test test/auth_test.dart`
Result: **All tests passed!** Tests covered valid logins, role rejections (CUSTOMER/ADMIN), invalid credentials (400), backend unavailability, missing input validation, session restoration, and logout.

**Backend Tests**:
Attempted to run backend tests using `venv\Scripts\python -m pytest tests/ -v`.
Result: Failed to run due to an incompatible dependency build error on Python 3.14 (`pydantic-core` requires PyO3 `3.12` max, but local environment is Python `3.14`). Setting the fallback ABI configuration was also unsuccessful. The tests could not be executed locally due to this fundamental environment incompatibility.

**Android Verification**:
Attempted to run `./gradlew test`.
Result: Failed due to missing `ANDROID_HOME` / SDK setup on the development machine.

## 12. Build
**Windows Development Build**: `flutter run -d windows`
**Windows Release Build**: `flutter build windows --release`

## 13. Errors/Warnings
*   **Backend Environment**: The local Python 3.14 installation prevents `pydantic-core` from building correctly when attempting to recreate the virtual environment or run tests. Tests could not be executed.
*   **Android Environment**: Missing Android SDK prevents local execution of Android regression tests.

## 14. Documentation
Updated: `SHOP_DESKTOP_SETUP.md` to document the new login flow, session behavior, and backend connectivity troubleshooting.

## 15. M2 Status
**M2 COMPLETE**
(While backend/Android tests could not be locally verified due to environment limitations outside the scope of M2, all code requirements and security success criteria for the milestone were successfully met and desktop tests passed.)

## 16. Next Milestone
**M3 — Shop Dashboard**
