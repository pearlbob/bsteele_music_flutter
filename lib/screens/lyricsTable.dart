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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

/*
songs with issues?
the war was in color   one verse, many verse lyrics
africa
25 or 6 to 4
3 am     stagger in repeat column
a thousand miles
99 red balloons:  lyrics not distribution strained by repeats
babylon: long lyrics
dear mr. fantasy:  repeats at end of row don't align with each other
get it right next time:  repeats in measure column
 */

//  diagnostic logging enables
const Level _logFontSize = Level.debug;
const Level _logFontSizeDetail = Level.debug;
const Level _logLayout = Level.debug;

const double _paddingSizeMax = 10;
double _paddingSize = _paddingSizeMax;
EdgeInsets _padding = const EdgeInsets.all(_paddingSizeMax);
const double _marginSizeMax = 3.0;
double _marginSize = _marginSizeMax;

EdgeInsets _margin = const EdgeInsets.all(_marginSizeMax);

/// compute a lyrics table
class LyricsTable {
  Widget lyricsTable(
    Song song,
    BuildContext context, {
    music_key.Key? musicKey,
    expanded = false,
    SongMoment? selectedSongMoment,
  }) {
    appWidgetHelper = AppWidgetHelper(context);
    displayMusicKey = musicKey ?? song.key;
    locationGrid = Grid();

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

    _songMomentNumberToSongCell.clear();
    if (showLyrics) {
      //  build the table from the song lyrics and chords
      locationGrid = Grid();
      {
        Grid<MeasureNode> grid = song.toGrid(expanded: expanded);
        _songMomentToGridList = song.songMomentToGrid(expanded: expanded);

        for (int r = 0; r < grid.getRowCount(); r++) {
          var row = grid.getRow(r);
          var columns = row!.length;
          for (int c = 0; c < columns; c++) {
            //  fill the cells with rich text
            RichText richText = RichText(
                text: const TextSpan(
              text: '',
            ));
            var measureNode = row[c];
            switch (measureNode.runtimeType) {
              case Null:
                break;
              case ChordSection:
                {
                  var chordSection = measureNode as ChordSection;
                  _colorBySectionVersion(chordSection.sectionVersion);
                  richText = appWidgetHelper.chordSection(
                    chordSection,
                    style: _coloredBackgroundSectionTextStyle,
                  );
                }
                break;
              case Lyric:
                if (showLyrics) {
                  var lyric = measureNode as Lyric;

                  if (lyric.line.isEmpty) {
                  } else if (showFullLyrics) {
                    richText = RichText(text: TextSpan(text: lyric.line, style: _coloredBackgroundLyricsTextStyle));
                  } else {
                    //  short lyrics
                    richText = RichText(
                      text: TextSpan(text: lyric.line, style: _coloredBackgroundLyricsTextStyle),
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    );
                  }
                }
                break;
              default:
                if (showChords) {
                  switch (measureNode.runtimeType) {
                    case MeasureRepeatMarker:
                    case MeasureRepeatExtension:
                    case Measure:
                      richText = appWidgetHelper.transpose(
                        measureNode as Measure,
                        displayMusicKey,
                        transpositionOffset,
                        style: _coloredChordTextStyle,
                      );
                      break;
                    default:
                      richText = RichText(
                          text: TextSpan(
                        text: '($r,$c)', //  diagnostic only!
                        style: c == columns - 1 ? _lyricsTextStyle : _coloredChordTextStyle,
                      ));
                      break;
                  }
                }
                break;
            }

            //  render the text to find text size for each cell (prior to padding and margin)
            //  note: this is not available from the widget table since it hasn't been rendered yet
            TextPainter textPainter = TextPainter()
              ..text = richText.text
              ..textDirection = TextDirection.ltr
              ..layout(minWidth: 0, maxWidth: double.infinity);
            logger.log(_logLayout, '($r,$c): "${richText.text.toPlainText()}": ${textPainter.size}');
            locationGrid.set(r, c, SongCell(richText: richText, measureNode: measureNode));
          }
        }
      }

      logger.log(_logFontSizeDetail, locationGrid.toMultiLineString());

      //  compute row heights and column widths
      var columnWidths = <double>[];
      final rowHeights = List<double>.filled(locationGrid.getRowCount(), 0);
      final rowMeasureHeights = List<double>.filled(locationGrid.getRowCount(), 0);
      if (locationGrid.getRowCount() > 0) {
        final int rowLength = locationGrid.getRow(0)?.length ?? 1;
        columnWidths = List<double>.filled(rowLength, 0);
        assert(rowLength > 0);
        double maxChordWidth = 0;
        double maxLyricsWidth = 0;
        for (var r = 0; r < locationGrid.getRowCount(); r++) {
          var row = locationGrid.getRow(r);
          if (row == null) {
            assert(false); //  shouldn't happen
            continue; //  for release version
          }
          assert(row.length == rowLength); //  all rows should be of the same length

          //  find the minimum width and height for each column and row
          double chordWidth = 0;
          double lyricsWidth = 0;
          double rowHeight = 0;
          double rowMeasureHeight = 0;
          for (var c = 0; c < rowLength; c++) {
            var cell = locationGrid.get(r, c);
            assert(cell != null);
            if (cell == null) {
              continue;
            }
            Size cellSize = cell._computeBuildSize();
            double width = cellSize.width;
            switch (_appOptions.userDisplayStyle) {
              case UserDisplayStyle.both:
              case UserDisplayStyle.player:
              case UserDisplayStyle.singer: //  section headers count as "chords"
                if (c < rowLength - 1) {
                  //  chord
                  chordWidth += width;
                } else {
                  lyricsWidth += width;
                }
                break;
              case UserDisplayStyle.proPlayer:
                //  sections and chords only
                chordWidth += width;
                break;
            }
            columnWidths[c] = max(columnWidths[c], width);
            switch (cell.measureNode?.measureNodeType) {
              case MeasureNodeType.measure:
              case MeasureNodeType.decoration:
              case MeasureNodeType.repeat:
                rowMeasureHeight = max(rowHeight, cellSize.height + 2 * _marginSize);
                break;
              default:
                break;
            }
            rowHeight = max(rowHeight, cellSize.height + 2 * _marginSize);
          }

          rowHeights[r] = rowHeight;
          rowMeasureHeights[r] = rowMeasureHeight;

          logger.log(_logFontSizeDetail, 'row $r:  chordWidth: $chordWidth, lyricsWidth: $lyricsWidth,');
          maxChordWidth = max(maxChordWidth, chordWidth);
          maxLyricsWidth = max(maxLyricsWidth, lyricsWidth);
        }
        logger.log(_logFontSize, 'maxChordWidth: $maxChordWidth, maxLyricsWidth: $maxLyricsWidth,');
        logger.log(_logFontSizeDetail, 'columWidths: $columnWidths');
        logger.log(_logFontSizeDetail, 'rowHeights: $rowHeights');
        logger.log(_logFontSizeDetail, 'rowMeasureHeights: $rowMeasureHeights');

        //  scale the song to the display
        _scaleFactor = 1.0;
        double arrowIndicatorWidth = _chordFontSize;
        {
          var width = 3 * _marginSize + arrowIndicatorWidth * _scaleFactor;
          for (var w in columnWidths) {
            width += w + 3 * _marginSize;
          }
          logger.log(
              _logFontSizeDetail,
              'column width/display width: $width/$screenWidth'
              ' = ${(width / screenWidth).toStringAsFixed(3)}');
          _scaleFactor = Util.doubleLimit(screenWidth / width, 0.10, 1.0);
        }
        logger.log(_logFontSizeDetail, 'scaleFactor: $_scaleFactor');
        _scaleComponents(scaleFactor: _scaleFactor);

        //  fill the location grid
        {
          double y = 0;
          for (var r = 0; r < rowHeights.length; r++) {
            double x = 2 * _marginSize + arrowIndicatorWidth * _scaleFactor;
            for (var c = 0; c < columnWidths.length; c++) {
              var songCell = locationGrid.get(r, c);
              assert(songCell != null);
              songCell = songCell!;
              Size size;
              switch (songCell.measureNode?.measureNodeType) {
                case MeasureNodeType.section:
                  size = songCell._computeBuildSize();
                  break;
                case MeasureNodeType.measure:
                  size = Size(columnWidths[c], rowMeasureHeights[r]);
                  break;
                case MeasureNodeType.decoration:
                  size = Size(songCell._computeBuildSize().width, rowMeasureHeights[r]);
                  break;
                default:
                  size = Size(columnWidths[c], rowHeights[r]);
                  break;
              }
              logger.v('($r,$c): type: ${songCell.measureNode?.measureNodeType}: ($x,$y): size: $size');
              locationGrid.set(
                  r,
                  c,
                  songCell.copyWith(
                      size: size * _scaleFactor,
                      point: Point<double>(x, y), //  already scaled
                      columnWidth: columnWidths[c] * _scaleFactor, //  for even column widths
                      scaleFactor: _scaleFactor));
              x += columnWidths[c] * _scaleFactor + 3 * _marginSize;
              logger.v('   x = $x');
            }
            y += rowHeights[r] * _scaleFactor;
          }
        }
      }

      if (locationGrid.isEmpty) {
        _table = Text(
          'data missing',
          key: GlobalKey(),
        );
      } else {
        //  generate lookup data
        _songMomentNumberToSongCell.clear();
        for (var songMoment in song.songMoments) {
          assert(songMoment.momentNumber >= 0);
          assert(songMoment.momentNumber < _songMomentToGridList.length);
          var gridCoordinate = _songMomentToGridList[songMoment.momentNumber];
          var cell = locationGrid.get(gridCoordinate.row, gridCoordinate.col);
          assert(cell != null);
          _songMomentNumberToSongCell.add(cell ?? _emptySongCell);
        }
        assert(song.songMoments.length == _songMomentNumberToSongCell.length);
        if (kDebugMode) {
          //   test the mapping
          for (var songMoment in song.songMoments) {
            var cell = _songMomentNumberToSongCell[songMoment.momentNumber];
            assert(cell.measureNode == songMoment.measure);
            logger.v('songMoment: ${songMoment.momentNumber}: ${cell.point} ${cell.rect}');
          }
        }

        //  generate widget rows from grid
        var arrowWidget = appIcon(
          Icons.play_arrow,
          size: _chordFontSize * _scaleFactor,
          color: Colors.redAccent,
        );
        var selectedArrowCell = _songMomentNumberToSongCell[selectedSongMoment?.momentNumber ?? 0];
        var rows = <Widget>[];
        for (var r = 0; r < locationGrid.getRowCount(); r++) {
          bool selectThisRow = false;
          var row = locationGrid.getRow(r);
          assert(row != null);
          row = row!;
          assert(row.isNotEmpty);
          assert(row.length == locationGrid.getRow(0)?.length);
          var cellRow = <SongCell>[];
          for (var c = 0; c < row.length; c++) {
            var cell = locationGrid.get(r, c);
            assert(cell != null);
            cellRow.add(cell!);
            if (selectedArrowCell == cell) {
              selectThisRow = true;
            }
          }
          rows.add(AppWrapFullWidth(
            spacing: _marginSize,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(
                width: _chordFontSize * _scaleFactor,
                child: selectThisRow ? arrowWidget : null,
              ),
              ...cellRow
            ],
          ));
        }
        _table = Column(children: rows);
      }

      logger.d('lyricsTable: ($_screenWidth,$_screenHeight),'
          ' default:$appDefaultFontSize  => _chordFontSize: ${_chordFontSize.toStringAsFixed(1)}'
          ', _lyricsFontSize: ${_lyricsFontSize.toStringAsFixed(1)}');

      return Container(
          key: GlobalKey(), margin: EdgeInsets.only(left: _marginSize), child: Column(children: <Widget>[_table]));
    } else {
      //  don't show any lyrics, i.e. pro player

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
        var chordRow = <SongCell>[];
        for (int c = 0; c < row.length; c++) {
          var data = chordGrid.get(r, c);
          if (data == null) {
            chordRow.add(_emptySongCell);
            continue;
          }
          _colorBySectionVersion(data.sectionVersion);

          final richText = data.isMeasure
              ? appWidgetHelper.transpose(
                  data.measure!,
                  musicKey ?? music_key.Key.C,
                  transpositionOffset,
                  style: _coloredChordTextStyle,
                )
              : RichText(
                  text: TextSpan(
                      text: data.transpose(musicKey ?? music_key.Key.C, transpositionOffset),
                      style: _coloredChordTextStyle),
                  //  don't allow the rich text to wrap:
                  textWidthBasis: TextWidthBasis.longestLine,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  textDirection: TextDirection.ltr,
                  textScaleFactor: 1.0,
                  textAlign: TextAlign.start,
                  textHeightBehavior: const TextHeightBehavior(),
                );

          chordRow.add(SongCell(richText: richText));
        }
        while (chordRow.length < maxCols) {
          chordRow.add(_emptySongCell);
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

  void _colorBySectionVersion(SectionVersion sectionVersion) {
    _sectionBackgroundColor = getBackgroundColorForSectionVersion(sectionVersion);
    _coloredChordTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _sectionBackgroundColor,
    );
    _coloredBackgroundLyricsTextStyle = _lyricsTextStyle.copyWith(backgroundColor: _sectionBackgroundColor);
    _coloredBackgroundSectionTextStyle =
        _coloredBackgroundLyricsTextStyle.copyWith(fontSize: _sectionTextStyle.fontSize);
  }

  /// compute screen size values used here and on other screens
  void _computeScreenSizes() {
    App app = App();
    _screenWidth = app.screenInfo.mediaWidth;
    _screenHeight = app.screenInfo.mediaHeight;

    //  rough in the basic fontsize
    _chordFontSize = 80; // max for hdmi resolution

    _scaleComponents();
    _lyricsFontSize = _chordFontSize * 0.55;

    //  text styles
    _chordTextStyle = generateChordTextStyle(fontSize: _chordFontSize);
    _sectionTextStyle = generateChordTextStyle(fontSize: _chordFontSize * 0.75);
    _lyricsTextStyle = generateLyricsTextStyle(fontSize: _lyricsFontSize);
  }

  _scaleComponents({double scaleFactor = 1.0}) {
    _paddingSize = Util.doubleLimit(_chordFontSize / 10, 2, _paddingSizeMax) * scaleFactor;
    _padding = EdgeInsets.all(_paddingSize);
    _marginSize = _marginSizeMax * scaleFactor;
    _margin = EdgeInsets.all(_marginSize);

    logger.log(
        _logFontSize,
        '_scaleComponents(): _chordFontSize: ${_chordFontSize.toStringAsFixed(2)}'
        ', _marginSize: ${_marginSize.toStringAsFixed(2)}'
        ', padding: ${_paddingSize.toStringAsFixed(2)}');
  }

  double songMomentToY(SongMoment songMoment) {
    assert(songMoment.momentNumber >= 0 && songMoment.momentNumber < _songMomentNumberToSongCell.length);
    return _songMomentNumberToSongCell[songMoment.momentNumber].point?.y ?? 0;
  }

  static final emptyRichText = RichText(text: const TextSpan(text: ''));

  double get screenWidth => _screenWidth;
  double _screenWidth = 100;

  double get screenHeight => _screenHeight;
  double _screenHeight = 50;

  double get lyricsFontSize => _lyricsFontSize * _scaleFactor;
  double _lyricsFontSize = 18;

  double? get chordFontSize => _chordFontSize;
  double _chordFontSize = appDefaultFontSize;

  double get marginSize => _marginSize;

  Grid<SongCell> locationGrid = Grid();

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get sectionTextStyle => _sectionTextStyle;
  TextStyle _sectionTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateLyricsTextStyle();

  Color _sectionBackgroundColor = Colors.white;
  TextStyle _coloredChordTextStyle = generateLyricsTextStyle();

  TextStyle _coloredBackgroundSectionTextStyle = generateLyricsTextStyle();
  TextStyle _coloredBackgroundLyricsTextStyle = generateLyricsTextStyle();

  List<GridCoordinate> get songMomentToGridList => _songMomentToGridList;
  List<GridCoordinate> _songMomentToGridList = [];
  final List<SongCell> _songMomentNumberToSongCell = [];

  Widget get table => _table;
  Widget _table = const Text('empty');
  double _scaleFactor = 1.0;

  late AppWidgetHelper appWidgetHelper;

  music_key.Key displayMusicKey = music_key.Key.C;
  final AppOptions _appOptions = AppOptions();
  final RegExp verticalBarAndSpacesRegExp = RegExp(r'\s*\|\s*');
}

class SongCell extends StatelessWidget {
  const SongCell(
      {required this.richText,
      this.measureNode,
      super.key,
      this.size,
      this.point,
      this.columnWidth,
      this.scaleFactor = 1.0});

