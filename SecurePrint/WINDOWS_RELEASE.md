# SecurePrint Shop - Windows Release

This document details the release and build process for the SecurePrint Shop Windows desktop application.

## 1. Current Status (M1)
**Framework:** Flutter (Windows Native Desktop)
**Version:** 1.0.0
**Status:** M1 Foundation Complete. A standalone Windows executable is successfully generated.

## 2. Build Command
To generate the release executable, ensure you have the Flutter SDK and Visual Studio 2022 (with C++ Desktop workload) installed.

Run the following command from the `shop_desktop/` directory:
```bash
flutter build windows --release
```

## 3. Release Output Location
After a successful build, the executable and its required runtime files (like `flutter_windows.dll` and the `data/` folder) are located at:
```
shop_desktop/build/windows/x64/runner/Release/secureprint_shop.exe
```

## 4. Limitations & Installer
*   **No final installer:** A final `.msi` or `.exe` installer (like Inno Setup or WiX) has **not** been created yet. Currently, you must distribute the entire `Release/` folder containing the executable and its supporting files.
*   **Authentication:** Not yet implemented.
*   **Auto-updates:** Not yet implemented.
