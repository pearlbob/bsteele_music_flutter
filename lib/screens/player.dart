import 'dart:async';
import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as musicKey;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/SongMaster.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../main.dart';

final playerPageRoute = MaterialPageRoute(builder: (BuildContext context) => Player(selectedSong));
final RouteObserver<PageRoute> playerRouteObserver = RouteObserver<PageRoute>();

const _lightBlue = const Color(0xFF4FC3F7);
const _tooltipColor = const Color(0xFFE8F5E9);

bool _isCapo = false;
bool _playerIsOnTop = false;
SongUpdate? _songUpdate;
_Player? _player;

void playerUpdate(BuildContext context, SongUpdate songUpdate) {
  _songUpdate = songUpdate;

  if (!_playerIsOnTop) {
    Navigator.pushNamedAndRemoveUntil(
        context, Player.routeName, (route) => route.isFirst || route.settings.name == Player.routeName);
  }
  Timer(Duration(milliseconds: 2), () {
    // ignore: invalid_use_of_protected_member
    _player?.setState(() {});
  });

  //print('playerUpdate: ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}');
}

/// Display the song moments in sequential order.
// ignore: must_be_immutable
class Player extends StatefulWidget {
  Player(this.song, {Key? key}) : super(key: key);

  @override
  State<Player> createState() => _Player();

  Song song; //  fixme: not const due to song updates!

  static final String routeName = '/player';
}

class _Player extends State<Player> with RouteAware {
  _Player() {
    _player = this;
  }

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

    _setSelectedSongKey(widget.song.key);

