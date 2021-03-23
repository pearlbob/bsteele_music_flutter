import 'dart:math';
import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:bsteele_music_flutter/gui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../appOptions.dart';
import '../main.dart';

typedef LyricsTextWidget = Widget Function(LyricSection lyricSection, int lineNumber, String s);
typedef LyricsSectionHeaderWidget = Widget Function(LyricSection lyricSection);
typedef LyricsEndWidget = Widget Function();

class LyricsTable {
  Table lyricsTable(
    Song song, {
    key,
    LyricsSectionHeaderWidget? sectionHeaderWidget,
    LyricsTextWidget? textWidget,
    LyricsEndWidget? lyricEndWidget,
  }) {
    displaySongKey = key ?? song.key;
    textWidget = textWidget ?? _defaultTextWidget;

    computeScreenSizes();

    //  build the table from the song moment grid
    Grid<SongMoment> grid = song.songMomentGrid;
    _rowLocations = [];
    if (grid.isEmpty) {
      _table = Table();
      return _table;
    }
    _rowLocations = List.generate(grid.getRowCount(), (i) {
      return null;
    });
    List<TableRow> rows = [];
    List<Widget> children = [];
    Color color = GuiColors.getColorForSection(Section.get(SectionEnum.chorus));

    bool showChords = _appOptions.playerDisplay;
    bool showFullLyrics = true; //isScreenBig || !_appOptions.playerDisplay;

    //  compute transposition offset from base key
    int tranOffset = displaySongKey.getHalfStep() - song.getKey().getHalfStep();

    //  keep track of the section
    ChordSection? lastChordSection;
    int? lastSectionCount;

    //  compute row length
    int maxCols = 0;
    for (int r = 0; r < grid.getRowCount(); r++) {
      List<SongMoment?>? row = grid.getRow(r);
      if (row != null) {
        maxCols = max(maxCols, row.length);
      }
    }

    //  map the song moment grid to a flutter table, one row at a time
    for (int r = 0; r < grid.getRowCount(); r++) {
      List<SongMoment?>? row = grid.getRow(r);
      if (row == null) {
        continue;
      }

      //  assume col 1 has a chord or comment in it
      if (row.length < 2) {
        continue;
      }

      //  find the first col with data
      //  should normally be col 1 (i.e. the second col)
      SongMoment? firstSongMoment;
      for (final SongMoment? sm in row)
        if (sm == null)
          continue;
        else {
          firstSongMoment = sm;
          break;
        }
      if (firstSongMoment == null) {
        continue;
      }

      GlobalKey? _rowKey = GlobalObjectKey(row);
      _rowLocations[r] = RowLocation(firstSongMoment, r, _rowKey);

      ChordSection chordSection = firstSongMoment.getChordSection();
      LyricSection lyricSection = firstSongMoment.lyricSection;
      int sectionCount = firstSongMoment.sectionCount;
      String? columnFiller;
      EdgeInsets marginInsets = EdgeInsets.all(fontScale);
      EdgeInsets textPadding = EdgeInsets.all(6);
      if (chordSection != lastChordSection || sectionCount != lastSectionCount) {
        //  add the section heading
        columnFiller = chordSection.sectionVersion.toString();
        color = GuiColors.getColorForSection(chordSection.getSection());
        if (sectionHeaderWidget != null) {
          children.add(sectionHeaderWidget(lyricSection));
          //  row length - 1 + 1 for missing lyrics
          for (int c = 0; c < maxCols; c++) {
            children.add(Text(''));
          }
          rows.add(TableRow(children: children));
          children = [];
        }
      }
      lastChordSection = chordSection;
      lastSectionCount = sectionCount;

      //  collect lyrics and show chords if asked
      String? momentLocation;
      String rowLyrics = '';
      for (int c = 0; c < row.length; c++) {
        SongMoment? sm = row[c];

        if (sm == null) {
          if (columnFiller == null)
            //  empty cell
            children.add(Container(
                margin: marginInsets,
                child: Text(
                  " ",
                )));
          else
            children.add(Container(
                margin: marginInsets,
                padding: textPadding,
                color: color,
                child: Text(
                  columnFiller,
                  style: _chordTextStyle,
                )));
          columnFiller = null; //  for subsequent rows
        } else {
          //  moment found
          rowLyrics += ' ' + (sm.lyrics ?? '');
          if (showChords) {
            children.add(Container(
                key: _rowKey,
                margin: marginInsets,
                padding: textPadding,
                color: color,
                child: Text(
                  sm.getMeasure().transpose(displaySongKey, tranOffset),
                  style: _chordTextStyle,
                )));
          }
          _rowKey = null;

          //  use the first non-null location for the table value key
          if (momentLocation == null) {
            momentLocation = sm.momentNumber.toString();
          }
        }

        //  section and lyrics only if on a cell phone
        if (!showChords) {
          //  collect the rest of the lyrics
          for (; c < row.length; c++) {
            SongMoment? sm = row[c];
            if (sm != null) {
              rowLyrics += ' ' + (sm.lyrics ?? '');
            }
          }
          break;
        }
      }

      if (showFullLyrics) {
        //  lyrics
        children.add(Container(
            margin: marginInsets,
            padding: textPadding,
            color: color,
            child: textWidget(
                lyricSection,
                0, //  fixme: offset of lyrics lines within lyrics section
                rowLyrics.trimLeft())));

        //  add row to table
        rows.add(TableRow(
            //key: ValueKey(r),
            children: children));
      }
      // else {
      //   //  short lyrics
      //   children.add(Container(
      //       margin: marginInsets,
      //       padding: EdgeInsets.all(2),
      //       color: color,
      //       child: Text(
      //         (firstSongMoment.lyrics ?? ''),
      //         style: _lyricsTextStyle,
      //         overflow: TextOverflow.ellipsis,
      //       )));
      //
      //   //  add row to table
      //   rows.add(TableRow(key: ValueKey(r), children: children));
      // }

      //  get ready for the next row by clearing the row data
      children = [];
    }

    if (lyricEndWidget != null) {
      children.add(lyricEndWidget());
      //  row length - 1 + 1 for missing lyrics
      for (int c = 0; c < maxCols; c++) {
        children.add(Text(''));
      }
      rows.add(TableRow(children: children));
      children = [];
    }

    // //  compute the flex for the columns
    // var columnWidths = <int, TableColumnWidth>{};
    // for (var i = 0; i < maxCols; i++) {
    //   columnWidths[i] = IntrinsicColumnWidth();
    // }
    // columnWidths[maxCols] = IntrinsicColumnWidth();//FlexColumnWidth();

    _table = Table(
      defaultColumnWidth: IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
      // columnWidths: columnWidths,
    );
    return _table;
  }

