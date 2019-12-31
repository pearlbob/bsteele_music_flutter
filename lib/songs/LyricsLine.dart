/// A line of lyrics in a section of a song.
/// Holds the lyrics.

class LyricsLine {
  /// A convenience constructor to build a typical lyrics line.
  LyricsLine(String lyrics) {
    setLyrics(lyrics);
  }

  ///  The lyrics to be sung over this measure.

  String getLyrics() {
    return lyrics;
  }

  ///  The lyrics to be sung over this measure.
  void setLyrics(String lyrics) {
    this.lyrics = (lyrics == null ? "" : lyrics);
  }

  String lyrics;
}
