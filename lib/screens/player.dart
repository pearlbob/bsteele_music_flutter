import 'dart:math';
import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:bsteele_music_flutter/SongMaster.dart';
import 'package:bsteele_music_flutter/gui.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../appOptions.dart';

/// Display the song moments in sequential order.
class Player extends StatefulWidget {
  const Player({Key key, @required this.song}) : super(key: key);

  @override
  _Player createState() => _Player();

  final Song song;
}

class _Player extends State<Player> {
  @override
  initState() {
    super.initState();

    //  control font size with ctl+wheel
    if (kIsWeb) {
      html.window.onMouseWheel.listen((event) {
        if (event.ctrlKey) {
          logger.v('event type: ${event.runtimeType.toString()},'
              ' d: ${event.deltaMode.toString()}'
              ' x: ${event.deltaX.toString()}'
              ' y: ${event.deltaY.toString()}'
              ' z: ${event.deltaZ.toString()}'
              //  ' ctl: ${event.ctrlKey.toString()}'
              '');
          event.preventDefault(); //  fixme: doesn't work

          double newFontSize = _defaultFontSize;
          if (event.deltaY < 0) {
            newFontSize++;
          } else if (event.deltaY > 0) {
            newFontSize--;
          }
          newFontSize = max(_defaultFontSizeMin, min(_defaultFontSizeMax, newFontSize));
          if (newFontSize != _defaultFontSize) {
            logger.d('newFontSize: $newFontSize');
            setState(() {
              _defaultFontSize = newFontSize;
              _forceTableRedisplay();
            });
          }
        }
      });
    }
    _appOptions = AppOptions();

    _displaySongKey = widget.song.key;

    //  eval sizes after first render
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      //  find the song's widget sizes after first rendering pass
      _lastDy = 0;
      double lastH = 0;
      double firstBoxDy;
      _RowLocation lastRowLocation;
      for (int i = 0; i < _rowLocations.length; i++) {
        _RowLocation rowLocation = _rowLocations[i];
        BuildContext buildContext = rowLocation.globalKey.currentContext;
        if (buildContext == null) continue;
        RenderBox box = buildContext.findRenderObject();

        {
          double dy = box.localToGlobal(Offset.zero).dy;
          if (firstBoxDy == null) {
            firstBoxDy = dy;
            rowLocation.dispY = 0;
          } else
            rowLocation.dispY = box.localToGlobal(Offset.zero).dy - firstBoxDy;
        }

        lastH = _lastDy != null ? rowLocation.dispY - _lastDy : box.size.height;
        rowLocation.height = box.size.height; //  placeholder
        if (lastRowLocation != null) lastRowLocation.height = lastH;
        _lastDy = rowLocation.dispY; //  for next time
        lastRowLocation = rowLocation;
        //logger.d(rowLocation.toString());
        //logger.d('    ${rowLocation.globalKey.currentContext.toString()}');
      }
      _lastDy += lastH;

//      //  diagnostics only
//      for (final RowLocation rowLocation in _rowLocations) {
//        logger.i('${rowLocation.toString()}');
//      }
//      logger.i('_lastDy: $_lastDy');
    });

    const int timerPeriod = 30;
    const int secondsPerMinute = 60;
    // const int millisecondsPerSecond = 1000;
    _ticker = Ticker((duration) {
      int t = DateTime.now().millisecondsSinceEpoch;
      int dt = t - _lastTime;
      _lastTime = t;

      if (_isPlaying) {
        if (!_isPaused) {
          _RowLocation _rowLocation = _rowLocationAtPosition(_scrollController.offset);
          if (_rowLocation != null) {
            if (_rowLocationBump != 0) {
              //  deal with the user bumping the scroll
              int row = _rowLocation.row;
              if (_rowLocationBump > 0) {
                ChordSection chordSection = _rowLocation.songMoment.chordSection;
                int sectionCount = _rowLocation.songMoment.sectionCount;
                for (int b = 0; b < _rowLocationBump; b++) {
                  int index = row + b;
                  if (index >= _rowLocations.length) {
                    break;
                  }
                  _RowLocation _nextRowLocation = _rowLocations[index];
                  if (chordSection != _nextRowLocation.songMoment.chordSection ||
                      sectionCount != _nextRowLocation.songMoment.sectionCount) {
                    _rowLocationBump = b;
                    break; //  don't roll over a section just by sloppy behavior
                  }
                }
              }
              row += _rowLocationBump;

              if (row < 0) {
                row = 0;
              } else if (row > _rowLocations.length - 1) {
                row = _rowLocations.length - 1;
              }
              _rowLocation = _rowLocations[row];

              _scrollController.animateTo(_rowLocation.dispY,
                  duration: Duration(milliseconds: 450), curve: Curves.ease);
              logger.i('_rowLocation: row: $row, Y: ${_rowLocation.dispY}');
            }
          }
        }
      }
      _rowLocationBump = 0;
      logger.v('ticker ${_tickerCount.toString()} $dt');
      _tickerCount++;
    });
    _ticker.start();

    songMaster = SongMaster();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  /// for the given position on the screen,
  /// return the row location in the song at that position
  _RowLocation _rowLocationAtPosition(double position) {
    if (position <= 0) return _rowLocations[0];
    for (final _RowLocation rowLocation in _rowLocations) {
      if (position < rowLocation.dispY + rowLocation.height) return rowLocation;
    }
    return null;
  }

