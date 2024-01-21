import 'dart:collection';
import 'dart:math';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/grid.dart';
import 'package:bsteele_music_lib/grid_coordinate.dart';
import 'package:bsteele_music_lib/songs/chord_section.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/lyric.dart';
import 'package:bsteele_music_lib/songs/lyric_section.dart';
import 'package:bsteele_music_lib/songs/measure.dart';
import 'package:bsteele_music_lib/songs/measure_node.dart';
import 'package:bsteele_music_lib/songs/measure_repeat_extension.dart';
import 'package:bsteele_music_lib/songs/measure_repeat_marker.dart';
import 'package:bsteele_music_lib/songs/nashville_note.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/section_version.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_base.dart';
import 'package:bsteele_music_lib/songs/song_moment.dart';
import 'package:bsteele_music_lib/songs/song_update.dart';
import 'package:bsteele_music_lib/util/us_timer.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_lib/util/util.dart';
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
const Level _logFontSizeDetail = Level.debug;
const Level _logLyricSectionCellState = Level.debug;
const Level _logLyricSectionIndicatorCellState = Level.debug;
const Level _logLyricsBuild = Level.debug;
const Level _logHeights = Level.debug;
const Level _logLyricsTableItems = Level.debug;
const Level _logLyricSectionNotifier = Level.debug;
const Level _logChildBuilder = Level.debug;

const double _paddingSizeMax = 3; //  fixme: can't be 0
double _paddingSize = _paddingSizeMax;
EdgeInsets _padding = const EdgeInsets.all(_paddingSizeMax);
const double _marginSizeMax = 6; //  note: vertical and horizontal are identical //  fixme: can't be less than 2
double _marginSize = _marginSizeMax;
EdgeInsets _margin = const EdgeInsets.all(_marginSizeMax);
const _idleHighlightColor = Colors.redAccent;
const _playHighlightColor = Colors.greenAccent;
const _defaultMaxLines = 12;
var _maxLines = 1;

///  The trick of the game: Figure the text size prior to boxing it
Size _computeRichTextSize(
  final RichText richText, {
  int? maxLines,
  double? maxWidth,
}) {
  InlineSpan text = richText.text;
  if (text.toPlainText().isEmpty && richText.children.isNotEmpty) {
    var first = richText.children.first;
    if (first is TextSpan) {
      text = first as TextSpan;
    }
  }
  if (text.toPlainText().isEmpty) {
    return const Size(10, 20); //  safety
  }
  return _computeInlineSpanSize(richText.text, textScaler: richText.textScaler, maxLines: maxLines, maxWidth: maxWidth);
}

Size _computeInlineSpanSize(
  final InlineSpan inLineSpan, {
  TextScaler? textScaler,
  int? maxLines,
  double? maxWidth,
}) {
  TextPainter textPainter = TextPainter(
    text: inLineSpan,
    textDirection: TextDirection.ltr,
    maxLines: maxLines ?? _maxLines,
    textScaler: textScaler ?? TextScaler.noScaling,
  )..layout(maxWidth: maxWidth ?? app.screenInfo.mediaWidth);
  Size ret = textPainter.size * app.screenInfo.devicePixelRatio;
  textPainter.dispose();
  return ret;
}

/// Class to hold a song moment and indicate play in the count in, prior to the first song moment.
class PlayMoment {
  const PlayMoment(this.songUpdateState, this.playMomentNumber, this.songMoment);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayMoment &&
          runtimeType == other.runtimeType &&
          songUpdateState == other.songUpdateState &&
          playMomentNumber == other.playMomentNumber &&
          songMoment == other.songMoment;

  @override
  String toString() {
    return 'PlayMoment{songUpdateState: ${songUpdateState.name}, playMomentNumber: $playMomentNumber, songMoment: $songMoment}';
  }

  @override
  int get hashCode => Object.hash(songUpdateState, playMomentNumber, songMoment);

  final SongUpdateState songUpdateState;
  final int playMomentNumber;
  final SongMoment? songMoment;
}

class PlayMomentNotifier extends ChangeNotifier {
  set playMoment(final PlayMoment? newPlayMoment) {
    if (newPlayMoment != _playMoment) {
      _playMoment = newPlayMoment;
      notifyListeners();
    }
  }

  PlayMoment? get playMoment => _playMoment;
  PlayMoment? _playMoment;
}

class SongMasterNotifier extends ChangeNotifier {
  set songMaster(final SongMaster? songMaster) {
    //  note: no change optimization due to singleton
    _songMaster = songMaster;
    notifyListeners();
  }

  SongMaster? get songMaster => _songMaster;
  SongMaster? _songMaster;
}

class LyricSectionNotifier extends ChangeNotifier {
  setIndexRow(final int lyricSectionIndex, final int row) {
    if (lyricSectionIndex != _lyricSectionIndex || row != _row) {
      _lyricSectionIndex = lyricSectionIndex;
      _row = row;
      notifyListeners();
      logger.log(_logLyricSectionNotifier, 'lyricSection.index: $_lyricSectionIndex, row: $_row');
    }
  }

  @override
  String toString() {
    return 'index: $_lyricSectionIndex, row: $_row, lyricSection: $lyricSection';
  }

  int get lyricSectionIndex => _lyricSectionIndex;
  int _lyricSectionIndex = 0;

  int get row => _row;
  int _row = 0;

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

    _locationGrid = Grid<_SongCellWidget>();

    //  compute transposition offset from base key

