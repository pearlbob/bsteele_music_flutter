import 'package:bsteele_music_lib/songs/key.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/util/play_list_search_matcher.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';

void main() {
  Logger.level = Level.info;

  test('test SongSearchMatcher', () {
    PlayListSearchMatcher songSearchMatcher = SongPlayListSearchMatcher(search: 's');
    var song = Song(
        title: 'A blue tune',
        artist: 'bob',
        copyright: 'copyright nobody 2022',
        key: Key.getDefault(),
        beatsPerMinute: MusicConstants.defaultBpm,
        beatsPerBar: 4,
        unitsPerMeasure: 4,
        user: 'bob',
        chords: 'v: G C G G, C C G G, D C G D c: G C G G, C C G G, D C G D',
        rawLyrics: 'v: bob, bob, bob berand');

    song.coverArtist = 'Barbara';
    var item = SongPlayListItem.fromSong(song);
    songSearchMatcher = SongPlayListSearchMatcher(search: 's');
    expect(songSearchMatcher.matches(item), false);
    songSearchMatcher = SongPlayListSearchMatcher(search: 'n');
    expect(songSearchMatcher.matches(item), true);
    songSearchMatcher = SongPlayListSearchMatcher(search: 'ue tun');
    expect(songSearchMatcher.matches(item), true);
    songSearchMatcher = SongPlayListSearchMatcher(search: 'blues tun');
    expect(songSearchMatcher.matches(item), false);
    songSearchMatcher = SongPlayListSearchMatcher(search: 'blue tun');
    expect(songSearchMatcher.matches(item), true);
    songSearchMatcher = SongPlayListSearchMatcher(search: '  bob  ');
    expect(songSearchMatcher.matches(item), true);
    songSearchMatcher = SongPlayListSearchMatcher(search: 'barb');
    expect(songSearchMatcher.matches(item), true);

    songSearchMatcher.search = 's';
    expect(songSearchMatcher.matches(item), false);
    songSearchMatcher.search = 'n';
    expect(songSearchMatcher.matches(item), true);
    songSearchMatcher.search = 'ue tun';
    expect(songSearchMatcher.matches(item), true);
    songSearchMatcher.search = 'blues tun';
    expect(songSearchMatcher.matches(item), false);
    songSearchMatcher.search = 'blue tun';
    expect(songSearchMatcher.matches(item), true);
    songSearchMatcher.search = '  bob  ';
    expect(songSearchMatcher.matches(item), true);
    songSearchMatcher.search = 'barb';
    expect(songSearchMatcher.matches(item), true);
  });
}
