// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui hide window;

import 'test_util.dart';

//  run test with 'additional args':  --dart-define=environment=test

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('Search for song test', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const ui.Size(
        16 * 1920, //  fixme: why is such a width needed?
        8 * 1080);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    for (var searchString in ['love', '25', 'the', 'asdf', '']) {
      await tester.enterText(find.byKey(const Key('searchText')), searchString);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      {
        final searchTextField = Find.findTextField('searchText');
        expect(searchTextField.controller!.text, searchString);
      }

      logger.d('"$searchString"');
      List<Widget> widgets = Find.findValueKeyContains('Song_', findSome: false);
      logger
          .d('     widgets.length: ${widgets.length}, type:  ${widgets.isEmpty ? 'none' : widgets[0].key.runtimeType}');
      if (widgets.isNotEmpty) {
        final regExp = RegExp(searchString, caseSensitive: false);
        for (var w in widgets) {
          logger.d('     ${(w.key as ValueKey<String>).value}');
          assert(regExp.hasMatch((w.key as ValueKey<String>).value));
        }
      }
    }

    {
      App _app = App();
      logger.i('allSongs.length: ${_app.allSongs.length}');
      assert(_app.allSongs.length > 1300);
      var allSongsSongIds = SplayTreeSet<String>();
      allSongsSongIds.addAll(_app.allSongs.map((song) {
        return song.songId.toString();
      }));
      logger.i('allSongsSongIds.length: ${allSongsSongIds.length}');

      var notHoliday = SplayTreeSet<String>();
      var holidayRexExp = RegExp(holidayMetadataNameValue.name, caseSensitive: false);
      notHoliday.addAll(allSongsSongIds.where((e) {
        return !holidayRexExp.hasMatch(e);
      }));
      logger.i('notHoliday.length: ${notHoliday.length}');

      //  find all
      await tester.enterText(find.byKey(const Key('searchText')), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      List<Widget> widgets = Find.findValueKeyContains('Song_');
      logger.d('widgets.length: ${widgets.length}');
      var widgetSongIds = SplayTreeSet<String>();
      widgetSongIds.addAll(widgets.map((w) => (w.key as ValueKey<String>).value));
      logger.i('widgetSongIds.length: ${widgetSongIds.length}');

      var missingNotHolidaySongIds = notHoliday.difference(widgetSongIds);
      logger.i('missing notHoliday diff widgetSongIds:  ${missingNotHolidaySongIds.length}');
      // for ( var id  in missingSongIds){
      //   logger.i('missing: $id');
      // }

      var missingWidgetSongIds = widgetSongIds.difference(notHoliday);
      expect(missingWidgetSongIds.length, 0);
      logger.i('missing widgetSongIds  diff notHoliday:  ${missingWidgetSongIds.length}');
      for (var id in missingWidgetSongIds) {
        logger.i('missingWidgetSongIds: $id');
      }

      //  assure tha the start of the elements found match the not holiday list
      for (var i = 0; i < widgetSongIds.length; i++) {
        expect(widgetSongIds.elementAt(i), notHoliday.elementAt(i));
      }
      logger.i('notHoliday.elementAt(${widgetSongIds.length - 1}):'
          '       ${notHoliday.elementAt(widgetSongIds.length - 1)}');
      logger.i('widgetSongIds.last:  ${widgetSongIds.last}');

      // for ( var id  in missingWidgetSongIds){
      //   logger.i('missingWidgetSongIds: $id');
      // }
    }
// var songsFinder = find.textContaining( RegExp('25'), skipOffstage: false);
//     expect(songsFinder, findsWidgets);
//     logger.i('songsFinder.evaluate().length: ${songsFinder.evaluate().length}');
//     logger.i('songsFinder.first: ${songsFinder.first}');
//     logger.i('songsFinder.last: ${songsFinder.last}');

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
