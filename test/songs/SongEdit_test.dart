import 'package:bsteele_music_flutter/appLogger.dart';
import 'package:bsteele_music_flutter/songs/ChordSection.dart';
import 'package:bsteele_music_flutter/songs/ChordSectionLocation.dart';
import 'package:bsteele_music_flutter/songs/Measure.dart';
import 'package:bsteele_music_flutter/songs/MeasureNode.dart';
import 'package:bsteele_music_flutter/songs/MeasureRepeat.dart';
import 'package:bsteele_music_flutter/songs/Phrase.dart';
import 'package:bsteele_music_flutter/songs/SectionVersion.dart';
import 'package:bsteele_music_flutter/songs/SongBase.dart';
import 'package:bsteele_music_flutter/songs/key.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

SongBase a;

class TestSong {
  void startingChords(String chords) {
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        chords,
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
  }

  void pre(MeasureEditType type, String locationString,
      String measureNodeString, String editEntry) {
    //  de-music character the result
    measureNodeString = _deMusic(measureNodeString);

    a.setCurrentMeasureEditType(type);
    if (locationString != null && locationString.isNotEmpty) {
      a.setCurrentChordSectionLocation(
          ChordSectionLocation.parseString(locationString));

      expect(a.getCurrentChordSectionLocation().toString(), locationString);

      if (measureNodeString != null) {
        expect(a.getCurrentMeasureNode().toMarkup().trim(),
            measureNodeString.trim());
      }
    }

    logger.d("editEntry: " + editEntry);
    logger.v("edit loc: " + a.getCurrentChordSectionLocation().toString());
    List<MeasureNode> measureNodes = a.parseChordEntry(editEntry);
    if (measureNodes.isEmpty &&
        (editEntry == null || editEntry.isEmpty) &&
        type == MeasureEditType.delete) {
      expect(a.deleteCurrentSelection(), isTrue);
    } else {
      for (MeasureNode measureNode in measureNodes) {
        logger.d("edit: " + measureNode.toMarkup());
      }
      expect(a.editList(measureNodes), isTrue);
    }
    logger.v("after edit loc: " + a.getCurrentChordSectionLocation().toString());
  }

  void resultChords(String chords) {
    expect(a.toMarkup().trim(), _deMusic(chords).trim());
  }

  void post(
      MeasureEditType type, String locationString, String measureNodeString) {
    measureNodeString = _deMusic(measureNodeString);

    expect(type, a.getCurrentMeasureEditType());
    expect(locationString, a.getCurrentChordSectionLocation().toString());
    logger.d("measureNodeString: " + measureNodeString);
    logger
        .d("getCurrentMeasureNode(): " + a.getCurrentMeasureNode().toString());
    if (measureNodeString == null)
      expect(a.getCurrentMeasureNode(), isNull);
    else {
      expect(a.getCurrentMeasureNode().toMarkup().trim(),
          measureNodeString.trim());
    }
  }

  String _deMusic(String s) {
    if (s == null) return null;

    //  de-music characters in the string
    s = s.replaceAll("♯", "#");
    s = s.replaceAll("♭", "b");
    return s;
  }
}

