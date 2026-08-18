import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// System notifications for the duty lifecycle.
///
/// Two channels with deliberately different weights:
///  * [_trackingChannel] — silent and ongoing. It is the "we are recording your
///    location" disclosure that has to stay visible for the whole shift, so it
///    must never buzz.
///  * [_alertChannel] — max importance with sound/vibration. Only the location
///    warning and the auto check-out land here, because both need to reach the
///    user while the app is backgrounded.
///
/// Note the tracking notification is posted twice over: geolocator raises its
/// own foreground-service notification for the position stream (that is what
/// actually keeps the process alive), and [showTrackingOn] posts the same
/// message on Android <8 style channels for platforms/paths where the service
/// notification isn't shown — see [suppressOngoingOnAndroid].
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const AndroidNotificationChannel _trackingChannel =
      AndroidNotificationChannel(
    'duty_tracking',
    'Duty tracking',
    description:
        'Ongoing notice shown while your location is shared with your organization.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  static const AndroidNotificationChannel _alertChannel =
      AndroidNotificationChannel(
    'duty_alerts',
    'Duty alerts',
    description:
        'Warnings that need your attention, such as location being turned off while on duty.',
    importance: Importance.max,
  );

  static const int trackingId = 1001;
  static const int locationWarningId = 1002;
  static const int autoCheckOutId = 1003;

  /// Android already shows geolocator's foreground-service notification with
  /// the same wording, so posting our own on top would duplicate it.
  static bool get suppressOngoingOnAndroid => Platform.isAndroid;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Safe to call more than once; only the first call does work.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly in [requestPermission] instead, so the prompt
          // lands when the user checks in rather than on a cold start.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_trackingChannel);
    await android?.createNotificationChannel(_alertChannel);
  }

  /// Requests POST_NOTIFICATIONS (Android 13+) / alert permission (iOS).
  ///
  /// Returns false when the user declined. Duty still works without it — the
  /// in-app banner carries the same warning — so callers treat this as a
  /// degraded mode, never a blocker.
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  /// The always-on disclosure for an active shift.
  Future<void> showTrackingOn() async {
    if (suppressOngoingOnAndroid) return;
    await _show(
      id: trackingId,
      title: 'Location tracking is on',
      body: 'Your location is being shared with your organization while you are on duty.',
      channel: _trackingChannel,
      ongoing: true,
      autoCancel: false,
    );
  }

  Future<void> cancelTrackingOn() => _cancel(trackingId);

  /// The location-off warning, re-posted each second with a fresh countdown.
  ///
  /// `onlyAlertOnce` keeps the per-second refresh from re-buzzing — the first
  /// post alerts, the rest silently update the same notification in place.
  Future<void> showLocationOffWarning(Duration remaining) async {
    await _show(
      id: locationWarningId,
      title: 'Turn location back on',
      body: 'Location is off. Turn it on within ${formatCountdown(remaining)} '
          'or you will be taken off duty automatically.',
      channel: _alertChannel,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
    );
  }

  Future<void> cancelLocationOffWarning() => _cancel(locationWarningId);

  Future<void> showAutoCheckedOut(Duration grace) async {
    await _show(
      id: autoCheckOutId,
      title: 'You were taken off duty',
      body: 'Location stayed off for more than ${formatMinutes(grace)}, '
          'so your duty was ended automatically.',
      channel: _alertChannel,
    );
  }

  /// Clears everything this service posts. Called on check-out and sign-out so
  /// no stale "tracking is on" notice outlives the shift.
  Future<void> cancelAll() async {
    await cancelTrackingOn();
    await cancelLocationOffWarning();
    await _cancel(autoCheckOutId);
  }

  /// "1:59" / "0:07" — the countdown rendering shared by the notification and
  /// the in-app banner so the two never disagree.
  static String formatCountdown(Duration remaining) {
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final minutes = clamped.inMinutes;
    final seconds = clamped.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatMinutes(Duration d) =>
      d.inMinutes == 1 ? '1 minute' : '${d.inMinutes} minutes';

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
    bool ongoing = false,
    bool autoCancel = true,
    bool onlyAlertOnce = false,
  }) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel.importance == Importance.max
              ? Priority.max
              : Priority.low,
          ongoing: ongoing,
          autoCancel: autoCancel,
          onlyAlertOnce: onlyAlertOnce,
          playSound: channel.playSound,
          enableVibration: channel.enableVibration,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: channel.importance == Importance.max,
        ),
      ),
    );
  }

  Future<void> _cancel(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id: id);
  }
}
