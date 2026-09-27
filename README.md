# Emp Mobile — Employee Location Tracking (Flutter, Android & iOS)

A field-employee app for the Emp platform: sign in, go on/off duty (which streams
GPS to the tracking backend), review attendance history, and manage your profile.
Built to match the provided UI screenshots. **Supports both Android and iOS.**

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
- The backend running and reachable (`../emp_server` — `docker compose up`, app on `:8000`)

## First-time setup

The `lib/` sources and `pubspec.yaml` are committed; the platform folders
(`android/`, `ios/`) are not. Generate them **in place** (this won't overwrite
existing `lib/` or `pubspec.yaml`):

```bash
cd emp_mobile
flutter create --project-name emp_mobile --platforms=android,ios .
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

<!-- On-duty tracking runs geolocator's location foreground service.
     FOREGROUND_SERVICE_LOCATION is the Android 14+ (API 34) split of
     FOREGROUND_SERVICE; WAKE_LOCK backs enableWakeLock so pings keep
     flowing with the screen off. -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>

<!-- Android 13+ runtime permission for the tracking notice and the
     location-off countdown. Requested at check-in, not at launch. -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

`ACCESS_BACKGROUND_LOCATION` is deliberately **not** requested: the foreground
service is started while the app is in the foreground, which is exactly the case
Android exempts, and asking for it triggers a Play Store policy review.

`android/app/build.gradle.kts` also needs core-library desugaring, which
`flutter_local_notifications` requires:

```kotlin
compileOptions { isCoreLibraryDesugaringEnabled = true /* ... */ }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
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

> Drop the cleartext config for production — use HTTPS.

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
  core/      config.dart (base URL, intervals, grace period) · theme.dart (dark UI)
  data/      session.dart (secure token store) · api_client.dart (JWT REST + 401 handling) · models.dart
  services/  auth · profile · tracking (geolocator + ingest) · attendance
             connectivity (interface up/down) · notification (channels + countdown)
  state/     auth_controller · duty_controller (readiness gate, check-in/out,
             15s ping loop, location watchdog)
  ui/        login · home_shell (bottom nav + warning banner) · duty · history · profile
             widgets/hold_button · widgets/preflight_dialog · widgets/location_warning_banner
```

- **Auth:** stateless JWT bearer. Token in the platform keystore
  (`flutter_secure_storage`). Any `401` clears it and returns to login.
- **Credentials are Base64-encoded** before POST (obfuscation, per the API
  contract) — `identifier` accepts username *or* mobile.
- **Check-in = presence reporting.** Holding "Check In" for 5s runs the
  verify steps (internet → location) then sends an `on-duty` ping and starts a
  15s ping timer; "Check Out" sends one `offline` ping and stops.
- **Check-in is gated.** `DutyController` watches internet (`connectivity_plus`)
  and location (geolocator service status + a 5s permission poll) continuously.
  Check In only appears when both are on; otherwise the Duty tab shows what is
  missing and opens a prompt with deep links to the OS location and network
  settings. The gate is re-verified inside `checkIn()` too, since it can go
  stale during the 5s hold.
- **On-duty location watchdog.** While on duty, a persistent notification states
  that location is being shared with the organization. If location is switched
  off, the user gets **2 minutes** (`AppConfig.locationGrace`) to restore it —
  counted down in an in-app banner (visible on every tab) *and* in a system
  notification, so it lands with the app backgrounded. If the countdown expires,
  the app checks the user out by itself and sends a final `offline` ping with
  `statusReason: "location-disabled"` so the roster can tell an automatic
  check-out apart from a deliberate one.
- **Background survival.** On-duty position updates run through geolocator's
  Android location **foreground service** (its notification is the "tracking is
  on" disclosure) and, on iOS, `UIBackgroundModes: location` with
  `allowBackgroundLocationUpdates`. Note geolocator's own caveat: a foreground
  service raises the process priority but does not make Android's killing of a
  destroyed activity impossible — for hard guarantees you still need a
  dedicated background-geolocation engine.

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
3. **Internet check is interface-level.** `connectivity_plus` reports whether a
   network interface is up, not whether the internet is actually reachable —
   connected Wi-Fi with a dead uplink still reads as online. That is deliberate
   for the pre-check-in gate (instant, no traffic); the real end-to-end test is
   the `/api/tracking/ingest` call during check-in, which fails the shift if the
   network is truly dead.
4. **Process death still ends tracking.** The foreground service keeps a shift
   alive while the app is backgrounded, but if Android kills the process (or the
   user force-stops it) the ping loop and the 2-minute watchdog stop with it —
   no `offline` ping is sent, so the web roster keeps showing the last reported
   status and position **indefinitely**: the backend has no server-side
   staleness rule, so `status` is only ever what this app last sent. A
   headless/background-isolate engine would be needed to close that gap (and a
   server-side "older than N minutes ⇒ offline" rule would make the roster
   self-healing regardless).
5. **Every ping depends on the backend having its tracking endpoints registered.**
   `/api/tracking/**` is served by the same application as the rest of the API, so
   there is no second service to configure. If that application is deployed without
   its tracking controllers registered, check-in and the 15s duty pings fail with
   **404** `No static resource api/tracking/ingest` — surfaced verbatim by
   `api_client`'s error path. That's a deployment fault, never an app bug, and no
   mobile change can fix it. **401** likewise means the token was rejected (e.g. the
   backend restarted with no `EMP_JWT_SECRET` and generated a new random key).

## iOS Setup & Run

`flutter create` above generates `ios/`. Before running on iOS, add the following to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location access is required to report duty location pings.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Location access is required for continuous duty tracking.</string>
<key>NSFaceIDUsageDescription</key>
<string>Face ID authentication is required to unlock your session.</string>

<!-- For local dev cleartext HTTP -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

Run on iOS Simulator or physical iOS device:
```bash
flutter run -d ios
```
