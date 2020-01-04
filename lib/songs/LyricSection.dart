import 'package:quiver/collection.dart';
import 'package:quiver/core.dart';

import 'LegacyDrumSection.dart';
import 'LyricsLine.dart';
import 'SectionVersion.dart';

/// A sectionVersion of a song that carries the lyrics, any special drum sectionVersion,
/// and the chord changes on a measure basis
/// with ultimately beat resolution.
class LyricSection implements Comparable<LyricSection> {
  /// Get the lyric sectionVersion's identifier
  SectionVersion getSectionVersion() {
    return sectionVersion;
  }

  /// Get the lyric sectionVersion's identifier
  void setSectionVersion(SectionVersion sectionVersion) {
    this.sectionVersion = sectionVersion;
  }

  /// The sectionVersion's measures.
  List<LyricsLine> getLyricsLines() {
    return lyricsLines;
  }

  void setLyricsLines(List<LyricsLine> lyricsLines) {
    this.lyricsLines = lyricsLines;
  }

  void add(LyricsLine lyricsLine) {
    lyricsLines.add(lyricsLine);
  }

  @override
  String toString() {
    return sectionVersion.toString();
  }

  /// Get the song's default drum sectionVersion.
  /// The sectionVersion will be played through all of its measures
  /// and then repeated as required for the sectionVersion's duration.
  /// When done, the drums will default back to the song's default drum sectionVersion.

  LegacyDrumSection getDrumSection() {
    return drumSection;
  }

  ///Set the song's default drum sectionVersion
  void setDrumSection(LegacyDrumSection drumSection) {
    this.drumSection = drumSection;
  }

  /// Compares this object with the specified object for order.  Returns a
  /// negative integer, zero, or a positive integer as this object is less
  /// than, equal to, or greater than the specified object.
  @override
  int compareTo(LyricSection other) {
    int ret = sectionVersion.compareTo(other.sectionVersion);
    if (ret != 0) return ret;

    if (lyricsLines == null) {
      if (other.lyricsLines != null) return -1;
    } else {
      if (other.lyricsLines == null) return 1;
      if (lyricsLines.length != other.lyricsLines.length)
        return lyricsLines.length - other.lyricsLines.length;
      for (int i = 0; i < lyricsLines.length; i++) {
        ret =
            lyricsLines.elementAt(i).compareTo(other.lyricsLines.elementAt(i));
        if (ret != 0) return ret;
      }
    }
    ret = drumSection.compareTo(other.drumSection);
    if (ret != 0) return ret;
    ret = sectionVersion.compareTo(other.sectionVersion);
    if (ret != 0) return ret;

    if (!listsEqual(lyricsLines, other.lyricsLines)) {
      //  compare the lists
      if (lyricsLines == null) return other.lyricsLines == null ? 0 : 1;
      if (other.lyricsLines == null) return -1;
      if (lyricsLines.length != other.lyricsLines.length)
        return lyricsLines.length < other.lyricsLines.length ? -1 : 1;
      for (int i = 0; i < lyricsLines.length; i++) {
        int ret = lyricsLines[i].compareTo(other.lyricsLines[i]);
        if (ret != 0) return ret;
      }
    }
    return 0;
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    return other is LyricSection &&
        sectionVersion == other.sectionVersion &&
        drumSection == other.drumSection &&
        listsEqual(lyricsLines, other.lyricsLines);
  }

  @override
  int get hashCode {
    int ret = sectionVersion.hashCode;
    ret = ret * 13 + drumSection.hashCode;
    if ( lyricsLines!=null )
    ret = ret * 17 + hashObjects(lyricsLines);
    return ret;
  }

  SectionVersion sectionVersion;
  LegacyDrumSection drumSection = new LegacyDrumSection();
  List<LyricsLine> lyricsLines = new List();
}
