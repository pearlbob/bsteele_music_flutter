import 'dart:collection';
import 'dart:math';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/grid.dart';
import 'package:bsteele_music_lib/grid_coordinate.dart';
import 'package:bsteele_music_lib/songs/chord_section.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/lyric.dart';
import 'package:bsteele_music_lib/songs/lyric_section.dart';
import 'package:bsteele_music_lib/songs/measure.dart';
import 'package:bsteele_music_lib/songs/measure_node.dart';
import 'package:bsteele_music_lib/songs/measure_repeat.dart';
import 'package:bsteele_music_lib/songs/measure_repeat_extension.dart';
import 'package:bsteele_music_lib/songs/measure_repeat_marker.dart';
import 'package:bsteele_music_lib/songs/nashville_note.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/section_version.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_base.dart';
import 'package:bsteele_music_lib/songs/song_moment.dart';
import 'package:bsteele_music_lib/songs/song_update.dart';
import 'package:bsteele_music_lib/util/app_util.dart';
import 'package:bsteele_music_lib/util/us_timer.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

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
const Level _logLyricSectionIndicatorCellState = Level.debug;
const Level _logLyricSectionIndicatorCellStateChild = Level.debug;
const Level _logLyricsBuild = Level.debug;
const Level _logLocationGrid = Level.debug;
const Level _logHeights = Level.debug;
const Level _logLyricSectionHeights = Level.debug;
const Level _logLyricsTableItems = Level.debug;
const Level _logLyricsTableItemDisplayOffsets = Level.debug;
const Level _logLyricSectionNotifier = Level.debug;
// const Level _logSongCellStateBuild = Level.debug;
const Level _logSongCellOffsetList = Level.debug;
const Level _logChildBuilder = Level.debug;
const Level _logSelectedCellState = Level.debug;
const Level _logPlayMoment = Level.debug;
const Level _logDisplayGrid = Level.debug;

const double _paddingSizeDefault = 6;
double _paddingSizeMax = _paddingSizeDefault;
double _paddingSize = _paddingSizeDefault;
EdgeInsets _padding = const EdgeInsets.all(_paddingSizeDefault);
const double _marginSizeDefault = 6;
double _marginSizeMax = _marginSizeDefault; //  note: vertical and horizontal are identical
double _marginSize = _marginSizeDefault;
EdgeInsets _margin = const EdgeInsets.all(_marginSizeDefault);
const _idleHighlightColor = Colors.redAccent;
const _playHighlightColor = Colors.greenAccent;
const _defaultMaxLines = 20;
var _maxLines = _defaultMaxLines;
const int _maxMomentNumber = 99999; //  many more than expected

///  The trick of the game: Figure the text size prior to boxing it
Size _computeRichTextSize(final RichText richText, {int? maxLines, double? maxWidth}) {
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
  return _computeInlineSpanSize(
    richText.text,
    textScaler: richText.textScaler,
    maxLines: maxLines ?? _maxLines,
    maxWidth: maxWidth,
  );
}

Size _computeInlineSpanSize(final InlineSpan inLineSpan, {TextScaler? textScaler, int? maxLines, double? maxWidth}) {
  TextPainter textPainter = TextPainter(
    text: inLineSpan,
    textDirection: TextDirection.ltr,
    maxLines: maxLines ?? _maxLines,
    textScaler: textScaler ?? TextScaler.noScaling,
  )..layout(maxWidth: maxWidth ?? app.screenInfo.mediaWidth);
  Size ret = textPainter.size;
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
    return 'PlayMoment{state: ${songUpdateState.name}, number: $playMomentNumber, songMoment: $songMoment}';
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
      logger.log(_logPlayMoment, 'playMoment: $_playMoment');
      notifyListeners();
    }
  }

  @override
  bool operator ==(Object other) {
    return other is PlayMomentNotifier && _playMoment == other._playMoment;
  }

  @override
  int get hashCode {
    return _playMoment?.hashCode ?? 0;
  }

  PlayMoment? get playMoment => _playMoment;
  PlayMoment? _playMoment;
}

