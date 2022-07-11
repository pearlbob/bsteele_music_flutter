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
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

//  diagnostic logging enables
const Level _logFontSize = Level.debug;
const Level _logFontSizeDetail = Level.debug;
const Level _logLayout = Level.debug;

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
    final Grid<Size> textSizeGrid = Grid<Size>();

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
      {
        Grid<MeasureNode> grid = song.toGrid(expanded: expanded);
        _songMomentToGridList = song.songMomentToGrid(expanded: expanded);

        for (int r = 0; r < grid.getRowCount(); r++) {
          children = [];

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

                  if (lyric.line.isEmpty) {} else if (showFullLyrics) {
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
              textSizeGrid.set(r, c, textPainter.size);

              children.add(_box(richText));
            } else {
              textSizeGrid.set(r, c, null);
              children.add(NullWidget());
            }
          }
          rows.add(TableRow(children: children));
        }
      }

      logger.log(_logFontSizeDetail, textSizeGrid.toMultiLineString());

      var columnWidths = <double>[];
      final rowHeights = List<double>.filled(textSizeGrid.getRowCount(), 0);
      if (rows.isNotEmpty) {
        final int rowLength = textSizeGrid.getRow(0)?.length ?? 1;
        columnWidths = List<double>.filled(rowLength, 0);
        assert(rowLength > 0);
        double maxChordWidth = 0;
        double maxLyricsWidth = 0;
        for (var r = 0; r < textSizeGrid.getRowCount(); r++) {
          var row = textSizeGrid.getRow(r);
          if (row == null) {
            assert(false); //  shouldn't happen
            continue; //  for release version
          }
          assert(row.length == rowLength);
          double chordWidth = 0;
          double lyricsWidth = 0;
          double rowHeight = 0;
          for (var c = 0; c < rowLength; c++) {
            var size = textSizeGrid.get(r, c);
            if (size == null) {
              continue;
            }
            double width = size.width + 2 * _paddingSize;
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
            rowHeight = max(rowHeight, size.height);
          }

          rowHeights[r] = rowHeight;

          logger.log(_logFontSizeDetail, 'row $r:  chordWidth: $chordWidth, lyricsWidth: $lyricsWidth,');
          maxChordWidth = max(maxChordWidth, chordWidth);
          maxLyricsWidth = max(maxLyricsWidth, lyricsWidth);
        }
        logger.log(_logFontSize, 'maxChordWidth: $maxChordWidth, maxLyricsWidth: $maxLyricsWidth,');
        logger.log(_logFontSize, 'columWidths: $columnWidths');
        logger.log(_logFontSize, 'rowHeights: $rowHeights');
      }

      if (rows.isEmpty) {
        _table = Table(
          key: GlobalKey(),
        );
      } else {
        Map<int, TableColumnWidth>? tableColumnWidths = {};
        for (var c = 0; c < columnWidths.length; c++) {
          tableColumnWidths[c] = FixedColumnWidth(columnWidths[c] //
                  +
                  defaultTableGap //  fixme: why is this required?
              );
          logger.log(_logFontSizeDetail, '$c: ${tableColumnWidths[c]}');
        }

        _table = Table(
          key: GlobalKey(),
          // defaultColumnWidth: const IntrinsicColumnWidth(),
          columnWidths: tableColumnWidths,
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

          chordRow.add(
            _box(richText),
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

  Container _box(RichText richText) {
    return Container(
      margin: getMeasureMargin(),
      padding: _padding,
      color: _sectionBackgroundColor,
      child: richText,
    );
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
    _chordFontSize ??= appDefaultFontSize * min(8, max(1, _screenWidth * usableRatio * screenFraction));
    double paddingSize = Util.doubleLimit(_chordFontSize! / 10, 0.5, 8);
    logger.log(
        _logFontSize,
        '_computeScreenSizes(): _chordFontSize: ${_chordFontSize?.toStringAsFixed(2)}'
        ', _screenWidth: ${_screenWidth.toStringAsFixed(2)}');
    logger.log(
        _logFontSize,
        ', screenFraction: ${screenFraction.toStringAsFixed(4)}'
        ', padding: ${_paddingSize.toStringAsFixed(2)}');
    _lyricsFontSize = _chordFontSize! * 0.5;

    _padding = EdgeInsets.all(_paddingSize);

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
  static const double _paddingSizeMax = 8;
  double _paddingSize = _paddingSizeMax;
  EdgeInsets _padding = const EdgeInsets.all(_paddingSizeMax);

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateLyricsTextStyle();

  Color _sectionBackgroundColor = Colors.white;
  TextStyle _coloredChordTextStyle = generateLyricsTextStyle();

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
