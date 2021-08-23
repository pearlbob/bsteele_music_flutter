import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:bsteeleMusicLib/songs/measureRepeatExtension.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songBase.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/gui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

typedef LyricsTextWidget = Widget Function(LyricSection lyricSection, int lineNumber, String s);
typedef LyricsSectionHeaderWidget = Widget Function(Key key, LyricSection lyricSection);
typedef LyricsEndWidget = Widget Function();

/// compute a lyrics table
class LyricsTable {
  Table lyricsTable(
    Song song,
    BuildContext context, {
    musicKey,
    LyricsSectionHeaderWidget? sectionHeaderWidget,
    LyricsTextWidget? textWidget,
    LyricsEndWidget? lyricEndWidget,
    expandRepeats = false,
  }) {
    appWidget.context = context; //	required on every build
    displayMusicKey = musicKey ?? song.key;
    textWidget = textWidget ?? _defaultTextWidget;

    computeScreenSizes();

    final EdgeInsets marginInsets = EdgeInsets.all(_fontScale);
    const EdgeInsets textPadding = EdgeInsets.all(6);

    //  build the table from the song lyrics and chords
    if (song.lyricSections.isEmpty) {
      _table = Table(
        key: GlobalKey(),
      );
      return _table;
    }

    _lyricSectionRowLocations = [];
    List<TableRow> rows = [];
    List<Widget> children = []; //  items for the current row
    Color color = GuiColors.getColorForSection(Section.get(SectionEnum.chorus));

    //  display style booleans
    bool showChords = _appOptions.userDisplayStyle == UserDisplayStyle.player ||
        _appOptions.userDisplayStyle == UserDisplayStyle.both;
    bool showFullLyrics = _appOptions.userDisplayStyle == UserDisplayStyle.singer ||
        _appOptions.userDisplayStyle == UserDisplayStyle.both;

    //  compute transposition offset from base key
    int tranOffset = displayMusicKey.getHalfStep() - song.getKey().getHalfStep();

    //  compute max row length
    int maxCols = song.chordRowMaxLength();
    int maxDisplayCols = (showChords ? maxCols : 1 /*  section marker  */
        ) +
        1 /*  lyrics  */;

    //  map the song moment grid to a flutter table, one row at a time
    for (var lyricSection in song.lyricSections) {
      ChordSection? chordSection = song.findChordSectionByLyricSection(lyricSection);
      if (chordSection == null) {
        assert(false); //  should never happen
        continue;
      }

      //  add the section heading
      color = GuiColors.getColorForSection(chordSection.getSection());
      {
        var globalKey = GlobalObjectKey(lyricSection);
        if (sectionHeaderWidget != null) {
          children.add(sectionHeaderWidget(globalKey, lyricSection));
        } else {
          children.add(Container(
            key: globalKey,
            margin: marginInsets,
            padding: textPadding,
            color: color,
            child: Text(
              chordSection.sectionVersion.toString(),
              style: _chordTextStyle,
              softWrap: false,
            ),
          ));
        }
        //  row length - 1 + 1 for missing lyrics
        for (int c = children.length; c < maxDisplayCols; c++) {
          children.add(const Text(''));
        }
        rows.add(TableRow(children: children));
        children = [];
        _lyricSectionRowLocations.add(LyricSectionRowLocation(lyricSection, rows.length, globalKey));
      }

      Key? _rowKey = UniqueKey();

      var expandedRowCount = chordSection.rowCount(expanded: true);
      var chordRowLimit = chordSection.rowCount(expanded: expandRepeats);
      var measureCount = 0;
      for (var row = 0; row < expandedRowCount; row++) {
        if (row >= chordRowLimit && row >= lyricSection.lyricsLines.length) {
          break; //  no more lyrics on this collapsed section
        }

        var measures = chordSection.rowAt(row, expanded: expandRepeats);

        //  collect lyrics and show chords if asked
        String rowLyrics = SongBase.shareLinesToRow(expandedRowCount, measureCount++, lyricSection.lyricsLines);
        rowLyrics = rowLyrics.replaceAll(verticalBarAndSpacesRegExp, ' ');
        for (int c = 0; c < maxCols; c++) {
          Measure? measure;
          if (c < measures.length) {
            measure = measures[c];
          }
          if (showChords) {
            if (_measureShouldBeVisible(measure)) {
              children.add(Container(
                  key: _rowKey,
                  margin: marginInsets,
                  padding: textPadding,
                  color: color,
                  child: appWidget.transpose(
                    measure!,
                    displayMusicKey,
                    tranOffset,
                    style: _chordTextStyle,
                  )));

              _rowKey = null;
            } else {
              //  empty cell
              children.add(Container(
                  margin: marginInsets,
                  child: const Text(
                    '',
                  )));
            }
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
                  rowLyrics.trim())));

          //  add row to table
          for (int c = children.length; c < maxDisplayCols; c++) {
            children.add(const Text(''));
          }
          rows.add(TableRow(
              //key: ValueKey(r),
              children: children));
        } else {
          //  short lyrics
          children.add(Container(
              margin: marginInsets,
              padding: const EdgeInsets.all(2),
              width: _shortLyricsWidth,
              color: color,
              child: Text(
                rowLyrics,
                style: _lyricsTextStyle,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
              )));

          //  add row to table
          for (int c = children.length; c < maxDisplayCols; c++) {
            children.add(const Text(''));
          }
          rows.add(TableRow(children: children));
        }

        //  get ready for the next row by clearing the row data
        children = [];
      }
    }

    if (lyricEndWidget != null) {
      children.add(lyricEndWidget());
      //  row length - 1 + 1 for missing lyrics
      for (int c = children.length; c < maxCols; c++) {
        children.add(const Text(''));
      }
      rows.add(TableRow(children: children));
      children = [];
    }

    _table = Table(
      key: GlobalKey(),
      defaultColumnWidth: const IntrinsicColumnWidth(), //  covers all
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
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
    App _app = App();
    _screenWidth = _app.screenInfo.widthInLogicalPixels;
    _screenHeight = _app.screenInfo.heightInLogicalPixels;
    _fontSize = appDefaultFontSize * min(4, max(1, _screenWidth / 500));
    _lyricsFontSize = fontSize * (_appOptions.userDisplayStyle == UserDisplayStyle.singer ? 1 : 0.65);
    _fontSize *= (_appOptions.userDisplayStyle == UserDisplayStyle.player ? 1.2 : 1);
    _shortLyricsWidth = _screenWidth * 0.20;

    _fontScale = fontSize / appDefaultFontSize;
    logger.v('lyricsTable: ($_screenWidth,$_screenHeight),'
        ' default:$appDefaultFontSize  => fontSize: $fontSize'
        ', _lyricsFontSize: $_lyricsFontSize, fontScale: $_fontScale');

    //  text styles
    _chordTextStyle = generateAppTextStyle(
      fontWeight: FontWeight.bold,
      fontSize: _fontSize,
      color: Colors.black87,
    );
    _lyricsTextStyle = generateAppTextStyle(
      fontWeight: FontWeight.normal,
      fontSize: _lyricsFontSize,
      color: Colors.black87,
    );
  }

  bool _measureShouldBeVisible(Measure? measure) {
    if (measure == null ||
        (measure is MeasureRepeatExtension && measure.marker == ChordSectionLocationMarker.repeatOnOneLineRight)) {
      return false;
    }
    return true;
  }

  double get screenWidth => _screenWidth;
  double _screenWidth = 100;

  double get screenHeight => _screenHeight;
  double _screenHeight = 50;

  List<LyricSectionRowLocation?> get lyricSectionRowLocations => _lyricSectionRowLocations;
  List<LyricSectionRowLocation?> _lyricSectionRowLocations = [];

  double get lyricsFontSize => _lyricsFontSize;
  double _lyricsFontSize = 18;

  double get fontSize => _fontSize;
  double _fontSize = 10;
  double _fontScale = 1;

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateAppTextStyle();

  double _shortLyricsWidth = 200; //  default value

  Table get table => _table;
  Table _table = Table();

  final AppWidget appWidget = AppWidget();

  music_key.Key displayMusicKey = music_key.Key.get(music_key.KeyEnum.C);
  final AppOptions _appOptions = AppOptions();
  final RegExp verticalBarAndSpacesRegExp = RegExp(r'\s*\|\s*');
}

/// helper class to help manage a song display
class LyricSectionRowLocation {
  LyricSectionRowLocation(this._lyricSection, this._row, this.key);

  @override
  String toString() {
    return ('${_row.toString()} ${key.toString()}'
        ', ${_lyricSection.toString()}');
  }

  int get sectionCount => _lyricSection.index;

  LyricSection get lyricSection => _lyricSection;
  final LyricSection _lyricSection;
  final int _row;
  final GlobalKey key;
}
