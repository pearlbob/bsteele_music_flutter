import 'package:bsteeleMusicLib/songs/song.dart';

class SongSearchMatcher {
  SongSearchMatcher(String? search)
      : _searchRegex = RegExp((search ?? '').trim().replaceAll("[^\\w\\s']+", ''), caseSensitive: false);

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
