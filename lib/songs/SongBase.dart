import 'dart:collection';
import 'dart:core';
import 'dart:math';

import 'package:logger/logger.dart';

import '../Grid.dart';
import '../GridCoordinate.dart';
import '../util.dart';
import 'Chord.dart';
import 'ChordDescriptor.dart';
import 'ChordSection.dart';
import 'ChordSectionLocation.dart';
import 'LegacyDrumSection.dart';
import 'LyricSection.dart';
import 'LyricsLine.dart';
import 'Measure.dart';
import 'MeasureComment.dart';
import 'MeasureNode.dart';
import 'MeasureRepeat.dart';
import 'MeasureRepeatExtension.dart';
import 'MusicConstants.dart';
import 'Phrase.dart';
import 'Section.dart';
import 'SectionVersion.dart';
import 'SongId.dart';
import 'SongMoment.dart';
import 'key.dart';
import 'scaleChord.dart';

enum

UpperCaseState {
  initial,
  flatIsPossible,
  comment,
  normal,
}

/// A piece of music to be played according to the structure it contains.
///  The song base class has been separated from the song class to allow most of the song
///  mechanics to be tested in the shared code environment where debugging is easier.

class SongBase {

  /**
   * Not to be used externally
   */
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
  static SongBase createSongBase(String title, String artist,
      String copyright,
      Key key, int bpm, int beatsPerBar, int unitsPerMeasure,
      String chords, String lyricsToParse) {
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
    if (songMoments.isNotEmpty)
      return;

    songMoments.clear();
    beatsToMoment.clear();

    if (lyricSections == null)
      return;

    _logger.d("lyricSections size: " + lyricSections.length.toString());
    int sectionCount = null;
    HashMap<SectionVersion, int> sectionVersionCountMap = new HashMap();
    chordSectionBeats.clear();
    int beatNumber = 0;
    for (LyricSection lyricSection in lyricSections) {
      ChordSection chordSection = findChordSection(lyricSection);
      if (chordSection == null)
        continue;

      //  compute section count
      SectionVersion sectionVersion = chordSection.getSectionVersion();
      sectionCount = sectionVersionCountMap[sectionVersion];
      if (sectionCount == null) {
        sectionCount = 0;
      }
      sectionCount++;
      sectionVersionCountMap[sectionVersion] = sectionCount;

      List<Phrase> phrases = chordSection.getPhrases();
      if (phrases != null) {
        int phraseIndex = 0;
        int sectionVersionBeats = 0;
        for (Phrase phrase in phrases) {
          if (phrase.isRepeat()) {
            MeasureRepeat measureRepeat = phrase as MeasureRepeat;
            int limit = measureRepeat.repeats;
            for (int repeat = 0; repeat < limit; repeat++) {
              List<Measure> measures = measureRepeat.getMeasures();
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
            List<Measure> measures = phrase.getMeasures();
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

      LyricSection lastLyricSection = null;
      int row = 0;
      int baseChordRow = 0;
      int maxChordRow = 0;
      for (SongMoment songMoment in songMoments) {
        if (lastLyricSection != songMoment.getLyricSection()) {
          if (lastLyricSection != null) {
            int rows = maxChordRow - baseChordRow + 1;
            chordSectionRows[lastLyricSection.getSectionVersion()] = rows;
            row += rows;
          }
          lastLyricSection = songMoment.getLyricSection();
          GridCoordinate sectionGridCoordinate =
          getGridCoordinate(
              new ChordSectionLocation(lastLyricSection.getSectionVersion()));

          baseChordRow = sectionGridCoordinate.row;
          maxChordRow = baseChordRow;
        }

        //  use the change of chord section rows to trigger moment grid row change
        GridCoordinate gridCoordinate = getGridCoordinate(
            songMoment.getChordSectionLocation());
        maxChordRow = max(maxChordRow, gridCoordinate.row);

        GridCoordinate momentGridCoordinate = new GridCoordinate(
            row + (gridCoordinate.row - baseChordRow), gridCoordinate.col);
        _logger.d(
            songMoment.toString() + ": " + momentGridCoordinate.toString());
        songMomentGridCoordinateHashMap[songMoment] = momentGridCoordinate;

        _logger.d("moment: " + songMoment.getMomentNumber().toString()
            + ": " + songMoment.getChordSectionLocation().toString()
            + "#" + songMoment.getSectionCount().toString()
            + " m:" + momentGridCoordinate.toString()
            + " " + songMoment.getMeasure().toMarkup()
            + (songMoment.getRepeatMax() > 1
                ? " " + (songMoment.getRepeat() + 1).toString() + "/" +
                songMoment.getRepeatMax().toString()
                : "")
        );
      }
      //  push the last one in
      if (lastLyricSection != null) {
        int rows = maxChordRow - baseChordRow + 1;
        chordSectionRows[lastLyricSection.getSectionVersion()] = rows;
      }
    }

    {
      //  install the beats to moment lookup entries
      int beat = 0;
      for (SongMoment songMoment in songMoments) {
        int limit = songMoment
            .getMeasure()
            .beatCount;
        for (int b = 0; b < limit; b++)
          beatsToMoment[beat++] = songMoment;
      }
    }
  }

  GridCoordinate getMomentGridCoordinate(SongMoment songMoment) {
    computeSongMoments();
    return songMomentGridCoordinateHashMap[songMoment];
  }

  GridCoordinate getMomentGridCoordinateFromMomentNumber(int momentNumber) {
    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null)
      return null;
    return songMomentGridCoordinateHashMap[songMoment];
  }


  void debugSongMoments() {
    computeSongMoments();

    for (SongMoment songMoment in songMoments) {
      GridCoordinate momentGridCoordinate = getMomentGridCoordinateFromMomentNumber(
          songMoment.getMomentNumber());
      _logger.d(songMoment.getMomentNumber().toString()
          + ": " + songMoment.getChordSectionLocation().toString()
          + "#" + songMoment.getSectionCount().toString()
          + " m:" + momentGridCoordinate.toString()
          + " " + songMoment.getMeasure().toMarkup()
          + (songMoment.getRepeatMax() > 1 ? " " +
              (songMoment.getRepeat() + 1).toString()
              + "/" + songMoment.repeatMax.toString() : "")
      );
    }
  }

  String songMomentMeasure(int momentNumber, Key key, int halfStepOffset) {
    computeSongMoments();
    if (momentNumber < 0 || songMoments.isEmpty ||
        momentNumber > songMoments.length - 1)
      return "";
    return songMoments[momentNumber].getMeasure().transpose(
        key, halfStepOffset);
  }

  String songNextMomentMeasure(int momentNumber, Key key, int halfStepOffset) {
    computeSongMoments();
    if (momentNumber < -1 || songMoments.isEmpty ||
        momentNumber > songMoments.length - 2)
      return "";
    return songMoments[momentNumber + 1].getMeasure().transpose(
        key, halfStepOffset);
  }

  String songMomentStatus(int beatNumber, int momentNumber) {
    computeSongMoments();
    if (songMoments.isEmpty)
      return "unknown";

    if (momentNumber < 0) {
//            beatNumber %= getBeatsPerBar();
//            if (beatNumber < 0)
//                beatNumber += getBeatsPerBar();
//            beatNumber++;
      return "count in " + (-momentNumber).toString();
    }

    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null)
      return "";

    Measure measure = songMoment.getMeasure();

    beatNumber %= measure.beatCount;
    if (beatNumber < 0)
      beatNumber += measure.beatCount;
    beatNumber++;

    String ret = songMoment.getChordSection().getSectionVersion().toString()
        + (songMoment.getRepeatMax() > 1
            ? " " + (songMoment.getRepeat() + 1).toString() + "/" +
            songMoment.getRepeatMax().toString()
            : "");

    if (appOptions.isDebug())
      ret = songMoment.getMomentNumber().toString()
          + ": " + songMoment.getChordSectionLocation().toString()
          + "#" + songMoment.getSectionCount().toString()
          + " "
          + ret.toString()
          + " b: " + (beatNumber + songMoment.getBeatNumber()).toString()
          + " = " + (beatNumber + songMoment.getSectionBeatNumber()).toString()
          + "/" + getChordSectionBeats(
          songMoment
              .getChordSectionLocation()
              .sectionVersion).toString()
          + " " + songMomentGridCoordinateHashMap[songMoment].toString()
    ;
    return ret;
  }

  /// Find the corrsesponding chord section for the given lyrics section
  ChordSection findChordSection(LyricSection lyricSection) {
    if (lyricSection == null)
      return null;
    _logger.d(
        "chordSectionMap size: " + getChordSectionMap().keys.length.toString());
    return getChordSectionMap()[lyricSection.sectionVersion];
  }

  /// Compute the duration and total beat count for the song.
  void computeDuration() {
    //  be lazy
    if (duration > 0)
      return;

    duration = 0;
    totalBeats = 0;

    List<SongMoment> moments = getSongMoments();
    if (beatsPerBar == 0 || defaultBpm == 0 || moments == null ||
        moments.isEmpty)
      return;

    for (SongMoment moment in moments) {
      totalBeats += moment
          .getMeasure()
          .beatCount;
    }
    duration = totalBeats * 60.0 / defaultBpm;
  }

  /// Find the chord section for the given section version.
  ChordSection getChordSection(SectionVersion sectionVersion) {
    return getChordSectionMap()[sectionVersion];
  }

  ChordSection getChordSectionByLocation(
      ChordSectionLocation chordSectionLocation) {
    if (chordSectionLocation == null)
      return null;
    return getChordSectionMap()[chordSectionLocation.sectionVersion];
  }

  double getLastModifiedTime() {
    return lastModifiedTime;
  }

  void setLastModifiedTime(double lastModifiedTime) {
    this.lastModifiedTime = lastModifiedTime;
  }

  String getUser() {
    return user;
  }

  void setUser(String user) {
    this.user = (user == null || user.length() <= 0) ? defaultUser : user;
  }

  List<MeasureNode> getMeasureNodes() {
    //  lazy eval
    if (measureNodes == null) {
      try {
        parseChords(chords);
      } catch (e) {
        _logger.w("unexpected: " + e.getMessage());
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
      }
      catch (e) {
        _logger.i("unexpected: " + e.getMessage().toString());
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
      if (c == '\n')
        c = ',';

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
          if ((c >= 'A' && c <= 'G') || (c >= 'a' && c <= 'g')) {
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
                for (ChordDescriptor chordDescriptor in ChordDescriptor
                    .values) {
                  cdString = chordDescriptor.toString();
                  if (cdString.length > 0 && test.startsWith(cdString)) {
                    isChordDescriptor = true;
                    break;
                  }
                }
                //  a chord descriptor makes a good partition to restart capitalization
                if (isChordDescriptor) {
                  sb.write(c.toUpperCase());
                  if (sf != null)
                    sb.write(sf);
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
              if (d >= '1' && d <= '9') {
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
          state = (c >= 'A' && c <= 'G')
              ? UpperCaseState.flatIsPossible
              : UpperCaseState.normal;
          continue; //  fall through
        case UpperCaseState.normal:
        //  reset on sequential reset characters
          if (c == ' '
              || c == '\n'
              || c == '\r'
              || c == '\t'
              || c == '/'
              || c == '/'
              || c == '.'
              || c == ','
              || c == ':'
              || c == '#'
              || c == MusicConstants.flatChar
              || c == MusicConstants.sharpChar
              || c == '['
              || c == ']'
          )
            state = UpperCaseState.initial;

          sb.write(c);
          break;
        case UpperCaseState.comment:
          sb.write(c);
          if (c == ')')
            state = UpperCaseState.initial;
          break;
      }
    }
    return sb.toString();
  }

  /**
   * Parse the current string representation of the song's chords into the song internal structures.
   */
  void parseChords(final String chords) {
    this.chords = chords; //  safety only
    measureNodes = new List();
    chordSectionMap = new HashMap();
    clearCachedValues(); //  force lazy eval

    if (chords != null) {
      _logger.f("parseChords for: " + getTitle());
      SplayTreeSet<ChordSection> emptyChordSections = new SplayTreeSet();
      MarkedString markedString = new MarkedString(chords);
      ChordSection chordSection;
      while (markedString.isNotEmpty) {
        markedString.stripLeadingWhitespace();
        if (markedString.isEmpty)
          break;
        _logger.d(markedString.toString());

        try {
          chordSection = ChordSection.parse(markedString, beatsPerBar, false);
          if (chordSection
              .getPhrases()
              .isEmpty)
            emptyChordSections.add(chordSection);
          else if (!emptyChordSections.isEmpty) {
            //  share the common measure sequence items
            for (ChordSection wasEmptyChordSection in emptyChordSections) {
              wasEmptyChordSection.setPhrases(chordSection.getPhrases());
              chordSectionMap[ wasEmptyChordSection.getSectionVersion()] =
                  wasEmptyChordSection;
            }
            emptyChordSections.clear();
          }
          measureNodes.add(chordSection);
          chordSectionMap[chordSection.getSectionVersion()] = chordSection;
          clearCachedValues();
        }
        catch (e) {
          //  try some repair
          clearCachedValues();

          _logger.d(logGrid());
          throw e;
        }
      }
      this.chords = chordsToJsonTransportString();
    }

    setDefaultCurrentChordLocation();

    _logger.d(logGrid()
    );
  }

  /// Will always return something, even if errors have to be commented out
  List<MeasureNode> parseChordEntry

      (final String entry) {
    List<MeasureNode> ret = new List();

    if (entry != null) {
      _logger.d("parseChordEntry: " + entry);
      SplayTreeSet<ChordSection> emptyChordSections = new SplayTreeSet();
      MarkedString markedString = new MarkedString(entry);
      ChordSection chordSection;
      int phaseIndex = 0;
      while (markedString.isNotEmpty) {
        markedString.stripLeadingWhitespace();
        if (markedString.isEmpty)
          break;
        _logger.d("parseChordEntry: " + markedString.toString());

        int mark = markedString.mark();

        try {
          //  if it's a full section (or multiple sections) it will all be handled here
          chordSection = ChordSection.parse(markedString, beatsPerBar, true);

          //  look for multiple sections defined at once
          if (chordSection
              .getPhrases()
              .isEmpty) {
            emptyChordSections.add(chordSection);
            continue;
          } else if (!emptyChordSections.isEmpty) {
            //  share the common measure sequence items
            for (ChordSection wasEmptyChordSection in emptyChordSections) {
              wasEmptyChordSection.setPhrases(chordSection.getPhrases());
              ret.add(wasEmptyChordSection);
            }
            emptyChordSections.clear();
          }
          ret.add(chordSection);
          continue;
        }
        catch (e) {
          markedString.resetTo(mark);
        }

        //  see if it's a complete repeat
        try {
          ret.add(
              MeasureRepeat.parse(markedString, phaseIndex, beatsPerBar, null));
          phaseIndex++;
          continue;
        }
        catch (e) {
          markedString.resetTo(mark);
        }
        //  see if it's a phrase
        try {
          ret.add(Phrase.parse(markedString, phaseIndex, beatsPerBar,
              getCurrentChordSectionLocationMeasure()));
          phaseIndex++;
          continue;
        }
        catche(e) {
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
        }
        catch (e) {
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
      for (Phrase phrase in chordSection.getPhrases()) {
        bool hasEndOfRow = false;
        for (Measure measure in phrase.getMeasures()) {
          if (measure.isComment())
            continue;
          if (measure.endOfRow) {
            hasEndOfRow = true;
            break;
          }
        }
        if (!hasEndOfRow && phrase.length >= 8) {
          int i = 0;
          for (Measure measure in phrase.getMeasures()) {
            if (measure.isComment())
              continue;
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
    if (sortedChordSections.isEmpty)
      return;

    ChordSection chordSection = sortedChordSections.last;
    if (chordSection != null) {
      List<Phrase> measureSequenceItems = chordSection.getPhrases();
      if (measureSequenceItems != null && measureSequenceItems.isNotEmpty) {
        Phrase lastPhrase = measureSequenceItems[ measureSequenceItems.length -
            1];
        currentChordSectionLocation =
        new ChordSectionLocation(chordSection.sectionVersion,
            phraseIndex: measureSequenceItems.length - 1,
            measureIndex: lastPhrase.length - 1);
      }
    }
  }

  void calcChordMaps() {
    getChordSectionLocationGrid(); //  use location grid to force them all in lazy eval
  }

  HashMap<GridCoordinate,
      ChordSectionLocation> getGridCoordinateChordSectionLocationMap() {
    getChordSectionLocationGrid();
    return gridCoordinateChordSectionLocationMap;
  }

  HashMap<ChordSectionLocation,
      GridCoordinate> getGridChordSectionLocationCoordinateMap() {
    getChordSectionLocationGrid();
    return gridChordSectionLocationCoordinateMap;
  }

  int getChordSectionLocationGridMaxColCount() {
    int maxCols = 0;
    for (GridCoordinate gridCoordinate in getGridCoordinateChordSectionLocationMap()
        .keySet()) {
      maxCols = max(maxCols, gridCoordinate.col);
    }
    return maxCols;
  }

  Grid<ChordSectionLocation> getChordSectionLocationGrid() {
    //  support lazy eval
    if (chordSectionLocationGrid != null)
      return chordSectionLocationGrid;

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
      SectionVersion sectionVersion = chordSection.getSectionVersion();

      //  only do a chord section once.  it might have a duplicate set of phrases and already be listed
      if (!sectionVersionsToDo.contains(sectionVersion))
        continue;
      sectionVersionsToDo.remove(sectionVersion);

      //  start each section on it's own line
      if (col != offset) {
        row++;
      }
      col = 0;

      _logger.d(
          "gridding: " + sectionVersion.toString() + " (" + col.toString() +
              ", " + row.toString() + ")");

      {
        //  grid the section header
        SplayTreeSet<
            SectionVersion> matchingSectionVersions = matchingSectionVersions(
            sectionVersion);
        GridCoordinate coordinate = new GridCoordinate(row, col);
        for (SectionVersion matchingSectionVersion in matchingSectionVersions) {
          chordSectionGridCoorinateMap.put(matchingSectionVersion, coordinate);
          ChordSectionLocation loc = new ChordSectionLocation(
              matchingSectionVersion);
          gridChordSectionLocationCoordinateMap.put(loc, coordinate);
        }
        for (SectionVersion matchingSectionVersion in matchingSectionVersions) {
          //  don't add identity mapping
          if (matchingSectionVersion == sectionVersion)
            continue;
          chordSectionGridMatches[matchingSectionVersion] = sectionVersion;
        }

        ChordSectionLocation loc = new ChordSectionLocation
            .byMultipleSectionVersion(matchingSectionVersions);
        gridCoordinateChordSectionLocationMap.put(coordinate, loc);
        gridChordSectionLocationCoordinateMap.put(loc, coordinate);
        grid.set(col, row, loc);
        col = offset;
        sectionVersionsToDo.removeAll(matchingSectionVersions);
      }

      //  allow for empty sections... on entry
      if (chordSection
          .getPhrases()
          .isEmpty) {
        row++;
        col = offset;
      } else {
        //  grid each phrase
        for (int phraseIndex = 0; phraseIndex < chordSection
            .getPhrases()
            .length; phraseIndex++) {
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
          int phraseSize = phrase
              .getMeasures()
              .length;
          if (phraseSize == 0 && phrase.isRepeat()) {
            //  special case: deal with empty repeat
            //  fill row to measures per line
            col = offset + measuresPerline - 1;
            {
              //  add repeat indicator
              ChordSectionLocation loc = new ChordSectionLocation(
                  sectionVersion, phraseIndex: phraseIndex);
              GridCoordinate coordinate = new GridCoordinate(row, col);
              gridCoordinateChordSectionLocationMap[coordinate] = loc;
              gridChordSectionLocationCoordinateMap[loc] = coordinate;
              grid.set(col++, row, loc);
            }
          } else {
            Measure measure = null;

            //  compute the max number of columns for this phrase
            int maxCol = offset;
            {
              int currentCol = offset;
              for (int measureIndex = 0; measureIndex <
                  phraseSize; measureIndex++) {
                measure = phrase.getMeasure(measureIndex);
                if (measure.isComment()) //  comments get their own row
                  continue;
                currentCol++;
                if (measure.endOfRow) {
                  if (currentCol > maxCol)
                    maxCol = currentCol;
                  currentCol = offset;
                }
              }
              if (currentCol > maxCol)
                maxCol = currentCol;
              maxCol = min(maxCol, measuresPerline + 1);
            }

            //  place each measure in the grid
            Measure lastMeasure = null;
            for (int measureIndex = 0; measureIndex <
                phraseSize; measureIndex++) {
              //  place comments on their own line
              //  don't upset the col location
              //  expect the output to span the row
              measure = phrase.getMeasure(measureIndex);
              if (measure.isComment()) {
                if (col > offset && lastMeasure != null &&
                    !lastMeasure.isComment())
                  row++;
                ChordSectionLocation loc = new ChordSectionLocation(
                    sectionVersion, phraseIndex: phraseIndex,
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


              if ((lastMeasure != null && lastMeasure.endOfRow)
                  || col >= offset +
                      measuresPerline //  limit line length to the measures per line
              ) {
                //  fill the row with nulls if the row is shorter then the others in this phrase
                while (col < maxCol)
                  grid.set(col++, row, null);

                //  put an end of line marker on multiline repeats
                if (phrase.isRepeat()) {
                  grid.set(col++, row,
                      new ChordSectionLocation.withMarker(
                          sectionVersion, phraseIndex,
                          (repeatExtensionUsed
                              ? ChordSectionLocationMarker.repeatMiddleRight
                              : ChordSectionLocationMarker.repeatUpperRight
                          )));
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
                    sectionVersion, phraseIndex: phraseIndex,
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
                  ChordSectionLocation loc = new ChordSectionLocation
                      .withMarker(
                      sectionVersion, phraseIndex,
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
                      sectionVersion, phraseIndex: phraseIndex);
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

    if (true) {
      _logger.d("gridCoordinateChordSectionLocationMap: ");
      SplayTreeSet set = SplayTreeSet<GridCoordinate>();
      set.addAll(gridCoordinateChordSectionLocationMap.keys);
      for (GridCoordinate coordinate in set) {
        _logger.d(" " + coordinate.toString()
            + " " + gridCoordinateChordSectionLocationMap[coordinate].toString()
            + " -> " + findMeasureNodeByLocation(
            gridCoordinateChordSectionLocationMap[coordinate]).toMarkup()
        )
        ;
      }
    }

    chordSectionLocationGrid = grid;
    _logger.d(grid.toString());
    return chordSectionLocationGrid;
  }

  /// Find all matches to the given section version, including the given section version itself
  SplayTreeSet<SectionVersion> matchingSectionVersions(
      SectionVersion multSectionVersion) {
    SplayTreeSet<SectionVersion> ret = new SplayTreeSet();
    if (multSectionVersion == null)
      return ret;
    ChordSection multChordSection = findChordSection(multSectionVersion);
    if (multChordSection == null)
      return ret;

    for (ChordSection chordSection in new SplayTreeSet<>(
        getChordSectionMap().values())) {
      if (multSectionVersion.equals(chordSection.getSectionVersion()))
        ret.add(multSectionVersion);
      else
      if (chordSection.getPhrases().equals(multChordSection.getPhrases())) {
        ret.add(chordSection.getSectionVersion());
      }
    }
    return
      ret;
  }

  ChordSectionLocation getLastChordSectionLocation() {
    Grid<ChordSectionLocation> grid = getChordSectionLocationGrid();
    if (grid == null || grid.isEmpty())
      return null;
    List<ChordSectionLocation> row = grid.getRow(grid.getRowCount() - 1);
    return grid.get(grid.getRowCount() - 1, row.length - 1);
  }

  HashMap<SectionVersion, GridCoordinate> getChordSectionGridCoorinateMap() {
    // force grid population from lazy eval
    if (chordSectionLocationGrid == null)
      getChordSectionLocationGrid();
    return chordSectionGridCoorinateMap;
  }

  final void clearCachedValues

  () {
  chordSectionLocationGrid = null;
  complexity = 0;
  chordsAsMarkup = null;
  songMoments.clear();
  duration = 0;
  totalBeats = 0;
  }


  String chordsToJsonTransportString

      () {
    StringBuilder sb = new StringBuilder();

    for (ChordSection chordSection in new SplayTreeSet<>(
        getChordSectionMap().values())) {
      sb.append(chordSection.toJson());
    }
    return sb.toString();
  }

  String toMarkup

      () {
    if (chordsAsMarkup != null)
      return chordsAsMarkup;

    StringBuilder sb = new StringBuilder();

    SplayTreeSet<SectionVersion> sortedSectionVersions = new SplayTreeSet<>(
        getChordSectionMap().keySet());
    SplayTreeSet<SectionVersion> completedSectionVersions = new SplayTreeSet();


//  markup by section version order
    for (SectionVersion sectionVersion in sortedSectionVersions) {
//  don't repeat anything
      if (completedSectionVersions.contains(sectionVersion))
        continue;
      completedSectionVersions.add(sectionVersion);

//  find all section versions with the same chords
      ChordSection chordSection = getChordSectionMap().get(sectionVersion);
      if (chordSection.isEmpty()) {
//  empty sections stand alone
        sb.append(sectionVersion.toString());
        sb.append(" ");
      } else {
        SplayTreeSet<
            SectionVersion> currentSectionVersions = new SplayTreeSet();
        for (SectionVersion otherSectionVersion in sortedSectionVersions) {
          if (chordSection.getPhrases().equals(
              getChordSectionMap().get(otherSectionVersion).getPhrases())) {
            currentSectionVersions.add(otherSectionVersion);
            completedSectionVersions.add(otherSectionVersion);
          }
        }

//  list the section versions for this chord section
        for (SectionVersion currentSectionVersion in currentSectionVersions) {
          sb.append(currentSectionVersion.toString());
          sb.append(" ");
        }
      }

//  chord section phrases (only) to output
      sb.append(chordSection.phrasesToMarkup());
      sb.append(" "); //  for human readability only
    }
    chordsAsMarkup = sb.toString();
    return chordsAsMarkup;
  }

  String toMarkup

      (ChordSectionLocation location) {
    StringBuilder sb = new StringBuilder();
    if (location != null) {
      if (location.isSection()) {
        sb.append(location.toString());
        sb.append(" ");
        sb.append(getChordSection(location).phrasesToMarkup());
        return sb.toString();
      } else {
        MeasureNode measureNode = findMeasureNodeByLocation(location);
        if (measureNode != null)
          return measureNode.toMarkup();
      }
    }
    return null;
  }

  String toEntry

      (ChordSectionLocation location) {
    StringBuilder sb = new StringBuilder();
    if (location != null) {
      if (location.isSection()) {
        sb.append(getChordSection(location).transposeToKey(key).toEntry());
        return sb.toString();
      } else {
        MeasureNode measureNode = findMeasureNodeByLocation(location);
        if (measureNode != null)
          return measureNode.transposeToKey(key).toEntry();
      }
    }
    return null;
  }

  /**
   * Add the given section version to the song chords
   *
   * @param sectionVersion the given section to add
   * @return true if the section version was added
   */
  final bool addSectionVersion

  (

  SectionVersion sectionVersion

  ) {
  if (sectionVersion == null || getChordSectionMap().containsKey(sectionVersion))
  return false;
  getChordSectionMap().put(sectionVersion, new ChordSection(sectionVersion));
  clearCachedValues();
  setCurrentChordSectionLocation(new ChordSectionLocation(sectionVersion));
  setCurrentMeasureEditType(MeasureEditType.append);
  return true;
  }


  final bool deleteCurrentChordSectionLocation

  () {

  setCurrentMeasureEditType(MeasureEditType.delete); //  tell the world

  preMod(null);

//  deal with deletes
  ChordSectionLocation location = getCurrentChordSectionLocation();


//  find the named chord section
  ChordSection chordSection = getChordSection(location);
  if (chordSection == null) {
  postMod();
  return false;
  }

  if (chordSection.getPhrases().isEmpty()) {
  chordSection.getPhrases().add(new Phrase(new List(), 0));
  }

  Phrase phrase;
  try {
  phrase = chordSection.getPhrase(location.getPhraseIndex());
  } catch (IndexOutOfBoundsException iob) {
  phrase = chordSection.getPhrases().get(0); //  use the default empty list
  }

  bool ret = false;

  if (location.isMeasure()) {
  ret = phrase.edit(MeasureEditType.delete, location.getMeasureIndex(), null);
  if (ret && phrase.isEmpty())
  return deleteCurrentChordSectionPhrase();
  } else if (location.isPhrase()) {
  return deleteCurrentChordSectionPhrase();
  } else if (location.isSection()) {
//  find the section prior to the one being deleted
  SplayTreeSet<SectionVersion> sortedSectionVersions = new SplayTreeSet<>(getChordSectionMap().keySet());
  SectionVersion nextSectionVersion = sortedSectionVersions.lower(chordSection.getSectionVersion());
  ret = (getChordSectionMap().remove(chordSection.getSectionVersion()) != null);
  if (ret) {
//  move deleted current to end of previous section
  if (nextSectionVersion == null) {
  sortedSectionVersions = new SplayTreeSet<>(getChordSectionMap().keySet());
  nextSectionVersion = (sortedSectionVersions.isEmpty() ? null : sortedSectionVersions.first());
  }
  if (nextSectionVersion != null) {
  location = findChordSectionLocation(getChordSectionMap().get(nextSectionVersion));
  }
  }
  }
  return standardEditCleanup(ret, location);
  }

  final bool deleteCurrentChordSectionPhrase

  () {
  ChordSectionLocation location = getCurrentChordSectionLocation();
  ChordSection chordSection = getChordSection(location);
  bool ret = chordSection.deletePhrase(location.getPhraseIndex());
  if (ret) {
//  move the current location if required
  if (location.getPhraseIndex() >= chordSection.getPhrases().length) {
  if (chordSection.getPhrases().isEmpty())
  location = new ChordSectionLocation(chordSection.getSectionVersion());
  else {
  int i = chordSection.getPhrases().length - 1;
  Phrase phrase = chordSection.getPhrase(i);
  int m = phrase.getMeasures().length - 1;
  location = new ChordSectionLocation(chordSection.getSectionVersion(), i, m);
  }
  }
  }
  return standardEditCleanup(ret, location);
  }

  final void preMod

  (

  MeasureNode measureNode

  ) {
  _logger.d("startingChords(\"" + toMarkup() + "\");");
  _logger.d(" pre(MeasureEditType." + getCurrentMeasureEditType().name()
  + ", \"" + getCurrentChordSectionLocation().toString() + "\""
  + ", \""
  + (getCurrentChordSectionLocationMeasureNode() == null
  ? "null"
      : getCurrentChordSectionLocationMeasureNode().toMarkup()) + "\""
  + ", \"" + (measureNode == null ? "null" : measureNode.toMarkup()) + "\");");
  }

  final void postMod

  () {
  _logger.d("resultChords(\"" + toMarkup() + "\");");
  _logger.d("post(MeasureEditType." + getCurrentMeasureEditType().name()
  + ", \"" + getCurrentChordSectionLocation().toString() + "\""
  + ", \"" + (getCurrentChordSectionLocationMeasureNode() == null
  ? "null"
      : getCurrentChordSectionLocationMeasureNode().toMarkup())
  + "\");");
  }


  final bool edit

  (

  List<MeasureNode> measureNodes

  ) {
  if (measureNodes == null || measureNodes.isEmpty())
  return false;

  for (MeasureNode measureNode in measureNodes) {
  if (!edit(measureNode))
  return false;
  }
  return true;
  }

  final bool deleteCurrentSelection

  () {
  setCurrentMeasureEditType(MeasureEditType.delete);
  return edit((MeasureNode) null);
  }

  /**
   * Edit the given measure in or out of the song based on the data from the edit location.
   *
   * @param measureNode the measure in question
   * @return true if the edit was performed
   */
  final bool edit

  (

  MeasureNode measureNode

  ) {
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
  ChordSection chordSection = getChordSection(location);
  if (chordSection == null) {
  switch (measureNode.getMeasureNodeType()) {
  case section:
  chordSection = (ChordSection) measureNode;
  break;
  default:
  chordSection = getChordSectionMap().get(SectionVersion.getDefault());
  if (chordSection == null) {
  chordSection = ChordSection.getDefault();
  getChordSectionMap().put(chordSection.getSectionVersion(), chordSection);
  }
  break;
  }
  }

//  default to insert if empty
  if (chordSection.getPhrases().isEmpty()) {
  chordSection.getPhrases().add(new Phrase(new List(), 0));
//fixme?  editType = MeasureEditType.insert;
  }

  Phrase phrase = null;
  try {
  phrase = chordSection.getPhrase(location.getPhraseIndex());
  } catch (Exception iob) {
  if (!chordSection.isEmpty())
  phrase = chordSection.getPhrases().get(0); //  use the default empty list
  }

  bool ret = false;

//  handle situations by the type of measure node being added
  ChordSectionLocation newLocation;
  ChordSection newChordSection;
  MeasureRepeat newRepeat;
  Phrase newPhrase;
  switch (measureNode.getMeasureNodeType()) {
  case section:
  switch (editType) {
  default:
//  all sections replace themselves
  newChordSection = (ChordSection) measureNode;
  getChordSectionMap().put(newChordSection.getSectionVersion(), newChordSection);
  ret = true;
  location = new ChordSectionLocation(newChordSection.getSectionVersion());
  break;
  case delete:
//  find the section prior to the one being deleted
  SplayTreeSet<SectionVersion> sortedSectionVersions = new SplayTreeSet<>(getChordSectionMap().keySet());
  SectionVersion nextSectionVersion = sortedSectionVersions.lower(chordSection.getSectionVersion());
  ret = (getChordSectionMap().remove(chordSection.getSectionVersion()) != null);
  if (ret) {
//  move deleted current to end of previous section
  if (nextSectionVersion == null) {
  sortedSectionVersions = new SplayTreeSet<>(getChordSectionMap().keySet());
  nextSectionVersion = sortedSectionVersions.first();
  }
  if (nextSectionVersion != null) {
  location = new ChordSectionLocation(nextSectionVersion);
  } else
  ;// fixme: set location to empty location
  }
  break;
  }
  return standardEditCleanup(ret, location);

  case repeat:
  newRepeat = (MeasureRepeat) measureNode;
  if (newRepeat.isEmpty()) {
//  empty repeat
  if (phrase.isRepeat()) {
//  change repeats
  MeasureRepeat repeat = (MeasureRepeat) phrase;
  if (newRepeat.getRepeats() < 2) {
  setCurrentMeasureEditType(MeasureEditType.append);

//  convert repeat to phrase
  newPhrase = new Phrase(repeat.getMeasures(), location.getPhraseIndex());
  int phaseIndex = location.getPhraseIndex();
  if (phaseIndex > 0 && chordSection.getPhrase(phaseIndex - 1).getMeasureNodeType() == MeasureNode.MeasureNodeType.phrase) {

//  expect combination of the two phrases
  Phrase priorPhrase = chordSection.getPhrase(phaseIndex - 1);
  location = new ChordSectionLocation(chordSection.getSectionVersion(),
  phaseIndex - 1, priorPhrase.getMeasures().length + newPhrase.getMeasures().length - 1);
  return standardEditCleanup(chordSection.deletePhrase(phaseIndex)
  && chordSection.add(phaseIndex, newPhrase), location);
  }
  location = new ChordSectionLocation(chordSection.getSectionVersion(),
  location.getPhraseIndex(), newPhrase.getMeasures().length - 1);
  _logger.d("new loc: " + location.toString());
  return standardEditCleanup(chordSection.deletePhrase(newPhrase.getPhraseIndex())
  && chordSection.add(newPhrase.getPhraseIndex(), newPhrase), location);
  }
  repeat.setRepeats(newRepeat.getRepeats());
  return standardEditCleanup(true, location);
  }
  if (newRepeat.getRepeats() <= 1)
  return true; //  no change but no change was asked for

  if (!phrase.isEmpty()) {
//  convert phrase line to a repeat
  GridCoordinate minGridCoordinate = getGridCoordinate(location);
  minGridCoordinate = new GridCoordinate(minGridCoordinate.row, 1);
  MeasureNode minMeasureNode = findMeasureNodeByGrid(minGridCoordinate);
  ChordSectionLocation minLocation = getChordSectionLocation(minGridCoordinate);
  GridCoordinate maxGridCoordinate = getGridCoordinate(location);
  maxGridCoordinate = new GridCoordinate(maxGridCoordinate.row, chordSectionLocationGrid.getRow(maxGridCoordinate.getRow()).length - 1);
  MeasureNode maxMeasureNode = findMeasureNodeByGrid(maxGridCoordinate);
  ChordSectionLocation maxLocation = getChordSectionLocation(maxGridCoordinate);
  _logger.d("min: " + minGridCoordinate.toString() + " " + minMeasureNode.toMarkup() + " " + minLocation.getMeasureIndex());
  _logger.d("max: " + maxGridCoordinate.toString() + " " + maxMeasureNode.toMarkup() + " " + maxLocation.getMeasureIndex());

//  delete the old
  int phraseIndex = phrase.getPhraseIndex();
  chordSection.deletePhrase(phraseIndex);
//  replace the old early part
  if (minLocation.getMeasureIndex() > 0) {
  chordSection.add(phraseIndex, new Phrase(phrase.getMeasures().subList(0, minLocation.getMeasureIndex()),
  phraseIndex));
  phraseIndex++;
  }
//  replace the sub-phrase with a repeat
      {
  MeasureRepeat repeat = new MeasureRepeat(phrase.getMeasures().subList(minLocation.getMeasureIndex(),
  maxLocation.getMeasureIndex() + 1), phraseIndex, newRepeat.getRepeats());
  chordSection.add(phraseIndex, repeat);
  location = new ChordSectionLocation(chordSection.getSectionVersion(), phraseIndex);
  phraseIndex++;
  }
//  replace the old late part
  if (maxLocation.getMeasureIndex() < phrase.getMeasures().length - 1) {
  chordSection.add(phraseIndex, new Phrase(
  phrase.getMeasures().subList(maxLocation.getMeasureIndex() + 1, phrase.getMeasures().length),
  phraseIndex));
//phraseIndex++;
  }
  return standardEditCleanup(true, location);
  }
  } else {
  newPhrase = newRepeat;

//  demote x1 repeat to phrase
  if (newRepeat.getRepeats() < 2)
  newPhrase = new Phrase(newRepeat.getMeasures(), newRepeat.getPhraseIndex());

//  non-empty repeat
  switch (editType) {
  case delete:
  return standardEditCleanup(chordSection.deletePhrase(phrase.getPhraseIndex()), location);
  case append:
  newPhrase.setPhraseIndex(phrase.getPhraseIndex() + 1);
  return standardEditCleanup(chordSection.add(phrase.getPhraseIndex() + 1, newPhrase),
  new ChordSectionLocation(chordSection.getSectionVersion(), phrase.getPhraseIndex() + 1));
  case insert:
  newPhrase.setPhraseIndex(phrase.getPhraseIndex());
  return standardEditCleanup(chordSection.add(phrase.getPhraseIndex(), newPhrase), location);
  case replace:
  newPhrase.setPhraseIndex(phrase.getPhraseIndex());
  return standardEditCleanup(chordSection.deletePhrase(phrase.getPhraseIndex())
  && chordSection.add(newPhrase.getPhraseIndex(), newPhrase), location);
  }
  }
  break;

  case phrase:
  newPhrase = (Phrase) measureNode;
  int phaseIndex = 0;
  switch (editType) {
  case append:
  if (location == null) {
  if (chordSection.getPhraseCount() == 0) {
//  append as first phrase
  location = new ChordSectionLocation(chordSection.getSectionVersion(), 0, newPhrase.length - 1);
  newPhrase.setPhraseIndex(phaseIndex);
  return standardEditCleanup(chordSection.add(phaseIndex, newPhrase), location);
  }

//  last of section
  Phrase lastPhrase = chordSection.lastPhrase();
  switch (lastPhrase.getMeasureNodeType()) {
  case phrase:
  location = new ChordSectionLocation(chordSection.getSectionVersion(),
  lastPhrase.getPhraseIndex(), lastPhrase.length + newPhrase.length - 1);
  return standardEditCleanup(lastPhrase.add(newPhrase.getMeasures()), location);
  }
  phaseIndex = chordSection.getPhraseCount();
  location = new ChordSectionLocation(chordSection.getSectionVersion(), phaseIndex, lastPhrase.length);
  newPhrase.setPhraseIndex(phaseIndex);
  return standardEditCleanup(chordSection.add(phaseIndex, newPhrase), location);
  }
  if (chordSection.isEmpty()) {
  location = new ChordSectionLocation(chordSection.getSectionVersion(), phaseIndex, newPhrase.length - 1);
  newPhrase.setPhraseIndex(phaseIndex);
  return standardEditCleanup(chordSection.add(phaseIndex, newPhrase), location);
  }

  if (location.hasMeasureIndex()) {
  newLocation = new ChordSectionLocation(chordSection.getSectionVersion(),
  phrase.getPhraseIndex(), location.getMeasureIndex() + newPhrase.length);
  return standardEditCleanup(phrase.edit(editType, location.getMeasureIndex(), newPhrase), newLocation);
  }
  if (location.hasPhraseIndex()) {
  phaseIndex = location.getPhraseIndex() + 1;
  newLocation = new ChordSectionLocation(chordSection.getSectionVersion(), phaseIndex, newPhrase.length - 1);
  return standardEditCleanup(chordSection.add(phaseIndex, newPhrase), newLocation);
  }
  newLocation = new ChordSectionLocation(chordSection.getSectionVersion(),
  phrase.getPhraseIndex(), phrase.getMeasures().length + newPhrase.length - 1);
  return standardEditCleanup(phrase.add(newPhrase.getMeasures()), newLocation);

  case insert:
  if (location == null) {
  if (chordSection.getPhraseCount() == 0) {
//  append as first phrase
  location = new ChordSectionLocation(chordSection.getSectionVersion(), 0, newPhrase.length - 1);
  newPhrase.setPhraseIndex(phaseIndex);
  return standardEditCleanup(chordSection.add(phaseIndex, newPhrase), location);
  }

//  first of section
  Phrase firstPhrase = chordSection.getPhrase(0);
  switch (firstPhrase.getMeasureNodeType()) {
  case phrase:
  location = new ChordSectionLocation(chordSection.getSectionVersion(),
  firstPhrase.getPhraseIndex(), 0);
  return standardEditCleanup(firstPhrase.add(newPhrase.getMeasures()), location);
  }

  phaseIndex = 0;
  location = new ChordSectionLocation(chordSection.getSectionVersion(), phaseIndex, firstPhrase.length);
  newPhrase.setPhraseIndex(phaseIndex);
  return standardEditCleanup(chordSection.add(phaseIndex, newPhrase), location);
  }
  if (chordSection.isEmpty()) {
  location = new ChordSectionLocation(chordSection.getSectionVersion(), phaseIndex, newPhrase.length - 1);
  newPhrase.setPhraseIndex(phaseIndex);
  return standardEditCleanup(chordSection.add(phaseIndex, newPhrase), location);
  }

  if (location.hasMeasureIndex()) {
  newLocation = new ChordSectionLocation(chordSection.getSectionVersion(),
  phrase.getPhraseIndex(), location.getMeasureIndex() + newPhrase.length - 1);
  return standardEditCleanup(phrase.edit(editType, location.getMeasureIndex(), newPhrase), newLocation);
  }

//  insert new phrase in front of existing phrase
  newLocation = new ChordSectionLocation(chordSection.getSectionVersion(),
  phrase.getPhraseIndex(), newPhrase.length - 1);
  return standardEditCleanup(phrase.add(0, newPhrase.getMeasures()), newLocation);
  case replace:
  if (location != null) {
  if (location.hasPhraseIndex()) {
  if (location.hasMeasureIndex()) {
  newLocation = new ChordSectionLocation(chordSection.getSectionVersion(), phaseIndex,
  location.getMeasureIndex() + newPhrase.length - 1);
  return standardEditCleanup(phrase.edit(
  editType, location.getMeasureIndex(), newPhrase), newLocation);
  }
//  delete the phrase before replacing it
  phaseIndex = location.getPhraseIndex();
  if (phaseIndex > 0 && chordSection.getPhrase(phaseIndex - 1).getMeasureNodeType() == MeasureNode.MeasureNodeType.phrase) {
//  expect combination of the two phrases
  Phrase priorPhrase = chordSection.getPhrase(phaseIndex - 1);
  location = new ChordSectionLocation(chordSection.getSectionVersion(),
  phaseIndex - 1, priorPhrase.getMeasures().length + newPhrase.getMeasures().length);
  return standardEditCleanup(chordSection.deletePhrase(phaseIndex)
  && chordSection.add(phaseIndex, newPhrase), location);
  } else {
  location = new ChordSectionLocation(chordSection.getSectionVersion(),
  phaseIndex, newPhrase.getMeasures().length - 1);
  return standardEditCleanup(chordSection.deletePhrase(phaseIndex)
  && chordSection.add(phaseIndex, newPhrase), location);
  }
  }
  break;
  }
  phaseIndex = (location != null && location.hasPhraseIndex() ? location.getPhraseIndex() : 0);
  break;
  default:
  phaseIndex = (location != null && location.hasPhraseIndex() ? location.getPhraseIndex() : 0);
  break;
  }
  newPhrase.setPhraseIndex(phaseIndex);
  location = new ChordSectionLocation(chordSection.getSectionVersion(), phaseIndex, newPhrase.length - 1);
  return standardEditCleanup(chordSection.add(phaseIndex, newPhrase), location);

  case measure:
  case comment:
//  add measure to current phrase
  if (location.hasMeasureIndex()) {
  newLocation = location;
  switch (editType) {
  case append:
  newLocation = location.nextMeasureIndexLocation();
  break;
  }
  return standardEditCleanup(phrase.edit(editType, newLocation.getMeasureIndex(), measureNode), newLocation);
  }

//  add measure to chordSection by creating a new phase
  if (location.hasPhraseIndex()) {
  List<Measure> measures = new List();
  measures.add((Measure) measureNode);
  newPhrase = new Phrase(measures, location.getPhraseIndex());
  switch (editType) {
  case delete:
  break;
  case append:
  newPhrase.setPhraseIndex(phrase.getPhraseIndex());
  return standardEditCleanup(chordSection.add(phrase.getPhraseIndex(), newPhrase),
  location.nextMeasureIndexLocation());
  case insert:
  newPhrase.setPhraseIndex(phrase.getPhraseIndex());
  return standardEditCleanup(chordSection.add(phrase.getPhraseIndex(), newPhrase), location);
  case replace:
  newPhrase.setPhraseIndex(phrase.getPhraseIndex());
  return standardEditCleanup(chordSection.deletePhrase(phrase.getPhraseIndex())
  && chordSection.add(newPhrase.getPhraseIndex(), newPhrase), location);
  }
  }
  break;
  }


//  edit measure node into location
  switch (editType) {
  case insert:
  switch (measureNode.getMeasureNodeType()) {
  case repeat:
  case phrase:
  ret = chordSection.insert(location.getPhraseIndex(), measureNode);
  break;
  }
//  no location change
  standardEditCleanup(ret, location);
  break;

  case append:
//  promote marker to repeat
  try {
  Measure refMeasure = phrase.getMeasure(location.getMeasureIndex());
  if (refMeasure instanceof MeasureRepeatMarker && phrase.isRepeat()) {
  MeasureRepeat measureRepeat = (MeasureRepeat) phrase;
  if (refMeasure == measureRepeat.getRepeatMarker()) {
//  appending at the repeat marker forces the section to add a sequenceItem list after the repeat
  int phraseIndex = chordSection.indexOf(measureRepeat) + 1;
  newPhrase = new Phrase(new List(), phraseIndex);
  chordSection.getPhrases().add(phraseIndex, newPhrase);
  phrase = newPhrase;
  }
  }
  } catch (IndexOutOfBoundsException iob) {
//  ignore attempt
  }

  if (location.isSection()) {
  switch (measureNode.getMeasureNodeType()) {
  case section:
  SectionVersion sectionVersion = location.getSectionVersion();
  return standardEditCleanup((getChordSectionMap().put(sectionVersion,
  (ChordSection) measureNode) != null), location.nextMeasureIndexLocation());
  case phrase:
  case repeat:
  return standardEditCleanup(chordSection.add(location.getPhraseIndex(),
  (Phrase) measureNode), location);
  }
  }
  if (location.isPhrase()) {
  switch (measureNode.getMeasureNodeType()) {
  case repeat:
  case phrase:
  chordSection.getPhrases().add(location.getPhraseIndex(), (Phrase) measureNode);
  return standardEditCleanup(true, location);
  }
  break;
  }

  break;

  case delete:
//  note: measureNode is ignored, and should be ignored
  if (location.isMeasure()) {
  ret = (phrase.delete(location.getMeasureIndex()) != null);
  if (ret) {
  if (location.getMeasureIndex() < phrase.length) {
  location = new ChordSectionLocation(chordSection.getSectionVersion(), location.getPhraseIndex(), location.getMeasureIndex());
  measureNode = findMeasureNodeByLocation(location);
  } else {
  if (phrase.length > 0) {
  int index = phrase.length - 1;
  location = new ChordSectionLocation(chordSection.getSectionVersion(), location.getPhraseIndex(), index);
  measureNode = findMeasureNodeByLocation(location);
  } else {
  chordSection.deletePhrase(location.getPhraseIndex());
  if (chordSection.getPhraseCount() > 0) {
  location = new ChordSectionLocation(chordSection.getSectionVersion(), 0, chordSection.getPhrase(0).length - 1);
  measureNode = findMeasureNodeByLocation(location);
  } else {
//  last phase was deleted
  location = new ChordSectionLocation(chordSection.getSectionVersion());
  measureNode = findMeasureNodeByLocation(location);
  }
  }
  }
  }
  } else if (location.isPhrase()) {
  ret = chordSection.deletePhrase(location.getPhraseIndex());
  if (ret) {
  if (location.getPhraseIndex() > 0) {
  int index = location.getPhraseIndex() - 1;
  location = new ChordSectionLocation(chordSection.getSectionVersion(), index, chordSection.getPhrase(index).length - 1);
  measureNode = findMeasureNodeByLocation(location);
  } else if (chordSection.getPhraseCount() > 0) {
  location = new ChordSectionLocation(chordSection.getSectionVersion(), 0, chordSection.getPhrase(0).length - 1);
  measureNode = findMeasureNodeByLocation(location);
  } else {
//  last one was deleted
  location = new ChordSectionLocation(chordSection.getSectionVersion());
  measureNode = findMeasureNodeByLocation(location);
  }
  }
  } else if (location.isSection()) {

  }
  standardEditCleanup(ret, location);
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
    if (location == null)
      return;
    ChordSection chordSection = getChordSectionMap()[location.sectionVersion];
    if (chordSection == null)
      return;
    int limit = chordSection.getPhraseCount();
    Phrase lastPhrase = null;
    for (int i = 0; i < limit; i++) {
      Phrase phrase = chordSection.getPhrase(i);
      if (lastPhrase == null) {
        if (phrase.getMeasureNodeType() == MeasureNode.MeasureNodeType.phrase)
          lastPhrase = phrase;
        continue;
      }
      if (phrase.getMeasureNodeType() == MeasureNode.MeasureNodeType.phrase) {
        if (lastPhrase != null) {
//  two contiguous phrases: join
          lastPhrase.add(phrase.getMeasures());
          chordSection.deletePhrase(i);
          limit--; //  one less index
        }
        lastPhrase = phrase;
      } else
        lastPhrase = null;
    }
  }

  /**
   * Find the measure sequence item for the given measure (i.e. the measure's parent container).
   *
   * @param measure the measure referenced
   * @return the measure's sequence item
   */
  Phrase findPhrase(Measure measure) {
    if (measure == null)
      return null;

    ChordSection chordSection = findChordSectionByMeasure(measure);
    if (chordSection == null)
      return null;
    for (Phrase msi in chordSection.getPhrases()) {
      for (Measure m in msi.getMeasures())
        if (m == measure)
          return msi;
    }
    return null;
  }

  ///Find the chord section for the given measure node.
  ChordSection findChordSectionByMeasure(MeasureNode measureNode) {
    if (measureNode == null)
      return null;

    String id = measureNode.getId();
    for (ChordSection chordSection in getChordSectionMap().values) {
      if (id != null && id == chordSection.getId())
        return chordSection;
      MeasureNode mn = chordSection.findMeasureNode(measureNode);
      if (mn != null)
        return chordSection;
    }
    return null;
  }

  ChordSectionLocation findChordSectionLocation(MeasureNode measureNode) {
    if (measureNode == null)
      return null;

    Phrase phrase;
    try {
      ChordSection chordSection = findChordSection(measureNode);
      switch (measureNode.getMeasureNodeType()) {
        case MeasureNodeType.section:
          return new ChordSectionLocation(chordSection.getSectionVersion());
        case MeasureNodeType.repeat:
        case MeasureNodeType.phrase:
          phrase = chordSection.findPhrase(measureNode);
          return new ChordSectionLocation(
              chordSection.getSectionVersion(),
              phraseIndex: phrase.getPhraseIndex());
        case MeasureNodeType.decoration:
        case MeasureNodeType.comment:
        case MeasureNodeType.measure:
          phrase = chordSection.findPhrase(measureNode);
          return new ChordSectionLocation(
              chordSection.getSectionVersion(),
              phraseIndex: phrase.getPhraseIndex(),
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
  ChordSection findChordSection(SectionVersion sectionVersion) {
    if (sectionVersion == null)
      return null;
    return getChordSectionMap()[sectionVersion]; //  get not type safe!!!!
  }

  Measure findMeasure

      (ChordSectionLocation chordSectionLocation) {
    try {
      return getChordSectionMap().get(chordSectionLocation.getSectionVersion())
          .getPhrase(chordSectionLocation.getPhraseIndex())
          .getMeasure(chordSectionLocation.getMeasureIndex());
    }
    catch
    (
    NullPointerException
    | IndexOutOfBoundsException ex) {
    return null;
    }
  }

  final Measure getCurrentChordSectionLocationMeasure

  () {
  ChordSectionLocation location = getCurrentChordSectionLocation();
  if (location.hasMeasureIndex()) {
  int index = location.getMeasureIndex();
  if (index > 0) {
  location = new ChordSectionLocation(location.getSectionVersion(), location.getPhraseIndex(), index);
  MeasureNode measureNode = findMeasureNodeByLocation(location);
  if (measureNode != null) {
  switch (measureNode.getMeasureNodeType()) {
  case measure:
  return (Measure) measureNode;
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
    try {
      ChordSection chordSection = getChordSectionMap()[chordSectionLocation
          .sectionVersion];
      if (chordSectionLocation.isSection)
        return chordSection;

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
    }
    catch (e) {
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

  ChordSection findChordSectionbyMarkedString
      (MarkedString markedString) {
    SectionVersion sectionVersion = SectionVersion.parse(
        markedString);
    return getChordSectionMap
      (
    ).
    get(sectionVersion);
  }


  bool chordSectionLocationDelete
      (ChordSectionLocation chordSectionLocation) {
    try {
      ChordSection chordSection = getChordSection(
          chordSectionLocation.getSectionVersion());
      if (chordSection.deleteMeasure(chordSectionLocation.getPhraseIndex(),
          chordSectionLocation.getMeasureIndex())) {
        clearCachedValues();
        setCurrentChordSectionLocation(chordSectionLocation);
        return true;
      }
    }
    catch
    (
    NullPointerException
    npe) {
    }
    return
    false;
  }

  bool chordSectionDelete
      (ChordSection chordSection) {
    if (chordSection == null)
      return false;
    bool ret = getChordSectionMap().remove(chordSection) != null;
    clearCachedValues();
    return ret;
  }

  void guessTheKey() {
//  fixme: key guess based on chords section or lyrics?
    setKey(Key.guessKey(findScaleChordsUsed().keys));
  }


  HashMap<ScaleChord, int> findScaleChordsUsed
      () {
    HashMap<ScaleChord, int> ret = new HashMap();
    for (ChordSection chordSection in getChordSectionMap().values) {
      for (Phrase msi in chordSection.getPhrases()) {
        for (Measure m in msi.getMeasures()) {
          for (Chord chord in m.chords) {
            ScaleChord scaleChord = chord.scaleChord;
            int chordCount = ret.sget(scaleChord);
            ret.put(scaleChord, chordCount == null ? 1 : chordCount + 1);
          }
        }
      }
    }
    return
      ret;
  }

  void parseLyrics() {
    int state = 0;
    String whiteSpace = "";
    StringBuffer lyricsBuffer = new StringBuffer();
    LyricSection lyricSection = null;

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
            if (lyricSection != null)
              lyricSections.add(lyricSection);

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
    clearCachedValues(
    );
  }

  /// Debug only!  a string form of the song chord section grid
  String logGrid() {
    StringBuffer sb = new StringBuffer("\n");

    calcChordMaps(); //  avoid ConcurrentModificationException
    for (int r = 0; r < getChordSectionLocationGrid().getRowCount(); r++) {
      List<ChordSectionLocation> row = chordSectionLocationGrid.getRow(r);
      for (int c = 0; c < row.length; c++) {
        ChordSectionLocation loc = row[c];
        if (loc == null)
          continue;
        sb.write("(");
        sb.write(r);
        sb.write(",");
        sb.write(c);
        sb.write(") ");
        sb.write(loc.isMeasure() ? "        " : (loc.isPhrase() ? "    " : ""));
        sb.write(loc.toString());
        sb.write("  ");
        sb.write(findMeasureNodeByLocation(loc).toMarkup() + "\n");
      }
    }
    return sb.toString();
  }

  void addRepeat
      (ChordSectionLocation chordSectionLocation
      ,

      MeasureRepeat repeat) {
    Measure measure = findMeasure(chordSectionLocation);
    if (measure == null)
      return;

    Phrase measureSequenceItem = findPhrase(measure);
    if (measureSequenceItem == null)
      return;

    ChordSection chordSection = findChordSection(measure);
    List<Phrase> measureSequenceItems = chordSection.getPhrases();
    int i = measureSequenceItems.indexOf(measureSequenceItem);
    if (i >= 0) {
      measureSequenceItems = new List<>(measureSequenceItems);
      measureSequenceItems.remove(i);
      repeat.setPhraseIndex(i);
      measureSequenceItems.add(i, repeat);
    } else {
      repeat.setPhraseIndex(measureSequenceItems.length - 1);
      measureSequenceItems.add(repeat);
    }

    chordSectionDelete(chordSection);
    chordSection =
    new ChordSection(chordSection.sectionVersion, measureSequenceItems);
    getChordSectionMap().put(chordSection.sectionVersion, chordSection);
    clearCachedValues();
  }

  void setRepeat
      (ChordSectionLocation chordSectionLocation, int
  repeats) {
    Measure measure = findMeasure(chordSectionLocation);
    if (measure == null)
      return;

    Phrase phrase = findPhrase(measure);
    if (phrase == null)
      return;

    if (phrase instanceof MeasureRepeat) {
      MeasureRepeat measureRepeat = ((MeasureRepeat) phrase);

      if (repeats <= 1) {
//  remove the repeat
        ChordSection chordSection = findChordSection(measureRepeat);
        List<Phrase> measureSequenceItems = chordSection.getPhrases();
        int phraseIndex = measureSequenceItems.indexOf(measureRepeat);
        measureSequenceItems.remove(phraseIndex);
        measureSequenceItems.add(
            phraseIndex, new Phrase(measureRepeat.getMeasures(), phraseIndex));

        chordSectionDelete(chordSection);
        chordSection = new ChordSection(
            chordSection.sectionVersion, measureSequenceItems);
        getChordSectionMap().put(
            chordSection.sectionVersion, chordSection);
      } else {
//  change the count
        measureRepeat.setRepeats(repeats);
      }
    } else {
//  change sequence items to repeat
      MeasureRepeat measureRepeat = new MeasureRepeat(
          phrase.getMeasures(), phrase.getPhraseIndex(), repeats);
      ChordSection chordSection = findChordSection(phrase);
      List<Phrase> measureSequenceItems = chordSection.getPhrases();
      int i = measureSequenceItems.indexOf(phrase);
      measureSequenceItems = new List<>(measureSequenceItems);
      measureSequenceItems.remove(i);
      measureSequenceItems.add(i, measureRepeat);

      chordSectionDelete(chordSection);
      chordSection =
      new ChordSection(chordSection.sectionVersion, measureSequenceItems);
      getChordSectionMap().put(chordSection.sectionVersion, chordSection);
    }

    clearCachedValues();
  }

  /**
   * Set the number of measures displayed per row
   *
   * @param measuresPerRow the number of measurese per row
   * @return true if a change was made
   */
  bool setMeasuresPerRow(int measuresPerRow) {
    if (measuresPerRow <= 0)
      return false;

    bool ret = false;
    for (ChordSection chordSection in new SplayTreeSet<>(
        getChordSectionMap().values())) {
      ret = chordSection.setMeasuresPerRow(measuresPerRow) || ret;
    }
    if (ret)
      clearCachedValues();
    return ret;
  }


  /**
   * Checks a song for completeness.
   *
   * @return a new song constructed with the song's current fields.
   * @throws ParseException exception thrown if the song's fields don't match properly.
   */
  Song checkSong
      () {
    return
      checkSong
        (
          getTitle
            (
          ),
          getArtist
            (
          ),
          getCopyright
            (
          ),
          getKey
            (
          ),
          int.toString(getDefaultBpm
            (
          )),
          int.toString(getBeatsPerBar
            (
          )),
          int.toString(getUnitsPerMeasure
            (
          )),
          getUser
            (
          ),
          toMarkup
            (
          ),
          getRawLyrics
            (
          ));
  }

  /**
   * Validate a song entry argument set
   *
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
  static Song checkSong

      (String title, String

  artist

      ,

      String copyright,
      Key

      key

      ,

      String bpmEntry, String

  beatsPerBarEntry

      ,

      String unitsPerMeasureEntry,
      String

      user

      ,

      String chordsTextEntry, String

  lyricsTextEntry) {
    if
    (
    title == null
        ||
        title.length() <= 0) {
      throw new ParseException("no song title given!", 0);
    }

    if
    (
    artist == null
        ||
        artist.length() <= 0) {
      throw new ParseException("no artist given!", 0);
    }

    if
    (
    copyright == null
        ||
        copyright.length() <= 0) {
      throw new ParseException("no copyright given!", 0);
    }

    if
    (
    key == null
    )
      key = Key.C; //  punt an error

    if
    (
    bpmEntry == null
        ||
        bpmEntry.length() <= 0) {
      throw new ParseException("no BPM given!", 0);
    }

//  check bpm
    RegExp twoOrThreeDigitsRegexp = RegExp.compile("^\\d{2,3}$");
    if (
    !
    twoOrThreeDigitsRegexp.test(bpmEntry)) {
      throw new ParseException(
          "BPM has to be a number from " + MusicConstant.minBpm + " to " +
              MusicConstant.maxBpm, 0);
    }
    int bpm = int.parseInt(bpmEntry);
    if (
    bpm
        <
        MusicConstant.minBpm || bpm > MusicConstant.maxBpm) {
      throw new ParseException(
          "BPM has to be a number from " + MusicConstant.minBpm + " to " +
              MusicConstant.maxBpm, 0);
    }

//  check beats per bar
    if
    (
    beatsPerBarEntry == null
        ||
        beatsPerBarEntry.length() <= 0) {
      throw new ParseException("no beats per bar given!", 0);
    }
    RegExp oneOrTwoDigitRegexp = RegExp.compile("^\\d{1,2}$");
    if (
    !
    oneOrTwoDigitRegexp.test(beatsPerBarEntry)) {
      throw new ParseException("Beats per bar has to be 2, 3, 4, 6, or 12", 0);
    }
    int beatsPerBar = int.parseInt(beatsPerBarEntry);
    switch (
    beatsPerBar) {
      case 2:
      case 3:
      case 4:
      case 6:
      case 12:
        break;
      default:
        throw new ParseException(
            "Beats per bar has to be 2, 3, 4, 6, or 12", 0);
    }


    if
    (
    chordsTextEntry == null
        ||
        chordsTextEntry.length() <= 0) {
      throw new ParseException("no chords given!", 0);
    }
    if
    (
    lyricsTextEntry == null
        ||
        lyricsTextEntry.length() <= 0) {
      throw new ParseException("no lyrics given!", 0);
    }

    if
    (
    unitsPerMeasureEntry == null
        ||
        unitsPerMeasureEntry.length() <= 0) {
      throw new ParseException("No units per measure given!", 0);
    }
    if
    (
    !
    oneOrTwoDigitRegexp.test(unitsPerMeasureEntry)) {
      throw new ParseException("Units per measure has to be 2, 4, or 8", 0);
    }
    int unitsPerMeasure = int.parseInt(unitsPerMeasureEntry);
    switch (
    unitsPerMeasure) {
      case 2:
      case 4:
      case 8:
        break;
      default:
        throw new ParseException("Units per measure has to be 2, 4, or 8", 0);
    }

    Song newSong = Song.createSong(
        title,
        artist,
        copyright,
        key,
        bpm,
        beatsPerBar,
        unitsPerMeasure,
        user,
        chordsTextEntry,
        lyricsTextEntry);
    newSong.resetLastModifiedDateToNow();

    if
    (
    newSong.getChordSections()
        .
    isEmpty
      (
    )) throw
    new
    ParseException
      ("The song has no chord sections!
    "
        ,
        0
    );

    for (ChordSection chordSection in newSong.getChordSections()) {
      if (chordSection.isEmpty())
        throw new ParseException(
            "Chord section " + chordSection.sectionVersion.toString()
                + " is empty.", 0);
    }

    //  see that all chord sections have a lyric section
    for (ChordSection chordSection in newSong.getChordSections()) {
      SectionVersion chordSectionVersion = chordSection.sectionVersion;
      bool found = false;
      for (LyricSection lyricSection in newSong.getLyricSections()) {
        if (chordSectionVersion.equals(lyricSection.getSectionVersion())) {
          found = true;
          break;
        }
      }
      if (!found) {
        throw new ParseException(
            "no use found for the declared chord section " + chordSectionVersion
                .toString(), 0);
      }
    }

//  see that all lyric sections have a chord section
    for
    (
    LyricSection
    lyricSection in newSong.getLyricSections()) {
      SectionVersion lyricSectionVersion = lyricSection.sectionVersion;
      bool found = false;
      for (ChordSection chordSection in newSong.getChordSections()) {
        if (lyricSectionVersion.equals(chordSection.getSectionVersion())) {
          found = true;
          break;
        }
      }
      if (!found) {
        throw new ParseException("no chords found for the lyric section " +
            lyricSectionVersion.toString(), 0);
      }
    }

    if
    (
    newSong.getMessage() == null) {
      for (ChordSection chordSection in newSong.getChordSections()) {
        for (Phrase phrase in chordSection.getPhrases()) {
          for (Measure measure in phrase.getMeasures()) {
            if (measure.isComment()) {
              throw new ParseException("chords should not have comments: see " +
                  chordSection.toString(), 0);
            }
          }
        }
      }
    }

    newSong.setMessage(null
    );

    if
    (
    newSong.getMessage() == null) {
//  an early song with default (no) structure?
      if (newSong
          .getLyricSections()
          .length == 1 &&
          newSong
              .getLyricSections()
              .get(0)
              .sectionVersion
              .equals
            (Section.getDefaultVersion())) {
        newSong.setMessage(
            "song looks too simple, is there really no structure?");
      }
    }

    return
      newSong;
  }

  static final List<StringTriple> diff

  (

  SongBase a, SongBase

  b

  ) {
  List<StringTriple> ret = new List();

  if (a.getTitle().compareTo(b.getTitle()) != 0)
  ret.add(new StringTriple("title:", a.getTitle(), b.getTitle()));
  if (a.getArtist().compareTo(b.getArtist()) != 0)
  ret.add(new StringTriple("artist:", a.getArtist(), b.getArtist()));
  if (a.getCoverArtist() != null && b.getCoverArtist() != null && a.getCoverArtist().compareTo(b.getCoverArtist()) != 0)
  ret.add(new StringTriple("cover:", a.getCoverArtist(), b.getCoverArtist()));
  if (a.getCopyright().compareTo(b.getCopyright()) != 0)
  ret.add(new StringTriple("copyright:", a.getCopyright(), b.getCopyright()));
  if (a.getKey().compareTo(b.getKey()) != 0)
  ret.add(new StringTriple("key:", a.getKey().toString(), b.getKey().toString()));
  if (a.getBeatsPerMinute() != b.getBeatsPerMinute())
  ret.add(new StringTriple("BPM:", int.toString(a.getBeatsPerMinute()), int.toString(b.getBeatsPerMinute())));
  if (a.getBeatsPerBar() != b.getBeatsPerBar())
  ret.add(new StringTriple("per bar:", int.toString(a.getBeatsPerBar()), int.toString(b.getBeatsPerBar())));
  if (a.getUnitsPerMeasure() != b.getUnitsPerMeasure())
  ret.add(new StringTriple("units/measure:", int.toString(a.getUnitsPerMeasure()), int.toString(b.getUnitsPerMeasure())));

//  chords
  for (ChordSection aChordSection in a.getChordSections()) {
  ChordSection bChordSection = b.getChordSection(aChordSection.getSectionVersion());
  if (bChordSection == null) {
  ret.add(new StringTriple("chords missing:", aChordSection.toMarkup(), ""));
  } else if (aChordSection.compareTo(bChordSection) != 0) {
  ret.add(new StringTriple("chords:", aChordSection.toMarkup(), bChordSection.toMarkup()));
  }
  }
  for (ChordSection bChordSection in b.getChordSections()) {
  ChordSection aChordSection = a.getChordSection(bChordSection.getSectionVersion());
  if (aChordSection == null) {
  ret.add(new StringTriple("chords missing:", "", bChordSection.toMarkup()));
  }
  }

//  lyrics
      {
  int limit = Math.min(a.getLyricSections().length, b.getLyricSections().length);
  for (int i = 0; i < limit; i++) {

  LyricSection aLyricSection = a.getLyricSections().get(i);
  SectionVersion sectionVersion = aLyricSection.sectionVersion;
  LyricSection bLyricSection = b.getLyricSections().get(i);
  int lineLimit = Math.min(aLyricSection.getLyricsLines().length, bLyricSection.getLyricsLines().length);
  for (int j = 0; j < lineLimit; j++) {
  String aLine = aLyricSection.getLyricsLines().get(j).getLyrics();
  String bLine = bLyricSection.getLyricsLines().get(j).getLyrics();
  if (aLine.compareTo(bLine) != 0)
  ret.add(new StringTriple("lyrics " + sectionVersion.toString(), aLine, bLine));
  }
  lineLimit = aLyricSection.getLyricsLines().length;
  for (int j = bLyricSection.getLyricsLines().length; j < lineLimit; j++) {
  String aLine = aLyricSection.getLyricsLines().get(j).getLyrics();
  ret.add(new StringTriple("lyrics missing " + sectionVersion.toString(), aLine, ""));
  }
  lineLimit = bLyricSection.getLyricsLines().length;
  for (int j = aLyricSection.getLyricsLines().length; j < lineLimit; j++) {
  String bLine = bLyricSection.getLyricsLines().get(j).getLyrics();
  ret.add(new StringTriple("lyrics missing " + sectionVersion.toString(), "", bLine));
  }

  }
  }

  return ret;
  }

  bool hasSectionVersion(Section section, int version) {
    if (section == null)
      return false;

    for (SectionVersion sectionVersion in getChordSectionMap().keySet()) {
      if (sectionVersion.getSection() == section &&
          sectionVersion.getVersion() == version)
        return true;
    }
    return
      false;
  }

  /// Sets the song's title and song id from the given title. Leading "The " articles are rotated to the title end.
  void setTitle
      (String title) {
//  move the leading "The " to the end
    RegExp theRegExp = RegExp.compile("^the +", "i");
    if (theRegExp.test(title)) {
      title = theRegExp.replace(title, "") + ", The";
    }
    this.title = title;
    computeSongId();
  }

  /**
   * Sets the song's artist
   *
   * @param artist artist's name
   */
  void setArtist
      (String artist) {
//  move the leading "The " to the end
    RegExp theRegExp = RegExp.compile("^the +", "i");
    if (theRegExp.test(artist)) {
      artist = theRegExp.replace(artist, "") + ", The";
    }
    this.artist = artist;
    computeSongId();
  }


  void setCoverArtist
      (String coverArtist) {
    if (coverArtist != null) {
//  move the leading "The " to the end
      RegExp theRegExp = RegExp.compile("^the +", "i");
      if (theRegExp.test(coverArtist)) {
        coverArtist = theRegExp.replace(coverArtist, "") + ", The";
      }
    }
    this.coverArtist = coverArtist;
    computeSongId();
  }

  void resetLastModifiedDateToNow() {
    //  for song override
  }

  void computeSongId
      () {
    songId = computeSongId(title, artist, coverArtist);
  }

  static SongId computeSongId(String title, String artist, String coverArtist) {
    return new SongId("Song_" + title.replaceAll("\\W+", "")
        + "_by_" + artist.replaceAll("\\W+", "")
        + (coverArtist == null || coverArtist.length <= 0 ? "" : "_coverBy_" +
            coverArtist));
  }

  /// Sets the copyright for the song.  All songs should have a copyright.
  void setCopyright
      (String copyright) {
    this.copyright = copyright;
  }

  /// Set the key for this song.
  void setKey(Key key) {
    this.key = key;
  }


  /**
   * Return the song default beats per minute.
   *
   * @return the default BPM
   */
  int getBeatsPerMinute() {
    return defaultBpm;
  }

  double getDefaultTimePerBar() {
    if (defaultBpm == 0)
      return 1;
    return beatsPerBar * 60.0 / defaultBpm;
  }

  double getSecondsPerBeat() {
    if (defaultBpm == 0)
      return 1;
    return 60.0 / defaultBpm;
  }

  /// Set the song default beats per minute.
  void setBeatsPerMinute(int bpm) {
    if (bpm < 20)
      bpm = 20;
    else if (bpm > 1000)
      bpm = 1000;
    this.defaultBpm = bpm;
  }

  /// Return the song's number of beats per bar
  int getBeatsPerBar() {
    return beatsPerBar;
  }

  /**
   * Set the song's number of beats per bar
   *
   * @param beatsPerBar the beatsPerBar to set
   */
  void setBeatsPerBar(int beatsPerBar) {
    //  never divide by zero
    if (beatsPerBar <= 1)
      beatsPerBar = 2;
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

  /**
   * Return the song's key
   *
   * @return the key
   */
  Key getKey() {
    return key;
  }

  /**
   * Return the song's identification string largely consisting of the title and artist name.
   *
   * @return the songId
   */
  SongId getSongId() {
    return songId;
  }

  /**
   * Return the song's title
   *
   * @return the title
   */
  String getTitle() {
    return title;
  }

  /**
   * Return the song's artist.
   *
   * @return the artist
   */
  String getArtist() {
    return artist;
  }

  /**
   * Return the lyrics.
   *
   * @return the rawLyrics
   */
  @deprecated
  String getLyricsAsString
      () {
    return rawLyrics;
  }

  /**
   * Return the default beats per minute.
   *
   * @return the defaultBpm
   */
  int getDefaultBpm
      () {
    return defaultBpm;
  }

  /**
   * Get the song's default drum section.
   * The section will be played through all of its measures
   * and then repeated as required for the song's duration.
   *
   * @return the drum section
   */
  LegacyDrumSection getDrumSection
      () {
    return drumSection;
  }

  /**
   * Set the song's default drum section
   *
   * @param drumSection the drum section
   */
  void setDrumSection
      (LegacyDrumSection drumSection) {
    this.drumSection = drumSection;
  }

  Collection<ChordSection> getChordSections() {
    return getChordSectionMap().values();
  }

  Arrangement getDrumArrangement
      () {
    return drumArrangement;
  }

  void setDrumArrangement
      (Arrangement drumArrangement) {
    this.drumArrangement = drumArrangement;
  }

  String getFileName
      () {
    return fileName;
  }

  void setFileName
      (String fileName) {
    this.fileName = fileName;

    RegExp fileVersionRegExp = RegExp.compile(" \\(([0-9]+)\\).songlyrics$");
    MatchResult mr = fileVersionRegExp.exec(fileName);
    if (mr != null) {
      fileVersionNumber = int.parseInt(mr.getGroup(1));
    } else
      fileVersionNumber = 0;
//_logger.info("setFileName(): "+fileVersionNumber);
  }

  double getDuration
      () {
    computeDuration();
    return duration;
  }

  int getTotalBeats
      () {
    computeDuration();
    return totalBeats;
  }

  int getSongMomentsSize
      () {
    return getSongMoments().length;
  }

  List<SongMoment> getSongMoments
      () {
    computeSongMoments();
    return songMoments;
  }

  SongMoment getSongMoment
      (int momentNumber) {
    computeSongMoments();
    if (songMoments.isEmpty() || momentNumber < 0 ||
        momentNumber >= songMoments.length)
      return null;
    return songMoments.get(momentNumber);
  }

  SongMoment getFirstSongMomentInSection
      (int momentNumber) {
    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null)
      return null;

    SongMoment firstSongMoment = songMoment;
    String id = songMoment.getChordSection().getId();
    for (int m = momentNumber - 1; m >= 0; m--) {
      SongMoment sm = songMoments[m];
      if (id != sm.getChordSection().getId()
          || sm.getSectionCount() != firstSongMoment.getSectionCount())
        return firstSongMoment;
      firstSongMoment = sm;
    }
    return firstSongMoment;
  }

  SongMoment getLastSongMomentInSection
      (int momentNumber) {
    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null)
      return null;

    SongMoment lastSongMoment = songMoment;
    String id = songMoment.getChordSection().getId();
    int limit = songMoments.length;
    for (int m = momentNumber + 1; m < limit; m++) {
      SongMoment sm = songMoments[m];
      if (id != sm.getChordSection().getId()
          || sm.getSectionCount() != lastSongMoment.getSectionCount())
        return lastSongMoment;
      lastSongMoment = sm;
    }
    return lastSongMoment;
  }

  double getSongTimeAtMoment
      (int momentNumber) {
    SongMoment songMoment = getSongMoment(momentNumber);
    if (songMoment == null)
      return 0;
    return songMoment.getBeatNumber() * getBeatsPerMinute() / 60.0;
  }

  static int getBeatNumberAtTime(int bpm, double songTime) {
    if (bpm <= 0)
      return null; //  we're done with this song play

    int songBeat = round(floor(songTime * bpm / 60.0)) as int;
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
  SongMoment getSongMomentAtRow
      (int rowIndex) {
    if (rowIndex < 0)
      return null;
    computeSongMoments();
    for (SongMoment songMoment : songMoments) {
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
    if (chordSectionLocation == null)
      return 0;
    return getChordSectionBeats(chordSectionLocation.sectionVersion);
  }

  int getChordSectionBeats(SectionVersion sectionVersion) {
    if (sectionVersion == null)
      return 0;
    computeSongMoments();
    int ret = chordSectionBeats[sectionVersion];
    if (ret == null)
      return 0;
    return ret;
  }

  int getChordSectionRows
      (SectionVersion sectionVersion) {
    computeSongMoments();
    int ret = chordSectionRows.get(sectionVersion);
    if (ret == null)
      return 0;
    return ret;
  }

  ///Compute a relative complexity index for the song
  int getComplexity() {
    if (complexity == 0) {
      //  compute the complexity
      SplayTreeSet<Measure> differentChords = new SplayTreeSet();
      for (ChordSection chordSection in getChordSectionMap().values) {
        for (Phrase phrase in chordSection.getPhrases()) {
          //  the more different measures, the greater the complexity
          differentChords.addAll(phrase.getMeasures());

          //  weight measures by guitar complexity
          for (Measure measure in phrase.getMeasures())
            if (!measure.isEasyGuitarMeasure())
              complexity++;
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

  void setCurrentMeasureEditType
      (MeasureEditType measureEditType) {
    currentMeasureEditType = measureEditType;
    _logger.d("curloc: "
        + (currentChordSectionLocation != null ? currentChordSectionLocation
            .toString() : "none")
        + " "
        + (currentMeasureEditType != null
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
        ChordSection lastChordSection = getChordSectionMap()[ sectionVersions
            .last];
        if (lastChordSection.isEmpty())
          currentChordSectionLocation =
          new ChordSectionLocation(lastChordSection.getSectionVersion());
        else {
          Phrase phrase = lastChordSection.lastPhrase();
          if (phrase.isEmpty())
            currentChordSectionLocation =
            new ChordSectionLocation(lastChordSection.sectionVersion,
                phraseIndex: phrase.getPhraseIndex());
          else
            currentChordSectionLocation =
            new ChordSectionLocation(lastChordSection.sectionVersion,
                phraseIndex: phrase.getPhraseIndex(), measureIndex: phrase
                    .getMeasures()
                    .length - 1);
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
        ChordSection chordSection = getChordSection(chordSectionLocation);
        ChordSection cs = chordSection;
        if (cs == null) {
          SplayTreeSet<
              SectionVersion> sortedSectionVersions = new SplayTreeSet();
          sortedSectionVersions.addAll(getChordSectionMap().keys);
          cs = getChordSectionMap()[sortedSectionVersions.last];
        }
        if (chordSectionLocation.hasPhraseIndex()) {
          Phrase phrase = cs.getPhrase(chordSectionLocation.getPhraseIndex());
          if (phrase == null)
            phrase = cs.getPhrase(cs.getPhraseCount() - 1);
          int phraseIndex = phrase.getPhraseIndex();
          if (chordSectionLocation.hasMeasureIndex()) {
            int pi = (phraseIndex >= cs.getPhraseCount() ? cs.getPhraseCount() -
                1 : phraseIndex);
            int measureIndex = chordSectionLocation.getMeasureIndex();
            int mi = (measureIndex >= phrase.length
                ? phrase.length - 1
                : measureIndex);
            if (cs != chordSection || pi != phraseIndex || mi != measureIndex)
              chordSectionLocation =
              new ChordSectionLocation(
                  cs.sectionVersion, phraseIndex: pi, measureIndex: mi);
          }
        }
      }
    catch ( NullPointerException npe ) {
    chordSectionLocation = null;
    } catch (Exception ex) {
//  javascript parse error
    _logger.d(ex.getMessage());
    chordSectionLocation = null;
    }

    currentChordSectionLocation = chordSectionLocation;
    _logger.d("curloc: "
    + (currentChordSectionLocation != null ? currentChordSectionLocation.toString() : "none")
    + " "
    + (currentMeasureEditType != null ? currentMeasureEditType.toString() : "no type")
    + " " + (currentChordSectionLocation != null ? findMeasureNodeByLocation(currentChordSectionLocation)
    :"none")
    );
  }





  @override
  String toString() {
  return title + (fileVersionNumber > 0 ? ":(" + fileVersionNumber + ")" : "") + " by " + artist;
  }

  static final bool containsSongTitleAndArtist(Collection<? extends SongBase> collection, SongBase
  song) {
  for (SongBase collectionSong : collection) {
  if (song.compareBySongId(collectionSong) == 0)
  return true;
  }
  return false;
  }

  /// Compare only the title and artist.
  ///To be used for listing purposes only.
  int compareBySongId(SongBase o) {
  if (o == null)
  return -1;
  int ret = getSongId().compareTo(o.getSongId());
  if (ret != 0) {
  return ret;
  }
  return 0;
  }

  bool songBaseSameAs(SongBase o) {
  //  song id built from title with reduced whitespace
  if (getTitle()!=(o.getTitle()))
  return false;
  if (getArtist()!=(o.getArtist()))
  return false;
  if (getCoverArtist() != null) {
  if (getCoverArtist()!=(o.getCoverArtist()))
  return false;
  } else if (o.getCoverArtist() != null) {
  return false;
  }
  if (getCopyright()!=(o.getCopyright()))
  return false;
  if (getKey()!=(o.getKey()))
  return false;
  if (defaultBpm != o.defaultBpm)
  return false;
  if (unitsPerMeasure != o.unitsPerMeasure)
  return false;
  if (beatsPerBar != o.beatsPerBar)
  return false;
  if (toMarkup()!=(o.toMarkup()))
  return false;
  if (rawLyrics!=(o.rawLyrics))
  return false;
  if (metadata!=(o.metadata))
  return false;
  if (lastModifiedTime != o.lastModifiedTime)
  return false;

//  hmm, think about these
  if (fileName != o.fileName)
  return false;
  if (fileVersionNumber != o.fileVersionNumber)
  return false;

  return true;

  }

//  primary values
  String title = "Unknown";
  String artist = "Unknown";
  String user = defaultUser;
  String coverArtist = "";
  String copyright = "Unknown";
  Key key = Key.get(KeyEnum.C); //  default
  int defaultBpm = 106; //  beats per minute
  int unitsPerMeasure = 4;//  units per measure, i.e. timeSignature numerator
  int beatsPerBar = 4; //  beats per bar, i.e. timeSignature denominator
  double lastModifiedTime;
  String rawLyrics = "";

//  meta data
  String fileName;

//  deprecated values
  int fileVersionNumber = 0;

//  computed values
  SongId songId;
  String timeSignature = unitsPerMeasure.toString() + "/" + beatsPerBar.toString();//   fixme: doesn't update!!!!
  double duration; //  units of seconds
  int totalBeats;
  String chords = "";
  HashMap<SectionVersion, ChordSection> chordSectionMap;
  List<MeasureNode> measureNodes;

  List<LyricSection> lyricSections = new List();
  HashMap<SectionVersion, GridCoordinate> chordSectionGridCoorinateMap = new HashMap();

//  match to representative section version
  HashMap<SectionVersion, SectionVersion> chordSectionGridMatches = new HashMap();

  HashMap<GridCoordinate, ChordSectionLocation> gridCoordinateChordSectionLocationMap;
  HashMap<ChordSectionLocation, GridCoordinate> gridChordSectionLocationCoordinateMap;
  HashMap<SongMoment, GridCoordinate> songMomentGridCoordinateHashMap = new HashMap();
  HashMap<SectionVersion, int> chordSectionBeats = new HashMap();
  HashMap<SectionVersion, int> chordSectionRows = new HashMap();

  ChordSectionLocation currentChordSectionLocation;
  MeasureEditType currentMeasureEditType = MeasureEditType.append;
  Grid<ChordSectionLocation> chordSectionLocationGrid = null;
  int complexity;
  String chordsAsMarkup;
  String message;
  List<SongMoment> songMoments = List();
  HashMap<int, SongMoment> beatsToMoment = new HashMap();


  LegacyDrumSection drumSection = new LegacyDrumSection();
  Arrangement drumArrangement; //  default
  SplayTreeSet<Metadata> metadata = new SplayTreeSet();
  static final AppOptions appOptions = AppOptions.getInstance();
  static final String defaultUser = "Unknown";

  static final Logger

  _logger

  =

  Logger

  (

  );

}


class ComparatorByTitle implements Comparator<SongBase> {

  /**
   * Compares its two arguments for order.
   *
   * @param o1 the first object to be compared.
   * @param o2 the second object to be compared.
   * @return a negative integer, zero, or a positive integer as the
   * first argument is less than, equal to, or greater than the
   * second.
   * @throws NullPointerException if an argument is null and this
   *                              comparator does not permit null arguments
   * @throws ClassCastException   if the arguments' types prevent them from
   *                              being compared by this comparator.
   */
  @override
  int compare(SongBase o1, SongBase o2) {
    return o1.compareBySongId(o2);
  }
}

 class ComparatorByArtist implements Comparator<SongBase> {

@override
int compare(SongBase o1, SongBase o2) {
int ret = o1.getArtist().compareTo(o2.getArtist());
if (ret != 0) {
return ret;
}
return o1.compareBySongId(o2);
}

}
