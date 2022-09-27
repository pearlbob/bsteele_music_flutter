// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:collection';
import 'dart:ui' as ui hide window;

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import 'test_util.dart';

//  run test with 'additional args':  --dart-define=environment=test

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Logger.level = Level.info;
  });

  testWidgets('Search for song test', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const ui.Size(
        16 * 1920, //  fixme: why is such a width needed?
        8 * 1080);

    // Build our app and trigger a frame.
    await tester.pumpWidget(const BSteeleMusicApp());
    await tester.pumpAndSettle();

    var mainSearchText = find.byKey(appKey(AppKeyEnum.playListSearch));
    expect(mainSearchText, findsOneWidget);

    for (var searchString in ['love', '25', 'the', 'asdf', '']) {
      await tester.enterText(mainSearchText, searchString);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      {
        final searchTextField = Find.findTextFieldByAppKey(AppKeyEnum.playListSearch);
        expect(searchTextField.controller!.text, searchString);
      }

      logger.d('"$searchString"');
      List<Widget> widgets = Find.findValueKeyContains('Song_', findSome: false);
      logger
          .d('     widgets.length: ${widgets.length}, type:  ${widgets.isEmpty ? 'none' : widgets[0].key.runtimeType}');
      // if (widgets.isNotEmpty) {  //  fixme
      //     final regExp = RegExp(searchString, caseSensitive: false);
      //     for (var w in widgets) {
      //       logger.d('     ${(w.key as ValueKey<String>).value}');
      //       assert(regExp.hasMatch((w.key as ValueKey<String>).value));
      //     }
      //   }
    }

    {
      logger.i('allSongs.length: ${app.allSongs.length}');
      assert(app.allSongs.length > 1500);
      var allSongsSongIds = SplayTreeSet<String>();
      allSongsSongIds.addAll(app.allSongs.map((song) {
        return song.songId.toString();
      }));
      logger.i('allSongsSongIds.length: ${allSongsSongIds.length}');

      //  find all
      await tester.enterText(mainSearchText, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      List<Widget> widgets = Find.findValueKeyContains('Song_');
      logger.d('widgets.length: ${widgets.length}');
      var widgetSongIds = SplayTreeSet<String>();
      widgetSongIds.addAll(widgets.map((w) => (w.key as ValueKey<String>).value));
      logger.i('widgetSongIds.length: ${widgetSongIds.length}');
    }

    testUtilShutdown(tester);
  });
}
