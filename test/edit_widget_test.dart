// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/appOptions.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await AppOptions().init();
  Logger.level = Level.info;

  testWidgets('edit test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
      await tester.pumpWidget(
          MaterialApp(
            title: 'Edit Screen',
            home: Edit(initialSong: Song.createEmptySong(),)),
          );

         // Verify that our counter starts at 0.
      var searchFinder = find.byKey(const ValueKey('title'));
      // print( 'searchFinder: ${searchFinder.description}');

     expect(searchFinder, findsOneWidget);


      // var testValue = 'love';
      // await tester.enterText(textField, testValue);
      // expect(find.text(testValue), findsOneWidget);
      // print(testValue);
    // expect(find.text('1'), findsNothing);
    //
    // // Tap the '+' icon and trigger a frame.
    // await tester.tap(find.byIcon(Icons.add));
    // await tester.pump();
    //
    // // Verify that our counter has incremented.
    // expect(find.text('0'), findsNothing);
    // expect(find.text('1'), findsOneWidget);

//  wait a while
//     await tester.pump(new Duration(milliseconds: 50));
  });
}
