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

/*
songs with issues?
the war was in color   one verse, many verse lyrics
africa
25 or 6 to 4
a thousand miles
99 red balloons:  lyrics not distribution strained by repeats
babylon: long lyrics
dear mr. fantasy:  repeats at end of row don't align with each other
get it right next time:  repeats in measure column
 */

//  diagnostic logging enables
const Level _logFontSize = Level.info;
const Level _logFontSizeDetail = Level.debug;
const Level _logLayout = Level.debug;

const double _paddingSizeMax = 10;
double _paddingSize = _paddingSizeMax;
EdgeInsets _padding = const EdgeInsets.all(_paddingSizeMax);
const double _marginSizeMax = 4.0;
double _marginSize = _marginSizeMax;
EdgeInsets _margin = const EdgeInsets.all(_marginSizeMax);

/// compute a lyrics table
class LyricsTable {
  Widget lyricsTable(
    Song song,
    BuildContext context, {
    music_key.Key? musicKey,
    expanded = false,
    List<SongMoment>? givenSelectedSongMoments,
    double? lyricsFraction,
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
            RichText? richText;
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
                    style: _coloredBackgroundLyricsTextStyle,
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

            if (richText != null) {
              //  render the text to find text size for each cell (prior to padding and margin)
              //  note: this is not available from the widget table since it hasn't been rendered yet
              TextPainter textPainter = TextPainter()
                ..text = richText.text
                ..textDirection = TextDirection.ltr
                ..layout(minWidth: 0, maxWidth: double.infinity);
              logger.log(_logLayout, '($r,$c): "${richText.text.toPlainText()}": ${textPainter.size}');
              locationGrid.set(r, c, SongCell(richText: richText, measureNode: measureNode));
            } else {
              locationGrid.set(r, c, SongCell(richText: richText, measureNode: measureNode));
            }
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
            if (cell == null) {
              continue;
            }
            double width = cell.width;
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
                rowMeasureHeight = max(rowHeight, cell.height + 2 * defaultTableGap);
                break;
              default:
                break;
            }
            rowHeight = max(rowHeight, cell.height + 2 * defaultTableGap);
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
        {
          var width = 3 * defaultTableGap;
          for (var w in columnWidths) {
            width += w + 3 * defaultTableGap;
          }
          logger.i('column width/display width: $width/$screenWidth  = ${(width / screenWidth).toStringAsFixed(3)}');
        }

        //  fill the location grid
        {
          double y = 0;
          for (var r = 0; r < rowHeights.length; r++) {
            double x = 0;
            for (var c = 0; c < columnWidths.length; c++) {
              var songCell = locationGrid.get(r, c);
              Size? size;
              switch (songCell?.measureNode?.measureNodeType) {
                case MeasureNodeType.section:
                  size = songCell?._buildSize;
                  break;
                case MeasureNodeType.measure:
                  size = Size(columnWidths[c], rowMeasureHeights[r]);
                  break;
                case MeasureNodeType.decoration:
                  size = Size(songCell?._buildSize.width ?? columnWidths[c], rowMeasureHeights[r]);
                  break;
                default:
                  size = Size(columnWidths[c], rowHeights[r]);
                  break;
              }
              logger.v('($r,$c): type: ${songCell?.measureNode?.measureNodeType}: ($x,$y): size: $size');
              locationGrid.set(r, c, songCell?.copyWith(point: Point(x, y), size: size, columnWidth: columnWidths[c]));
              logger.v('x + columnWidths[c] + 3 * defaultTableGap == x + ${columnWidths[c] + 3 * defaultTableGap}'
                  ' = ${x + columnWidths[c] + 3 * defaultTableGap}');
              x += columnWidths[c] + 3 * defaultTableGap;
              logger.v('   x = $x');
            }
            y += rowHeights[r] + 2 * defaultTableGap;
          }
        }
      }

