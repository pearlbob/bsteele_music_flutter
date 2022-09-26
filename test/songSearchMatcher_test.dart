import 'package:bsteeleMusicLib/songs/key.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/util/songSearchMatcher.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  Logger.level = Level.info;

  test('test SongSearchMatcher', () {
    SongSearchMatcher songSearchMatcher = SongSearchMatcher('s');
    var song = Song.createSong('A blue tune', 'bob', 'copyright nobody', Key.getDefault(), 106, 4, 4, 'bob',
        'v: G C G G, C C G G, D C G D c: G C G G, C C G G, D C G D', 'v: bob, bob, bob berand');
    song.coverArtist = 'Barbara';
    expect(songSearchMatcher.matchesSong(song), false);
    songSearchMatcher = SongSearchMatcher('n');
    expect(songSearchMatcher.matchesSong(song), true);
    songSearchMatcher = SongSearchMatcher('ue tun');
    expect(songSearchMatcher.matchesSong(song), true);
    songSearchMatcher = SongSearchMatcher('blues tun');
    expect(songSearchMatcher.matchesSong(song), false);
    songSearchMatcher = SongSearchMatcher('blue tun');
    expect(songSearchMatcher.matchesSong(song), true);
    songSearchMatcher = SongSearchMatcher('  bob  ');
    expect(songSearchMatcher.matchesSong(song), true);
    songSearchMatcher = SongSearchMatcher('barb');
    expect(songSearchMatcher.matchesSong(song), true);
  });
}
