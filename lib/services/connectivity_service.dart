import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device has a usable network interface.
///
/// This is an *interface* check, not a reachability check: connected Wi-Fi with
/// a dead uplink still reads as online. That is the right trade-off for the
/// pre-check-in gate, which exists to catch the common case of mobile data or
/// Wi-Fi being switched off — it answers instantly and costs no traffic. The
/// real reachability test stays where it already was: the `/api/tracking/ingest`
/// call during check-in, which fails the shift if the network is truly dead.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Emits on every interface change (data toggled, Wi-Fi dropped, …).
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  /// Fails open: if the platform channel misbehaves we would rather let someone
  /// try to check in and see a real error than block them on a false negative.
  Future<bool> isOnline() async {
    try {
      return _isOnline(await _connectivity.checkConnectivity());
    } catch (_) {
      return true;
    }
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.isEmpty || results.any((r) => r != ConnectivityResult.none);
}
