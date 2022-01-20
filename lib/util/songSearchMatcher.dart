import 'package:bsteeleMusicLib/songs/song.dart';

class SongSearchMatcher {
  SongSearchMatcher(String? search)
      : _searchRegex = RegExp((search ?? '').trim().replaceAll("[^\\w\\s']+", ''), caseSensitive: false);

  bool matches(Song song) {
    return _searchRegex.hasMatch(song.getTitle()) ||
        _searchRegex.hasMatch(song.getArtist()) ||
        _searchRegex.hasMatch(song.coverArtist) ||
        _searchRegex.hasMatch(song.songId.toUnderScorelessString() //  removes contractions
            );
  }

  String get pattern => _searchRegex.pattern;

  bool get isEmpty => _searchRegex.pattern.isEmpty;

  bool get isNotEmpty => _searchRegex.pattern.isNotEmpty;

  final RegExp _searchRegex;
}
