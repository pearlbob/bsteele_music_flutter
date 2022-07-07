import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/gridCoordinate.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyric.dart';
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:bsteeleMusicLib/songs/measureNode.dart';
import 'package:bsteeleMusicLib/songs/measureRepeatExtension.dart';
import 'package:bsteeleMusicLib/songs/measureRepeatMarker.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/sectionVersion.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

//  diagnostic logging enables
//const Level _lyricsTableLogBuild = Level.debug;
const Level _lyricsTableLogFontSize = Level.debug;

/// compute a lyrics table
class LyricsTable {
  Widget lyricsTable(
    Song song,
    BuildContext context, {
    music_key.Key? musicKey,
    expanded = false,
    double? chordFontSize,
    List<SongMoment>? givenSelectedSongMoments,
    double? lyricsFraction,
  }) {
    appWidgetHelper = AppWidgetHelper(context);
    displayMusicKey = musicKey ?? song.key;
    _chordFontSize = chordFontSize;
    List<SongMoment> selectedSongMoments = givenSelectedSongMoments ?? [];

    _computeScreenSizes();

    _sectionBackgroundColor =
        getBackgroundColorForSectionVersion(SectionVersion.bySection(Section.get(SectionEnum.chorus)));

    //  display style booleans
    bool showChords = _appOptions.userDisplayStyle == UserDisplayStyle.player ||
        _appOptions.userDisplayStyle == UserDisplayStyle.proPlayer ||
        _appOptions.userDisplayStyle == UserDisplayStyle.both;
    bool showLyrics = _appOptions.userDisplayStyle != UserDisplayStyle.proPlayer;
    bool showFullLyrics = _appOptions.userDisplayStyle == UserDisplayStyle.singer ||
        _appOptions.userDisplayStyle == UserDisplayStyle.both;

    //  compute transposition offset from base key
    int transpositionOffset = displayMusicKey.getHalfStep() - song.getKey().getHalfStep();

    _colorBySectionVersion(SectionVersion.defaultInstance);

    if (showLyrics) {
      //  build the table from the song lyrics and chords
      List<TableRow> rows = [];
      List<Widget> children = []; //  items for the current row
      bool hasLyrics = false;
      {
        Grid<MeasureNode> grid = song.toGrid(expanded: expanded);
        _songMomentToGridList = song.songMomentToGrid(expanded: expanded);

        Widget w;

        TextStyle textStyle = _coloredChordTextStyle;
        for (int r = 0; r < grid.getRowCount(); r++) {
          children = [
            AppSpace(horizontalSpace: _lyricsFontSize) //  slot for play arrow
          ];
          var row = grid.getRow(r);
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
                  _colorBySectionVersion(chordSection.sectionVersion);
                  w = _box(appWidgetHelper.chordSection(
                    chordSection,
                    style: _coloredBackgroundLyricsTextStyle,
                  ));
                }
                break;
              case Lyric:
                if (showLyrics) {
                  var lyric = measureNode as Lyric;
                  hasLyrics = true;

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
                } else {
                  w = const Text('');
                }
                break;
              default:
                if (showChords) {
                  switch (measureNode.runtimeType) {
                    case MeasureRepeatMarker:
                    case MeasureRepeatExtension:
                      w = _measureBox(
                          Text(
                            measureNode.toString(),
                            style: _coloredChordTextStyle,
                          ),
                          selectionColor:
                              textStyle.backgroundColor //  note the trick, uses textStyle from prior measures
                          );
                      break;
                    case Measure:
                      {
                        //  setup the text style
                        var index = _songMomentToGridList.indexOf(GridCoordinate(r, c));
                        var songMoment = song.songMoments[index];
                        bool isSelected = selectedSongMoments.contains(songMoment);
                        textStyle = isSelected ? _selectedChordTextStyle : _coloredChordTextStyle;
                        // logger.i('selectedSongMoments: $selectedSongMoments');
                      }
                      w = _measureBox(
                          appWidgetHelper.transpose(
                            measureNode as Measure,
                            displayMusicKey,
                            transpositionOffset,
                            style: _coloredChordTextStyle,
                          ),
                          selectionColor: textStyle.backgroundColor);
                      break;
                    default:
                      w = _box(Text(
                        '($r,$c)', //  diagnostic only!
                        style: c == columns - 1 ? _lyricsTextStyle : _coloredChordTextStyle,
                      ));
                      break;
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

      if (rows.isEmpty) {
        _table = Table(
          key: GlobalKey(),
        );
      } else {
        Map<int, TableColumnWidth>? columnWidths = {};
        if (rows.isNotEmpty && hasLyrics) {
          columnWidths[rows[0].children!.length - 1] = const FlexColumnWidth();
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
      }

      logger.d('lyricsTable: ($_screenWidth,$_screenHeight),'
          ' default:$appDefaultFontSize  => _chordFontSize: ${_chordFontSize?.toStringAsFixed(1)}'
          ', _lyricsFontSize: ${_lyricsFontSize.toStringAsFixed(1)}');

      return _table;
    } else {
      //  don't show lyrics

      //  list the lyrics sections
      var sections = <Widget>[];
      for (var lyricSection in song.lyricSections) {
        _colorBySectionVersion(lyricSection.sectionVersion);
        sections.add(
          Container(
            padding: const EdgeInsets.all(15.0),
            margin: const EdgeInsets.all(4.0),
            color: _coloredChordTextStyle.backgroundColor,
            child: Text(
              lyricSection.sectionVersion.toString().replaceAll(
                    ':',
                    '',
                  ),
              style: _coloredChordTextStyle,
            ),
          ),
        );
      }

      //  show the chord table
      List<TableRow> tableRows = [];
      var chordGrid = song.chordSectionGrid;
      int maxCols = 0;
      for (int r = 0; r < chordGrid.getRowCount(); r++) {
        maxCols = max(maxCols, chordGrid.getRow(r)?.length ?? 0);
      }
      for (int r = 0; r < chordGrid.getRowCount(); r++) {
        var row = chordGrid.getRow(r);
        if (row == null) {
          continue;
        }
        var chordRow = <Widget>[];
        for (int c = 0; c < row.length; c++) {
          var data = chordGrid.get(r, c);
          if (data == null) {
            chordRow.add(
              const Text(
                ' ',
              ),
            );
            continue;
          }
          _colorBySectionVersion(data.sectionVersion);
          chordRow.add(
            _box(
              Text(
                data.transpose(musicKey ?? music_key.Key.C, transpositionOffset),
                style: _coloredChordTextStyle,
              ),
            ),
          );
        }
        while (chordRow.length < maxCols) {
          chordRow.add(const Text(''));
        }
        tableRows.add(TableRow(children: chordRow));
      }

      return Column(
        children: [
          AppWrapFullWidth(children: sections),
          const AppSpace(
            verticalSpace: 10,
          ),
          Table(
            key: GlobalKey(),
            defaultColumnWidth: const IntrinsicColumnWidth(),
            //  covers all
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: tableRows,
            //   border: const TableBorder(),
          ),
        ],
      );
    }
  }

  Widget _measureBox(Widget w, {Color? selectionColor}) {
    return Container(
      //  outline container
      margin: getMeasureMargin(),
      padding: _padding,
      color: selectionColor ?? _sectionBackgroundColor,
      child: Container(
        //  inner container of section color
        margin: getMeasureMargin(),
        padding: _padding,
        color: _sectionBackgroundColor,
        child: w,
      ),
    );
  }

  Widget _box(Widget w) {
    return Container(
      margin: getMeasureMargin(),
      padding: getMeasurePadding(),
      color: _sectionBackgroundColor,
      child: w,
    );
  }

  void _colorBySectionVersion(SectionVersion sectionVersion) {
    _sectionBackgroundColor = getBackgroundColorForSectionVersion(sectionVersion);
    _coloredChordTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _sectionBackgroundColor,
    );
    _selectedChordTextStyle = _chordTextStyle.copyWith(
      backgroundColor: Colors.red, //  fixme: add to css
    );
    _coloredBackgroundLyricsTextStyle = _lyricsTextStyle.copyWith(backgroundColor: _sectionBackgroundColor);
  }

  /// compute screen size values used here and on other screens
  void _computeScreenSizes() {
    App app = App();
    const usableRatio = 0.93;
    _screenWidth = app.screenInfo.mediaWidth;
    _screenHeight = app.screenInfo.mediaHeight;

    const screenFraction = 1.0 / 200;
    _chordFontSize ??= appDefaultFontSize * min(8, max(1, _screenWidth * usableRatio * screenFraction));
    double paddingSize = Util.doubleLimit(_chordFontSize! / 10, 0.5, 8);
    logger.log(
        _lyricsTableLogFontSize,
        '_computeScreenSizes(): _chordFontSize: ${_chordFontSize?.toStringAsFixed(2)}'
        ', _screenWidth: ${_screenWidth.toStringAsFixed(2)}');
    logger.log(
        _lyricsTableLogFontSize,
        ', screenFraction: ${screenFraction.toStringAsFixed(4)}'
        ', padding: ${paddingSize.toStringAsFixed(2)}');
    _lyricsFontSize = _chordFontSize! * 0.5;

    _padding = EdgeInsets.all(paddingSize);

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
  EdgeInsets _padding = const EdgeInsets.all(5);

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateLyricsTextStyle();

  Color _sectionBackgroundColor = Colors.white;
  TextStyle _coloredChordTextStyle = generateLyricsTextStyle();
  TextStyle _selectedChordTextStyle = generateLyricsTextStyle();

  TextStyle _coloredBackgroundLyricsTextStyle = generateLyricsTextStyle();

  List<GridCoordinate> get songMomentToGridList => _songMomentToGridList;
  List<GridCoordinate> _songMomentToGridList = [];

  Table get table => _table;
  Table _table = Table();

  late AppWidgetHelper appWidgetHelper;

  music_key.Key displayMusicKey = music_key.Key.C;
  final AppOptions _appOptions = AppOptions();
  final RegExp verticalBarAndSpacesRegExp = RegExp(r'\s*\|\s*');
}
