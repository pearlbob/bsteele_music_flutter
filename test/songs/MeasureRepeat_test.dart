import 'package:bsteele_music_flutter/GridCoordinate.dart';
import 'package:bsteele_music_flutter/songs/ChordSection.dart';
import 'package:bsteele_music_flutter/songs/ChordSectionLocation.dart';
import 'package:bsteele_music_flutter/songs/MeasureRepeat.dart';
import 'package:bsteele_music_flutter/songs/Phrase.dart';
import 'package:bsteele_music_flutter/songs/SongBase.dart';
import 'package:bsteele_music_flutter/songs/key.dart';
import 'package:bsteele_music_flutter/util.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  Logger.level = Level.warning;
  Logger logger = Logger();

  test("parseMarkup", () {
    MeasureRepeat measureRepeat;

    try {
      //  bad input means this is not a repeat
      measureRepeat =
          MeasureRepeat.parseString("[A B C D [ x2 E F", 0, 4, null);
      fail("bad input was parsed");
    } catch (e) {
      //  expected
    }

    String s;

    s = "A B C D |\n E F G Gb x2 ";
    MarkedString markedString = new MarkedString(s);
    MeasureRepeat refRepeat = MeasureRepeat.parse(markedString, 0, 4, null);
    expect(refRepeat, isNotNull);
    expect("[A B C D, E F G G♭ ] x2 ", refRepeat.toMarkup());
    expect(0, markedString.available());

    s = "[A B C D ] x2 ";
    markedString = new MarkedString(s);
    refRepeat = MeasureRepeat.parse(markedString, 0, 4, null);
    expect(refRepeat, isNotNull);
    expect(s, refRepeat.toMarkup());
    expect(0, markedString.available());

    s = "[A B C D ] x2 E F";
    measureRepeat = MeasureRepeat.parseString(s, 0, 4, null);
    expect(measureRepeat, isNotNull);
    expect(s, startsWith(measureRepeat.toMarkup()));
    expect(refRepeat, measureRepeat);

    s = "   [   A B   C D ]\nx2 Eb Fmaj7";
    measureRepeat = MeasureRepeat.parseString(s, 0, 4, null);
    expect(measureRepeat, isNotNull);
    expect(refRepeat, measureRepeat);

    s = "A B C D x2 Eb Fmaj7";
    measureRepeat = MeasureRepeat.parseString(s, 0, 4, null);
    expect(measureRepeat, isNotNull);
    expect(refRepeat, measureRepeat);

    //  test without brackets
    measureRepeat = MeasureRepeat.parseString("   A B C D  x2 E F", 0, 4, null);
    expect(measureRepeat, isNotNull);
    expect(refRepeat, measureRepeat);

    //  test with comment
    refRepeat = MeasureRepeat.parseString("   A B(yo)C D  x2 E F", 0, 4, null);
    expect(refRepeat, isNotNull);
    expect("[A B (yo) C D ] x2 ", refRepeat.toMarkup());

    measureRepeat =
        MeasureRepeat.parseString("   A B (yo)|\nC D  x2 E F", 0, 4, null);
    expect(measureRepeat, isNotNull);
    expect("[A B (yo) C D ] x2 ", measureRepeat.toMarkup());
    expect(refRepeat, measureRepeat);

    measureRepeat =
        MeasureRepeat.parseString(" [   A B (yo)|\nC D]x2 E F", 0, 4, null);
    expect(measureRepeat, isNotNull);
    expect("[A B (yo) C D ] x2 ", measureRepeat.toMarkup());
    expect(refRepeat, measureRepeat);

    measureRepeat =
        MeasureRepeat.parseString(" [   A B (yo)   C D]x2 E F", 0, 4, null);
    expect(measureRepeat, isNotNull);
    expect("[A B (yo) C D ] x2 ", measureRepeat.toMarkup());
    expect(refRepeat, measureRepeat);
  });

  test("testMultilineInput", () {
    MeasureRepeat measureRepeat;

    ChordSection chordSection = null;


    chordSection = ChordSection.parseString(
        "v3: A B C D | \n E F G G# | x2   \n"
        , 4);

    expect(chordSection, isNotNull);
    Phrase phrase = chordSection.getPhrase(0);
    expect(phrase is MeasureRepeat, isTrue);
    measureRepeat = phrase as MeasureRepeat;
    logger.d(measureRepeat.toMarkup());
    ChordSectionLocation loc = new ChordSectionLocation(
        chordSection.sectionVersion, phraseIndex: 0);
    logger.d(loc.toString());
    expect("V3:0", loc.toString());

    chordSection = ChordSection.parseString("v3:A B C D|\nE F G G#|x2\n", 4);

    expect(chordSection, isNotNull);
    phrase = chordSection.getPhrase(0);
    expect(phrase is MeasureRepeat, isTrue);
    measureRepeat = phrase as MeasureRepeat;
    logger.d(measureRepeat.toMarkup());
    loc = new ChordSectionLocation(chordSection.sectionVersion, phraseIndex: 0);
    logger.d(loc.toString());
    expect("V3:0", loc.toString());
  });

  test("testGridMapping", () {
    int beatsPerBar = 4;
    SongBase a;

    a = SongBaseTest.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        beatsPerBar,
        4,
        "V: [G Bm F♯m G, GBm ] x3",
        "v: bob, bob, bob berand\n");
    a.debugSongMoments();

    try {
      ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
      ChordSection chordSection = a.findChordSection(cs.sectionVersion);
      expect(chordSection, isNotNull);
      Phrase phrase = chordSection.getPhrase(0);
      assertTrue(phrase.isRepeat());

      MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
      expect(5, measureRepeat.size());

      Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
      MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(0, 1));
      expect(measureNode, isNotNull);
      expect(Measure.parseString("G", a.getBeatsPerBar()), measureNode);

      measureNode = a.findMeasureNode(new GridCoordinate(0, 2));
      expect(measureNode, isNotNull);
      expect(Measure.parseString("Bm", a.getBeatsPerBar()), measureNode);

      measureNode = a.findMeasureNode(new GridCoordinate(0, 3));
      expect(measureNode, isNotNull);
      expect(Measure.parseString("F♯m", a.getBeatsPerBar()), measureNode);

      measureNode = a.findMeasureNode(new GridCoordinate(0, 4));
      expect(measureNode, isNotNull);
      expect(Measure.parseString("G", a.getBeatsPerBar()), measureNode);

      measureNode = a.findMeasureNode(new GridCoordinate(1, 1));
      expect(measureNode, isNotNull);
      expect(Measure.parseString("GBm", a.getBeatsPerBar()), measureNode);

      measureNode = a.findMeasureNode(new GridCoordinate(1, 2));
      assertNull(measureNode);
      measureNode = a.findMeasureNode(new GridCoordinate(1, 3));
      assertNull(measureNode);
      measureNode = a.findMeasureNode(new GridCoordinate(1, 4));
      assertNull(measureNode);


      ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(
          new GridCoordinate(1, 4 + 1));
      assertNotNull(chordSectionLocation);
      expect(ChordSectionLocation.Marker.repeatLowerRight,
          chordSectionLocation.getMarker());
      chordSectionLocation =
          a.getChordSectionLocation(new GridCoordinate(1, 4 + 1 + 1));
      assertNotNull(chordSectionLocation);
      expect(
          ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
      measureNode = a.findMeasureNode(chordSectionLocation);
      expect(measureNode, isNotNull);
      assertTrue(measureNode.isRepeat());
    }
    catch
    (
    ParseException e) {
    e.printStackTrace();
    fail();
    }

    a = SongBaseTest.createSongBase("A", "bob", "bsteele.com", Key.getDefault(),
    100, beatsPerBar, 4,
    "v: [A B , Ab Bb Eb, D C G G# ] x3 T: A",
    "i:\nv: bob, bob, bob berand\nt: last line \n");
    a.debugSongMoments();

    try {
    ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
    ChordSection chordSection = a.findChordSection(cs.sectionVersion);
    expect(chordSection,isNotNull);
    Phrase phrase = chordSection.getPhrase(0);
    assertTrue(phrase.isRepeat());

    MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
    expect(9, measureRepeat.size());

    Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
    MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(0, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(0, 2));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("B", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(0, 3));
    assertNull(measureNode);
    measureNode = a.findMeasureNode(new GridCoordinate(0, 4));
    assertNull(measureNode);


    measureNode = a.findMeasureNode(new GridCoordinate(1, 3));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("Eb", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(1, 4));
    assertNull(measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(1, 4));
    assertNull(measureNode);


    measureNode = a.findMeasureNode(new GridCoordinate(2, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("G#", a.getBeatsPerBar()), measureNode);

    ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 4+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.repeatLowerRight, chordSectionLocation.getMarker());
    chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 4+1+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
    measureNode = a.findMeasureNode(chordSectionLocation);
    expect(measureNode,isNotNull);
    assertTrue(measureNode.isRepeat());
    } catch (ParseException e) {
    e.printStackTrace();
    fail();
    }


    a = SongBaseTest.createSongBase("A", "bob", "bsteele.com", Key.getDefault(),
    100, beatsPerBar, 4,
    "v: E F F# G [A B C D Ab Bb Eb Db D C G Gb D C G# A#] x3 T: A",
    //         1 2 3  4  1 2 3 4 5  6  7  8  1 2 3 4  5 6 7  8
    //                                       9 101112 131415 16
    "i:\nv: bob, bob, bob berand\nt: last line \n");
    a.debugSongMoments();

    try {
    ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
    ChordSection chordSection = a.findChordSection(cs.sectionVersion);
    expect(chordSection,isNotNull);
    Phrase phrase = chordSection.getPhrase(1);
    assertTrue(phrase.isRepeat());

    MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
    expect(16, measureRepeat.size());

    Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
    MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(1, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("D", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("Gb", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 7));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("G#", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 8));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A#", a.getBeatsPerBar()), measureNode);

    ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 8+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.repeatLowerRight, chordSectionLocation.getMarker());
    chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 8+1+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
    measureNode = a.findMeasureNode(chordSectionLocation);
    expect(measureNode,isNotNull);
    assertTrue(measureNode.isRepeat());
    } catch (ParseException e) {
    e.printStackTrace();
    fail();
    }

    a = SongBaseTest.createSongBase("A", "bob", "bsteele.com", Key.getDefault(),
    100, beatsPerBar, 4,
    "v: A B C D x3 T: A",
    "i:\nv: bob, bob, bob berand\nt: last line \n");
    a.debugSongMoments();

    try {
    ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
    ChordSection chordSection = a.findChordSection(cs.sectionVersion);
    expect(chordSection,isNotNull);
    Phrase phrase = chordSection.getPhrase(0);
    assertTrue(phrase.isRepeat());

    MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
    expect(4, measureRepeat.size());

    Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
    MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(0, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(0, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("D", a.getBeatsPerBar()), measureNode);

    ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(0, 4+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
    measureNode = a.findMeasureNode(chordSectionLocation);
    expect(measureNode,isNotNull);
    assertTrue(measureNode.isRepeat());
    } catch (ParseException e) {
    e.printStackTrace();
    fail();
    }

    a = SongBaseTest.createSongBase("A", "bob", "bsteele.com", Key.getDefault(),
    100, beatsPerBar, 4,
    "v: [A B C D] x3 T: A",
    "i:\nv: bob, bob, bob berand\nt: last line \n");
    a.debugSongMoments();

    try {
    ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
    ChordSection chordSection = a.findChordSection(cs.sectionVersion);
    expect(chordSection,isNotNull);
    Phrase phrase = chordSection.getPhrase(0);
    assertTrue(phrase.isRepeat());

    MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
    expect(4, measureRepeat.size());

    Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
    MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(0, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(0, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("D", a.getBeatsPerBar()), measureNode);

    ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(0, 4+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
    measureNode = a.findMeasureNode(chordSectionLocation);
    expect(measureNode,isNotNull);
    assertTrue(measureNode.isRepeat());
    } catch (ParseException e) {
    e.printStackTrace();
    fail();
    }

    a = SongBaseTest.createSongBase("A", "bob", "bsteele.com", Key.getDefault(),
    100, beatsPerBar, 4,
    "v: [A B C D, Ab Bb Eb Db, D C G G# ] x3 T: A",
    "i:\nv: bob, bob, bob berand\nt: last line \n");
    a.debugSongMoments();

    try {
    ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
    ChordSection chordSection = a.findChordSection(cs.sectionVersion);
    expect(chordSection,isNotNull);
    Phrase phrase = chordSection.getPhrase(0);
    assertTrue(phrase.isRepeat());

    MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
    expect(12, measureRepeat.size());

    Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
    MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(0, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(0, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("D", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(1, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("Db", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("G#", a.getBeatsPerBar()), measureNode);

    ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 4+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.repeatLowerRight, chordSectionLocation.getMarker());
    chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 4+1+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
    measureNode = a.findMeasureNode(chordSectionLocation);
    expect(measureNode,isNotNull);
    assertTrue(measureNode.isRepeat());
    } catch (ParseException e) {
    e.printStackTrace();
    fail();
    }


    a = SongBaseTest.createSongBase("A", "bob", "bsteele.com", Key.getDefault(),
    100, beatsPerBar, 4,
    "v: [A B C D, Ab Bb Eb Db, D C G# ] x3 T: A",
    "i:\nv: bob, bob, bob berand\nt: last line \n");
    a.debugSongMoments();

    try {
    ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
    ChordSection chordSection = a.findChordSection(cs.sectionVersion);
    expect(chordSection,isNotNull);
    Phrase phrase = chordSection.getPhrase(0);
    assertTrue(phrase.isRepeat());

    MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
    expect(11, measureRepeat.size());

    Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
    MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(0, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(0, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("D", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(1, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("Db", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 3));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("G#", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 4));
    assertNull(measureNode);

    ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 4+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.repeatLowerRight, chordSectionLocation.getMarker());
    chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 4+1+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
    measureNode = a.findMeasureNode(chordSectionLocation);
    expect(measureNode,isNotNull);
    assertTrue(measureNode.isRepeat());
    } catch (ParseException e) {
    e.printStackTrace();
    fail();
    }

    a = SongBaseTest.createSongBase("A", "bob", "bsteele.com", Key.getDefault(),
    100, beatsPerBar, 4,
    "v: [A B C D, Ab Bb Eb Db, D C G G# ] x3 E F F# G T: A",
    "i:\nv: bob, bob, bob berand\nt: last line \n");
    a.debugSongMoments();

    try {
    ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
    ChordSection chordSection = a.findChordSection(cs.sectionVersion);
    expect(chordSection,isNotNull);
    Phrase phrase = chordSection.getPhrase(0);
    assertTrue(phrase.isRepeat());

    MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
    expect(12, measureRepeat.size());

    Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
    MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(0, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A", a.getBeatsPerBar()), measureNode);
    measureNode = a.findMeasureNode(new GridCoordinate(1, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("Db", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(0, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("D", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(1, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("Db", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("G#", a.getBeatsPerBar()), measureNode);
    ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 4+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.repeatLowerRight, chordSectionLocation.getMarker());
    chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(2, 4+1+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
    measureNode = a.findMeasureNode(chordSectionLocation);
    expect(measureNode,isNotNull);
    assertTrue(measureNode.isRepeat());
    } catch (ParseException e) {
    e.printStackTrace();
    fail();
    }


    a = SongBaseTest.createSongBase("A", "bob", "bsteele.com", Key.getDefault(),
    100, beatsPerBar, 4,
    "v: E F F# Gb [A B C D, Ab Bb Eb Db, D C G G# ] x3 T: A",
    "i:\nv: bob, bob, bob berand\nt: last line \n");
    a.debugSongMoments();

    ChordSection cs = ChordSection.parseString("v:", a.getBeatsPerBar());
    ChordSection chordSection = a.findChordSection(cs.sectionVersion);
    expect(chordSection,isNotNull);
    Phrase phrase = chordSection.getPhrase(1);
    assertTrue(phrase.isRepeat());

    MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
    expect(12, measureRepeat.size());

    Grid<ChordSectionLocation> grid = a.getChordSectionLocationGrid();
    MeasureNode measureNode = a.findMeasureNode(new GridCoordinate(1, 1));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("A", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(0, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("Gb", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(1, 3));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("C", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(2, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("Db", a.getBeatsPerBar()), measureNode);

    measureNode = a.findMeasureNode(new GridCoordinate(3, 4));
    expect(measureNode,isNotNull);
    expect(Measure.parseString("G#", a.getBeatsPerBar()), measureNode);

    ChordSectionLocation chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(3, 4+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.repeatLowerRight, chordSectionLocation.getMarker());
    chordSectionLocation = a.getChordSectionLocation(new GridCoordinate(3, 4+1+1));
    assertNotNull(chordSectionLocation);
    expect(ChordSectionLocation.Marker.none, chordSectionLocation.getMarker());
    measureNode = a.findMeasureNode(chordSectionLocation);
    expect(measureNode,isNotNull);
    assertTrue(measureNode.isRepeat
    (
    )
    );

  });
}