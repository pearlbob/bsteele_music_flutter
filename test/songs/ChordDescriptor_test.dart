import 'package:bsteele_music_flutter/songs/ChordDescriptor.dart';
import 'package:bsteele_music_flutter/songs/MusicConstants.dart';
import 'package:flutter/cupertino.dart';
import 'package:test/test.dart';

void main() {
  test("ChordDescriptor testing", () {
    expect(ChordDescriptor.major7,
        ChordDescriptor.parseString("" + MusicConstants.greekCapitalDelta));
    expect(ChordDescriptor.diminished,
        ChordDescriptor.parseString("" + MusicConstants.diminishedCircle));
    expect(ChordDescriptor.major, ChordDescriptor.parseString(""));
    expect(ChordDescriptor.minor, ChordDescriptor.parseString("m"));
    expect(ChordDescriptor.dominant7, ChordDescriptor.parseString("7"));
    expect(ChordDescriptor.major7, ChordDescriptor.parseString("maj7"));
    expect(ChordDescriptor.minor7, ChordDescriptor.parseString("m7"));
    expect(ChordDescriptor.augmented5, ChordDescriptor.parseString("aug5"));
    expect(ChordDescriptor.diminished, ChordDescriptor.parseString("dim"));
    expect(ChordDescriptor.suspended4, ChordDescriptor.parseString("sus4"));
    expect(ChordDescriptor.power5, ChordDescriptor.parseString("5"));
    expect(ChordDescriptor.dominant9, ChordDescriptor.parseString("9"));
    expect(ChordDescriptor.dominant13, ChordDescriptor.parseString("13"));
    expect(ChordDescriptor.dominant11, ChordDescriptor.parseString("11"));
    expect(ChordDescriptor.minor7b5, ChordDescriptor.parseString("m7b5"));
    expect(ChordDescriptor.add9, ChordDescriptor.parseString("add9"));
    expect(ChordDescriptor.jazz7b9, ChordDescriptor.parseString("jazz7b9"));
    expect(ChordDescriptor.sevenSharp5, ChordDescriptor.parseString("7#5"));
    expect(ChordDescriptor.sevenFlat5, ChordDescriptor.parseString("7b5"));
    expect(ChordDescriptor.sevenSharp9, ChordDescriptor.parseString("7#9"));
    expect(ChordDescriptor.sevenFlat9, ChordDescriptor.parseString("7b9"));
    expect(ChordDescriptor.major6, ChordDescriptor.parseString("6"));
    expect(ChordDescriptor.six9, ChordDescriptor.parseString("69"));
    expect(ChordDescriptor.power5, ChordDescriptor.parseString("5"));
    expect(ChordDescriptor.diminished7, ChordDescriptor.parseString("dim7"));
    expect(ChordDescriptor.augmented, ChordDescriptor.parseString("aug"));
    expect(ChordDescriptor.augmented5, ChordDescriptor.parseString("aug5"));
    expect(ChordDescriptor.augmented7, ChordDescriptor.parseString("aug7"));
    expect(ChordDescriptor.suspended7, ChordDescriptor.parseString("sus7"));
    expect(ChordDescriptor.suspended2, ChordDescriptor.parseString("sus2"));
    expect(ChordDescriptor.suspended, ChordDescriptor.parseString("sus"));
    expect(ChordDescriptor.minor11, ChordDescriptor.parseString("m11"));
    expect(ChordDescriptor.minor13, ChordDescriptor.parseString("m13"));

    for (ChordDescriptor cd in ChordDescriptor.values) {
      print(cd.toString() + ":\t" + cd.chordComponentsToString());
    }
    {
      int expected = -1;
      ChordDescriptor cd1 = ChordDescriptor.dominant7;
      for (ChordDescriptor cd2 in ChordDescriptor.values) {
        int compareValue = cd2.compareTo(cd1);
        compareValue = (compareValue < 0 ? -1 : (compareValue > 0 ? 1 : 0));

        debugPrint(cd2.toString() + ":\tcompare:\t" + compareValue.toString());
        if (cd1 == cd2) {
          expect(0, compareValue);
          expected = 1;
        } else
          expect(expected, compareValue);
      }
    }

    //print(ChordDescriptor.generateGrammar());
  });
}
