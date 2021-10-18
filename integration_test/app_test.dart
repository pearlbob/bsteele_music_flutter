// This is a basic Flutter integration test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/main.dart' as bsteele_music_app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

List<String> _testCommands = [
  "mainSearchText.2",
  "mainSong.Song_12_Bar_Blues_by_All",
  "playerEdit",
  "editChordSectionLocation.V:0:1",
  "editDominant7Chord",
  "editAcceptChordModificationAndFinish",
  // "editScaleNote.G",
  // "editScaleChord.C5",
  // "editMajorChord",
  // "appBack",
  // "appBack",

  // "mainSong.Song_25_or_6_to_4_by_Chicago",
  // "playerEdit",
  // "editChordSectionLocation.I:0:1",
  // "editMajorChord",
  // "editAcceptChordModificationAndFinish",
  // "editAcceptChordModificationAndFinish",
  // "editUndo",
  // "editRedo",
  // "editScreenDetail",
  // "appBack",
  // "appBack",
  // "appBack",
  // "mainHamburger",
  // "mainDrawerOptions",
  // "appBack",
  // "mainSearchText.love",
  // "mainHamburger",
  // "mainDrawerAbout",
  // "aboutWriteDiagnosticLogFile",
  // "appBack",
  // "mainHamburger",
  // "mainDrawerOptions",
  // "appBack",
  // "mainHamburger",
  // "mainDrawerSongs",
  // "appBack",
  // "mainHamburger",
  // "mainDrawerCssDemo",
  // "appBack",
  // "mainSearchText.blues",
  // "String.Song_12_Bar_Blues_by_All",
  // "playerCapo",
  // "appBack",
  // "mainSearchText.2",
  // "String.Song_25_or_6_to_4_by_Chicago",
  // "playerBack",
  // "mainHamburger",
  // "mainDrawerAbout",
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
        assert(parts.isNotEmpty);
        AppKeyEnum? appKeyEnum = Util.enumFromString<AppKeyEnum>(parts[0], AppKeyEnum.values);
        if (appKeyEnum == null) {
          assert(false);
        }
        var type = appKeyEnumTypeMap[appKeyEnum];
        late Finder finder;
        String? text;
        switch (type) {
          case null:
            finder = find.byKey(ValueKey<String>(appKeyEnum!.name), skipOffstage: false);
            break;
          case ScaleChord:
            try {
              var scaleChord = ScaleChord.parseString(parts[1]);
              finder = find.byKey(appKey(appKeyEnum!, value: scaleChord!), skipOffstage: false);
            } catch (d) {
              assert(false);
            }
            break;
          case ScaleNote:
            try {
              var scaleNote = ScaleNote.parseString(parts[1]);
              finder = find.byKey(appKey(appKeyEnum!, value: scaleNote!), skipOffstage: false);
            } catch (d) {
              assert(false);
            }
            break;
          case ChordSectionLocation:
            {
              var chordSectionLocation = ChordSectionLocation.fromString(parts[1]);
              if (chordSectionLocation == null) {
                assert(false);
              }
              finder = find.byKey(appKey(appKeyEnum!, value: chordSectionLocation!));
            }
            break;
          case String:
            assert(parts.length == 2);
            text = parts[1];
            finder = find.byKey(appKey(appKeyEnum!), skipOffstage: false);
            break;
          case Id:
            assert(parts.length >= 2);
            finder = find.byKey(appKey(appKeyEnum!, value: Id(parts[1])), skipOffstage: false);
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
