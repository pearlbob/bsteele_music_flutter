// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui' as ui hide window;

import 'package:bsteele_music_flutter/main.dart';
import 'package:flutter_test/flutter_test.dart';

//  run test with 'additional args':  --dart-define=environment=test

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    tester.binding.window.physicalSizeTestValue = const ui.Size(
        16 * 1920, //  fixme: why is such a width needed?
        8 * 1080);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // // Verify that our counter starts at 0.
    // expect(find.text('0'), findsOneWidget);
    // expect(find.text('1'), findsNothing);
    //
    // // Tap the '+' icon and trigger a frame.
    // await tester.tap(find.byIcon(Icons.add));
    // await tester.pump();
    //
    // // Verify that our counter has incremented.
    // expect(find.text('0'), findsNothing);
    // expect(find.text('1'), findsOneWidget);
  });
}
