// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/appOptions.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class _TextFieldFinder extends MatchFinder {
  _TextFieldFinder(this._valueKeyString);

  @override
  String get description => '_TextFieldFinder: $_valueKeyString';

  @override
  bool matches(Element candidate) {
    return (candidate.widget is TextField &&
        candidate.widget.key is ValueKey &&
        (candidate.widget.key as ValueKey).value == _valueKeyString);
  }

  final String _valueKeyString;
}

class _TextFinder extends MatchFinder {
  _TextFinder(this._valueKeyString);

  @override
  String get description => '_TextFinder: $_valueKeyString';

  @override
  bool matches(Element candidate) {
    return (candidate.widget is Text &&
        candidate.widget.key is ValueKey &&
        (candidate.widget.key as ValueKey).value == _valueKeyString);
  }

  final String _valueKeyString;
}

class _DropDownFinder extends MatchFinder {
  _DropDownFinder(this._valueKeyString);

  @override
  String get description => '_DropDownFinder: $_valueKeyString';

  @override
  bool matches(Element candidate) {
    return (candidate.widget is DropdownButton &&
        candidate.widget.key is ValueKey &&
        (candidate.widget.key as ValueKey).value == _valueKeyString);
  }

  final String _valueKeyString;
}

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

class _Find {
  static TextField findTextField(String valueKeyString) {
    var _textFieldFinder = _TextFieldFinder(valueKeyString);
    expect(_textFieldFinder, findsOneWidget);
    var ret = _textFieldFinder.evaluate().first.widget as TextField;
    expect(ret.controller, isNotNull);
    return ret;
  }

  static Text findText(String valueKeyString) {
    var _textFinder = _TextFinder(valueKeyString);
    expect(_textFinder, findsOneWidget);
    var ret = _textFinder.evaluate().first.widget as Text;
    return ret;
  }

  static DropdownButton<music_key.Key> findDropDown(String valueKeyString) {
    var _textFinder = _DropDownFinder(valueKeyString);
    expect(_textFinder, findsOneWidget);
    var ret = _textFinder.evaluate().first.widget as DropdownButton<music_key.Key>;
    return ret;
  }

// static Widget findGlobalObjectKeyWidget(String valueKeyString) {
//   var _textFinder = _GlobalObjectKeyFinder(valueKeyString);
//   expect(_textFinder, findsOneWidget);
//   return _textFinder.evaluate().first.widget;
// }
}

void main() async {
  Logger.level = Level.info;

  TestWidgetsFlutterBinding.ensureInitialized();
  await AppOptions().init();

  testWidgets('edit test', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(
        2 * 1920, //  fixme: why is such a width needed?
        2 * 1080);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(
      title: 'Edit Screen',
      home: Edit(
        initialSong: Song.createEmptySong(),
      ),
    ));

    await tester.pump();

    var testTitle = '000 test edit widget song';
    var testArtist = 'original bob';
    var coverArtist = 'bob again';
    var copyright = '2021 pearlbob';

    var errorMessage = _Find.findText('errorMessage');
    logger.i('errorMessage: "${errorMessage.data}"');
    expect(errorMessage.data, contains('title'));

    var titleTextField = _Find.findTextField('title');
    expect(titleTextField.controller!.text, isEmpty);
    titleTextField.controller!.text = testTitle;

    await tester.pump();
    errorMessage = _Find.findText('errorMessage');

    logger.i('title: "${titleTextField.controller!.text}"');
    logger.i('errorMessage: "${errorMessage.data}"');
    expect(errorMessage.data, contains('artist'));

    var artistTextField = _Find.findTextField('artist');
    expect(artistTextField.controller!.text, isEmpty);
    artistTextField.controller!.text = testArtist;

    await tester.pump();
    errorMessage = _Find.findText('errorMessage');

    logger.i('artist: "${artistTextField.controller!.text}"');

    var coverArtistTextField = _Find.findTextField('coverArtist');
    expect(coverArtistTextField.controller!.text, isEmpty);
    coverArtistTextField.controller!.text = coverArtist;
    logger.i('coverArtist: "${coverArtistTextField.controller!.text}"');

    await tester.pump();
    errorMessage = _Find.findText('errorMessage');
    expect(errorMessage.data, contains('copyright'));

    var copyrightTextField = _Find.findTextField('copyright');
    expect(copyrightTextField.controller!.text, isEmpty);
    copyrightTextField.controller!.text = copyright;
    logger.i('copyright: "${copyrightTextField.controller!.text}"');

    await tester.pump();
    errorMessage = _Find.findText('errorMessage');
    expect(errorMessage.data, contains('chords'));

    expect(titleTextField.controller!.text, testTitle);
    expect(artistTextField.controller!.text, testArtist);
    expect(coverArtistTextField.controller!.text, coverArtist);
    expect(copyrightTextField.controller!.text, copyright);

    errorMessage = _Find.findText('errorMessage');
    logger.i('errorMessage: "${errorMessage.data}"');
    expect(errorMessage.data, contains('chords'));

    DropdownButton<music_key.Key> keyDropdownButton = _Find.findDropDown('editKeyDropdown');
    expect(keyDropdownButton.items, isNotEmpty);
    expect(keyDropdownButton.items!.length, 12 + 1);
    expect(keyDropdownButton.value, music_key.Key.getDefault());
    logger.i('keyDropdown: ${keyDropdownButton.items!.length}');
    logger.i('keyDropdown.value.runtimeType: ${keyDropdownButton.value.runtimeType}');

    {
      //  work around some type issues
      var itemsToString = keyDropdownButton.items!.map((item) => item.value.toString());

      // var keyDropdownFinder = _DropDownFinder('keyDropdown');
      for (var musicKey in music_key.Key.values) {
        logger.i('   musicKey: ${musicKey.halfStep} ${musicKey.toMarkup()}');

        // await tester.tap(keyDropdownFinder, warnIfMissed: false);
        // await tester.pump();
        // // await tester.pump(const Duration(seconds: 1));
        // await tester.pumpAndSettle( );
        // // await tester.pumpAndSettle(
        // //     const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));

        final keySelection = find.byKey(ValueKey('key_' + musicKey.toMarkup()));
        //fixme:      expect(keySelection, findsOneWidget);
        logger.i('   keySelection: ${keySelection.first}');

        await tester.tap(keySelection.first, warnIfMissed: false);
        await tester.pump();
        await tester.pumpAndSettle();
        // await tester.pump(const Duration(seconds: 1));

        // await tester.pumpAndSettle(
        //     const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));
        errorMessage = _Find.findText('errorMessage');
        logger.i('errorMessage.data: ${errorMessage.data}');
        expect(errorMessage.data, contains('chords'));

        //    keyDropdownButton = _Find.findDropDown('keyDropdown');

        logger.i('keyDropdownButton.value: ${keyDropdownButton.value}');

        var containsKey = itemsToString.contains(musicKey.toString());
        expect(containsKey, isTrue);
      }
    }

//  wait a while
//     await tester.pump(new Duration(milliseconds: 50));
  });
}