  Widget _defaultTextWidget(LyricSection lyricSection, int lineNumber, String s) {
    return Text(
      s,
      style: _lyricsTextStyle,
    );
  }

  /// compute screen size values used here and on other screens
  void computeScreenSizes() {
    _screenWidth = screenInfo.widthInLogicalPixels;
    _screenHeight = screenInfo.heightInLogicalPixels;
    _fontSize = defaultFontSize * min(4, max(1, _screenWidth /350));
    _lyricsFontSize = fontSize * 0.75;

    fontScale = fontSize / defaultFontSize;
    logger.v('lyricsTable: ($_screenWidth,$_screenHeight),'
        ' default:$defaultFontSize  => fontSize: $fontSize, _lyricsFontSize: $_lyricsFontSize, fontScale: $fontScale');

    _chordTextStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize);
    _lyricsTextStyle = TextStyle(fontWeight: FontWeight.normal, fontSize: _lyricsFontSize);
  }

  double get screenWidth => _screenWidth;
  double _screenWidth = 100;

  double get screenHeight => _screenHeight;
  double _screenHeight = 50;

  List<RowLocation?> get rowLocations => _rowLocations;
  List<RowLocation?> _rowLocations = [];

  double get lyricsFontSize => _lyricsFontSize;
  double _lyricsFontSize = 18;

  double get fontSize => _fontSize;
  double _fontSize = 10;
  double fontScale = 1;

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = TextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = TextStyle();

  Table get table => _table;
  Table _table = Table();

  music_key.Key displaySongKey = music_key.Key.get(music_key.KeyEnum.C);
  AppOptions _appOptions = AppOptions();
}

/// helper class to help manage a song display
class RowLocation {
  RowLocation(this.songMoment, this.row, this.globalKey);

  @override
  String toString() {
    return ('${row.toString()} ${globalKey.toString()}'
        ', ${songMoment.toString()}');
  }

  final SongMoment songMoment;
  final GlobalKey globalKey;
  final int row;
}
