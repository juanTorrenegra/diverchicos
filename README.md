# diverchicos

A Flutter app for the Diverchicos games and main menu.

## Getting Started

```bash
flutter pub get
flutter run
```

Useful docs: [Flutter documentation](https://docs.flutter.dev/)

## Android development notes

### `adb: device offline`

If `flutter run` builds the APK but reports `adb: device offline`, the project is fine — the phone/USB connection needs attention.

1. Unplug and replug the USB cable (use a data-capable cable/port).
2. On the phone: enable **USB debugging** and accept the computer authorization prompt.
3. If it persists, revoke USB debugging authorizations in Developer options, then reconnect.
4. Reset ADB:

```bash
adb kill-server && adb start-server && adb devices
```

The device should appear as `device`, not `offline`.

### Kotlin / Gradle warnings

This project uses **built-in Kotlin** (`android.builtInKotlin=true` in `android/gradle.properties`).

You may still see warnings about third-party plugins (`audioplayers_android`, `video_player_android`) applying the legacy Kotlin Gradle Plugin. That comes from those packages, not this app. On Flutter 3.44 builds still succeed; watch for plugin updates before future Flutter releases.

Migration reference: [Flutter built-in Kotlin guide](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)

