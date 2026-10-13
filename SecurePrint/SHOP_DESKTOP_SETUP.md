# SecurePrint Shop - Setup Guide

Welcome to SecurePrint Shop! This application securely bridges customer print requests directly to your local Windows printers.

---

## 1. First Launch & Authentication Modes
Upon launching `SecurePrint-Shop.exe`, you will be greeted by the Login Screen.

### Authentication Modes
SecurePrint Shop supports two explicit authentication modes:
- **Production Backend Mode (Default)**: Connects to the authoritative FastAPI server (`/api/v1/auth/login`) for authentication, role verification, and live print job coordination.
- **Local Development Mode (Offline Demo)**: Allows testers to create local offline accounts and navigate the UI without requiring an active backend connection.

### Default Backend Connection
By default, the application is configured to connect to the local FastAPI development server at:
```
http://127.0.0.1:8000
```
- **Important**: `127.0.0.1` (localhost) is valid **only when the FastAPI backend is running on the exact same PC** as the SecurePrint Shop desktop application.
- If the backend is not running or unreachable, the application displays a clear connection error banner. It does **not** silently fall back to offline mode.

### LAN / Store Network Configuration (Separate PCs)
If your shop runs the FastAPI backend on a primary counter PC or dedicated server and you are running the desktop client on a separate workstation:
1. Ensure the backend host runs uvicorn listening on its local network interface (`--host 0.0.0.0 --port 8000`).
2. Ensure Windows Firewall on the backend PC allows inbound TCP connections on port 8000 for your private store network.
3. On the client desktop Login Screen, click the **Settings** gear icon in the server connection banner.
4. Under **Backend URL**, enter the host's LAN IP address and port (e.g. `http://192.168.1.100:8000`).
5. Click **Test Connection** to confirm connectivity.
6. Click **Save** to persist the configuration in Windows SecureStorage.
7. **Security Warning**: **Never expose the development server directly to the public internet** (e.g. via raw port-forwarding).

### Local Development / Offline Testing
To run in offline mode for UI testing without the backend:
1. Open the Login screen and click the **Settings** gear icon.
2. Select **Local Development (Offline Demo)** and save.
3. Click **Sign Up** to create an isolated local test account. Accounts are stored in:
   `%APPDATA%\SecurePrintShop\local_accounts.json`
   (Passwords are hashed using salted PBKDF2-HMAC-SHA256 with 100,000 iterations).

---

## 2. Login
Enter the Shop credentials provided by your Administrator. Your secure session token will be saved to the Windows credential manager, so you will remain authenticated upon restarting the application.

---

## 3. Printer Setup
1. Turn on and connect your designated printing hardware to Windows. Ensure Windows has successfully installed the required printer drivers.
2. In the SecurePrint application, navigate to the **Settings** tab.
3. Under "Printer Settings", allow the application to scan for available hardware.
4. Select your preferred printing device.
5. The application automatically queries printer hardware capabilities (`DeviceCapabilitiesW`):
   - Two-sided (duplex) printing requires a hardware duplex unit.
   - Color printing requires a color-capable driver.
   - If a customer requests a capability unsupported by the selected printer, the application displays a warning banner and safely prevents execution.

---

## 4. QR Scanner Setup
To authorize documents securely, your Shop requires a barcode/QR scanner:
1. Plug your USB or Bluetooth barcode scanner into the Windows machine.
2. Ensure the scanner acts as a standard "Keyboard Wedge" (it types the scanned characters and presses Enter).
3. The SecurePrint application's **Secure Access** tab automatically focuses its input field, waiting for your physical scanner input.

---

## 5. Document Workflow
When a customer arrives at your shop:
1. They will present a **Secure Access QR Code** on their mobile device.
2. Navigate to the **Secure Access** tab in the desktop application.
3. Scan the QR code.
4. If authorized, the document will temporarily download into the application's secure sandbox.
5. You can view the document natively within the application's **Document Preview** screen.
6. Click **Print** to spool the document to your selected local printer. 
7. Upon job completion, temporary document access is automatically revoked on the server.

---

## 6. Troubleshooting
- **Connection Issues**: Click the Settings gear on the login screen and click "Test Connection". Ensure the backend service is running and firewall rules allow port 8000.
- **Printer Not Showing**: Ensure the printer is visible in `Windows Settings -> Printers & Scanners`.
- **Printer Capability Warning**: If a job cannot be printed because duplex or color is unsupported, select a printer that supports the required feature.
- **Grey Screen / Errors**: If the application encounters an error, a safe error banner is shown. Return to Home to reset the view.

---

## 7. Logout
If you need to change Shop profiles or securely clear the terminal:
1. Navigate to the **Settings** tab.
2. Scroll to the "Session" section.
3. Click **Logout** and confirm the prompt. This erases active credentials and returns you to the login screen.

---

## 8. Version
This guide corresponds to **SecurePrint Shop Version 1.0.0**.