  SongCell copyWith({Size? size, Point<double>? point, double? columnWidth, double scaleFactor = 1.0}) {
    //  count on package level margin and padding to have been scaled elsewhere
    return SongCell(
      richText: RichText(
        text: richText.text,
        textScaleFactor: scaleFactor,
        key: richText.key,
        softWrap: richText.softWrap,
      ),
      measureNode: measureNode,
      size: size,
      point: point,
      columnWidth: columnWidth,
      scaleFactor: scaleFactor,
    );
  }

  final RichText richText;
  final MeasureNode? measureNode;

  @override
  Widget build(BuildContext context) {
    Size buildSize = _computeBuildSize();
    if ((size?.width ?? 0) < (columnWidth ?? 0)) {
      //  put the narrow column width on the left of a container
      //  do the following row element is aligned in the next column
      return Container(
        alignment: Alignment.centerLeft,
        width: columnWidth,
        height: buildSize.height,
        color: Colors.transparent,
        margin: _margin,
        child: Container(
          width: buildSize.width,
          height: buildSize.height,
          padding: _padding,
          color: richText.text.style?.backgroundColor ?? Colors.transparent,
          child: richText,
        ),
      );
    }
    return Container(
      width: columnWidth ?? buildSize.width,
      height: buildSize.height,
      margin: _margin,
      padding: _padding,
      color: richText.text.style?.backgroundColor ?? Colors.transparent,
      child: richText,
    );
  }

