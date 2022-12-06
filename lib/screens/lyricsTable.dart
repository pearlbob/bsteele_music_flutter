import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/grid_coordinate.dart';
import 'package:bsteeleMusicLib/songs/chord_section.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyric.dart';
import 'package:bsteeleMusicLib/songs/lyric_section.dart';
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:bsteeleMusicLib/songs/measure_node.dart';
import 'package:bsteeleMusicLib/songs/measure_repeat_extension.dart';
import 'package:bsteeleMusicLib/songs/measure_repeat_marker.dart';
import 'package:bsteeleMusicLib/songs/nashville_note.dart';
import 'package:bsteeleMusicLib/songs/section_version.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/song_base.dart';
import 'package:bsteeleMusicLib/songs/song_moment.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/usTimer.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/appOptions.dart';
import '../audio/app_audio_player.dart';

const _slashColor = Color(0xffcb4931);
const _fadedSlashColor = Color(0xffe27e65);
const _middleDot = '\u00b7';

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
const Level _logLyricsBuild = Level.debug;
const Level _logHeights = Level.debug;
const Level _logLyricsTableItems = Level.debug;
const Level _logChildBuilder = Level.debug;

const double _paddingSizeMax = 5; //  fixme: can't be 0
double _paddingSize = _paddingSizeMax;
EdgeInsets _padding = const EdgeInsets.all(_paddingSizeMax);
const double _marginSizeMax = 4; //  note: vertical and horizontal are identical //  fixme: can't be less than 2
double _marginSize = _marginSizeMax;
EdgeInsets _margin = const EdgeInsets.all(_marginSizeMax);
const _highlightColor = Colors.redAccent;
const _defaultMaxLines = 8;
var _maxLines = 1;

///  The trick of the game: Figure the text size prior to boxing it
Size _computeRichTextSize(
  RichText richText, {
  double textScaleFactor = 1.0,
  int? maxLines,
  double? maxWidth,
}) {
  TextPainter textPainter = TextPainter(
    text: richText.text,
    textDirection: TextDirection.ltr,
    maxLines: maxLines ?? _maxLines,
    textScaleFactor: textScaleFactor,
  )..layout(maxWidth: maxWidth ?? app.screenInfo.mediaWidth);
  logger.v('_computeRichTextSize: textScaleFactor: $textScaleFactor, maxWidth: $maxWidth, size: ${textPainter.size}');
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
  LyricSection? lyricSection;
}