    displayMusicKey = musicKey ?? song.key;
    int transpositionOffset = displayMusicKey.getHalfStep() - song.key.getHalfStep();

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
                  _SongCellWidget(
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

          bool rowHasReducedBeats = _rowHasExplicitBeats(row);

          for (var c = 0; c < row.length; c++) {
            ChordSection chordSection = displayGrid.get(r, c) as ChordSection;
            _colorBySectionVersion(chordSection.sectionVersion);

            //  generate the lyric section set of matching lyric sections
            SplayTreeSet<int> set = SplayTreeSet();
            for (var i = 0; i < song.lyricSections.length; i++) {
              if (song.lyricSections[i].sectionVersion == chordSection.sectionVersion) {
                set.add(i);
              }
            }

            //  subsequent rows
            switch (c) {
              case 0:
                _locationGrid.set(
                  r,
                  c,
                  _SongCellWidget(
                    richText: RichText(
                      text: TextSpan(
                        text: chordSection.sectionVersion.toString(),
                        style: _coloredChordTextStyle,
                      ),
                    ),
                    type: SongCellType.columnFill,
                    measureNode: chordSection,
                    lyricSectionSet: set,
                  ),
                );
                break;
              case 1:
                _locationGrid.set(
                  r,
                  c,
                  _SongCellWidget(
                    richText: RichText(
                      text: _chordSectionTextSpan(chordSection, song.key, transpositionOffset),
                    ),
                    type: SongCellType.columnMinimum,
                    measureNode: chordSection,
                    lyricSectionSet: set,
                    rowHasReducedBeats: rowHasReducedBeats,
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
                      _SongCellWidget(
                        richText: RichText(
                          text: TextSpan(
                            text: chordSection.sectionVersion.toString(),
                            style: _coloredChordTextStyle,
                          ),
                        ),
                        type: SongCellType.columnMinimum,
                        measureNode: lyricSection,
                        lyricSectionIndex: lyricSection.index,
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
                    _SongCellWidget(
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
                    _SongCellWidget(
                      richText: RichText(
                        text: _chordSectionTextSpan(
                          chordSection,
                          song.key,
                          transpositionOffset,
                          displayMusicKey: displayMusicKey,
                          style: _coloredLyricTextStyle.copyWith(
                            color: Colors.black54,
                            backgroundColor: App.disabledColor,
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
                    _SongCellWidget(
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
                      ? _SongCellWidget.empty(
                          isFixedHeight: true,
                        )
                      : _SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: chordSection.sectionVersion.toString(),
                              style: _coloredChordTextStyle,
                            ),
                          ),
                          type: SongCellType.columnMinimum,
                          measureNode: mn,
                          isFixedHeight: true,
                        ),
                );
                break;
              case BannerColumn.repeats:
                var marker = mn is MeasureRepeatMarker ? mn : null;
                _locationGrid.set(
                  banner.index,
                  momentNumber,
                  marker == null
                      ? _SongCellWidget.empty(
                          isFixedHeight: true,
                        )
                      : _SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: 'x${(marker.repetition ?? 0) + 1}/${marker.repeats}',
                              style: _coloredLyricTextStyle,
                            ),
                          ),
                          type: SongCellType.columnMinimum,
                          measureNode: mn,
                          isFixedHeight: true,
                        ),
                );
                break;
              case BannerColumn.lyrics:
                var lyric = mn is Lyric ? mn : null;
                _locationGrid.set(
                  banner.index,
                  momentNumber,
                  lyric == null
                      ? _SongCellWidget.empty()
                      : _SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: lyric.toMarkup(),
                              style: _coloredLyricTextStyle,
                            ),
                          ),
                          type: SongCellType.columnFill,
                          measureNode: mn,
                          isFixedHeight: true,
                        ),
                );
                break;
              default:
                _locationGrid.set(
                  banner.index,
                  momentNumber,
                  mn == null
                      ? _SongCellWidget.empty()
                      : _SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: mn.toString(),
                              style: _coloredChordTextStyle,
                            ),
                          ),
                          type: SongCellType.columnFill,
                          measureNode: mn,
                          isFixedHeight: true,
                        ),
                );
                break;
            }
          }
        }
        break;

      case UserDisplayStyle.player:
      case UserDisplayStyle.both:
        {
          LyricSection? lyricSection;
          for (var r = 0; r < displayGrid.getRowCount(); r++) {
            List<MeasureNode?>? row = displayGrid.getRow(r);
            assert(row != null);
            row = row!;

            //  see if the row has reduced beats
            bool rowHasReducedBeats = _rowHasExplicitBeats(row);

            for (var c = 0; c < row.length; c++) {
              MeasureNode? measureNode = displayGrid.get(r, c);
              if (measureNode == null) {
                continue;
              }
              switch (measureNode.measureNodeType) {
                case MeasureNodeType.lyricSection:
                  lyricSection = measureNode as LyricSection;
                  _displayChordSection(
                      GridCoordinate(r, c), song.findChordSectionByLyricSection(lyricSection)!, measureNode,
                      selectable: false, lyricSectionIndex: lyricSection.index);
                  break;
                case MeasureNodeType.section:
                  _displayChordSection(GridCoordinate(r, c), measureNode as ChordSection, measureNode,
                      lyricSectionIndex: lyricSection?.index);
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
                      _SongCellWidget(
                        richText: RichText(
                          text: TextSpan(
                            text: measureNode.toMarkup().trim(),
                            style: _coloredLyricTextStyle,
                          ),
                          maxLines: songCellType == SongCellType.lyricEllipsis ? 1 : _maxLines,
                        ),
                        type: songCellType,
                        measureNode: measureNode,
                        lyricSectionIndex: lyricSection?.index,
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
                      case const (MeasureRepeatExtension):
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
                      case const (MeasureRepeatMarker):
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
                            textAlign: TextAlign.start,
                            textHeightBehavior: const TextHeightBehavior(),
                          );
                        }
                        break;
                      case const (Measure):
                        richText = RichText(
                          text: _measureNashvilleSelectionTextSpan(measure, song.key, transpositionOffset,
                              style: _coloredChordTextStyle,
                              displayMusicKey: displayMusicKey,
                              showBeats: Measure.reducedTopDots),
                          //  don't allow the rich text to wrap:
                          textWidthBasis: TextWidthBasis.longestLine,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          textHeightBehavior: const TextHeightBehavior(),
                        );
                        break;
                    }

                    _locationGrid.set(
                      r,
                      c,
                      _SongCellWidget(
                        richText: richText,
                        type: SongCellType.columnFill,
                        measureNode: measureNode,
                        lyricSectionIndex: lyricSection?.index,
                        expanded: expanded,
                        rowHasReducedBeats: rowHasReducedBeats,
                      ),
                    );
                  }
                  break;

                default:
                  //  color done by prior chord section
                  _locationGrid.set(
                    r,
                    c,
                    _SongCellWidget(
                      richText: RichText(
                        text: TextSpan(
                          text: measureNode.toMarkup(),
                          style: _coloredChordTextStyle,
                        ),
                      ),
                      type: SongCellType.columnFill,
                      measureNode: measureNode,
                      lyricSectionIndex: lyricSection?.index,
                      rowHasReducedBeats: rowHasReducedBeats,
                    ),
                  );
                  break;
              }
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
    double arrowIndicatorWidth = _appOptions.playWithLineIndicator ? _chordFontSizeUnscaled : 0;
    var totalWidth =
        widths.fold<double>(arrowIndicatorWidth, (previous, e) => previous + e + _paddingSize + 2 * _marginSize);
    var chordWidth = totalWidth - widths.last;
    logger.log(_logFontSize, 'chord ratio: $chordWidth/$totalWidth = ${chordWidth / totalWidth}');

    //  limit space for player lyrics
    if (_appOptions.userDisplayStyle == UserDisplayStyle.player && widths.last == 0) {
      widths.last = max(0.3 * totalWidth, 0.97 * (screenWidth - totalWidth));
      totalWidth = chordWidth + widths.last;
    } else if (_appOptions.userDisplayStyle == UserDisplayStyle.both) {
      if (totalWidth >= screenWidth) {
        //  use as much spare space as needed for lyrics
        widths.last = max(0.4 * totalWidth, 0.97 * (screenWidth - (totalWidth - widths.last)));
        totalWidth = chordWidth + widths.last;
      }
    }
    logger.log(_logFontSizeDetail, 'raw widths.last: ${widths.last}/$totalWidth = ${widths.last / totalWidth}');
    logger.log(_logFontSizeDetail, 'raw widths: $widths, total: ${widths.fold(0.0, (p, e) => p + e)}');

    logger.log(
        _logFontSizeDetail,
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
        _scaleFactor = 0.98 * screenWidth / totalWidth;
        break;
    }

    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.proPlayer:
        //  fit everything vertically
        // logger.log(_logFontSize, 'proPlayer: _scaleFactor: $_scaleFactor vs ${screenHeight * 0.65 / totalHeight}');
        {
          var oldScaleFactor = _scaleFactor;
          _scaleFactor = min(
              _scaleFactor,
              screenHeight *
                  0.65 //  fixme: this is only close, empirically
                  /
                  totalHeight);
          widths[1] = screenWidth * oldScaleFactor / _scaleFactor; //  fixme: a nasty hack
        }
        break;
      default:
        break;
    }
    _scaleFactor = min(_scaleFactor, 1.0);
    _scaleFactor /= app.screenInfo.devicePixelRatio; //fixme: why?

    logger.log(_logFontSize, '_scaleFactor: $_scaleFactor, ${app.screenInfo.fontSize}');
    logger.log(
        _logFontSizeDetail,
        'totalWidth: $totalWidth, totalHeight: $totalHeight, screenWidth: $screenWidth'
        ', scaled width: ${totalWidth * _scaleFactor}');

    //  rescale the grid to fit the window
    _scaleFactor = min(_scaleFactor, 1.0);
    _scaleComponents(scaleFactor: _scaleFactor);
    if (_scaleFactor < 1.0) {
      //  reset the widths to scale
      double widthSum = arrowIndicatorWidth;
      for (var i = 0; i < widths.length; i++) {
        var w = widths[i] * _scaleFactor;
        widths[i] = w;
        widthSum += w + _paddingSize + 2 * marginSize;
      }
      _unusedMargin = max(1, (screenWidth - widthSum) / 2);
      logger.i(
          'screenWidth: $screenWidth, widthSum: $widthSum, _scaleFactor: $_scaleFactor, _unusedMargin: $_unusedMargin'); // fixme: this basically fails

      //  reset the heights to scale
      for (var i = 0; i < heights.length; i++) {
        heights[i] = heights[i] * _scaleFactor;
      }
    } else {
      _unusedMargin = max(0, (screenWidth - totalWidth) / 2);
      logger.i(
          'screenWidth: $screenWidth, totalWidth: $totalWidth, _scaleFactor: $_scaleFactor, _unusedMargin: $_unusedMargin'); // fixme: this basically fails
    }

    logger.log(_logHeights, 'scaled heights: $heights');
    if (_logFontSize.index <= Level.info.index) {
      var scaledTotal = widths.fold(0.0, (p, e) => p + e);
      logger.log(_logFontSize, 'scaled widths.last: ${widths.last}, fraction: ${widths.last / scaledTotal}');
      logger.log(_logFontSizeDetail, 'scaled widths: $widths, total: $scaledTotal');
      logger.log(
          _logFontSize,
          'scaled:'
          ' chordFontSize: ${(_chordFontSizeUnscaled * _scaleFactor).toStringAsFixed(2)}'
          ', lyricsFontSize: ${(_lyricsFontSizeUnscaled * _scaleFactor).toStringAsFixed(2)}'
          ', _scaleFactor: $_scaleFactor'
          ', _marginSize: ${_marginSize.toStringAsFixed(2)}'
          ', padding: ${_paddingSize.toStringAsFixed(2)}');
    }
    _maxLines = _appOptions.userDisplayStyle == UserDisplayStyle.player ? 1 : _defaultMaxLines;

    //  set the location grid sizing
    final double xMargin = 2.0 * _marginSize;
    final double yMargin = xMargin; // same size as x
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
      logger.t('map: ${songMoment.momentNumber}:'
          ' ${song.songMomentToGridCoordinate[songMoment.momentNumber]}');
      var gc = song.songMomentToGridCoordinate[songMoment.momentNumber];
      _locationGrid.setAt(
        gc,
        _locationGrid.at(gc)?.copyWith(songMoment: songMoment),
      );
    }
    logger.log(_logLyricsBuild, 'lyricsBuild: songMoment mapping: ${usTimer.deltaToString()}');

    //  box up the children, applying necessary widths and heights
    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        {
          for (var c = 0; c < song.songMoments.length; c++) {
            List<_SongCellWidget> columnChildren = [];
            for (var r = 0; r < BannerColumn.values.length; r++) {
              var cell = _locationGrid.get(r, c);
              assert(cell != null);
              columnChildren.add(cell!.copyWith(size: Size(widths[c], heights[r])));
            }
            Widget columnWidget = Column(crossAxisAlignment: CrossAxisAlignment.start, children: columnChildren);
            logger.t('banner columnChildren: ${columnChildren.map((c) => c.size)}');
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

      //  other user display styles
      default:
        {
          List<Widget> sectionChildren = [];
          LyricSection? lastLyricSection;
          for (var r = 0; r < _locationGrid.getRowCount(); r++) {
            var row = _locationGrid.getRow(r);
            assert(row != null);
            row = row!;

            sectionChildren.add(AppSpace(
              horizontalSpace: arrowIndicatorWidth * _scaleFactor,
              verticalSpace: r == 0 ? initialVerticalOffset : 0,
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
                  logger.t(' ChordSection: ${cell.measureNode}');
                  lyricSection = cell.measureNode as LyricSection;
                }
              }
              rowChildren.add(child);
            }
            Widget rowWidget;
            {
              if (r == 0 && _appOptions.userDisplayStyle == UserDisplayStyle.proPlayer) {
                //  put the first row of pro in a wrap
                rowWidget = AppWrap(children: [
                  AppSpace(
                    horizontalSpace: arrowIndicatorWidth * _scaleFactor,
                  ),
                  ...rowChildren
                ]);
              } else if (arrowIndicatorWidth > 0) {
                // add a row indicator if required
                var firstWidget = LyricSectionIndicatorCellWidget(
                  lyricSection: lyricSection!,
                  row: r,
                  width: arrowIndicatorWidth * _scaleFactor,
                  height: heights[r],
                  fontSize: _chordFontSizeUnscaled * _scaleFactor,
                );
                rowWidget = Row(children: [
                  // AppSpace(
                  //   horizontalSpace: _unusedMargin/2, // centering
                  // ),
                  firstWidget,
                  ...rowChildren
                ]);
              } else {
                rowWidget = Row(children: [
                  // AppSpace(
                  //   horizontalSpace: _unusedMargin/2, // centering
                  // ),
                  ...rowChildren
                ]);
              }
              // logger.t('rowChildren: $rowChildren');
            }

            lastLyricSection = lyricSection;
            items.add(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sectionChildren,
            ));
            sectionChildren = [];

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

    //  show copyright
    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        items.add(Text(
          'Release/Label: ${song.copyright}',
          style: _lyricsTextStyle,
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
                'Release/Label: ${song.copyright}',
                style: _lyricsTextStyle.copyWith(
                    fontSize: (_lyricsTextStyle.fontSize ?? _lyricsFontSizeUnscaled) * _scaleFactor * 0.75),
              ),
              //  give the scrolling some stuff to scroll the bottom up on
              AppSpace(verticalSpace: screenHeight / 2),
            ],
          ),
        ));
        break;
    }

    logger.log(_logLyricsBuild, 'lyricsBuild: boxing: ${usTimer.deltaToString()}');

    //  build the lookups for song moment and lyric sections
    {
      int lastSongMomentNumber = 0;
      _songMomentNumberToRowMap.clear();
      _lyricSectionIndexToRowMap.clear();
      _songMomentNumberToRowMap[0] = 0;
      for (var r = 0; r < _locationGrid.getRowCount(); r++) {
        logger.log(_logLyricsTableItems, 'row $r:');
        var row = _locationGrid.getRow(r);
        assert(row != null);
        row = row!;
        _rowCount = r;

        for (var c = 0; c < row.length; c++) {
          var cell = _locationGrid.get(r, c);
          if (cell == null) {
            continue; //  for example, first column in lyrics for singer display style
          }
          var songMoment = cell.songMoment;
          if (songMoment == null) {
            continue;
          }
          if (_lyricSectionIndexToRowMap[songMoment.lyricSection.index] == null) {
            _lyricSectionIndexToRowMap[songMoment.lyricSection.index] = r;
          }
          while (songMoment.momentNumber >= lastSongMomentNumber) {
            _songMomentNumberToRowMap[lastSongMomentNumber] = r;
            lastSongMomentNumber++;
          }
          logger.log(
              _logLyricsTableItems,
              '  $c: songMoment: $songMoment, repeat: ${songMoment.repeatMax}'
              ', lyricSection.index: ${songMoment.lyricSection.index}'
              // ',  ${cell?.measureNode}'
              );
        }
      }
    }
    // logger.i((SplayTreeSet<int>.from(_songMomentNumberToRowMap.keys)
    //     .map((k) => '$k -> ${_songMomentNumberToRowMap[k]}')).toList().toString());
    // logger.i((SplayTreeSet<int>.from(_lyricSectionIndexToRowMap.keys)
    //     .map((k) => '$k -> ${_lyricSectionIndexToRowMap[k]}')).toList().toString());

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
          if (phrase.isRepeat()) {
            children.add(TextSpan(text: '[ ', style: style));
          }
          for (var measure in phrase.measures) {
            var textSpan = _measureTextSpan(measure, originalKey, transpositionOffset,
                displayMusicKey: displayMusicKey, style: style, showBeats: true);
            if (children.isNotEmpty) children.add(TextSpan(text: ' ', style: style));
            children.add(textSpan);
            if (measure.endOfRow) {
              children.add(TextSpan(text: ',  ', style: style));
            }
          }
          if (phrase.isRepeat()) {
            children.add(TextSpan(text: ' ] x${phrase.repeats}   ', style: style));
          } else {
            children.add(TextSpan(text: '   ', style: style));
          }
        }
        break;
      default:
        break;
    }

    if (_nashvilleSelection == NashvilleSelection.both) {
      children.add(TextSpan(text: '\n', style: style));
    }

    final List<TextSpan> nashvilleChildren = [];
    switch (_nashvilleSelection) {
      case NashvilleSelection.both:
      case NashvilleSelection.only:
        for (var phrase in chordSection.phrases) {
          if (phrase.isRepeat()) {
            children.add(TextSpan(text: '[ ', style: style));
          }
          if (nashvilleChildren.isNotEmpty) {
            //  space the nashville children with a dot
            nashvilleChildren.add(TextSpan(text: _middleDot, style: style));
          }
          for (var measure in phrase.measures) {
            var textSpan = _nashvilleMeasureTextSpan(measure, originalKey, transpositionOffset,
                displayMusicKey: displayMusicKey, style: style);
            if (nashvilleChildren.isNotEmpty) nashvilleChildren.add(TextSpan(text: ' ', style: style));
            nashvilleChildren.add(textSpan);
            if (measure.endOfRow) {
              nashvilleChildren.add(TextSpan(text: '  $_middleDot  ', style: style));
            }
          }
          if (phrase.isRepeat()) {
            nashvilleChildren.add(TextSpan(text: ' ] x${phrase.repeats}   ', style: style));
          } else {
            nashvilleChildren.add(TextSpan(text: '   ', style: style));
          }
        }
        break;
      case NashvilleSelection.off:
        break;
    }

    //  combine the lists
    children.addAll(nashvilleChildren);

    return TextSpan(children: children, style: style);
  }

  ///  see if the row has reduced beats
  bool _rowHasExplicitBeats(final List<MeasureNode?> row) {
    //  see if the row has reduced beats
    bool rowHasExplicitBeats = false;
    for (var c = 0; c < row.length; c++) {
      MeasureNode? measureNode = row[c];
      if (measureNode == null) {
        continue;
      }
      switch (measureNode.measureNodeType) {
        case MeasureNodeType.measure:
          //  color done by prior chord section
          {
            Measure measure = measureNode as Measure;
            rowHasExplicitBeats = rowHasExplicitBeats || measure.requiresNashvilleBeats;
          }
          break;
        default:
          break;
      }
    }
    //logger.i('rowHasExplicitBeats: rowHasExplicitBeats');
    return rowHasExplicitBeats;
  }

  /// Transcribe the measure node to a text span, adding Nashville notation when appropriate.
  TextSpan _measureNashvilleSelectionTextSpan(
      final Measure measure, final music_key.Key originalKey, int transpositionOffset,
      {final music_key.Key? displayMusicKey, TextStyle? style, final bool showBeats = true}) {
    style = style ?? _coloredChordTextStyle;

    final List<TextSpan> children = [];
    switch (_nashvilleSelection) {
      case NashvilleSelection.off:
      case NashvilleSelection.both:
        var textSpan = _measureTextSpan(measure, originalKey, transpositionOffset,
            displayMusicKey: displayMusicKey, style: style, showBeats: showBeats);
        if (children.isNotEmpty) children.add(TextSpan(text: ' ', style: style));
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
        if (nashvilleChildren.isNotEmpty) nashvilleChildren.add(TextSpan(text: ' ', style: style));
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
      {final music_key.Key? displayMusicKey, TextStyle? style, final bool showBeats = false}) {
    style = style ?? _coloredChordTextStyle;
    logger.t('_measureTextSpan: style.color: ${style.color}'
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
        List<TextSpan> chordChildren = [];
        var transposedChord = chord.transpose(displayMusicKey ?? originalKey, transpositionOffset);
        var isSlash = transposedChord.slashScaleNote != null;

        //  chord note
        {
          var scaleNote = transposedChord.scaleChord.scaleNote;
          //  process scale note by accidental choice
          switch (_appOptions.accidentalExpressionChoice) {
            case AccidentalExpressionChoice.alwaysSharp:
              scaleNote = scaleNote.asSharp();
              break;
            case AccidentalExpressionChoice.alwaysFlat:
              scaleNote = scaleNote.asFlat();
              break;
            case AccidentalExpressionChoice.easyRead:
              scaleNote = scaleNote.asEasyRead();
              break;
            default:
              break;
          }

          chordChildren.add(TextSpan(
            text: scaleNote.toString(),
            style: style,
          ));
        }
        {
          //  chord descriptor
          var name = transposedChord.scaleChord.chordDescriptor.shortName;
          if (name.isNotEmpty) {
            chordChildren.add(
              TextSpan(
                text: name,
                style: chordDescriptorStyle,
              ),
            );
          }
        }

        //  other stuff
        {
          var otherStuff = transposedChord.anticipationOrDelay.toString() +
              (showBeats && !measure.requiresNashvilleBeats ? transposedChord.beatsToString() : '');
          if (otherStuff.isNotEmpty) {
            chordChildren.add(TextSpan(
              text: otherStuff,
              style: style,
            ));
          }
        }
        if (isSlash) {
          var slashScaleNote = transposedChord.slashScaleNote //
              ??
              ScaleNote.X; //  should never happen!

          //  process scale note by accidental choice
          switch (_appOptions.accidentalExpressionChoice) {
            case AccidentalExpressionChoice.alwaysSharp:
              slashScaleNote = slashScaleNote.asSharp();
              break;
            case AccidentalExpressionChoice.alwaysFlat:
              slashScaleNote = slashScaleNote.asFlat();
              break;
            case AccidentalExpressionChoice.easyRead:
              slashScaleNote = slashScaleNote.asEasyRead();
              break;
            default:
              break;
          }
          var s = '/$slashScaleNote '; //  notice the final space for italics
          //  and readability
          chordChildren.add(TextSpan(
            text: s,
            style: slashStyle,
          ));
        }
        children.add(TextSpan(children: chordChildren));
      }
    } else {
      //  non chord measures such as repeats, repeat markers and comments
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
      fontSize: (style.fontSize ?? _chordFontSizeUnscaled),
      fontWeight: FontWeight.normal,
      backgroundColor: style.backgroundColor,
    );

    //  text span for nashville, if required
    final List<TextSpan> nashvilleChildren = [];

    if (measure.chords.isNotEmpty) {
      bool first = true;
      for (final chord in measure.chords) {
        //  note: algorithm elsewhere relies on only one text span per chord!

        //  space the next chord in the measure
        final List<TextSpan> chordChildren = [];
        if (first) {
          first = false;
        } else {
          chordChildren.add(TextSpan(text: ' ', style: style));
        }

        chordChildren.add(TextSpan(
            text: NashvilleNote.byHalfStep(chord.scaleChord.scaleNote.halfStep - keyOffset).toString(), style: style));
        {
          String descriptor = chord.scaleChord.chordDescriptor.toNashville();
          if (descriptor.isNotEmpty) {
            chordChildren.add(TextSpan(text: descriptor, style: chordDescriptorStyle));
          }
        }
        // nashvilleChildren.add(TextSpan(text: '${chord.anticipationOrDelay}', style: style));

        if (chord.slashScaleNote != null) {
          chordChildren.add(TextSpan(
            //  notice the final space for italics  and readability
            text: '/${NashvilleNote.byHalfStep(chord.slashScaleNote!.halfStep - keyOffset)} ',
            style: slashStyle,
          ));
        }
        nashvilleChildren.add(TextSpan(children: chordChildren, style: style));
      }
    }

    return TextSpan(style: style, children: nashvilleChildren);
  }

  void _displayChordSection(GridCoordinate gc, ChordSection chordSection, MeasureNode measureNode,
      {bool? selectable, int? lyricSectionIndex}) {
    _colorBySectionVersion(chordSection.sectionVersion);
    _locationGrid.setAt(
      gc,
      _SongCellWidget(
        richText: RichText(
          text: TextSpan(
            text: chordSection.sectionVersion.toString(),
            style: _coloredSectionTextStyle,
          ),
        ),
        type: SongCellType.flow,
        measureNode: measureNode,
        selectable: selectable,
        lyricSectionIndex: lyricSectionIndex,
      ),
    );
  }

  void _colorBySectionVersion(SectionVersion sectionVersion) {
    _sectionBackgroundColor = App.getBackgroundColorForSectionVersion(sectionVersion);
    _coloredChordTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _sectionBackgroundColor,
    );
    _coloredSectionTextStyle = _coloredChordTextStyle.copyWith(
      fontSize: (_coloredChordTextStyle.fontSize ?? appDefaultFontSize) / 2,
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
    _chordFontSizeUnscaled = 65; // max for hdmi resolution

    _scaleComponents();
    _lyricsFontSizeUnscaled = _chordFontSizeUnscaled * 0.75;

    //  text styles
    _chordTextStyle = generateChordTextStyle(
        fontFamily: appFontFamily, fontSize: _chordFontSizeUnscaled, fontWeight: FontWeight.bold);
    _lyricsTextStyle = _chordTextStyle.copyWith(fontSize: _lyricsFontSizeUnscaled, fontWeight: FontWeight.normal);
  }

  int songMomentNumberToRow(final int? rowNumber) {
    if (rowNumber == null) {
      return 0;
    }
    return _songMomentNumberToRowMap[rowNumber] ?? 0 /* should never be null */;
  }

  int rowToLyricSectionIndex(final int row) {
    if (_locationGrid.isEmpty) {
      return 0;
    }
    //  fixme: to weak
    //  find the grid row
    var gridRow = _locationGrid.getRow(Util.intLimit(row, 0, _locationGrid.getRowCount() - 1));
    if (gridRow == null || gridRow.isEmpty) {
      return 0;
    }
    //  find the lyric section from the row
    for (var cell in gridRow) {
      if (cell != null && cell.lyricSectionIndex != null) {
        return cell.lyricSectionIndex!;
      }
    }
    return 0;
  }

  int rowToMomentNumber(final int row) {
    if (_locationGrid.isEmpty) {
      return 0;
    }

    //  look past the current row to find the moment... the row might just be a section header.
    for (int r = row; r <= row + 1; r++) {
      //  fixme: too weak
      //  find the grid row
      var gridRow = _locationGrid.getRow(Util.intLimit(r, 0, _locationGrid.getRowCount() - 1));
      if (gridRow == null || gridRow.isEmpty) {
        continue;
      }
      //  find the lyric section from the row
      for (var cell in gridRow) {
        if (cell != null && cell.songMoment != null) {
          return cell.songMoment!.momentNumber;
        }
      }
    }
    return 0;
  }

  int lyricSectionIndexToRow(final int index) =>
      _lyricSectionIndexToRowMap[index] ?? 1 /* can be null prior to song eval */;

  _scaleComponents({double scaleFactor = 1.0}) {
    _paddingSize = _paddingSizeMax * scaleFactor;
    _padding = EdgeInsets.all(_paddingSize);
    _marginSize = _marginSizeMax * scaleFactor;
    _margin = EdgeInsets.all(_marginSize);
  }

  NashvilleSelection _nashvilleSelection = NashvilleSelection.off;

  double get screenWidth => _screenWidth;
  double _screenWidth = 1920; //  initial value only

  double get unusedMargin => _unusedMargin;
  double _unusedMargin = 1;

  double get screenHeight => _screenHeight;
  double _screenHeight = 1080; //  initial value only

  double _chordFontSizeUnscaled = appDefaultFontSize;
  double _lyricsFontSizeUnscaled = 18; //  initial value only

  double get marginSize => _marginSize;

  Grid<_SongCellWidget> _locationGrid = Grid();

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateLyricsTextStyle();
  static const double initialVerticalOffset = 105;

  Color _sectionBackgroundColor = Colors.white;
  TextStyle _coloredSectionTextStyle = generateLyricsTextStyle();
  TextStyle _coloredChordTextStyle = generateLyricsTextStyle();
  TextStyle _coloredLyricTextStyle = generateLyricsTextStyle();

  double _scaleFactor = 1.0;

  int get rowCount => _rowCount;
  int _rowCount = 0;

  final Map<int, int> _songMomentNumberToRowMap = HashMap();
  final Map<int, int> _lyricSectionIndexToRowMap = HashMap();

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

