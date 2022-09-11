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
import 'package:bsteeleMusicLib/songs/measureRepeatExtension.dart';
import 'package:bsteeleMusicLib/songs/measureRepeatMarker.dart';
import 'package:bsteeleMusicLib/songs/sectionVersion.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songBase.dart';
import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

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
const Level _logLyricSectionCellState = Level.debug;

const double _paddingSizeMax = 5; //  fixme: can't be 0
double _paddingSize = _paddingSizeMax;
EdgeInsets _padding = const EdgeInsets.all(_paddingSizeMax);
const double _marginSizeMax = 4; //  note: vertical and horizontal are identical //  fixme: can't be less than 2
double _marginSize = _marginSizeMax;
EdgeInsets _margin = const EdgeInsets.all(_marginSizeMax);
const _highlightColor = Colors.redAccent;

///  The trick of the game: Figure the text size prior to boxing it
Size _computeRichTextSize(RichText richText, {double textScaleFactor = 1.0}) {
  TextPainter textPainter =
      TextPainter(text: richText.text, textDirection: TextDirection.ltr, textScaleFactor: textScaleFactor)
        ..layout(minWidth: 0, maxWidth: double.infinity);
  return textPainter.size;
}

class SongMomentNotifier extends ChangeNotifier {
  set songMoment(final SongMoment? songMoment) {
    logger.v('songMoment: $_songMoment');
    if (songMoment != _songMoment) {
      _songMoment = songMoment;
      notifyListeners();
    }
  }

  SongMoment? get songMoment => _songMoment;
  SongMoment? _songMoment;
}

class LyricSectionNotifier extends ChangeNotifier {
  set index(int index) {
    index = max(index, 0);
    if (index != _index) {
      _index = index;
      notifyListeners();
      logger.v('lyricSection: $_index');
    }
  }

  int get index => _index;
  int _index = 0;
}

/// compute a lyrics table
class LyricsTable {
  Widget lyricsTable(
    Song song,
    BuildContext context, {
    music_key.Key? musicKey,
    expanded = false,
  }) {
    return Column(children: lyricsTableItems(song, context, musicKey: musicKey, expanded: expanded));
  }

