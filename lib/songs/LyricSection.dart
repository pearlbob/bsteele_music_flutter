

import 'LegacyDrumSection.dart';
import 'LyricsLine.dart';
import 'SectionVersion.dart';

/// A sectionVersion of a song that carries the lyrics, any special drum sectionVersion,
/// and the chord changes on a measure basis
/// with ultimately beat resolution.
  class LyricSection {

  /**
   * Get the lyric sectionVersion's identifier
   *
   * @return the identifier
   */
     SectionVersion getSectionVersion() {
  return sectionVersion;
  }

  /**
   * Get the lyric sectionVersion's identifier
   *
   * @param sectionVersion the identifier
   */
     void setSectionVersion(SectionVersion sectionVersion) {
  this.sectionVersion = sectionVersion;
  }


  /**
   * The sectionVersion's measures.
   *
   * @return the sectionVersion's measures
   */
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

  /**
   * Get the song's default drum sectionVersion.
   * The sectionVersion will be played through all of its measures
   * and then repeated as required for the sectionVersion's duration.
   * When done, the drums will default back to the song's default drum sectionVersion.
   * @return the drum sectionVersion
   */
     LegacyDrumSection getDrumSection() {
  return drumSection;
  }

  /**
   * Set the song's default drum sectionVersion
   * @param drumSection the drum sectionVersion
   */
     void setDrumSection(LegacyDrumSection drumSection) {
  this.drumSection = drumSection;
  }

    SectionVersion sectionVersion;
    LegacyDrumSection drumSection = new LegacyDrumSection();
    List<LyricsLine> lyricsLines = new List();
}