class LyricSectionIndicatorCellWidget extends StatefulWidget {
  LyricSectionIndicatorCellWidget(
      {super.key,
      required this.lyricSection,
      required this.row,
      required this.width,
      required this.height,
      this.fontSize = appDefaultFontSize})
      : index = lyricSection.index;

  @override
  State<StatefulWidget> createState() {
    return _LyricSectionIndicatorCellState();
  }

  final LyricSection lyricSection;
  final int row;
  final double fontSize;
  final double width;
  final double height;
  final int index;
}

class _LyricSectionIndicatorCellState extends State<LyricSectionIndicatorCellWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayMomentNotifier, LyricSectionNotifier>(
      builder: (context, playMomentNotifier, lyricSectionNotifier, child) {
        var isNowSelected =
            lyricSectionNotifier.lyricSectionIndex == widget.index && lyricSectionNotifier.row == widget.row;
        if (isNowSelected == selected &&
            _songUpdateState == playMomentNotifier.playMoment?.songUpdateState &&
            child != null) {
          logger.log(
              _logLyricSectionIndicatorCellState,
              'LyricSectionIndicatorCellState.child'
              ' remained: ${widget.index}, row: ${lyricSectionNotifier.row} $child');
          return child;
        }
        selected = isNowSelected;
        _songUpdateState = playMomentNotifier.playMoment?.songUpdateState;
        logger.log(
            _logLyricSectionIndicatorCellState,
            'LyricSectionIndicatorCellState selected: $selected'
            ', notifier: ${lyricSectionNotifier.lyricSectionIndex}');
        return childBuilder(context);
      },
      child: Builder(builder: childBuilder),
    );
  }

  Widget childBuilder(BuildContext context) {
    logger.log(
        _logLyricSectionIndicatorCellState,
        'LyricSectionIndicatorCellState.childBuilder: run: '
        '${widget.index}:'
        ' selected: $selected');

    switch (AppOptions().playerScrollHighlight) {
      case PlayerScrollHighlight.off:
      case PlayerScrollHighlight.measure:
        return NullWidget();
      default:
        break;
    }

    return SizedBox(
      width: widget.width,
      child: selected
          ? Transform.flip(
              child: appIcon(
              Icons.play_arrow,
              size: widget.fontSize,
              color: _songUpdateState == SongUpdateState.playing ? _playHighlightColor : _idleHighlightColor,
            ))
          : NullWidget(), //Container( color:  Colors.cyan,height: widget.height), // empty box
    );
  }

  var selected = false;
  SongUpdateState? _songUpdateState;
}