/// compute a lyrics table
class LyricsTable {
  List<Widget> lyricsTableItems(
    Song song,
    BuildContext context, {
    music_key.Key? musicKey,
    expanded = false,
  }) {
    var usTimer = UsTimer();
    appWidgetHelper = AppWidgetHelper(context);
    displayMusicKey = musicKey ?? song.key;
    _nashvilleSelection = _appOptions.nashvilleSelection;
    _maxLines = 1;

    _computeScreenSizes();

    var displayGrid = song.toDisplayGrid(_appOptions.userDisplayStyle, expanded: expanded);
    logger.log(_logLyricsBuild, 'lyricsBuild: displayGrid: ${usTimer.deltaToString()}');

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
                    lyricSectionIndex: lyricSection.index,
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
                    //  skip highlight on section heading
                  ),
                );
                break;
              case 1:
                chordSection = displayGrid.get(r, c) as ChordSection;
                _colorBySectionVersion(chordSection.sectionVersion);

                //  generate the lyric section set of matching lyric sections
                SplayTreeSet<int> set = SplayTreeSet();
                for (var i = 0; i < song.lyricSections.length; i++) {
                  if (song.lyricSections[i].sectionVersion == chordSection.sectionVersion) {
                    set.add(i);
                  }
                }

                _locationGrid.set(
                  r,
                  c,
                  SongCellWidget(
                    richText: RichText(
                      text: _chordSectionTextSpan(chordSection, song.key, transpositionOffset),
                    ),
                    type: SongCellType.columnMinimum,
                    measureNode: chordSection,
                    lyricSectionSet: set,
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
                  //  show the section version
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
                  //   show the chords
                  ChordSection chordSection = mn as ChordSection;
                  _colorBySectionVersion(chordSection.sectionVersion);
                  _locationGrid.set(
                    r,
                    c,
                    SongCellWidget(
                      richText: RichText(
                        text: _chordSectionTextSpan(
                          chordSection,
                          song.key,
                          transpositionOffset,
                          displayMusicKey: displayMusicKey,
                          style: _coloredLyricTextStyle.copyWith(
                            color: Colors.black54,
                            backgroundColor: Colors.grey.shade300,
                            fontSize: _coloredLyricTextStyle.fontSize ?? app.screenInfo.fontSize,
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
                          style: _coloredChordTextStyle,
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

      case UserDisplayStyle.banner:
        for (var momentNumber = 0; momentNumber < song.songMoments.length; momentNumber++) {
          for (var banner in BannerColumn.values) {
            //  color by chord section
            var chordSection = displayGrid.get(BannerColumn.chordSections.index, momentNumber);
            if (chordSection is ChordSection) {
              _colorBySectionVersion(chordSection.sectionVersion);
            }

            MeasureNode? mn = displayGrid.get(banner.index, momentNumber);
            switch (banner) {
              case BannerColumn.chordSections:
                var chordSection = mn is ChordSection ? mn : null;
                _locationGrid.set(
                  banner.index,
                  momentNumber,
                  chordSection == null
                      ? SongCellWidget.empty()
                      : SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: chordSection.sectionVersion.toString(),
                              style: _coloredChordTextStyle,
                            ),
                          ),
                          type: SongCellType.columnMinimum,
                          measureNode: mn,
                        ),
                );
                break;
              case BannerColumn.repeats:
                var marker = mn is MeasureRepeatMarker ? mn : null;
                _locationGrid.set(
                  banner.index,
                  momentNumber,
                  marker == null
                      ? SongCellWidget.empty()
                      : SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: 'x${(marker.repetition ?? 0) + 1}/${marker.repeats}',
                              style: _coloredLyricTextStyle,
                            ),
                          ),
                          type: SongCellType.columnMinimum,
                          measureNode: mn,
                        ),
                );
                break;
              case BannerColumn.lyrics:
                var lyric = mn is Lyric ? mn : null;
                _locationGrid.set(
                  banner.index,
                  momentNumber,
                  lyric == null
                      ? SongCellWidget.empty()
                      : SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: lyric.toMarkup(),
                              style: _coloredLyricTextStyle,
                            ),
                          ),
                          type: SongCellType.columnFill,
                          measureNode: mn,
                        ),
                );
                break;
              default:
                _locationGrid.set(
                  banner.index,
                  momentNumber,
                  mn == null
                      ? SongCellWidget.empty()
                      : SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: mn.toString(),
                              style: _coloredChordTextStyle,
                            ),
                          ),
                          type: SongCellType.columnFill,
                          measureNode: mn,
                        ),
                );
                break;
            }
          }
        }
        break;

      case UserDisplayStyle.player:
      case UserDisplayStyle.both:
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
                {
                  var songCellType = _appOptions.userDisplayStyle == UserDisplayStyle.both
                      ? SongCellType.lyric
                      : SongCellType.lyricEllipsis;
                  _locationGrid.set(
                    r,
                    c,
                    SongCellWidget(
                      richText: RichText(
                        text: TextSpan(
                          text: measureNode.toMarkup(),
                          style: _coloredLyricTextStyle,
                        ),
                        maxLines: songCellType == SongCellType.lyricEllipsis ? 1 : _maxLines,
                      ),
                      type: songCellType,
                      measureNode: measureNode,
                      expanded: expanded,
                    ),
                  );
                }
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
                        richText = RichText(
                          text: TextSpan(
                            text: measure.toString(),
                            style: _coloredChordTextStyle,
                          ),
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
                      }
                      break;
                    case Measure:
                      richText = RichText(
                        text: _measureNashvilleSelectionTextSpan(measure, song.key, transpositionOffset,
                            style: _coloredChordTextStyle, displayMusicKey: displayMusicKey),
                        //  don't allow the rich text to wrap:
                        textWidthBasis: TextWidthBasis.longestLine,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        textDirection: TextDirection.ltr,
                        textScaleFactor: 1.0,
                        textAlign: TextAlign.start,
                        textHeightBehavior: const TextHeightBehavior(),
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

    logger.log(_logLyricsBuild, 'lyricsBuild: _locationGrid: ${usTimer.deltaToString()}');

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
            widths[c] = max(widths[c], cell.buildSize.width);
            break;
        }

        heights[r] = max(heights[r], cell.buildSize.height);
      }
    }
    logger.log(_logHeights, 'heights: $heights');
    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        //  even up the banner width's
        var width = 0.0;
        var r = BannerColumn.chords.index;
        var row = _locationGrid.getRow(r);
        assert(row != null);
        row = row!;

        for (var c = 0; c < row.length - 1 /*  exclude the copyright*/; c++) {
          width = max(width, row[c]!.buildSize.width);
        }

        if (width < app.screenInfo.mediaWidth / 5) {
          width = app.screenInfo.mediaWidth / 5;
        }

        for (var c = 0; c < row.length - 1 /*  exclude the copyright*/; c++) {
          widths[c] = width;
        }

        //  even all the banner lyric widths
        _maxLines = _defaultMaxLines;
        {
          int r = BannerColumn.lyrics.index;
          var row = displayGrid.getRow(r);
          assert(row != null);
          row = row!;

          for (var c = 0; c < row.length - 1 /*  exclude the copyright*/; c++) {
            var cell = _locationGrid.get(r, c);
            if (cell != null) {
              _locationGrid.set(r, c, cell.copyWith(columnWidth: width));
            }
          }
        }

        //  re-compute max lyric height after width change
        double height = app.screenInfo.fontSize; //  safety
        {
          int r = BannerColumn.lyrics.index;
          var row = displayGrid.getRow(r);
          assert(row != null);
          row = row!;

          for (var c = 0; c < row.length - 1 /*  exclude the copyright*/; c++) {
            var cell = _locationGrid.get(r, c);
            if (cell != null) {
              height = max(height, cell.computedBuildSize.height);
              logger.log(
                  _logHeights,
                  'banner computedBuildSize: ${cell.computedBuildSize}'
                  ', columnWidth: ${cell.columnWidth}');
            }
          }
          logger.log(_logHeights, 'banner new height: $height');

          //  apply the new height
          heights[r] = height;
          for (var c = 0; c < row.length - 1 /*  exclude the copyright*/; c++) {
            var cell = _locationGrid.get(r, c);
            if (cell != null) {
              _locationGrid.set(r, c, cell.copyWith(size: Size(cell.buildSize.width, height)));
            }
          }
        }

        logger.log(_logHeights, 'banner widths: $widths');
        logger.log(_logHeights, 'banner heights: $heights');
        break;
      default:
        break;
    }

    //  discover the overall total width and height
    double arrowIndicatorWidth = _chordFontSizeUnscaled;
    var totalWidth = widths.fold<double>(arrowIndicatorWidth, (previous, e) => previous + e + 2.0 * _marginSize);
    var chordWidth = totalWidth - widths.last;
    logger.log(_logFontSize, 'chord ratio: $chordWidth/$totalWidth = ${chordWidth / totalWidth}');

    //  limit space for player lyrics
    if (_appOptions.userDisplayStyle == UserDisplayStyle.player && widths.last == 0) {
      widths.last = max(0.3 * totalWidth, 0.97 * (screenWidth - totalWidth));
      totalWidth += widths.last;
    }
    logger.log(_logFontSize, 'raw widths.last: ${widths.last}/$totalWidth');
    logger.log(_logFontSize, 'raw widths: $widths, total: ${widths.fold(0.0, (p, e) => p + e)}');

    logger.log(
        _logFontSize,
        'raw:'
        ' _chordFontSize: ${_chordFontSizeUnscaled.toStringAsFixed(2)}'
        ', _lyricsFontSize: ${_lyricsFontSizeUnscaled.toStringAsFixed(2)}'
        ', _marginSize: ${_marginSize.toStringAsFixed(2)}'
        ', padding: ${_paddingSize.toStringAsFixed(2)}');
    var totalHeight = heights.fold<double>(0.0, (previous, e) => previous + e + 2.0 * _marginSize);

    assert(totalWidth > 0);
    assert(totalHeight > 0);

    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        _scaleFactor = 0.65;
        break;
      default:
        //  fit the horizontal by scaling
        _scaleFactor = screenWidth / (totalWidth * 1.02 /* rounding safety */);
        break;
    }

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
    logger.log(_logHeights, 'scaled heights: $heights');
    logger.log(_logFontSize, 'scaled widths.last: ${widths.last}');
    logger.log(_logFontSize, 'scaled widths: $widths, total: ${widths.fold(0.0, (p, e) => p + e)}');
    logger.log(
        _logFontSize,
        'scaled:'
        ' _chordFontSize: ${_chordFontSizeUnscaled.toStringAsFixed(2)}'
        ', _lyricsFontSize: ${_lyricsFontSizeUnscaled.toStringAsFixed(2)}'
        ', _marginSize: ${_marginSize.toStringAsFixed(2)}'
        ', padding: ${_paddingSize.toStringAsFixed(2)}');
    _maxLines = _appOptions.userDisplayStyle == UserDisplayStyle.player ? 1 : 8;

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

            cell = cell.copyWith(textScaleFactor: _scaleFactor, columnWidth: width, point: Point(x, y));
            _locationGrid.set(r, c, cell);
            // logger.log(_logHeights, 'heights: ${heights[r]} vs ${cell.buildSize.height}');
            heights[r] = max(heights[r], cell.buildSize.height); //  for banner mode
          }
          x += widths[c] + xMargin;
        }
        y += heights[r] + yMargin;
      }
    }

    logger.log(_logLyricsBuild, 'lyricsBuild: scaling: ${usTimer.deltaToString()}');

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
    logger.log(_logLyricsBuild, 'lyricsBuild: songMoment mapping: ${usTimer.deltaToString()}');

    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        //  box up the children, applying necessary widths and heights
        {
          for (var c = 0; c < song.songMoments.length; c++) {
            List<SongCellWidget> columnChildren = [];
            for (var r = 0; r < BannerColumn.values.length; r++) {
              var cell = _locationGrid.get(r, c);
              assert(cell != null);
              columnChildren.add(cell!.copyWith(size: Size(widths[c], heights[r])));
            }
            Widget columnWidget = Column(crossAxisAlignment: CrossAxisAlignment.start, children: columnChildren);
            logger.v('banner columnChildren: ${columnChildren.map((c) => c.size)}');
            items.add(columnWidget);
          }
        }
        logger.log(_logHeights, 'banner scaled heights: $heights');

        for (var c = 0; c < song.songMoments.length; c++) {
          for (var r = 0; r < BannerColumn.values.length; r++) {
            var cell = _locationGrid.get(r, c);
            // logger.i( 'banner cell: ($r,$c): $cell');
            // assert(cell != null );
            if (cell != null) {}
          }
        }
        break;

      default:
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
            Widget rowWidget;
            {
              var firstWidget = (lastLyricSection == lyricSection)
                  ? AppSpace(
                      horizontalSpace: arrowIndicatorWidth * _scaleFactor,
                    )
                  : LyricSectionCellWidget(
                      lyricSection: lyricSection!,
                      width: arrowIndicatorWidth * _scaleFactor,
                      height: heights[r],
                      fontSize: _chordFontSizeUnscaled * _scaleFactor,
                    );

              if (r == 0 && _appOptions.userDisplayStyle == UserDisplayStyle.proPlayer) {
                //  put the first row of pro in a wrap
                rowWidget = AppWrap(children: [firstWidget, ...rowChildren]);
              } else {
                rowWidget = Row(children: [firstWidget, ...rowChildren]);
              }
              // logger.v('rowChildren: $rowChildren');
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
        break;
    }

    logger.v(_locationGrid.toString());

    //  show copyright
    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        items.add(Text(
          'Copyright: ${song.copyright}',
          style: _coloredChordTextStyle,
        ));
        break;
      default:
        items.add(Padding(
          padding: EdgeInsets.all(_lyricsFontSizeUnscaled),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSpace(verticalSpace: _lyricsFontSizeUnscaled),
              Text(
                'Copyright: ${song.copyright}',
                style: _lyricsTextStyle.copyWith(fontSize: _lyricsFontSizeUnscaled * _scaleFactor),
              ),
              //  give the scrolling some stuff to scroll the bottom up on
              AppSpace(verticalSpace: screenHeight / 2),
            ],
          ),
        ));
        break;
    }

    logger.log(_logLyricsBuild, 'lyricsBuild: boxing: ${usTimer.deltaToString()}');

    logger.log(_logLyricsTableItems, 'lyricsTable usTimer: $usTimer');

    return items;
  }

  /// Transcribe the chord section to a text span, adding Nashville notation when appropriate.
  TextSpan _chordSectionTextSpan(
      final ChordSection chordSection, final music_key.Key originalKey, int transpositionOffset,
      {final music_key.Key? displayMusicKey, TextStyle? style}) {
    style = style ?? _coloredChordTextStyle;

    final List<TextSpan> children = [];
    switch (_nashvilleSelection) {
      case NashvilleSelection.off:
      case NashvilleSelection.both:
        for (var phrase in chordSection.phrases) {
          for (var measure in phrase.measures) {
            var textSpan = _measureTextSpan(measure, originalKey, transpositionOffset,
                displayMusicKey: displayMusicKey, style: style);
            children.add(TextSpan(text: ' ', style: style));
            children.add(textSpan);
            if (measure.endOfRow) {
              children.add(TextSpan(text: '   ', style: style));
            }
          }
          if (phrase.isRepeat()) {
            children.add(TextSpan(text: '  x${phrase.repeats}   ', style: style));
          } else {
            children.add(TextSpan(text: '   ', style: style));
          }
        }
        break;
      default:
        break;
    }

    final List<TextSpan> nashvilleChildren = [];
    switch (_nashvilleSelection) {
      case NashvilleSelection.both:
      case NashvilleSelection.only:
        for (var phrase in chordSection.phrases) {
          if (nashvilleChildren.isNotEmpty) {
            //  space the nashville children with a dot
            nashvilleChildren.add(TextSpan(text: _middleDot, style: style));
          }
          for (var measure in phrase.measures) {
            var textSpan = _nashvilleMeasureTextSpan(measure, originalKey, transpositionOffset,
                displayMusicKey: displayMusicKey, style: style);
            nashvilleChildren.add(TextSpan(text: ' ', style: style));
            nashvilleChildren.add(textSpan);
            if (measure.endOfRow) {
              nashvilleChildren.add(TextSpan(text: '  $_middleDot  ', style: style));
            }
          }
          if (phrase.isRepeat()) {
            nashvilleChildren.add(TextSpan(text: '  x${phrase.repeats}   ', style: style));
          } else {
            nashvilleChildren.add(TextSpan(text: '   ', style: style));
          }
        }
        break;
      case NashvilleSelection.off:
        break;
    }

    if (nashvilleChildren.isNotEmpty && children.isNotEmpty) {
      //  add nashville on new row
      children.add(TextSpan(text: '\n', style: style));
    }

    //  combine the lists
    children.addAll(nashvilleChildren);

    return TextSpan(children: children, style: style);
  }

  /// Transcribe the measure node to a text span, adding Nashville notation when appropriate.
  TextSpan _measureNashvilleSelectionTextSpan(
      final Measure measure, final music_key.Key originalKey, int transpositionOffset,
      {final music_key.Key? displayMusicKey, TextStyle? style}) {
    style = style ?? _coloredChordTextStyle;

    final List<TextSpan> children = [];
    switch (_nashvilleSelection) {
      case NashvilleSelection.off:
      case NashvilleSelection.both:
        var textSpan =
            _measureTextSpan(measure, originalKey, transpositionOffset, displayMusicKey: displayMusicKey, style: style);
        children.add(TextSpan(text: ' ', style: style));
        children.add(textSpan);
        break;
      default:
        break;
    }

    final List<TextSpan> nashvilleChildren = [];
    switch (_nashvilleSelection) {
      case NashvilleSelection.both:
      case NashvilleSelection.only:
        var textSpan = _nashvilleMeasureTextSpan(measure, originalKey, transpositionOffset,
            displayMusicKey: displayMusicKey, style: style);
        nashvilleChildren.add(TextSpan(text: ' ', style: style));
        nashvilleChildren.add(textSpan);
        break;
      case NashvilleSelection.off:
        break;
    }

    if (nashvilleChildren.isNotEmpty && children.isNotEmpty) {
      //  add nashville on new row
      children.add(TextSpan(text: '\n', style: style));
    }

    //  combine the lists
    children.addAll(nashvilleChildren);

    return TextSpan(children: children, style: style);
  }

  TextSpan _measureTextSpan(final Measure measure, final music_key.Key originalKey, final int transpositionOffset,
      {final music_key.Key? displayMusicKey, TextStyle? style}) {
    style = style ?? _coloredChordTextStyle;
    logger.v('_measureTextSpan: style.color: ${style.color}'
        ', black: ${Colors.black}, ==: ${style.color?.value == Colors.black.value}');
    var slashColor = style.color?.value == Colors.black.value ? _slashColor : _fadedSlashColor;
    final TextStyle slashStyle =
        style.copyWith(color: slashColor, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic);

    TextStyle chordDescriptorStyle =
        style.copyWith(fontSize: (style.fontSize ?? _chordFontSizeUnscaled), fontWeight: FontWeight.normal).copyWith(
              backgroundColor: style.backgroundColor,
            );

    //  figure the chord text span
    final List<TextSpan> children = [];

    if (measure.chords.isNotEmpty) {
      for (final chord in measure.chords) {
        var transposedChord = chord.transpose(displayMusicKey ?? originalKey, transpositionOffset);
        var isSlash = transposedChord.slashScaleNote != null;

        //  chord note
        children.add(TextSpan(
          text: transposedChord.scaleChord.scaleNote.toString(),
          style: style,
        ));
        {
          //  chord descriptor
          var name = transposedChord.scaleChord.chordDescriptor.shortName;
          if (name.isNotEmpty) {
            children.add(
              TextSpan(
                text: name,
                style: chordDescriptorStyle,
              ),
            );
          }
        }

        //  other stuff
        children.add(TextSpan(
          text: transposedChord.anticipationOrDelay.toString() + transposedChord.beatsToString(),
          style: style,
        ));
        if (isSlash) {
          var s = '/${transposedChord.slashScaleNote.toString()} '; //  notice the final space for italics
          //  and readability
          children.add(TextSpan(
            text: s,
            style: slashStyle,
          ));
        }
      }
    } else {
      //  no chord measures such as repeats, repeat markers and comments
      children.add(TextSpan(
        text: measure.toString(),
        style: style,
      ));
    }

    return TextSpan(
      style: style,
      children: children,
    );
  }

  TextSpan _nashvilleMeasureTextSpan(
      final Measure measure, final music_key.Key originalKey, final int transpositionOffset,
      {final music_key.Key? displayMusicKey, TextStyle? style}) {
    final keyOffset = originalKey.getHalfStep();

    style = style ?? _coloredChordTextStyle;
    var slashColor = style.color == Colors.black ? _slashColor : _fadedSlashColor;
    final TextStyle slashStyle =
        style.copyWith(color: slashColor, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic);

    TextStyle chordDescriptorStyle = generateChordDescriptorTextStyle(
      fontSize: 0.8 * (style.fontSize ?? _chordFontSizeUnscaled),
      fontWeight: FontWeight.normal,
      backgroundColor: style.backgroundColor,
    );

    //  text span for nashville, if required
    final List<TextSpan> nashvilleChildren = [];

    if (measure.chords.isNotEmpty) {
      bool first = true;
      for (final chord in measure.chords) {
        //  space the next chord in the measure
        if (first) {
          first = false;
        } else {
          nashvilleChildren.add(TextSpan(text: ' ', style: style));
        }

        nashvilleChildren.add(TextSpan(
            text: NashvilleNote.byHalfStep(chord.scaleChord.scaleNote.halfStep - keyOffset).toString(), style: style));
        nashvilleChildren
            .add(TextSpan(text: chord.scaleChord.chordDescriptor.toNashville(), style: chordDescriptorStyle));
        // nashvilleChildren.add(TextSpan(text: '${chord.anticipationOrDelay}', style: style));

        if (chord.slashScaleNote != null) {
          nashvilleChildren.add(TextSpan(
            //  notice the final space for italics  and readability
            text: '/${NashvilleNote.byHalfStep(chord.slashScaleNote!.halfStep - keyOffset)} ',
            style: slashStyle,
          ));
        }
      }
    }

    return TextSpan(style: style, children: nashvilleChildren);
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
    _sectionBackgroundColor = App.getBackgroundColorForSectionVersion(sectionVersion);
    _coloredChordTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _sectionBackgroundColor,
    );
    _coloredLyricTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _sectionBackgroundColor,
      fontSize: (_appOptions.userDisplayStyle == UserDisplayStyle.banner ? 0.5 : 1) * _lyricsFontSizeUnscaled,
      fontWeight: FontWeight.normal,
    );
  }

  /// compute screen size values used here and on other screens
  void _computeScreenSizes() {
    App app = App();
    _screenWidth = app.screenInfo.mediaWidth;
    _screenHeight = app.screenInfo.mediaHeight;

    //  rough in the basic fontsize
    _chordFontSizeUnscaled = 90; // max for hdmi resolution

    _scaleComponents();
    _lyricsFontSizeUnscaled = _chordFontSizeUnscaled * 0.75;

    //  text styles
    _chordTextStyle = generateChordTextStyle(
        fontFamily: appFontFamily, fontSize: _chordFontSizeUnscaled, fontWeight: FontWeight.bold);
    _lyricsTextStyle = _chordTextStyle.copyWith(fontSize: _lyricsFontSizeUnscaled, fontWeight: FontWeight.normal);
  }

  _scaleComponents({double scaleFactor = 1.0}) {
    _paddingSize = _paddingSizeMax * scaleFactor;
    _padding = EdgeInsets.all(_paddingSize);
    _marginSize = _marginSizeMax * scaleFactor;
    _margin = EdgeInsets.all(_marginSize);
  }

  NashvilleSelection _nashvilleSelection = NashvilleSelection.off;

  double get screenWidth => _screenWidth;
  double _screenWidth = 1920; //  initial value only

  double get screenHeight => _screenHeight;
  double _screenHeight = 1080; //  initial value only

  double _chordFontSizeUnscaled = appDefaultFontSize;
  double _lyricsFontSizeUnscaled = 18; //  initial value only

  double get marginSize => _marginSize;

  Grid<SongCellWidget> _locationGrid = Grid();

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

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
          logger.log(_logLyricSectionCellState, '_LyricSectionCellState.child returned: ${widget.index}: $child');
          return child;
        }
        selected = isNowSelected;
        return childBuilder(context);
      },
      child: Builder(builder: childBuilder),
    );
  }

  Widget childBuilder(BuildContext context) {
    logger.log(
        _logLyricSectionCellState,
        '_LyricSectionCellState.childBuilder: run: '
        '${widget.index}:'
        ' selected: $selected');
    return SizedBox(
      width: widget.width,
      child: selected
          ? appIcon(
              Icons.play_arrow,
              size: widget.fontSize,
              color: Colors.redAccent,
            )
          : NullWidget(), //Container( color:  Colors.cyan,height: widget.height), // empty box
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
    this.lyricSectionIndex,
    this.lyricSectionSet,
    this.size,
    this.point,
    this.columnWidth,
    this.withEllipsis,
    this.textScaleFactor = 1.0,
    this.songMoment,
    this.expanded,
    this.selectable,
  });

  SongCellWidget.empty({
    super.key,
    this.type = SongCellType.columnFill,
    this.measureNode,
    this.lyricSectionIndex,
    this.lyricSectionSet,
    this.size,
    this.point,
    this.columnWidth,
    this.withEllipsis,
    this.textScaleFactor = 1.0,
    this.songMoment,
    this.expanded,
    this.selectable,
  }) : richText = _emptyRichText;

  // : richText = RichText(key: richText.key,
  //         text: TextSpan(text: '${richText.text} nash', style: richText.text.style, ),
  //         textScaleFactor: textScaleFactor,
  //   softWrap: richText.softWrap,
  //       );

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
        text: //  default to one line
            TextSpan(text: richText.text.toPlainText(), style: richText.text.style),
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      copyOfRichText = RichText(
        key: richText.key,
        text: richText.text,
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        softWrap: richText.softWrap,
        maxLines: _maxLines, //richText.maxLines,
      );
    }

    //  count on package level margin and padding to have been scaled elsewhere
    return SongCellWidget(
      key: key,
      richText: copyOfRichText,
      type: type,
      measureNode: measureNode,
      lyricSectionIndex: lyricSectionIndex,
      lyricSectionSet: lyricSectionSet,
      size: size ?? this.size,
      point: point ?? this.point,
      columnWidth: columnWidth ?? this.columnWidth,
      withEllipsis: withEllipsis,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      songMoment: songMoment ?? this.songMoment,
      expanded: expanded,
      selectable: selectable,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _SongCellState();
  }

  ///  efficiency compromised for const StatelessWidget song cell
  Size get computedBuildSize {
    //logger.i('computedBuildSize: columnWidth: $columnWidth, $_maxLines');
    return (withEllipsis ?? false)
        ? size!
        : _computeRichTextSize(richText,
                textScaleFactor: textScaleFactor,
                maxLines: _maxLines,
                maxWidth: columnWidth ?? app.screenInfo.mediaWidth) +
            Offset(_paddingSize + 2.0 * _marginSize, 2.0 * _marginSize);
  }

  Size get buildSize => size ?? computedBuildSize;

  @override
  String toString({DiagnosticLevel? minLevel}) {
    return 'SongCellWidget{richText: $richText, type: ${type.name}, measureNode: $measureNode'
        ', type: ${measureNode?.measureNodeType}, size: $size, point: $point}';
  }

  final SongCellType type;
  final bool? withEllipsis;
  final RichText richText;
  final MeasureNode? measureNode;
  final int? lyricSectionIndex;
  final SplayTreeSet<int>? lyricSectionSet;
  final double textScaleFactor;
  final Size? size;
  final double? columnWidth;
  final Point<double>? point;
  final SongMoment? songMoment;
  final bool? expanded;
  final bool? selectable;
  static final _emptyRichText = RichText(
    text: const TextSpan(text: ''),
  );
}

