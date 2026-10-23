# SymptoCare — Flutter Application

## 1. Project Overview

SymptoCare is an AI-based symptom analysis and health-risk prediction application. The project aims to provide a mobile interface through which users can interact with symptom-analysis features and related health-risk predictions.

This project is currently under development. This folder contains the current project implementation and configuration.

**Technology:** Flutter and Dart for the mobile application frontend.

Backend services and machine-learning components may be maintained separately. Their integration must be verified against the actual project implementation.

## 2. Development Environment

### Required software

1. **Flutter SDK** — required to build and run the application.
2. **Android Studio** — recommended for Android SDK management and emulator setup.
3. **Android SDK** — required to compile and run the Android application.
4. **Android Emulator or physical Android device** — required to test the application.

### Recommended software

- **Visual Studio Code** with the Flutter extension.
- **Git for Windows** for version control and collaboration.

### Official installation links

- Flutter: [https://docs.flutter.dev/install](https://docs.flutter.dev/install)
- Android Studio: [https://developer.android.com/studio](https://developer.android.com/studio)
- Visual Studio Code: [https://code.visualstudio.com/](https://code.visualstudio.com/)
- Git for Windows: [https://git-scm.com/downloads/win](https://git-scm.com/downloads/win)

## 3. Android SDK Setup
## 3. Android SDK Setup — Exact Components

Install Android Studio first:
https://developer.android.com/studio

Open Android Studio → **Tools → SDK Manager**.

### A. SDK Platforms tab

Select:

- **Android 16.0 (API Level 36) — Android SDK Platform**, if compatible with this project's `compileSdk` setting.

If the project's `android/app/build.gradle` or `android/app/build.gradle.kts` specifies a different `compileSdk` version, install that platform too.

Click **Apply** to install the selected platform.

### B. SDK Tools tab

Ensure these components are checked:

1. **Android SDK Build-Tools** — select the version required by the project; install the latest compatible version offered.
2. **Android SDK Platform-Tools** — required.
3. **Android SDK Command-line Tools (latest)** — required.
4. **Android Emulator** — required if using a virtual Android device.
5. **CMake** — install if required by Flutter's Android setup or a project dependency.
6. **NDK (Side by side)** — install if required by Flutter's Android setup or a project dependency.

Click **Apply** and wait for installation to finish.

### C. Create an Android Emulator

If not using a physical Android phone:

1. Open **Tools → Device Manager**.
2. Click **Create Virtual Device**.
3. Choose **Phone**, then select a Pixel device profile.
4. Choose a compatible Android system image. For a typical Windows x64 computer, select an **x86_64** image when available.
5. Download the image if prompted.
6. Finish creating the virtual device and start it.

A system image is needed for the Android version you want to emulate. A Google Play image is useful when testing features that require the Play Store or Google Play services.

### D. Accept Android SDK licences

Open PowerShell or the VS Code terminal and run:

```bash
flutter doctor --android-licenses
flutter doctor
```

Accept the required licences when prompted and resolve any Android toolchain errors.

### E. Verify the device

Start the emulator, then run:

```bash
flutter devices
```

The emulator or connected Android phone should appear in the device list.

Official Flutter Android setup guide:
https://docs.flutter.dev/platform-integration/android/setup



## 4. Verify the Development Environment

Open a terminal and run:

```bash
flutter --version
flutter doctor
flutter doctor --android-licenses
```

Accept the required Android SDK licences when prompted.

Resolve any required setup issues reported by `flutter doctor` before running the application.

## 5. Project Setup

1. Download and extract the project ZIP.
2. Open the extracted project folder in VS Code or Android Studio.
3. Open a terminal in the directory containing `pubspec.yaml`.
4. Install the project dependencies:

```bash
flutter pub get
```

Keep `pubspec.yaml` and `pubspec.lock` if the lock file exists.

## 6. Run the Application

Start an Android emulator or connect an Android device with USB debugging enabled.

Check the available devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

To check for Dart and Flutter issues:

```bash
flutter analyze
```

## 7. Project Structure

The following are common Flutter project files. Review the actual folder contents before assuming every item is present.

- `lib/` — Dart source code, screens, widgets and application logic.
- `lib/main.dart` — application entry point.
- `lib/screens/` — application screens, if organized this way.
- `lib/widgets/` — reusable UI components, if present.
- `lib/theme/` — theme and styling configuration, if present.
- `android/` — Android-specific configuration and build files.
- `pubspec.yaml` — Flutter dependencies and asset declarations.
- `pubspec.lock` — resolved package versions, if present.
- `assets/` — images, icons and other resources, if used.
- `test/` — tests, if present.

Review the existing source code before reorganizing or renaming files.

## 8. Frontend Development Handover

The Flutter frontend is under development.

Before continuing:

1. Run the existing application.
2. Review the implemented screens, reusable widgets and navigation.
3. Identify completed and unfinished UI components.
4. Preserve the current implementation before making changes.
5. Continue the remaining pages using the existing design and theme.
6. Test navigation and layouts after each significant change.

The Android startup splash-screen behavior is a known issue that still needs review.

The exact list of completed screens and remaining pages should be documented after inspecting the current implementation.

## 9. Backend and API Integration

Backend and machine-learning integration must be checked against the supplied project files and the team's architecture.

If the backend runs separately:

- Obtain the backend setup instructions from the responsible team member.
- Configure the correct backend base URL for the emulator or physical device.
- Confirm the expected API endpoints and request/response formats.
- Test loading, error and successful-response states in the frontend.
- Do not assume that backend-dependent features work without a running service.

Python and a `requirements.txt` file are required only if Python backend code is included and needs to be run locally.

## 10. Dependencies

Flutter dependencies are declared in `pubspec.yaml`.

Install them with:

```bash
flutter pub get
```

Do not install packages individually unless the project requires an additional dependency.

If a new package is introduced, update `pubspec.yaml` and test the application.

## 11. Troubleshooting

### Flutter command not found

Verify that the Flutter SDK is installed and its `bin` directory is added to the system PATH.

### Android licences or SDK errors

Open Android Studio's SDK Manager, install missing components, and run:

```bash
flutter doctor --android-licenses
flutter doctor
```

### Dependencies fail to resolve

Check the internet connection and the package declarations in `pubspec.yaml`, then retry:

```bash
flutter pub get
```

### No device is detected

Start an Android emulator or connect a physical Android device, enable USB debugging if applicable, and run:

```bash
flutter devices
```

### App fails to build

Review the complete terminal error before changing Gradle files, SDK versions or dependencies.

## 12. Security

- Do not commit or share API keys, passwords, access tokens or private credentials.
- Keep secret configuration files out of shared archives and repositories.
- Provide an example configuration with placeholder values if required.
- Use authorised credentials and follow the team's configuration instructions.

## 13. Handover Checklist

Before continuing development:

- [ ] Install and verify Flutter and Android Studio.
- [ ] Confirm Android SDK setup using `flutter doctor`.
- [ ] Run `flutter pub get`.
- [ ] Launch the app using `flutter run`.
- [ ] Review existing screens and navigation.
- [ ] Identify the next frontend tasks.
- [ ] Confirm backend requirements with the responsible team member.
- [ ] Keep credentials private.
