import 'package:bsteele_music_flutter/Grid.dart';
import 'package:bsteele_music_flutter/appLogger.dart';
import 'package:bsteele_music_flutter/songs/ChordSection.dart';
import 'package:bsteele_music_flutter/songs/LyricSection.dart';
import 'package:bsteele_music_flutter/songs/LyricsLine.dart';
import 'package:bsteele_music_flutter/songs/SongBase.dart';
import 'package:bsteele_music_flutter/songs/SongMoment.dart';
import 'package:bsteele_music_flutter/songs/key.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  Logger.level = Level.debug;

  test("test song moment lyrics distribution", () {
    List<String> lyricsData = [
      'bob, bob, bob berand',
      'please take my hand',
      'you got me rockn and rolln',
      'bob berand',
      'dude',
      '',
      'when and saw',
      'betty lew',
      "i don't know more",
    ];
    for (int lines = 0; lines < lyricsData.length; lines++) {
      //  Generate the lyrics lines for the given number of lines
      String lyrics = '';
      for (int i = 0; i < lines; i++) {
        lyrics = (lyrics.isEmpty
            ? 'v:\n$i ${lyricsData[i]}'
            : '$lyrics\n$i ${lyricsData[i]}');
      }
      logger.i('lines: $lines\n$lyrics');

      //  Create the song
      SongBase a = SongBase.createSongBase("A", "bob", "bsteele.com",
          Key.getDefault(), 100, 4, 4, "v: A B C D x4", lyrics);
      logger.d('lines: $lines');
      logger.d('lyrics: ${a.rawLyrics}');

      Grid<SongMoment> grid = a.songMomentGrid;
      int rows = grid.getRowCount();
      ChordSection chordSection;
      for (int r = 0; r < rows; r++) {
        List<SongMoment> row = grid.getRow(r);
        int cols = row.length;
        String rowLyrics;
        for (int c = 0; c < cols; c++) {
          SongMoment songMoment = grid.get(r, c);
          if (songMoment == null) continue;

          //  Change of section is a change in lyrics... typically.
          if (songMoment.chordSection != chordSection) {
            chordSection = songMoment.chordSection;
            rowLyrics = null;
          }

          //  All moments in the row have the same lyrics
          if (rowLyrics == null)
            rowLyrics = songMoment.lyrics;
          else
            expect(songMoment.lyrics, rowLyrics);
          logger.d('($r,$c) ${songMoment.toString()}: ${songMoment.lyrics}');
        }
      }
    }
  });
}