//  /// for the given position on the screen,
//  /// return the time represented in the song at that position
//  double songTimeAtPosition(double position) {
//    if (position <= 0) return 0;
//
//    RowLocation rowLocation = _rowLocationAtPosition(position);
//    if (rowLocation == null) return null;
//
//    return (rowLocation.songMoment.beatNumber +
//            (position - rowLocation.dispY) /
//                rowLocation.height *
//                rowLocation.beats) *
//        60 /
//        widget.song.getBeatsPerMinute();
//  }

  @override
  Widget build(BuildContext context) {
    Song song = widget.song; //  convenience only

    double _screenWidth = MediaQuery.of(context).size.width;
    double _screenHeight = MediaQuery.of(context).size.height;
    _screenOffset = _screenHeight / 2;
    _isTooNarrow = _screenWidth <= 800;
    final double fontSize = _defaultFontSize * min(5, max(1, _screenWidth / 400)) / (_isTooNarrow ? 2 : 1);
    final double fontScale = fontSize / _defaultFontSize;

    final double lyricsFontSize = fontSize * 0.75;

    final TextStyle chordTextStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize);
    final TextStyle lyricsTextStyle = TextStyle(fontWeight: FontWeight.normal, fontSize: lyricsFontSize);

    if (_table == null) {
      logger.d("size: " + MediaQuery.of(context).size.toString());

      //  build the table from the song moment grid
      Grid<SongMoment> grid = song.songMomentGrid;
      _rowLocations = null;
      if (grid.isNotEmpty) {
        {
          _rowLocations = List(grid.getRowCount());
          List<TableRow> rows = List();
          List<Widget> children = List();
          Color color = GuiColors.getColorForSection(Section.get(SectionEnum.chorus));

          bool showChords = !_isTooNarrow || _appOptions.playerDisplay;
          bool showFullLyrics = !_isTooNarrow || !_appOptions.playerDisplay;

          //  compute transposition offset from base key
          int tranOffset = _displaySongKey.getHalfStep() - song.getKey().getHalfStep();

          //  keep track of the section
          ChordSection lastChordSection;
          int lastSectionCount;

          //  map the song moment grid to a flutter table, one row at a time
          for (int r = 0; r < grid.getRowCount(); r++) {
            List<SongMoment> row = grid.getRow(r);

            //  assume col 1 has a chord or comment in it
            if (row.length < 2) {
              continue;
            }

            //  find the first col with data
            //  should normally be col 1 (i.e. the second col)
            SongMoment firstSongMoment;
            for (final SongMoment sm in row)
              if (sm == null)
                continue;
              else {
                firstSongMoment = sm;
                break;
              }
            if (firstSongMoment == null) continue;

            GlobalKey _rowKey = GlobalKey(debugLabel: r.toString());
            _rowLocations[r] = _RowLocation(firstSongMoment, r, _rowKey, song.rowBeats(r));

            ChordSection chordSection = firstSongMoment.getChordSection();
            int sectionCount = firstSongMoment.sectionCount;
            String columnFiller;
            EdgeInsets marginInsets = EdgeInsets.all(fontScale);
            EdgeInsets textPadding = EdgeInsets.all(6);
            if (chordSection != lastChordSection || sectionCount != lastSectionCount) {
              //  add the section heading
              columnFiller = chordSection.sectionVersion.toString();
              color = GuiColors.getColorForSection(chordSection.getSection());
            }
            lastChordSection = chordSection;
            lastSectionCount = sectionCount;

            String momentLocation;
            String rowLyrics = '';
            for (int c = 0; c < row.length; c++) {
              SongMoment sm = row[c];

              if (sm == null) {
                if (columnFiller == null)
                  //  empty cell
                  children.add(Container(
                      margin: marginInsets,
                      child: Text(
                        " ",
                      )));
                else
                  children.add(Container(
                      margin: marginInsets,
                      padding: textPadding,
                      color: color,
                      child: Text(
                        columnFiller,
                        style: chordTextStyle,
                      )));
                columnFiller = null; //  for subsequent rows
              } else {
                //  moment found
                rowLyrics += ' ' + sm.lyrics;
                children.add(Container(
                    key: _rowKey,
                    margin: marginInsets,
                    padding: textPadding,
                    color: color,
                    child: Text(
                      sm.getMeasure().transpose(_displaySongKey, tranOffset),
                      style: chordTextStyle,
                    )));
                _rowKey = null;

                //  use the first non-null location for the table value key
                if (momentLocation == null) momentLocation = sm.momentNumber.toString();
              }

              //  section and lyrics only if on a cell phone
              if (!showChords) {
                //  collect the rest of the lyrics
                for (; c < row.length; c++) {
                  SongMoment sm = row[c];
                  if (sm != null) {
                    rowLyrics += ' ' + sm.lyrics;
                  }
                }
                break;
              }
            }

            if (momentLocation != null || _isTooNarrow) {
              if (showFullLyrics) {
                //  lyrics
                children.add(Container(
                    margin: marginInsets,
                    padding: textPadding,
                    color: color,
                    child: Text(
                      rowLyrics.trimLeft(),
                      style: lyricsTextStyle,
                    )));

                //  add row to table
                rows.add(TableRow(key: ValueKey(r), children: children));
              } else {
                //  short lyrics
                children.add(Container(
                    margin: marginInsets,
                    padding: EdgeInsets.all(2),
                    color: color,
                    child: Text(
                      firstSongMoment.lyrics,
                      style: lyricsTextStyle,
                      overflow: TextOverflow.ellipsis,
                    )));

                //  add row to table
                rows.add(TableRow(key: ValueKey(r), children: children));
              }

              //  get ready for the next row by clearing the row data
              children = List();
            }
          }

          _table = Table(
            defaultColumnWidth: IntrinsicColumnWidth(),
            children: rows,
          );
        }
      }
    }

    if (_appOptions.debug) {
      int i = 0;
      for (final TableRow tableRow in _table.children) {
        logger.v('rowkey:  ${tableRow.key.toString()}');
        int j = 0;
        for (final Widget widget in tableRow.children) {
          if (widget.key != null) {
            logger.i('\t\($i\,$j\)');
          }
          j++;
        }
        i++;
      }
    }

    {
      //  generate the rolled key list
      //  higher pitch on top
      //  lower pit on bottom

      if (keyDropDownMenuList == null) {
        const int steps = MusicConstants.halfStepsPerOctave;
        const int halfOctave = steps ~/ 2;
        ScaleNote firstScaleNote = song?.getSongMoment(0)?.measure?.chords[0]?.scaleChord?.scaleNote;
        if (firstScaleNote != null && song.key.getKeyScaleNote() == firstScaleNote) {
          firstScaleNote = null; //  not needed
        }
        List<music_key.Key> rolledKeyList = List(steps);

        List<music_key.Key> list = music_key.Key.keysByHalfStepFrom(song.key); //temp loc
        for (int i = 0; i <= halfOctave; i++) {
          rolledKeyList[i] = list[halfOctave - i];
        }
        for (int i = halfOctave + 1; i < steps; i++) {
          rolledKeyList[i] = list[steps - i + halfOctave];
        }

        keyDropDownMenuList = [];
        final double lyricsTextWidth = textWidth(context, lyricsTextStyle, "G"); //  something sane
        final String onString = '(on ';
        final double onStringWidth = textWidth(context, lyricsTextStyle, onString);

        for (int i = 0; i < steps; i++) {
          music_key.Key value = rolledKeyList[i];

          int relativeOffset = halfOctave - i;
          String valueString =
              value.toMarkup().padRight(2); //  fixme: required by pulldown list font bug!  (see the "on ..." below)
          String offsetString = '';
          if (relativeOffset > 0) {
            offsetString = '+${relativeOffset.toString()}';
          } else if (relativeOffset < 0) {
            offsetString = '${relativeOffset.toString()}';
          }

          keyDropDownMenuList.add(DropdownMenuItem<music_key.Key>(
              key: ValueKey(value.getHalfStep()),
              value: value,
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                SizedBox(
                  width: 2 * lyricsTextWidth, //  max width of chars expected
                  child: Text(
                    valueString,
                    style: lyricsTextStyle,
                    textAlign: TextAlign.left,
                  ),
                ),
                SizedBox(
                  width: 2 * lyricsTextWidth, //  max width of chars expected
                  child: Text(
                    offsetString,
                    style: lyricsTextStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                //  show the first note if it's not the same as the key
                if (firstScaleNote != null)
                  SizedBox(
                    width: onStringWidth + 3 * lyricsTextWidth, //  max width of chars expected
                    child: Text(
                      onString + '${firstScaleNote.transpose(value, relativeOffset).toMarkup()})',
                      style: lyricsTextStyle,
                      textAlign: TextAlign.right,
                    ),
                  )
              ])));
        }
      }

      if (bpmDropDownMenuList == null) {
        final int bpm = song.getBeatsPerMinute();

        bpmDropDownMenuList = List();
        for (int i = -60; i < 60; i++) {
          int value = bpm + i;
          if (value < 40) continue;
          bpmDropDownMenuList.add(
            DropdownMenuItem<int>(
              key: ValueKey(value),
              value: value,
              child: Text(
                value.toString().padLeft(3),
                style: lyricsTextStyle,
              ),
            ),
          );
          if (i < -30 || i > 30)
            i += 10 - 1; //  in addition to increment above
          else if (i < -5 || i > 5) i += 5 - 1; //  in addition to increment above
        }
      }
    }

    final double boxCenter = _screenOffset;
    final double boxHeight = _screenOffset;
    final double boxOffset = boxHeight / 2;

    final hoverColor = Colors.blue[700];

    return Scaffold(
      backgroundColor: Colors.white,
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _playerOnKey,
        autofocus: true,
        child: Stack(
          children: <Widget>[
            //  smooth background
            Positioned(
              top: boxCenter - boxOffset,
              child: Container(
                constraints: BoxConstraints.loose(Size(_screenWidth, boxHeight)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white,
                      Colors.blue[300],
                      Colors.blue[300],
                      Colors.white,
                    ],
                  ),
                ),
              ),
            ),
            //  tiny marker
            Positioned(
              top: boxCenter,
              child: Container(
                constraints: BoxConstraints.loose(Size(10, 4)),
                decoration: BoxDecoration(
                  color: Colors.black,
                ),
              ),
            ),
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.vertical,
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: TextDirection.ltr,
                  children: <Widget>[
                    if (!_isPlaying)
                      Column(
                        children: <Widget>[
                          AppBar(
                            //  let the app bar scroll off the screen for more room for the song
                            title: InkWell(
                              onTap: () {
                                openLink(_titleAnchor());
                              },
                              child: Text(
                                '${song.title}',
                                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                              ),
                              hoverColor: hoverColor,
                            ),
                            centerTitle: true,
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 16, right: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                InkWell(
                                  onTap: () {
                                    openLink(_artistAnchor());
                                  },
                                  child: Text(
                                    ' by  ${song.artist}',
                                    style: lyricsTextStyle,
                                  ),
                                  hoverColor: hoverColor,
                                ),
                                if (!_isTooNarrow)
                                  FlatButton.icon(
                                    padding: const EdgeInsets.all(8),
                                    color: Colors.lightBlue[300],
                                    hoverColor: hoverColor,
                                    icon: Icon(
                                      Icons.edit,
                                      size: fontSize,
                                    ),
                                    label: Text(''),
                                    onPressed: () {
                                      _navigateToEdit(context, song);
                                    },
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.only(left: 8, right: 24),
                                child: FlatButton.icon(
                                  color: Colors.lightBlue[300],
                                  hoverColor: hoverColor,
                                  icon: Icon(
                                    _playStopIcon,
                                    size: fontSize,
                                  ),
                                  label: Text(''),
                                  onPressed: () {
                                    _play();
                                  },
                                ),
                              ),
                              Text(
                                "Key: ",
                                style: lyricsTextStyle,
                              ),
                              if (!_isTooNarrow)
                                DropdownButton<music_key.Key>(
                                  items: keyDropDownMenuList,
                                  onChanged: (_value) {
                                    setState(() {
                                      _displaySongKey = _value;
                                      _forceTableRedisplay();
                                    });
                                  },
                                  value: _displaySongKey,
                                  style: TextStyle(
                                    //  size controlled by textScaleFactor above
                                    color: Colors.black87,
                                    textBaseline: TextBaseline.ideographic,
                                  ),
                                  iconSize: fontSize,
                                  itemHeight: 1.2 * kMinInteractiveDimension,
                                )
                              else
                                Text(
                                  _displaySongKey.toString(),
                                  style: lyricsTextStyle,
                                ),
                              Text(
                                "   BPM: ",
                                style: lyricsTextStyle,
                              ),
                              if (!_isTooNarrow)
                                DropdownButton<int>(
                                  items: bpmDropDownMenuList,
                                  onChanged: (_value) {
                                    setState(() {
                                      song.setBeatsPerMinute(_value);
                                      bpmDropDownMenuList = null; //  refresh to new value
                                      setState(() {});
                                    });
                                  },
                                  value: song.getBeatsPerMinute(),
                                  style: TextStyle(
                                    //  size controlled by textScaleFactor above
                                    color: Colors.black87,
                                    textBaseline: TextBaseline.ideographic,
                                  ),
                                  iconSize: fontSize,
                                  itemHeight: 1.2 * kMinInteractiveDimension,
                                )
                              else
                                Text(
                                  song.getBeatsPerMinute().toString(),
                                  style: lyricsTextStyle,
                                ),
                              Text(
                                "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}",
                                style: lyricsTextStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (_isPlaying)
                      SizedBox(
                        height: _screenOffset,
                      ),
                    Center(child: _table),
                    Text(
                      "Copyright: ${song.getCopyright()}",
                      style: lyricsTextStyle,
                    ),
                    if (_isPlaying)
                      SizedBox(
                        height: _screenOffset,
                      ),
                  ]),
            ),
          ],
        ),
      ),
      floatingActionButton: _isPlaying
          ? (_isPaused
              ? FloatingActionButton(
                  mini: _isTooNarrow,
                  onPressed: () {
                    _pauseToggle();
                  },
                  tooltip: 'Stop.  Space bar will continue the play.',
                  child: Icon(
                    Icons.play_arrow,
                    size: floatingActionSize,
                  ),
                )
              : FloatingActionButton(
                  mini: _isTooNarrow,
                  onPressed: () {
                    _stop();
                  },
                  tooltip: 'Stop the play.',
                  child: Icon(
                    Icons.stop,
                    size: floatingActionSize,
                  ),
                ))
          : (_scrollController.hasClients && _scrollController.offset > 0
              ? FloatingActionButton(
                  mini: _isTooNarrow,
                  onPressed: () {
                    _stop();
                    _scrollController.animateTo(0, duration: Duration(milliseconds: 333), curve: Curves.ease).then((_) {
                      logger.d('_scrollAnimationFuture complete');
                      setState(() {});
                    });
                  },
                  tooltip: 'Top',
                  child: Icon(
                    Icons.arrow_upward,
                    size: floatingActionSize,
                  ),
                )
              : FloatingActionButton(
                  mini: _isTooNarrow,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  tooltip: 'Back',
                  child: Icon(
                    Icons.arrow_back,
                    size: floatingActionSize,
                  ),
                )),
    );
  }

  void _playerOnKey(RawKeyEvent value) {
    if (value.runtimeType == RawKeyDownEvent) {
      RawKeyDownEvent e = value as RawKeyDownEvent;
      logger.i('_playerOnKey(): ${e.data.logicalKey}'
          ', ctl: ${e.isControlPressed}'
          ', shf: ${e.isShiftPressed}'
          ', alt: ${e.isAltPressed}');
      //  only deal with new key down events
      LogicalKeyboardKey logicalKeyboardKey = e.data.logicalKey;
      int keyId = e.data.logicalKey.keyId;
      // if (e.runtimeType != RawKeyDownEvent) {
      //   _keysDown.remove(keyId);
      //   return;
      // }
      // if (_keysDown.contains(keyId)) return;

      //  find the key to process
      LogicalKeyboardKey keyDown = e.data.logicalKey;

      //  process control space
      // if (_isPlaying == false &&
      //     keyId == LogicalKeyboardKey.space.keyId &&
      //     e.data.isControlPressed) {
      //   int t = DateTime.now().millisecondsSinceEpoch;
      //   int dt = t - lastTapToTime;
      //   if (dt > 60 / 40.0 * 1000) {
      //     //  minimum hertz in milliseconds per hertz
      //     //  reset the rolling average
      //     _tapRollingAverage.reset();
      //   } else if (dt > 0) {
      //     double bpm = _tapRollingAverage.roll(60 * 1000.0 / dt);
      //     int intBpm = max(40, min(200, bpm.round()));
      //     logger.d('roll: $intBpm');
      //     _player._setBpm(intBpm);
      //   }
      //
      //   lastTapToTime = t;
      //   return;
      // }

      //  cancel any other key processing pending
      // if (_debounce != null) {
      //   _debounce.cancel();
      // }

      logger.d('key: ${keyDown.toString()}');

      if (keyId == LogicalKeyboardKey.space.keyId) {
        if (!_isPlaying)
          _play();
        else {
          _RowLocation _rowLocation = _rowLocationAtPosition(_scrollController.offset);
          _rowLocationBump = (_rowLocation?.songMoment?.chordSection?.chordRowCount ?? 1);
          // _player._pauseToggle();
        }
        setState(() {});
      } else if (_isPlaying && !_isPaused && e.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
        logger.i('arrowDown @ $_rowLocationIndex');
        _rowLocationBump++;
      } else if (_isPlaying && !_isPaused && e.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
        logger.i('arrowUp @ $_rowLocationIndex');
        _rowLocationBump--;
      } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
        if (_isPlaying) {
          _stop();
        } else {
          Navigator.pop(context);
        }
      }
    }
  }