  List<Widget> lyricsTableItems(
    Song song,
    BuildContext context, {
    music_key.Key? musicKey,
    expanded = false,
  }) {
    appWidgetHelper = AppWidgetHelper(context);
    displayMusicKey = musicKey ?? song.key;

    _computeScreenSizes();

    var displayGrid = song.toDisplayGrid(_appOptions.userDisplayStyle, expanded: expanded);
    _locationGrid = Grid<SongCellWidget>();

    //  compute transposition offset from base key

    displayMusicKey = musicKey ?? song.key;
    int transpositionOffset = displayMusicKey.getHalfStep() - song.getKey().getHalfStep();

    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.proPlayer:
        for (var r = 0; r < displayGrid.getRowCount(); r++) {
          var row = displayGrid.getRow(r);
          assert(row != null);
          row = row!;

          if (r == 0) {
            //  list all sections in order
            {
              //  list the sections
              assert(row.length == song.lyricSections.length);
              for (var c = 0; c < row.length; c++) {
                var chordSection = displayGrid.get(r, c) as ChordSection;
                var lyricSection = song.lyricSections[c];
                assert(chordSection == song.findChordSectionByLyricSection(lyricSection));
                _colorBySectionVersion(chordSection.sectionVersion);
                _locationGrid.set(
                  r,
                  c,
                  SongCellWidget(
                    richText: RichText(
                      text: TextSpan(
                        text: chordSection.sectionVersion.toString().replaceAll(':', ''),
                        style: _coloredChordTextStyle,
                      ),
                    ),
                    type: SongCellType.flow,
                    measureNode: lyricSection,
                  ),
                );
              }
            }
            continue;
          }

          for (var c = 0; c < row.length; c++) {
            ChordSection chordSection;
            //  subsequent rows
            switch (c) {
              case 0:
                chordSection = displayGrid.get(r, c) as ChordSection;
                _colorBySectionVersion(chordSection.sectionVersion);
                _locationGrid.set(
                  r,
                  c,
                  SongCellWidget(
                    richText: RichText(
                      text: TextSpan(
                        text: chordSection.sectionVersion.toString(),
                        style: _coloredChordTextStyle,
                      ),
                    ),
                    type: SongCellType.columnFill,
                    measureNode: chordSection,
                  ),
                );
                break;
              case 1:
                chordSection = displayGrid.get(r, c) as ChordSection;
                _colorBySectionVersion(chordSection.sectionVersion);
                _locationGrid.set(
                  r,
                  c,
                  SongCellWidget(
                    richText: RichText(
                      text: TextSpan(
                        text: chordSection.transpose(displayMusicKey, transpositionOffset),
                        style: _coloredChordTextStyle,
                      ),
                    ),
                    type: SongCellType.columnMinimum,
                    measureNode: chordSection,
                  ),
                );
                break;
              default:
                assert(false); //  should not happen
                break;
            }
          }
        }
        break;

      case UserDisplayStyle.singer:
        for (var r = 0; r < displayGrid.getRowCount(); r++) {
          var row = displayGrid.getRow(r);
          assert(row != null);
          row = row!;

          for (var c = 0; c < row.length; c++) {
            MeasureNode? mn = displayGrid.get(r, c);
            switch (c) {
              case 0:
                if (mn?.measureNodeType == MeasureNodeType.lyricSection) {
                  var lyricSection = mn as LyricSection;
                  ChordSection? chordSection = song.findChordSectionByLyricSection(lyricSection);
                  if (chordSection != null) {
                    _colorBySectionVersion(chordSection.sectionVersion);
                    _locationGrid.set(
                      r,
                      c,
                      SongCellWidget(
                        richText: RichText(
                          text: TextSpan(
                            text: chordSection.sectionVersion.toString(),
                            style: _coloredChordTextStyle,
                          ),
                        ),
                        type: SongCellType.columnMinimum,
                        measureNode: lyricSection,
                      ),
                    );
                  } else {
                    assert(false);
                  }
                } else if (mn?.measureNodeType == MeasureNodeType.section) {
                  ChordSection chordSection = mn as ChordSection;
                  _colorBySectionVersion(chordSection.sectionVersion);
                  _locationGrid.set(
                    r,
                    c,
                    SongCellWidget(
                      richText: RichText(
                        text: TextSpan(
                          text: chordSection.sectionVersion.toString(),
                          style: _coloredChordTextStyle,
                        ),
                      ),
                      type: SongCellType.columnMinimum,
                      measureNode: chordSection,
                    ),
                  );
                } else {
                  assert(mn == null);
                }
                break;
              case 1:
                if (mn?.measureNodeType == MeasureNodeType.section) {
                  ChordSection chordSection = mn as ChordSection;
                  _colorBySectionVersion(chordSection.sectionVersion);
                  _locationGrid.set(
                    r,
                    c,
                    SongCellWidget(
                      richText: RichText(
                        text: TextSpan(
                          text: chordSection.transpose(displayMusicKey, transpositionOffset),
                          style: _coloredLyricTextStyle.copyWith(
                            color: Colors.black54,
                            backgroundColor: Colors.grey.shade300,
                            fontSize: app.screenInfo.fontSize,
                          ),
                        ),
                      ),
                      type: SongCellType.columnMinimum,
                      measureNode: chordSection,
                      selectable: false,
                    ),
                  );
                } else if (mn is Lyric) {
                  //  color done by prior chord section
                  _locationGrid.set(
                    r,
                    c,
                    SongCellWidget(
                      richText: RichText(
                        text: TextSpan(
                          text: mn.toMarkup(),
                          style: _coloredLyricTextStyle,
                        ),
                      ),
                      type: SongCellType.columnFill,
                      measureNode: mn,
                    ),
                  );
                } else {
                  assert(false);
                }
                break;
              default:
                assert(false); //  should not happen
                break;
            }
          }
        }
        break;

      default:
        for (var r = 0; r < displayGrid.getRowCount(); r++) {
          var row = displayGrid.getRow(r);
          assert(row != null);
          row = row!;

          for (var c = 0; c < row.length; c++) {
            MeasureNode? measureNode = displayGrid.get(r, c);
            if (measureNode == null) {
              continue;
            }
            switch (measureNode.measureNodeType) {
              case MeasureNodeType.lyricSection:
                _displayChordSection(GridCoordinate(r, c),
                    song.findChordSectionByLyricSection(measureNode as LyricSection)!, measureNode,
                    selectable: false);
                break;
              case MeasureNodeType.section:
                _displayChordSection(GridCoordinate(r, c), measureNode as ChordSection, measureNode);
                break;
              case MeasureNodeType.lyric:
                //  color done by prior chord section
                _locationGrid.set(
                  r,
                  c,
                  SongCellWidget(
                    richText: RichText(
                      text: TextSpan(
                        text: measureNode.toMarkup(),
                        style: _coloredLyricTextStyle,
                      ),
                    ),
                    type: _appOptions.userDisplayStyle == UserDisplayStyle.both
                        ? SongCellType.lyric
                        : SongCellType.lyricEllipsis,
                    measureNode: measureNode,
                    expanded: expanded,
                  ),
                );
                break;
              case MeasureNodeType.measure:
              //  color done by prior chord section
                {
                  Measure measure = measureNode as Measure;
                  RichText richText = RichText(
                      text: TextSpan(
                    text: '($r,$c)', //  diagnostic only!
                    style: _lyricsTextStyle,
                  ));
                  switch (measure.runtimeType) {
                    case MeasureRepeatExtension:
                      if (!expanded) {
                        richText = RichText(
                            text: TextSpan(
                          text: measure.toString(),
                          style: _coloredChordTextStyle.copyWith(
                              fontFamily: appFontFamily,
                              fontWeight: FontWeight.bold), //  fixme: a font failure workaround
                        ));
                      }
                      break;
                    case MeasureRepeatMarker:
                      if (!expanded) {
                        richText = appWidgetHelper.transpose(
                          measure,
                          displayMusicKey,
                          transpositionOffset,
                          style: _coloredChordTextStyle,
                        );
                      }
                      break;
                    case Measure:
                      richText = appWidgetHelper.transpose(
                        measure,
                        displayMusicKey,
                        transpositionOffset,
                        style: _coloredChordTextStyle,
                      );
                      break;
                  }

                  _locationGrid.set(
                    r,
                    c,
                    SongCellWidget(
                      richText: richText,
                      type: SongCellType.columnFill,
                      measureNode: measureNode,
                      expanded: expanded,
                    ),
                  );
                }
                break;

              default:
              //  color done by prior chord section
                _locationGrid.set(
                  r,
                  c,
                  SongCellWidget(
                    richText: RichText(
                      text: TextSpan(
                        text: measureNode.toMarkup(),
                        style: _coloredChordTextStyle,
                      ),
                    ),
                    type: SongCellType.columnFill,
                    measureNode: measureNode,
                  ),
                );
                break;
            }
          }
        }
        break;
    }

