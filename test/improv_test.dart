// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/chord_component.dart';
import 'package:bsteele_music_lib/songs/key.dart';
import 'package:bsteele_music_lib/songs/mode.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() async {
  Logger.level = Level.info;

  test('improv test', () {
    logger.i('improv test:');

    for (MajorKey majorKey in MajorKey.values) {
      logger.i('');
      MinorKey minorKey = majorKey.minorKey;
      logger.i('majorKey: ${majorKey.toString().padRight(2)} / $minorKey');
      for (Mode mode in Mode.values) {
        logger.i('  mode: ${Util.firstToUpper(mode.name)}, ${mode.isMajor ? 'major' : 'minor'}'
            ', halfStep: ${mode.halfStep}');
        mode.chordComponents;
        for (ChordComponent component in mode.chordComponents) {
          final halfSteps = (mode.halfStep + component.halfSteps) % MusicConstants.halfStepsPerOctave;
          logger.i(
            '     ${majorKey.getKeyScaleNoteByHalfStep(halfSteps).toString().padLeft(2)}'
            ' ${component.toString().padLeft(2)}'
                // ', halfSteps: $halfSteps',
          );
        }
      }
    }
  });
}
