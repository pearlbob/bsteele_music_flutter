import 'dart:math';
import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:bsteeleMusicLib/util/util.dart';

import 'package:bsteele_music_flutter/SongMaster.dart';
import 'package:bsteele_music_flutter/gui.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../appOptions.dart';
import '../main.dart';

/*

 */

const _lightBlue = const Color(0xFF4FC3F7);
const _tooltipColor = const Color(0xFFE8F5E9);

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

    // //  control font size with ctl+wheel
    // if (kIsWeb) {
    //   html.window.onMouseWheel.listen((event) {
    //     if (event.ctrlKey) {
    //       logger.i('event type: ${event.runtimeType.toString()},'
    //           ' d: ${event.deltaMode.toString()}'
    //           ' x: ${event.deltaX.toString()}'
    //           ' y: ${event.deltaY.toString()}'
    //           ' z: ${event.deltaZ.toString()}'
    //           //  ' ctl: ${event.ctrlKey.toString()}'
    //           '');
    //       event.preventDefault(); //  fixme: doesn't work
    //
    //       double newFontSize = defaultFontSize;
    //       if (event.deltaY < 0) {
    //         newFontSize++;
    //       } else if (event.deltaY > 0) {
    //         newFontSize--;
    //       }
    //       newFontSize = max(_defaultFontSizeMin, min(_defaultFontSizeMax, newFontSize));
    //       if (newFontSize != defaultFontSize) {
    //         logger.d('newFontSize: $newFontSize');
    //         setState(() {
    //           defaultFontSize = newFontSize;
    //           _forceTableRedisplay();
    //         });
    //       }
    //     }
    //   });
    // }
    _appOptions = AppOptions();

    _displaySongKey = widget.song.key ?? music_key.Key.getDefault();

    WidgetsBinding.instance?.scheduleWarmUpFrame();

    songMaster = SongMaster();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Song song = widget.song; //  convenience only

    double _screenWidth = screenInfo.widthInLogicalPixels;
    double _screenHeight = screenInfo.heightInLogicalPixels;
    _screenOffset = _screenHeight / 2;
    final double fontSize = isPhone ? defaultFontSize : defaultFontSize * min(5, max(1, _screenWidth / 650));
    final double fontScale = fontSize / defaultFontSize;
    logger.d(
        'player: ($_screenWidth,$_screenHeight), default:$defaultFontSize  => fontSize: $fontSize, fontScale: $fontScale');

    final double lyricsFontSize = fontSize * 0.75;

    final TextStyle chordTextStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize);
    _lyricsTextStyle = TextStyle(fontWeight: FontWeight.normal, fontSize: lyricsFontSize);

    if (_table == null) {
      logger.d("size: " + MediaQuery.of(context).size.toString());

      //  build the table from the song moment grid
      Grid<SongMoment> grid = song.songMomentGrid;
      _rowLocations = null;
      if (grid.isNotEmpty) {
        {
          _rowLocations = List.generate(grid.getRowCount(), (i) {
            return null;
          });
          List<TableRow> rows = [];
          List<Widget> children = [];
          Color color = GuiColors.getColorForSection(Section.get(SectionEnum.chorus));

          bool showChords = isScreenBig || _appOptions.playerDisplay;
          bool showFullLyrics = true; //fixme: too rash for a phone?  isScreenBig || !_appOptions.playerDisplay;

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

            GlobalKey<_Player> _rowKey = GlobalKey(debugLabel: 'rowLoc${r.toString()}');
            _rowLocations[r] = _RowLocation(firstSongMoment, r, _rowKey);

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

            if (momentLocation != null || !isScreenBig) {
              if (showFullLyrics) {
                //  lyrics
                children.add(Container(
                    margin: marginInsets,
                    padding: textPadding,
                    color: color,
                    child: Text(
                      rowLyrics.trimLeft(),
                      style: _lyricsTextStyle,
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
                      style: _lyricsTextStyle,
                      overflow: TextOverflow.ellipsis,
                    )));

                //  add row to table
                rows.add(TableRow(key: ValueKey(r), children: children));
              }

              //  get ready for the next row by clearing the row data
              children = [];
            }
          }

          _table = Table(
            defaultColumnWidth: IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
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
        for (final Widget widget in tableRow.children ?? []) {
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
        ScaleNote firstScaleNote = song.getSongMoment(0)?.measure?.chords[0]?.scaleChord?.scaleNote;
        if (firstScaleNote != null && song.key.getKeyScaleNote() == firstScaleNote) {
          firstScaleNote = null; //  not needed
        }
        List<music_key.Key> rolledKeyList = List.generate(steps, (i) {
          return null;
        });

        List<music_key.Key> list = music_key.Key.keysByHalfStepFrom(song.key); //temp loc
        for (int i = 0; i <= halfOctave; i++) {
          rolledKeyList[i] = list[halfOctave - i];
        }
        for (int i = halfOctave + 1; i < steps; i++) {
          rolledKeyList[i] = list[steps - i + halfOctave];
        }

        keyDropDownMenuList = [];
        final double lyricsTextWidth = textWidth(context, _lyricsTextStyle, 'G'); //  something sane
        final String onString = '(on ';
        final double onStringWidth = textWidth(context, _lyricsTextStyle, onString);

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
                    style: _lyricsTextStyle,
                    textAlign: TextAlign.left,
                  ),
                ),
                SizedBox(
                  width: 2 * lyricsTextWidth, //  max width of chars expected
                  child: Text(
                    offsetString,
                    style: _lyricsTextStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
                //  show the first note if it's not the same as the key
                if (firstScaleNote != null)
                  SizedBox(
                    width: onStringWidth + 3 * lyricsTextWidth, //  max width of chars expected
                    child: Text(
                      onString + '${firstScaleNote.transpose(value, relativeOffset).toMarkup()})',
                      style: _lyricsTextStyle,
                      textAlign: TextAlign.right,
                    ),
                  )
              ])));
        }
      }

      if (bpmDropDownMenuList == null) {
        final int bpm = song.getBeatsPerMinute();

        bpmDropDownMenuList = [];
        for (int i = -60; i < 60; i++) {
          int value = bpm + i;
          if (value < 40) continue;
          bpmDropDownMenuList.add(
            DropdownMenuItem<int>(
              key: ValueKey(value),
              value: value,
              child: Text(
                value.toString().padLeft(3),
                style: _lyricsTextStyle,
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
    const Color blue300 = Color(0xFF64B5F6);

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
                      blue300,
                      blue300,
                      Colors.white,
                    ],
                  ),
                ),
              ),
            ),
            //  put title and artist on top, behind the chords and lyrics
            // if (_isPlaying && false) //  no longer required
            //   Positioned(
            //     top: boxHeight / 3,
            //     left: _screenWidth / 3, //  fixed position
            //     child: Row(children: <Widget>[
            //       Text(
            //         song.title,
            //         style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
            //       ),
            //       Text(
            //         '  by  ',
            //       ),
            //       Text(
            //         song.artist,
            //         style: TextStyle(
            //           fontSize: lyricsFontSize,
            //         ),
            //       ),
            //     ]),
            //   ),
            //  tiny center marker
            Positioned(
              top: boxCenter,
              child: Container(
                constraints: BoxConstraints.loose(Size(10, 4)),
                decoration: BoxDecoration(
                  color: Colors.black,
                ),
              ),
            ),
            GestureDetector(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.vertical,
                child:
                SizedBox(
                  //width: _screenWidth*3/4,//  fixme: temp!!!!!!!!!!!!!!!!!
                  child:
                Column(
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
                                      style: _lyricsTextStyle,
                                    ),
                                    hoverColor: hoverColor,
                                  ),
                                  _playTooltip(
                                    '''
Space bar or clicking the song area starts "play" mode.
    First section is in the middle of the display.
    Display items on the top will be missing.
Another space bar or song area hit advances one section.
Down or right arrow also advances one section.
Up or left arrow backs up one section.
Scrolling with the mouse wheel works as well.
Enter ends the "play" mode.
With escape, the app goes back to the play list.''',
                                    FlatButton(
                                      padding: const EdgeInsets.all(8),
                                      color: _lightBlue,
                                      hoverColor: hoverColor,
                                      child: Text(
                                        'Hints',
                                        style: _lyricsTextStyle,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ),
                                  if (isEditReady)
                                    FlatButton.icon(
                                      padding: const EdgeInsets.all(8),
                                      color: _lightBlue,
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
                                  child: _playTooltip(
                                    'Tip: use space bar to start playing',
                                    FlatButton.icon(
                                      color: _lightBlue,
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
                                ),
                                Text(
                                  'Key: ',
                                  style: _lyricsTextStyle,
                                ),
                                DropdownButton<music_key.Key>(
                                  items: keyDropDownMenuList,
                                  onChanged: (_value) {
                                    setState(() {
                                      if ( _value != null ) {
                                        _displaySongKey = _value;
                                        _forceTableRedisplay();
                                      }
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
                                ),
                                Text(
                                  "   BPM: ",
                                  style: _lyricsTextStyle,
                                ),
                                if (isScreenBig)
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
                                    style: _lyricsTextStyle,
                                  ),
                                Text(
                                  "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}",
                                  style: _lyricsTextStyle,
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
                        style: _lyricsTextStyle,
                      ),
                      if (_isPlaying)
                        SizedBox(
                          height: _screenOffset,
                        ),
                    ]),
              ),),
              onTap: () {
                if (_isPlaying) {
                  _sectionBump(1);
                } else {
                  _play();
                }
              },
            ),
          ],
        ),
      ),
      floatingActionButton: _isPlaying
          ? (_isPaused
              ? FloatingActionButton(
                  mini: !isScreenBig,
                  onPressed: () {
                    _pauseToggle();
                  },
                  tooltip: 'Stop.  Space bar will continue the play.',
                  child: Icon(
                    Icons.play_arrow,
                  ),
                )
              : FloatingActionButton(
                  mini: !isScreenBig,
                  onPressed: () {
                    _stop();
                  },
                  child: _playTooltip(
                    'Escape to stop the play\nor space to next section',
                    Icon(
                      Icons.stop,
                    ),
                  ),
                ))
          : (_scrollController.hasClients && _scrollController.offset > 0
              ? FloatingActionButton(
                  mini: !isScreenBig,
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
                  ),
                )
              : FloatingActionButton(
                  mini: !isScreenBig,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  tooltip: 'Back',
                  child: Icon(
                    Icons.arrow_back,
                  ),
                )),
    );
  }

  void _playerOnKey(RawKeyEvent value) {
    if (value.runtimeType == RawKeyDownEvent) {
      RawKeyDownEvent e = value as RawKeyDownEvent;
      logger.d('_playerOnKey(): ${e.data.logicalKey}'
          ', ctl: ${e.isControlPressed}'
          ', shf: ${e.isShiftPressed}'
          ', alt: ${e.isAltPressed}');
      //  only deal with new key down events

      logger.d('key: ${e.data.logicalKey.toString()}');

      if (e.isKeyPressed(LogicalKeyboardKey.space) ||
              e.isKeyPressed(LogicalKeyboardKey.keyB) //  workaround for cheap foot pedal... only outputs b
          ) {
        if (!_isPlaying)
          _play();
        else {
          _sectionBump(1);
        }
      } else if (_isPlaying &&
          !_isPaused &&
          (e.isKeyPressed(LogicalKeyboardKey.arrowDown) || e.isKeyPressed(LogicalKeyboardKey.arrowRight))) {
        logger.d('arrowDown @ $_rowLocationIndex');
        _sectionBump(1);
      } else if (_isPlaying &&
          !_isPaused &&
          (e.isKeyPressed(LogicalKeyboardKey.arrowUp) || e.isKeyPressed(LogicalKeyboardKey.arrowLeft))) {
        logger.d('arrowUp @ $_rowLocationIndex');
        _sectionBump(-1);
      } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
        if (_isPlaying) {
          _stop();
        } else {
          logger.i('pop the navigator');
          Navigator.pop(context);
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.numpadEnter) || e.isKeyPressed(LogicalKeyboardKey.enter)) {
        if (_isPlaying) {
          _stop();
        }
      }
    }
  }

  /// bump from one section to the next
  _sectionBump(int bump) {
    if (_rowLocations?.isEmpty??true) {
      _sectionLocations = null;
      return;
    }
    if (_sectionLocations == null && _rowLocations.isNotEmpty) {
      //  initialize the section locations... after the initial rendering
      double y0;
      ChordSection chordSection = _rowLocations[0].songMoment.chordSection;
      int sectionCount = 0;

      _sectionLocations = [];
      for (_RowLocation _rowLocation in (_rowLocations??[])) {
        if ( _rowLocation == null ) continue;
        if (chordSection == _rowLocation.songMoment.chordSection &&
            sectionCount == _rowLocation.songMoment.sectionCount) {
          continue; //  same section, no entry
        }
        chordSection = _rowLocation.songMoment.chordSection;
        sectionCount = _rowLocation.songMoment.sectionCount;

        GlobalKey key = _rowLocation.globalKey;
        double y = (key.currentContext.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
        y0 ??= y;
        y -= y0;
        _sectionLocations.add(y);

        logger.d('${key.toString()}: $y');
      }

      //  add half of the deltas to center each selection
      {
        List<double> tmp = [];
        for (int i = 0; i < _sectionLocations.length - 1; i++) {
          tmp.add((_sectionLocations[i] + _sectionLocations[i + 1]) / 2);
        }

        //  average the last with the end of the last
        GlobalKey key = _rowLocations.last.globalKey;
        double y = (key.currentContext.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dy;
        y0 ??= y;
        y -= y0;
        tmp.add((_sectionLocations[_sectionLocations.length - 1] + y + key.currentContext.size.height) / 2);
        _sectionLocations = tmp;
      }
    }

    //  find the best location for the current scroll position
    double target = (_sectionLocations.where((e) => e >= _scrollController.offset).toList()..sort()).first;

    //  bump it by units of section
    target = _sectionLocations[Util.limit(_sectionLocations.indexOf(target) + bump, 0, _sectionLocations.length - 1) as int];

    _scrollController.animateTo(target, duration: Duration(milliseconds: 550), curve: Curves.ease);
    logger.d('_sectionSelection: $target');
  }

  IconData get _playStopIcon => _isPlaying ? Icons.stop : Icons.play_arrow;

  _play() {
    setState(() {
      _sectionBump(0);
      _rowLocationIndex = 0;
      logger.d('play');
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
      logger.d('stop()');
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

  /// helper function to generate tool tips
  Widget _playTooltip(String message, Widget child) {
    return Tooltip(
        message: message,
        child: child,
        textStyle: _lyricsTextStyle,

        //  fixme: why is this broken on web?
        //waitDuration: Duration(seconds: 1, milliseconds: 200),

        verticalOffset: 50,
        decoration: BoxDecoration(
            color: _tooltipColor,
            border: Border.all(),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            boxShadow: const [BoxShadow(color: Colors.grey, offset: Offset(8, 8), blurRadius: 10)]),
        padding: EdgeInsets.all(8));
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
    _sectionLocations = null;
    _table = null;
  }

  static final String anchorUrlStart = "https://www.youtube.com/results?search_query=";

  bool _isPlaying = false;
  bool _isPaused = false;

  double _screenOffset=0;
  List<_RowLocation> _rowLocations;
  int _rowLocationIndex=0;

  Table _table;
  music_key.Key _displaySongKey = music_key.Key.get(music_key.KeyEnum.C);
  List<DropdownMenuItem<music_key.Key>> keyDropDownMenuList;
  List<DropdownMenuItem<int>> bpmDropDownMenuList;

  SongMaster songMaster;
  ScrollController _scrollController = ScrollController();
  AppOptions _appOptions;

  // static const double _defaultFontSizeMin = defaultFontSize - 5;
  // static const double _defaultFontSizeMax = defaultFontSize + 5;

  final FocusNode _focusNode = FocusNode();
  TextStyle _lyricsTextStyle = TextStyle();
  List<double> _sectionLocations;
}

/// helper class to help manage a song display
class _RowLocation {
  _RowLocation(this.songMoment, this.row, this.globalKey);

  @override
  String toString() {
    return ('${row.toString()} ${globalKey.toString()}'
        ', ${songMoment.toString()}');
  }

  final SongMoment songMoment;
  final GlobalKey globalKey;
  final int row;
}
