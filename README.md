# Emp Mobile — Employee Location Tracking (Flutter, Android-first)

A field-employee app for the Emp platform: sign in, go on/off duty (which streams
GPS to the tracking backend), review attendance history, and manage your profile.
Built to match the provided UI screenshots. **Android first; iOS later.**

Talks to the existing backend (`../emp_server`) — no backend changes required:

| Screen   | Endpoint(s) used                                                        |
|----------|-------------------------------------------------------------------------|
| Login    | `POST /api/auth/login` (Base64 creds) → JWT, then `GET /api/auth/me`     |
| Profile  | `GET /api/users?q=<username>` (resolve own record) · logout `POST /api/auth/logout` |
| Duty     | `POST /api/tracking/ingest` — `on-duty` ping on check-in + every 15s; `offline` on check-out |
| History  | `GET /api/attendance` — **not live on the backend yet** (see Gaps)       |

---

## Prerequisites

This environment does **not** have Flutter installed, so the app was authored as
source only. On your dev machine:

- Flutter SDK ≥ 3.4 (`flutter --version`)
- Android Studio + an emulator or a physical device with USB debugging
- The backend running and reachable (`../emp_server` — `docker compose up`, gateway on `:8000`)

## First-time setup

The `lib/` sources and `pubspec.yaml` are committed; the platform folders
(`android/`, `ios/`) are not. Generate them **in place** (this won't overwrite
existing `lib/` or `pubspec.yaml`):

```bash
cd emp_mobile
flutter create --org tech.devopslabs --project-name emp_mobile --platforms=android,ios .
flutter pub get
```

Then apply the two Android edits below (permissions + cleartext for dev), and run.

## Run (Android)

```bash
# Android emulator (reaches host localhost via 10.0.2.2 — the default):
flutter run

# Physical device — point at your machine's LAN IP:
flutter run --dart-define=CORE_BASE=http://192.168.1.20:8000
```

The base URL is configured in [lib/core/config.dart](lib/core/config.dart) and
overridable with `--dart-define=CORE_BASE=...` (no rebuild of source needed).

---

## Required Android edits (after `flutter create`)

### 1. Permissions — `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>` (above `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<!-- Only if you later add background pinging via a foreground service:
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
-->
```

### 2. Cleartext HTTP for local dev (the dev backend is plain `http://`)

Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <domain-config cleartextTrafficPermitted="true">
    <domain includeSubdomains="true">10.0.2.2</domain>
    <!-- add your LAN IP here for physical-device testing -->
  </domain-config>
</network-security-config>
```

Reference it on the `<application>` tag in the manifest:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config"
    ... >
```

> Drop the cleartext config for production — use HTTPS behind the gateway.

### 3. Biometric — `MainActivity`

`local_auth` needs `FlutterFragmentActivity`. Edit
`android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity
class MainActivity : FlutterFragmentActivity()
```

`minSdkVersion` should be **21+** (set in `android/app/build.gradle` if not already).

---

## Architecture

```
lib/
  core/      config.dart (base URL, intervals) · theme.dart (dark UI)
  data/      session.dart (secure token store) · api_client.dart (JWT REST + 401 handling) · models.dart
  services/  auth · profile · tracking (geolocator + ingest) · attendance
  state/     auth_controller · duty_controller (check-in/out + 15s ping loop)
  ui/        login · home_shell (bottom nav) · duty · history · profile · widgets/hold_button
```

- **Auth:** stateless JWT bearer. Token in the platform keystore
  (`flutter_secure_storage`). Any `401` clears it and returns to login.
- **Credentials are Base64-encoded** before POST (obfuscation, per the API
  contract) — `identifier` accepts username *or* mobile.
- **Check-in = presence reporting.** Holding "Check In" for 5s runs the
  verify steps (internet → location) then sends an `on-duty` ping and starts a
  15s ping timer; "Check Out" sends one `offline` ping and stops.

---

## Known gaps / backend TODOs (surfaced honestly in-app — no mock data)

1. **Attendance/History has no backend.** There is no punch-clock table and no
   `/api/attendance` endpoint yet (the tracking service only ingests raw GPS via
   `/api/tracking/ingest` and reads `/locations` + `/route`). The History tab
   calls the contract the web app already targets and shows a clear
   "not available yet" state until the backend ships it. Hours/distance shown in
   the screenshots require this endpoint.
2. **No org/department on the user object.** `UserResponse` has no organization
   or department fields, so the Profile screen shows `—` for those. Role shows
   the raw role UUID (as in the screenshot) — there's no role-name resolution
   endpoint for employees yet.
3. **Foreground/background pinging.** The 15s ping loop runs while the app is in
   the foreground. For reliable on-duty tracking with the screen off, add a
   foreground location service (e.g. `flutter_background_geolocation` or a
   platform foreground service) — scaffolding noted in the manifest above.

## iOS (later)

`flutter create` above already lays down `ios/`. Before running on iOS add to
`ios/Runner/Info.plist`: `NSLocationWhenInUseUsageDescription`,
`NSFaceIDUsageDescription`, and (for dev cleartext) an `NSAppTransportSecurity`
exception. Then `flutter run -d ios`.
# emp-mobile
