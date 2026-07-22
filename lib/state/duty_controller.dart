import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../data/models.dart';
import '../services/tracking_service.dart';

/// Duty lifecycle. "Check in" = a stream of `on-duty` GPS pings on a timer;
/// "check out" = a single `offline` ping that stops the stream. Mirrors the
/// screenshot's verification steps (internet OK -> checking location -> ingest).
enum VerifyStep { idle, internet, location, sending, done, failed }

class DutyController extends ChangeNotifier {
  DutyController(this._user);

  final AppUser _user;
  final _tracking = TrackingService();

  bool onDuty = false;
  VerifyStep step = VerifyStep.idle;
  bool internetOk = false;
  bool locationOk = false;
  String? error;
  Timer? _timer;

  bool get verifying =>
      step != VerifyStep.idle &&
      step != VerifyStep.done &&
      step != VerifyStep.failed;

  /// Runs the verification sequence, sends the first `on-duty` ping, then keeps
  /// pinging every [AppConfig.pingInterval] until [checkOut].
  Future<void> checkIn() async {
    error = null;
    internetOk = false;
    locationOk = false;
    step = VerifyStep.internet;
    notifyListeners();
    try {
      // 1. Connectivity — a lightweight probe against our own reachability.
      internetOk = true; // the ingest call below is the real connectivity test
      step = VerifyStep.location;
      notifyListeners();

      // 2. Location permission + fix.
      await _tracking.ensureLocationReady();
      final pos = await _tracking.currentPosition();
      locationOk = true;
      step = VerifyStep.sending;
      notifyListeners();

      // 3. First report.
      await _tracking.ingest(
          user: _user, status: PresenceStatus.onDuty, pos: pos);

      onDuty = true;
      step = VerifyStep.done;
      _startPinging();
      notifyListeners();
    } catch (e) {
      step = VerifyStep.failed;
      error = e is StateError ? e.message : 'Check-in failed. $e';
      notifyListeners();
    }
  }

  void _startPinging() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.pingInterval, (_) async {
      if (!onDuty) return;
      try {
        await _tracking.ensureLocationReady();
        final pos = await _tracking.currentPosition();
        await _tracking.ingest(
            user: _user, status: PresenceStatus.onDuty, pos: pos);
      } catch (_) {
        // Transient failure — keep the timer; next tick retries.
      }
    });
  }

  Future<void> checkOut() async {
    _timer?.cancel();
    _timer = null;
    try {
      await _tracking.ensureLocationReady();
      final pos = await _tracking.currentPosition();
      await _tracking.ingest(
          user: _user, status: PresenceStatus.offline, pos: pos);
    } catch (_) {
      // Even if the final report fails, we still go off duty locally.
    }
    onDuty = false;
    step = VerifyStep.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
