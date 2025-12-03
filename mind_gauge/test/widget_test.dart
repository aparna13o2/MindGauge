import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mind_gauge/main.dart'; // Ensure this import path is correct

void main() {
  testWidgets('Renders MINDGAUGE title on the Splash Screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // NOTE: We are replacing 'MyApp()' with the actual app name: 'MindGaugeApp()'
    await tester.pumpWidget(const MindGaugeApp());

    // Wait for the simulated splash screen delay to pass, which should land us on the AuthScreen
    await tester.pumpAndSettle();

    // Verify that the title text is present on the Auth Screen
    expect(find.text('MINDGAUGE'), findsOneWidget);
    expect(find.text('Measure your Mental Health Status'), findsOneWidget);

    // Verify that the REGISTER button is present on the Auth Screen
    expect(find.text('REGISTER'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
  });
}
