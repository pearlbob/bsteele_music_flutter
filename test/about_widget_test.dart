// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:bsteele_music_flutter/screens/about.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'test_util.dart';


void main() async {
  Logger.level = Level.debug;
  logger.d('main()');
  TestWidgetsFlutterBinding.ensureInitialized();

  PackageInfo.setMockInitialValues(
      appName: 'appName',
      packageName: 'packageName',
      version: 'version',
      buildNumber: 'buildNumber',
      buildSignature: 'buildSignature',
      installerStore: 'installerStore');
  packageInfo = await PackageInfo.fromPlatform();

  testWidgets('about test', (WidgetTester tester) async {
    //tester.binding.window.physicalSizeTestValue = const Size(2 * 1920, 2 * 1080); //  fixme: why so big?

    await tester.runAsync(() async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MaterialApp(
        title: 'About Screen',
        // home: Edit(initialSong: Song.createEmptySong(),)),
        home: About(),
      ));

      await tester.pumpAndSettle(const Duration(seconds: 1));

      //  find a utc date
      {
        var finder = RegexpTextFinder(r'.*utcDate: +20\d\d[01]\d\d\d_[0-2]\d[0-5]\d[0-5]\d$');
        expect(finder, findsOneWidget);
        logger.i((finder.first.evaluate().first.widget as Text).data);
      }

      //  find the screen size
      {
        var finder = RegexpTextFinder(r'screen: *\(\d+,\d+\)\s*$');
        expect(finder, findsOneWidget);
        logger.i((finder.first.evaluate().first.widget as Text).data);
      }
    });
  });
}
