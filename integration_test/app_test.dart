// This is a basic Flutter integration test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/main.dart' as bsteele_music_app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

List<String> _testCommands = [
  "AppKeyEnum.mainSearchText.2",
  "String.Song_12_Bar_Blues_by_All",
  "AppKeyEnum.playerEdit",
  "ChordSectionLocation.V:0:1",
  "AppKeyEnum.editMajorChord",
  "AppKeyEnum.editAcceptChordModificationAndFinish",
  "AppKeyEnum.editUndo",
  "AppKeyEnum.editRedo",
  "AppKeyEnum.editScreenDetail",
  "AppKeyEnum.appBack",
  "AppKeyEnum.appBack",
  "AppKeyEnum.appBack",
  "AppKeyEnum.mainHamburger",
  "AppKeyEnum.mainDrawerOptions",
  "AppKeyEnum.appBack",
  "AppKeyEnum.mainSearchText.love",
  "AppKeyEnum.mainHamburger",
  "AppKeyEnum.mainDrawerAbout",
  "AppKeyEnum.aboutWriteDiagnosticLogFile",
  "AppKeyEnum.appBack",
  "AppKeyEnum.mainHamburger",
  "AppKeyEnum.mainDrawerOptions",
  "AppKeyEnum.appBack",
  "AppKeyEnum.mainHamburger",
  "AppKeyEnum.mainDrawerSongs",
  "AppKeyEnum.appBack",
  "AppKeyEnum.mainHamburger",
  "AppKeyEnum.mainDrawerCssDemo",
  "AppKeyEnum.appBack",
  "AppKeyEnum.mainSearchText.blues",
  "String.Song_12_Bar_Blues_by_All",
  "AppKeyEnum.playerCapo",
  "AppKeyEnum.appBack",
  "AppKeyEnum.mainSearchText.2",
  "String.Song_25_or_6_to_4_by_Chicago",
  "AppKeyEnum.playerBack",
  "AppKeyEnum.mainHamburger",
  "AppKeyEnum.mainDrawerAbout",
];

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('app test', (WidgetTester tester) async {
      // Build our app
      bsteele_music_app.main();

      // Trigger a frame.
      await tester.pumpAndSettle();

      //  parse and run the test commands
      for (var cmd in _testCommands) {
        logger.i('cmd: $cmd');
        var parts = cmd.split('.');
        var type = parts[0];
        late Finder finder;
        String? text;
        switch (type) {
          case 'AppKeyEnum':
            late AppKeyEnum appKeyEnum;
            try {
              appKeyEnum = AppKeyEnum.values.byName(parts[1]);
            } catch (e) {
              logger.i('not found: $cmd');
              assert(false);
            }

            logger.i('$appKeyEnum');

            finder = find.byKey(ValueKey<AppKeyEnum>(appKeyEnum));

            if (parts.length > 2) {
              //  app key with text values
              text = parts[2];
            }
            break;
          case 'String':
            finder = find.byKey(ValueKey<String>(parts[1]));
            break;
          case 'ChordSectionLocation':
            finder = find.byKey(ValueKey<ChordSectionLocation>(ChordSectionLocation.parseString(parts[1])));
            break;

          default:
            logger.i('Unknown command: $cmd');
            assert(false);
            break;
        }

        expect(finder, findsOneWidget);

        if (text != null) {
          //  input text values
          logger.i('part with text: \'$text\'');
          await tester.enterText(finder, text);
        } else {
          await tester.tap(finder);
        }

        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
      }

      await Future.delayed(const Duration(seconds: 7));
    });
  });
}
