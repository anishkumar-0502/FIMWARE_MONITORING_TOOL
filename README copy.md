# BMS RS485 Tool (Flutter)

A production-ready Flutter application for communicating with BMS (RX385 IC) via USB-to-RS485.

## Architecture
This project follows a strict **MVC (Model-View-Controller)** pattern using **GetX** for state management and dependency injection.

- **lib/app/data/models**: Contains BMS data models and frame builder/parser.
- **lib/app/data/services**: Platform-abstracted serial communication services.
- **lib/app/modules**: Features divided into modules (Connection, Dashboard, Config, Logs).
- **lib/app/core**: Utilities like CRC16 calculation and responsive UI helpers.

## Features
- **Multi-platform support**: Windows, macOS, Linux, and Android (USB OTG).
- **Responsive UI**: Sidebar for desktop and Bottom Navigation for mobile.
- **BMS Protocol**: Custom frame handling with pluggable CRC16.
- **Real-time Logging**: Hex-level TX/RX logging with export capability.

## Platform Setup

### Desktop (Windows/macOS/Linux)
- Uses `flutter_libserialport`.
- **macOS**: Ensure you enable Serial Port and USB entitlements in `Runner/DebugProfile.entitlements` and `Runner/Release.entitlements`.

### Android
- Uses `usb_serial`.
- Supports USB OTG automatically via `device_filter.xml`.
- Ensure your phone supports USB Host mode.

## Building

### Windows EXE
```bash
flutter build windows
```

### Android APK
```bash
flutter build apk --release
```

### macOS App
```bash
flutter build macos
```

## Protocol Implementation
The `BmsFrame` class handles the protocol:
`Header(1) | DeviceID(1) | Command(1) | Length(1) | Payload(N) | CRC(2)`

CRC is calculated using CRC16-Modbus by default.
