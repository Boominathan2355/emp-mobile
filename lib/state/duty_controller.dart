import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/config.dart';
import '../data/models.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/tracking_service.dart';

/// Duty lifecycle. "Check in" = a stream of `on-duty` GPS pings on a timer;
/// "check out" = a single `offline` ping that stops the stream. Mirrors the
/// screenshot's verification steps (internet OK -> checking location -> ingest).
///
/// Two guards run off the same set of subscriptions:
///
///  * **Before duty** — internet and location are watched continuously so the
///    Duty screen can offer Check In only when both are on, and prompt for
///    whichever is missing otherwise. See [preflightReady].
///  * **During duty** — if location goes away, the user gets
///    [AppConfig.locationGrace] to restore it (in-app banner + a system
///    notification counting down), after which the app takes them off duty and
///    tells the backend why. Losing *network* mid-shift is not fatal: pings
///    simply retry on the next tick.
enum VerifyStep { idle, internet, location, sending, done, failed }

class DutyController extends ChangeNotifier {
  DutyController(this._user) {
    _startReadinessMonitor();
  }

  final AppUser _user;
  final _tracking = TrackingService();
  final _connectivity = ConnectivityService();
  final _notifications = NotificationService.instance;

  bool onDuty = false;
  VerifyStep step = VerifyStep.idle;
  bool internetOk = false;
  bool locationOk = false;
  String? error;

  /// Live pre-check-in state. Null means "not determined yet" — the Duty screen
  /// shows a checking state rather than flashing a false "turn it on" prompt on
  /// the first frame.
  bool? networkReady;
  bool? locationReady;

  /// True once both prerequisites have been determined, either way.
  bool get preflightChecked => networkReady != null && locationReady != null;

  /// Whether Check In can be offered at all.
  bool get preflightReady => networkReady == true && locationReady == true;

  /// True while location is unavailable and the grace countdown is running.
  bool locationLost = false;

  /// Time left before the automatic check-out. Only meaningful while
  /// [locationLost]; drives the banner and the notification countdown.
  Duration graceRemaining = Duration.zero;

  /// Set when the *app* ended the shift rather than the user. Cleared on the
  /// next check-in or when the user dismisses it.
  bool autoCheckedOut = false;

  Timer? _pingTimer;
  Timer? _graceTimer;
  Timer? _readinessTimer;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<ServiceStatus>? _serviceSub;
  StreamSubscription<bool>? _connectivitySub;
  Position? _lastPosition;
  DateTime? _graceDeadline;
  bool _disposed = false;

  bool get verifying =>
      step != VerifyStep.idle &&
      step != VerifyStep.done &&
      step != VerifyStep.failed;

  // ---------------------------------------------------------------------------
  // Readiness monitoring (runs for the controller's whole life)
  // ---------------------------------------------------------------------------

  /// Watches internet and location for as long as this controller exists. The
  /// same signals serve the pre-check-in gate and the on-duty watchdog, so
  /// there is one subscription set rather than two that could disagree.
  void _startReadinessMonitor() {
    // "disabled" is conclusive, "enabled" is not: the GPS toggle can come back
    // on while the app's location *permission* is still revoked. Confirming via
    // refresh() keeps a half-restored state from cancelling a running grace
    // countdown and handing out a fresh 2 minutes every time it flaps.
    _serviceSub = _tracking.serviceStatusStream.listen(
      (status) {
        if (status == ServiceStatus.disabled) {
          _setLocationReady(false);
        } else {
          unawaited(refresh());
        }
      },
      onError: (_) {},
    );
    _connectivitySub = _connectivity.onlineChanges.listen(
      _setNetworkReady,
      onError: (_) {},
    );

    // The streams above cover the OS toggles. The poll is what catches a
    // location *permission* revoked from app settings, which the service
    // stream never reports, and re-syncs after the app is resumed.
    _readinessTimer =
        Timer.periodic(AppConfig.locationWatchdogInterval, (_) => refresh());
    unawaited(refresh());
  }