    //  look for column widths and heights
    var widths = List<double>.filled(displayGrid.maxColumnCount, 0);
    var heights = List<double>.filled(displayGrid.getRowCount(), 0);
    for (var r = 0; r < displayGrid.getRowCount(); r++) {
      var row = displayGrid.getRow(r);
      assert(row != null);
      row = row!;

      for (var c = 0; c < row.length; c++) {
        var cell = _locationGrid.get(r, c);
        if (cell == null) {
          continue; //  for example, first column in lyrics for singer display style
        }

        switch (cell.type) {
          case SongCellType.flow:
          case SongCellType.lyricEllipsis:
            break;
          default:
            widths[c] = max(widths[c], cell.rect.width);
            break;
        }

        heights[r] = max(heights[r], cell.rect.height);
      }
    }

    //  discover the overall total width and height
    double arrowIndicatorWidth = _chordFontSize;
    var totalWidth = widths.fold<double>(arrowIndicatorWidth, (previous, e) => previous + e + 2.0 * _marginSize);
    //  allocate space for player lyrics
    if (_appOptions.userDisplayStyle == UserDisplayStyle.player && widths.last == 0) {
      widths.last = max(0.3 * totalWidth, 0.97 * (screenWidth - totalWidth));
      totalWidth += widths.last;
    }
    var totalHeight = heights.fold<double>(0.0, (previous, e) => previous + e + 2.0 * _marginSize);