class SongMasterNotifier extends ChangeNotifier {
  set songMaster(final SongMaster? songMaster) {
    //  note: no change optimization required due to singleton
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
  List<Widget> lyricsTableItems(Song song, {music_key.Key? musicKey, double initialHeightOffset = 100}) {
    var usTimer = UsTimer();
    _song = song;
    displayMusicKey = musicKey ?? song.key;
    _nashvilleSelection = appOptions.nashvilleSelection;
    _simplifiedChordsSelection = appOptions.simplifiedChords;
    _maxLines = _defaultMaxLines;

    _paddingSizeMax = _paddingSizeDefault;
    _marginSizeMax = _marginSizeDefault;
    _computeScreenSizes();

    var displayGrid = song.toDisplayGrid(appOptions.userDisplayStyle);
    logger.log(_logLyricsBuild, 'lyricsBuild: displayGrid: ${usTimer.deltaToString()}');

    _cellGrid = Grid<_SongCellWidget>();

    //  compute transposition offset from base key

    displayMusicKey = musicKey ?? song.key;
    int transpositionOffset = displayMusicKey.getHalfStep() - song.key.getHalfStep();

    switch (appOptions.userDisplayStyle) {
      case .proPlayer:
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
                _cellGrid.set(
                  r,
                  c,
                  _SongCellWidget(
                    richText: RichText(
                      text: TextSpan(
                        text: chordSection.sectionVersion.toString().replaceAll(':', ''),
                        style: _coloredChordTextStyle,
                      ),
                    ),
                    row: r,
                    column: c,
                    type: _SongCellType.flow,
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
                _cellGrid.set(
                  r,
                  c,
                  _SongCellWidget(
                    richText: RichText(
                      text: TextSpan(text: chordSection.sectionVersion.toString(), style: _coloredChordTextStyle),
                    ),
                    row: r,
                    column: c,
                    type: _SongCellType.columnFill,
                    measureNode: chordSection,
                    lyricSectionSet: set,
                  ),
                );
                break;
              case 1:
                _cellGrid.set(
                  r,
                  c,
                  _SongCellWidget(
                    richText: RichText(text: _chordSectionTextSpan(chordSection, song.key, transpositionOffset)),
                    row: r,
                    column: c,
                    type: _SongCellType.columnMinimum,
                    measureNode: chordSection,
                    lyricSectionSet: set,
                    rowHasExplicitBeats: rowHasReducedBeats,
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

      case .singer:
        for (var r = 0; r < displayGrid.getRowCount(); r++) {
          var row = displayGrid.getRow(r);
          assert(row != null);
          row = row!;

          for (var c = 0; c < row.length; c++) {
            MeasureNode? mn = displayGrid.get(r, c);
            switch (c) {
              case 0:
                if (mn?.measureNodeType == .lyricSection) {
                  //  show the section version
                  var lyricSection = mn as LyricSection;
                  ChordSection? chordSection = song.findChordSectionByLyricSection(lyricSection);
                  if (chordSection != null) {
                    _colorBySectionVersion(chordSection.sectionVersion);
                    _cellGrid.set(
                      r,
                      c,
                      _SongCellWidget(
                        richText: RichText(
                          text: TextSpan(text: chordSection.sectionVersion.toString(), style: _coloredChordTextStyle),
                        ),
                        row: r,
                        column: c,
                        type: _SongCellType.columnMinimum,
                        measureNode: lyricSection,
                        lyricSectionIndex: lyricSection.index,
                      ),
                    );
                  } else {
                    assert(false);
                  }
                } else if (mn?.measureNodeType == .section) {
                  ChordSection chordSection = mn as ChordSection;
                  _colorBySectionVersion(chordSection.sectionVersion);
                  _cellGrid.set(
                    r,
                    c,
                    _SongCellWidget(
                      richText: RichText(
                        text: TextSpan(text: chordSection.sectionVersion.toString(), style: _coloredChordTextStyle),
                      ),
                      row: r,
                      column: c,
                      type: _SongCellType.columnMinimum,
                      measureNode: chordSection,
                    ),
                  );
                } else {
                  assert(mn == null);
                }
                break;

              case 1:
                if (mn?.measureNodeType == .section) {
                  //   show the chords
                  ChordSection chordSection = mn as ChordSection;
                  _colorBySectionVersion(chordSection.sectionVersion);
                  _cellGrid.set(
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
                      row: r,
                      column: c,
                      type: _SongCellType.columnMinimum,
                      measureNode: chordSection,
                      selectable: false,
                    ),
                  );
                } else if (mn is Lyric) {
                  //  color done by prior chord section
                  _cellGrid.set(
                    r,
                    c,
                    _SongCellWidget(
                      richText: RichText(
                        text: TextSpan(text: mn.toMarkup(), style: _coloredLyricTextStyle),
                      ),
                      row: r,
                      column: c,
                      type: _SongCellType.columnFill,
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

      case .banner:
        for (var momentNumber = 0; momentNumber < song.songMoments.length; momentNumber++) {
          for (var banner in BannerColumn.values) {
            //  color by chord section
            var chordSection = displayGrid.get(BannerColumn.chordSections.index, momentNumber);
            if (chordSection is ChordSection) {
              _colorBySectionVersion(chordSection.sectionVersion);
            }

            MeasureNode? mn = displayGrid.get(banner.index, momentNumber);
            switch (banner) {
              case .chordSections:
                var chordSection = mn is ChordSection ? mn : null;
                _cellGrid.set(
                  banner.index,
                  momentNumber,
                  chordSection == null
                      ? _SongCellWidget._empty(isFixedHeight: true, row: 0, column: momentNumber)
                      : _SongCellWidget(
                          richText: RichText(
                            text: TextSpan(text: chordSection.sectionVersion.toString(), style: _coloredChordTextStyle),
                          ),
                          row: 0,
                          column: momentNumber,
                          type: _SongCellType.columnMinimum,
                          measureNode: mn,
                          isFixedHeight: true,
                        ),
                );
                break;
              case .repeats:
                var marker = mn is MeasureRepeatMarker ? mn : null;
                _cellGrid.set(
                  banner.index,
                  momentNumber,
                  marker == null
                      ? _SongCellWidget._empty(isFixedHeight: true, row: 0, column: momentNumber)
                      : _SongCellWidget(
                          richText: RichText(
                            text: TextSpan(
                              text: 'x${(marker.repetition ?? 0) + 1}/${marker.repeats}',
                              style: _coloredLyricTextStyle,
                            ),
                          ),
                          row: 0,
                          column: momentNumber,
                          type: _SongCellType.columnMinimum,
                          measureNode: mn,
                          isFixedHeight: true,
                        ),
                );
                break;
              case .lyrics:
                var lyric = mn is Lyric ? mn : null;
                _cellGrid.set(
                  banner.index,
                  momentNumber,
                  lyric == null
                      ? _SongCellWidget._empty(row: 0, column: momentNumber)
                      : _SongCellWidget(
                          richText: RichText(
                            text: TextSpan(text: lyric.toMarkup(), style: _coloredLyricTextStyle),
                          ),
                          row: 0,
                          column: momentNumber,
                          type: _SongCellType.columnFill,
                          measureNode: mn,
                          isFixedHeight: true,
                        ),
                );
                break;
              default:
                _cellGrid.set(
                  banner.index,
                  momentNumber,
                  mn == null
                      ? _SongCellWidget._empty(row: 0, column: momentNumber)
                      : _SongCellWidget(
                          richText: RichText(
                            text: TextSpan(text: mn.toString(), style: _coloredChordTextStyle),
                          ),
                          row: 0,
                          column: momentNumber,
                          type: _SongCellType.columnFill,
                          measureNode: mn,
                          isFixedHeight: true,
                        ),
                );
                break;
            }
          }
        }
        break;

      case .highContrast:
        _paddingSizeMax = 18;
        _marginSizeMax = 5;
        _computeScreenSizes();

        for (var r = 0; r < displayGrid.getRowCount(); r++) {
          List<MeasureNode?>? row = displayGrid.getRow(r);
          assert(row != null);
          row = row!;

          for (var c = 0; c < row.length; c++) {
            MeasureNode? mn = displayGrid.get(r, c);
            if (mn == null) {
              _cellGrid.set(r, c, _SongCellWidget._empty(row: r, column: c));
            } else if (mn.measureNodeType == .lyricSection) {
              _cellGrid.set(
                r,
                c,
                _SongCellWidget(
                  richText: RichText(
                    text: TextSpan(
                      text: '${(mn as LyricSection).sectionVersion}',
                      //  '${(Logger.level.index <= _logSongCellOffsetList.index ? r : '')}'
                      style: _highContrastTextStyle,
                    ),
                  ),
                  row: r,
                  column: c,
                  type: _SongCellType.columnFill,
                  measureNode: mn,
                  alignment: .center,
                ),
              );
            } else {
              _cellGrid.set(
                r,
                c,
                _SongCellWidget(
                  richText: RichText(
                    text: _measureNashvilleSelectionTextSpan(
                      mn as Measure,
                      song.key,
                      transpositionOffset,
                      style: _highContrastTextStyle,
                      displayMusicKey: displayMusicKey,
                      showBeats: Measure.reducedNashvilleDots,
                      withInversion: false,
                    ),
                  ),
                  row: r,
                  column: c,
                  type: _SongCellType.columnFill,
                  measureNode: mn,
                  alignment: .center,
                ),
              );
            }
          }
        }

        //  map the song moments to the cell grid
        for (var songMoment in song.songMoments) {
          var momentNumber = songMoment.momentNumber;
          GridCoordinate gc = song.songMomentToGridCoordinate[momentNumber];
          var cell = _cellGrid.at(gc);
          assert(cell != null);
          cell = cell!;

          _cellGrid.setAt(gc, cell.copyWith(songMoment: songMoment));
        }
        break;

      case .player:
      case .both:
        {
          LyricSection? lyricSection;
          for (var r = 0; r < displayGrid.getRowCount(); r++) {
            List<MeasureNode?>? row = displayGrid.getRow(r);
            assert(row != null);
            row = row!;

            //  see if the row has reduced beats
            bool rowHasExplicitBeats = _rowHasExplicitBeats(row);

            for (var c = 0; c < row.length; c++) {
              MeasureNode? measureNode = displayGrid.get(r, c);
              if (measureNode == null) {
                continue;
              }
              switch (measureNode.measureNodeType) {
                case .lyricSection:
                  lyricSection = measureNode as LyricSection;
                  _displayChordSection(
                    GridCoordinate(r, c),
                    song.findChordSectionByLyricSection(lyricSection)!,
                    measureNode,
                    selectable: false,
                    lyricSectionIndex: lyricSection.index,
                  );
                  break;
                //
                case .section:
                  _displayChordSection(
                    GridCoordinate(r, c),
                    measureNode as ChordSection,
                    measureNode,
                    lyricSectionIndex: lyricSection?.index,
                  );
                  break;
                //
                case .lyric:
                  //  color done by prior chord section
                  {
                    var songCellType = appOptions.userDisplayStyle == .both
                        ? _SongCellType.lyric
                        : _SongCellType.lyricEllipsis;
                    _cellGrid.set(
                      r,
                      c,
                      _SongCellWidget(
                        richText: RichText(
                          text: TextSpan(text: measureNode.toMarkup().trim(), style: _coloredLyricTextStyle),
                          maxLines: songCellType == _SongCellType.lyricEllipsis ? 1 : _maxLines,
                        ),
                        row: r,
                        column: c,
                        type: songCellType,
                        measureNode: measureNode,
                        lyricSectionIndex: lyricSection?.index,
                      ),
                    );
                  }
                  break;
                //
                case .measure:
                  //  color done by prior chord section
                  {
                    Measure measure = measureNode as Measure;
                    RichText richText = RichText(
                      text: TextSpan(
                        text: '($r,$c)', //  diagnostic only!
                        style: _lyricsTextStyle,
                      ),
                    );
                    //
                    switch (measure.runtimeType) {
                      case const (MeasureRepeatExtension):
                        richText = RichText(
                          text: TextSpan(
                            text: measure.toString(),
                            style: _coloredChordTextStyle.copyWith(
                              fontFamily: appFontFamily,
                              fontWeight: .bold,
                            ), //  fixme: a font failure workaround
                          ),
                        );
                        break;
                      case const (MeasureRepeatMarker): //  fixme: this should not be possible
                        //  the repeat marker has a MeasureNodeType of decoration!
                        assert(false);
                        richText = RichText(
                          text: TextSpan(text: measure.toString(), style: _coloredChordTextStyle),
                          //  don't allow the rich text to wrap:
                          textWidthBasis: TextWidthBasis.longestLine,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          textHeightBehavior: const TextHeightBehavior(),
                        );
                        break;
                      case const (Measure):
                        richText = RichText(
                          text: _measureNashvilleSelectionTextSpan(
                            measure,
                            song.key,
                            transpositionOffset,
                            style: _coloredChordTextStyle,
                            displayMusicKey: displayMusicKey,
                            showBeats: Measure.reducedNashvilleDots,
                          ),
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

                    _cellGrid.set(
                      r,
                      c,
                      _SongCellWidget(
                        richText: richText,
                        row: r,
                        column: c,
                        type: _SongCellType.columnFill,
                        measureNode: measureNode,
                        lyricSectionIndex: lyricSection?.index,
                        rowHasExplicitBeats: rowHasExplicitBeats,
                      ),
                    );
                  }
                  break;

                default:
                  //  color done by prior chord section
                  // logger.i(
                  //     'default measureNodeType: r=$r, c=$c, ${measureNode.runtimeType}  ${measureNode.measureNodeType}');
                  _cellGrid.set(
                    r,
                    c,
                    _SongCellWidget(
                      richText: RichText(
                        text: TextSpan(text: measureNode.toMarkup(), style: _coloredChordTextStyle),
                      ),
                      row: r,
                      column: c,
                      type: _SongCellType.columnFill,
                      measureNode: measureNode,
                      lyricSectionIndex: lyricSection?.index,
                      rowHasExplicitBeats: rowHasExplicitBeats,
                    ),
                  );
                  break;
              }
            }
          }

          //  compute the moment min/max moment number restriction if it's a repeat
          {
            //  look ahead for the measure repeat markers that carry the repetition limits
            //  (i.e. the last repetition for this repeat cycle)
            HashMap<GridCoordinate, MeasureRepeatMarker> measureRepeatMarkerMap = HashMap();
            _cellGrid.foreach((r, c, cell) {
              if (cell.measureNode?.measureNodeType == .measureRepeatMarker) {
                GridCoordinate gridCoordinate = GridCoordinate(r, c);
                var measureRepeatMarker = cell.measureNode as MeasureRepeatMarker;
                measureRepeatMarkerMap[gridCoordinate] = measureRepeatMarker;
              }
            });
            var measureRepeatMarkerMapKeys = SplayTreeSet<GridCoordinate>()..addAll(measureRepeatMarkerMap.keys);
            for (var gc in measureRepeatMarkerMapKeys) {
              MeasureRepeatMarker? measureRepeatMarker = measureRepeatMarkerMap[gc];
              logger.log(_logDisplayGrid, 'test: (${gc.row},${gc.col}):  ${measureRepeatMarker?.toDebugString()}');
            }

            int? initialMomentNumber;
            int? firstMomentNumber;
            for (var songMoment in song.songMoments) {
              var momentNumber = songMoment.momentNumber;
              GridCoordinate gc = song.songMomentToGridCoordinate[momentNumber];
              var cell = _cellGrid.at(gc);
              assert(cell != null);
              cell = cell!;

              if (songMoment.phrase is MeasureRepeat) {
                //  find the matching measure repeat marker
                late MeasureRepeatMarker measureRepeatMarker;
                late GridCoordinate keyGc;
                try {
                  keyGc = measureRepeatMarkerMapKeys.firstWhere((keyGc) {
                    return gc.compareTo(keyGc) <= 0;
                  });

                  // logger.log(_logDisplayGrid, 'found: (${gc.row},${gc.col}):  $keyGc:  ');
                  measureRepeatMarker = measureRepeatMarkerMap[keyGc]!;
                } catch (e) {
                  logger.log(_logDisplayGrid, 'NOT found: (${gc.row},${gc.col}): $e');
                  assert(false);
                  continue;
                }

                // logger.i(
                //   '  repeat @${songMoment.momentNumber}:  '
                //   'first: ${songMoment.chordSectionSongMomentNumber} + ${songMoment.phrase.length}'
                //   ' * ${songMoment.repeat} of ${songMoment.repeatMax}'
                //   ' = ${songMoment.chordSectionSongMomentNumber + songMoment.phrase.length * songMoment.repeat}',
                // );

                initialMomentNumber ??= momentNumber;
                firstMomentNumber ??= momentNumber;

                int lastMomentNumber =
                    initialMomentNumber +
                    measureRepeatMarker.measuresPerRepeat * (measureRepeatMarker.lastRepetition ?? 1);

                var first = firstMomentNumber; //  safety
                var last = lastMomentNumber;

                assert(measureRepeatMarker.repeats > 1);
                if (measureRepeatMarker.lastRepetition == 1) {
                  //  first with following repetitions
                  first = 0;
                } else if ((measureRepeatMarker.repetition ?? 0) > 1 &&
                    (measureRepeatMarker.lastRepetition ?? measureRepeatMarker.repeats) < measureRepeatMarker.repeats) {
                  //  in the middle with following repetitions
                  first = firstMomentNumber;
                } else if ((measureRepeatMarker.repetition ?? 0) == 1 &&
                    (measureRepeatMarker.lastRepetition ?? 0) == measureRepeatMarker.repeats) {
                  //  all repetitions are in one repeat repetition
                  first = 0;
                  last = song.songMoments.length;
                } else if ((measureRepeatMarker.lastRepetition ?? 0) == measureRepeatMarker.repeats) {
                  //  last repetition
                  last = song.songMoments.length;
                }

                logger.log(
                  _logDisplayGrid,
                  'found: (${gc.row},${gc.col}):  ${measureRepeatMarker.toDebugString()}'
                  ', first: $first, last: $last',
                );

                _cellGrid.setAt(
                  gc,
                  cell.copyWith(songMoment: songMoment, firstMomentNumber: first, lastMomentNumber: last),
                );
                if (momentNumber >=
                    initialMomentNumber + measureRepeatMarker.measuresPerRepeat * measureRepeatMarker.repeats - 1) {
                  initialMomentNumber = null;
                  firstMomentNumber = null;
                } else if (momentNumber >= lastMomentNumber - 1) {
                  firstMomentNumber = null;
                }
              } else {
                //  always show non-repeat moments
                _cellGrid.setAt(
                  gc,
                  cell.copyWith(
                    songMoment: songMoment,
                    firstMomentNumber: 0,
                    lastMomentNumber: song.songMoments.length,
                  ),
                ); //  fixme: overkill?
                firstMomentNumber = null;
              }
            }
          }

          //  spread the repeat min/max row to the repeat measures and extensions
          SongMoment? lastSongMoment;
          for (var r = 0; r < displayGrid.getRowCount(); r++) {
            List<MeasureNode?>? row = displayGrid.getRow(r);
            assert(row != null);
            row = row!;
            var firstMomentNumber = 0;
            var lastMomentNumber = song.songMoments.length;

            for (var c = 0; c < row.length; c++) {
              MeasureNode? measureNode = displayGrid.get(r, c);
              if (measureNode == null) {
                continue;
              }

              //  deal with multiple rows of a single repeat
              switch (measureNode.measureNodeType) {
                case .measure:
                  var cell = _cellGrid.get(r, c);
                  cell = cell!;
                  lastSongMoment = cell.songMoment;
                  //  load the repeat min/max from the measure
                  //  note that this is done for non-repeat phrases which is unnecessary but otherwise harmless
                  firstMomentNumber = cell.firstMomentNumber ?? firstMomentNumber;
                  lastMomentNumber = cell.lastMomentNumber ?? lastMomentNumber;
                  break;

                case .measureRepeatMarker:
                case .decoration:
                  var cell = _cellGrid.get(r, c);
                  cell = cell!;
                  _cellGrid.set(
                    r,
                    c,
                    cell.copyWith(
                      firstMomentNumber: firstMomentNumber,
                      lastMomentNumber: lastMomentNumber,
                      songMoment: lastSongMoment,
                    ),
                  );
                  break;
                default:
                  //  all others should have all inclusive min/max.
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
        var cell = _cellGrid.get(r, c);
        if (cell == null) {
          continue; //  for example, first column in lyrics for singer display style
        }

        switch (cell.type) {
          case .flow:
          case .lyricEllipsis:
            break;
          default:
            widths[c] = max(widths[c], cell.buildSize.width);
            break;
        }

        heights[r] = max(heights[r], cell.buildSize.height);
      }
    }
    logger.log(_logHeights, 'raw heights: $heights');

    switch (appOptions.userDisplayStyle) {
      case .banner:
        //  even up the banner width's
        var width = 0.0;
        var r = BannerColumn.chords.index;
        var row = _cellGrid.getRow(r);
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
            var cell = _cellGrid.get(r, c);
            if (cell != null) {
              _cellGrid.set(r, c, cell.copyWith(columnWidth: width));
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
            var cell = _cellGrid.get(r, c);
            if (cell != null) {
              height = max(height, cell.computedBuildSize.height);
              logger.log(
                _logHeights,
                'banner computedBuildSize: ${cell.computedBuildSize}'
                ', columnWidth: ${cell.columnWidth}',
              );
            }
          }
          logger.log(_logHeights, 'banner new height: $height');

          //  apply the new height
          heights[r] = height;
          for (var c = 0; c < row.length - 1 /*  exclude the copyright*/; c++) {
            var cell = _cellGrid.get(r, c);
            if (cell != null) {
              _cellGrid.set(r, c, cell.copyWith(size: Size(cell.buildSize.width, height)));
            }
          }
        }

        logger.log(_logHeights, 'banner widths: $widths');
        logger.log(_logHeights, 'banner heights: $heights');
        break;

      case .highContrast:
        {
          //  find the largest width
          for (int r = 0; r < _cellGrid.getRowCount(); r++) {
            var row = _cellGrid.getRow(r);
            assert(row != null);
            row = row!;

            for (var c = 0; c < row.length; c++) {
              var cell = row[c];
              if (cell != null) {
                widths[c] = max(widths[c], cell.buildSize.width);
              }
            }
          }

          //  re-compute max lyric height after width change
          double height = app.screenInfo.fontSize; //  safety
          for (int r = 0; r < _cellGrid.getRowCount(); r++) {
            var row = _cellGrid.getRow(r);
            assert(row != null);
            row = row!;

            for (var c = 0; c < row.length; c++) {
              var cell = _cellGrid.get(r, c);
              if (cell != null) {
                height = max(height, cell.computedBuildSize.height);
                logger.log(
                  _logHeights,
                  'highContrast computedBuildSize: ${cell.computedBuildSize}'
                  ', columnWidth: ${cell.columnWidth}',
                );
              }
            }
            logger.log(_logHeights, 'highContrast new height: $height');

            //  apply the new height at all
            heights[0] = height;
            for (int r = 0; r < _cellGrid.getRowCount(); r++) {
              var row = _cellGrid.getRow(r);
              assert(row != null);
              row = row!;

              for (var c = 0; c < row.length; c++) {
                var cell = _cellGrid.get(r, c);
                if (cell != null) {
                  _cellGrid.set(r, c, cell.copyWith(size: Size(cell.buildSize.width, height), columnWidth: widths[c]));
                }
              }
            }
          }
        }

        logger.log(_logHeights, 'highContrast widths: $widths');
        logger.log(_logHeights, 'highContrast heights: $heights');
        break;
      default:
        break;
    }

    //  discover the overall total width and height
    double arrowIndicatorWidth = appOptions.playWithLineIndicator ? _chordFontSizeUnscaled : 0;
    var totalWidth = widths.fold<double>(
      arrowIndicatorWidth,
      (previous, e) => previous + e + _paddingSize + 2 * _marginSize,
    );
    var chordWidth = totalWidth - widths.last;
    logger.log(_logFontSize, 'chord ratio: $chordWidth/$totalWidth = ${chordWidth / totalWidth}');

    //  limit space for player lyrics
    if (appOptions.userDisplayStyle == .player && widths.last == 0) {
      widths.last = max(0.3 * totalWidth, 0.97 * (screenWidth - totalWidth));
      totalWidth = chordWidth + widths.last;
    } else if (appOptions.userDisplayStyle == .both) {
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
      ', padding: ${_paddingSize.toStringAsFixed(2)}',
    );
    var totalHeight = heights.fold<double>(0.0, (previous, e) => previous + e + 2.0 * _marginSize);

    assert(totalWidth > 0);
    assert(totalHeight > 0);

    switch (appOptions.userDisplayStyle) {
      case .banner:
        _scaleFactor = 0.65;
        break;
      default:
        //  fit the horizontal by scaling
        _scaleFactor = 0.98 * screenWidth / totalWidth;
        break;
    }

    _scaleFactor *= 0.84;
    logger.log(_logFontSize, 'post  correction: $_scaleFactor');

    switch (appOptions.userDisplayStyle) {
      case .proPlayer:
        //  fit everything vertically
        // logger.log(_logFontSize, 'proPlayer: _scaleFactor: $_scaleFactor vs ${screenHeight * 0.65 / totalHeight}');
        {
          var oldScaleFactor = _scaleFactor;
          _scaleFactor = min(
            _scaleFactor,
            screenHeight *
                0.65 //  fixme: this is only close, empirically
                /
                totalHeight,
          );
          widths[1] = screenWidth * oldScaleFactor / _scaleFactor; //  fixme: a nasty hack
        }
        break;
      default:
        break;
    }
    _scaleFactor = min(_scaleFactor, 1.0);

    logger.log(_logFontSize, '_scaleFactor: $_scaleFactor, ${app.screenInfo.fontSize}');
    logger.log(
      _logFontSizeDetail,
      'totalWidth: $totalWidth, totalHeight: $totalHeight, screenWidth: $screenWidth'
      ', scaled width: ${totalWidth * _scaleFactor}',
    );

    //  adjust for vertical scale constraints
    switch (appOptions.userDisplayStyle) {
      case .both:
      case .player:
        {
          //  try:
          //  I Love Rock 'n' Roll by Arrows, cover by Joan Jett & the Blackhearts: max lyric length: 16
          //  Rockstar by Nickelback: max lyric length: 12  C3:
          //  Hey Hey What Can I Do by Led Zeppelin: max lyric length: 11  outro
          //  I Wanna Be Like You by Christopher Walken: max lyric length: 35
          //  Rock & Roll by Velvet Underground, The: max lyric length: 23  outro

          //  assume that most of the media height is available
          const maxHeightFraction = 0.8;
          //  fixme: only approximate!
          final double maxHeight = maxHeightFraction * (app.screenInfo.mediaHeight - kToolbarHeight);

          logger.log(
            _logLyricSectionHeights,
            'app.screenInfo: _scaleFactor: ${to3(_scaleFactor)}, mediaHeight: ${app.screenInfo.mediaHeight}',
          );
          double lyricSectionHeight = 0;
          double maxLyricSectionHeight = 0;
          LyricSection? lyricSection;
          for (var r = 0; r < displayGrid.getRowCount(); r++) {
            var row = displayGrid.getRow(r);
            assert(row != null);
            row = row!;

            for (var c = 0; c < row.length; c++) {
              var mn = displayGrid.get(r, c);
              switch (mn?.measureNodeType) {
                case .lyricSection:
                  if (lyricSection != null) {
                    maxLyricSectionHeight = max(maxLyricSectionHeight, lyricSectionHeight);
                    logger.log(
                      _logLyricSectionHeights,
                      'last lyricSection: $lyricSection'
                      ', ends at row: $r, lyricSectionHeight: $lyricSectionHeight/$maxHeight',
                    );
                    lyricSectionHeight = 0;
                  }
                  lyricSection = mn as LyricSection;
                  logger.log(
                    _logLyricSectionHeights,
                    'lyricSection: $mn: ${lyricSection.lyricsLines.length}'
                    ', row: $r',
                  );
                default:
                  break;
              }
            }

            lyricSectionHeight += heights[r];
          }
          //  last section
          if (lyricSection != null) {
            maxLyricSectionHeight = max(maxLyricSectionHeight, lyricSectionHeight);
          }

          //  limit height
          if (maxLyricSectionHeight > 0) {
            double hScaleFactor =  maxHeight / maxLyricSectionHeight;
            logger.log(
              _logLyricSectionHeights,
              'maxLyricSectionHeight: $maxLyricSectionHeight/$maxHeight'
              ', hScaleFactor: ${to3(hScaleFactor)}'
              ', _scaleFactor: $_scaleFactor',
            );
            _scaleFactor = min(_scaleFactor, hScaleFactor);
          }
          logger.log(_logFontSize, 'post height reduction: _scaleFactor: $_scaleFactor');
        }
        break;
      default:
        break;
    }

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
      _unusedMargin = max(0, (screenWidth - widthSum) / 2);
      // logger.log(_logFontSize,
      //     'screenWidth: $screenWidth, widthSum: $widthSum, _scaleFactor: $_scaleFactor, _unusedMargin: $_unusedMargin');

      //  reset the heights to scale
      for (var i = 0; i < heights.length; i++) {
        heights[i] = heights[i] * _scaleFactor;
      }
    } else {
      _unusedMargin = max(0, (screenWidth - totalWidth) / 2);
      // logger.log(_logFontSize,
      //     'screenWidth: $screenWidth, totalWidth: $totalWidth, _scaleFactor: $_scaleFactor, _unusedMargin: $_unusedMargin');
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
        ', padding: ${_paddingSize.toStringAsFixed(2)}',
      );
    }
    _maxLines = appOptions.userDisplayStyle == .player ? 1 : _defaultMaxLines;

    //  set the cell grid sizing
    final double xMargin = 2.0 * _marginSize;
    {
      for (var r = 0; r < _cellGrid.getRowCount(); r++) {
        var row = _cellGrid.getRow(r);
        assert(row != null);
        row = row!;

        for (var c = 0; c < row.length; c++) {
          var cell = _cellGrid.get(r, c);
          if (cell != null) {
            double? width;
            switch (cell.type) {
              case .flow:
                break;
              default:
                width = widths[c];
                break;
            }

            cell = cell.copyWith(textScaleFactor: _scaleFactor, columnWidth: width);
            _cellGrid.set(r, c, cell);
            // logger.log(_logHeights,
            //     'heights: r:$r, ${heights[r].toStringAsFixed(1)} vs ${cell.buildSize.height.toStringAsFixed(1)}');
            heights[r] = max(heights[r], cell.buildSize.height);
          }
        }
      }
      logger.log(_logHeights, 'heights: ${heights.join(', ')}');
      logger.log(
        _logHeights,
        'totalHeights: ${heights.reduce((acc, value) {
          return acc + value;
        })}'
        ', _scaleFactor: $_scaleFactor',
      );
    }

    logger.log(_logLyricsBuild, 'lyricsBuild: scaling: ${usTimer.deltaToString()}');

    List<Widget> items = [];

    //  map from song moment to cell grid
    for (var songMoment in song.songMoments) {
      var gc = song.songMomentToGridCoordinate[songMoment.momentNumber];
      //  notice that the last moment at the grid cell overwrites prior moments in a non-expanded repeat row
      assert(_cellGrid.at(gc) != null);
      _cellGrid.setAt(gc, _cellGrid.at(gc)?.copyWith(songMoment: songMoment));
      logger.log(_logLocationGrid, '_logLocationGrid[$gc] = $songMoment');
    }
    logger.log(_logLyricsBuild, 'lyricsBuild: songMoment mapping: ${usTimer.deltaToString()}');

    //  box up the children, applying necessary widths and heights
    switch (appOptions.userDisplayStyle) {
      case .banner:
        {
          for (var c = 0; c < song.songMoments.length; c++) {
            List<_SongCellWidget> columnChildren = [];
            for (var r = 0; r < BannerColumn.values.length; r++) {
              var cell = _cellGrid.get(r, c);
              assert(cell != null);
              columnChildren.add(cell!.copyWith(size: Size(widths[c], heights[r])));
            }
            Widget columnWidget = Column(crossAxisAlignment: .start, children: columnChildren);
            logger.t('banner columnChildren: ${columnChildren.map((c) => c.size)}');
            items.add(columnWidget);
          }
        }
        logger.log(_logHeights, 'banner scaled heights: $heights');

        for (var c = 0; c < song.songMoments.length; c++) {
          for (var r = 0; r < BannerColumn.values.length; r++) {
            var cell = _cellGrid.get(r, c);
            // logger.i( 'banner cell: ($r,$c): $cell');
            assert(cell != null);
            // if (cell != null) {}
          }
        }
        break;

      case .highContrast:
        {
          for (int r = 0; r < _cellGrid.getRowCount(); r++) {
            var row = _cellGrid.getRow(r);
            assert(row != null);
            row = row!;

            List<Widget> rowChildren = [];
            for (var c = 0; c < row.length; c++) {
              var cell = _cellGrid.get(r, c);
              if (cell != null) {
                rowChildren.add(cell.copyWith(size: Size(widths[c], heights[0])));
              }
            }
            items.add(
              Column(
                crossAxisAlignment: .start,
                children: [Wrap(children: rowChildren)],
              ),
            );
          }
        }
        logger.log(_logHeights, 'highContrast scaled heights: $heights');
        break;

      //  other user display styles
      default:
        {
          List<Widget> sectionChildren = [];
          LyricSection? lastLyricSection;
          for (var r = 0; r < _cellGrid.getRowCount(); r++) {
            var row = _cellGrid.getRow(r);
            assert(row != null);
            row = row!;

            LyricSection? lyricSection = lastLyricSection;

            List<Widget> rowChildren = [];
            for (var c = 0; c < row.length; c++) {
              Widget child;
              var cell = _cellGrid.get(r, c);
              if (cell == null) {
                child = AppSpace(horizontalSpace: widths[c] + xMargin);
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
              if (r == 0 && appOptions.userDisplayStyle == .proPlayer) {
                //  put the first row of pro in a wrap
                rowWidget = AppWrap(
                  children: [
                    AppSpace(horizontalSpace: arrowIndicatorWidth * _scaleFactor),
                    ...rowChildren,
                  ],
                );
              } else if (arrowIndicatorWidth > 0) {
                // add a row indicator if required

                //  find the first moment number
                int? momentNumber;
                for (var c = 0; c < row.length; c++) {
                  var cell = _cellGrid.get(r, c);
                  if (cell?.songMoment != null) {
                    momentNumber = cell?.songMoment!.momentNumber;
                    break;
                  }
                }

                //  add a row indicator
                var firstWidget = _LyricSectionIndicatorCellWidget(
                  lyricSection: lyricSection!,
                  row: r,
                  width: arrowIndicatorWidth * _scaleFactor,
                  height: heights[r],
                  fontSize: _chordFontSizeUnscaled * _scaleFactor,
                  momentNumber: momentNumber,
                );
                rowWidget = Row(
                  children: [
                    AppSpace(
                      horizontalSpace: _unusedMargin, // centering
                    ),
                    firstWidget,
                    ...rowChildren,
                  ],
                );
              } else {
                rowWidget = Row(
                  children: [
                    AppSpace(
                      horizontalSpace: _unusedMargin, // centering
                    ),
                    ...rowChildren,
                  ],
                );
              }
              // logger.t('rowChildren: $rowChildren');
            }

            lastLyricSection = lyricSection;
            //  offset the initial row by the requested amount
            if ( r == 0 ) {
              sectionChildren.add( SizedBox(height: initialHeightOffset * _scaleFactor,) );
            }
            items.add(Column(crossAxisAlignment: .start, children: sectionChildren));
            sectionChildren = [];

            sectionChildren.add(rowWidget);
          }
          //  complete with the last
          if (sectionChildren.isNotEmpty) {
            items.add(Column(crossAxisAlignment: .start, children: sectionChildren));
          }
        }
        break;
    }

    //  show copyright
    switch (appOptions.userDisplayStyle) {
      case .banner:
        items.add(Text('Release/Label: ${song.copyright}', style: _lyricsTextStyle));
        break;
      case .highContrast:
        items.add(AppSpace(verticalSpace: heights[0]));
        break;
      default:
        items.add(
          Padding(
            padding: EdgeInsets.all(_lyricsFontSizeUnscaled),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                AppSpace(verticalSpace: _lyricsFontSizeUnscaled),
                Text(
                  'Release/Label: ${song.copyright}',
                  style: _lyricsTextStyle.copyWith(
                    fontSize: (_lyricsTextStyle.fontSize ?? _lyricsFontSizeUnscaled) * _scaleFactor * 0.75,
                  ),
                ),
                //  give the scrolling some stuff to scroll the bottom up on
                AppSpace(verticalSpace: 10 * _lyricsFontSizeUnscaled),
              ],
            ),
          ),
        );
        break;
    }

    logger.log(_logLyricsBuild, 'lyricsBuild: boxing: ${usTimer.deltaToString()}');

    //  build the lookups for song moment and lyric sections
    {
      _lyricSectionIndexToRowMap.clear();
      _rowNumberToDisplayOffset = List.filled(_cellGrid.getRowCount(), 0.0);
      double offset = 0;
      for (var r = 0; r < _cellGrid.getRowCount(); r++) {
        logger.log(_logLyricsTableItems, 'row $r:');
        var row = _cellGrid.getRow(r);
        assert(row != null);
        row = row!;
        _rowCount = r;

        for (var c = 0; c < row.length; c++) {
          var cell = _cellGrid.get(r, c);
          if (cell == null) {
            continue; //  for example, first column in lyrics for singer display style
          }
          var songMoment = cell.songMoment;
          if (songMoment != null) {
            if (_lyricSectionIndexToRowMap[songMoment.lyricSection.index] == null) {
              _lyricSectionIndexToRowMap[songMoment.lyricSection.index] = r;
            }
          } else if (cell.measureNode is Lyric) {
            //var lyric = cell.measureNode as Lyric;
            //logger.i('  lyric: ($c,$r): ${lyric.repeat}: $lyric ');
          }
          logger.log(
            _logLyricsTableItems,
            '  ($c,$r): songMoment: $songMoment, repeat: ${songMoment?.repeat}/${songMoment?.repeatMax}'
            ', lyricsLines: ${songMoment?.lyricSection.lyricsLines.length}'
            ', lyricSection.index: ${songMoment?.lyricSection.index}'
            ', height: ${heights[r].toStringAsFixed(1)}'
            ', ${cell.richText.text.toPlainText()}',

            // ',  ${cell?.measureNode}'
          );
        }

        _rowNumberToDisplayOffset[r] = offset;
        offset += heights[r] + _marginSize / 2 + _paddingSize / 2;
      }
    }
    // logger.i('height spacing: ${_marginSize / 2 + _paddingSize / 2}');

    //  fill the song moment number to display offset list
    //  worry about compressed repeat rows
    {
      double offset = 0;
      int lastR = 0;
      _songMomentNumberToDisplayOffset = List<double>.filled(song.songMoments.length, 0.0);
      for (var songMoment in song.songMoments) {
        var r = _song.songMomentToGridCoordinate[songMoment.momentNumber].row;
        _songMomentNumberToDisplayOffset[songMoment.momentNumber] = offset;

        logger.log(
          _logLyricsTableItemDisplayOffsets,
          'moment ${songMoment.momentNumber}: row: $r'
          ', offset: ${offset.toStringAsFixed(1)}'
          ', $songMoment'
          ', lyrics ${songMoment.lyricSection.index}',
          // ', lyricSection: "${songMoment.lyricSection.lyricsLines}"'
          //
        );

        //  prep for the next row
        if (r != lastR) {
          if (r >= heights.length) {
            logger.i('fixme: error here: $r >= ${heights.length}, $songMoment');
          } else {
            offset += heights[r] + _marginSize / 2 + _paddingSize / 2;
            lastR = r;
          }
        }
      }
    }

    //  // let the repeat cells know where they are in the song moments
    //  // the last song moment is used
    // {
    //   SongMoment? lastSongMoment;
    //   for (int r = 0; r < _cellGrid.getRowCount(); r++) {
    //     var row = _cellGrid.getRow(r);
    //     assert(row != null);
    //     row = row!;
    //
    //     for (var c = 0; c < row.length; c++) {
    //       var cell = _cellGrid.get(r, c);
    //       if (cell == null) continue;
    //
    //       if (cell.songMoment != null) {
    //         lastSongMoment = cell.songMoment;
    //       }
    //       if (cell.measureNode is MeasureRepeatMarker && lastSongMoment != null) {
    //         var marker = cell.measureNode as MeasureRepeatMarker;
    //         logger.i('repeat: $marker, repetition: ${marker.repetition}');
    //         _cellGrid.set(
    //           r,
    //           c,
    //           cell.copyWith(
    //             firstMomentNumber:
    //                 lastSongMoment.momentNumber + 1 + lastSongMoment.phrase.length * (((marker.repetition ?? 1)-1) - marker.repeats ),
    //             lastMomentNumber: lastSongMoment.momentNumber,
    //           ),
    //         );
    //         lastSongMoment = null;
    //       }
    //     }
    //   }
    // }

    // logger.i((SplayTreeSet<int>.from(_lyricSectionIndexToRowMap.keys)
    //     .map((k) => '$k -> ${_lyricSectionIndexToRowMap[k]}')).toList().toString());
    if (Logger.level.index <= _logSongCellOffsetList.index) {
      var lastOffset = 0.0;
      for (var r = 0; r < _cellGrid.getRowCount(); r++) {
        var offset = _rowNumberToDisplayOffset[r];
        var delta = offset - lastOffset;
        lastOffset = offset;
        logger.log(
          _logFontSize,
          '  row $r: displayOffset: ${offset.toStringAsFixed(3)}'
          ', delta: ${delta.toStringAsFixed(3)}',
        );
      }
    }

    //  diagnostics only
    if (_logDisplayGrid.index <= Level.info.index) {
      logger.log(_logDisplayGrid, 'songMomentGrid:');
      logger.log(_logDisplayGrid, song.songMomentGrid.toString());
      logger.log(_logDisplayGrid, 'displayGrid:');
      logger.log(_logDisplayGrid, displayGrid.toString());
      logger.log(_logDisplayGrid, 'displayGrid repeats:');
      for (int r = 0; r < displayGrid.getRowCount(); r++) {
        var row = displayGrid.getRow(r);
        assert(row != null);
        row = row!;

        for (var c = 0; c < row.length; c++) {
          var mn = displayGrid.get(r, c);
          if (mn != null) {
            switch (mn.measureNodeType) {
              case .measureRepeatMarker:
                var marker = mn as MeasureRepeatMarker;
                logger.log(_logDisplayGrid, '   ($r,$c): ${marker.toDebugString()}');
                break;
              default:
                break;
            }
          }
        }
      }
      logger.log(_logDisplayGrid, '_cellGrid:');
      for (int r = 0; r < _cellGrid.getRowCount(); r++) {
        var row = _cellGrid.getRow(r);
        assert(row != null);
        row = row!;
        logger.log(_logDisplayGrid, 'row $r:  height: ${heights[r]}');

        for (var c = 0; c < row.length; c++) {
          var cell = _cellGrid.get(r, c);
          if (cell != null) {
            switch (cell.measureNode?.measureNodeType) {
              case .measureRepeatMarker:
                var marker = cell.measureNode as MeasureRepeatMarker;
                logger.log(
                  _logDisplayGrid,
                  '      col $c: ${cell.measureNode} :'
                  ', moment: ${cell.songMoment}'
                  ', repetition: ${marker.repetition}'
                  ', lastRepetition: ${marker.lastRepetition}'
                  ', mn: ${cell.firstMomentNumber}'
                  ' to ${cell.lastMomentNumber} / ${cell.measuresPerRepeat}'
                  ', repeat: ${cell.songMoment?.repeat}',
                );
                break;
              default:
                logger.log(
                  _logDisplayGrid,
                  '      col $c: ${cell.measureNode} :'
                  ', moment: ${cell.songMoment}'
                  ', mn: ${cell.firstMomentNumber} to ${cell.lastMomentNumber}',
                );
                break;
            }
          }
        }
      }
    }

    return items;
  }

  /// Transcribe the chord section to a text span, adding Nashville notation when appropriate.
  TextSpan _chordSectionTextSpan(
    final ChordSection chordSection,
    final music_key.Key originalKey,
    int transpositionOffset, {
    final music_key.Key? displayMusicKey,
    TextStyle? style,
  }) {
    style = style ?? _coloredChordTextStyle;

    final List<TextSpan> children = [];
    switch (_nashvilleSelection) {
      case .off:
      case .both:
        for (var phrase in chordSection.phrases) {
          if (phrase.isRepeat()) {
            children.add(TextSpan(text: '[ ', style: style));
          }
          for (var measure in phrase.measures) {
            var textSpan = _measureTextSpan(
              measure,
              originalKey,
              transpositionOffset,
              displayMusicKey: displayMusicKey,
              style: style,
              showBeats: true,
            );
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

    if (_nashvilleSelection == .both) {
      children.add(TextSpan(text: '\n', style: style));
    }

    final List<TextSpan> nashvilleChildren = [];
    switch (_nashvilleSelection) {
      case .both:
      case .only:
        for (var phrase in chordSection.phrases) {
          if (phrase.isRepeat()) {
            children.add(TextSpan(text: '[ ', style: style));
          }
          if (nashvilleChildren.isNotEmpty) {
            //  space the nashville children with a dot
            nashvilleChildren.add(TextSpan(text: _middleDot, style: style));
          }
          for (var measure in phrase.measures) {
            var textSpan = _nashvilleMeasureTextSpan(
              measure,
              originalKey,
              transpositionOffset,
              displayMusicKey: displayMusicKey,
              style: style,
            );
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
      case .off:
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
        case .measure:
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
    final Measure measure,
    final music_key.Key originalKey,
    int transpositionOffset, {
    final music_key.Key? displayMusicKey,
    TextStyle? style,
    final bool showBeats = true,
    withInversion = true,
  }) {
    style = style ?? _coloredChordTextStyle;

    final List<TextSpan> children = [];
    switch (_nashvilleSelection) {
      case NashvilleSelection.off:
      case NashvilleSelection.both:
        var textSpan = _measureTextSpan(
          measure,
          originalKey,
          transpositionOffset,
          displayMusicKey: displayMusicKey,
          style: style,
          showBeats: showBeats,
          withInversion: withInversion,
        );
        if (children.isNotEmpty) children.add(TextSpan(text: ' ', style: style));
        children.add(textSpan);
        break;
      default:
        break;
    }

    final List<TextSpan> nashvilleChildren = [];
    switch (_nashvilleSelection) {
      case .both:
      case .only:
        var textSpan = _nashvilleMeasureTextSpan(
          measure,
          originalKey,
          transpositionOffset,
          displayMusicKey: displayMusicKey,
          style: style,
        );
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

  TextSpan _measureTextSpan(
    final Measure measure,
    final music_key.Key originalKey,
    final int transpositionOffset, {
    final music_key.Key? displayMusicKey,
    TextStyle? style,
    final bool showBeats = false,
    final withInversion = false,
  }) {
    style = style ?? _coloredChordTextStyle;
    logger.t(
      '_measureTextSpan: style.color: ${style.color}'
      ', black: ${Colors.black}, ==: ${style.color == Colors.black}',
    );
    var slashColor = style.color == Colors.black ? _slashColor : _fadedSlashColor;
    final TextStyle slashStyle = style.copyWith(color: slashColor, fontWeight: .bold, fontStyle: FontStyle.italic);

    TextStyle chordDescriptorStyle = style
        .copyWith(fontSize: (style.fontSize ?? _chordFontSizeUnscaled), fontWeight: .normal)
        .copyWith(backgroundColor: style.backgroundColor);

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
          switch (appOptions.accidentalExpressionChoice) {
            case .alwaysSharp:
              scaleNote = scaleNote.asSharp();
              break;
            case .alwaysFlat:
              scaleNote = scaleNote.asFlat();
              break;
            case .easyRead:
              scaleNote = scaleNote.asEasyRead();
              break;
            default:
              break;
          }

          chordChildren.add(TextSpan(text: scaleNote.toString(), style: style));
        }
        {
          //  chord descriptor
          var chordDescriptor = transposedChord.scaleChord.chordDescriptor;
          chordDescriptor = _simplifiedChordsSelection ? chordDescriptor.simplified : chordDescriptor;
          var name = chordDescriptor.shortName;
          if (name.isNotEmpty) {
            chordChildren.add(TextSpan(text: name, style: chordDescriptorStyle));
          }
        }

        //  other stuff
        {
          var otherStuff =
              transposedChord.anticipationOrDelay.toString() +
              (showBeats && !measure.requiresNashvilleBeats ? transposedChord.beatsToString() : '');
          if (otherStuff.isNotEmpty) {
            chordChildren.add(TextSpan(text: otherStuff, style: style));
          }
        }
        if (isSlash && withInversion) {
          var slashScaleNote =
              transposedChord
                  .slashScaleNote //
                  ??
              ScaleNote.X; //  should never happen!

          //  process scale note by accidental choice
          switch (appOptions.accidentalExpressionChoice) {
            case .alwaysSharp:
              slashScaleNote = slashScaleNote.asSharp();
              break;
            case .alwaysFlat:
              slashScaleNote = slashScaleNote.asFlat();
              break;
            case .easyRead:
              slashScaleNote = slashScaleNote.asEasyRead();
              break;
            default:
              break;
          }
          var s = '/$slashScaleNote '; //  notice the final space for italics
          //  and readability
          chordChildren.add(TextSpan(text: s, style: slashStyle));
        }
        children.add(TextSpan(children: chordChildren));
      }
    } else {
      //  non chord measures such as repeats, repeat markers and comments
      children.add(TextSpan(text: measure.toString(), style: style));
    }

    return TextSpan(style: style, children: children);
  }

  TextSpan _nashvilleMeasureTextSpan(
    final Measure measure,
    final music_key.Key originalKey,
    final int transpositionOffset, {
    final music_key.Key? displayMusicKey,
    TextStyle? style,
  }) {
    final keyOffset = originalKey.getHalfStep();

    style = style ?? _coloredChordTextStyle;
    var slashColor = style.color == Colors.black ? _slashColor : _fadedSlashColor;
    final TextStyle slashStyle = style.copyWith(color: slashColor, fontWeight: .bold, fontStyle: FontStyle.italic);

    TextStyle chordDescriptorStyle = generateChordDescriptorTextStyle(
      fontSize: (style.fontSize ?? _chordFontSizeUnscaled),
      fontWeight: .normal,
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

        chordChildren.add(
          TextSpan(
            text: NashvilleNote.byHalfStep(chord.scaleChord.scaleNote.halfStep - keyOffset).toString(),
            style: style,
          ),
        );
        {
          String descriptor = chord.scaleChord.chordDescriptor.toNashville();
          if (descriptor.isNotEmpty) {
            chordChildren.add(TextSpan(text: descriptor, style: chordDescriptorStyle));
          }
        }
        // nashvilleChildren.add(TextSpan(text: '${chord.anticipationOrDelay}', style: style));

        if (chord.slashScaleNote != null) {
          chordChildren.add(
            TextSpan(
              //  notice the final space for italics  and readability
              text: '/${NashvilleNote.byHalfStep(chord.slashScaleNote!.halfStep - keyOffset)} ',
              style: slashStyle,
            ),
          );
        }
        nashvilleChildren.add(TextSpan(children: chordChildren, style: style));
      }
    }

    return TextSpan(style: style, children: nashvilleChildren);
  }

  void _displayChordSection(
    GridCoordinate gc,
    ChordSection chordSection,
    MeasureNode measureNode, {
    bool? selectable,
    int? lyricSectionIndex,
  }) {
    _colorBySectionVersion(chordSection.sectionVersion);
    _cellGrid.setAt(
      gc,
      _SongCellWidget(
        richText: RichText(
          text: TextSpan(text: chordSection.sectionVersion.toString(), style: _coloredSectionTextStyle),
        ),
        row: gc.row,
        column: gc.col,
        type: _SongCellType.flow,
        measureNode: measureNode,
        selectable: selectable,
        lyricSectionIndex: lyricSectionIndex,
      ),
    );
  }

  void _colorBySectionVersion(SectionVersion sectionVersion) {
    _sectionBackgroundColor = App.getBackgroundColorForSectionVersion(sectionVersion);
    _coloredChordTextStyle = _chordTextStyle.copyWith(backgroundColor: _sectionBackgroundColor);
    _coloredSectionTextStyle = _coloredChordTextStyle.copyWith(
      fontSize: (_coloredChordTextStyle.fontSize ?? appDefaultFontSize) / 2,
    );
    _coloredLyricTextStyle = _chordTextStyle.copyWith(
      backgroundColor: _sectionBackgroundColor,
      fontSize: (appOptions.userDisplayStyle == .banner ? 0.5 : 1) * _lyricsFontSizeUnscaled,
      fontWeight: .normal,
    );
  }

  /// compute screen size values used here and on other screens
  void _computeScreenSizes() {
    App app = App();
    _screenWidth = app.screenInfo.mediaWidth;
    _screenHeight = app.screenInfo.mediaHeight;

    //  rough in the basic fontSize
    _chordFontSizeUnscaled = 65; // max for hdmi resolution

    _scaleComponents();
    _lyricsFontSizeUnscaled = _chordFontSizeUnscaled * 0.75;

    //  text styles
    _chordTextStyle = generateChordTextStyle(
      fontFamily: appFontFamily,
      fontSize: _chordFontSizeUnscaled,
      fontWeight: .bold,
    );
    _lyricsTextStyle = _chordTextStyle.copyWith(fontSize: _lyricsFontSizeUnscaled, fontWeight: .normal);
  }

  int songMomentNumberToGridRow(final int? momentNumber) {
    if (momentNumber == null) {
      return 0;
    }

    return _song.songMomentToGridCoordinate[min(max(momentNumber, 0), _song.songMoments.length - 1)].row;
  }

  double rowToDisplayOffset(final int? rowNumber) {
    if (rowNumber == null) {
      return 0;
    }
    return _rowNumberToDisplayOffset[Util.intLimit(rowNumber, 0, _rowNumberToDisplayOffset.length - 1)];
  }

  double displayOffsetToRowNumber(final double displayOffset) {
    for (int i = 0; i < _rowNumberToDisplayOffset.length; i++) {
      var offset = _rowNumberToDisplayOffset[i];
      if (offset >= displayOffset) {
        return i.toDouble();
      }
    }
    return _rowNumberToDisplayOffset.length.toDouble();
  }

  // int displayOffsetToRow(final double offset) {
  //   if (_songMomentToDisplayOffset.isEmpty) {
  //     return 0;
  //   }
  //   //  fixme: optimize this reverse lookup
  //   int limit = _songMomentToDisplayOffset.length;
  //   for (var row = 0; row < limit; row++) {
  //     var rowOffset = _songMomentToDisplayOffset[row];
  //     if (rowOffset > offset) {
  //       return max(0, row - 1);
  //     }
  //   }
  //   return limit - 1;
  // }

  int displayOffsetToSongMomentNumber(final double offset) {
    if (_songMomentNumberToDisplayOffset.isEmpty) {
      return 0;
    }
    //  fixme: optimize this reverse lookup
    int limit = _songMomentNumberToDisplayOffset.length;
    for (var m = 0; m < limit; m++) {
      var rowOffset = _songMomentNumberToDisplayOffset[m];
      if (rowOffset > offset) {
        return max(0, m - 1);
      }
    }
    return limit - 1;
  }

  int rowToLyricSectionIndex(final int row) {
    if (_cellGrid.isEmpty) {
      return 0;
    }
    //  fixme: to weak
    //  find the grid row
    var gridRow = _cellGrid.getRow(Util.intLimit(row, 0, _cellGrid.getRowCount() - 1));
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

  int lastRowInSection(final int row) {
    if (_cellGrid.isEmpty) {
      return 0;
    }

    var lyricSectionIndex = 0;
    {
      //  find the grid row
      var gridRow = _cellGrid.getRow(Util.intLimit(row, 0, _cellGrid.getRowCount() - 1));
      if (gridRow == null || gridRow.isEmpty) {
        return 0;
      }

      //  find the last grid row with the same lyric section

      for (var cell in gridRow) {
        if (cell != null && cell.lyricSectionIndex != null) {
          lyricSectionIndex = cell.lyricSectionIndex!;
          break;
        }
      }
    }
    int r = row + 1;
    for (; r < _cellGrid.getRowCount(); r++) {
      var gridRow = _cellGrid.getRow(r);
      if (gridRow != null) {
        for (var cell in gridRow) {
          if (cell != null && cell.lyricSectionIndex != null) {
            if (lyricSectionIndex != cell.lyricSectionIndex!) {
              return r - 1;
            }
          }
        }
      }
    }
    return r - 1;
  }

  int gridRowToMomentNumber(final int row) {
    if (_cellGrid.isEmpty) {
      return 0;
    }

    //  look past the current row to find the moment... the row might just be a section header.
    for (int r = row; r <= row + 1; r++) {
      //  fixme: too weak
      //  find the grid row
      //  note that on a non-expanded repeat, the highest moment in that grid location will be there
      var gridRow = _cellGrid.getRow(Util.intLimit(r, 0, _cellGrid.getRowCount() - 1));
      if (gridRow == null || gridRow.isEmpty) {
        continue;
      }

      //  find the moment number from the row
      for (var cell in gridRow) {
        // logger.i('     r: $r, cell: ${cell?.songMoment}');
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

  late Song _song;

  NashvilleSelection _nashvilleSelection = NashvilleSelection.off;
  bool _simplifiedChordsSelection = false;

  double get screenWidth => _screenWidth;
  double _screenWidth = 1920; //  initial value only

  double get unusedMargin => _unusedMargin;
  double _unusedMargin = 0;

  double get screenHeight => _screenHeight;
  double _screenHeight = 1080; //  initial value only

  double _chordFontSizeUnscaled = appDefaultFontSize;
  double _lyricsFontSizeUnscaled = 18; //  initial value only

  double get marginSize => _marginSize;

  Grid<_SongCellWidget> _cellGrid = Grid();

  TextStyle get chordTextStyle => _chordTextStyle;
  TextStyle _chordTextStyle = generateAppTextStyle();

  TextStyle get lyricsTextStyle => _lyricsTextStyle;
  TextStyle _lyricsTextStyle = generateLyricsTextStyle();

  Color _sectionBackgroundColor = Colors.white;
  TextStyle _coloredSectionTextStyle = generateLyricsTextStyle();
  TextStyle _coloredChordTextStyle = generateLyricsTextStyle();
  TextStyle _coloredLyricTextStyle = generateLyricsTextStyle();
  final TextStyle _highContrastTextStyle = generateAppTextStyle(
    color: Colors.white,
    backgroundColor: Colors.black,
    fontFamily: 'Arimo',
    fontSize: 300.0,
    fontWeight: .w900,
  );

  double get scaleFactor => _scaleFactor;
  double _scaleFactor = 1.0;

  int get rowCount => _rowCount;
  int _rowCount = 0;

  List<double> _rowNumberToDisplayOffset = [];
  List<double> _songMomentNumberToDisplayOffset = [];
  final Map<int, int> _lyricSectionIndexToRowMap = HashMap();

  music_key.Key displayMusicKey = music_key.Key.C;
  final RegExp verticalBarAndSpacesRegExp = RegExp(r'\s*\|\s*');
}

enum _SongCellType { columnFill, columnMinimum, lyric, lyricEllipsis, flow }

class _LyricSectionIndicatorCellWidget extends StatefulWidget {
  _LyricSectionIndicatorCellWidget({
    required this.lyricSection,
    required this.row,
    required this.width,
    required this.height,
    this.fontSize = appDefaultFontSize,
    this.momentNumber,
  }) : index = lyricSection.index;

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
  final int? momentNumber;
}

class _LyricSectionIndicatorCellState extends State<_LyricSectionIndicatorCellWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<PlayMomentNotifier, LyricSectionNotifier>(
      builder: (context, playMomentNotifier, lyricSectionNotifier, child) {
        var currentSongUpdateState = playMomentNotifier.playMoment?.songUpdateState ?? .none;
        var isNowSelected =
            currentSongUpdateState.isPlayingOrPausedOrHold &&
            lyricSectionNotifier.lyricSectionIndex == widget.index &&
            lyricSectionNotifier.row == widget.row;
        var songMoment = playMomentNotifier._playMoment?.songMoment;
        logger.log(
          _logLyricSectionIndicatorCellState,
          'LyricSectionIndicatorCellState isNowSelected: $selected, selected: $isNowSelected'
          ', momentNumber: ${songMoment?.momentNumber}'
          ', lyricSectionIndex: ${lyricSectionNotifier._lyricSectionIndex}',
        );

        if (isNowSelected == selected &&
            _songUpdateState == currentSongUpdateState &&
            _lastRepeat == songMoment?.repeat &&
            _repeatMax == songMoment?.repeatMax &&
            child != null) {
          // logger.log(
          //     _logLyricSectionIndicatorCellState,
          //     'LyricSectionIndicatorCellState.child'
          //     ' remained: ${widget.index}, row: ${lyricSectionNotifier.row} $child');
          return child;
        }
        selected = isNowSelected;
        _lastRepeat = songMoment?.repeat;
        _repeatMax = songMoment?.repeatMax;
        _songUpdateState = currentSongUpdateState;

        return childBuilder(context);
      },
      child: Builder(builder: childBuilder),
    );
  }

  Widget childBuilder(BuildContext context) {
    logger.log(
      _logLyricSectionIndicatorCellStateChild,
      'LyricSectionIndicatorCellState.childBuilder: run: '
      '${widget.index}:'
      ' _songUpdateState: $_songUpdateState'
      ', selected: $selected',
    );

    switch (appOptions.playerScrollHighlight) {
      case .off:
      case .measure:
        return NullWidget();
      case .chordRow:
        break;
    }

    Widget repeatCountWidget = ((_repeatMax ?? 0) > 0)
        ? Center(
            child: Text(
              '${(_lastRepeat ?? 0) + 1}',
              style: appTextStyle.copyWith(
                backgroundColor: Colors.transparent,
                fontSize: appTextStyle.fontSize! * 1.25,
              ),
            ),
          )
        : NullWidget();

    return SizedBox(
      width: widget.width,
      child: selected
          ? DecoratedBox(
              decoration: const ShapeDecoration(color: Colors.white, shape: CircleBorder()),
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  appIcon(
                    Icons.play_arrow,
                    size: widget.fontSize,
                    color: _songUpdateState == .playing ? _playHighlightColor : _idleHighlightColor,
                  ),
                  repeatCountWidget,
                ],
              ),
            )
          : (kDebugMode
                ? Text(
                    '${widget.row.toString()}'
                    '${widget.momentNumber != null ? '\n${widget.momentNumber}' : ''}',
                    style: appTextStyle,
                  )
                : NullWidget()), // hold the horizontal space in the grid
    );
  }

  var selected = false;
  SongUpdateState? _songUpdateState;
  int? _lastRepeat;
  int? _repeatMax;
}

class _SongCellWidget extends StatefulWidget {
  const _SongCellWidget({
    super.key,
    required this.richText,
    required this.row,
    required this.column,
    this.type = _SongCellType.columnFill,
    this.measureNode,
    this.lyricSectionIndex,
    this.lyricSectionSet,
    this.size,
    this.columnWidth,
    this.withEllipsis,
    this.songMoment,
    this.firstMomentNumber,
    this.lastMomentNumber,
    this.selectable,
    this.isFixedHeight = false,
    this.rowHasExplicitBeats = false,
    this.alignment = .centerLeft,
  });

  _SongCellWidget._empty({this.isFixedHeight = false, required this.row, required this.column})
    : richText = _emptyRichText,
      type = _SongCellType.columnFill,
      withEllipsis = false,
      measureNode = null,
      lyricSectionIndex = null,
      lyricSectionSet = null,
      size = null,
      columnWidth = null,

      //  many more than expected
      rowHasExplicitBeats = false,
      songMoment = null,
      firstMomentNumber = null,
      lastMomentNumber = null,
      selectable = false,
      alignment = .centerLeft;

  _SongCellWidget copyWith({
    Size? size,
    double? columnWidth,
    double? textScaleFactor,
    SongMoment? songMoment,
    int? firstMomentNumber,
    int? lastMomentNumber,
  }) {
    RichText copyOfRichText;
    if (type == _SongCellType.lyricEllipsis && columnWidth != null) {
      copyOfRichText = RichText(
        key: richText.key,
        text: //  default to one line
        TextSpan(
          text: richText.text.toPlainText(),
          style: richText.text.style,
        ),
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
      row: row,
      column: column,
      type: type,
      measureNode: measureNode,
      lyricSectionIndex: lyricSectionIndex,
      lyricSectionSet: lyricSectionSet,
      size: size ?? this.size,
      columnWidth: columnWidth ?? this.columnWidth,
      withEllipsis: withEllipsis,
      songMoment: songMoment ?? this.songMoment,
      firstMomentNumber: firstMomentNumber ?? this.firstMomentNumber,
      lastMomentNumber: lastMomentNumber ?? this.lastMomentNumber,
      selectable: selectable,
      isFixedHeight: isFixedHeight,
      rowHasExplicitBeats: rowHasExplicitBeats,
      alignment: alignment,
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
        : _computeRichTextSize(richText, maxLines: _maxLines, maxWidth: width) +
              Offset(2 * _paddingSize + 2 * _marginSize, 2 * _paddingSize + 2 * _marginSize);
    return ret;
  }

  Size get buildSize => size ?? computedBuildSize;

  @override
  String toString({DiagnosticLevel? minLevel}) {
    return 'SongCellWidget{richText: $richText, type: ${type.name}, measureNode: $measureNode'
        ', type: ${measureNode?.measureNodeType}, size: $size }';
  }

  int get measuresPerRepeat {
    return (measureNode != null && measureNode is MeasureRepeatMarker)
        ? (measureNode as MeasureRepeatMarker).measuresPerRepeat
        : 0;
  }

  final _SongCellType type;
  final bool? withEllipsis;
  final RichText richText;
  final int row;
  final int column;
  final MeasureNode? measureNode;
  final int? lyricSectionIndex;
  final SplayTreeSet<int>? lyricSectionSet;
  final Size? size;
  final double? columnWidth;
  final bool isFixedHeight;
  final SongMoment? songMoment;
  final int? firstMomentNumber;
  final int? lastMomentNumber;
  final bool? selectable;
  final Alignment alignment;
  final bool rowHasExplicitBeats;

  //
  static final _emptyRichText = RichText(text: const TextSpan(text: ''));
}

class _SongCellState extends State<_SongCellWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PlayMomentNotifier>(
      builder: (context, playMomentNotifier, child) {
        var playMomentNumber = playMomentNotifier.playMoment?.playMomentNumber ?? 0;
        var isNowSelected = false;
        var repeat = 0;

        bool byMoment =
            (widget.firstMomentNumber ?? 0) <= max(playMomentNumber, 0) &&
            playMomentNumber < (widget.lastMomentNumber ?? _maxMomentNumber);

        //  compute the repeat
        if (widget.measureNode?.measureNodeType == .measureRepeatMarker) {
          var marker = widget.measureNode! as MeasureRepeatMarker;

          var last = widget.songMoment?.momentNumber ?? 0;
          var first =
              last - ((marker.lastRepetition ?? 0) - ((marker.repetition ?? 1) - 1)) * marker.measuresPerRepeat + 1;

          repeat = 0;
          if (playMomentNumber >= first && playMomentNumber <= last) {
            repeat =
                (marker.repetition ?? 1) -
                1 +
                min<int>((playMomentNumber - first) ~/ marker.measuresPerRepeat, marker.repeats - 1);
          } else if (playMomentNumber >= last) {
            repeat = marker.repeats - 1;
          }

          // if (widget.row == 3 && playMomentNumber >= 19 && playMomentNumber < 29) {
          //   logger.log(
          //     _logSongCellStateBuild,
          //     'cellState Build: (${widget.row},${widget.column}):'
          //     ' playMomentNumber: $playMomentNumber'
          //     ', firstMomentNumber: ${widget.firstMomentNumber}'
          //     ', lastMomentNumber: ${widget.lastMomentNumber}'
          //     ', byMoment: $byMoment'
          //     ', repeat: $repeat',
          //   );
          // }
        }

        if (byMoment) {
          //  this is a row element that is being displayed
          if ((widget.selectable ?? true) &&
              ((playMomentNotifier.playMoment?.songUpdateState == .playing &&
                      (playMomentNotifier.playMoment?.playMomentNumber ?? -1) >= 0) //
                  ||
                  widget.lyricSectionIndex != null ||
                  widget.lyricSectionSet != null)) {
            switch (widget.measureNode.runtimeType) {
              case const (Measure):
                var moment = playMomentNotifier.playMoment?.songMoment ?? widget.songMoment;
                isNowSelected =
                    moment != null &&
                    playMomentNotifier.playMoment?.songUpdateState == .playing &&
                    playMomentNumber >= 0 &&
                    (playMomentNumber == widget.songMoment?.momentNumber ||
                        (
                        //  deal with abbreviated or hidden repeat rows
                        moment.lyricSection == widget.songMoment?.lyricSection &&
                            moment.phraseIndex == widget.songMoment?.phraseIndex &&
                            moment.phrase.repeats > 1 &&
                            widget.songMoment?.momentNumber != null &&
                            (playMomentNumber - widget.songMoment!.momentNumber) % moment.phrase.length == 0));
                if (isNowSelected) {
                  logger.log(
                    _logSelectedCellState,
                    '_SongCellState: ${widget.measureNode.runtimeType}: $isNowSelected'
                    ', ${widget.measureNode}'
                    ', textScaler: ${widget.richText.textScaler}'
                    ', moment: ${widget.songMoment?.momentNumber}'
                    ', playMomentNumber: $playMomentNumber',
                    //
                  );
                }
                break;
            }
          }

          switch (appOptions.playerScrollHighlight) {
            case .off:
            case .chordRow:
              isNowSelected = false;
              break;
            case .measure:
              break;
          }
        } else {
          isNowSelected = false;
          lastRepeat = null;
          child = null;
          Size size = widget.buildSize;
          return Container(
            alignment: .centerLeft,
            width: widget.columnWidth ?? size.width,
            height: widget.isFixedHeight ? (widget.size?.height ?? size.height) : size.height,
            margin: _margin,
            //  to assure the size is correct
            padding: _padding, //  to assure the size is correct
          );
        }

        // for efficiency, use the existing child
        if (isNowSelected == lastSelected && repeat == lastRepeat && child != null) {
          return child;
        }
        lastSelected = isNowSelected;
        lastRepeat = repeat;

        // logger.i( 'pre-childBuilder: ${widget.songMoment?.momentNumber}: $selected, $playMomentNumber'
        // ', ${widget.songMoment?.momentNumber}');
        return childBuilder(context);
      },
      child: Builder(builder: childBuilder),
    );
  }

  Widget childBuilder(BuildContext context) {
    RichText richText =
        //  an exception for repeat decorators with multiple repeats
        (widget.measureNode is MeasureRepeatMarker && lastRepeat != null)
        ? RichText(
            text: TextSpan(
              text:
                  'x${appOptions.showRepeatCounts ? '${lastRepeat! + 1}/' : ''}'
                  '${(widget.measureNode! as MeasureRepeatMarker).repeats}',
              style: widget.richText.text.style,
            ),
            textScaler: widget.richText.textScaler,
            maxLines: 1,
          )
        : widget.richText;

    //  diagnostic only
    logger.log(
      _logChildBuilder,
      '_SongCellState.childBuilder (${widget.row},${widget.column}): selected: $lastSelected, lastRepeat: $lastRepeat: '
      '#${widget.songMoment?.momentNumber}'
      ': ${richText.text.toPlainText()}'
      ', lastRepeat: $lastRepeat'
      // ', row: $_row vs ${widget.row}'
      ', firstMomentNumber: ${widget.firstMomentNumber}'
      ', lastMomentNumber: ${widget.lastMomentNumber}',
      //', widget.lyricSectionIndex: ${widget.lyricSectionIndex}'
      //
    );

    Size buildSize = widget.computedBuildSize;

    //  set width
    double width;
    switch (widget.type) {
      case .columnMinimum:
        width = buildSize.width;
        break;
      default:
        width = widget.columnWidth ?? buildSize.width;
        break;
    }

    //  fixe height for banner and high contrast only
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
    //     alignment: .centerLeft,
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
    if (widget.measureNode?.measureNodeType == .measure && richText.text is TextSpan) {
      //  fixme: limit to odd length measures

      Measure measure = widget.measureNode! as Measure;

      //  see if all the beats total the normal beat count and that they are all equal
      bool showOddBeats = measure.requiresNashvilleBeats;

      // if (showOddBeats) {
      //   logger.i('showOddBeats: $measure');
      // }

      if (widget.rowHasExplicitBeats) {
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
              // logger.i('break here');
            }
            if (chordTextSpan is TextSpan) {
              var chordRichText = RichText(text: chordTextSpan, textScaler: richText.textScaler);
              //  assumes text spans have been styled appropriately
              //  put beats on the top, Nashville style
              //  note that any odd beats in the row means all get extra vertical spacing
              Size beatsSize = _computeRichTextSize(chordRichText);
              chordWidgets.add(
                Column(
                  children: [
                    CustomPaint(
                      painter: showOddBeats ? _BeatMarkCustomPainter(measure.chords[chordIndex].beats) : null,
                      size: Size(
                        beatsSize.width,
                        richText.textScaler.scale(richText.text.style?.fontSize ?? 10) / 6,
                      ), //  fixme: why is this needed?
                    ),
                    chordRichText,
                  ],
                ),
              );
            } else {
              Text('not TextSpan: $chordTextSpan');
            }
            chordIndex++;
          }
          textWidget = SizedBox(
            width: width,
            height: height,
            child: AppWrap(children: chordWidgets),
          );
        }
      }
    }

    return Container(
      alignment: widget.alignment,
      width: width,
      height: height,
      margin: _margin,
      padding: _padding,
      foregroundDecoration: //
      lastSelected
          ? BoxDecoration(
              border: Border.all(width: _marginSize, color: _idleHighlightColor),
            )
          : null,
      color: widget.richText.text.style?.backgroundColor ?? Colors.transparent,
      child: textWidget,
    );
  }

  var lastSelected = false; //  indicates the cell is currently selected, i.e. highlighted
  int? lastRepeat; //  last repeat indicated for repeat markers with multiple repeats
}

@immutable
class _BeatMarkCustomPainter extends CustomPainter {
  const _BeatMarkCustomPainter(this.beats);

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

ScaleNote scaleNoteByAccidentalExpressionChoice(
  final ScaleNote scaleNote,
  final AccidentalExpressionChoice choice, {
  final music_key.Key? key,
}) {
  //  process scale note by accidental choice
  switch (choice) {
    case .alwaysSharp:
      return scaleNote.asSharp();
    case .alwaysFlat:
      return scaleNote.asFlat();
    case .easyRead:
      return scaleNote.asEasyRead();
    case .byKey:
      return (key ?? music_key.Key.getDefault()).isSharp ? scaleNote.asSharp() : scaleNote.asFlat();
  }
}
