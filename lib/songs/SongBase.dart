import 'dart:collection';
import 'dart:core';
import 'dart:math';

import 'package:quiver/collection.dart';
import 'package:quiver/core.dart';

import '../Grid.dart';
import '../GridCoordinate.dart';
import '../appLogger.dart';
import '../appOptions.dart';
import '../util.dart';
import 'Chord.dart';
import 'ChordDescriptor.dart';
import 'ChordSection.dart';
import 'ChordSectionLocation.dart';
import 'LyricSection.dart';
import 'LyricsLine.dart';
import 'Measure.dart';
import 'MeasureComment.dart';
import 'MeasureNode.dart';
import 'MeasureRepeat.dart';
import 'MeasureRepeatExtension.dart';
import 'MeasureRepeatMarker.dart';
import 'MusicConstants.dart';
import 'Phrase.dart';
import 'Section.dart';
import 'SectionVersion.dart';
import 'Song.dart';
import 'SongId.dart';
import 'SongMoment.dart';
import 'key.dart';
import 'scaleChord.dart';

enum UpperCaseState {
  initial,
  flatIsPossible,
  comment,
  normal,
}

/// A piece of music to be played according to the structure it contains.
///  The song base class has been separated from the song class to allow most of the song
///  mechanics to be tested in the shared code environment where debugging is easier.

class SongBase {
  ///  Not to be used externally
  SongBase() {
    setTitle("");
    setArtist("");
    setCoverArtist(null);
    copyright = "";
    setKey(Key.get(KeyEnum.C));
    unitsPerMeasure = 4;
    setRawLyrics("");
    setChords("");
    setBeatsPerMinute(100);
    setBeatsPerBar(4);
  }

  /// A convenience constructor used to enforce the minimum requirements for a song.
  /// <p>Note that this is the base class for a song object.
  /// The split from Song was done for testability reasons.
  /// It's much easier to test free of GWT.
  static SongBase createSongBase(
      String title,
      String artist,
      String copyright,
      Key key,
      int bpm,
      int beatsPerBar,
      int unitsPerMeasure,
      String chords,
      String lyricsToParse) {
    SongBase song = new SongBase();
    song.setTitle(title);
    song.setArtist(artist);
    song.setCopyright(copyright);
    song.setKey(key);
    song.setUnitsPerMeasure(unitsPerMeasure);
    song.setChords(chords);
    song.setRawLyrics(lyricsToParse);

    song.setBeatsPerMinute(bpm);
    song.setBeatsPerBar(beatsPerBar);

    return song;
  }

  /// Compute the song moments list given the song's current state.
  /// Moments are the temporal sequence of measures as the song is to be played.
  /// All repeats are expanded.  Measure node such as comments,
  /// repeat ends, repeat counts, section headers, etc. are ignored.
  void computeSongMoments() {
    if (songMoments.isNotEmpty) return;

    songMoments.clear();
    beatsToMoment.clear();

    if (lyricSections == null) return;

    logger.d("lyricSections size: " + lyricSections.length.toString());
    int sectionCount;
    HashMap<SectionVersion, int> sectionVersionCountMap = new HashMap();
    chordSectionBeats.clear();
    int beatNumber = 0;
    for (LyricSection lyricSection in lyricSections) {
      ChordSection chordSection = findChordSectionByLyricSection(lyricSection);
      if (chordSection == null) continue;

      //  compute section count
      SectionVersion sectionVersion = chordSection.sectionVersion;
      sectionCount = sectionVersionCountMap[sectionVersion];
      if (sectionCount == null) {
        sectionCount = 0;
      }
      sectionCount++;
      sectionVersionCountMap[sectionVersion] = sectionCount;

      List<Phrase> phrases = chordSection.phrases;
      if (phrases != null) {
        int phraseIndex = 0;
        int sectionVersionBeats = 0;
        for (Phrase phrase in phrases) {
          if (phrase.isRepeat()) {
            MeasureRepeat measureRepeat = phrase as MeasureRepeat;
            int limit = measureRepeat.repeats;
            for (int repeat = 0; repeat < limit; repeat++) {
              List<Measure> measures = measureRepeat.measures;
              if (measures != null) {
                int repeatCycleBeats = 0;
                for (Measure measure in measures) {
                  repeatCycleBeats += measure.beatCount;
                }
                int measureIndex = 0;
                for (Measure measure in measures) {
                  songMoments.add(new SongMoment(
                      songMoments.length,
                      //  size prior to add
                      beatNumber,
                      sectionVersionBeats,
                      lyricSection,
                      chordSection,
                      phraseIndex,
                      phrase,
                      measureIndex,
                      measure,
                      repeat,
                      repeatCycleBeats,
                      limit,
                      sectionCount));
                  measureIndex++;
                  beatNumber += measure.beatCount;
                  sectionVersionBeats += measure.beatCount;
                }
              }
            }
          } else {
            List<Measure> measures = phrase.measures;
            if (measures != null) {
              int measureIndex = 0;
              for (Measure measure in measures) {
                songMoments.add(new SongMoment(
                    songMoments.length,
                    //  size prior to add
                    beatNumber,
                    sectionVersionBeats,
                    lyricSection,
                    chordSection,
                    phraseIndex,
                    phrase,
                    measureIndex,
                    measure,
                    0,
                    0,
                    0,
                    sectionCount));
                measureIndex++;
                beatNumber += measure.beatCount;
                sectionVersionBeats += measure.beatCount;
              }
            }
          }
          phraseIndex++;
        }

        for (SectionVersion sv in matchingSectionVersions(sectionVersion)) {
          chordSectionBeats[sv] = sectionVersionBeats;
        }
      }
    }

    {
//  generate song moment grid coordinate map for play to display purposes
      songMomentGridCoordinateHashMap.clear();
      chordSectionRows.clear();

      LyricSection lastLyricSection;
      int row = 0;
      int baseChordRow = 0;
      int maxChordRow = 0;
      for (SongMoment songMoment in songMoments) {
        if (lastLyricSection != songMoment.getLyricSection()) {
          if (lastLyricSection != null) {
            int rows = maxChordRow - baseChordRow + 1;
            chordSectionRows[lastLyricSection.sectionVersion] = rows;
            row += rows;
          }
          lastLyricSection = songMoment.getLyricSection();
          GridCoordinate sectionGridCoordinate = getGridCoordinate(
              new ChordSectionLocation(lastLyricSection.sectionVersion));

          baseChordRow = sectionGridCoordinate.row;
          maxChordRow = baseChordRow;
        }

        //  use the change of chord section rows to trigger moment grid row change
        GridCoordinate gridCoordinate =
            getGridCoordinate(songMoment.getChordSectionLocation());
        maxChordRow = max(maxChordRow, gridCoordinate.row);

        GridCoordinate momentGridCoordinate = new GridCoordinate(
            row + (gridCoordinate.row - baseChordRow), gridCoordinate.col);
        logger
            .d(songMoment.toString() + ": " + momentGridCoordinate.toString());
        songMomentGridCoordinateHashMap[songMoment] = momentGridCoordinate;

        logger.d("moment: " +
            songMoment.getMomentNumber().toString() +
            ": " +
            songMoment.getChordSectionLocation().toString() +
            "#" +
            songMoment.getSectionCount().toString() +
            " m:" +
            momentGridCoordinate.toString() +
            " " +
            songMoment.getMeasure().toMarkup() +
            (songMoment.getRepeatMax() > 1
                ? " " +
                    (songMoment.getRepeat() + 1).toString() +
                    "/" +
                    songMoment.getRepeatMax().toString()
                : ""));
      }
      //  push the last one in
      if (lastLyricSection != null) {
        int rows = maxChordRow - baseChordRow + 1;
        chordSectionRows[lastLyricSection.sectionVersion] = rows;
      }
    }

    {
      //  install the beats to moment lookup entries
      int beat = 0;
      for (SongMoment songMoment in songMoments) {
        int limit = songMoment.getMeasure().beatCount;
        for (int b = 0; b < limit; b++) beatsToMoment[beat++] = songMoment;
      }
    }
  }

  GridCoordinate getMomentGridCoordinate(SongMoment songMoment) {
    computeSongMoments();
    return songMomentGridCoordinateHashMap[songMoment];
  }

