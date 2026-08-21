// EMBER - Widget Test
// Basic smoke tests for EMBER app components
//
// NOTE: Because Supabase uses shared_preferences and real HTTP under the hood,
// we stub both before initializing so tests run fully offline.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ember/main.dart';

Future<void> setupSupabase() async {
  // Stub shared_preferences so Supabase's GoTrue storage works without a device
  SharedPreferences.setMockInitialValues({});

  await Supabase.initialize(
    url: 'https://placeholder.supabase.co',
    anonKey: 'mock-supabase-anon-key-for-widget-testing',
  );
}

void main() {
  setUpAll(() async {
    await setupSupabase();
  });

  group('EMBER App', () {
    testWidgets('App launches without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(const EmberApp());

      // Allow a frame to settle (auth stream, etc.)
      await tester.pump(const Duration(milliseconds: 300));

      // The root MaterialApp should always be present
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Shows Scaffold on startup (loading or login)',
        (WidgetTester tester) async {
      await tester.pumpWidget(const EmberApp());
      await tester.pump();

      // Either a loading indicator or the login/onboarding Scaffold must appear.
      // No red error screens should be visible.
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      expect(find.text('An error has occurred'), findsNothing);
    });
  });
}