void main() {
  Logger.level = Level.verbose;
  TestSong ts = TestSong();

  test("testEdits", () {
    SectionVersion v = SectionVersion.parseString("v:");
    SectionVersion iSection = SectionVersion.parseString("i:");
    int beatsPerBar = 4;
    ChordSectionLocation location;
    ChordSection newSection;
    MeasureRepeat newRepeat;
    Phrase newPhrase;
    Measure newMeasure;

    ts.startingChords("");
    ts.pre(MeasureEditType.append, "", "", "i: [A B C D]");
    ts.resultChords("I: A B C D ");
    ts.post(MeasureEditType.append, "I:", "I: A B C D");

    ts.startingChords("");
    ts.pre(MeasureEditType.append, "", "",
        SongBase.entryToUppercase("i: [a b c d]"));
    ts.resultChords("I: A B C D ");
    ts.post(MeasureEditType.append, "I:", "I: A B C D");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G F F  O: Dm C B B♭ A  ");
    ts.pre(MeasureEditType.replace, "C:", "C: F F C C G G F F ",
        "C: F F C C G G C B F F ");
    ts.resultChords(
        "I: V: [Am Am/G Am/F# FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C, G G C B, F F  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.append, "C:", "C: F F C C, G G C B, F F ");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C B F F  O: Dm C B B♭ A  ");
    ts.pre(MeasureEditType.delete, "C:0:7", "B", "null");
    ts.resultChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C F F  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.delete, "C:0:7", "F");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C F F  O: Dm C B B♭ A  ");
    ts.pre(MeasureEditType.delete, "C:0:7", "F", "null");
    ts.resultChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C F  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.delete, "C:0:7", "F");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C F  O: Dm C B B♭ A  ");
    ts.pre(MeasureEditType.delete, "C:0:7", "F", "null");
    ts.resultChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.delete, "C:0:6", "C");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C  O: Dm C B B♭ A  ");
    ts.pre(MeasureEditType.append, "C:0:6", "C", "G G ");
    ts.resultChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C G G  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.append, "C:0:8", "G");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G C G G  O: Dm C B B♭ A  ");
    ts.pre(
        MeasureEditType.replace, "I2:0", "[Am Am/G Am/F♯ FE ] x2 ", "[] x3 ");
    ts.resultChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x3  C: F F C C G G C G G  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.append, "I2:0", "[Am Am/G Am/F♯ FE ] x3 ");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x3  C: F F C C G G C G G  O: Dm C B B♭ A  ");
    ts.pre(
        MeasureEditType.replace, "I2:0", "[Am Am/G Am/F♯ FE ] x3 ", "[] x1 ");
    ts.resultChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: Am Am/G Am/F♯ FE  C: F F C C G G C G G  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.append, "I2:0:3", "FE");

    ts.startingChords(
        "I: A G D  V: D C G G  V1: Dm  V2: Em  PC: D C G D  C: F7 G7 G Am  ");
    ts.pre(MeasureEditType.delete, "I:0:1", "G", "null");
    ts.resultChords(
        "I: A D  V: D C G G  V1: Dm  V2: Em  PC: D C G D  C: F7 G7 G Am  ");
    ts.post(MeasureEditType.delete, "I:0:1", "D");

    ts.startingChords(
        "I: A G D  V: D C G G  V1: Dm  V2: Em  PC: D C G D  C: F7 G7 G Am  ");
    ts.pre(MeasureEditType.replace, "I:0:1", "G", "B C");
    ts.resultChords(
        "I: A B C D  V: D C G G  V1: Dm  V2: Em  PC: D C G D  C: F7 G7 G Am  ");
    ts.post(MeasureEditType.append, "I:0:2", "C");

    ts.startingChords("V: C F C C F F C C G F C G  ");
    ts.pre(MeasureEditType.append, "V:0:11", "G", "PC: []");
    ts.resultChords("V: C F C C F F C C G F C G  PC: [] ");
    ts.post(MeasureEditType.append, "PC:", "PC: []");
    ts.startingChords("V: C F C C F F C C G F C G  PC: [] ");
    ts.pre(MeasureEditType.replace, "PC:", "PC: []", "PC: []");
    ts.resultChords("V: C F C C F F C C G F C G  PC: [] ");
    ts.post(MeasureEditType.append, "PC:", "PC: []");
    ts.startingChords("V: C F C C F F C C G F C G  PC:  ");
    ts.pre(MeasureEditType.append, "PC:", "PC: []", "O: []");
    ts.resultChords("V: C F C C F F C C G F C G  PC: [] O: [] ");
    ts.post(MeasureEditType.append, "O:", "O: []");
    ts.startingChords("V: C F C C F F C C G F C G  PC: []  O: [] ");
    ts.pre(MeasureEditType.replace, "O:", "O: []", "O: []");
    ts.resultChords("V: C F C C F F C C G F C G  PC: [] O: [] ");
    ts.post(MeasureEditType.append, "O:", "O: []");

    ts.startingChords("V: [C♯m A♭ F A♭ ] x4 C  C: [C G B♭ F ] x4  ");
    ts.pre(MeasureEditType.delete, "V:", "V: [C♯m A♭ F A♭ ] x4 C ", "null");
    ts.resultChords("C: [C G B♭ F ] x4  ");
    ts.post(MeasureEditType.delete, "C:", "C: [C G B♭ F ] x4 ");
    ts.startingChords("C: [C G B♭ F ] x4  ");
    ts.pre(MeasureEditType.delete, "C:", "C: [C G B♭ F ] x4 ", "null");
    ts.resultChords("");
    ts.post(MeasureEditType.append, "V:", null);

    ts.startingChords("V: [C♯m A♭ F A♭ ] x4 C  PC2:  C: T: [C G B♭ F ] x4  ");
    ts.pre(MeasureEditType.delete, "PC2:", "PC2: [C G B♭ F ] x4", "null");
    ts.resultChords("V: [C♯m A♭ F A♭ ] x4 C  C: T: [C G B♭ F ] x4  ");
    ts.post(MeasureEditType.delete, "V:", "V: [C♯m A♭ F A♭ ] x4 C ");
    ts.startingChords("V: [C♯m A♭ F A♭ ] x4 C  C: T: [C G B♭ F ] x4  ");
    ts.pre(MeasureEditType.delete, "V:", "V: [C♯m A♭ F A♭ ] x4 C ", "null");
    ts.resultChords("C: T: [C G B♭ F ] x4  ");
    ts.post(MeasureEditType.delete, "C:", "C: [C G B♭ F ] x4 ");
    ts.startingChords("C: T: [C G B♭ F ] x4  ");
    ts.pre(MeasureEditType.delete, "C:", "C: [C G B♭ F ] x4 ", "null");
    ts.resultChords("T: [C G B♭ F ] x4  ");
    ts.post(MeasureEditType.delete, "T:", "T: [C G B♭ F ] x4 ");
    ts.startingChords("T: [C G B♭ F ] x4  ");
    ts.pre(MeasureEditType.delete, "T:", "T: [C G B♭ F ] x4 ", "null");
    ts.resultChords("");
    ts.post(MeasureEditType.append, "V:", null);

    ts.startingChords("V: C F C C F F C C G F C G  ");
    ts.pre(MeasureEditType.append, "V:0:7", "C", "C PC:");
    ts.resultChords("V: C F C C F F C C C G F C G  PC: []");
    ts.post(MeasureEditType.append, "PC:", "PC: []");
    ts.startingChords("V: C F C C F F C C G F C G  ");
    ts.pre(MeasureEditType.append, "V:0:7", "C", "PC:");
    ts.resultChords("V: C F C C F F C C G F C G  PC: []");
    ts.post(MeasureEditType.append, "PC:", "PC: []");

    ts.startingChords(
        "V: (Prechorus) C (C/) (chorus) [C G B♭ F ] x4 (Tag Chorus)  ");
    ts.pre(MeasureEditType.delete, "V:0:0", "(Prechorus)", "null");
    ts.resultChords("V: C (C/) (chorus) [C G B♭ F ] x4 (Tag Chorus)  ");

    ts.startingChords(
        "V: (Verse) [C♯m A♭ F A♭ ] x4 (Prechorus) C (C/) (chorus) [C G B♭ F ] x4 (Tag Chorus)  ");
    ts.pre(MeasureEditType.delete, "V:0:0", "(Verse)", "null");
    ts.resultChords(
        "V: [C♯m A♭ F A♭ ] x4 (Prechorus) C (C/) (chorus) [C G B♭ F ] x4 (Tag Chorus)  ");
    ts.post(MeasureEditType.delete, "V:0:0", "C♯m");
    a.setCurrentChordSectionLocation(ChordSectionLocation.parseString("V:0"));
    expect("[C♯m A♭ F A♭ ] x4 ",
        a.getCurrentChordSectionLocationMeasureNode().toMarkup());
    a.setCurrentChordSectionLocation(ChordSectionLocation.parseString("V:1:0"));
    expect("(Prechorus)",
        a.getCurrentChordSectionLocationMeasureNode().toMarkup());
    ts.pre(MeasureEditType.delete, "V:1:0", "(Prechorus)", "null");
    ts.resultChords(
        "V: [C♯m A♭ F A♭ ] x4 C (C/) (chorus) [C G B♭ F ] x4 (Tag Chorus)  ");
    ts.post(MeasureEditType.delete, "V:1:0", "C");
    ts.pre(MeasureEditType.delete, "V:1:1", "(C/)", "null");
    ts.resultChords(
        "V: [C♯m A♭ F A♭ ] x4 C (chorus) [C G B♭ F ] x4 (Tag Chorus)  ");
    ts.post(MeasureEditType.delete, "V:1:1", "(chorus)");
    ts.pre(MeasureEditType.delete, "V:1:1", "(chorus)", "null");
    ts.resultChords("V: [C♯m A♭ F A♭ ] x4 C [C G B♭ F ] x4 (Tag Chorus)  ");
    ts.post(MeasureEditType.delete, "V:2:0", "C");
    ts.pre(MeasureEditType.delete, "V:3:0", "(Tag Chorus)", "null");
    ts.resultChords("V: [C♯m A♭ F A♭ ] x4 C [C G B♭ F ] x4  ");
    ts.post(MeasureEditType.delete, "V:2:3", "F");

    ts.startingChords(
        "I: CXCC XCCC CXCC XCCC (bass-only)  V: Cmaj7 Cmaj7 Cmaj7 Cmaj7 Cmaj7 C7 F F Dm G Em Am F G Cmaj7 Cmaj7  C: A♭ A♭ E♭ E♭ B♭ B♭ G G  O: Cmaj7 Cmaj7 Cmaj7 Cmaj7 Cmaj7 C7 F F Dm G Em Am F G Em A7 F F G G Cmaj7 Cmaj7 Cmaj7 Cmaj7 Cmaj7 Cmaj7 (fade)  ");
    ts.pre(MeasureEditType.append, "I:0:4", "(bass-only)", "XCCC ");
    ts.resultChords(
        "I: CXCC XCCC CXCC XCCC (bass-only) XCCC  V: Cmaj7 Cmaj7 Cmaj7 Cmaj7 Cmaj7 C7 F F Dm G Em Am F G Cmaj7 Cmaj7  C: A♭ A♭ E♭ E♭ B♭ B♭ G G  O: Cmaj7 Cmaj7 Cmaj7 Cmaj7 Cmaj7 C7 F F Dm G Em Am F G Em A7 F F G G Cmaj7 Cmaj7 Cmaj7 Cmaj7 Cmaj7 Cmaj7 (fade)  ");
    ts.post(MeasureEditType.append, "I:0:5", "XCCC");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G F F  O: Dm C B B♭ A  ");
    ts.pre(MeasureEditType.append, "I:0", "[Am Am/G Am/F♯ FE ] x4 ", "E ");
    ts.resultChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4 E  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G F F  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.append, "I:1:0", "E");

    ts.startingChords(
        "I: V: O: E♭sus2 B♭ Gm7 Em F F7 G7 G Em Em Em Em Em Em Em Em Em C  C: [Cm F B♭ E♭ ] x3 Cm F  ");
    ts.pre(MeasureEditType.delete, "I:0:14", "Em", "null");
    ts.resultChords(
        "I: V: O: E♭sus2 B♭ Gm7 Em F F7 G7 G Em Em Em Em Em Em Em Em C  C: [Cm F B♭ E♭ ] x3 Cm F  ");
    ts.post(MeasureEditType.delete, "I:0:14", "Em");

    ts.startingChords("I: V: O: E♭sus2 B♭ Gm7 C  C: [Cm F B♭ E♭ ] x3 Cm F  ");
    ts.pre(MeasureEditType.append, "I:0:2", "Gm7", "Em7 ");
    ts.resultChords("I: V: O: E♭sus2 B♭ Gm7 Em7 C  C: [Cm F B♭ E♭ ] x3 Cm F  ");
    ts.post(MeasureEditType.append, "I:0:3", "Em7");

    ts.startingChords(
        "I: V: [Am Am/G Am/F♯ FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G F F  O: Dm C B B♭ A  ");
    ts.pre(MeasureEditType.replace, "V:0:2", "Am/F♯", "Am/G ");
    ts.resultChords(
        "I: V: [Am Am/G Am/G FE ] x4  I2: [Am Am/G Am/F♯ FE ] x2  C: F F C C G G F F  O: Dm C B B♭ A  ");
    ts.post(MeasureEditType.append, "V:0:2", "Am/G");

    ts.startingChords("V: C F C C F F C C G F C G  ");
    ts.pre(MeasureEditType.replace, "V:0:3", "C", "[] x1 ");
    ts.resultChords("V: C F C C F F C C G F C G  ");
    ts.post(MeasureEditType.replace, "V:0:3", "C");

    ts.startingChords("V: C F C C F F C C G F C G  ");
    //                 0 1 2 3 4 5 6 7 8 9 0 1
    ts.pre(MeasureEditType.replace, "V:0:6", "C", "[] x2 ");
    ts.resultChords("V: [C F C C F F C C ] x2 G F C G  ");
    //               0 1 2 3  4 5 6 7      8 9 0 1
    //               0 1 2 3  0 1 2 3      0 1 2 3
    ts.post(MeasureEditType.append, "V:0", "[C F C C F F C C ] x2");

    ts.startingChords("V: C F C C F F C C G F C G  ");
    //                 0 1 2 3 4 5 6 7 8 9 0 1
    ts.pre(MeasureEditType.replace, "V:0:6", "C", "[] x3 ");
    ts.resultChords("V: [C F C C F F C C ] x3 G F C G  ");
    ts.post(MeasureEditType.append, "V:0", "[C F C C F F C C ] x3");

    ts.startingChords("I:  V:  ");
    ts.pre(MeasureEditType.append, "V:", "V: []", "Dm ");
    ts.resultChords("I: [] V: Dm  ");
    ts.post(MeasureEditType.append, "V:0:0", "Dm");

    ts.startingChords("I:  V:  ");
    ts.pre(MeasureEditType.replace, "V:", "V: []", "Dm ");
    ts.resultChords("I: [] V: Dm  ");
    ts.post(MeasureEditType.append, "V:0:0", "Dm");

    ts.startingChords("V: C F F C C F F C C G F C G  ");
    ts.pre(MeasureEditType.delete, "V:", "V: C F F C C F F C C G F C G ", null);
    ts.resultChords("");
    ts.post(MeasureEditType.append, "V:", null);

    ts.startingChords("V: C F C C F F C C G F C G  ");
    ts.pre(MeasureEditType.append, "V:0:11", "G", "- ");
    ts.resultChords("V: C F C C F F C C G F C G G  ");
    ts.post(MeasureEditType.append, "V:0:12", "G");

    ts.startingChords("V: C F C C F F C C G F C G G  ");
    ts.pre(MeasureEditType.append, "V:0:1", "F", "-");
    ts.resultChords("V: C F F C C F F C C G F C G G  ");
    ts.post(MeasureEditType.append, "V:0:2", "F");

    ts.startingChords("V: C F F C C F F C C G F C G G  ");
    ts.pre(MeasureEditType.append, "V:0:2", "F", "  -  ");
    ts.resultChords("V: C F F F C C F F C C G F C G G  ");
    ts.post(MeasureEditType.append, "V:0:3", "F");

    ts.startingChords("V: C F C C F F C C G F C G  ");
    ts.pre(MeasureEditType.append, "V:0:1", "F", "-");
    ts.resultChords("V: C F F C C F F C C G F C G  ");
    ts.post(MeasureEditType.append, "V:0:2", "F");

    ts.startingChords("I:  V:  ");
    ts.pre(MeasureEditType.append, "V:", "V: []", "T: ");
    ts.resultChords("I: [] V: [] T: []"); //  fixme: why is this?
    ts.post(MeasureEditType.append, "T:", "T: []");

    ts.startingChords("V: C F C C F F C C [G F C G ] x4  ");
    ts.pre(MeasureEditType.replace, "V:1", "[G F C G ] x4 ", "B ");
    ts.resultChords("V: C F C C F F C C B  ");
    //               0 1 2 3 4 5 6 7 8
    ts.post(MeasureEditType.append, "V:0:8", "B");

    //  insert into a repeat
    ts.startingChords("V: [C F C C ] x2 F F C C G F C G  ");
    ts.pre(MeasureEditType.insert, "V:0:1", "F", "Dm ");
    ts.resultChords("V: [C Dm F C C ] x2 F F C C G F C G  ");
    ts.post(MeasureEditType.append, "V:0:1", "Dm");

    //  append into the middle
    ts.startingChords("V: C Dm C C F F C C G F C G  ");
    ts.pre(MeasureEditType.append, "V:0:1", "Dm", "Em ");
    ts.resultChords("V: C Dm Em C C F F C C G F C G  ");
    ts.post(MeasureEditType.append, "V:0:2", "Em");

    //  replace second measure
    ts.startingChords("V: C F C C F F C C G F C G  "); //
    ts.pre(MeasureEditType.replace, "V:0:1", "F", "Dm "); //
    ts.resultChords("V: C Dm C C F F C C G F C G  "); //
    ts.post(MeasureEditType.append, "V:0:1", "Dm"); //

    a = SongBase.createSongBase(
        "A", "bob", "bsteele.com", Key.getDefault(), 100, 4, 4, "", "");
    logger.d(a.toMarkup());
    newPhrase = Phrase.parseString("A B C D", 0, beatsPerBar, null);
    logger.d(newPhrase.toMarkup());
    expect(a.editMeasureNode(newPhrase), isTrue);
    logger.d(a.toMarkup());
    expect("V: A B C D", a.toMarkup().trim());
    expect("V:0:3", a.getCurrentChordSectionLocation().toString());

    a = SongBase.createSongBase(
        "A", "bob", "bsteele.com", Key.getDefault(), 100, 4, 4, "", "");
    logger.d(a.toMarkup());
    newSection = ChordSection.parseString("v:", beatsPerBar);
    expect(a.editMeasureNode(newSection), isTrue);
    logger.d(a.toMarkup());
    expect("V: []", a.toMarkup().trim());
    expect("V:", a.getCurrentChordSectionLocation().toString());
    a.setCurrentMeasureEditType(MeasureEditType.append);
    newPhrase = Phrase.parseString("A B C D", 0, beatsPerBar, null);
    logger.d(newPhrase.toMarkup());
    expect(a.editMeasureNode(newPhrase), isTrue);
    logger.d(a.toMarkup());
    expect("V: A B C D", a.toMarkup().trim());
    expect("V:0:3", a.getCurrentChordSectionLocation().toString());
    newMeasure = Measure.parseString("E", beatsPerBar);
    logger.d(newPhrase.toMarkup());
    expect(a.editMeasureNode(newMeasure), isTrue);
    logger.d(a.toMarkup());
    expect("V: A B C D E", a.toMarkup().trim());
    expect("V:0:4", a.getCurrentChordSectionLocation().toString());
    newPhrase = Phrase.parseString("F", 0, beatsPerBar, null);
    logger.d(newPhrase.toMarkup());
    expect(a.editMeasureNode(newPhrase), isTrue);
    logger.d(a.toMarkup());
    expect("V: A B C D E F", a.toMarkup().trim());
    expect("V:0:5", a.getCurrentChordSectionLocation().toString());

    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: nope nope");
    logger.d(a.toMarkup());
    location = ChordSectionLocation.parseString("i:0:3");
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newPhrase = Phrase.parseString("Db C B A", 0, beatsPerBar, null);
    expect(a.editMeasureNode(newPhrase), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D D♭ C B A  V: D E F F♯  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect("I:0:7", a.getCurrentChordSectionLocation().toString());
    expect("A", a.getCurrentMeasureNode().toMarkup());

    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "V: C F C C [GB F C Dm7 ] x4 G F C G  ",
        "v: bob, bob, bob berand");
    logger.d(a.toMarkup());
    location = ChordSectionLocation.parseString("v:1");
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.replace);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newRepeat = MeasureRepeat.parseString("[]x1", 0, beatsPerBar, null);
    expect(a.editMeasureNode(newRepeat), isTrue);
    logger.d(a.toMarkup());
    expect("V: C F C C GB F C Dm7 G F C G", a.toMarkup().trim());
    //                        0 1 2 3 4  5 6 7   8 9 0 1
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect("V:0:7", a.getCurrentChordSectionLocation().toString());
    expect("Dm7", a.getCurrentMeasureNode().toMarkup());

    //   current type	current edit loc	entry	replace entry	new edit type	new edit loc	result
    logger.d(
        "section	append	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newSection = ChordSection.parseString("v: A D C D", beatsPerBar);
    expect(a.editMeasureNode(newSection), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(location, a.getCurrentChordSectionLocation());
    expect(newSection, a.getCurrentMeasureNode());

    logger.d(
        "repeat	append	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v, phraseIndex: 1);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());
    location = ChordSectionLocation.parseString("i:0:3");
    a.setCurrentChordSectionLocation(location);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newMeasure = Measure.parseString("F", beatsPerBar);
    expect(a.editMeasureNode(newMeasure), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D F  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("i:0:4"),
        a.getCurrentChordSectionLocation());
    expect(newMeasure.toMarkup(),
        a.getCurrentChordSectionLocationMeasureNode().toMarkup());

    logger.d(
        "phrase	append	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    a.setCurrentChordSectionLocation(
        new ChordSectionLocation(v, phraseIndex: 0));
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d(
        "measure	append	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    a.setCurrentChordSectionLocation(
        new ChordSectionLocation(v, phraseIndex: 0));
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d(
        "section	insert	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.insert);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(location, a.getCurrentChordSectionLocation());

    logger.d(
        "repeat	insert	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v, phraseIndex: 1);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.insert);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d(
        "phrase	insert	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    a.setCurrentChordSectionLocation(
        new ChordSectionLocation(v, phraseIndex: 0));
    a.setCurrentMeasureEditType(MeasureEditType.insert);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d(
        "measure	insert	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    a.setCurrentChordSectionLocation(
        new ChordSectionLocation(v, phraseIndex: 0));
    a.setCurrentMeasureEditType(MeasureEditType.insert);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d(
        "section	replace	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(iSection);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.replace);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d(
        "repeat	replace	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    a.setCurrentChordSectionLocation(
        new ChordSectionLocation(v, phraseIndex: 1));
    a.setCurrentMeasureEditType(MeasureEditType.replace);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d(
        "phrase	replace	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    a.setCurrentChordSectionLocation(
        new ChordSectionLocation(v, phraseIndex: 0));
    a.setCurrentMeasureEditType(MeasureEditType.replace);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d(
        "measure	replace	section(s)		replace	section(s)	add or replace section(s), de-dup");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    a.setCurrentChordSectionLocation(
        new ChordSectionLocation(v, phraseIndex: 0, measureIndex: 2));
    a.setCurrentMeasureEditType(MeasureEditType.replace);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());

    logger.d("section	delete	section(s)	yes	append	measure	delete section");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(iSection);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.delete);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("V: D E F F♯  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(new ChordSectionLocation(v), a.getCurrentChordSectionLocation());
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.delete);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v: A D C D", beatsPerBar)),
        isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        new ChordSectionLocation(iSection), a.getCurrentChordSectionLocation());

    logger.d("repeat  delete  section(s)  yes  append  measure  delete repeat");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D   V: D E F F# [ D C B A ]x2  c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v, phraseIndex: 1);
    a.setCurrentChordSectionLocation(location);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    a.setCurrentMeasureEditType(MeasureEditType.delete);
    expect(a.deleteCurrentSelection(), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: D E F F♯  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("V:0:3"),
        a.getCurrentChordSectionLocation());

    logger.d("phrase	delete	section(s)	yes	append	measure	delete phrase");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D   V: D E F F# [ D C B A ]x2  c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.delete);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(
        a.editMeasureNode(ChordSection.parseString("v:", beatsPerBar)), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("I:"),
        a.getCurrentChordSectionLocation());

    logger.d("measure	delete	section(s)	yes	append	measure	delete measure");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D   V: D E F F# [ D C B A ]x2  c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v, phraseIndex: 0, measureIndex: 1);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.delete);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(a.deleteCurrentSelection(), isTrue);
    logger.d(a.toMarkup());
    expect(
        "I: A B C D  V: D F F♯ [D C B A ] x2  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("V:0:1"),
        a.getCurrentChordSectionLocation());

    logger.d(
        "section  append  repeat    replace  repeat  add to start of section");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = new ChordSectionLocation(v);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newRepeat =
        MeasureRepeat.parseString("[ A D C D ] x3", 0, beatsPerBar, null);
    expect(a.editMeasureNode(newRepeat), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: D E F F♯ [A D C D ] x3  C: D C G G",
        a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("V:1"),
        a.getCurrentChordSectionLocation());

    //   current type	current edit loc	entry	replace entry	new edit type	new edit loc	result
    logger.d("repeat  append  repeat    replace  repeat  replace repeat");
    //  x1 repeat should be converted to phrase
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: [D E F F#]x3 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation(v, phraseIndex: 0);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.replace);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newRepeat =
        MeasureRepeat.parseString("[ A D C D ] x1", 0, beatsPerBar, null);
    expect(a.editMeasureNode(newRepeat), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: A D C D  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("V:0"),
        a.getCurrentChordSectionLocation());

    //  empty x1 repeat appended should be convert repeat to phrase
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: [D E F F#]x3 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation(v, phraseIndex: 0);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newRepeat = MeasureRepeat.parseString("[] x1", 0, beatsPerBar, null);
    expect(a.editMeasureNode(newRepeat), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: D E F F♯  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("V:0:3"),
        a.getCurrentChordSectionLocation());

    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: [D E F F#]x3 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation(v, phraseIndex: 0);
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.replace);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newRepeat =
        MeasureRepeat.parseString("[ A D C D ] x4", 0, beatsPerBar, null);
    expect(a.editMeasureNode(newRepeat), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: [A D C D ] x4  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("V:0"),
        a.getCurrentChordSectionLocation());

    logger.d("phrase  append  repeat    replace  repeat  append repeat");

    logger.d("measure  append  repeat    replace  repeat  append repeat");
    //  empty repeat replaces current phrase
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation.parseString("v:0:3");
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newRepeat = MeasureRepeat.parseString("[ ] x3", 0, beatsPerBar, null);
    expect(a.editMeasureNode(newRepeat), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: [D E F F♯ ] x3  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("v:0"),
        a.getCurrentChordSectionLocation());
    //  non-empty repeat appends to current section
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation.parseString("v:0:3");
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.append);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newRepeat =
        MeasureRepeat.parseString("[ D C G G] x3", 0, beatsPerBar, null);
    expect(a.editMeasureNode(newRepeat), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: D E F F♯ [D C G G ] x3  C: D C G G",
        a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(ChordSectionLocation.parseString("v:1"),
        a.getCurrentChordSectionLocation());

    logger.d(
        "section  insert  repeat    replace  repeat  add to start of section");
    logger.d("repeat  insert  repeat    replace  repeat  insert repeat");
    logger.d("phrase  insert  repeat    replace  repeat  insert repeat");
    logger.d("measure  insert  repeat    replace  repeat  insert repeat");
    logger.d(
        "section  replace  repeat    replace  repeat  replace section content");
    logger.d("repeat  replace  repeat    replace  repeat  replace repeat");
    logger.d("phrase  replace  repeat    replace  repeat  replace phrase");
    logger.d("measure  replace  repeat    replace  repeat  replace measure");
    logger.d("section  delete  repeat  yes  append  measure  delete section");
    logger.d("repeat  delete  repeat  yes  append  measure  delete repeat");
    logger.d("phrase  delete  repeat  yes  append  measure  delete phrase");
    logger.d("measure  delete  repeat  yes  append  measure  delete measure");
    logger.d("section  append  phrase       phrase  append to end of section");
    logger.d(
        "repeat  append  phrase    replace  phrase  append to end of repeat");
    logger.d(
        "phrase  append  phrase    replace  phrase  append to end of phrase, join phrases");
    logger.d(
        "measure  append  phrase    replace  phrase  append to end of measure, join phrases");
    logger.d(
        "section  insert  phrase    replace  phrase  insert to start of section");
    logger.d(
        "repeat  insert  phrase    replace  phrase  insert to start of repeat content");
    logger.d(
        "phrase  insert  phrase    replace  phrase  insert to start of phrase");
    logger.d(
        "measure  insert  phrase    replace  phrase  insert at start of measure");
    logger.d(
        "section  replace  phrase    replace  phrase  replace section content");
    logger.d(
        "repeat  replace  phrase    replace  phrase  replace repeat content");
    logger.d("phrase  replace  phrase    replace  phrase  replace");
    logger.d("measure  replace  phrase    replace  phrase  replace");
    logger.d("section  delete  phrase  yes  append  measure  delete section");
    logger.d("repeat  delete  phrase  yes  append  measure  delete repeat");
    logger.d("phrase  delete  phrase  yes  append  measure  delete phrase");
    logger.d("measure  delete  phrase  yes  append  measure  delete measure");
    logger.d(
        "section  append  measure    append  measure  append to end of section");
    logger.d(
        "repeat  append  measure    append  measure  append past end of repeat");
    logger.d(
        "phrase  append  measure    append  measure  append to end of phrase");
    logger.d(
        "measure  append  measure    append  measure  append to end of measure");
    logger.d(
        "section  insert  measure    append  measure  insert to start of section");
    logger.d(
        "repeat  insert  measure    append  measure  insert prior to start of repeat");
    logger.d(
        "phrase  insert  measure    append  measure  insert to start of phrase");

    logger.d(
        "measure  insert  measure    append  measure  insert to start of measure");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ A D C D ] x3 c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation.parseString("v:0:2");
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.insert);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newMeasure = Measure.parseString("Gm", beatsPerBar);
    expect(a.editMeasureNode(newMeasure), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: D E Gm F F♯ [A D C D ] x3  C: D C G G",
        a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(location, a.getCurrentChordSectionLocation());

    logger.d(
        "section  replace  measure    append  measure  replace section content");
    logger.d("repeat  replace  measure    append  measure  replace repeat");
    logger.d("phrase  replace  measure    append  measure  replace phrase");
    logger.d("measure  replace  measure    append  measure  replace");
    logger.d("section  delete  measure  yes  append  measure  delete section");
    logger.d("repeat  delete  measure  yes  append  measure  delete repeat");
    logger.d("phrase  delete  measure  yes  append  measure  delete phrase");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation.parseString("v:0:2");
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.delete);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(a.deleteCurrentSelection(), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: D E F♯  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(location, a.getCurrentChordSectionLocation());

    logger.d("measure  delete  measure  yes  append  measure  delete measure");
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation.parseString("v:0:2");
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.delete);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(a.deleteCurrentSelection(), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: D E F♯  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(location, a.getCurrentChordSectionLocation());
    a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# c: D C G G",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");
    logger.d(a.toMarkup());
    location = ChordSectionLocation.parseString("v:0:2");
    a.setCurrentChordSectionLocation(location);
    a.setCurrentMeasureEditType(MeasureEditType.delete);
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a
            .findMeasureNodeByLocation(a.getCurrentChordSectionLocation())
            .toString() +
        " " +
        a.getCurrentMeasureEditType().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    newMeasure = Measure.parseString("F", beatsPerBar);
    expect(a.editMeasureNode(newMeasure), isTrue);
    logger.d(a.toMarkup());
    expect("I: A B C D  V: D E F♯  C: D C G G", a.toMarkup().trim());
    logger.d(a.getCurrentChordSectionLocation().toString() +
        " " +
        a.getCurrentChordSectionLocationMeasureNode().toString());
    expect(location, a.getCurrentChordSectionLocation());
  });
}
