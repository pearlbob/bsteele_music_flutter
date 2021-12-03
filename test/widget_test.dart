// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:ui' as ui hide window;

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_util.dart';

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
    await tester.pumpWidget(BSteeleMusicApp());
    await tester.pumpAndSettle();

    List<Widget> widgets;

    {
      var finder = find.byKey(const ValueKey<String>('mainSong.Song_12_Bar_Blues_by_Any'));
      expect(finder, findsOneWidget);
    }

    var mainSearchText = find.byKey(appKey(AppKeyEnum.mainSearchText));
    expect(mainSearchText, findsOneWidget);

    {
      var searchString = 'this will not match any song';
      await tester.enterText(mainSearchText, searchString);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    widgets = Find.findValueKeyContains('Song_', findSome: false);
    expect(widgets, isEmpty);

    {
      var clearSearch = find.byKey(appKey(AppKeyEnum.mainClearSearch));
      expect(clearSearch, findsOneWidget);
      await tester.tap(clearSearch);
      await tester.pumpAndSettle();
    }

    widgets = Find.findValueKeyContains('Song_', findSome: false);
    expect(widgets, isNotEmpty);

    {
      var searchString = 'this will not match any song';
      await tester.enterText(mainSearchText, searchString);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      widgets = Find.findValueKeyContains('Song_', findSome: false);
      expect(widgets, isEmpty);
    }
    {
      var searchString = 'Chicago';
      await tester.enterText(mainSearchText, searchString);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      widgets = Find.findValueKeyContains('Song_', findSome: false);
      expect(widgets, isNotEmpty);
      var song25Or6To4ByChicago = find.byKey(const ValueKey<String>('mainSong.Song_25_or_6_to_4_by_Chicago'));
      expect(song25Or6To4ByChicago, findsOneWidget);
      // await tester.tap(song25Or6To4ByChicago);
      // await tester.pumpAndSettle(); //  fixme: error here.  why?  because it transitions to another screen
    }
    {
      var clearSearch = find.byKey(appKey(AppKeyEnum.mainClearSearch));
      expect(clearSearch, findsOneWidget);
      await tester.tap(clearSearch);
      await tester.pumpAndSettle();
    }
    {
      widgets = Find.findValueKeyContains('Song_', findSome: false);
      expect(widgets, isNotEmpty);
    }
    // var hamburger = find.byKey(const appKey(AppKeyEnum.mainHamburger));
    // expect(hamburger,findsOneWidget);
  });
}
