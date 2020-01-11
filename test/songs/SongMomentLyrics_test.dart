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
  Logger.level = Level.info;

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
      String lyrics = '';
      for (int i = 0; i < lines; i++) {
        lyrics = (lyrics.isEmpty
            ? 'v:\n$i ${lyricsData[i]}'
            : '$lyrics\n$i ${lyricsData[i]}');
      }
      logger.i('lines: $lines\n$lyrics');

      SongBase a = SongBase.createSongBase("A", "bob", "bsteele.com",
          Key.getDefault(), 100, 4, 4, "v: A B C D x4", lyrics);
      logger.d('lines: $lines');
      logger.d('lyrics: ${a.rawLyrics}');
      for (SongMoment songMoment in a.songMoments) {
        logger.d(songMoment.toString());
      }

      for (LyricSection lyricSection in a.getLyricSections()) {
        ChordSection chordSection =
            a.getChordSection(lyricSection.sectionVersion);
        int lines = 0;
        for (LyricsLine lyricsLine in lyricSection.lyricsLines) {
          lines++;
          logger.v('\t$lyricSection:$lines: "${lyricsLine.lyrics}"');
        }
        int rows = chordSection.chordRows;

        int minimumLinesPerRow = rows > 0 ? lines ~/ rows : 0;
        int rowsOfExtraLines = lines % rows;

        logger.i('$chordSection has $rows chord rows and $lines lines of lyrics'
            ' = $minimumLinesPerRow per + $rowsOfExtraLines rows with extra line');

        int lineIndex = 0;
        int extraLine = rowsOfExtraLines;
        for (int row = 0; row < rows; row++) {
          String rowLyrics = '';
          if (lineIndex < lyricSection.lyricsLines.length) {
            for (int i = 0; i < minimumLinesPerRow; i++)
              rowLyrics = (rowLyrics.length > 0 ? rowLyrics + '\n' : '') +
                  lyricSection.lyricsLines[lineIndex++].toString();
            if (extraLine > 0) {
              rowLyrics += (rowLyrics.length > 0 ? rowLyrics + '\n' : '') +
                  lyricSection.lyricsLines[lineIndex++].toString();
              extraLine--;
            }
          }
          logger.i('row $row:');
          logger.i('\t$rowLyrics');
        }
      }
    }
  });
}