//  String _dt() {
//    int t = DateTime.now().millisecondsSinceEpoch;
//    String ret = ((t - _lastT) / 1000.0).toStringAsFixed(3);
//    _lastT = t;
//    return ret;
//  }

  IconData get _playStopIcon => _isPlaying ? Icons.stop : Icons.play_arrow;

  _play() {
    setState(() {
      _rowLocationIndex = 0;
      _scrollController.jumpTo(0);
      logger.d('animated play');
      _isPaused = false;
      _isPlaying = true;
      songMaster.playSong(widget.song);
    });
  }

  _stop() {
    setState(() {
      _isPlaying = false;
      _isPaused = true;
      _scrollController.jumpTo(0);
      songMaster.stop();
      logger.i('stop()');
    });
  }

  void _pauseToggle() {
    setState(() {
      if (_isPlaying) {
        _isPaused = !_isPaused;
        if (_isPaused) {
          songMaster.pause();
          _scrollController.jumpTo(_scrollController.offset);
        } else {
          songMaster.resume();
        }
      } else {
        songMaster.resume();
        _isPlaying = true;
        _isPaused = false;
      }
    });
  }

  String _titleAnchor() {
    return anchorUrlStart + Uri.encodeFull('${widget.song.title} ${widget.song.artist}');
  }

  String _artistAnchor() {
    return anchorUrlStart + Uri.encodeFull('${widget.song.artist}');
  }

  _navigateToEdit(BuildContext context, Song song) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: song)),
    );
  }

  void _setBpm(int bpm) {
    bpmDropDownMenuList = null;
    widget.song.setBeatsPerMinute(bpm);
    setState(() {});
  }

  void _forceTableRedisplay() {
    _table = null;
  }

  static final String anchorUrlStart = "https://www.youtube.com/results?search_query=";

  Ticker _ticker;
  static int _tickerCount = 0;
  int _lastTime = DateTime.now().millisecondsSinceEpoch;

  bool _isPlaying = false;
  bool _isPaused = false;

  bool _isTooNarrow = false;
  double _screenOffset;
  double _lastDy = 0;
  List<_RowLocation> _rowLocations;
  int _rowLocationIndex;
  int _rowLocationBump = 0;

  Table _table;
  music_key.Key _displaySongKey = music_key.Key.get(music_key.KeyEnum.C);
  List<DropdownMenuItem<music_key.Key>> keyDropDownMenuList;
  List<DropdownMenuItem<int>> bpmDropDownMenuList;

  SongMaster songMaster;
  ScrollController _scrollController = ScrollController();
  AppOptions _appOptions;
  double _defaultFontSize = 14.0; //  borrowed from Text widget
  static const double _defaultFontSizeMin = 14.0 - 5;
  static const double _defaultFontSizeMax = 14.0 + 5;

  static const double floatingActionSize = 50; //  inside the prescribed 56 pixel size
  final FocusNode _focusNode = FocusNode();
}

/// helper class to help manage a song display
class _RowLocation {
  _RowLocation(this.songMoment, this.row, this.globalKey, this._beats);

  @override
  String toString() {
    return ('${row.toString()} ${globalKey.toString()}'
        ', ${songMoment.toString()}'
        ', beats: ${beats.toString()}'
        // ', dispY: ${dispY.toStringAsFixed(1)}'
        // ', h: ${height.toStringAsFixed(1)}'
        ', b/h: ${pixelsPerBeat.toStringAsFixed(1)}');
  }

  void _computePixelsPerBeat() {
    if (_height != null && beats != null && beats > 0) _pixelsPerBeat = _height / beats;
  }

  final SongMoment songMoment;
  final GlobalKey globalKey;
  final int row;

  set beats(value) {
    _beats = value;
    _computePixelsPerBeat();
  }

  int get beats => _beats;
  int _beats;

  double dispY;

  set height(value) {
    _height = value;
    _computePixelsPerBeat();
  }

  double get height => _height;
  double _height;

  double get pixelsPerBeat => _pixelsPerBeat;
  double _pixelsPerBeat;
}
