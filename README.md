# Magn

<p align="center">
  <strong>Precision Minimalist Stopwatch & Session Cadence Tracker for Android</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" alt="Platform Android" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License MIT" />
</p>

---

## Overview

**Magn** is an Android stopwatch crafted with a focus on tactile minimalism and precision. Built on Flutter using a monotonic system-clock timing engine, Magn combines fluid sunset chromatics with practical features for athletics, cadence training, and focused sessions.

### Signature Chromatics

| Color Token | Hex Code | Visual Swatch |
| :--- | :--- | :--- |
| **Deep Red** | `#AA0003` | `Color(0xFFAA0003)` |
| **Coral Pink** | `#FF6B6B` | `Color(0xFFFF6B6B)` |
| **Warm Cream** | `#FFEDD5` | `Color(0xFFFFEDD5)` |

---

## Key Features

- **Monotonic Precision**: System-clock driven timing engine immune to system time drift and background app throttling.
- **Tabular Monospace Typography**: Monospaced tabular numeral glyphs (`FontFeature.tabularFigures()`) guaranteeing zero horizontal jitter during millisecond ticks.
- **Interactive Precision Mode**: Toggle between classic `MM:SS` standard cadence and high-resolution centisecond precision mode (`.cs`).
- **Dynamic Lap Delta Tracking**: Real-time lap splits highlighting personal bests (**fastest lap**) and pacing deltas (**slowest lap**).
- **Offline Session Persistence**: Local storage repository preserving recorded sessions across device reboots and app updates.
- **Tactile Haptic Feedback**: Context-aware physical haptics for start, stop, lap splits, and session resets.
- **Automated CI/CD**: Preconfigured GitHub Actions pipeline that verifies formatting, runs test suites, and compiles release APKs.

---

## Architectural Structure

Magn follows Clean Architecture and MVVM patterns:

```text
magn/
├── .github/
│   └── workflows/
│       └── build-apk.yml           # Automated GitHub Actions APK compilation
├── android/                        # Android native platform harness
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart     # Exact brand chromatics & gradient stops
│   │   │   └── app_dimensions.dart # Metrics, radii, and typography scales
│   │   ├── theme/
│   │   │   └── app_theme.dart      # Material 3 system theming
│   │   └── utils/
│   │       ├── haptics_util.dart   # Platform tactile feedback helper
│   │       └── time_formatter.dart # MM:SS, HH:MM:SS, and duration formatting
│   ├── data/
│   │   ├── models/
│   │   │   ├── lap_model.dart      # Lap split entity & serialization
│   │   │   └── session_model.dart  # Session model & JSON converters
│   │   └── repositories/
│   │       └── session_repository.dart # SharedPreferences-backed repository
│   ├── domain/
│   │   └── stopwatch_engine.dart   # High-resolution monotonic timing engine
│   ├── presentation/
│   │   ├── controllers/
│   │   │   └── stopwatch_controller.dart # ChangeNotifier ViewModel
│   │   ├── screens/
│   │   │   ├── history_bottom_sheet.dart # Session history & lap breakdown
│   │   │   └── stopwatch_screen.dart     # Main stopwatch screen
│   │   └── widgets/
│   │       ├── control_buttons.dart      # StadiumBorder Start/Stop/Lap controls
│   │       ├── gradient_scaffold.dart    # Full-screen sunset gradient container
│   │       ├── lap_list_view.dart        # Real-time lap split table
│   │       └── timer_display.dart        # Non-jittering digital timer display
│   └── main.dart                   # Application bootstrap & dependency wiring
├── test/
│   ├── unit/
│   │   ├── stopwatch_engine_test.dart
│   │   └── time_formatter_test.dart
│   └── widget/
│       └── timer_display_test.dart
└── pubspec.yaml
```

---

## Building & Development

### Prerequisites
- Flutter SDK `^3.0.0`
- Android SDK & Java 17

### Local Execution

```bash
# Get dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run unit and widget tests
flutter test

# Run on connected Android device
flutter run
```

### Compiling Release APK

```bash
flutter build apk --release
```
The output APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
