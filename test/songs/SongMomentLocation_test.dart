import 'dart:math';

import 'package:bsteele_music_flutter/Grid.dart';
import 'package:bsteele_music_flutter/GridCoordinate.dart';
import 'package:bsteele_music_flutter/appLogger.dart';
import 'package:bsteele_music_flutter/songs/ChordSectionLocation.dart';
import 'package:bsteele_music_flutter/songs/Section.dart';
import 'package:bsteele_music_flutter/songs/SectionVersion.dart';
import 'package:bsteele_music_flutter/songs/SongBase.dart';
import 'package:bsteele_music_flutter/songs/SongMoment.dart';
import 'package:bsteele_music_flutter/songs/SongMomentLocation.dart';
import 'package:bsteele_music_flutter/songs/key.dart';
import 'package:bsteele_music_flutter/util.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  Logger.level = Level.debug;

  test("parse ", () {
    SongMomentLocation loc;
    {
      loc = SongMomentLocation.parseString(null);
      expect(loc, isNull);

      loc = SongMomentLocation.parseString("V2:");
      expect(loc, isNull);
      loc = SongMomentLocation.parseString("V2:0");
      expect(loc, isNull);
      loc = SongMomentLocation.parseString("V2:0:1");
      expect(loc, isNull);
      loc = SongMomentLocation.parseString("V2:0:1");
      expect(loc, isNull);
      loc = SongMomentLocation.parseString("V2:0:1#0");
      expect(loc, isNull);
      loc = SongMomentLocation.parseString("V2:2:1#3");
      SongMomentLocation locExpected = SongMomentLocation(
          ChordSectionLocation(
              SectionVersion(Section.get(SectionEnum.verse), 2),
              phraseIndex: 2,
              measureIndex: 1),
          3);
      //System.out.println(locExpected);
      expect(loc, locExpected);
    }

    for (Section section in Section.values)
      for (int version = 0; version < 10; version++)
        for (int phraseIndex = 0; phraseIndex <= 3; phraseIndex++)
          for (int index = 1; index < 8; index++) {
            for (int instance = 1; instance < 4; instance++) {
              SongMomentLocation locExpected = new SongMomentLocation(
                  new ChordSectionLocation(new SectionVersion(section, version),
                      phraseIndex: phraseIndex, measureIndex: index),
                  instance);
              MarkedString markedString = new MarkedString(section.toString() +
                  (version > 0 ? version.toString() : "") +
                  ":" +
                  phraseIndex.toString() +
                  ":" +
                  index.toString() +
                  "#" +
                  instance.toString());

              logger.d(markedString.toString());
              loc = SongMomentLocation.parse(markedString);

              expect(loc, isNotNull);
              expect(loc, locExpected);
            }
          }
  });

  test("grid ", () {
    SongBase _a = SongBase.createSongBase(
        "A",
        "bob",
        "bsteele.com",
        Key.getDefault(),
        100,
        4,
        4,
        "i: A B C D V: D E F F# [ D C B A ]x2 c: D C G G A B",
        "i:\nv: bob, bob, bob berand\nc: sing chorus here \no: last line of outro");

    Grid<SongMoment> grid = Grid();
    int maxCol = 0;
    for (SongMoment songMoment in _a.songMoments) {
      GridCoordinate momentGridCoordinate =
          _a.getMomentGridCoordinate(songMoment);
      logger.d(
          'add ${songMoment.toString()}  at (${momentGridCoordinate.row},${momentGridCoordinate.col})');
      grid.set(momentGridCoordinate.row, momentGridCoordinate.col, songMoment);
      maxCol = max(maxCol, momentGridCoordinate.col);
    }
    //  fill the rows to a common maximum length
    for (int row = 0; row < grid.getRowCount(); row++) {
      if (grid.getRow(row).length < maxCol)
        grid.set(row, maxCol, null);
    }
    for (int row = 0; row < grid.getRowCount(); row++) {
      logger.i('$row:');
      for (int col = 0; col < grid.rowLength(row); col++) {
        SongMoment songMoment = grid.get(row, col);
        String s = (songMoment == null ? 'null' : songMoment.toString());
        logger.i('\t($row,$col): $s');
      }
    }
  });
}