    WidgetsBinding.instance?.scheduleWarmUpFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    playerRouteObserver.subscribe(this, playerPageRoute);
  }

  @override
  void didPush() {
    _playerIsOnTop = true;
    super.didPush();
  }

  @override
  void didPop() {
    _playerIsOnTop = false;
    super.didPop();
  }

  @override
  void didPopNext() {
    // Covering route was popped off the navigator.
    _playerIsOnTop = false;
  }

  @override
  void dispose() {
    _player = null;
    _playerIsOnTop = false;
    _songUpdate = null;
    playerRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _positionAfterBuild() {
    if (_songUpdate != null && _isPlaying) {
      _scrollToSectionByMoment(_songUpdate!.songMoment);
    }
  }

  @override
  Widget build(BuildContext context) {
    Song song = widget.song; //  default only

    //  deal with song updates
    if (_songUpdate != null) {
      if (!song.songBaseSameContent(_songUpdate!.song)) {
        song = _songUpdate!.song;
        widget.song = song;
        _table = null; //  force re-eval
        //print('new update song:  ${song.getSongMomentsSize()}');
        _play();
      } else {
        WidgetsBinding.instance?.addPostFrameCallback((_) {
          // executes after build
          _positionAfterBuild();
        });
      }
      _displaySongKey = _songUpdate!.currentKey;
    }

    _lyricsTable.computeScreenSizes();

    var _lyricsTextStyle = _lyricsTable.lyricsTextStyle;

    if (_table == null) {
      _table = _lyricsTable.lyricsTable(
        song,
        musicKey: _displaySongKey,
      );
      _rowLocations = _lyricsTable.rowLocations;
      _screenOffset = _lyricsTable.screenHeight / 2;
      _sectionLocations = null; //  clear any previous song cached data
    }

    // if (_appOptions.debug && _table != null) {
    //   int i = 0;
    //   for (final TableRow tableRow in _table!.children) {
    //     logger.v('rowkey:  ${tableRow.key.toString()}');
    //     int j = 0;
    //     for (final Widget widget in tableRow.children ?? []) {
    //       if (widget.key != null) {
    //         logger.i('\t\($i\,$j\)');
    //       }
    //       j++;
    //     }
    //     i++;
    //   }
    // }

    {
      //  generate the rolled key list
      //  higher pitch on top
      //  lower pit on bottom

      if (keyDropDownMenuList == null) {
        const int steps = MusicConstants.halfStepsPerOctave;
        const int halfOctave = steps ~/ 2;
        ScaleNote? firstScaleNote = song.getSongMoment(0)?.measure.chords[0].scaleChord.scaleNote;
        if (firstScaleNote != null && song.key.getKeyScaleNote() == firstScaleNote) {
          firstScaleNote = null; //  not needed
        }
        List<musicKey.Key?> rolledKeyList = List.generate(steps, (i) {
          return null;
        });

        List<musicKey.Key> list = musicKey.Key.keysByHalfStepFrom(song.key); //temp loc
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
          musicKey.Key value = rolledKeyList[i]!;

          int relativeOffset = halfOctave - i;
          String valueString =
              value.toMarkup().padRight(2); //  fixme: required by pulldown list font bug!  (see the "on ..." below)
          String offsetString = '';
          if (relativeOffset > 0) {
            offsetString = '+${relativeOffset.toString()}';
          } else if (relativeOffset < 0) {
            offsetString = '${relativeOffset.toString()}';
          }

          keyDropDownMenuList!.add(DropdownMenuItem<musicKey.Key>(
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
          bpmDropDownMenuList!.add(
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
                constraints: BoxConstraints.loose(Size(_lyricsTable.screenWidth, boxHeight)),
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
                child: SizedBox(
                  //width: _screenWidth*3/4,//  fixme: temp!!!!!!!!!!!!!!!!!
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
                                    style: TextStyle(fontSize: _lyricsTable.fontSize, fontWeight: FontWeight.bold),
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
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          primary: _lightBlue,
                                          padding: const EdgeInsets.all(8),
                                        ),
                                        child: Text(
                                          'Hints',
                                          style: _lyricsTextStyle,
                                        ),
                                        onPressed: () {},
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Capo',
                                          style: _lyricsTextStyle,
                                        ),
                                        Switch(
                                          onChanged: (value) {
                                            setState(() {
                                              _isCapo = !_isCapo;
                                              _setSelectedSongKey(_selectedSongKey);
                                            });
                                          },
                                          value: _isCapo,
                                        ),
                                        if (_isCapo && _capoLocation > 0)
                                          Text(
                                            'on $_capoLocation',
                                            style: _lyricsTextStyle,
                                          ),
                                        if (_isCapo && _capoLocation == 0)
                                          Text(
                                            'no capo needed',
                                            style: _lyricsTextStyle,
                                          ),
                                      ],
                                    ),
                                    if (isEditReady)
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.all(8),
                                          primary: _lightBlue,
                                        ),
                                        icon: Icon(
                                          Icons.edit,
                                          size: _lyricsTable.fontSize,
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
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          primary: _lightBlue,
                                        ),
                                        icon: Icon(
                                          _playStopIcon,
                                          size: _lyricsTable.fontSize,
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
                                  DropdownButton<musicKey.Key>(
                                    items: keyDropDownMenuList,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value != null) {
                                          _setSelectedSongKey(value);
                                        }
                                      });
                                    },
                                    value: _selectedSongKey,
                                    style: TextStyle(
                                      //  size controlled by textScaleFactor above
                                      color: Colors.black87,
                                      textBaseline: TextBaseline.ideographic,
                                    ),
                                    iconSize: _lyricsTable.fontSize,
                                    itemHeight: 1.2 * kMinInteractiveDimension,
                                  ),
                                  Text(
                                    "   BPM: ",
                                    style: _lyricsTextStyle,
                                  ),
                                  if (isScreenBig)
                                    DropdownButton<int>(
                                      items: bpmDropDownMenuList,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value != null) {
                                            song.setBeatsPerMinute(value);
                                            bpmDropDownMenuList = null; //  refresh to new value
                                            setState(() {});
                                          }
                                        });
                                      },
                                      value: song.getBeatsPerMinute(),
                                      style: TextStyle(
                                        //  size controlled by textScaleFactor above
                                        color: Colors.black87,
                                        textBaseline: TextBaseline.ideographic,
                                      ),
                                      iconSize: _lyricsTable.fontSize,
                                      itemHeight: 1.2 * kMinInteractiveDimension,
                                    )
                                  else
                                    Text(
                                      song.getBeatsPerMinute().toString(),
                                      style: _lyricsTextStyle,
                                    ),
                                  Text(
                                    "  Time: ${song.timeSignature}",
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
                ),
              ),
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
        logger.d('arrowDown');
        _sectionBump(1);
      } else if (_isPlaying &&
          !_isPaused &&
          (e.isKeyPressed(LogicalKeyboardKey.arrowUp) || e.isKeyPressed(LogicalKeyboardKey.arrowLeft))) {
        logger.d('arrowUp');
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

  _scrollToSectionByMoment(SongMoment? songMoment) {
    if (songMoment == null) {
      return;
    }

    _updateSectionLocations();

    if (_sectionLocations != null && _sectionLocations!.isNotEmpty) {
      double target =
          _sectionLocations![Util.limit(songMoment.lyricSection.index, 0, _sectionLocations!.length - 1) as int];
      if (_scrollController.offset != target) {
        _scrollController.animateTo(target, duration: Duration(milliseconds: 550), curve: Curves.ease);
        //print('_sectionByMomentNumber: $songMoment => section #${songMoment.lyricSection.index} => $target');
      }
    }
  }

  /// bump from one section to the next
  _sectionBump(int bump) {
    if (_rowLocations.isEmpty) {
      _sectionLocations = null;
      return;
    }

    if (!_scrollController.hasClients) {
      return; //  safety during initial configuration
    }

    _updateSectionLocations();

    if (_sectionLocations != null && _sectionLocations!.isNotEmpty) {
      //  find the best location for the current scroll position
      var sortedLocations = _sectionLocations!.where((e) => e >= _scrollController.offset).toList()..sort();
      if (sortedLocations.isNotEmpty) {
        double? target = sortedLocations.first;

        //  bump it by units of section
        int r = Util.limit(_sectionLocations!.indexOf(target) + bump, 0, _sectionLocations!.length - 1) as int;
        target = _sectionLocations![r];

        _scrollController.animateTo(target, duration: Duration(milliseconds: 550), curve: Curves.ease);
        // print('_sectionBump: bump: $bump, $r => $target');
      }
    }
  }

  _updateSectionLocations() {
    //  lazy update
    if (_scrollController.hasClients && _sectionLocations == null && _rowLocations.isNotEmpty) {
      //  initialize the section locations... after the initial rendering
      double? y0;
      ChordSection chordSection = _rowLocations[0]!.songMoment.chordSection;
      int sectionCount = 0;

      _sectionLocations = [];
      for (RowLocation? _rowLocation in _rowLocations) {
        if (_rowLocation == null) {
          continue;
        }
        if (chordSection == _rowLocation.songMoment.chordSection &&
            sectionCount == _rowLocation.songMoment.sectionCount) {
          continue; //  same section, no entry
        }
        chordSection = _rowLocation.songMoment.chordSection;
        sectionCount = _rowLocation.songMoment.sectionCount;

        GlobalKey key = _rowLocation.globalKey;
        double y = _scrollController.offset; //  safety
        {
          //  deal with possible missing render objects
          var renderObject = key.currentContext?.findRenderObject();
          if (renderObject != null && renderObject is RenderBox) {
            y = renderObject.localToGlobal(Offset.zero).dy;
          } else {
            _sectionLocations = null;
            return;
          }
        }
        y0 ??= y;
        y -= y0;
        _sectionLocations!.add(y);

        logger.d('${key.toString()}: $y');
      }

      //  add half of the deltas to center each selection
      {
        List<double> tmp = [];
        for (int i = 0; i < _sectionLocations!.length - 1; i++) {
          tmp.add(_sectionLocations![i + 1] //  start of the next section
              //  fixme when only flutter: (_sectionLocations![i] + _sectionLocations![i + 1]) / 2
          );
        }

        //  average the last with the end of the last
        GlobalKey key = _rowLocations.last!.globalKey;
        double y = _scrollController.offset; //  safety
        {
          //  deal with possible missing render objects
          var renderObject = key.currentContext?.findRenderObject();
          if (renderObject != null && renderObject is RenderBox) {
            y = renderObject.localToGlobal(Offset.zero).dy;
          } else {
            _sectionLocations = null;
            return;
          }
        }
        y0 ??= y;
        y -= y0;
        tmp.add((_sectionLocations![_sectionLocations!.length - 1] + y + (key.currentContext?.size?.height ?? 0)) / 2);
        _sectionLocations = tmp;  //  last location
      }
    }
  }

  IconData get _playStopIcon => _isPlaying ? Icons.stop : Icons.play_arrow;

  _play() {
    setState(() {
      _sectionBump(0);
      logger.d('play:');
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

  _setSelectedSongKey(musicKey.Key key) {
    _selectedSongKey = key;

    if (_isCapo) {
      _displaySongKey = key.capoKey;
      _capoLocation = key.capoLocation;
    } else {
      _displaySongKey = key;
    }

    _forceTableRedisplay();
  }

  /// helper function to generate tool tips
  Widget _playTooltip(String message, Widget child) {
    return Tooltip(
        message: message,
        child: child,
        textStyle: _lyricsTable.lyricsTextStyle,

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
    _playerIsOnTop = false;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: song)),
    );
    _playerIsOnTop = true;
  }

  void _forceTableRedisplay() {
    _sectionLocations = null;
    _table = null;
  }

  static final String anchorUrlStart = "https://www.youtube.com/results?search_query=";

  bool _isPlaying = false;
  bool _isPaused = false;

  double _screenOffset = 0;
  List<RowLocation?> _rowLocations = [];

  Table? _table;
  LyricsTable _lyricsTable = LyricsTable();
  musicKey.Key _selectedSongKey = musicKey.Key.get(musicKey.KeyEnum.C);
  musicKey.Key _displaySongKey = musicKey.Key.get(musicKey.KeyEnum.C);

  int _capoLocation = 0;
  List<DropdownMenuItem<musicKey.Key>>? keyDropDownMenuList;
  List<DropdownMenuItem<int>>? bpmDropDownMenuList;

  SongMaster songMaster = SongMaster();

  ScrollController _scrollController = ScrollController();

  //AppOptions _appOptions = AppOptions();

  // static const double _defaultFontSizeMin = defaultFontSize - 5;
  // static const double _defaultFontSizeMax = defaultFontSize + 5;

  final FocusNode _focusNode = FocusNode();
  List<double>? _sectionLocations;
}
