import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_id.dart';
import 'package:bsteele_music_lib/songs/song_performance.dart';
import 'package:bsteele_music_flutter/screens/drum_screen.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';

abstract class PlayListSearchMatcher {
  bool matches(PlayListItem item, {year = false});

  set search(final String? search) {
    var s = (search ?? '').trim().replaceAll("[^\\w\\s']+", '');
    //  a tiny attempt to defend against a bad regex
    if (s.endsWith('\\')) {
      s = '$s ';
    }
    try {
      _searchRegex = RegExp(s, caseSensitive: false);
    } catch (e) {
      _searchRegex = RegExp(' ', caseSensitive: false); //  fixme: what should happen here?
    }
  }

  String? get pattern => _searchRegex?.pattern;

  bool get isEmpty => _searchRegex == null || _searchRegex!.pattern.isEmpty;

  bool get isNotEmpty => _searchRegex != null && _searchRegex!.pattern.isNotEmpty;

  RegExp? _searchRegex;
}

class SongPlayListSearchMatcher extends PlayListSearchMatcher {
  SongPlayListSearchMatcher({final String? search}) {
    this.search = search;
  }

  @override
  bool matches(PlayListItem item, {year = false}) {
    if (item is SongPlayListItem) {
      if (item.songPerformance != null) {
        return _performanceMatchesOrEmptySearch(item.songPerformance!, year: year);
      }
      return _matchesOrEmptySearch(item.song, year: year);
    }
    return false;
  }

  bool _performanceMatchesOrEmptySearch(SongPerformance songPerformance, {year = false}) {
    if (isEmpty) {
      return true;
    }
    if (_searchRegex!.hasMatch(songPerformance.singer)) {
      return true;
    }
    var song = songPerformance.song;
    if (song != null) {
      return _matchesSong(song, year: year);
    }
    //  try to match a song id without a song
    return _searchRegex!.hasMatch(SongId.asReadableString(songPerformance.songIdAsString));
  }

  bool _matchesOrEmptySearch(Song song, {year = false}) {
    return isEmpty || _matchesSong(song, year: year);
  }

  bool _matchesSong(Song song, {year = false}) {
    return isNotEmpty &&
        (_searchRegex!.hasMatch(song.title) ||
            _searchRegex!.hasMatch(song.artist) ||
            (song.coverArtist.isNotEmpty && _searchRegex!.hasMatch(song.coverArtist)) ||
            (year && _searchRegex!.hasMatch(song.getCopyrightYear().toString())) ||
            _searchRegex!.hasMatch(song.songId.toUnderScorelessString()) //  removes contractions
        );
  }
}

class DrumPlayListSearchMatcher extends PlayListSearchMatcher {
  @override
  bool matches(PlayListItem item, {year = false}) {
    return isEmpty || _searchRegex!.hasMatch((item as DrumPlayListItem).drumParts.name);
  }
}
