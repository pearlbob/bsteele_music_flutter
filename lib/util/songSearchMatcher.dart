import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';

class SongSearchMatcher {
  SongSearchMatcher(String? search)
      : _searchRegex = RegExp((search ?? '').trim().replaceAll("[^\\w\\s']+", ''), caseSensitive: false);

  bool performanceMatchesOrEmptySearch(SongPerformance songPerformance, {year = false}) {
    if (isEmpty) {
      return true;
    }
    if (_searchRegex.hasMatch(songPerformance.singer)) {
      return true;
    }
    var song = songPerformance.song;
    if (song == null) {
      return false;
    }
    return matches(song, year: year);
  }

  bool matchesOrEmptySearch(Song song, {year = false}) {
    return isEmpty || matches(song, year: year);
  }

  bool matches(Song song, {year = false}) {
    return isNotEmpty &&
        (_searchRegex.hasMatch(song.getTitle()) ||
            _searchRegex.hasMatch(song.getArtist()) ||
            (song.coverArtist.isNotEmpty && _searchRegex.hasMatch(song.coverArtist)) ||
            (year && _searchRegex.hasMatch(song.getCopyrightYear().toString())) ||
            _searchRegex.hasMatch(song.songId.toUnderScorelessString()) //  removes contractions
        );
  }

  String get pattern => _searchRegex.pattern;

  bool get isEmpty => _searchRegex.pattern.isEmpty;

  bool get isNotEmpty => _searchRegex.pattern.isNotEmpty;

  final RegExp _searchRegex;
}
