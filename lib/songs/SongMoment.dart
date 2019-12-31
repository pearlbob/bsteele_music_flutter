import 'ChordSection.dart';
import 'ChordSectionLocation.dart';
import 'LyricSection.dart';
import 'Measure.dart';
import 'MeasureNode.dart';
import 'Phrase.dart';

class SongMoment implements Comparable<SongMoment> {
  SongMoment(
      this.momentNumber,
      this.beatNumber,
      this.sectionBeatNumber,
      this.lyricSection,
      this.chordSection,
      this.phraseIndex,
      this.phrase,
      this.measureIndex,
      this.measure,
      this.repeat,
      this.repeatCycleBeats,
      this.repeatMax,
      this.sectionCount);

  int getMomentNumber() {
    return momentNumber;
  }

  int getBeatNumber() {
    return beatNumber;
  }

  int getSectionBeatNumber() {
    return sectionBeatNumber;
  }

  LyricSection getLyricSection() {
    return lyricSection;
  }

  ChordSection getChordSection() {
    return chordSection;
  }

  @deprecated
  MeasureNode getPhrase() {
    return phrase;
  }

  int getPhraseIndex() {
    return phraseIndex;
  }

  int getMeasureIndex() {
    return measureIndex;
  }

  Measure getMeasure() {
    return measure;
  }

  int getRepeat() {
    return repeat;
  }

  int getRepeatCycleBeats() {
    return repeatCycleBeats;
  }

  int getRepeatMax() {
    return repeatMax;
  }

  int getSectionCount() {
    return sectionCount;
  }

  @override
  int compareTo(SongMoment o) {
    if (momentNumber == o.momentNumber) return 0;
    return momentNumber < o.momentNumber ? -1 : 1;
  }

  ChordSectionLocation getChordSectionLocation() {
    if (chordSectionLocation == null)
      chordSectionLocation = new ChordSectionLocation(
          chordSection.getSectionVersion(),
          phraseIndex: phraseIndex,
          measureIndex: measureIndex);
    return chordSectionLocation;
  }

  @override
  String toString() {
    return momentNumber.toString() +
        ": " +
        getChordSectionLocation().toString() +
        "#" +
        sectionCount.toString() +
        " " +
        measure.toMarkup() +
        " beat " +
        getBeatNumber().toString() +
        (repeatMax > 1
            ? " " + repeat.toString() + "/" + repeatMax.toString()
            : "");
  }

  ChordSectionLocation chordSectionLocation;

  final int momentNumber;
  final int
      beatNumber; //  total beat count from start of song to the start of the moment
  final int
      sectionBeatNumber; //  total beat count from start of the current section to the start of the moment

  final int repeat; //  current iteration from 0 to repeatMax - 1
  final int repeatMax;
  final int repeatCycleBeats; //  number of beats in one cycle of the repeat

  final LyricSection lyricSection;
  final ChordSection chordSection;
  final int phraseIndex;
  final Phrase phrase;
  final int measureIndex;
  final Measure measure;
  final int sectionCount;
}