      if (locationGrid.isEmpty) {
        _table = Text(
          'data missing',
          key: GlobalKey(),
        );
      } else {
        var rows = <Widget>[];

        for (var r = 0; r < locationGrid.getRowCount(); r++) {
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
          }
          rows.add(AppWrapFullWidth(
            spacing: defaultTableGap,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: cellRow,
          ));
        }
        _table = Column(children: rows);
      }

      logger.d('lyricsTable: ($_screenWidth,$_screenHeight),'
          ' default:$appDefaultFontSize  => _chordFontSize: ${_chordFontSize?.toStringAsFixed(1)}'
          ', _lyricsFontSize: ${_lyricsFontSize.toStringAsFixed(1)}');

      return Column(key: GlobalKey(), children: <Widget>[_table]);
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
            chordRow.add(const SongCell());
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
          chordRow.add(const SongCell());
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
  }

  /// compute screen size values used here and on other screens
  void _computeScreenSizes() {
    App app = App();
    const usableRatio = 0.93;
    _screenWidth = app.screenInfo.mediaWidth;
    _screenHeight = app.screenInfo.mediaHeight;

    const screenFraction = 1.0 / 200;
    _chordFontSize = appDefaultFontSize * min(8, max(1, _screenWidth * usableRatio * screenFraction));
    _paddingSize = Util.doubleLimit(_chordFontSize! / 8, 1, _paddingSizeMax);
    _padding = EdgeInsets.all(_paddingSize);
    _marginSize = Util.doubleLimit(_chordFontSize! / 8, 1, _marginSizeMax);
    _margin = EdgeInsets.all(_marginSize);
    logger.log(
        _logFontSize,
        '_computeScreenSizes(): _chordFontSize: ${_chordFontSize?.toStringAsFixed(2)}'
        ', _screenWidth: ${_screenWidth.toStringAsFixed(2)}'
        ', screenFraction: ${screenFraction.toStringAsFixed(4)}'
        ', padding: ${_paddingSize.toStringAsFixed(2)}');
    _lyricsFontSize = _chordFontSize! * 0.5;

    //  text styles
    _chordTextStyle = generateChordTextStyle(fontSize: _chordFontSize);

    _lyricsTextStyle = generateLyricsTextStyle(fontSize: _lyricsFontSize);
  }

  static final emptyRichText = RichText(text: const TextSpan(text: ''));

  double get screenWidth => _screenWidth;
  double _screenWidth = 100;

  double get screenHeight => _screenHeight;
  double _screenHeight = 50;

  double get lyricsFontSize => _lyricsFontSize;
  double _lyricsFontSize = 18;

  double? get chordFontSize => _chordFontSize;
  double? _chordFontSize;

  Grid<SongCell> locationGrid = Grid();

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateLyricsTextStyle();

  Color _sectionBackgroundColor = Colors.white;
  TextStyle _coloredChordTextStyle = generateLyricsTextStyle();

  TextStyle _coloredBackgroundLyricsTextStyle = generateLyricsTextStyle();

  List<GridCoordinate> get songMomentToGridList => _songMomentToGridList;
  List<GridCoordinate> _songMomentToGridList = [];

  Widget get table => _table;
  Widget _table = const Text('empty');

  late AppWidgetHelper appWidgetHelper;

  music_key.Key displayMusicKey = music_key.Key.C;
  final AppOptions _appOptions = AppOptions();
  final RegExp verticalBarAndSpacesRegExp = RegExp(r'\s*\|\s*');
}

class SongCell extends StatelessWidget {
  const SongCell({this.richText, this.measureNode, super.key, this.size, this.point, this.columnWidth});

  SongCell copyWith({Size? size, Point<double>? point, double? columnWidth}) {
    return SongCell(richText: richText, measureNode: measureNode, size: size, point: point, columnWidth: columnWidth);
  }

  final RichText? richText;
  final MeasureNode? measureNode;

  @override
  Widget build(BuildContext context) {
    if (width < columnWidth ?? 0) {
      //  put the narrow column width on the left of a container
      return Container(
        alignment: Alignment.centerLeft,
        width: columnWidth,
        height: height,
        color: Colors.transparent,
        margin: _margin,
        child: Container(
          width: width,
          height: height,
          padding: _padding,
          color: richText?.text.style?.backgroundColor ?? Colors.transparent,
          child: richText,
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      margin: _margin,
      padding: _padding,
      color: richText?.text.style?.backgroundColor ?? Colors.transparent,
      child: richText,
    );
  }

  Size _computeBuildSize() {
    return _computeTextSize() + Offset(_paddingSize, _paddingSize) * 2;
  }

  Size _computeTextSize() {
    TextPainter textPainter = TextPainter(text: richText?.text ?? const TextSpan(), textDirection: TextDirection.ltr)
      ..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size;
  }

  Size get _buildSize => (size ?? _computeBuildSize()); //  efficiency compromised for const StatelessWidget song cell

  get rect {
    return Rect.fromLTWH(point?.x ?? 0.0, point?.y ?? 0.0, _buildSize.width, _buildSize.height);
  }

  get width => _buildSize.width;

  get height => _buildSize.height;

  @override
  String toString({DiagnosticLevel? minLevel}) {
    return 'SongCell{richText: $richText, measureNode: $measureNode'
        ', type: ${measureNode?.measureNodeType}, size: $size, point: $point}';
  } //  efficiency compromised for const song cell

  final Size? size;
  final double? columnWidth;
  final Point<double>? point;
}

// final _emptySongCell = SongCell(richText: RichText(text: const TextSpan(text: 'NULL cell!')));