    assert(totalWidth > 0);
    assert(totalHeight > 0);

    //  fit the horizontal by scaling
    _scaleFactor = screenWidth / (totalWidth * 1.02 /* rounding safety */);
    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.proPlayer:
        //  fit everything vertically
        _scaleFactor = min(
            _scaleFactor,
            screenHeight *
                0.65 //  fixme: this is only close, empirically
                /
                totalHeight);
        break;
      default:
        break;
    }
    _scaleFactor = min(_scaleFactor, 1.0);

    logger.log(_logFontSize, '_scaleFactor: $_scaleFactor');
    logger.log(
        _logFontSize,
        'totalWidth: $totalWidth, totalHeight: $totalHeight, screenWidth: $screenWidth'
        ', scaled width: ${totalWidth * _scaleFactor}');
    if (_scaleFactor < 1.0) {
      //  rescale the grid to fit the window
      _scaleComponents(scaleFactor: _scaleFactor);

      for (var i = 0; i < widths.length; i++) {
        widths[i] = widths[i] * _scaleFactor;
      }
      for (var i = 0; i < heights.length; i++) {
        heights[i] = heights[i] * _scaleFactor;
      }
    }

    //  set the location grid sizing
    final double xMargin = 2.0 * _marginSize;
    final double yMargin = xMargin;
    {
      double y = 0;
      for (var r = 0; r < _locationGrid.getRowCount(); r++) {
        var row = _locationGrid.getRow(r);
        assert(row != null);
        row = row!;

        double x = arrowIndicatorWidth * _scaleFactor;
        for (var c = 0; c < row.length; c++) {
          var cell = _locationGrid.get(r, c);
          if (cell != null) {
            double? width;
            switch (cell.type) {
              case SongCellType.flow:
                break;
              default:
                width = widths[c];
                break;
            }

            _locationGrid.set(
              r,
              c,
              cell.copyWith(textScaleFactor: _scaleFactor, columnWidth: width, point: Point(x, y)),
            );
          }
          x += widths[c] + xMargin;
        }
        y += heights[r] + yMargin;
      }
    }

    List<Widget> items = [];

    //  map from song moment to cell grid
    for (var songMoment in song.songMoments) {
      logger.v('map: ${songMoment.momentNumber}:'
          ' ${song.songMomentToGridCoordinate[songMoment.momentNumber]}');
      var gc = song.songMomentToGridCoordinate[songMoment.momentNumber];
      _locationGrid.setAt(
        gc,
        _locationGrid.at(gc)?.copyWith(songMoment: songMoment),
      );
    }

    //  box up the children, applying necessary widths and heights
    {
      List<Widget> sectionChildren = [];
      LyricSection? lastLyricSection;
      for (var r = 0; r < _locationGrid.getRowCount(); r++) {
        var row = _locationGrid.getRow(r);
        assert(row != null);
        row = row!;

        sectionChildren.add(AppSpace(
          horizontalSpace: arrowIndicatorWidth * _scaleFactor,
        ));

        LyricSection? lyricSection = lastLyricSection;

        List<Widget> rowChildren = [];
        for (var c = 0; c < row.length; c++) {
          Widget child;
          var cell = _locationGrid.get(r, c);
          if (cell == null) {
            child = AppSpace(
              horizontalSpace: widths[c] + xMargin,
            );
          } else {
            child = cell;
            if (cell.measureNode?.runtimeType == LyricSection) {
              logger.v(' ChordSection: ${cell.measureNode}');
              lyricSection = cell.measureNode as LyricSection;
            }
          }
          rowChildren.add(child);
        }
        Row rowWidget;
        {
          var firstWidget = (lastLyricSection == lyricSection)
              ? AppSpace(
                  horizontalSpace: arrowIndicatorWidth * _scaleFactor,
                )
              : LyricSectionCellWidget(
            lyricSection: lyricSection!,
                  width: arrowIndicatorWidth * _scaleFactor,
                  height: heights[r],
                  fontSize: _chordFontSize * _scaleFactor,
                );

          rowWidget = Row(
            children: [firstWidget, ...rowChildren],
          );
        }

        if (lastLyricSection != lyricSection) {
          if (lastLyricSection != null) {
            lastLyricSection = lyricSection;
            items.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sectionChildren,
            ));
            sectionChildren = [];
          }
          lastLyricSection = lyricSection;
        }
        sectionChildren.add(rowWidget);
      }
      //  complete with the last
      if (sectionChildren.isNotEmpty) {
        items.add(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sectionChildren,
        ));
      }
    }

    logger.v(_locationGrid.toString());

    //  show copyright
    items.add(Padding(
      padding: EdgeInsets.all(_lyricsFontSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpace(verticalSpace: _lyricsFontSize),
          Text(
            'Copyright: ${song.copyright}',
            style: _lyricsTextStyle.copyWith(fontSize: _lyricsFontSize * _scaleFactor),
          ),
          //  give the scrolling some stuff to scroll the bottom up on
          AppSpace(verticalSpace: screenHeight / 2),
        ],
      ),
    ));

    return items;
  }

  void _displayChordSection(GridCoordinate gc, ChordSection chordSection, MeasureNode measureNode, {bool? selectable}) {
    _colorBySectionVersion(chordSection.sectionVersion);
    _locationGrid.setAt(
      gc,
      SongCellWidget(
        richText: RichText(
          text: TextSpan(
            text: chordSection.sectionVersion.toString(),
            style: _coloredChordTextStyle,
          ),
        ),
        type: SongCellType.columnMinimum,
        measureNode: measureNode,
        selectable: selectable,
      ),
    );
  }

  void _colorBySectionVersion(SectionVersion sectionVersion) {
    _sectionBackgroundColor = getBackgroundColorForSectionVersion(sectionVersion);
    _coloredChordTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _sectionBackgroundColor,
    );
    _coloredLyricTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _sectionBackgroundColor,
      fontSize: lyricsFontSize,
      fontWeight: FontWeight.normal,
    );
  }

  /// compute screen size values used here and on other screens
  void _computeScreenSizes() {
    App app = App();
    _screenWidth = app.screenInfo.mediaWidth;
    _screenHeight = app.screenInfo.mediaHeight;

    //  rough in the basic fontsize
    _chordFontSize = 90; // max for hdmi resolution

    _scaleComponents();
    _lyricsFontSize = _chordFontSize * 0.55;

    //  text styles
    _chordTextStyle =
        generateChordTextStyle(fontFamily: appFontFamily, fontSize: _chordFontSize, fontWeight: FontWeight.bold);
    _sectionTextStyle = _chordTextStyle.copyWith(fontSize: _chordFontSize * 0.75);
    _lyricsTextStyle = _chordTextStyle.copyWith(fontSize: _lyricsFontSize, fontWeight: FontWeight.normal);
  }

  _scaleComponents({double scaleFactor = 1.0}) {
    _paddingSize = _paddingSizeMax * scaleFactor;
    _padding = EdgeInsets.all(_paddingSize);
    _marginSize = _marginSizeMax * scaleFactor;
    _margin = EdgeInsets.all(_marginSize);

    logger.log(
        _logFontSize,
        '_scaleComponents(): _chordFontSize: ${_chordFontSize.toStringAsFixed(2)}'
        ', _marginSize: ${_marginSize.toStringAsFixed(2)}'
        ', padding: ${_paddingSize.toStringAsFixed(2)}');
  }

  double get screenWidth => _screenWidth;
  double _screenWidth = 100;

  double get screenHeight => _screenHeight;
  double _screenHeight = 50;

  double get lyricsFontSize => _lyricsFontSize * _scaleFactor;
  double _lyricsFontSize = 18;

  double get chordFontSize => _chordFontSize * _scaleFactor;
  double _chordFontSize = appDefaultFontSize;

  double get marginSize => _marginSize;

  Grid<SongCellWidget> _locationGrid = Grid();

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get sectionTextStyle => _sectionTextStyle;
  TextStyle _sectionTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateLyricsTextStyle();

  Color _sectionBackgroundColor = Colors.white;
  TextStyle _coloredChordTextStyle = generateLyricsTextStyle();
  TextStyle _coloredLyricTextStyle = generateLyricsTextStyle();

  double _scaleFactor = 1.0;

  late AppWidgetHelper appWidgetHelper;

  music_key.Key displayMusicKey = music_key.Key.C;
  final AppOptions _appOptions = AppOptions();
  final RegExp verticalBarAndSpacesRegExp = RegExp(r'\s*\|\s*');
}

