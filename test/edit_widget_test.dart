// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
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

  testWidgets('edit test', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(
        4 * 1920, //  fixme: why is such a width needed?
        4 * 1080);

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
    var copyright = '2021 pearlbob';

    Text errorMessage; // = _Find.findText('errorMessage');
    // logger.i('errorMessage: "${errorMessage.data}"');
    // expect(errorMessage.data, contains('title'));

    var titleTextField = Find.findTextField('title');
    expect(titleTextField.controller!.text, isEmpty);
    titleTextField.controller!.text = testTitle;

    await tester.pump();
    errorMessage = Find.findValueKeyText('errorMessage');

    logger.i('title: "${titleTextField.controller!.text}"');
    logger.i('errorMessage: "${errorMessage.data}"');
    expect(errorMessage.data?.toLowerCase(), contains('artist'));

    var artistTextField = Find.findTextField('artist');
    expect(artistTextField.controller!.text, isEmpty);
    artistTextField.controller!.text = testArtist;

    await tester.pump();
    errorMessage = Find.findValueKeyText('errorMessage');

    logger.i('artist: "${artistTextField.controller!.text}"');

    var coverArtistTextField = Find.findTextField('coverArtist');
    expect(coverArtistTextField.controller!.text, isEmpty);
    coverArtistTextField.controller!.text = coverArtist;
    logger.i('coverArtist: "${coverArtistTextField.controller!.text}"');

    await tester.pump();
    errorMessage = Find.findValueKeyText('errorMessage');
    expect(errorMessage.data, contains('copyright'));

    var copyrightTextField = Find.findTextField('copyright');
    expect(copyrightTextField.controller!.text, isEmpty);
    copyrightTextField.controller!.text = copyright;
    logger.i('copyright: "${copyrightTextField.controller!.text}"');

    await tester.pump();
    errorMessage = Find.findValueKeyText('errorMessage');
    expect(errorMessage.data, contains('chords'));

    expect(titleTextField.controller!.text, testTitle);
    expect(artistTextField.controller!.text, testArtist);
    expect(coverArtistTextField.controller!.text, coverArtist);
    expect(copyrightTextField.controller!.text, copyright);

    errorMessage = Find.findValueKeyText('errorMessage');
    logger.i('errorMessage: "${errorMessage.data}"');
    expect(errorMessage.data, contains('chords'));

    DropdownButton<music_key.Key> keyDropdownButton = Find.findDropDown('editKeyDropdown');
    expect(keyDropdownButton.items, isNotEmpty);
    expect(keyDropdownButton.items!.length, MusicConstants.halfStepsPerOctave + 1);
    expect(keyDropdownButton.value, music_key.Key.getDefault());
    logger.i('keyDropdown: ${keyDropdownButton.items!.length}');
    logger.i('keyDropdown.value.runtimeType: ${keyDropdownButton.value.runtimeType}');

    {
      var keyDropdownFinder = DropDownFinder('editKeyDropdown');
      expect(keyDropdownFinder, findsOneWidget);
      for (var musicKey in music_key.Key.values) {
        logger.i('   musicKey: ${musicKey.halfStep} ${musicKey.toMarkup()}');

        await tester.tap(keyDropdownFinder.first, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        final keySelection = find.byKey(ValueKey('key_' + musicKey.toMarkup()));
        // expect(keySelection, findsOneWidget);  //  fixme: why 2?
        logger.d('keySelection: $keySelection');

        await tester.tap(keySelection.last, warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        errorMessage = Find.findValueKeyText('errorMessage');
        logger.d('errorMessage.data: ${errorMessage.data}');
        expect(errorMessage.data, contains('chords'));

        //  expect that the key has been selected
        expect(find.byKey(ValueKey('keyTally_' + musicKey.toMarkup()), skipOffstage: false), findsOneWidget);
      }
    }

    var newChordSection = find.byKey(const ValueKey('newChordSection'));
    expect(newChordSection, findsOneWidget);
    await tester.dragUntilVisible(
      newChordSection, // what you want to find
      find.byKey(const ValueKey('singleChildScrollView')), // widget you want to scroll
      const Offset(0, 200), // delta to move
    );
    // await tester.tap(newChordSection.last);
    //await tester.pumpAndSettle(const Duration(seconds: 1));   //  fixme:  A RenderFlex overflowed by 132 pixels on the right.

//  wait a while
//     await tester.pump(new Duration(milliseconds: 50));
  });
}
