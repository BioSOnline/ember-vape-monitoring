import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ember/core/theme/theme_provider.dart';
import 'package:ember/screens/relief_screen.dart';

void main() {
  Widget createReliefScreen() {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MaterialApp(
        home: ReliefScreen(),
      ),
    );
  }

  group('Craving Relief Flow Tests', () {
    testWidgets('Renders all primary sections and header banner', (WidgetTester tester) async {
      await tester.pumpWidget(createReliefScreen());
      await tester.pumpAndSettle();

      expect(find.text('Craving Relief'), findsOneWidget);
      expect(find.text('Feeling a craving?'), findsOneWidget);
      expect(find.text('Quick Relief Tools'), findsOneWidget);
      expect(find.text('4-4-6 Box Breathing'), findsOneWidget);
      expect(find.text('Urge Delay Challenge'), findsOneWidget);
      expect(find.text('Coping Strategies'), findsOneWidget);
      expect(find.text('0/6 Completed'), findsOneWidget);
    });

    testWidgets('Box breathing exercise starts and displays active phases', (WidgetTester tester) async {
      await tester.pumpWidget(createReliefScreen());
      await tester.pumpAndSettle();

      // Tap Begin Box Breathing button
      final beginBtn = find.text('Begin Box Breathing');
      expect(beginBtn, findsOneWidget);
      await tester.tap(beginBtn);
      await tester.pump();

      // Verify active state
      expect(find.text('Breathe In'), findsOneWidget);
      expect(find.text('Cycle 1/4'), findsOneWidget);
      expect(find.text('End Exercise'), findsOneWidget);

      // Advance clock by 4 seconds (Breathe In -> Hold Breath)
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Hold Breath'), findsOneWidget);

      // Advance clock by 4 seconds (Hold -> Breathe Out)
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Breathe Out Slowly'), findsOneWidget);

      // Tap End Exercise
      await tester.tap(find.text('End Exercise'));
      await tester.pump();

      // Verify returned to start state
      expect(find.text('Begin Box Breathing'), findsOneWidget);
    });

    testWidgets('Delay timer preset options and countdown lifecycle', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createReliefScreen());
      await tester.pumpAndSettle();

      // Check preset choices
      expect(find.text('3 Minutes'), findsOneWidget);
      expect(find.text('5 Minutes'), findsOneWidget);
      expect(find.text('10 Minutes'), findsOneWidget);

      // Select 3 Minutes preset
      await tester.tap(find.text('3 Minutes'));
      await tester.pumpAndSettle();

      expect(find.text('Start 3-Minute Challenge'), findsOneWidget);

      // Start the timer
      await tester.tap(find.text('Start 3-Minute Challenge'));
      await tester.pump();

      // Initial formatted time 03:00
      expect(find.text('03:00'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Advance 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('02:59'), findsOneWidget);

      // Pause timer
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);

      // Advance time while paused: should NOT decrease
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('02:59'), findsOneWidget);

      // Reset timer
      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(find.text('Start 3-Minute Challenge'), findsOneWidget);
    });

    testWidgets('Interactive coping strategies toggle and update counter', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createReliefScreen());
      await tester.pumpAndSettle();

      expect(find.text('0/6 Completed'), findsOneWidget);

      // Tap "Drink a Cold Glass of Water"
      final waterStrategy = find.text('Drink a Cold Glass of Water');
      expect(waterStrategy, findsOneWidget);
      await tester.tap(waterStrategy);
      await tester.pump();

      // Counter increments to 1/6
      expect(find.text('1/6 Completed'), findsOneWidget);

      // Tap "Take a 5-Minute Walk"
      final walkStrategy = find.text('Take a 5-Minute Walk');
      await tester.tap(walkStrategy);
      await tester.pump();

      // Counter increments to 2/6
      expect(find.text('2/6 Completed'), findsOneWidget);

      // Tap "Drink a Cold Glass of Water" again to uncheck
      await tester.tap(waterStrategy);
      await tester.pump();

      // Counter drops back to 1/6
      expect(find.text('1/6 Completed'), findsOneWidget);
    });
  });
}
