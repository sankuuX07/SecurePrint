# SecurePrint Shop - Setup Guide

Welcome to SecurePrint Shop! This application securely bridges customer print requests from the cloud directly to your local Windows printers. 

*Note: Application installation and Start Menu shortcuts will be handled seamlessly by the forthcoming Installer (M15).*

## 1. First Launch & Authentication Modes
Upon launching `SecurePrint-Shop.exe`, you will be greeted by the Login Screen.

### Authentication Modes
SecurePrint Shop supports two explicit authentication modes:
- **Local Development Mode (Default)**: Allows shop owners and testers to create local accounts, test the UI workflow, and navigate the application offline without requiring a live backend connection.
- **Production Backend Mode**: Uses the authoritative FastAPI server (`/api/v1/auth/login`) for authentication, role verification, and live print job coordination.

### Local Test Accounts & Data Storage
In Local Development mode:
1. Click **Sign Up** from the login screen.
2. Fill in the Shop details (Owner Name, Shop Name, Email, Phone, Password, Address, City).
3. Click **Create Account** to generate an isolated local test account.
4. Accounts are persisted securely in your Windows User Application Data directory:
   `%APPDATA%\SecurePrintShop\local_accounts.json`
5. Passwords are never stored in plaintext; they are hashed using salted PBKDF2-HMAC-SHA256 (100,000 iterations).

### Switching Authentication Modes
1. Sign in to the application.
2. Navigate to the **Settings** tab.
3. Under "General Configuration", use the **Authentication Mode** dropdown to toggle between:
   - `LOCAL DEVELOPMENT (OFFLINE)`
   - `PRODUCTION BACKEND (FASTAPI)`
4. The application immediately updates the mode and persists your preference.

## 2. Backend Configuration
If your organization requires a custom server network (or LAN environment), you can configure it before or after logging in:
1. Click the **Settings** gear icon on the application.
2. Under "Configuration", locate **Backend URL**.
3. Enter your assigned production endpoint (e.g., `https://api.secureprint.com`) and click **Save**.
4. Use the **Test Connection** button to verify the application can reach the cloud.

## 3. Login
Enter the Shop credentials provided by your Administrator. Your secure session token will be saved securely to the Windows credential manager, so you will not need to log in again upon restarting the application.

## 4. Printer Setup
1. Turn on and connect your designated printing hardware to Windows. Ensure Windows has successfully installed the required printer drivers.
2. In the SecurePrint application, navigate to the **Settings** tab.
3. Under "Printer Settings", allow the application to scan for available hardware.
4. Select your preferred printing device. This will be the default output for all future print jobs.

## 5. QR Scanner Setup
To authorize documents securely, your Shop requires a barcode/QR scanner. 
1. Plug your USB or Bluetooth barcode scanner into the Windows machine.
2. Ensure the scanner acts as a standard "Keyboard Wedge" (it types the scanned characters and presses Enter).
3. The SecurePrint application's **Secure Access** tab automatically focuses its input field, waiting for your physical scanner input.

## 6. Document Workflow
When a customer arrives at your shop:
1. They will present a **Secure Access QR Code** on their mobile device.
2. Navigate to the **Secure Access** tab in the desktop application.
3. Scan the QR code.
4. If authorized, the document will temporarily download into the application's secure sandbox.
5. You can view the document natively within the application's **Document Preview** screen.
6. Click **Print** to spool the document to your selected local printer. 

## 7. Troubleshooting
- **Grey Screen / Errors**: If the application crashes, you will see a safe "Something went wrong" banner. Navigate back or click the Home tab to reset the view state.
- **Connection Issues**: Go to **Settings -> Diagnostics** and run a network test. Ensure your firewall is not blocking outbound HTTPS requests.
- **Printer Not Showing**: Ensure the printer is visible in the native `Windows Settings -> Printers & Scanners` menu.

## 8. Logout
If you need to change Shop profiles or securely wipe the terminal:
1. Navigate to the **Settings** tab.
2. Scroll to the "Session" section.
3. Click **Logout** and confirm the prompt. This will securely erase your credentials and drop you back to the login screen.

## 9. Version
This guide corresponds to **SecurePrint Shop Version 1.0.0**.
