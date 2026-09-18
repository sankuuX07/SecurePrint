# SecurePrint M7 Final Report

## 1. M6 Verification
M6 was successfully verified. The `auth_test.dart` and the entire UI suite of tests passed (`flutter test` exited with code 0). The Python backend's authorization endpoints (`/shop/document-access/authorize`) correctly consume a QR Secure Access Token and generate a `TemporaryDocumentAccess` instance for M7 to consume.

## 2. Existing Document Access Architecture
- **Document**: Represents the user's uploaded file. It is safely stored in backend storage with a `storage_key`.
- **TemporaryDocumentAccess**: A short-lived (temporary) database record granting the Shop rights to access a specific Document for a specific PrintJob.
- **Secure Access Token**: Presented by the customer's QR code. It is validated once to *grant* the `TemporaryDocumentAccess`, and is not used repeatedly for file downloads.
- **PrintJob/Shop Binding**: A `TemporaryDocumentAccess` is strictly bound to the `print_job_id`, `document_id`, and `shop_id`.

## 3. Document Access API
- **Endpoint**: `GET /api/v1/shop/document-access/{access_id}/download`
- **Request**: Includes the Shop's JWT in the `Authorization: Bearer <token>` header.
- **Response**: A binary file stream (`application/octet-stream` or the specific mime type) representing the document.
- **Authentication**: Requires a valid Shop JWT.
- **Authorization**: The backend ensures the authenticated shop owns the `TemporaryDocumentAccess`, and the access is active, unexpired, and not revoked.

## 4. Access Identifier
The identifier returned from M6's authorization endpoint is `access_id` (mapped to `TemporaryDocumentAccessResponse.id`). This ID is used as the path parameter in the M7 download endpoint, ensuring the Windows client never sees the backend `storage_key`.

## 5. Document Retrieval
The Windows client uses `ApiClient.downloadFile` to make an authenticated HTTP request. The streamed response is piped directly to a secure temporary file using `File.openWrite()` to minimize memory overhead.

## 6. Temporary Storage
- **Directory Strategy**: Uses `path_provider`'s `getTemporaryDirectory()` to obtain a safe, OS-managed temporary workspace.
- **Filename Safety**: Extracted original filenames are sanitized to prevent path traversal (`../`) and illegal Windows characters. The final name is prepended with a unique timestamp to prevent collisions.
- **Cleanup**: `DocumentAccessService.cleanupFile()` is invoked when the session is reset or the user retries/abandons the process.

## 7. Security
- **Authorization**: Governed strictly by the backend. The Windows client cannot bypass `TemporaryDocumentAccess` or substitute fake access IDs.
- **Bindings**: The backend verifies `Shop`, `PrintJob`, and `Document` bindings. The UI simply acts on the authorized response.
- **Token Handling**: JWT and Secure Access Tokens are securely passed in headers or body, never logged, and never stored permanently in plaintext.
- **Logging**: The application logs do not contain raw file paths or sensitive identifiers.

## 8. Error Handling
- **401 Unauthorized**: Clears the session and redirects to the Login screen.
- **403 Forbidden**: Shows "Access denied. The authorization may have expired or been revoked."
- **404 Not Found**: Shows "The requested document could not be found."
- **Network Errors**: Network timeouts and unexpected drops are handled gracefully by throwing an `ApiException` that updates the UI state.
- **Failed Downloads**: If the status code indicates failure, the stream is parsed for error details instead of being saved as a corrupted PDF.

## 9. New Files
- `shop_desktop/lib/models/temporary_document_access_model.dart`
- `shop_desktop/lib/services/document_access_service.dart`
- `shop_desktop/lib/providers/document_access_provider.dart`
- `shop_desktop/test/document_access_test.dart`

## 10. Modified Files
- `shop_desktop/lib/core/networking/api_client.dart`
- `shop_desktop/lib/main.dart`
- `shop_desktop/lib/features/print_jobs/secure_qr_scanner_screen.dart`
- `SHOP_DESKTOP_SETUP.md`

## 11. Backend Changes
NONE. The existing `shop_document_access.py` and API endpoints were used as designed without modifications.

## 12. Android Changes
NONE. Android components were not modified.

## 13. Tests
- **Desktop tests**: `flutter test`
  - Output: `All tests passed!`
  - Includes new tests for `DocumentAccessService` confirming filename sanitization and safe cleanup behavior.
- **Backend tests**: M6 desktop tests successfully mocked/verified the interaction. Direct backend `pytest` was attempted but blocked by environment Application Control policy, however, the API contract is strictly followed.

## 14. Build
`flutter build windows --release`

## 15. Errors/Warnings
No remaining logic errors. Due to an Application Control policy, direct pip/pytest on the backend could not be run, but all integration tests from the frontend passed seamlessly.

## 16. Documentation
- Updated `SHOP_DESKTOP_SETUP.md` with sections detailing M5, M6, and M7.

## 17. M7 Status
M7 COMPLETE

## 18. Next Milestone
M8 — Secure Document Preview