enum SongCellType {
  columnFill,
  columnMinimum,
  lyric,
  lyricEllipsis,
  flow;
}

class LyricSectionCellWidget extends StatefulWidget {
  LyricSectionCellWidget(
      {super.key,
      required this.lyricSection,
      required this.width,
      required this.height,
      this.fontSize = appDefaultFontSize})
      : index = lyricSection.index;

  @override
  State<StatefulWidget> createState() {
    return _LyricSectionCellState();
  }

  final LyricSection lyricSection;
  final double fontSize;
  final double width;
  final double height;
  final int index;
}

class _LyricSectionCellState extends State<LyricSectionCellWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<LyricSectionNotifier>(
      builder: (context, lyricSectionNotifier, child) {
        var isNowSelected = lyricSectionNotifier.index == widget.index;
        if (isNowSelected == selected && child != null) {
          return child;
        }
        selected = isNowSelected;
        return childBuilder(context);
      },
      child: Builder(builder: childBuilder),
    );
  }

  Widget childBuilder(BuildContext context) {
    logger.log(_logLyricSectionCellState, '_LyricSectionCellState.childBuilder: run: selected: $selected');
    return SizedBox(
      width: widget.width,
      child: selected
          ? appIcon(
              Icons.play_arrow,
              size: widget.fontSize,
              color: Colors.redAccent,
            )
          : null, //Container( color:  Colors.cyan,height: widget.height), // empty box
    );
  }

  var selected = false;
}

