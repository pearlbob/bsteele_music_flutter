// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteele_music_flutter/screens/improv.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/chord.dart';
import 'package:bsteele_music_lib/songs/chord_component.dart';
import 'package:bsteele_music_lib/songs/key.dart';
import 'package:bsteele_music_lib/songs/measure.dart';
import 'package:bsteele_music_lib/songs/mode.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/phrase.dart';
import 'package:bsteele_music_lib/songs/pitch.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
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
        logger.i(
          '  mode: ${Util.firstToUpper(mode.name)}, ${mode.isMajor ? 'major' : 'minor'}'
          ', halfStep: ${mode.halfStep}',
        );
        mode.chordComponents;
        for (ChordComponent component in mode.chordComponents) {
          final halfSteps = (mode.halfStep + component.halfSteps) % MusicConstants.halfStepsPerOctave;
          logger.i(
            '     ${majorKey.getKeyScaleNoteByHalfStep(halfSteps).toString().padLeft(2)}'
            ' ${component.toString().padLeft(2)}',
            // ', halfSteps: $halfSteps',
          );
        }
      }
    }
  });

  test('improv Diatonic.parse', () {
    for (final progString in commonImprovChordProgressions) {
      logger.i(progString);
      List<Diatonic> progression = Diatonic.parse(progString);
      String parsed;
      {
        StringBuffer sb = StringBuffer();
        for (Diatonic diatonic in progression) {
          if (sb.isNotEmpty) sb.write(' ');
          sb.write(diatonic.label);
        }
        parsed = sb.toString();
      }
      // logger.i('   parsed: $parsed');
      assert(progString == parsed);
    }
  });

  test('improv guess', () {
    for (final MajorKey majorKey in MajorKey.values) {
      for (final progString in commonImprovChordProgressions) {
        List<Diatonic> progression = Diatonic.parse(progString);
        String parsed;
        {
          StringBuffer sb = StringBuffer();
          for (Diatonic diatonic in progression) {
            if (sb.isNotEmpty) sb.write(' ');
            sb.write(diatonic.label);
          }
          parsed = sb.toString();
        }

        for (final Mode mode in Mode.values) {
          String progChordString;
          {
            StringBuffer sb = StringBuffer();
            for (Diatonic diatonic in progression) {
              if (sb.isNotEmpty) sb.write(' ');
              sb.write(majorKey.getKeyScaleNoteByHalfStep(diatonic.halfStep + mode.halfStep).toString());
            }
            progChordString = sb.toString();
          }
          logger.i('');
          logger.i('$majorKey ${mode.name} ${mode.isMajor}: $parsed:  "$progChordString"');
          ProgressionGuessResult result = guessProgression(progChordString);
          logger.i(result.toString());
        }
      }
    }
  });
}

class ProgressionGuessResult {
  const ProgressionGuessResult(this.majorKey, this.mode, this.progression, this.progChordString);

  @override
  String toString() {
    return '$majorKey, ${mode.name}  ${mode.isMajor}: $progression:  "$progChordString"';
  }

  final MajorKey majorKey;
  final Mode mode;
  final List<Diatonic> progression;
  final String progChordString;
}

ProgressionGuessResult guessProgression(String progChordString, {int beatsPerBar = 4}) {
  //  find the scale notes used and their count
  Phrase phrase = Phrase.parseString(progChordString, 0, beatsPerBar, null);

  logger.i('guessProgression: "$progChordString"  => $phrase');

  List<Chord> chords = [];
  Map<int, int> scaleNotes = {};
  for (final Measure m in phrase.measures) {
    for (final chord in m.chords) {
      // chord.slashScaleNote;
      for (final pitch in chord.pianoChordPitches()) {
        final int halfStep = pitch.scaleNote.halfStep;
        scaleNotes[halfStep] = (scaleNotes[halfStep] ?? 0) + 1;
      }
      chords.add(chord);
    }
  }
  logger.i('  "$progChordString"  => $chords: ${scaleNotes}');

  int bestScore = 0;
  ProgressionGuessResult? bestResult;
  for (final MajorKey majorKey in MajorKey.values) {
    for (final Mode mode in Mode.values) {
      int score = 0;
      PentatonicScale pentatonicScale = mode.pentatonicScale;
      for (final degree in pentatonicScale.degrees) {
        ScaleNote note = majorKey.getKeyScaleNoteByHalfStep(mode.halfStep + degree.halfSteps);
        // logger.i('   $note:  ${note.halfStep}  ${scaleNotes[note.halfStep]}');
        score += (scaleNotes[note.halfStep] ?? 0);
      }
      if (score > bestScore) {
        bestScore = score;
        bestResult = ProgressionGuessResult(majorKey, mode, [], progChordString);
        logger.i('   bestScore:  $bestScore  at  $bestResult');
      }
    }
  }

  return bestResult ?? ProgressionGuessResult(MajorKey.C, Mode.ionian, [], progChordString);
}
