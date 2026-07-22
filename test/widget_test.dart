import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emp_mobile/app.dart';

void main() {
  testWidgets('boots to a loading gate then the login screen', (tester) async {
    await tester.pumpWidget(const EmpApp());

    // The auth gate shows a spinner while it bootstraps the stored session.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Let bootstrap settle; with no stored token it lands on the login screen.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sign in to start your duty'), findsOneWidget);
  });
}