class SongCellWidget extends StatefulWidget {
  const SongCellWidget({
    super.key,
    required this.richText,
    this.type = SongCellType.columnFill,
    this.measureNode,
    this.size,
    this.point,
    this.columnWidth,
    this.withEllipsis,
    this.textScaleFactor = 1.0,
    this.songMoment,
    this.expanded,
    this.selectable,
  });

  SongCellWidget copyWith({
    Size? size,
    Point<double>? point,
    double? columnWidth,
    double? textScaleFactor,
    SongMoment? songMoment,
  }) {
    RichText copyOfRichText;

    if (type == SongCellType.lyricEllipsis && columnWidth != null) {
      copyOfRichText = RichText(
        key: richText.key,
        //  fixme: will this be a mistake? an error?  not currently used
        text: //  default to one line
            TextSpan(text: richText.text.toPlainText().replaceAll('\n', ', '), style: richText.text.style),
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      copyOfRichText = RichText(
        text: richText.text,
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        key: richText.key,
        softWrap: richText.softWrap,
      );
    }

    //  count on package level margin and padding to have been scaled elsewhere
    return SongCellWidget(
      key: key,
      richText: copyOfRichText,
      type: type,
      measureNode: measureNode,
      size: size ?? this.size,
      point: point ?? this.point,
      columnWidth: columnWidth ?? this.columnWidth,
      withEllipsis: withEllipsis,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      songMoment: songMoment,
      expanded: expanded,
      selectable: selectable,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _SongCellState();
  }

  ///  efficiency compromised for const StatelessWidget song cell
  Size _computeBuildSize() {
    return (withEllipsis ?? false)
        ? size!
        : _computeRichTextSize(richText, textScaleFactor: textScaleFactor) +
            Offset(_paddingSize + 2.0 * _marginSize, 2.0 * _marginSize);
  }

  Rect get rect {
    //  fixme: should be lazy eval
    Size buildSize = size ?? _computeBuildSize();
    return Rect.fromLTWH(
        point?.x ?? 0.0,
        point?.y ?? 0.0,
        ((size?.width ?? 0) < (columnWidth ?? 0) ? columnWidth! : buildSize.width), //  width
        buildSize.height //  height
        );
  }

  @override
  String toString({DiagnosticLevel? minLevel}) {
    return 'SongCellWidget{richText: $richText, type: ${type.name}, measureNode: $measureNode'
        ', type: ${measureNode?.measureNodeType}, size: $size, point: $point}';
  }

  final SongCellType type;
  final bool? withEllipsis;
  final RichText richText;
  final MeasureNode? measureNode;
  final double textScaleFactor;
  final Size? size;
  final double? columnWidth;
  final Point<double>? point;
  final SongMoment? songMoment;
  final bool? expanded;
  final bool? selectable;
}

class _SongCellState extends State<SongCellWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SongMomentNotifier>(
      builder: (context, songMomentNotifier, child) {
        var moment = songMomentNotifier.songMoment;
        var isNowSelected = false;
        if (moment != null && (widget.selectable ?? true)) {
          switch (widget.measureNode.runtimeType) {
            case LyricSection:
              isNowSelected = moment.lyricSection == widget.measureNode;
              break;
            case ChordSection:
              isNowSelected = moment.chordSection == widget.measureNode;
              break;
            default:
              isNowSelected = (moment.momentNumber == widget.songMoment?.momentNumber ||
                  (
                      //  deal with compressed repeats
                      !(widget.expanded ?? true) &&
                          moment.lyricSection == widget.songMoment?.lyricSection &&
                          moment.phraseIndex == widget.songMoment?.phraseIndex &&
                          moment.phrase.repeats > 1 &&
                          widget.songMoment?.measureIndex != null &&
                          (moment.measureIndex - widget.songMoment!.measureIndex) % moment.phrase.length == 0));
          }
        }
        logger.v('_SongCellState: songMoment: ${widget.songMoment} vs ${moment?.momentNumber}');
        if (isNowSelected == selected && child != null) {
          return child;
        }
        selected = isNowSelected;
        return childBuilder(context);
      },
      child: Builder(builder: childBuilder),
    );
  }

