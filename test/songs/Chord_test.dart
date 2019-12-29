import 'dart:collection';

import 'package:bsteele_music_flutter/songs/Chord.dart';
import 'package:bsteele_music_flutter/songs/ChordAnticipationOrDelay.dart';
import 'package:bsteele_music_flutter/songs/ChordDescriptor.dart';
import 'package:bsteele_music_flutter/songs/key.dart';
import 'package:bsteele_music_flutter/songs/scaleChord.dart';
import 'package:bsteele_music_flutter/songs/scaleNote.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

import '../CustomMatchers.dart';

void main() {
  Logger.level = Level.warning;
  Logger _logger = new Logger();

  test("testSetScaleChord testing", () {
    SplayTreeSet<ScaleChord> slashScaleChords = SplayTreeSet();
    for (int beatsPerBar = 2; beatsPerBar <= 4; beatsPerBar++)
      for (ChordAnticipationOrDelay anticipationOrDelay
          in ChordAnticipationOrDelay.values) {
        _logger.d("anticipationOrDelay: " + anticipationOrDelay.toString());
        for (ScaleNote scaleNote in ScaleNote.values) {
          if (scaleNote.getEnum() == ScaleNoteEnum.X) continue;
          for (ChordDescriptor chordDescriptor in ChordDescriptor.values) {
            for (int beats = 2; beats <= 4; beats++) {
              ScaleChord scaleChord =  new ScaleChord(scaleNote, chordDescriptor);
              if (chordDescriptor == ChordDescriptor.minor)
                slashScaleChords.add(scaleChord);
              Chord chord = new Chord(scaleChord, beats, beatsPerBar, null,
                  anticipationOrDelay, true);
              _logger.d(chord.toString());
              Chord pChord = Chord.parseString(chord.toString(), beatsPerBar);

              if (beats != beatsPerBar) {
                //  the beats will default to beats per bar if unspecified
                expect(pChord.scaleChord, CompareTo(chord.scaleChord));
                expect(pChord.slashScaleNote, chord.slashScaleNote);
              } else
                expect( pChord, CompareTo(chord) );
            }
          }
        }
      }
  });

  test("testChordParse testing", () {
    Chord chord;
    int beatsPerBar = 4;
    chord = new Chord.byScaleChord(
        ScaleChord.fromScaleNoteEnumAndChordDescriptor(
            ScaleNoteEnum.D, ChordDescriptor.diminished));
    chord.slashScaleNote = ScaleNote.get(ScaleNoteEnum.G);

    _logger.i("\""+Chord.parseString("Ddim/G", beatsPerBar).toString()+"\"");
    _logger.i("compare: "+Chord.parseString("Ddim/G", beatsPerBar).compareTo(chord).toString());
    _logger.i("==: "+(Chord.parseString("Ddim/G", beatsPerBar)==chord?"true":"false"));
    Chord pChord =Chord.parseString("Ddim/G", beatsPerBar);
    expect(pChord, CompareTo(chord));

    chord = new Chord.byScaleChord(
        new ScaleChord.fromScaleNoteEnumAndChordDescriptor(
            ScaleNoteEnum.X, ChordDescriptor.major));
    chord.slashScaleNote = ScaleNote.get(ScaleNoteEnum.G);
    expect(Chord.parseString("X/G", beatsPerBar), CompareTo(chord));

    chord = new Chord.byScaleChord(
        new ScaleChord.fromScaleNoteEnumAndChordDescriptor(
            ScaleNoteEnum.A, ChordDescriptor.diminished));
    chord.slashScaleNote = ScaleNote.get(ScaleNoteEnum.G);
    expect(Chord.parseString("Adim/G", beatsPerBar), CompareTo(chord));
    chord = new Chord.byScaleChord(
        new ScaleChord.fromScaleNoteEnumAndChordDescriptor(
            ScaleNoteEnum.G, ChordDescriptor.suspendedSecond));
    chord.slashScaleNote = ScaleNote.get(ScaleNoteEnum.A);
    expect(Chord.parseString("G2/A", beatsPerBar), CompareTo(chord));
    chord = new Chord.byScaleChord(
        new ScaleChord.fromScaleNoteEnumAndChordDescriptor(
            ScaleNoteEnum.G, ChordDescriptor.add9));
    expect(Chord.parseString("Gadd9A", beatsPerBar), CompareTo(chord));

    chord = Chord.parseString("G.1", beatsPerBar);
    expect(chord.toString(), "G.1");
    chord = Chord.parseString("G.2", beatsPerBar);
    expect(chord.toString(), "G.");
    chord = Chord.parseString("G.3", beatsPerBar);
    expect(chord.toString(), "G..");
    chord = Chord.parseString("G.4", beatsPerBar);
    expect(chord.toString(), "G");
  });

  test("testChordTranspose testing", () {
    int count = 0;
    for (Key key in Key.values)
      for (ScaleNote sn in ScaleNote.values)
        for (int beatsPerBar = 2; beatsPerBar <= 4; beatsPerBar++)
          for (int halfSteps = -15; halfSteps < 15; halfSteps++)
            for (ChordDescriptor chordDescriptor in ChordDescriptor.values) {
              ScaleNote snHalfSteps = sn.transpose(key, halfSteps);

              _logger.d(sn.toString() +
                  chordDescriptor.shortName +
                  " " +
                  halfSteps.toString() +
                  " in key " +
                  key.toString() +
                  " " +
                  beatsPerBar.toString() +
                  " beats");
              expect(
                  Chord.parseString(
                      snHalfSteps.toString() + chordDescriptor.shortName,
                      beatsPerBar),
                  CompareTo(Chord.parseString(sn.toString() + chordDescriptor.shortName,
                          beatsPerBar)
                      .transpose(key, halfSteps)));
              count++;
            }
    _logger.d("transpose count: " + count.toString());

    count = 0;
    for (Key key in Key.values)
      for (ScaleNote sn in ScaleNote.values)
        for (ScaleNote slashSn in ScaleNote.values)
          for (int beatsPerBar = 2; beatsPerBar <= 4; beatsPerBar++)
            for (int halfSteps = -15; halfSteps < 15; halfSteps++)
              for (ChordDescriptor chordDescriptor in ChordDescriptor.values) {
                ScaleNote snHalfSteps = sn.transpose(key, halfSteps);
                ScaleNote slashSnHalfSteps = slashSn.transpose(key, halfSteps);

                _logger.d(sn.toString() +
                    chordDescriptor.shortName +
                    "/" +
                    slashSn.toString() +
                    " " +
                    halfSteps.toString() +
                    " in key " +
                    key.toString() +
                    " " +
                    beatsPerBar.toString() +
                    " beats");
                expect(
                    Chord.parseString(
                        snHalfSteps.toString() +
                            chordDescriptor.shortName +
                            "/" +
                            slashSnHalfSteps.toString(),
                        beatsPerBar),
                    CompareTo(Chord.parseString(
                            sn.toString() +
                                chordDescriptor.shortName +
                                "/" +
                                slashSn.toString(),
                            beatsPerBar)
                        .transpose(key, halfSteps)));
                count++;
              }
    _logger.d("transpose slash count: " + count.toString());
  });

  test("testSimpleChordTranspose testing", () {
    int count = 0;
    for (Key key in <Key>[Key.get(KeyEnum.C), Key.get(KeyEnum.G)])
      for (ScaleNote sn in ScaleNote.values)
        for (int halfSteps = 0; halfSteps < 12; halfSteps++) {
          ScaleNote snHalfSteps = sn.transpose(key, halfSteps);

          _logger.d(sn.toString() +
              " " +
              halfSteps.toString() +
              " in key " +
              key.toString() +
              " +> " +
              snHalfSteps.toString());
//                                assertEquals(Chord.parse(snHalfSteps + chordDescriptor.getShortName(), beatsPerBar),
//                                        Chord.parse(sn + chordDescriptor.getShortName(), beatsPerBar)
//                                                .transpose(key, halfSteps));
          count++;
        }
    _logger.d("transpose count: " + count.toString());
  });
}
