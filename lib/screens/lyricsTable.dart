import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/gridCoordinate.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyric.dart';
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:bsteeleMusicLib/songs/measureNode.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

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
    expanded = false,
    double? chordFontSize,
  }) {
    appWidgetHelper = AppWidgetHelper(context);
    displayMusicKey = musicKey ?? song.key;
    _chordFontSize = chordFontSize;

    _computeScreenSizes();

    //  build the table from the song lyrics and chords
    if (song.lyricSections.isEmpty) {
      _table = Table(
        key: GlobalKey(),
      );
      return _table;
    }

    List<TableRow> rows = [];
    List<Widget> children = []; //  items for the current row
    _backgroundColor = getBackgroundColorForSection(Section.get(SectionEnum.chorus));

    //  display style booleans
    bool showChords = _appOptions.userDisplayStyle == UserDisplayStyle.player ||
        _appOptions.userDisplayStyle == UserDisplayStyle.both;
    bool showFullLyrics = _appOptions.userDisplayStyle == UserDisplayStyle.singer ||
        _appOptions.userDisplayStyle == UserDisplayStyle.both;

    //  compute transposition offset from base key
    int tranOffset = displayMusicKey.getHalfStep() - song.getKey().getHalfStep();

    _grid = song.toGrid(expanded: expanded);
    _songMomentToGridList = song.songMomentToGrid(expanded: expanded);

    {
      Widget w;

      _colorBySection(ChordSection.getDefault());

      for (int r = 0; r < _grid.getRowCount(); r++) {
        children = [];
        var row = _grid.getRow(r);
        var columns = row!.length;
        for (int c = 0; c < columns; c++) {
          var measureNode = row[c];
          switch (measureNode.runtimeType) {
            case Null:
              w = const Text('');
              break;
            case ChordSection:
              {
                var chordSection = measureNode as ChordSection;
                _colorBySection(chordSection);
                w = _box(appWidgetHelper.chordSection(
                  chordSection,
                  style: _coloredChordTextStyle,
                ));
              }
              break;
            case Lyric:
              {
                var lyric = measureNode as Lyric;

                if (lyric.line.isEmpty) {
                  w = const Text('');
                } else if (showFullLyrics) {
                  w = _box(Text(
                    lyric.line,
                    style: _coloredBackgroundLyricsTextStyle,
                  ));
                } else {
                  //  short lyrics
                  w = _box(Text(
                    lyric.line,
                    style: _coloredBackgroundLyricsTextStyle,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ));
                }
              }
              break;
            default:
              if (showChords) {
                if (measureNode is Measure) {
                  w = _box(appWidgetHelper.transpose(
                    measureNode,
                    displayMusicKey,
                    tranOffset,
                    style: _coloredChordTextStyle,
                  ));
                } else {
                  w = _box(Text(
                    '($r,$c)',
                    style: c == columns - 1 ? _lyricsTextStyle : _chordTextStyle,
                  ));
                }
              } else {
                w = const Text('');
              }
              break;
          }
          children.add(w);
        }
        rows.add(TableRow(children: children));
      }
    }

    Map<int, TableColumnWidth>? columnWidths = {};
    if (rows.isNotEmpty) {
      columnWidths[rows[0].children!.length - 1] =
          MinColumnWidth(const IntrinsicColumnWidth(), FractionColumnWidth(showChords ? 0.35 : 0.95));
    }

    _table = Table(
      key: GlobalKey(),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: columnWidths,
      //  covers all
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
      border: TableBorder.symmetric(),
    );

    logger.d('lyricsTable: ($_screenWidth,$_screenHeight),'
        ' default:$appDefaultFontSize  => _chordFontSize: ${_chordFontSize?.toStringAsFixed(1)}'
        ', _lyricsFontSize: ${_lyricsFontSize.toStringAsFixed(1)}');

    return _table;
  }

  Widget _box(Widget w) {
    return Container(
      margin: getMeasureMargin(),
      padding: getMeasurePadding(),
      color: _backgroundColor,
      child: w,
    );
  }

  void _colorBySection(ChordSection chordSection) {
    _backgroundColor = getBackgroundColorForSection(chordSection.getSection());
    _coloredChordTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _backgroundColor,
    );
    _coloredBackgroundLyricsTextStyle = _lyricsTextStyle.copyWith(backgroundColor: _backgroundColor);
  }

  /// compute screen size values used here and on other screens
  void _computeScreenSizes() {
    App app = App();
    _screenWidth = app.screenInfo.widthInLogicalPixels;
    _screenHeight = app.screenInfo.heightInLogicalPixels;
    _chordFontSize ??= appDefaultFontSize * min(4, max(1, _screenWidth / 500));
    _lyricsFontSize = _chordFontSize! * 0.6;

    //  text styles
    _chordTextStyle = generateChordTextStyle(fontSize: _chordFontSize);

    _lyricsTextStyle = generateLyricsTextStyle(fontSize: _lyricsFontSize);
  }

  double get screenWidth => _screenWidth;
  double _screenWidth = 100;

  double get screenHeight => _screenHeight;
  double _screenHeight = 50;

  double get lyricsFontSize => _lyricsFontSize;
  double _lyricsFontSize = 18;

  double? get chordFontSize => _chordFontSize;
  double? _chordFontSize;

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateLyricsTextStyle();

  Color _backgroundColor = Colors.white;
  TextStyle _coloredChordTextStyle = generateLyricsTextStyle();
  TextStyle _coloredBackgroundLyricsTextStyle = generateLyricsTextStyle();

  //Grid<MeasureNode> get grid => _grid;
  Grid<MeasureNode> _grid = Grid();

  List<GridCoordinate> get songMomentToGridList => _songMomentToGridList;
  List<GridCoordinate> _songMomentToGridList = [];

  Table get table => _table;
  Table _table = Table();

  late AppWidgetHelper appWidgetHelper;

  music_key.Key displayMusicKey = music_key.Key.get(music_key.KeyEnum.C);
  final AppOptions _appOptions = AppOptions();
  final RegExp verticalBarAndSpacesRegExp = RegExp(r'\s*\|\s*');
}