  Widget childBuilder(BuildContext context) {
    Size buildSize = widget._computeBuildSize();
    var maxWidth = max(widget.columnWidth ?? buildSize.width, (widget.size?.width ?? 0));
    double width = maxWidth;
    switch (widget.type) {
      case SongCellType.columnMinimum:
        width = buildSize.width;
        break;
      default:
        break;
    }
    logger.v('_SongCellState: childBuilder: selected: $selected, songMoment: ${widget.songMoment?.momentNumber}'
        ', text: "${widget.richText.text.toPlainText()}"'
        ', width: $width/$maxWidth'
        ', columnWidth: ${widget.columnWidth}');

    if ((widget.size?.width ?? 0) < (widget.columnWidth ?? 0)) {
      //  put the narrow column width on the left of a container
      //  do the following row element is aligned in the next column

      Color color;
      switch (widget.type) {
        case SongCellType.columnMinimum:
          color = Colors.transparent;
          break;
        default:
          color = widget.richText.text.style?.backgroundColor ?? Colors.transparent;
          break;
      }

      return Container(
        alignment: Alignment.topLeft,
        width: maxWidth,
        height: buildSize.height,
        color: color,
        margin: _margin,
        child: Container(
          width: width,
          height: buildSize.height,
          padding: _padding,
          foregroundDecoration: selected
              ? BoxDecoration(
                  border: Border.all(
                    width: _marginSize,
                    color: _highlightColor,
                  ),
                )
              : null,
          color: widget.richText.text.style?.backgroundColor ?? Colors.transparent,
          child: widget.richText,
        ),
      );
    }
    return Container(
      width: maxWidth,
      height: buildSize.height,
      margin: _margin,
      padding: _padding,
      foregroundDecoration: selected
          ? BoxDecoration(
              border: Border.all(
                width: _marginSize,
                color: _highlightColor,
              ),
            )
          : null,
      color: widget.richText.text.style?.backgroundColor ?? Colors.transparent,
      child: widget.richText,
    );
  }

  var selected = false; //  indicates the cell is currently selected, i.e. highlighted
}