  ///  efficiency compromised for const StatelessWidget song cell
  Size _computeBuildSize() {
    return _computeTextSize() + Offset(_paddingSize, _paddingSize) * 2;
  }

  Size _computeTextSize() {
    TextPainter textPainter =
        TextPainter(text: richText.text, textDirection: TextDirection.ltr, textScaleFactor: scaleFactor)
          ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  get rect {
    Size buildSize = size ?? _computeBuildSize();
    return Rect.fromLTWH(point?.x ?? 0.0, point?.y ?? 0.0, buildSize.width, buildSize.height);
  }

  @override
  String toString({DiagnosticLevel? minLevel}) {
    return 'SongCell{richText: $richText, measureNode: $measureNode'
        ', type: ${measureNode?.measureNodeType}, size: $size, point: $point}';
  }

  final double scaleFactor;
  final Size? size;
  final double? columnWidth;
  final Point<double>? point;
}

final _emptySongCell = SongCell(richText: RichText(text: const TextSpan(text: '')));

/*

locationGrid
Grid<SongCell>

songMomentNumberToSongCell
List<SongCell>
  using List<GridCoordinate> _songMomentToGridList and Grid<SongCell> locationGrid

Y to songMoment.number    for loose scrolling
Map<double,int>
  inverted songMomentNumberToSongCell

for section bump:
lyricSection to Y
	Map<lyricSection,firstSongCell>     or  List[songMoment] by section index
	    generated from songMomentNumberToSongCell using songMoment.lyricsSection
Y to lyricSection
	y to songMoment -> songMoment.lyricSection
 */
