// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/key.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'test_util.dart';

// class _GlobalObjectKeyFinder extends MatchFinder {
//   _GlobalObjectKeyFinder(this._valueKeyString);
//
//   @override
//   String get description => '_GlobalObjectKeyFinder: $_valueKeyString';
//
//   @override
//   bool matches(Element candidate) {
//     return (candidate.widget.key is GlobalObjectKey &&
//         (candidate.widget.key as GlobalObjectKey).value == _valueKeyString);
//   }
//
//   final String _valueKeyString;
// }

// Widget appOptionsChangeNotifierProvider(BuildContext context, Widget? child) {
//   return ChangeNotifierProvider<AppOptions>(
//       create: (_) => AppOptions(),
//       builder: (BuildContext context, Widget? child) {
//         return child ?? const Text('no child');
//       });
// }

void main() async {
  Logger.level = Level.info;

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit widget test', (WidgetTester tester) async {
    //tester.binding.window.physicalSizeTestValue = const Size(4 * 1920, 4 * 1080);

    await tester.pumpWidget(
      MaterialApp(
          title: 'Edit Screen',
          home: ChangeNotifierProvider<AppOptions>(
              create: (_) => AppOptions(),
              builder: (BuildContext context, Widget? child) {
                return Edit(
                  initialSong: Song.createEmptySong(),
                );
              })),
    );

    await tester.pumpAndSettle(const Duration(seconds: 1));

    var testTitle = '000 test edit widget song';
    var testArtist = 'original bob';
    var coverArtist = 'bob again';
    var copyright = '2021 pearl bob';

    var errorMessage = Find.findTextByAppKey(AppKeyEnum.editErrorMessage);
    logger.i('errorMessage: "${errorMessage.data}"');
    expect(errorMessage.data, contains('title'));

    var titleTextField = Find.findTextFieldByAppKey(AppKeyEnum.editTitle);
    expect(titleTextField.controller!.text, isEmpty);
    titleTextField.controller!.text = testTitle;

    await tester.pump();
    errorMessage = Find.findTextByAppKey(AppKeyEnum.editErrorMessage);

    logger.i('title: "${titleTextField.controller!.text}"');
    logger.i('errorMessage: "${errorMessage.data}"');
    expect(errorMessage.data?.toLowerCase(), contains('artist'));

    var artistTextField = Find.findTextFieldByAppKey(AppKeyEnum.editArtist);
    expect(artistTextField.controller!.text, isEmpty);
    artistTextField.controller!.text = testArtist;

    await tester.pump();
    errorMessage = Find.findTextByAppKey(AppKeyEnum.editErrorMessage);

    logger.i('artist: "${artistTextField.controller!.text}"');

    var coverArtistTextField = Find.findTextFieldByAppKey(AppKeyEnum.editCoverArtist);
    expect(coverArtistTextField.controller!.text, isEmpty);
    coverArtistTextField.controller!.text = coverArtist;
    logger.i('coverArtist: "${coverArtistTextField.controller!.text}"');

    await tester.pump();
    errorMessage = Find.findTextByAppKey(AppKeyEnum.editErrorMessage);
    expect(errorMessage.data, contains('copyright'));

    var copyrightTextField = Find.findTextFieldByAppKey(AppKeyEnum.editReleaseAndLabel);
    expect(copyrightTextField.controller!.text, isEmpty);
    copyrightTextField.controller!.text = copyright;
    logger.i('copyright: "${copyrightTextField.controller!.text}"');

    await tester.pump();
    errorMessage = Find.findTextByAppKey(AppKeyEnum.editErrorMessage);
    expect(errorMessage.data, contains('chords'));

    expect(titleTextField.controller!.text, testTitle);
    expect(artistTextField.controller!.text, testArtist);
    expect(coverArtistTextField.controller!.text, coverArtist);
    expect(copyrightTextField.controller!.text, copyright);

    errorMessage = Find.findTextByAppKey(AppKeyEnum.editErrorMessage);
    logger.i('errorMessage: "${errorMessage.data}"');
    expect(errorMessage.data, contains('chords'));

    DropdownButton<music_key.Key> keyDropdownButton = Find.findDropDownByAppKey(AppKeyEnum.editEditKeyDropdown);
    expect(keyDropdownButton.items, isNotEmpty);
    expect(keyDropdownButton.items!.length, MusicConstants.halfStepsPerOctave + 1);
    expect(keyDropdownButton.value, music_key.Key.getDefault());
    logger.v('keyDropdownButton.value: ${keyDropdownButton.value}');

    {
      var keyDropdownFinder = DropDownFinderByAppKey(AppKeyEnum.editEditKeyDropdown);
      expect(keyDropdownFinder, findsOneWidget);

      for (var musicKey in music_key.Key.values) {
        switch (musicKey.keyEnum) {
          case KeyEnum.Gb:
          case KeyEnum.Db:
          case KeyEnum.Ab:
            continue;
          default:
            break;
        }

        logger.i('   musicKey: ${musicKey.halfStep} ${musicKey.toMarkup()}');

        await tester.tap(keyDropdownFinder.first, warnIfMissed: false);
        await tester.pump();
        await tester.pumpAndSettle();

        // debugDumpApp();
        //
        // for (final element in find.bySubtype<DropdownMenuItem>().evaluate()) {
        //   logger.i('element: $element');
        // }

        var key = appKeyCreate(AppKeyEnum.editMusicKey, value: musicKey);

        final keySelection = find.byKey(key);

        //  two are generated by the stack overlay: expect(keySelection, findsOneWidget);
        await tester.tap(
            keySelection.last //  apparently the second one works
            ,
            warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        keyDropdownButton = Find.findDropDownByAppKey(AppKeyEnum.editEditKeyDropdown);
        logger.v('keyDropdownButton.value: ${keyDropdownButton.value}');

        errorMessage = Find.findTextByAppKey(AppKeyEnum.editErrorMessage);
        logger.d('errorMessage.data: ${errorMessage.data}');
        expect(errorMessage.data, contains('chords'));

        {
          var finder = RegexpTextFinder(r'^keyTally_');
          expect(finder, findsOneWidget);
          logger.v((finder.first.evaluate().first.widget as Text).data);
          expect((finder.first.evaluate().first.widget as Text).data, 'keyTally_${musicKey.toMarkup()}');
        }
      }
    }

//  wait a while
//     await tester.pump(new Duration(milliseconds: 50));
  });
}