class _SongCellState extends State<SongCellWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<SongMomentNotifier, LyricSectionNotifier>(
      builder: (context, songMomentNotifier, lyricSectionNotifier, child) {
        var moment = songMomentNotifier.songMoment;
        var isNowSelected = false;

        if (widget.selectable ?? true) {
          switch (widget.measureNode.runtimeType) {
            case LyricSection:
              isNowSelected = lyricSectionNotifier.index == widget.lyricSectionIndex;
              logger.log(
                  _logLyricSectionCellState,
                  '_SongCellState: $isNowSelected'
                  ', ${moment?.lyricSection} == ${widget.measureNode}'
                  //    ', songMoment: ${widget.songMoment} vs ${moment.momentNumber}'
                  );
              break;
            case ChordSection:
              isNowSelected = widget.lyricSectionSet?.contains(lyricSectionNotifier.index) ?? false;
              logger.log(
                  _logLyricSectionCellState,
                  '_SongCellState: ChordSection: $isNowSelected'
                  ', ${widget.measureNode}'
                  ', lyricSectionNotifier.index: ${lyricSectionNotifier.index}'
                  ', widget.lyricSectionIndex: ${widget.lyricSectionIndex}'
                  //    ', songMoment: ${widget.songMoment} vs ${moment.momentNumber}'
                  );
              break;
            default:
              isNowSelected = moment != null &&
                  (moment.momentNumber == widget.songMoment?.momentNumber ||
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

        // for efficiency
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
    if (selected) {
      logger.log(
          _logChildBuilder,
          '_SongCellState: ${widget.songMoment?.momentNumber}'
          ': ${widget.richText.text.toPlainText()}'
          ' dt: ${(AppAudioPlayer().getCurrentTime() - (SongMaster().songTime ?? 0)).toStringAsFixed(3)}'
          ', songTime: ${SongMaster().songTime}');
    }
    Size buildSize = widget.computedBuildSize;
    double width = 10; //  safety only
    switch (widget.type) {
      case SongCellType.columnMinimum:
        width = buildSize.width;
        break;
      default:
        width = widget.columnWidth ?? buildSize.width;
        break;
    }
    // if (widget.type == SongCellType.lyric) {
    //   logger.log(
    //       _logSongCell,
    //       '_SongCellState: childBuilder: '
    //       ', textScaleFactor: ${widget.textScaleFactor}'
    //       //  'selected: $selected, songMoment: ${widget.songMoment?.momentNumber}'
    //       // ', text: "${widget.richText.text.toPlainText() /*.substring(0, 10)*/}"'
    //       // ', len: ${widget.richText.text.toPlainText().length}'
    //       ', maxLines: ${widget.richText.maxLines}'
    //       // ', width: $width/$maxWidth'
    //       ', size: $buildSize'
    //       ', columnWidth: ${widget.columnWidth}');
    // }

    RichText richText = widget.richText;
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
        width: width,
        height: buildSize.height,
        color: color,
        margin: _margin,
        child: Container(
          width: width,
          height: buildSize.height,
          padding: _padding,
          foregroundDecoration: //
              selected
                  ? BoxDecoration(
                      border: Border.all(
                        width: _marginSize,
                        color: _highlightColor,
                      ),
                    )
                  : null,
          color: widget.richText.text.style?.backgroundColor ?? Colors.transparent,
          child: richText,
        ),
      );
    }

    return Container(
      width: width,
      height: widget.size?.height ?? buildSize.height,
      margin: _margin,
      padding: _padding,
      foregroundDecoration: //
          selected
              ? BoxDecoration(
                  border: Border.all(
                    width: _marginSize,
                    color: _highlightColor,
                  ),
                )
              : null,
      color: widget.richText.text.style?.backgroundColor ?? Colors.transparent,
      child: richText,
    );
  }

  var selected = false; //  indicates the cell is currently selected, i.e. highlighted
}
