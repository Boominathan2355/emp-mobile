import 'package:flutter/material.dart';

import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  // Channels have to exist before anything can post to them. The runtime
  // *permission* is asked for later, at check-in, where the reason for it is
  // obvious; a failure here (unsupported platform) must not block the app.
  try {
    await NotificationService.instance.init();
  } catch (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'emp_mobile',
      context: ErrorDescription('initialising notifications'),
    ));
  }

  runApp(const EmpApp());
}