  GridCoordinate getMomentGridCoordinateFromMomentNumber(int momentNumber) {
    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null) return null;
    return songMomentGridCoordinateHashMap[songMoment];
  }

  void debugSongMoments() {
    computeSongMoments();

    for (SongMoment songMoment in songMoments) {
      GridCoordinate momentGridCoordinate =
          getMomentGridCoordinateFromMomentNumber(songMoment.getMomentNumber());
      logger.d(songMoment.getMomentNumber().toString() +
          ": " +
          songMoment.getChordSectionLocation().toString() +
          "#" +
          songMoment.getSectionCount().toString() +
          " m:" +
          momentGridCoordinate.toString() +
          " " +
          songMoment.getMeasure().toMarkup() +
          (songMoment.getRepeatMax() > 1
              ? " " +
                  (songMoment.getRepeat() + 1).toString() +
                  "/" +
                  songMoment.repeatMax.toString()
              : ""));
    }
  }

  String songMomentMeasure(int momentNumber, Key key, int halfStepOffset) {
    computeSongMoments();
    if (momentNumber < 0 ||
        songMoments.isEmpty ||
        momentNumber > songMoments.length - 1) return "";
    return songMoments[momentNumber]
        .getMeasure()
        .transpose(key, halfStepOffset);
  }

  String songNextMomentMeasure(int momentNumber, Key key, int halfStepOffset) {
    computeSongMoments();
    if (momentNumber < -1 ||
        songMoments.isEmpty ||
        momentNumber > songMoments.length - 2) return "";
    return songMoments[momentNumber + 1]
        .getMeasure()
        .transpose(key, halfStepOffset);
  }

  String songMomentStatus(int beatNumber, int momentNumber) {
    computeSongMoments();
    if (songMoments.isEmpty) return "unknown";

    if (momentNumber < 0) {
//            beatNumber %= getBeatsPerBar();
//            if (beatNumber < 0)
//                beatNumber += getBeatsPerBar();
//            beatNumber++;
      return "count in " + (-momentNumber).toString();
    }

    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null) return "";

    Measure measure = songMoment.getMeasure();

    beatNumber %= measure.beatCount;
    if (beatNumber < 0) beatNumber += measure.beatCount;
    beatNumber++;

    String ret = songMoment.getChordSection().sectionVersion.toString() +
        (songMoment.getRepeatMax() > 1
            ? " " +
                (songMoment.getRepeat() + 1).toString() +
                "/" +
                songMoment.getRepeatMax().toString()
            : "");

    if (appOptions.isDebug())
      ret = songMoment.getMomentNumber().toString() +
          ": " +
          songMoment.getChordSectionLocation().toString() +
          "#" +
          songMoment.getSectionCount().toString() +
          " " +
          ret.toString() +
          " b: " +
          (beatNumber + songMoment.getBeatNumber()).toString() +
          " = " +
          (beatNumber + songMoment.getSectionBeatNumber()).toString() +
          "/" +
          getChordSectionBeats(
                  songMoment.getChordSectionLocation().sectionVersion)
              .toString() +
          " " +
          songMomentGridCoordinateHashMap[songMoment].toString();
    return ret;
  }

  /// Find the corrsesponding chord section for the given lyrics section
  ChordSection findChordSectionByLyricSection(LyricSection lyricSection) {
    if (lyricSection == null) return null;
    logger.d(
        "chordSectionMap size: " + getChordSectionMap().keys.length.toString());
    return getChordSectionMap()[lyricSection.sectionVersion];
  }

  /// Compute the duration and total beat count for the song.
  void computeDuration() {
    //  be lazy
    if (duration > 0) return;

    duration = 0;
    totalBeats = 0;

    List<SongMoment> moments = getSongMoments();
    if (beatsPerBar == 0 ||
        defaultBpm == 0 ||
        moments == null ||
        moments.isEmpty) return;

    for (SongMoment moment in moments) {
      totalBeats += moment.getMeasure().beatCount;
    }
    duration = totalBeats * 60.0 / defaultBpm;
  }

  /// Find the chord section for the given section version.
  ChordSection getChordSection(SectionVersion sectionVersion) {
    return getChordSectionMap()[sectionVersion];
  }

  ChordSection getChordSectionByLocation(
      ChordSectionLocation chordSectionLocation) {
    if (chordSectionLocation == null) return null;
    ChordSection ret =
        getChordSectionMap()[chordSectionLocation.sectionVersion];
    return ret;
  }

  String getUser() {
    return user;
  }

  void setUser(String user) {
    this.user = (user == null || user.length <= 0) ? defaultUser : user;
  }

  List<MeasureNode> getMeasureNodes() {
    //  lazy eval
    if (measureNodes == null) {
      try {
        parseChords(chords);
      } catch (e) {
        logger.w("unexpected: " + e.getMessage());
        return null;
      }
    }
    return measureNodes;
  }

  HashMap<SectionVersion, ChordSection> getChordSectionMap() {
    //  lazy eval
    if (chordSectionMap == null) {
      try {
        parseChords(chords);
      } catch (e) {
        logger.i("unexpected: " + e.getMessage().toString());
        return null;
      }
    }
    return chordSectionMap;
  }

  /// Try to promote lower case characters to uppercase when they appear to be musical chords
  static String entryToUppercase(String entry) {
    StringBuffer sb = StringBuffer();

    UpperCaseState state = UpperCaseState.initial;
    for (int i = 0; i < entry.length; i++) {
      String c = entry[i];

      //  map newlines!
      if (c == '\n') c = ',';

      switch (state) {
        case UpperCaseState.flatIsPossible:
          if (c == 'b') {
            state = UpperCaseState.initial;
            sb.write(c);
            break;
          }
          continue;
        //  fall through
        case UpperCaseState.initial:
          if ((c.codeUnitAt(0) >= 'A'.codeUnitAt(0) &&
                  c.codeUnitAt(0) <= 'G'.codeUnitAt(0)) ||
              (c.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
                  c.codeUnitAt(0) <= 'g'.codeUnitAt(0))) {
            if (i < entry.length - 1) {
              String sf = entry[i + 1];
              switch (sf) {
                case 'b':
                case '#':
                case MusicConstants.flatChar:
                case MusicConstants.sharpChar:
                  i++;
                  break;
                default:
                  sf = null;
                  break;
              }
              if (i < entry.length - 1) {
                String test = entry.substring(i + 1);
                bool isChordDescriptor = false;
                String cdString = "";
                for (ChordDescriptor chordDescriptor
                    in ChordDescriptor.values) {
                  cdString = chordDescriptor.toString();
                  if (cdString.length > 0 && test.startsWith(cdString)) {
                    isChordDescriptor = true;
                    break;
                  }
                }
                //  a chord descriptor makes a good partition to restart capitalization
                if (isChordDescriptor) {
                  sb.write(c.toUpperCase());
                  if (sf != null) sb.write(sf);
                  sb.write(cdString);
                  i += cdString.length;
                  break;
                } else {
                  sb.write(c.toUpperCase());
                  if (sf != null) {
                    sb.write(sf);
                  }
                  break;
                }
              } else {
                sb.write(c.toUpperCase());
                if (sf != null) {
                  sb.write(sf);
                }
                break;
              }
            }
            //  map the chord to upper case
            c = c.toUpperCase();
          } else if (c == 'x') {
            if (i < entry.length - 1) {
              String d = entry[i + 1];
              if (d.codeUnitAt(0) >= '1'.codeUnitAt(0) &&
                  d.codeUnitAt(0) <= '9'.codeUnitAt(0)) {
                sb.write(c);
                break; //  don't cap a repeat repetition declaration
              }
            }
            sb.write(c.toUpperCase()); //  x to X
            break;
          } else if (c == '(') {
            sb.write(c);

            //  don't cap a comment
            state = UpperCaseState.comment;
            break;
          }
          state = (c.codeUnitAt(0) >= 'A'.codeUnitAt(0) &&
                  c.codeUnitAt(0) <= 'G'.codeUnitAt(0))
              ? UpperCaseState.flatIsPossible
              : UpperCaseState.normal;
          continue; //  fall through
        case UpperCaseState.normal:
          //  reset on sequential reset characters
          if (c == ' ' ||
              c == '\n' ||
              c == '\r' ||
              c == '\t' ||
              c == '/' ||
              c == '/' ||
              c == '.' ||
              c == ',' ||
              c == ':' ||
              c == '#' ||
              c == MusicConstants.flatChar ||
              c == MusicConstants.sharpChar ||
              c == '[' ||
              c == ']') state = UpperCaseState.initial;

          sb.write(c);
          break;
        case UpperCaseState.comment:
          sb.write(c);
          if (c == ')') state = UpperCaseState.initial;
          break;
      }
    }
    return sb.toString();
  }

  /// Parse the current string representation of the song's chords into the song internal structures.
  void parseChords(final String chords) {
    this.chords = chords; //  safety only
    measureNodes = new List();
    chordSectionMap = new HashMap();
    clearCachedValues(); //  force lazy eval

    if (chords != null) {
      logger.d("parseChords for: " + getTitle());
      SplayTreeSet<ChordSection> emptyChordSections = new SplayTreeSet();
      MarkedString markedString = new MarkedString(chords);
      ChordSection chordSection;
      while (markedString.isNotEmpty) {
        markedString.stripLeadingWhitespace();
        if (markedString.isEmpty) break;
        logger.d(markedString.toString());

        try {
          chordSection = ChordSection.parse(markedString, beatsPerBar, false);
          if (chordSection.phrases.isEmpty)
            emptyChordSections.add(chordSection);
          else if (emptyChordSections.isNotEmpty) {
            //  share the common measure sequence items
            for (ChordSection wasEmptyChordSection in emptyChordSections) {
              wasEmptyChordSection.setPhrases(chordSection.phrases);
              chordSectionMap[wasEmptyChordSection.sectionVersion] =
                  wasEmptyChordSection;
            }
            emptyChordSections.clear();
          }
          measureNodes.add(chordSection);
          chordSectionMap[chordSection.sectionVersion] = chordSection;
          clearCachedValues();
        } catch (e) {
          //  try some repair
          clearCachedValues();

          logger.d(logGrid());
          throw e;
        }
      }
      this.chords = chordsToJsonTransportString();
    }

    setDefaultCurrentChordLocation();

    logger.d(logGrid());
  }

  /// Will always return something, even if errors have to be commented out
  List<MeasureNode> parseChordEntry(final String entry) {
    List<MeasureNode> ret = new List();

    if (entry != null) {
      logger.d("parseChordEntry: " + entry);
      SplayTreeSet<ChordSection> emptyChordSections = new SplayTreeSet();
      MarkedString markedString = new MarkedString(entry);
      ChordSection chordSection;
      int phaseIndex = 0;
      while (markedString.isNotEmpty) {
        markedString.stripLeadingWhitespace();
        if (markedString.isEmpty) break;
        logger.d("parseChordEntry: " + markedString.toString());

        int mark = markedString.mark();

        try {
          //  if it's a full section (or multiple sections) it will all be handled here
          chordSection = ChordSection.parse(markedString, beatsPerBar, true);

          //  look for multiple sections defined at once
          if (chordSection.phrases.isEmpty) {
            emptyChordSections.add(chordSection);
            continue;
          } else if (emptyChordSections.isNotEmpty) {
            //  share the common measure sequence items
            for (ChordSection wasEmptyChordSection in emptyChordSections) {
              wasEmptyChordSection.setPhrases(chordSection.phrases);
              ret.add(wasEmptyChordSection);
            }
            emptyChordSections.clear();
          }
          ret.add(chordSection);
          continue;
        } catch (e) {
          markedString.resetTo(mark);
        }

        //  see if it's a complete repeat
        try {
          ret.add(
              MeasureRepeat.parse(markedString, phaseIndex, beatsPerBar, null));
          phaseIndex++;
          continue;
        } catch (e) {
          markedString.resetTo(mark);
        }
        //  see if it's a phrase
        try {
          ret.add(Phrase.parse(markedString, phaseIndex, beatsPerBar,
              getCurrentChordSectionLocationMeasure()));
          phaseIndex++;
          continue;
        } catch (e) {
          markedString.resetTo(mark);
        }
        //  see if it's a single measure
        try {
          ret.add(Measure.parse(markedString, beatsPerBar,
              getCurrentChordSectionLocationMeasure()));
          continue;
        } catch (e) {
          markedString.resetTo(mark);
        }
        //  see if it's a comment
        try {
          ret.add(MeasureComment.parse(markedString));
          phaseIndex++;
          continue;
        } catch (e) {
          markedString.resetTo(mark);
        }
        //  the entry was not understood, force it to be a comment
        {
          int commentIndex = markedString.indexOf(" ");
          if (commentIndex < 0) {
            ret.add(new MeasureComment(markedString.toString()));
            break;
          } else {
            ret.add(new MeasureComment(
                markedString.remainingStringLimited(commentIndex)));
            markedString.consume(commentIndex);
          }
        }
      }

      //  add trailing empty sections... without a following non-empty section
      for (ChordSection wasEmptyChordSection in emptyChordSections)
        ret.add(wasEmptyChordSection);
    }

    //  try to help add row separations
    //  default to rows of 4 if there are 8 or more measures
    if (ret.length > 0 && ret[0] is ChordSection) {
      ChordSection chordSection = ret[0] as ChordSection;
      for (Phrase phrase in chordSection.phrases) {
        bool hasEndOfRow = false;
        for (Measure measure in phrase.measures) {
          if (measure.isComment()) continue;
          if (measure.endOfRow) {
            hasEndOfRow = true;
            break;
          }
        }
        if (!hasEndOfRow && phrase.length >= 8) {
          int i = 0;
          for (Measure measure in phrase.measures) {
            if (measure.isComment()) continue;
            i++;
            if (i % 4 == 0) {
              measure.endOfRow = true;
            }
          }
        }
      }
    }

    //  deal with sharps and flats misapplied.
    List<MeasureNode> transposed = new List();
    for (MeasureNode measureNode in ret) {
      transposed.add(measureNode.transposeToKey(key));
    }
    return transposed;
  }

  void setDefaultCurrentChordLocation() {
    currentChordSectionLocation = null;

    SplayTreeSet<ChordSection> sortedChordSections = SplayTreeSet();
    sortedChordSections.addAll(getChordSectionMap().values);
    if (sortedChordSections.isEmpty) return;

    ChordSection chordSection = sortedChordSections.last;
    if (chordSection != null) {
      List<Phrase> measureSequenceItems = chordSection.phrases;
      if (measureSequenceItems != null && measureSequenceItems.isNotEmpty) {
        Phrase lastPhrase =
            measureSequenceItems[measureSequenceItems.length - 1];
        currentChordSectionLocation = new ChordSectionLocation(
            chordSection.sectionVersion,
            phraseIndex: measureSequenceItems.length - 1,
            measureIndex: lastPhrase.length - 1);
      }
    }
  }

  void calcChordMaps() {
    getChordSectionLocationGrid(); //  use location grid to force them all in lazy eval
  }

  HashMap<GridCoordinate, ChordSectionLocation>
      getGridCoordinateChordSectionLocationMap() {
    getChordSectionLocationGrid();
    return gridCoordinateChordSectionLocationMap;
  }

  HashMap<ChordSectionLocation, GridCoordinate>
      getGridChordSectionLocationCoordinateMap() {
    getChordSectionLocationGrid();
    return gridChordSectionLocationCoordinateMap;
  }

  int getChordSectionLocationGridMaxColCount() {
    int maxCols = 0;
    for (GridCoordinate gridCoordinate
        in getGridCoordinateChordSectionLocationMap().keys) {
      maxCols = max(maxCols, gridCoordinate.col);
    }
    return maxCols;
  }

  Grid<ChordSectionLocation> getChordSectionLocationGrid() {
    //  support lazy eval
    if (chordSectionLocationGrid != null) return chordSectionLocationGrid;

    Grid<ChordSectionLocation> grid = Grid();
    chordSectionGridCoorinateMap = new HashMap();
    chordSectionGridMatches = new HashMap();
    gridCoordinateChordSectionLocationMap = new HashMap();
    gridChordSectionLocationCoordinateMap = new HashMap();

    //  grid each section
    final int offset = 1; //  offset of phrase start from section start
    int row = 0;
    int col = offset;

    //  use a separate set to avoid modifying a set
    SplayTreeSet<SectionVersion> sectionVersionsToDo = SplayTreeSet();
    sectionVersionsToDo.addAll(getChordSectionMap().keys);
    for (ChordSection chordSection in getChordSectionMap().values) {
      SectionVersion sectionVersion = chordSection.sectionVersion;

      //  only do a chord section once.  it might have a duplicate set of phrases and already be listed
      if (!sectionVersionsToDo.contains(sectionVersion)) continue;
      sectionVersionsToDo.remove(sectionVersion);

      //  start each section on it's own line
      if (col != offset) {
        row++;
      }
      col = 0;

      logger.d("gridding: " +
          sectionVersion.toString() +
          " (" +
          col.toString() +
          ", " +
          row.toString() +
          ")");

      {
        //  grid the section header
        SplayTreeSet<SectionVersion> matchingSectionVersionsSet =
            matchingSectionVersions(sectionVersion);
        GridCoordinate coordinate = new GridCoordinate(row, col);
        for (SectionVersion matchingSectionVersion
            in matchingSectionVersionsSet) {
          chordSectionGridCoorinateMap[matchingSectionVersion] = coordinate;
          ChordSectionLocation loc =
              new ChordSectionLocation(matchingSectionVersion);
          gridChordSectionLocationCoordinateMap[loc] = coordinate;
        }
        for (SectionVersion matchingSectionVersion
            in matchingSectionVersionsSet) {
          //  don't add identity mapping
          if (matchingSectionVersion == sectionVersion) continue;
          chordSectionGridMatches[matchingSectionVersion] = sectionVersion;
        }

        ChordSectionLocation loc =
            new ChordSectionLocation.byMultipleSectionVersion(
                matchingSectionVersionsSet);
        gridCoordinateChordSectionLocationMap[coordinate] = loc;
        gridChordSectionLocationCoordinateMap[loc] = coordinate;
        grid.set(col, row, loc);
        col = offset;
        sectionVersionsToDo.removeAll(matchingSectionVersionsSet);
      }

      //  allow for empty sections... on entry
      if (chordSection.phrases.isEmpty) {
        row++;
        col = offset;
      } else {
        //  grid each phrase
        for (int phraseIndex = 0;
            phraseIndex < chordSection.phrases.length;
            phraseIndex++) {
          //  start each phrase on it's own line
          if (col > offset) {
            row++;
            col = offset;
          }

          Phrase phrase = chordSection.getPhrase(phraseIndex);

          //  default to max measures per row
          final int measuresPerline = 8;

          //  grid each measure of the phrase
          bool repeatExtensionUsed = false;
          int phraseSize = phrase.measures.length;
          if (phraseSize == 0 && phrase.isRepeat()) {
            //  special case: deal with empty repeat
            //  fill row to measures per line
            col = offset + measuresPerline - 1;
            {
              //  add repeat indicator
              ChordSectionLocation loc = new ChordSectionLocation(
                  sectionVersion,
                  phraseIndex: phraseIndex);
              GridCoordinate coordinate = new GridCoordinate(row, col);
              gridCoordinateChordSectionLocationMap[coordinate] = loc;
              gridChordSectionLocationCoordinateMap[loc] = coordinate;
              grid.set(col++, row, loc);
            }
          } else {
            Measure measure;

            //  compute the max number of columns for this phrase
            int maxCol = offset;
            {
              int currentCol = offset;
              for (int measureIndex = 0;
                  measureIndex < phraseSize;
                  measureIndex++) {
                measure = phrase.getMeasure(measureIndex);
                if (measure.isComment()) //  comments get their own row
                  continue;
                currentCol++;
                if (measure.endOfRow) {
                  if (currentCol > maxCol) maxCol = currentCol;
                  currentCol = offset;
                }
              }
              if (currentCol > maxCol) maxCol = currentCol;
              maxCol = min(maxCol, measuresPerline + 1);
            }

            //  place each measure in the grid
            Measure lastMeasure;
            for (int measureIndex = 0;
                measureIndex < phraseSize;
                measureIndex++) {
              //  place comments on their own line
              //  don't upset the col location
              //  expect the output to span the row
              measure = phrase.getMeasure(measureIndex);
              if (measure.isComment()) {
                if (col > offset &&
                    lastMeasure != null &&
                    !lastMeasure.isComment()) row++;
                ChordSectionLocation loc = new ChordSectionLocation(
                    sectionVersion,
                    phraseIndex: phraseIndex,
                    measureIndex: measureIndex);
                grid.set(offset, row, loc);
                GridCoordinate coordinate = new GridCoordinate(row, offset);
                gridCoordinateChordSectionLocationMap[coordinate] = loc;
                gridChordSectionLocationCoordinateMap[loc] = coordinate;
                if (measureIndex < phraseSize - 1)
                  row++;
                else
                  col = offset + measuresPerline; //  prep for next phrase
                continue;
              }

              if ((lastMeasure != null && lastMeasure.endOfRow) ||
                      col >=
                          offset +
                              measuresPerline //  limit line length to the measures per line
                  ) {
                //  fill the row with nulls if the row is shorter then the others in this phrase
                while (col < maxCol) grid.set(col++, row, null);

                //  put an end of line marker on multiline repeats
                if (phrase.isRepeat()) {
                  grid.set(
                      col++,
                      row,
                      new ChordSectionLocation.withMarker(
                          sectionVersion,
                          phraseIndex,
                          (repeatExtensionUsed
                              ? ChordSectionLocationMarker.repeatMiddleRight
                              : ChordSectionLocationMarker.repeatUpperRight)));
                  repeatExtensionUsed = true;
                }
                if (col > offset) {
                  row++;
                  col = offset;
                }
              }

              {
                //  grid the measure with it's location
                ChordSectionLocation loc = new ChordSectionLocation(
                    sectionVersion,
                    phraseIndex: phraseIndex,
                    measureIndex: measureIndex);
                GridCoordinate coordinate = new GridCoordinate(row, col);
                gridCoordinateChordSectionLocationMap[coordinate] = loc;
                gridChordSectionLocationCoordinateMap[loc] = coordinate;
                grid.set(col++, row, loc);
              }

              //  put the repeat on the end of the last line of the repeat
              if (phrase.isRepeat() && measureIndex == phraseSize - 1) {
                col = maxCol;

                //  close the multiline repeat marker
                if (repeatExtensionUsed) {
                  ChordSectionLocation loc =
                      new ChordSectionLocation.withMarker(
                          sectionVersion,
                          phraseIndex,
                          ChordSectionLocationMarker.repeatLowerRight);
                  GridCoordinate coordinate = new GridCoordinate(row, col);
                  gridCoordinateChordSectionLocationMap[coordinate] = loc;
                  gridChordSectionLocationCoordinateMap[loc] = coordinate;
                  grid.set(col++, row, loc);

                  repeatExtensionUsed = false;
                }

                {
                  //  add repeat indicator
                  ChordSectionLocation loc = new ChordSectionLocation(
                      sectionVersion,
                      phraseIndex: phraseIndex);
                  GridCoordinate coordinate = new GridCoordinate(row, col);
                  gridCoordinateChordSectionLocationMap[coordinate] = loc;
                  gridChordSectionLocationCoordinateMap[loc] = coordinate;
                  grid.set(col++, row, loc);
                }
                row++;
                col = offset;
              }

              lastMeasure = measure;
            }
          }
        }
      }
    }


    {
      logger.d("gridCoordinateChordSectionLocationMap: ");
      SplayTreeSet set = SplayTreeSet<GridCoordinate>();
      set.addAll(gridCoordinateChordSectionLocationMap.keys);
      for (GridCoordinate coordinate in set) {
        logger.d(" " +
            coordinate.toString() +
            " " +
            gridCoordinateChordSectionLocationMap[coordinate].toString() +
            " -> " +
            findMeasureNodeByLocation(
                    gridCoordinateChordSectionLocationMap[coordinate])
                ?.toMarkup().toString());
      }
    }

    chordSectionLocationGrid = grid;
    logger.d(grid.toString());
    return chordSectionLocationGrid;
  }

  /// Find all matches to the given section version, including the given section version itself
  SplayTreeSet<SectionVersion> matchingSectionVersions(
      SectionVersion multSectionVersion) {
    SplayTreeSet<SectionVersion> ret = new SplayTreeSet();
    if (multSectionVersion == null) return ret;
    ChordSection multChordSection =
        findChordSectionBySectionVersion(multSectionVersion);
    if (multChordSection == null) return ret;

    {
      SplayTreeSet<ChordSection> set = SplayTreeSet();
      set.addAll(getChordSectionMap().values);
      for (ChordSection chordSection in set) {
        if (multSectionVersion == chordSection.sectionVersion)
          ret.add(multSectionVersion);
        else if (chordSection.phrases == multChordSection.phrases) {
          ret.add(chordSection.sectionVersion);
        }
      }
    }
    return ret;
  }

  ChordSectionLocation getLastChordSectionLocation() {
    Grid<ChordSectionLocation> grid = getChordSectionLocationGrid();
    if (grid == null || grid.isEmpty) return null;
    List<ChordSectionLocation> row = grid.getRow(grid.getRowCount() - 1);
    return grid.get(grid.getRowCount() - 1, row.length - 1);
  }

  HashMap<SectionVersion, GridCoordinate> getChordSectionGridCoorinateMap() {
    // force grid population from lazy eval
    if (chordSectionLocationGrid == null) getChordSectionLocationGrid();
    return chordSectionGridCoorinateMap;
  }

  void clearCachedValues() {
    chordSectionLocationGrid = null;
    complexity = 0;
    chordsAsMarkup = null;
    songMoments.clear();
    duration = 0;
    totalBeats = 0;
  }

  String chordsToJsonTransportString() {
    StringBuffer sb = StringBuffer();

    SplayTreeSet<ChordSection> set = SplayTreeSet();
    set.addAll(getChordSectionMap().values);
    for (ChordSection chordSection in set) {
      sb.write(chordSection.toJson());
    }
    return sb.toString();
  }

  String toMarkup() {
    if (chordsAsMarkup != null) return chordsAsMarkup;

    StringBuffer sb = StringBuffer();

    SplayTreeSet<SectionVersion> sortedSectionVersions = new SplayTreeSet();
    sortedSectionVersions.addAll(getChordSectionMap().keys);
    SplayTreeSet<SectionVersion> completedSectionVersions = new SplayTreeSet();

    //  markup by section version order
    for (SectionVersion sectionVersion in sortedSectionVersions) {
      //  don't repeat anything
      if (completedSectionVersions.contains(sectionVersion)) continue;
      completedSectionVersions.add(sectionVersion);

      //  find all section versions with the same chords
      ChordSection chordSection = getChordSectionMap()[sectionVersion];
      if (chordSection.isEmpty()) {
        //  empty sections stand alone
        sb.write(sectionVersion.toString());
        sb.write(" ");
      } else {
        SplayTreeSet<SectionVersion> currentSectionVersions = SplayTreeSet();
        for (SectionVersion otherSectionVersion in sortedSectionVersions) {
          if (listsEqual(chordSection.phrases,
              getChordSectionMap()[otherSectionVersion].phrases)) {
            currentSectionVersions.add(otherSectionVersion);
            completedSectionVersions.add(otherSectionVersion);
          }
        }

        //  list the section versions for this chord section
        for (SectionVersion currentSectionVersion in currentSectionVersions) {
          sb.write(currentSectionVersion.toString());
          sb.write(" ");
        }
      }

      //  chord section phrases (only) to output
      sb.write(chordSection.phrasesToMarkup());
      sb.write(" "); //  for human readability only
    }
    chordsAsMarkup = sb.toString();
    return chordsAsMarkup;
  }

  String toMarkupByLocation(ChordSectionLocation location) {
    StringBuffer sb = new StringBuffer();
    if (location != null) {
      if (location.isSection) {
        sb.write(location.toString());
        sb.write(" ");
        sb.write(getChordSectionByLocation(location).phrasesToMarkup());
        return sb.toString();
      } else {
        MeasureNode measureNode = findMeasureNodeByLocation(location);
        if (measureNode != null) return measureNode.toMarkup();
      }
    }
    return null;
  }

  String toEntry(ChordSectionLocation location) {
    StringBuffer sb = new StringBuffer();
    if (location != null) {
      if (location.isSection) {
        sb.write(
            getChordSectionByLocation(location).transposeToKey(key).toEntry());
        return sb.toString();
      } else {
        MeasureNode measureNode = findMeasureNodeByLocation(location);
        if (measureNode != null)
          return measureNode.transposeToKey(key).toEntry();
      }
    }
    return null;
  }

  /// Add the given section version to the song chords
  bool addSectionVersion(SectionVersion sectionVersion) {
    if (sectionVersion == null ||
        getChordSectionMap().containsKey(sectionVersion)) return false;
    getChordSectionMap()[sectionVersion] =
        new ChordSection(sectionVersion, null);
    clearCachedValues();
    setCurrentChordSectionLocation(new ChordSectionLocation(sectionVersion));
    setCurrentMeasureEditType(MeasureEditType.append);
    return true;
  }

  bool deleteCurrentChordSectionLocation() {
    setCurrentMeasureEditType(MeasureEditType.delete); //  tell the world

    preMod(null);

    //  deal with deletes
    ChordSectionLocation location = getCurrentChordSectionLocation();

    //  find the named chord section
    ChordSection chordSection = getChordSectionByLocation(location);
    if (chordSection == null) {
      postMod();
      return false;
    }

    if (chordSection.phrases.isEmpty) {
      chordSection.phrases.add(new Phrase(new List(), 0));
    }

    Phrase phrase;
    try {
      phrase = chordSection.getPhrase(location.phraseIndex);
    } catch (e) {
      phrase = chordSection.phrases[0]; //  use the default empty list
    }

    bool ret = false;

    if (location.isMeasure) {
      ret = phrase.edit(MeasureEditType.delete, location.measureIndex, null);
      if (ret && phrase.isEmpty()) return deleteCurrentChordSectionPhrase();
    } else if (location.isPhrase) {
      return deleteCurrentChordSectionPhrase();
    } else if (location.isSection) {
      //  find the section prior to the one being deleted
      List<SectionVersion> sortedSectionVersions = List();
      sortedSectionVersions.addAll(getChordSectionMap().keys);
      sortedSectionVersions.sort((a, b) => a.compareTo(b));
      SectionVersion nextSectionVersion =
          _priorSectionVersion(chordSection.sectionVersion);

      ret = (getChordSectionMap().remove(chordSection.sectionVersion) != null);
      if (ret) {
        //  move deleted current to end of previous section
        if (nextSectionVersion == null) {
          nextSectionVersion = _firstSectionVersion();
        }
        if (nextSectionVersion != null) {
          location = findChordSectionLocation(
              getChordSectionMap()[nextSectionVersion]);
        }
      }
    }
    return standardEditCleanup(ret, location);
  }

  bool deleteCurrentChordSectionPhrase() {
    ChordSectionLocation location = getCurrentChordSectionLocation();
    ChordSection chordSection = getChordSectionByLocation(location);
    bool ret = chordSection.deletePhrase(location.phraseIndex);
    if (ret) {
      //  move the current location if required
      if (location.phraseIndex >= chordSection.phrases.length) {
        if (chordSection.phrases.isEmpty)
          location = new ChordSectionLocation(chordSection.sectionVersion);
        else {
          int i = chordSection.phrases.length - 1;
          Phrase phrase = chordSection.getPhrase(i);
          int m = phrase.measures.length - 1;
          location = new ChordSectionLocation(chordSection.sectionVersion,
              phraseIndex: i, measureIndex: m);
        }
      }
    }
    return standardEditCleanup(ret, location);
  }

  void preMod(MeasureNode measureNode) {
    logger.d("startingChords(\"" + toMarkup() + "\");");
    logger.d(" pre(MeasureEditType." +
        getCurrentMeasureEditType().toString() +
        ", \"" +
        getCurrentChordSectionLocation().toString() +
        "\"" +
        ", \"" +
        (getCurrentChordSectionLocationMeasureNode() == null
            ? "null"
            : getCurrentChordSectionLocationMeasureNode().toMarkup()) +
        "\"" +
        ", \"" +
        (measureNode == null ? "null" : measureNode.toMarkup()) +
        "\");");
  }

  void postMod() {
    logger.d("resultChords(\"" + toMarkup() + "\");");
    logger.d("post(MeasureEditType." +
        getCurrentMeasureEditType().toString() +
        ", \"" +
        getCurrentChordSectionLocation().toString() +
        "\"" +
        ", \"" +
        (getCurrentChordSectionLocationMeasureNode() == null
            ? "null"
            : getCurrentChordSectionLocationMeasureNode().toMarkup()) +
        "\");");
  }

  bool editList(List<MeasureNode> measureNodes) {
    if (measureNodes == null || measureNodes.isEmpty) return false;

    for (MeasureNode measureNode in measureNodes) {
      if (!editMeasureNode(measureNode)) return false;
    }
    return true;
  }

  bool deleteCurrentSelection() {
    setCurrentMeasureEditType(MeasureEditType.delete);
    return editMeasureNode(null);
  }

  /// Edit the given measure in or out of the song based on the data from the edit location.
  bool editMeasureNode(MeasureNode measureNode) {
    MeasureEditType editType = getCurrentMeasureEditType();

    if (editType == MeasureEditType.delete)
      return deleteCurrentChordSectionLocation();

    preMod(measureNode);

    if (measureNode == null) {
      postMod();
      return false;
    }

    ChordSectionLocation location = getCurrentChordSectionLocation();

    //  find the named chord section
    ChordSection chordSection = getChordSectionByLocation(location);
    if (chordSection == null) {
      switch (measureNode.getMeasureNodeType()) {
        case MeasureNodeType.section:
          chordSection = measureNode as ChordSection;
          break;
        default:
          chordSection = getChordSectionMap()[SectionVersion.getDefault()];
          if (chordSection == null) {
            chordSection = ChordSection.getDefault();
            getChordSectionMap()[chordSection.sectionVersion] = chordSection;
          }
          break;
      }
    }

    //  default to insert if empty
    if (chordSection.phrases.isEmpty) {
      chordSection.phrases.add(new Phrase(new List(), 0));
      //fixme?  editType = MeasureEditType.insert;
    }

    Phrase phrase;
    try {
      phrase = chordSection.getPhrase(location.phraseIndex);
    } catch (e) {
      if (!chordSection.isEmpty())
        phrase = chordSection.phrases[0]; //  use the default empty list
    }

    bool ret = false;

    //  handle situations by the type of measure node being added
    ChordSectionLocation newLocation;
    ChordSection newChordSection;
    MeasureRepeat newRepeat;
    Phrase newPhrase;
    switch (measureNode.getMeasureNodeType()) {
      case MeasureNodeType.section:
        switch (editType) {
          case MeasureEditType.delete:
            //  find the section prior to the one being deleted
            SplayTreeSet<SectionVersion> sortedSectionVersions = SplayTreeSet();
            sortedSectionVersions.addAll(getChordSectionMap().keys);
            SectionVersion nextSectionVersion =
                _priorSectionVersion(chordSection.sectionVersion);
            ret = (getChordSectionMap().remove(chordSection.sectionVersion) !=
                null);
            if (ret) {
              //  move deleted current to end of previous section
              if (nextSectionVersion == null) {
                nextSectionVersion = _firstSectionVersion();
              }
              if (nextSectionVersion != null) {
                location = new ChordSectionLocation(nextSectionVersion);
              }
              //else ; // fixme: set location to empty location
            }
            break;
          default:
            //  all sections replace themselves
            newChordSection = measureNode as ChordSection;
            getChordSectionMap()[newChordSection.sectionVersion] =
                newChordSection;
            ret = true;
            location = new ChordSectionLocation(newChordSection.sectionVersion);
            break;
        }
        return standardEditCleanup(ret, location);

      case MeasureNodeType.repeat:
        newRepeat = measureNode as MeasureRepeat;
        if (newRepeat.isEmpty()) {
          //  empty repeat
          if (phrase.isRepeat()) {
            //  change repeats
            MeasureRepeat repeat = phrase as MeasureRepeat;
            if (newRepeat.repeats < 2) {
              setCurrentMeasureEditType(MeasureEditType.append);

              //  convert repeat to phrase
              newPhrase = new Phrase(repeat.measures, location.phraseIndex);
              int phaseIndex = location.phraseIndex;
              if (phaseIndex > 0 &&
                  chordSection.getPhrase(phaseIndex - 1).getMeasureNodeType() ==
                      MeasureNodeType.phrase) {
                //  expect combination of the two phrases
                Phrase priorPhrase = chordSection.getPhrase(phaseIndex - 1);
                location = new ChordSectionLocation(chordSection.sectionVersion,
                    phraseIndex: phaseIndex - 1,
                    measureIndex: priorPhrase.measures.length +
                        newPhrase.measures.length -
                        1);
                return standardEditCleanup(
                    chordSection.deletePhrase(phaseIndex) &&
                        chordSection.add(phaseIndex, newPhrase),
                    location);
              }
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: location.phraseIndex,
                  measureIndex: newPhrase.measures.length - 1);
              logger.d("new loc: " + location.toString());
              return standardEditCleanup(
                  chordSection.deletePhrase(newPhrase.phraseIndex) &&
                      chordSection.add(newPhrase.phraseIndex, newPhrase),
                  location);
            }
            repeat.repeats = newRepeat.repeats;
            return standardEditCleanup(true, location);
          }
          if (newRepeat.repeats <= 1)
            return true; //  no change but no change was asked for

          if (!phrase.isEmpty()) {
            //  convert phrase line to a repeat
            GridCoordinate minGridCoordinate = getGridCoordinate(location);
            minGridCoordinate = new GridCoordinate(minGridCoordinate.row, 1);
            MeasureNode minMeasureNode =
                findMeasureNodeByGrid(minGridCoordinate);
            ChordSectionLocation minLocation =
                getChordSectionLocation(minGridCoordinate);
            GridCoordinate maxGridCoordinate = getGridCoordinate(location);
            maxGridCoordinate = new GridCoordinate(
                maxGridCoordinate.row,
                chordSectionLocationGrid.getRow(maxGridCoordinate.row).length -
                    1);
            MeasureNode maxMeasureNode =
                findMeasureNodeByGrid(maxGridCoordinate);
            ChordSectionLocation maxLocation =
                getChordSectionLocation(maxGridCoordinate);
            logger.d("min: " +
                minGridCoordinate.toString() +
                " " +
                minMeasureNode.toMarkup() +
                " " +
                minLocation.measureIndex.toString());
            logger.d("max: " +
                maxGridCoordinate.toString() +
                " " +
                maxMeasureNode.toMarkup() +
                " " +
                maxLocation.measureIndex.toString());

            //  delete the old
            int phraseIndex = phrase.phraseIndex;
            chordSection.deletePhrase(phraseIndex);
            //  replace the old early part
            if (minLocation.measureIndex > 0) {
              List<Measure> range = List();
              range.addAll(
                  phrase.measures.getRange(0, minLocation.measureIndex));
              chordSection.add(phraseIndex, new Phrase(range, phraseIndex));
              phraseIndex++;
            }
            //  replace the sub-phrase with a repeat
            {
              List<Measure> range = List();
              range.addAll(phrase.measures.getRange(
                  minLocation.measureIndex, maxLocation.measureIndex + 1));
              MeasureRepeat repeat =
                  new MeasureRepeat(range, phraseIndex, newRepeat.repeats);
              chordSection.add(phraseIndex, repeat);
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: phraseIndex);
              phraseIndex++;
            }
            //  replace the old late part
            if (maxLocation.measureIndex < phrase.measures.length - 1) {
              List<Measure> range = List();
              List<Measure> measures = phrase.measures;
              range.addAll(measures.getRange(
                  maxLocation.measureIndex + 1, measures.length));
              chordSection.add(phraseIndex, new Phrase(range, phraseIndex));
              //phraseIndex++;
            }
            return standardEditCleanup(true, location);
          }
        } else {
          newPhrase = newRepeat;

          //  demote x1 repeat to phrase
          if (newRepeat.repeats < 2)
            newPhrase = new Phrase(newRepeat.measures, newRepeat.phraseIndex);

          //  non-empty repeat
          switch (editType) {
            case MeasureEditType.delete:
              return standardEditCleanup(
                  chordSection.deletePhrase(phrase.phraseIndex), location);
            case MeasureEditType.append:
              newPhrase.setPhraseIndex(phrase.phraseIndex + 1);
              return standardEditCleanup(
                  chordSection.add(phrase.phraseIndex + 1, newPhrase),
                  new ChordSectionLocation(chordSection.sectionVersion,
                      phraseIndex: phrase.phraseIndex + 1));
            case MeasureEditType.insert:
              newPhrase.setPhraseIndex(phrase.phraseIndex);
              return standardEditCleanup(
                  chordSection.add(phrase.phraseIndex, newPhrase), location);
            case MeasureEditType.replace:
              newPhrase.setPhraseIndex(phrase.phraseIndex);
              return standardEditCleanup(
                  chordSection.deletePhrase(phrase.phraseIndex) &&
                      chordSection.add(newPhrase.phraseIndex, newPhrase),
                  location);
          }
        }
        break;

      case MeasureNodeType.phrase:
        newPhrase = measureNode as Phrase;
        int phraseIndex = 0;
        switch (editType) {
          case MeasureEditType.append:
            if (location == null) {
              if (chordSection.getPhraseCount() == 0) {
                //  append as first phrase
                location = new ChordSectionLocation(chordSection.sectionVersion,
                    phraseIndex: 0, measureIndex: newPhrase.length - 1);
                newPhrase.setPhraseIndex(phraseIndex);
                return standardEditCleanup(
                    chordSection.add(phraseIndex, newPhrase), location);
              }

              //  last of section
              Phrase lastPhrase = chordSection.lastPhrase();
              switch (lastPhrase.getMeasureNodeType()) {
                case MeasureNodeType.phrase:
                  location = new ChordSectionLocation(
                      chordSection.sectionVersion,
                      phraseIndex: lastPhrase.phraseIndex,
                      measureIndex: lastPhrase.length + newPhrase.length - 1);
                  return standardEditCleanup(
                      lastPhrase.add(newPhrase.measures), location);
                default:
                  break;
              }
              phraseIndex = chordSection.getPhraseCount();
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: phraseIndex, measureIndex: lastPhrase.length);
              newPhrase.setPhraseIndex(phraseIndex);
              return standardEditCleanup(
                  chordSection.add(phraseIndex, newPhrase), location);
            }
            if (chordSection.isEmpty()) {
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: phraseIndex, measureIndex: newPhrase.length - 1);
              newPhrase.setPhraseIndex(phraseIndex);
              return standardEditCleanup(
                  chordSection.add(phraseIndex, newPhrase), location);
            }

            if (location.hasMeasureIndex) {
              newLocation = new ChordSectionLocation(
                  chordSection.sectionVersion,
                  phraseIndex: phrase.phraseIndex,
                  measureIndex: location.measureIndex + newPhrase.length);
              return standardEditCleanup(
                  phrase.edit(editType, location.measureIndex, newPhrase),
                  newLocation);
            }
            if (location.hasPhraseIndex) {
              phraseIndex = location.phraseIndex + 1;
              newLocation = new ChordSectionLocation(
                  chordSection.sectionVersion,
                  phraseIndex: phraseIndex,
                  measureIndex: newPhrase.length - 1);
              return standardEditCleanup(
                  chordSection.add(phraseIndex, newPhrase), newLocation);
            }
            newLocation = new ChordSectionLocation(chordSection.sectionVersion,
                phraseIndex: phrase.phraseIndex,
                measureIndex: phrase.measures.length + newPhrase.length - 1);
            return standardEditCleanup(
                phrase.add(newPhrase.measures), newLocation);

          case MeasureEditType.insert:
            if (location == null) {
              if (chordSection.getPhraseCount() == 0) {
                //  append as first phrase
                location = new ChordSectionLocation(chordSection.sectionVersion,
                    phraseIndex: 0, measureIndex: newPhrase.length - 1);
                newPhrase.setPhraseIndex(phraseIndex);
                return standardEditCleanup(
                    chordSection.add(phraseIndex, newPhrase), location);
              }

              //  first of section
              Phrase firstPhrase = chordSection.getPhrase(0);
              switch (firstPhrase.getMeasureNodeType()) {
                case MeasureNodeType.phrase:
                  location = new ChordSectionLocation(
                      chordSection.sectionVersion,
                      phraseIndex: firstPhrase.phraseIndex,
                      measureIndex: 0);
                  return standardEditCleanup(
                      firstPhrase.add(newPhrase.measures), location);
                default:
                  break;
              }

              phraseIndex = 0;
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: phraseIndex, measureIndex: firstPhrase.length);
              newPhrase.setPhraseIndex(phraseIndex);
              return standardEditCleanup(
                  chordSection.add(phraseIndex, newPhrase), location);
            }
            if (chordSection.isEmpty()) {
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: phraseIndex, measureIndex: newPhrase.length - 1);
              newPhrase.setPhraseIndex(phraseIndex);
              return standardEditCleanup(
                  chordSection.add(phraseIndex, newPhrase), location);
            }

            if (location.hasMeasureIndex) {
              newLocation = new ChordSectionLocation(
                  chordSection.sectionVersion,
                  phraseIndex: phrase.phraseIndex,
                  measureIndex: location.measureIndex + newPhrase.length - 1);
              return standardEditCleanup(
                  phrase.edit(editType, location.measureIndex, newPhrase),
                  newLocation);
            }

            //  insert new phrase in front of existing phrase
            newLocation = new ChordSectionLocation(chordSection.sectionVersion,
                phraseIndex: phrase.phraseIndex,
                measureIndex: newPhrase.length - 1);
            return standardEditCleanup(
                phrase.addAllAt(0, newPhrase.measures), newLocation);
          case MeasureEditType.replace:
            if (location != null) {
              if (location.hasPhraseIndex) {
                if (location.hasMeasureIndex) {
                  newLocation = new ChordSectionLocation(
                      chordSection.sectionVersion,
                      phraseIndex: phraseIndex,
                      measureIndex:
                          location.measureIndex + newPhrase.length - 1);
                  return standardEditCleanup(
                      phrase.edit(editType, location.measureIndex, newPhrase),
                      newLocation);
                }
                //  delete the phrase before replacing it
                phraseIndex = location.phraseIndex;
                if (phraseIndex > 0 &&
                    chordSection
                            .getPhrase(phraseIndex - 1)
                            .getMeasureNodeType() ==
                        MeasureNodeType.phrase) {
                  //  expect combination of the two phrases
                  Phrase priorPhrase = chordSection.getPhrase(phraseIndex - 1);
                  location = new ChordSectionLocation(
                      chordSection.sectionVersion,
                      phraseIndex: phraseIndex - 1,
                      measureIndex: priorPhrase.measures.length +
                          newPhrase.measures.length);
                  return standardEditCleanup(
                      chordSection.deletePhrase(phraseIndex) &&
                          chordSection.add(phraseIndex, newPhrase),
                      location);
                } else {
                  location = new ChordSectionLocation(
                      chordSection.sectionVersion,
                      phraseIndex: phraseIndex,
                      measureIndex: newPhrase.measures.length - 1);
                  return standardEditCleanup(
                      chordSection.deletePhrase(phraseIndex) &&
                          chordSection.add(phraseIndex, newPhrase),
                      location);
                }
              }
              break;
            }
            phraseIndex = (location != null && location.hasPhraseIndex
                ? location.phraseIndex
                : 0);
            break;
          default:
            phraseIndex = (location != null && location.hasPhraseIndex
                ? location.phraseIndex
                : 0);
            break;
        }
        newPhrase.setPhraseIndex(phraseIndex);
        location = new ChordSectionLocation(chordSection.sectionVersion,
            phraseIndex: phraseIndex, measureIndex: newPhrase.length - 1);
        return standardEditCleanup(
            chordSection.add(phraseIndex, newPhrase), location);

      case MeasureNodeType.measure:
      case MeasureNodeType.comment:
        //  add measure to current phrase
        if (location.hasMeasureIndex) {
          newLocation = location;
          switch (editType) {
            case MeasureEditType.append:
              newLocation = location.nextMeasureIndexLocation();
              break;
            default:
              break;
          }
          return standardEditCleanup(
              phrase.edit(editType, newLocation.measureIndex, measureNode),
              newLocation);
        }

        //  add measure to chordSection by creating a new phase
        if (location.hasPhraseIndex) {
          List<Measure> measures = new List();
          measures.add(measureNode as Measure);
          newPhrase = new Phrase(measures, location.phraseIndex);
          switch (editType) {
            case MeasureEditType.delete:
              break;
            case MeasureEditType.append:
              newPhrase.setPhraseIndex(phrase.phraseIndex);
              return standardEditCleanup(
                  chordSection.add(phrase.phraseIndex, newPhrase),
                  location.nextMeasureIndexLocation());
            case MeasureEditType.insert:
              newPhrase.setPhraseIndex(phrase.phraseIndex);
              return standardEditCleanup(
                  chordSection.add(phrase.phraseIndex, newPhrase), location);
            case MeasureEditType.replace:
              newPhrase.setPhraseIndex(phrase.phraseIndex);
              return standardEditCleanup(
                  chordSection.deletePhrase(phrase.phraseIndex) &&
                      chordSection.add(newPhrase.phraseIndex, newPhrase),
                  location);
          }
        }
        break;
      case MeasureNodeType.decoration:
        return false;
    }

    //  edit measure node into location
    switch (editType) {
      case MeasureEditType.insert:
        switch (measureNode.getMeasureNodeType()) {
          case MeasureNodeType.repeat:
          case MeasureNodeType.phrase:
            ret = chordSection.insert(location.phraseIndex, measureNode);
            break;
          default:
            break;
        }
        //  no location change
        standardEditCleanup(ret, location);
        break;

      case MeasureEditType.append:
        //  promote marker to repeat
        try {
          Measure refMeasure = phrase.getMeasure(location.measureIndex);
          if (refMeasure is MeasureRepeatMarker && phrase.isRepeat()) {
            MeasureRepeat measureRepeat = phrase as MeasureRepeat;
            if (refMeasure == measureRepeat.getRepeatMarker()) {
              //  appending at the repeat marker forces the section to add a sequenceItem list after the repeat
              int phraseIndex = chordSection.indexOf(measureRepeat) + 1;
              newPhrase = new Phrase(new List(), phraseIndex);
              chordSection.phrases.insert(phraseIndex + 1, newPhrase);
              phrase = newPhrase;
            }
          }
        } catch (e) {
          //  ignore attempt
        }

        if (location.isSection) {
          switch (measureNode.getMeasureNodeType()) {
            case MeasureNodeType.section:
              SectionVersion sectionVersion = location.sectionVersion;
              return standardEditCleanup(
                  ((getChordSectionMap()[sectionVersion] =
                          measureNode as ChordSection) !=
                      null),
                  location.nextMeasureIndexLocation());
            case MeasureNodeType.phrase:
            case MeasureNodeType.repeat:
              return standardEditCleanup(
                  chordSection.add(location.phraseIndex, measureNode as Phrase),
                  location);
            default:
              break;
          }
        }
        if (location.isPhrase) {
          switch (measureNode.getMeasureNodeType()) {
            case MeasureNodeType.repeat:
            case MeasureNodeType.phrase:
              chordSection.phrases
                  .insert(location.phraseIndex + 1, measureNode as Phrase);
              return standardEditCleanup(true, location);
            default:
              break;
          }
          break;
        }

        break;

      case MeasureEditType.delete:
        //  note: measureNode is ignored, and should be ignored
        if (location.isMeasure) {
          ret = (phrase.deleteAt(location.measureIndex) != null);
          if (ret) {
            if (location.measureIndex < phrase.length) {
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: location.phraseIndex,
                  measureIndex: location.measureIndex);
              measureNode = findMeasureNodeByLocation(location);
            } else {
              if (phrase.length > 0) {
                int index = phrase.length - 1;
                location = new ChordSectionLocation(chordSection.sectionVersion,
                    phraseIndex: location.phraseIndex, measureIndex: index);
                measureNode = findMeasureNodeByLocation(location);
              } else {
                chordSection.deletePhrase(location.phraseIndex);
                if (chordSection.getPhraseCount() > 0) {
                  location = new ChordSectionLocation(
                      chordSection.sectionVersion,
                      phraseIndex: 0,
                      measureIndex: chordSection.getPhrase(0).length - 1);
                  measureNode = findMeasureNodeByLocation(location);
                } else {
                  //  last phase was deleted
                  location =
                      new ChordSectionLocation(chordSection.sectionVersion);
                  measureNode = findMeasureNodeByLocation(location);
                }
              }
            }
          }
        } else if (location.isPhrase) {
          ret = chordSection.deletePhrase(location.phraseIndex);
          if (ret) {
            if (location.phraseIndex > 0) {
              int index = location.phraseIndex - 1;
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: index,
                  measureIndex: chordSection.getPhrase(index).length - 1);
              measureNode = findMeasureNodeByLocation(location);
            } else if (chordSection.getPhraseCount() > 0) {
              location = new ChordSectionLocation(chordSection.sectionVersion,
                  phraseIndex: 0,
                  measureIndex: chordSection.getPhrase(0).length - 1);
              measureNode = findMeasureNodeByLocation(location);
            } else {
              //  last one was deleted
              location = new ChordSectionLocation(chordSection.sectionVersion);
              measureNode = findMeasureNodeByLocation(location);
            }
          }
        } else if (location.isSection) {
          //  fixme: what did i have in mind?
        }
        standardEditCleanup(ret, location);
        break;
      default:
        break;
    }
    postMod();
    return ret;
  }

  bool standardEditCleanup(bool ret, ChordSectionLocation location) {
    if (ret) {
      clearCachedValues(); //  force lazy re-compute of markup when required, after and edit

      collapsePhrases(location);
      setCurrentChordSectionLocation(location);
      resetLastModifiedDateToNow();

      switch (getCurrentMeasureEditType()) {
        // case MeasureEditType.replace:
        case MeasureEditType.delete:
          if (getCurrentChordSectionLocationMeasureNode() == null)
            setCurrentMeasureEditType(MeasureEditType.append);
          break;
        default:
          setCurrentMeasureEditType(MeasureEditType.append);
          break;
      }
    }
    postMod();
    return ret;
  }

  void collapsePhrases(ChordSectionLocation location) {
    if (location == null) return;
    ChordSection chordSection = getChordSectionMap()[location.sectionVersion];
    if (chordSection == null) return;
    int limit = chordSection.getPhraseCount();
    Phrase lastPhrase;
    for (int i = 0; i < limit; i++) {
      Phrase phrase = chordSection.getPhrase(i);
      if (lastPhrase == null) {
        if (phrase.getMeasureNodeType() == MeasureNodeType.phrase)
          lastPhrase = phrase;
        continue;
      }
      if (phrase.getMeasureNodeType() == MeasureNodeType.phrase) {
        if (lastPhrase != null) {
          //  two contiguous phrases: join
          lastPhrase.add(phrase.measures);
          chordSection.deletePhrase(i);
          limit--; //  one less index
        }
        lastPhrase = phrase;
      } else
        lastPhrase = null;
    }
  }

  SectionVersion _priorSectionVersion(SectionVersion sectionVersion) {
    List<SectionVersion> sortedSectionVersions = List();
    sortedSectionVersions.addAll(getChordSectionMap().keys);
    int i = max(
        0,
        min(sortedSectionVersions.indexOf(sectionVersion) - 1,
            sortedSectionVersions.length - 1));
    return sortedSectionVersions.elementAt(i);
  }

  SectionVersion _firstSectionVersion() {
    SplayTreeSet<SectionVersion> set = SplayTreeSet();
    set.addAll(getChordSectionMap().keys);
    return (set.isEmpty ? null : set.first);
  }

  /// Find the measure sequence item for the given measure (i.e. the measure's parent container).
  Phrase findPhrase(Measure measure) {
    if (measure == null) return null;

    ChordSection chordSection = findChordSectionByMeasure(measure);
    if (chordSection == null) return null;
    for (Phrase msi in chordSection.phrases) {
      for (Measure m in msi.measures) if (m == measure) return msi;
    }
    return null;
  }

  ///Find the chord section for the given measure node.
  ChordSection findChordSectionByMeasure(MeasureNode measureNode) {
    if (measureNode == null) return null;

    String id = measureNode.getId();
    for (ChordSection chordSection in getChordSectionMap().values) {
      if (id != null && id == chordSection.getId()) return chordSection;
      MeasureNode mn = chordSection.findMeasureNode(measureNode);
      if (mn != null) return chordSection;
    }
    return null;
  }

  ChordSectionLocation findChordSectionLocation(MeasureNode measureNode) {
    if (measureNode == null) return null;

    Phrase phrase;
    try {
      ChordSection chordSection = findChordSectionByMeasure(measureNode);
      switch (measureNode.getMeasureNodeType()) {
        case MeasureNodeType.section:
          return new ChordSectionLocation(chordSection.sectionVersion);
        case MeasureNodeType.repeat:
        case MeasureNodeType.phrase:
          phrase = chordSection.findPhrase(measureNode);
          return new ChordSectionLocation(chordSection.sectionVersion,
              phraseIndex: phrase.phraseIndex);
        case MeasureNodeType.decoration:
        case MeasureNodeType.comment:
        case MeasureNodeType.measure:
          phrase = chordSection.findPhrase(measureNode);
          return new ChordSectionLocation(chordSection.sectionVersion,
              phraseIndex: phrase.phraseIndex,
              measureIndex: phrase.findMeasureNodeIndex(measureNode));
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  ChordSectionLocation getChordSectionLocation(GridCoordinate gridCoordinate) {
    return getGridCoordinateChordSectionLocationMap()[gridCoordinate];
  }

  GridCoordinate getGridCoordinate(ChordSectionLocation chordSectionLocation) {
    chordSectionLocation = chordSectionLocation.changeSectionVersion(
        chordSectionGridMatches[chordSectionLocation.sectionVersion]);
    return getGridChordSectionLocationCoordinateMap()[chordSectionLocation];
  }

  /// Find the chord section for the given type of chord section
  ChordSection findChordSectionBySectionVersion(SectionVersion sectionVersion) {
    if (sectionVersion == null) return null;
    return getChordSectionMap()[sectionVersion]; //  get not type safe!!!!
  }

  Measure findMeasureByChordSectionLocation(
      ChordSectionLocation chordSectionLocation) {
    try {
      return getChordSectionMap()[chordSectionLocation.sectionVersion]
          .getPhrase(chordSectionLocation.phraseIndex)
          .getMeasure(chordSectionLocation.measureIndex);
    } catch (e) {
      return null;
    }
  }

  Measure getCurrentChordSectionLocationMeasure() {
    ChordSectionLocation location = getCurrentChordSectionLocation();
    if (location.hasMeasureIndex) {
      int index = location.measureIndex;
      if (index > 0) {
        location = new ChordSectionLocation(location.sectionVersion,
            phraseIndex: location.phraseIndex, measureIndex: index);
        MeasureNode measureNode = findMeasureNodeByLocation(location);
        if (measureNode != null) {
          switch (measureNode.getMeasureNodeType()) {
            case MeasureNodeType.measure:
              return measureNode as Measure;
            default:
              break;
          }
        }
      }
    }
    return null;
  }

  MeasureNode findMeasureNodeByGrid(GridCoordinate coordinate) {
    return findMeasureNodeByLocation(
        getGridCoordinateChordSectionLocationMap()[coordinate]);
  }

  MeasureNode findMeasureNodeByLocation(
      ChordSectionLocation chordSectionLocation) {
    if (chordSectionLocation == null) return null;
    ChordSection chordSection =
        getChordSectionMap()[chordSectionLocation.sectionVersion];
    if (chordSection == null) return null;
    if (chordSectionLocation.isSection) return chordSection;

    try {
      Phrase phrase = chordSection.getPhrase(chordSectionLocation.phraseIndex);
      if (chordSectionLocation.isPhrase) {
        switch (chordSectionLocation.marker) {
          case ChordSectionLocationMarker.none:
            return phrase;
          default:
            return MeasureRepeatExtension.get(chordSectionLocation.marker);
        }
      }

      return phrase.getMeasure(chordSectionLocation.measureIndex);
    } catch (RangeError) {
      return null;
    }
  }

  MeasureNode getCurrentMeasureNode() {
    return findMeasureNodeByLocation(currentChordSectionLocation);
  }

  ChordSection findChordSectionByString(String s) {
    SectionVersion sectionVersion = SectionVersion.parseString(s);
    return getChordSectionMap()[sectionVersion];
  }

  ChordSection findChordSectionbyMarkedString(MarkedString markedString) {
    SectionVersion sectionVersion = SectionVersion.parse(markedString);
    return getChordSectionMap()[sectionVersion];
  }

  bool chordSectionLocationDelete(ChordSectionLocation chordSectionLocation) {
    try {
      ChordSection chordSection =
          getChordSection(chordSectionLocation.sectionVersion);
      if (chordSection.deleteMeasure(chordSectionLocation.phraseIndex,
          chordSectionLocation.measureIndex)) {
        clearCachedValues();
        setCurrentChordSectionLocation(chordSectionLocation);
        return true;
      }
    } catch (e) {}
    return false;
  }

  bool chordSectionDelete(ChordSection chordSection) {
    if (chordSection == null) return false;
    bool ret = getChordSectionMap().remove(chordSection) != null;
    clearCachedValues();
    return ret;
  }

  void guessTheKey() {
    //  fixme: key guess based on chords section or lyrics?
    setKey(Key.guessKey(findScaleChordsUsed().keys));
  }

  HashMap<ScaleChord, int> findScaleChordsUsed() {
    HashMap<ScaleChord, int> ret = new HashMap();
    for (ChordSection chordSection in getChordSectionMap().values) {
      for (Phrase msi in chordSection.phrases) {
        for (Measure m in msi.measures) {
          for (Chord chord in m.chords) {
            ScaleChord scaleChord = chord.scaleChord;
            int chordCount = ret[scaleChord];
            ret[scaleChord] = (chordCount == null ? 1 : chordCount + 1);
          }
        }
      }
    }
    return ret;
  }

  void parseLyrics() {
    int state = 0;
    String whiteSpace = "";
    StringBuffer lyricsBuffer = new StringBuffer();
    LyricSection lyricSection;

    lyricSections = new List();

    MarkedString markedString = new MarkedString(rawLyrics);
    while (markedString.isNotEmpty) {
      String c = markedString.charAt(0);
      switch (state) {
        case 0:
          //  absorb leading white space
          if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            break;
          }
          state++;
          continue;
        case 1:
          try {
            SectionVersion version = SectionVersion.parse(markedString);
            if (lyricSection != null) lyricSections.add(lyricSection);

            lyricSection = new LyricSection();
            lyricSection.setSectionVersion(version);

            whiteSpace = ""; //  ignore white space
            state = 0;
            continue;
          } catch (e) {
            //  ignore
          }
          state++;
          continue;
        case 2:
          //  absorb all characters to newline
          switch (c) {
            case ' ':
            case '\t':
              whiteSpace += c;
              break;
            case '\n':
            case '\r':
              if (lyricSection == null) {
                //  oops, an old unformatted song, force a lyrics section
                lyricSection = new LyricSection();
                lyricSection.setSectionVersion(Section.getDefaultVersion());
              }
              lyricSection.add(new LyricsLine(lyricsBuffer.toString()));
              lyricsBuffer = new StringBuffer();
              whiteSpace = ""; //  ignore trailing white space
              state = 0;
              break;
            default:
              lyricsBuffer.write(whiteSpace);
              lyricsBuffer.write(c);
              whiteSpace = "";
              break;
          }
          break;
        default:
          throw "fsm broken at state: " + state.toString();
      }

      markedString.consume(1);
    }
    //  last one is not terminated by another section
    if (lyricSection != null)
      lyricSection.add(new LyricsLine(lyricsBuffer.toString()));
    lyricSections.add(lyricSection);

    //  safety with lazy eval
    clearCachedValues();
  }

  /// Debug only!  a string form of the song chord section grid
  String logGrid() {
    StringBuffer sb = new StringBuffer("\n");

    calcChordMaps(); //  avoid ConcurrentModificationException
    for (int r = 0; r < getChordSectionLocationGrid().getRowCount(); r++) {
      List<ChordSectionLocation> row = chordSectionLocationGrid.getRow(r);
      for (int c = 0; c < row.length; c++) {
        ChordSectionLocation loc = row[c];
        if (loc == null) continue;
        sb.write("(");
        sb.write(r);
        sb.write(",");
        sb.write(c);
        sb.write(") ");
        sb.write(loc.isMeasure ? "        " : (loc.isPhrase ? "    " : ""));
        sb.write(loc.toString());
        sb.write("  ");
        //sb.write(findMeasureNodeByLocation(loc).toMarkup() + "\n");
      }
    }
    return sb.toString();
  }

  void addRepeat(
      ChordSectionLocation chordSectionLocation, MeasureRepeat repeat) {
    Measure measure = findMeasureByChordSectionLocation(chordSectionLocation);
    if (measure == null) return;

    Phrase measureSequenceItem = findPhrase(measure);
    if (measureSequenceItem == null) return;

    ChordSection chordSection = findChordSectionByMeasure(measure);
    List<Phrase> measureSequenceItems = chordSection.phrases;
    int i = measureSequenceItems.indexOf(measureSequenceItem);
    if (i >= 0) {
      List<Phrase> copy = new List();
      copy.addAll(measureSequenceItems);
      measureSequenceItems = copy;
      measureSequenceItems.removeAt(i);
      repeat.setPhraseIndex(i);
      measureSequenceItems.insert(i, repeat);
    } else {
      repeat.setPhraseIndex(measureSequenceItems.length - 1);
      measureSequenceItems.add(repeat);
    }

    chordSectionDelete(chordSection);
    chordSection =
        new ChordSection(chordSection.sectionVersion, measureSequenceItems);
    getChordSectionMap()[chordSection.sectionVersion] = chordSection;
    clearCachedValues();
  }

  void setRepeat(ChordSectionLocation chordSectionLocation, int repeats) {
    Measure measure = findMeasureByChordSectionLocation(chordSectionLocation);
    if (measure == null) return;

    Phrase phrase = findPhrase(measure);
    if (phrase == null) return;

    if (phrase is MeasureRepeat) {
      MeasureRepeat measureRepeat = phrase;

      if (repeats <= 1) {
        //  remove the repeat
        ChordSection chordSection = findChordSectionByMeasure(measureRepeat);
        List<Phrase> measureSequenceItems = chordSection.phrases;
        int phraseIndex = measureSequenceItems.indexOf(measureRepeat);
        measureSequenceItems.removeAt(phraseIndex);
        measureSequenceItems.insert(
            phraseIndex, new Phrase(measureRepeat.measures, phraseIndex));

        chordSectionDelete(chordSection);
        chordSection =
            new ChordSection(chordSection.sectionVersion, measureSequenceItems);
        getChordSectionMap()[chordSection.sectionVersion] = chordSection;
      } else {
        //  change the count
        measureRepeat.repeats = repeats;
      }
    } else {
      //  change sequence items to repeat
      MeasureRepeat measureRepeat =
          new MeasureRepeat(phrase.measures, phrase.phraseIndex, repeats);
      ChordSection chordSection = findChordSectionByMeasure(phrase);
      List<Phrase> measureSequenceItems = chordSection.phrases;
      int i = measureSequenceItems.indexOf(phrase);
      List<Phrase> copy = new List();
      copy.addAll(measureSequenceItems);
      measureSequenceItems = copy;
      measureSequenceItems.removeAt(i);
      measureSequenceItems.insert(i, measureRepeat);

      chordSectionDelete(chordSection);
      chordSection =
          new ChordSection(chordSection.sectionVersion, measureSequenceItems);
      getChordSectionMap()[chordSection.sectionVersion] = chordSection;
    }

    clearCachedValues();
  }

  /// Set the number of measures displayed per row
  bool setMeasuresPerRow(int measuresPerRow) {
    if (measuresPerRow <= 0) return false;

    bool ret = false;
    SplayTreeSet<ChordSection> set = SplayTreeSet();
    set.addAll(getChordSectionMap().values);
    for (ChordSection chordSection in set) {
      ret = chordSection.setMeasuresPerRow(measuresPerRow) || ret;
    }
    if (ret) clearCachedValues();
    return ret;
  }

  /// Checks a song for completeness.
  Song checkSong() {
    return checkSongBase(
        getTitle(),
        getArtist(),
        getCopyright(),
        getKey(),
        getDefaultBpm().toString(),
        getBeatsPerBar().toString(),
        getUnitsPerMeasure().toString(),
        getUser(),
        toMarkup(),
        getRawLyrics());
  }

  /// Validate a song entry argument set
  /*
   * @param title                the song's title
   * @param artist               the artist associated with this song or at least this song version
   * @param copyright            the copyright notice associated with the song
   * @param key                  the song's musical key
   * @param bpmEntry             the song's number of beats per minute
   * @param beatsPerBarEntry     the song's default number of beats per par
   * @param user                 the app user's name
   * @param unitsPerMeasureEntry the inverse of the note duration fraction per entry, for exmple if each beat is
   *                             represented by a quarter note, the units per measure would be 4.
   * @param chordsTextEntry      the string transport form of the song's chord sequence description
   * @param lyricsTextEntry      the string transport form of the song's section sequence and lyrics
   * @return a new song if the fields are valid
   * @throws ParseException exception thrown if the song's fields don't match properly.
   */
  static Song checkSongBase(
      String title,
      String artist,
      String copyright,
      Key key,
      String bpmEntry,
      String beatsPerBarEntry,
      String unitsPerMeasureEntry,
      String user,
      String chordsTextEntry,
      String lyricsTextEntry) {
    if (title == null || title.length <= 0) {
      throw "no song title given!";
    }

    if (artist == null || artist.length <= 0) {
      throw "no artist given!";
    }

    if (copyright == null || copyright.length <= 0) {
      throw "no copyright given!";
    }

    if (key == null) key = Key.get(KeyEnum.C); //  punt on an error

    if (bpmEntry == null || bpmEntry.length <= 0) {
      throw "no BPM given!";
    }

    //  check bpm
    RegExp twoOrThreeDigitsRegexp = RegExp("^\\d{2,3}\$");
    if (!twoOrThreeDigitsRegexp.hasMatch(bpmEntry)) {
      throw "BPM has to be a number from " +
          MusicConstants.minBpm.toString() +
          " to " +
          MusicConstants.maxBpm.toString();
    }
    int bpm = int.parse(bpmEntry);
    if (bpm < MusicConstants.minBpm || bpm > MusicConstants.maxBpm) {
      throw "BPM has to be a number from " +
          MusicConstants.minBpm.toString() +
          " to " +
          MusicConstants.maxBpm.toString();
    }

    //  check beats per bar
    if (beatsPerBarEntry == null || beatsPerBarEntry.length <= 0) {
      throw "no beats per bar given!";
    }
    RegExp oneOrTwoDigitRegexp = RegExp("^\\d{1,2}\$");
    if (!oneOrTwoDigitRegexp.hasMatch(beatsPerBarEntry)) {
      throw "Beats per bar has to be 2, 3, 4, 6, or 12";
    }
    int beatsPerBar = int.parse(beatsPerBarEntry);
    switch (beatsPerBar) {
      case 2:
      case 3:
      case 4:
      case 6:
      case 12:
        break;
      default:
        throw "Beats per bar has to be 2, 3, 4, 6, or 12";
    }

    if (chordsTextEntry == null || chordsTextEntry.length <= 0) {
      throw "no chords given!";
    }
    if (lyricsTextEntry == null || lyricsTextEntry.length <= 0) {
      throw "no lyrics given!";
    }

    if (unitsPerMeasureEntry == null || unitsPerMeasureEntry.length <= 0) {
      throw "No units per measure given!";
    }
    if (!oneOrTwoDigitRegexp.hasMatch(unitsPerMeasureEntry)) {
      throw "Units per measure has to be 2, 4, or 8";
    }
    int unitsPerMeasure = int.parse(unitsPerMeasureEntry);
    switch (unitsPerMeasure) {
      case 2:
      case 4:
      case 8:
        break;
      default:
        throw "Units per measure has to be 2, 4, or 8";
    }

    Song newSong = Song.createSong(title, artist, copyright, key, bpm,
        beatsPerBar, unitsPerMeasure, user, chordsTextEntry, lyricsTextEntry);
    newSong.resetLastModifiedDateToNow();

    if (newSong.getChordSections().isEmpty)
      throw "The song has no chord sections! ";

    for (ChordSection chordSection in newSong.getChordSections()) {
      if (chordSection.isEmpty())
        throw "Chord section " +
            chordSection.sectionVersion.toString() +
            " is empty.";
    }

    //  see that all chord sections have a lyric section
    for (ChordSection chordSection in newSong.getChordSections()) {
      SectionVersion chordSectionVersion = chordSection.sectionVersion;
      bool found = false;
      for (LyricSection lyricSection in newSong.getLyricSections()) {
        if (chordSectionVersion == lyricSection.sectionVersion) {
          found = true;
          break;
        }
      }
      if (!found) {
        throw "no use found for the declared chord section " +
            chordSectionVersion.toString();
      }
    }

    //  see that all lyric sections have a chord section
    for (LyricSection lyricSection in newSong.getLyricSections()) {
      SectionVersion lyricSectionVersion = lyricSection.sectionVersion;
      bool found = false;
      for (ChordSection chordSection in newSong.getChordSections()) {
        if (lyricSectionVersion == chordSection.sectionVersion) {
          found = true;
          break;
        }
      }
      if (!found) {
        throw "no chords found for the lyric section " +
            lyricSectionVersion.toString();
      }
    }

    if (newSong.getMessage() == null) {
      for (ChordSection chordSection in newSong.getChordSections()) {
        for (Phrase phrase in chordSection.phrases) {
          for (Measure measure in phrase.measures) {
            if (measure.isComment()) {
              throw "chords should not have comments: see " +
                  chordSection.toString();
            }
          }
        }
      }
    }

    newSong.setMessage(null);

    if (newSong.getMessage() == null) {
      //  an early song with default (no) structure?
      if (newSong.getLyricSections().length == 1 &&
          newSong.getLyricSections()[0].sectionVersion ==
              Section.getDefaultVersion()) {
        newSong
            .setMessage("song looks too simple, is there really no structure?");
      }
    }

    return newSong;
  }

  static List<StringTriple> diff(SongBase a, SongBase b) {
    List<StringTriple> ret = new List();

    if (a.getTitle().compareTo(b.getTitle()) != 0)
      ret.add(new StringTriple("title:", a.getTitle(), b.getTitle()));
    if (a.getArtist().compareTo(b.getArtist()) != 0)
      ret.add(new StringTriple("artist:", a.getArtist(), b.getArtist()));
    if (a.getCoverArtist() != null &&
        b.getCoverArtist() != null &&
        a.getCoverArtist().compareTo(b.getCoverArtist()) != 0)
      ret.add(
          new StringTriple("cover:", a.getCoverArtist(), b.getCoverArtist()));
    if (a.getCopyright().compareTo(b.getCopyright()) != 0)
      ret.add(
          new StringTriple("copyright:", a.getCopyright(), b.getCopyright()));
    if (a.getKey().compareTo(b.getKey()) != 0)
      ret.add(new StringTriple(
          "key:", a.getKey().toString(), b.getKey().toString()));
    if (a.getBeatsPerMinute() != b.getBeatsPerMinute())
      ret.add(new StringTriple("BPM:", a.getBeatsPerMinute().toString(),
          b.getBeatsPerMinute().toString()));
    if (a.getBeatsPerBar() != b.getBeatsPerBar())
      ret.add(new StringTriple("per bar:", a.getBeatsPerBar().toString(),
          b.getBeatsPerBar().toString()));
    if (a.getUnitsPerMeasure() != b.getUnitsPerMeasure())
      ret.add(new StringTriple(
          "units/measure:",
          a.getUnitsPerMeasure().toString(),
          b.getUnitsPerMeasure().toString()));

    //  chords
    for (ChordSection aChordSection in a.getChordSections()) {
      ChordSection bChordSection =
          b.getChordSection(aChordSection.sectionVersion);
      if (bChordSection == null) {
        ret.add(
            new StringTriple("chords missing:", aChordSection.toMarkup(), ""));
      } else if (aChordSection.compareTo(bChordSection) != 0) {
        ret.add(new StringTriple(
            "chords:", aChordSection.toMarkup(), bChordSection.toMarkup()));
      }
    }
    for (ChordSection bChordSection in b.getChordSections()) {
      ChordSection aChordSection =
          a.getChordSection(bChordSection.sectionVersion);
      if (aChordSection == null) {
        ret.add(
            new StringTriple("chords missing:", "", bChordSection.toMarkup()));
      }
    }

    //  lyrics
    {
      int limit = min(a.getLyricSections().length, b.getLyricSections().length);
      for (int i = 0; i < limit; i++) {
        LyricSection aLyricSection = a.getLyricSections()[i];
        SectionVersion sectionVersion = aLyricSection.sectionVersion;
        LyricSection bLyricSection = b.getLyricSections()[i];
        int lineLimit = min(aLyricSection.getLyricsLines().length,
            bLyricSection.getLyricsLines().length);
        for (int j = 0; j < lineLimit; j++) {
          String aLine = aLyricSection.getLyricsLines()[j].getLyrics();
          String bLine = bLyricSection.getLyricsLines()[j].getLyrics();
          if (aLine.compareTo(bLine) != 0)
            ret.add(new StringTriple(
                "lyrics " + sectionVersion.toString(), aLine, bLine));
        }
        lineLimit = aLyricSection.getLyricsLines().length;
        for (int j = bLyricSection.getLyricsLines().length;
            j < lineLimit;
            j++) {
          String aLine = aLyricSection.getLyricsLines()[j].getLyrics();
          ret.add(new StringTriple(
              "lyrics missing " + sectionVersion.toString(), aLine, ""));
        }
        lineLimit = bLyricSection.getLyricsLines().length;
        for (int j = aLyricSection.getLyricsLines().length;
            j < lineLimit;
            j++) {
          String bLine = bLyricSection.getLyricsLines()[j].getLyrics();
          ret.add(new StringTriple(
              "lyrics missing " + sectionVersion.toString(), "", bLine));
        }
      }
    }

    return ret;
  }

  bool hasSectionVersion(Section section, int version) {
    if (section == null) return false;

    for (SectionVersion sectionVersion in getChordSectionMap().keys) {
      if (sectionVersion.getSection() == section &&
          sectionVersion.getVersion() == version) return true;
    }
    return false;
  }

  /// Sets the song's title and song id from the given title. Leading "The " articles are rotated to the title end.
  void setTitle(String title) {
    this.title = _theToTheEnd(title);
    computeSongIdFromSongData();
  }

  /// Sets the song's artist
  void setArtist(String artist) {
    this.artist = _theToTheEnd(artist);
    computeSongIdFromSongData();
  }

  void setCoverArtist(String coverArtist) {
    this.coverArtist = _theToTheEnd(coverArtist);
    computeSongIdFromSongData();
  }

  String _theToTheEnd(String s) {
    if (s == null || s.length <= 4) return s;

    //  move the leading "The " to the end
    RegExp theRegExp = RegExp("^ *(the +)(.*)", caseSensitive: false);
    RegExpMatch m = theRegExp.firstMatch(s);
    if (m != null) {
      s = m.group(2) + ", " + m.group(1);
    }
    return s;
  }

  void resetLastModifiedDateToNow() {
    //  for song override
  }

  void computeSongIdFromSongData() {
    songId = computeSongId(title, artist, coverArtist);
  }

  static SongId computeSongId(String title, String artist, String coverArtist) {
    return new SongId("Song_" +
        title.replaceAll("\\W+", "") +
        "_by_" +
        artist.replaceAll("\\W+", "") +
        (coverArtist == null || coverArtist.length <= 0
            ? ""
            : "_coverBy_" + coverArtist));
  }

  /// Sets the copyright for the song.  All songs should have a copyright.
  void setCopyright(String copyright) {
    this.copyright = copyright;
  }

  /// Set the key for this song.
  void setKey(Key key) {
    this.key = key;
  }

  /// Return the song default beats per minute.
  int getBeatsPerMinute() {
    return defaultBpm;
  }

  double getDefaultTimePerBar() {
    if (defaultBpm == 0) return 1;
    return beatsPerBar * 60.0 / defaultBpm;
  }

  double getSecondsPerBeat() {
    if (defaultBpm == 0) return 1;
    return 60.0 / defaultBpm;
  }

  /// Set the song default beats per minute.
  void setBeatsPerMinute(int bpm) {
    if (bpm < 20)
      bpm = 20;
    else if (bpm > 1000) bpm = 1000;
    this.defaultBpm = bpm;
  }

  /// Return the song's number of beats per bar
  int getBeatsPerBar() {
    return beatsPerBar;
  }

  /// Set the song's number of beats per bar
  void setBeatsPerBar(int beatsPerBar) {
    //  never divide by zero
    if (beatsPerBar <= 1) beatsPerBar = 2;
    this.beatsPerBar = beatsPerBar;
    clearCachedValues();
  }

  /// Return an integer that represents the number of notes per measure
  /// represented in the sheet music.  Typically this is 4; meaning quarter notes.
  int getUnitsPerMeasure() {
    return unitsPerMeasure;
  }

  void setUnitsPerMeasure(int unitsPerMeasure) {
    this.unitsPerMeasure = unitsPerMeasure;
  }

  /// Return the song's copyright
  String getCopyright() {
    return copyright;
  }

  /// Return the song's key
  Key getKey() {
    return key;
  }

  /// Return the song's identification string largely consisting of the title and artist name.
  String getSongId() {
    return songId.songId;
  }

  /// Return the song's title
  String getTitle() {
    return title;
  }

  /// Return the song's artist.
  String getArtist() {
    return artist;
  }

  /// Return the lyrics.
  @deprecated
  String getLyricsAsString() {
    return rawLyrics;
  }

  /// Return the default beats per minute.
  int getDefaultBpm() {
    return defaultBpm;
  }

  Iterable<ChordSection> getChordSections() {
    return getChordSectionMap().values;
  }

  String getFileName() {
    return fileName;
  }

  void setFileName(String fileName) {
    this.fileName = fileName;

    RegExp fileVersionRegExp = RegExp(r" \(([0-9]+)\).songlyrics$");
    RegExpMatch mr = fileVersionRegExp.firstMatch(fileName);
    if (mr != null) {
      fileVersionNumber = int.parse(mr.group(1));
    } else
      fileVersionNumber = 0;
    //logger.info("setFileName(): "+fileVersionNumber);
  }

  double getDuration() {
    computeDuration();
    return duration;
  }

  int getTotalBeats() {
    computeDuration();
    return totalBeats;
  }

  int getSongMomentsSize() {
    return getSongMoments().length;
  }

  List<SongMoment> getSongMoments() {
    computeSongMoments();
    return songMoments;
  }

  SongMoment getSongMoment(int momentNumber) {
    computeSongMoments();
    if (songMoments.isEmpty ||
        momentNumber < 0 ||
        momentNumber >= songMoments.length) return null;
    return songMoments[momentNumber];
  }

  SongMoment getFirstSongMomentInSection(int momentNumber) {
    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null) return null;

    SongMoment firstSongMoment = songMoment;
    String id = songMoment.getChordSection().getId();
    for (int m = momentNumber - 1; m >= 0; m--) {
      SongMoment sm = songMoments[m];
      if (id != sm.getChordSection().getId() ||
          sm.getSectionCount() != firstSongMoment.getSectionCount())
        return firstSongMoment;
      firstSongMoment = sm;
    }
    return firstSongMoment;
  }

  SongMoment getLastSongMomentInSection(int momentNumber) {
    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null) return null;

    SongMoment lastSongMoment = songMoment;
    String id = songMoment.getChordSection().getId();
    int limit = songMoments.length;
    for (int m = momentNumber + 1; m < limit; m++) {
      SongMoment sm = songMoments[m];
      if (id != sm.getChordSection().getId() ||
          sm.getSectionCount() != lastSongMoment.getSectionCount())
        return lastSongMoment;
      lastSongMoment = sm;
    }
    return lastSongMoment;
  }

  double getSongTimeAtMoment(int momentNumber) {
    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null) return 0;
    return songMoment.getBeatNumber() * getBeatsPerMinute() / 60.0;
  }

  static int getBeatNumberAtTime(int bpm, double songTime) {
    if (bpm <= 0) return null; //  we're done with this song play

    int songBeat = songTime * bpm ~/ 60.0;
    return songBeat;
  }

  int getSongMomentNumberAtSongTime(double songTime) {
    if (getBeatsPerMinute() <= 0)
      return null; //  we're done with this song play

    int songBeat = getBeatNumberAtTime(getBeatsPerMinute(), songTime);
    if (songBeat < 0) {
      return (songBeat - beatsPerBar + 1) ~/
          beatsPerBar; //  constant measure based lead in
    }

    computeSongMoments();
    if (songBeat >= beatsToMoment.length)
      return null; //  we're done with the last measure of this song play

    return beatsToMoment[songBeat].getMomentNumber();
  }

  /// Return the first moment on the given row
  SongMoment getSongMomentAtRow(int rowIndex) {
    if (rowIndex < 0) return null;
    computeSongMoments();
    for (SongMoment songMoment in songMoments) {
      //  return the first moment on this row
      if (rowIndex == getMomentGridCoordinate(songMoment).row)
        return songMoment;
    }
    return null;
  }

  List<LyricSection> getLyricSections() {
    return lyricSections;
  }

  int getFileVersionNumber() {
    return fileVersionNumber;
  }

  int getChordSectionBeatsFromLocation(
      ChordSectionLocation chordSectionLocation) {
    if (chordSectionLocation == null) return 0;
    return getChordSectionBeats(chordSectionLocation.sectionVersion);
  }

  int getChordSectionBeats(SectionVersion sectionVersion) {
    if (sectionVersion == null) return 0;
    computeSongMoments();
    int ret = chordSectionBeats[sectionVersion];
    if (ret == null) return 0;
    return ret;
  }

  int getChordSectionRows(SectionVersion sectionVersion) {
    computeSongMoments();
    int ret = chordSectionRows[sectionVersion];
    if (ret == null) return 0;
    return ret;
  }

  ///Compute a relative complexity index for the song
  int getComplexity() {
    if (complexity == 0) {
      //  compute the complexity
      SplayTreeSet<Measure> differentChords = new SplayTreeSet();
      for (ChordSection chordSection in getChordSectionMap().values) {
        for (Phrase phrase in chordSection.phrases) {
          //  the more different measures, the greater the complexity
          differentChords.addAll(phrase.measures);

          //  weight measures by guitar complexity
          for (Measure measure in phrase.measures)
            if (!measure.isEasyGuitarMeasure()) complexity++;
        }
      }
      complexity += getChordSectionMap().values.length;
      complexity += differentChords.length;
    }
    return complexity;
  }

  void setDuration(double duration) {
    this.duration = duration;
  }

  String getRawLyrics() {
    return rawLyrics;
  }

  void setChords(String chords) {
    this.chords = chords;
    clearCachedValues();
  }

  void setRawLyrics(String rawLyrics) {
    this.rawLyrics = rawLyrics;
    parseLyrics();
  }

  void setTotalBeats(int totalBeats) {
    this.totalBeats = totalBeats;
  }

  void setDefaultBpm(int defaultBpm) {
    this.defaultBpm = defaultBpm;
  }

  String getCoverArtist() {
    return coverArtist;
  }

  String getMessage() {
    return message;
  }

  void setMessage(String message) {
    this.message = message;
  }

  MeasureEditType getCurrentMeasureEditType() {
    return currentMeasureEditType;
  }

  void setCurrentMeasureEditType(MeasureEditType measureEditType) {
    currentMeasureEditType = measureEditType;
    logger.d("curloc: " +
        (currentChordSectionLocation != null
            ? currentChordSectionLocation.toString()
            : "none") +
        " " +
        (currentMeasureEditType != null
            ? currentMeasureEditType.toString()
            : "no type"));
  }

  ChordSectionLocation getCurrentChordSectionLocation() {
    //  insist on something non-null
    if (currentChordSectionLocation == null) {
      if (getChordSectionMap().keys.isEmpty) {
        currentChordSectionLocation =
            new ChordSectionLocation(SectionVersion.getDefault());
      } else {
        //  last location
        SplayTreeSet<SectionVersion> sectionVersions = SplayTreeSet();
        sectionVersions.addAll(getChordSectionMap().keys);
        ChordSection lastChordSection =
            getChordSectionMap()[sectionVersions.last];
        if (lastChordSection.isEmpty())
          currentChordSectionLocation =
              new ChordSectionLocation(lastChordSection.sectionVersion);
        else {
          Phrase phrase = lastChordSection.lastPhrase();
          if (phrase.isEmpty())
            currentChordSectionLocation = new ChordSectionLocation(
                lastChordSection.sectionVersion,
                phraseIndex: phrase.phraseIndex);
          else
            currentChordSectionLocation = new ChordSectionLocation(
                lastChordSection.sectionVersion,
                phraseIndex: phrase.phraseIndex,
                measureIndex: phrase.measures.length - 1);
        }
      }
    }
    return currentChordSectionLocation;
  }

  MeasureNode getCurrentChordSectionLocationMeasureNode() {
    return currentChordSectionLocation == null
        ? null
        : findMeasureNodeByLocation(currentChordSectionLocation);
  }

  void setCurrentChordSectionLocation(
      ChordSectionLocation chordSectionLocation) {
//  try to find something close if the exact location doesn't exist
    if (chordSectionLocation == null) {
      chordSectionLocation = currentChordSectionLocation;
      if (chordSectionLocation == null) {
        chordSectionLocation = getLastChordSectionLocation();
      }
    }
    if (chordSectionLocation != null)
      try {
        ChordSection chordSection =
            getChordSectionByLocation(chordSectionLocation);
        ChordSection cs = chordSection;
        if (cs == null) {
          SplayTreeSet<SectionVersion> sortedSectionVersions =
              new SplayTreeSet();
          sortedSectionVersions.addAll(getChordSectionMap().keys);
          cs = getChordSectionMap()[sortedSectionVersions.last];
        }
        if (chordSectionLocation.hasPhraseIndex) {
          Phrase phrase = cs.getPhrase(chordSectionLocation.phraseIndex);
          if (phrase == null) phrase = cs.getPhrase(cs.getPhraseCount() - 1);
          int phraseIndex = phrase.phraseIndex;
          if (chordSectionLocation.hasMeasureIndex) {
            int pi = (phraseIndex >= cs.getPhraseCount()
                ? cs.getPhraseCount() - 1
                : phraseIndex);
            int measureIndex = chordSectionLocation.measureIndex;
            int mi = (measureIndex >= phrase.length
                ? phrase.length - 1
                : measureIndex);
            if (cs != chordSection || pi != phraseIndex || mi != measureIndex)
              chordSectionLocation = new ChordSectionLocation(cs.sectionVersion,
                  phraseIndex: pi, measureIndex: mi);
          }
        }
      } catch (e) {
        chordSectionLocation = null;
      }
//    catch
//    (
//    Exception ex) {
//    //  javascript parse error
//    logger.d(ex.getMessage());
//    chordSectionLocation = null;
//    }

    currentChordSectionLocation = chordSectionLocation;
    logger.d("curloc: " +
        (currentChordSectionLocation != null
            ? currentChordSectionLocation.toString()
            : "none") +
        " " +
        (currentMeasureEditType != null
            ? currentMeasureEditType.toString()
            : "no type") +
        " " +
        (currentChordSectionLocation != null
            ? findMeasureNodeByLocation(currentChordSectionLocation).toString()
            : "none"));
  }

  @override
  String toString() {
    return title +
        (fileVersionNumber > 0
            ? ":(" + fileVersionNumber.toString() + ")"
            : "") +
        " by " +
        artist;
  }

  static bool containsSongTitleAndArtist(
      Iterable<SongBase> iterable, SongBase song) {
    for (SongBase collectionSong in iterable) {
      if (song.compareBySongId(collectionSong) == 0) return true;
    }
    return false;
  }

  /// Compare only the title and artist.
  ///To be used for listing purposes only.
  int compareBySongId(SongBase o) {
    if (o == null) return -1;
    int ret = getSongId().compareTo(o.getSongId());
    if (ret != 0) {
      return ret;
    }
    return 0;
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SongBase && songBaseSameAs(other);
  }

  bool songBaseSameAs(SongBase o) {
    //  song id built from title with reduced whitespace
    if (title != o.title) return false;
    if (artist != o.artist) return false;
    if (coverArtist != null) {
      if (coverArtist != o.coverArtist) return false;
    } else if (o.coverArtist != null) {
      return false;
    }
    if (copyright != o.copyright) return false;
    if (key != o.key) return false;
    if (defaultBpm != o.defaultBpm) return false;
    if (unitsPerMeasure != o.unitsPerMeasure) return false;
    if (beatsPerBar != o.beatsPerBar) return false;
    if (chords != o.chords) return false;
    if (rawLyrics != (o.rawLyrics)) return false;
    //    if (metadata != (o.metadata))
    //      return false;
    if (lastModifiedTime != o.lastModifiedTime) return false;

    //  hmm, think about these
    if (fileName != o.fileName) return false;
    if (fileVersionNumber != o.fileVersionNumber) return false;

    return true;
  }

  @override
  int get hashCode {
    //  2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97
    int ret = hash4(title, artist, coverArtist, copyright);
    ret =
        ret * 17 + hash4(key.keyEnum, defaultBpm, unitsPerMeasure, beatsPerBar);
    ret = ret * 19 + hash3(chords, rawLyrics, lastModifiedTime);
    ret = ret * 23 + hash2(fileName, fileVersionNumber);
    return ret;
  }

  //  primary values
  String title = "Unknown";
  String artist = "Unknown";
  String user = defaultUser;
  String coverArtist = "";
  String copyright = "Unknown";
  Key key = Key.get(KeyEnum.C); //  default
  int defaultBpm = 106; //  beats per minute
  int unitsPerMeasure = 4; //  units per measure, i.e. timeSignature numerator
  int beatsPerBar = 4; //  beats per bar, i.e. timeSignature denominator
  int lastModifiedTime;
  String chords = "";
  String rawLyrics = "";

  //  deprecated values
  int fileVersionNumber = 0;

  //  meta data
  String fileName;

  //  computed values
  SongId songId;
  double duration; //  units of seconds
  int totalBeats;
  HashMap<SectionVersion, ChordSection> chordSectionMap;
  List<MeasureNode> measureNodes;

  List<LyricSection> lyricSections = new List();
  HashMap<SectionVersion, GridCoordinate> chordSectionGridCoorinateMap =
      new HashMap();

  //  match to representative section version
  HashMap<SectionVersion, SectionVersion> chordSectionGridMatches =
      new HashMap();

  HashMap<GridCoordinate, ChordSectionLocation>
      gridCoordinateChordSectionLocationMap;
  HashMap<ChordSectionLocation, GridCoordinate>
      gridChordSectionLocationCoordinateMap;
  HashMap<SongMoment, GridCoordinate> songMomentGridCoordinateHashMap =
      new HashMap();
  HashMap<SectionVersion, int> chordSectionBeats = new HashMap();
  HashMap<SectionVersion, int> chordSectionRows = new HashMap();

  ChordSectionLocation currentChordSectionLocation;
  MeasureEditType currentMeasureEditType = MeasureEditType.append;
  Grid<ChordSectionLocation> chordSectionLocationGrid;

  int complexity;
  String chordsAsMarkup;
  String message;
  List<SongMoment> songMoments = List();
  HashMap<int, SongMoment> beatsToMoment = new HashMap();

  //SplayTreeSet<Metadata> metadata = new SplayTreeSet();
  static final AppOptions appOptions = AppOptions();
  static final String defaultUser = "Unknown";
}

//  set.sort(comparatorByTitle);
Comparator<SongBase> comparatorByTitle = (SongBase o1, SongBase o2) {
  ///  Compares its two arguments for order.
  return o1.compareBySongId(o2);
};

Comparator<SongBase> comparatorByArtist = (SongBase o1, SongBase o2) {
  int ret = o1.getArtist().compareTo(o2.getArtist());
  if (ret != 0) return ret;
  return o1.compareBySongId(o2);
};

void foo() {
  List<SongBase> list = List();
  list.sort(comparatorByTitle);
  list.forEach((SongBase song) {
    print('${song.songId}: ${song.title} by ${song.artist}');
  });
  list.sort(comparatorByArtist);
  list.forEach((SongBase song) {
    print('${song.songId}: ${song.title} by ${song.artist}');
  });
}
