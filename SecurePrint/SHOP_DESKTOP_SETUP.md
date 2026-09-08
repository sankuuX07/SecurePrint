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

## 8. Current M1 Limitations
*   The Dashboard screen is a placeholder.
*   Authentication (Shop Login) is not yet implemented.
*   Print Jobs, Documents, Printing, History, and Settings navigation tabs show placeholder screens.
*   No final installer (`setup.exe`) is created yet; only the raw executable and runtime files are built.