  /// Re-reads both prerequisites now. Called on a timer, and by the Duty screen
  /// when the user asks to re-check from the prompt.
  Future<void> refresh() async {
    final results = await Future.wait([
      _tracking.isLocationUsable(),
      _connectivity.isOnline(),
    ]);
    _setLocationReady(results[0]);
    _setNetworkReady(results[1]);
  }

  void _setNetworkReady(bool ready) {
    if (networkReady == ready) return;
    networkReady = ready;
    _safeNotify();
  }

  /// Location availability feeds the pre-check-in gate when off duty and the
  /// grace countdown when on duty.
  void _setLocationReady(bool ready) {
    final changed = locationReady != ready;
    locationReady = ready;

    if (onDuty) {
      if (ready) {
        _onLocationRestored();
      } else {
        _onLocationLost();
      }
    }
    if (changed) _safeNotify();
  }

  // ---------------------------------------------------------------------------
  // Check in / out
  // ---------------------------------------------------------------------------

  /// Runs the verification sequence, sends the first `on-duty` ping, then keeps
  /// pinging every [AppConfig.pingInterval] until [checkOut].
  ///
  /// The Duty screen only offers this once [preflightReady] is true, but it is
  /// re-verified here anyway: the gate can go stale between the tap and the
  /// 5-second hold completing.
  Future<void> checkIn() async {
    error = null;
    internetOk = false;
    locationOk = false;
    autoCheckedOut = false;
    step = VerifyStep.internet;
    notifyListeners();
    try {
      // 1. Connectivity — interface state up front, then the ingest call below
      //    is the real end-to-end test.
      if (!await _connectivity.isOnline()) {
        throw StateError(
            'No internet connection. Turn on mobile data or Wi-Fi to check in.');
      }
      internetOk = true;
      step = VerifyStep.location;
      notifyListeners();

      // 2. Location permission + fix.
      await _tracking.ensureLocationReady();
      final pos = await _tracking.currentPosition();
      _lastPosition = pos;
      locationOk = true;
      step = VerifyStep.sending;
      notifyListeners();

      // 3. First report.
      await _tracking.ingest(
          user: _user, status: PresenceStatus.onDuty, pos: pos);

      onDuty = true;
      step = VerifyStep.done;

      // Asked for at check-in rather than app start: the permission prompt is
      // far easier to say yes to when the countdown it powers is about to
      // matter. A "no" only costs the notification, never the shift.
      await _notifications.requestPermission();
      await _notifications.showTrackingOn();

      _startPinging();
      _startPositionStream();
      notifyListeners();
    } catch (e) {
      step = VerifyStep.failed;
      error = e is StateError ? e.message : 'Check-in failed. $e';
      notifyListeners();
    }
  }

  Future<void> checkOut() async {
    _stopTracking();
    try {
      await _tracking.ensureLocationReady();
      final pos = await _tracking.currentPosition();
      await _tracking.ingest(
          user: _user, status: PresenceStatus.offline, pos: pos);
    } catch (_) {
      // Even if the final report fails, we still go off duty locally.
    }
    onDuty = false;
    locationLost = false;
    graceRemaining = Duration.zero;
    autoCheckedOut = false;
    step = VerifyStep.idle;
    await _notifications.cancelAll();
    _safeNotify();
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(AppConfig.pingInterval, (_) async {
      if (!onDuty || locationLost) return;
      try {
        final pos = _lastPosition ?? await _tracking.currentPosition();
        _lastPosition = pos;
        await _tracking.ingest(
            user: _user, status: PresenceStatus.onDuty, pos: pos);
      } catch (_) {
        // Transient failure — keep the timer; next tick retries.
      }
    });
  }

  /// Keeps a fresh fix around for the ping timer and, on Android, is what runs
  /// the foreground service that stops the OS freezing the shift while the app
  /// is backgrounded. Deliberately decoupled from the ping cadence: GPS updates
  /// as often as it likes, the network only every [AppConfig.pingInterval].
  void _startPositionStream() {
    _positionSub?.cancel();
    _positionSub = _tracking.dutyPositionStream().listen(
      (pos) => _lastPosition = pos,
      onError: (_) {
        // The stream dies when location goes away; the watchdog owns that case.
      },
      cancelOnError: false,
    );
  }

