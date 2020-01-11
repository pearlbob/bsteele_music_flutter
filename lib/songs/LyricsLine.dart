/// A line of lyrics in a section of a song.
/// Holds the lyrics.

class LyricsLine implements Comparable<LyricsLine> {
  /// A convenience constructor to build a typical lyrics line.
  LyricsLine(this._lyrics) ;

  ///  The lyrics to be sung over this measure.
  void setLyrics(String lyrics) {
    _lyrics = (lyrics == null ? "" : lyrics);
  }

  @override
  int compareTo(LyricsLine other) {
    return _lyrics.compareTo(other._lyrics);
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LyricsLine && _lyrics == other._lyrics;
  }

  @override
  int get hashCode {
    return _lyrics.hashCode;
  }


  @override
  String toString() {
    return _lyrics;
  }

  String get lyrics=>  _lyrics;
  String _lyrics;
}