class _SongCellWidget extends StatefulWidget {
  const _SongCellWidget({
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
    this.songMoment,
    this.expanded,
    this.selectable,
    this.isFixedHeight = false,
    this.rowHasReducedBeats = false,
  });

  _SongCellWidget.empty({
    this.type = SongCellType.columnFill,
    this.measureNode,
    this.lyricSectionIndex,
    this.lyricSectionSet,
    this.size,
    this.point,
    this.columnWidth,
    this.withEllipsis,
    this.songMoment,
    this.expanded,
    this.selectable,
    this.isFixedHeight = false,
    this.rowHasReducedBeats = false,
  }) : richText = _emptyRichText;

  _SongCellWidget copyWith({
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
        textScaler: textScaleFactor != null ? TextScaler.linear(textScaleFactor) : richText.textScaler,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else {
      copyOfRichText = RichText(
        key: richText.key,
        text: richText.text,
        textScaler: textScaleFactor != null ? TextScaler.linear(textScaleFactor) : richText.textScaler,
        softWrap: richText.softWrap,
        maxLines: _maxLines, //richText.maxLines,
      );
    }

    //  count on package level margin and padding to have been scaled elsewhere
    return _SongCellWidget(
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
      songMoment: songMoment ?? this.songMoment,
      expanded: expanded,
      selectable: selectable,
      isFixedHeight: isFixedHeight,
      rowHasReducedBeats: rowHasReducedBeats,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _SongCellState();
  }

  ///  efficiency compromised for const StatelessWidget song cell
  Size get computedBuildSize {
    //  add a tolerance
    var width = columnWidth ?? app.screenInfo.mediaWidth;
    var ret = (withEllipsis ?? false)
        ? size!
        : _computeRichTextSize(richText, maxWidth: width) +
            Offset(2 * _paddingSize + 2.0 * _marginSize, 2 * _paddingSize + 2.0 * _marginSize);
    return ret;
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
  final Size? size;
  final double? columnWidth;
  final bool isFixedHeight;
  final Point<double>? point;
  final SongMoment? songMoment;
  final bool? expanded;
  final bool? selectable;
  final bool rowHasReducedBeats;
  static final _emptyRichText = RichText(
    text: const TextSpan(text: ''),
  );
}

class _SongCellState extends State<_SongCellWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayMomentNotifier, LyricSectionNotifier>(
      builder: (context, playMomentNotifier, lyricSectionNotifier, child) {
        var moment = playMomentNotifier.playMoment?.songMoment;
        var playMomentNumber = playMomentNotifier.playMoment?.playMomentNumber;
        var isNowSelected = false;

        logger.log(
            _logLyricSectionCellState,
            '_SongCellState consumer build: momentNumber: ${widget.songMoment?.momentNumber} vs ${moment?.momentNumber}'
            ', widget.lyricSectionIndex: ${widget.lyricSectionIndex}');

        if ((widget.selectable ?? true) &&
            ((playMomentNotifier.playMoment?.songUpdateState == SongUpdateState.playing &&
                    (playMomentNotifier.playMoment?.playMomentNumber ?? -1) >= 0) //
                ||
                widget.lyricSectionIndex != null ||
                widget.lyricSectionSet != null)) {
          switch (widget.measureNode.runtimeType) {
            case const (LyricSection):
              isNowSelected = lyricSectionNotifier.lyricSectionIndex == widget.lyricSectionIndex;
              logger.log(
                  _logLyricSectionCellState,
                  '_SongCellState: $isNowSelected'
                  ', ${moment?.lyricSection} == ${widget.measureNode}'
                  //    ', songMoment: ${widget.songMoment} vs ${moment.momentNumber}'
                  );
              break;
            case const (ChordSection):
              isNowSelected = widget.lyricSectionSet?.contains(lyricSectionNotifier.lyricSectionIndex) ?? false;
              logger.log(
                  _logLyricSectionCellState,
                  '_SongCellState: ChordSection: $isNowSelected'
                  ', ${widget.measureNode}'
                  ', lyricSectionNotifier.index: ${lyricSectionNotifier.lyricSectionIndex}'
                  ', widget.lyricSectionIndex: ${widget.lyricSectionIndex}'
                  //    ', songMoment: ${widget.songMoment} vs ${moment.momentNumber}'
                  );
              break;
            default:
              isNowSelected = moment != null &&
                  (playMomentNumber == widget.songMoment?.momentNumber ||
                      (
                          //  deal with compressed repeats
                          !(widget.expanded ?? true) &&
                              moment.lyricSection == widget.songMoment?.lyricSection &&
                              moment.phraseIndex == widget.songMoment?.phraseIndex &&
                              moment.phrase.repeats > 1 &&
                              widget.songMoment?.measureIndex != null &&
                              (moment.measureIndex - widget.songMoment!.measureIndex) % moment.phrase.length == 0));
              logger.log(
                  _logLyricSectionCellState,
                  '_SongCellState: ${widget.measureNode.runtimeType}: $isNowSelected'
                  ', ${widget.measureNode}'
                  ', textScaler: ${widget.richText.textScaler}'
                  ', moment: ${widget.songMoment?.momentNumber}'
                  ', playMomentNumber: $playMomentNumber'
                  //
                  );
              break;
          }
        }

        switch (AppOptions().playerScrollHighlight) {
          case PlayerScrollHighlight.off:
          case PlayerScrollHighlight.chordRow:
            isNowSelected = false;
            break;
          case PlayerScrollHighlight.measure:
            break;
        }

        // // for efficiency, use the existing child
        // if (isNowSelected == selected && child != null) {
        //   return child;
        // }
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
          '_SongCellState.childBuilder: selected: ${widget.songMoment?.momentNumber}'
          ': ${widget.richText.text.toPlainText()}'
          ' dt: ${(AppAudioPlayer().getCurrentTime() - (SongMaster().songTime ?? 0)).toStringAsFixed(3)}'
          ', songTime: ${SongMaster().songTime}'
          //
          );

      //  check the delay
      //Future.delayed(Duration.zero, () => _checkTheAutoPlayDelay(context));
    }

    RichText richText = widget.richText;
    Size buildSize = widget.computedBuildSize;

    //  set width
    double width;
    switch (widget.type) {
      case SongCellType.columnMinimum:
        width = buildSize.width;
        break;
      default:
        width = widget.columnWidth ?? buildSize.width;
        break;
    }

    //  fixe height for banner only
    //  otherwise, allow the height to float
    double? height = widget.isFixedHeight ? (widget.size?.height ?? buildSize.height) : null;

    // if ((widget.size?.width ?? 0) < (widget.columnWidth ?? 0)) {
    //   //  put the narrow column width on the left of a container
    //   //  do the following row element is aligned in the next column
    //
    //   Color color;
    //   switch (widget.type) {
    //     case SongCellType.columnMinimum:
    //       color = Colors.transparent;
    //       break;
    //     default:
    //       color = widget.richText.text.style?.backgroundColor ?? Colors.transparent;
    //       break;
    //   }
    //
    //   return Container(
    //     alignment: Alignment.centerLeft,
    //     color: color,
    //     margin: _margin,
    //     width: width,
    //     height: height,
    //     padding: _padding,
    //     foregroundDecoration: //
    //         selected
    //             ? BoxDecoration(
    //                 border: Border.all(
    //                   width: _marginSize,
    //                   color: _idleHighlightColor,
    //                 ),
    //               )
    //             : null,
    //     child: richText,
    //   );
    // }

    Widget textWidget = richText;
    if (widget.measureNode?.measureNodeType == MeasureNodeType.measure && richText.text is TextSpan) {
      //  fixme: limit to odd length measures

      Measure measure = widget.measureNode! as Measure;

      //  see if all the beats total the normal beat count and that they are all equal
      bool showOddBeats = measure.requiresNashvilleBeats;

      // if (showOddBeats) {
      //   logger.i('showOddBeats: $measure');
      // }

      if (widget.rowHasReducedBeats) {
        //  make all measures the same height if any of them have explicit beats, i.e. dots added
        var measureTextSpan = richText.text as TextSpan;
        if (measureTextSpan.children != null &&
            measureTextSpan.children!.isNotEmpty &&
            measureTextSpan.children!.first is TextSpan) {
          var textSpan = measureTextSpan.children!.first as TextSpan;

          List<Widget> chordWidgets = [];
          int chordIndex = 0;
          for (var chordTextSpan in textSpan.children!) {
            if (textSpan.children!.length != measure.chords.length) {
              logger.i('break here');
            }
            if (chordTextSpan is TextSpan) {
              var chordRichText = RichText(text: chordTextSpan, textScaler: richText.textScaler);
              //  assumes text spans have been styled appropriately
              //  put beats on the top, Nashville style
              //  note that any odd beats in the row means all get extra vertical spacing
              Size beatsSize = _computeRichTextSize(chordRichText);
              chordWidgets.add(Column(children: [
                CustomPaint(
                  painter: showOddBeats ? _BeatMarkCustomPainter(measure.chords[chordIndex].beats) : null,
                  size: Size(
                      beatsSize.width,
                      richText.textScaler.scale(richText.text.style?.fontSize ?? 10) /
                          6), //  fixme: why is this needed?
                ),
                chordRichText,
              ]));
            } else {
              Text('not TextSpan: $chordTextSpan');
            }
            chordIndex++;
          }
          textWidget = AppWrap(children: chordWidgets);
        }
      }
    }

    return Container(
      alignment: Alignment.centerLeft,
      width: width,
      height: height,
      margin: _margin,
      padding: _padding,
      foregroundDecoration: //
          selected
              ? BoxDecoration(
                  border: Border.all(
                    width: _marginSize,
                    color: _idleHighlightColor,
                  ),
                )
              : null,
      color: widget.richText.text.style?.backgroundColor ?? Colors.transparent,
      child: textWidget,
    );
  }

  var selected = false; //  indicates the cell is currently selected, i.e. highlighted
}

class _BeatMarkCustomPainter extends CustomPainter {
  _BeatMarkCustomPainter(this.beats);

  @override
  void paint(final Canvas canvas, Size size) {
    final paint = Paint();
    paint.color = Colors.black;
    final double unit = size.height;
    final double space = unit / 2;
    final double start = size.width / 2 - (beats * (unit + space)) / 2; // unit + space per dot

    for (int i = 0; i < beats; i++) {
      double x = start + i * (unit + space);
      canvas.drawArc(Rect.fromLTWH(x, 0, unit, unit), 0, 2 * pi, true, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // TODO: implement shouldRepaint
    return true;
  }

  final int beats;
}
