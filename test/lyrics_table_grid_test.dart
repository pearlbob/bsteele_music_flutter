import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/key.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_base.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  Logger.level = Level.info;

  test('test lyrics to moment and back', () {
    //  Create the song
    Song a = Song(
        title: 'After Midnight',
        artist: 'Eric Clapton',
        copyright: 'BMG',
        key: Key.D,
        beatsPerMinute: 110,
        beatsPerBar: 4,
        unitsPerMeasure: 4,
        chords: '''I:
D FG D D x2
V:
D FG D D x2
D G G A
O:
D FG D D x3''',
        rawLyrics: '''I: (instrumental)

V:
After midnight
We gonna let it all hang down
After midnight
We gonna chugalug and shout
Gonna stimulate some action
We gonna get some satisfaction
We gonna find out what it is all about
V: After midnight
We gonna let it all hang down
After midnight
We gonna shake your tambourine
After midnight
Soul gonna be peaches & cream
Gonna cause talk and suspicion
We gonna give an exhibition
We gonna find out what it is all about
V: (instrumental)
V: After midnight
We gonna let it all hang down
After midnight
We gonna shake your tambourine
After midnight
Soul gonna be peaches & cream
Gonna cause talk and suspicion
We gonna give an exhibition
We gonna find out what it is all about
O: After midnight
We gonna let it all hang down
After midnight
We gonna let it all hang down
After midnight
We gonna let it all hang down
After midnight
We gonna let it all hang down
''');

    UserDisplayStyle userDisplayStyle = .both;
    var lyricsTable = LyricsTable();
    // var items =
    lyricsTable.lyricsTableItems(a);

    var nodeGrid = a.toDisplayGrid(userDisplayStyle);

    for (var songMoment in a.songMoments) {
      var gridRow = lyricsTable.songMomentNumberToGridRow(songMoment.momentNumber);
      var momentNumber = lyricsTable.gridRowToMomentNumber(gridRow);
      var nodeRow = nodeGrid.getRow(gridRow);
      // var displayRow = nodeGrid.getRow(gridRow);
      // for (var cell in displayRow ?? []) {
      //   if ( cell is Measure ){
      //
      //
      //   logger.i('display cell: $cell');
      //   }
      // }

      logger.i('$songMoment:  ${songMoment.lyricSection.index}'
          ', gridRow: $gridRow'
          ', nodeRow: $nodeRow'
          ', momentNumber: $momentNumber');
    }
  });
}