  // ---------------------------------------------------------------------------
  // On-duty location watchdog
  // ---------------------------------------------------------------------------

  /// Starts (or leaves running) the grace countdown. Idempotent — the service
  /// stream and the poll both reach here and must not restart each other's
  /// clock.
  void _onLocationLost() {
    if (!onDuty || locationLost) return;

    locationLost = true;
    _graceDeadline = DateTime.now().add(AppConfig.locationGrace);
    graceRemaining = AppConfig.locationGrace;

    // The Android foreground service cannot survive without location updates;
    // drop the stream now and rebuild it if location comes back.
    _positionSub?.cancel();
    _positionSub = null;

    unawaited(_notifications.cancelTrackingOn());
    unawaited(_notifications.showLocationOffWarning(graceRemaining));

    _graceTimer?.cancel();
    _graceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = _graceDeadline;
      if (deadline == null) return;
      final left = deadline.difference(DateTime.now());
      graceRemaining = left.isNegative ? Duration.zero : left;
      if (graceRemaining == Duration.zero) {
        unawaited(_autoCheckOut());
      } else {
        unawaited(_notifications.showLocationOffWarning(graceRemaining));
        _safeNotify();
      }
    });
    _safeNotify();
  }

  /// Cancels the countdown and resumes tracking. Also idempotent.
  void _onLocationRestored() {
    if (!locationLost) return;

    locationLost = false;
    _graceDeadline = null;
    graceRemaining = Duration.zero;
    _graceTimer?.cancel();
    _graceTimer = null;

    unawaited(_notifications.cancelLocationOffWarning());
    if (onDuty) {
      unawaited(_notifications.showTrackingOn());
      _startPositionStream();
    }
    _safeNotify();
  }

  /// Ends the shift because location stayed off past the grace period.
  ///
  /// The final `offline` ping uses the last fix we hold — a fresh one is by
  /// definition unavailable — and carries [AppConfig.reasonLocationDisabled]
  /// so the roster shows this as an automatic check-out, not a deliberate one.
  Future<void> _autoCheckOut() async {
    if (!onDuty) return;

    _stopTracking();
    final pos = _lastPosition ?? await _tracking.lastKnownPosition();
    if (pos != null) {
      try {
        await _tracking.ingest(
          user: _user,
          status: PresenceStatus.offline,
          pos: pos,
          statusReason: AppConfig.reasonLocationDisabled,
        );
      } catch (_) {
        // Off duty locally regardless; the server ages the stale ping out.
      }
    }

    onDuty = false;
    locationLost = false;
    graceRemaining = Duration.zero;
    autoCheckedOut = true;
    step = VerifyStep.idle;

    await _notifications.cancelLocationOffWarning();
    await _notifications.cancelTrackingOn();
    await _notifications.showAutoCheckedOut(AppConfig.locationGrace);
    _safeNotify();
  }

  // ---------------------------------------------------------------------------
  // Actions the UI can take
  // ---------------------------------------------------------------------------

  /// Dismisses the "you were taken off duty" notice.
  void acknowledgeAutoCheckOut() {
    if (!autoCheckedOut) return;
    autoCheckedOut = false;
    unawaited(_notifications.cancelAll());
    notifyListeners();
  }

  /// Sends the user to the OS location toggle.
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Tears down the duty timers/subscriptions. Readiness monitoring is left
  /// running on purpose — the Duty screen still needs it the moment someone
  /// goes off duty.
  void _stopTracking() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _graceTimer?.cancel();
    _graceTimer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _graceDeadline = null;
  }

  /// Timers can outlive the widget tree by a tick; notifying a disposed
  /// ChangeNotifier throws.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTracking();
    _readinessTimer?.cancel();
    _serviceSub?.cancel();
    _connectivitySub?.cancel();
    unawaited(_notifications.cancelAll());
    super.dispose();
  }
}
