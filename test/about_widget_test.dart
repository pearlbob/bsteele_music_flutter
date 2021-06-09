// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/screens/about.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _RegexpTextFinder extends MatchFinder {
  _RegexpTextFinder(String regexpString) : _regExp = RegExp(regexpString);

  @override
  String get description => '_RegexpTextFinder: ${_regExp.pattern}';

  @override
  bool matches(Element candidate) {
    if (candidate.widget is Text) {
      var text = (candidate.widget as Text).data ?? '';
      RegExpMatch? m = _regExp.firstMatch(text);
      if (  m != null){
        logger.d(' matching: <$text>');
        return true;
      }
    }
    return false;
  }

  final RegExp _regExp;
}

void main() async {
  Logger.level = Level.info;
  logger.d('main()');
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('about test', (WidgetTester tester) async {
   // tester.binding.window.physicalSizeTestValue = const Size(1920, 1080);

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(
      title: 'Edit Screen',
      // home: Edit(initialSong: Song.createEmptySong(),)),
      home: About(),
    ));

    await tester.pump();

    expect(_RegexpTextFinder(r'.*utcDate: +20\d\d[01]\d\d\d_[0-2]\d[0-5]\d[0-5]\d\n$'), findsOneWidget);
  });
}
