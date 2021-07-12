import 'dart:async';
import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/SongMaster.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/app/appTextStyle.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

//  fixme: shapes in chromium?  circles become stop signs
//  fixme: compile to armv71

final playerPageRoute = MaterialPageRoute(builder: (BuildContext context) => Player(App().selectedSong));
final RouteObserver<PageRoute> playerRouteObserver = RouteObserver<PageRoute>();

const _lightBlue = Color(0xFF4FC3F7);
const _tooltipColor = Color(0xFFE8F5E9);

App _app = App();
bool _isCapo = false;
bool _playerIsOnTop = false;
SongUpdate? _songUpdate;
SongUpdate? _lastSongUpdate;
music_key.Key _selectedSongKey = music_key.Key.get(music_key.KeyEnum.C);
_Player? _player;
const _centerSelections = true; //fixme: add later!

const Level _playerLogScroll = Level.debug;
const Level _playerLogMode = Level.debug;
const Level _playerLogKeyboard = Level.debug;
const Level _playerLogMusicKey = Level.debug;

void playerUpdate(BuildContext context, SongUpdate songUpdate) {
  if (!_playerIsOnTop) {
    Navigator.pushNamedAndRemoveUntil(
        context, Player.routeName, (route) => route.isFirst || route.settings.name == Player.routeName);
  }

  //  listen if anyone else is talking
  _player?._songUpdateService.isLeader = false;

  _songUpdate = songUpdate;
  _lastSongUpdate = null;
  _player?._setSelectedSongKey(songUpdate.currentKey);

  Timer(const Duration(milliseconds: 2), () {
    // ignore: invalid_use_of_protected_member
    _player?.setState(() {
      _player?._setPlayMode();
    });
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

  static const String routeName = '/player';
}

class _Player extends State<Player> with RouteAware {
  _Player() {
    _player = this;

    _scrollController.addListener(() {
      if (_songUpdateService.isLeader) {
        var sectionTarget = _sectionIndexAtScrollOffset();
        if (sectionTarget != null) {
          LyricSection? lyricSection = _lyricSectionRowLocations[sectionTarget]?.lyricSection;
          if (lyricSection != null) {
            for (var songMoment in widget.song.songMoments) {
              if (songMoment.lyricSection == lyricSection) {
                _leaderSongUpdate(songMoment.momentNumber);
                break;
              }
            }
          }
        }
      }
    });
  }

  @override
  initState() {
    super.initState();

    // //  control font size with ctl+wheel
    // if (kIsWeb) {
    //   html.window.onMouseWheel.listen((event) {
    //     if (event.ctrlKey) {
    //       logger.d('event type: ${event.runtimeType.toString()},'
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

    _displayKeyOffset = _app.displayKeyOffset;
    _setSelectedSongKey(widget.song.key);

    _leaderSongUpdate(0);

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
      if (!song.songBaseSameContent(_songUpdate!.song) || _displayKeyOffset != _app.displayKeyOffset) {
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
      _setSelectedSongKey(_songUpdate!.currentKey);
    }
    _displayKeyOffset = _app.displayKeyOffset;

    _lyricsTable.computeScreenSizes();

    var _lyricsTextStyle = _lyricsTable.lyricsTextStyle;
    var _chordsTextStyle = _lyricsTable.chordTextStyle;
    logger.d('_lyricsTextStyle.fontSize: ${_lyricsTextStyle.fontSize}');

    const sectionCenterLocationFraction = 1.0 / 2;

    if (_table == null) {
      _table = _lyricsTable.lyricsTable(song, musicKey: _displaySongKey, expandRepeats: !_appOptions.compressRepeats);
      _lyricSectionRowLocations = _lyricsTable.lyricSectionRowLocations;
      _screenOffset = _centerSelections ? _lyricsTable.screenHeight * sectionCenterLocationFraction : 0;
      _sectionLocations.clear(); //  clear any previous song cached data
    }

    {
      //  generate the rolled key list
      //  higher pitch on top
      //  lower pit on bottom
      const int steps = MusicConstants.halfStepsPerOctave;
      const int halfOctave = steps ~/ 2;
      ScaleNote? firstScaleNote = song.getSongMoment(0)?.measure.chords[0].scaleChord.scaleNote;
      if (firstScaleNote != null && song.key.getKeyScaleNote() == firstScaleNote) {
        firstScaleNote = null; //  not needed
      }
      List<music_key.Key?> rolledKeyList = List.generate(steps, (i) {
        return null;
      });

      List<music_key.Key> list = music_key.Key.keysByHalfStepFrom(song.key); //temp loc
      for (int i = 0; i <= halfOctave; i++) {
        rolledKeyList[i] = list[halfOctave - i];
      }
      for (int i = halfOctave + 1; i < steps; i++) {
        rolledKeyList[i] = list[steps - i + halfOctave];
      }

      _keyDropDownMenuList.clear();
      final double chordsTextWidth = textWidth(context, _chordsTextStyle, 'G'); //  something sane
      const String onString = '(on ';
      final double onStringWidth = textWidth(context, _lyricsTextStyle, onString);

      for (int i = 0; i < steps; i++) {
        music_key.Key value = rolledKeyList[i] ?? _selectedSongKey;

        //  deal with the Gb/F# duplicate issue
        if (value.halfStep == _selectedSongKey.halfStep) {
          value = _selectedSongKey;
        }

        logger.log(_playerLogMusicKey, 'key value: $value');

        int relativeOffset = halfOctave - i;
        String valueString =
            value.toMarkup().padRight(2); //  fixme: required by drop down list font bug!  (see the "on ..." below)
        String offsetString = '';
        if (relativeOffset > 0) {
          offsetString = '+${relativeOffset.toString()}';
        } else if (relativeOffset < 0) {
          offsetString = relativeOffset.toString();
        }

        _keyDropDownMenuList.add(DropdownMenuItem<music_key.Key>(
            key: ValueKey(value.getHalfStep()),
            value: value,
            child: appWrap([
              SizedBox(
                width: 3 * chordsTextWidth, //  max width of chars expected
                child: Text(
                  valueString,
                  style: _chordsTextStyle,
                  textAlign: TextAlign.left,
                ),
              ),
              SizedBox(
                width: 2 * chordsTextWidth, //  max width of chars expected
                child: Text(
                  offsetString,
                  style: _chordsTextStyle,
                  textAlign: TextAlign.right,
                ),
              ),
              //  show the first note if it's not the same as the key
              if (firstScaleNote != null)
                SizedBox(
                  width: onStringWidth + 4 * chordsTextWidth, //  max width of chars expected
                  child: Text(
                    onString + '${firstScaleNote.transpose(value, relativeOffset).toMarkup()})',
                    style: _chordsTextStyle,
                    textAlign: TextAlign.right,
                  ),
                )
            ])));
      }
    }

    List<DropdownMenuItem<int>> _bpmDropDownMenuList = [];
    {
      final int bpm = song.beatsPerMinute;

      //  assure entries are unique
      SplayTreeSet<int> set = SplayTreeSet();
      set.add(bpm);
      for (int i = -60; i < 60; i++) {
        int value = bpm + i;
        if (value < 40) {
          continue;
        }
        set.add(value);
        if (i < -30 || i > 30) {
          i += 10 - 1;
        } else if (i < -5 || i > 5) {
          i += 5 - 1;
        } //  in addition to increment above
      }

      List<DropdownMenuItem<int>> bpmList = [];
      for (var value in set) {
        bpmList.add(
          DropdownMenuItem<int>(
            key: ValueKey(value),
            value: value,
            child: Text(
              value.toString().padLeft(3),
              style: _lyricsTextStyle,
            ),
          ),
        );
      }

      _bpmDropDownMenuList = bpmList;
    }

    final double boxCenter = _app.screenInfo.heightInLogicalPixels * sectionCenterLocationFraction;
    final double boxHeight = boxCenter * 2;
    final double boxOffset = boxCenter;

    final hoverColor = Colors.blue[700];
    const Color blue300 = Color(0xFF64B5F6);
    final showTopOfDisplay = !_isPlaying;//|| (_sectionLocations.isNotEmpty && _sectionTarget <= _sectionLocations[0]);
    logger.log(
        _playerLogScroll,
        'showTopOfDisplay: $showTopOfDisplay,'
        ' sectionTarget: $_sectionTarget, '
        ' _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}');
    logger.log(_playerLogMode, 'playing: $_isPlaying, pause: $_isPaused');

    return Scaffold(
      backgroundColor: Colors.white,
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _playerOnKey,
        autofocus: true,
        child: Stack(
          children: <Widget>[
            //  smooth background
            Positioned(
              top: boxCenter - boxOffset,
              child: Container(
                constraints: BoxConstraints.loose(Size(_lyricsTable.screenWidth, boxHeight)),
                decoration: const BoxDecoration(
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
            if (_centerSelections)
              Positioned(
                top: boxCenter,
                child: Container(
                  constraints: BoxConstraints.loose(const Size(10, 4)),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                ),
              ),
            GestureDetector(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: TextDirection.ltr,
                      children: <Widget>[
                        if (showTopOfDisplay)
                          Column(
                            children: <Widget>[
                              AppBar(
                                //  let the app bar scroll off the screen for more room for the song
                                title: InkWell(
                                  onTap: () {
                                    openLink(_titleAnchor());
                                  },
                                  child: Text(
                                    song.title,
                                    style: AppTextStyle(fontSize: _lyricsTable.fontSize, fontWeight: FontWeight.bold),
                                  ),
                                  hoverColor: hoverColor,
                                ),
                                centerTitle: true,
                              ),
                              Container(
                                padding: const EdgeInsets.only(top: 16, right: 12),
                                child: appWrapFullWidth([
                                  InkWell(
                                    onTap: () {
                                      openLink(_artistAnchor());
                                    },
                                    child: Text(
                                      ' by  ${song.artist}',
                                      style: _chordsTextStyle,
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
                                  appWrap(
                                    [
                                      Text(
                                        'Capo',
                                        style: _chordsTextStyle,
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
                                          style: _chordsTextStyle,
                                        ),
                                      if (_isCapo && _capoLocation == 0)
                                        Text(
                                          'no capo needed',
                                          style: _chordsTextStyle,
                                        ),
                                    ],
                                  ),
                                  if (_app.isEditReady)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.all(8),
                                        primary: Colors.green,
                                      ),
                                      icon: Icon(
                                        Icons.edit,
                                        size: _lyricsTable.fontSize,
                                      ),
                                      label: const Text(''),
                                      onPressed: () {
                                        _navigateToEdit(context, song);
                                      },
                                    ),
                                ], alignment: WrapAlignment.spaceBetween),
                              ),
                              appWrapFullWidth([
                                Container(
                                  padding: const EdgeInsets.only(left: 8, right: 8),
                                  child: _playTooltip(
                                    'Tip: use space bar to start playing',
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        primary: _isPlaying ? Colors.red : Colors.green,
                                      ),
                                      icon: Icon(
                                        _playStopIcon,
                                        size: 2 * _lyricsTable.fontSize,
                                      ),
                                      label: const Text(''),
                                      onPressed: () {
                                        _isPlaying ? _stop() : _play();
                                      },
                                    ),
                                  ),
                                ),
                                appWrap([
                                Text(
                                  'Key: ',
                                  style: _chordsTextStyle,
                                ),
                                DropdownButton<music_key.Key>(
                                  items: _keyDropDownMenuList,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        _setSelectedSongKey(value);
                                      }
                                    });
                                  },
                                  value: _selectedSongKey,
                                  style: _chordsTextStyle,
                                  iconSize: _lyricsTable.fontSize,
                                  itemHeight: 1.2 * kMinInteractiveDimension,
                                ),
                                const SizedBox(
                                  width: 5,
                                ),
                                if (_displayKeyOffset > 0 || (_isCapo && _capoLocation > 0))
                                  Text(
                                    '($_selectedSongKey' +
                                        (_displayKeyOffset > 0 ? '+$_displayKeyOffset' : '') +
                                        (_isCapo && _capoLocation > 0 ? '-$_capoLocation' : '') //  indicate: "maps to"
                                        +
                                        '=$_displaySongKey)',
                                    style: _lyricsTextStyle,
                                  ),], alignment: WrapAlignment.spaceBetween),
                                appWrap([
                                  Text(
                                    'BPM: ',
                                    style: _lyricsTextStyle,
                                  ),
                                  if (_app.isScreenBig)
                                    DropdownButton<int>(
                                      items: _bpmDropDownMenuList,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value != null) {
                                            song.setBeatsPerMinute(value);
                                            setState(() {});
                                          }
                                        });
                                      },
                                      value: song.beatsPerMinute,
                                      style: _chordsTextStyle,
                                      iconSize: _lyricsTable.fontSize,
                                      itemHeight: 1.2 * kMinInteractiveDimension,
                                    )
                                  else
                                    Text(
                                      song.beatsPerMinute.toString(),
                                      style: _lyricsTextStyle,
                                    ),
                                ]),
                                Text(
                                  '  Time: ${song.timeSignature}',
                                  style: _chordsTextStyle,
                                ),
                                  Text(
                                  _songUpdateService.isConnected
                                      ? (_songUpdateService.isLeader
                                          ? 'I\'m the leader'
                                          : (_songUpdateService.leaderName == AppOptions.unknownUser
                                              ? ''
                                              : 'following ${_songUpdateService.leaderName}'))
                                      : '',
                                  style: _lyricsTextStyle,
                                ),
                              ], alignment: WrapAlignment.spaceAround),
                            ],
                          )
                        else
                          SizedBox(
                            height: _screenOffset,
                          ),
                        Center(child: _table),
                        Text(
                          'Copyright: ${song.copyright}',
                          style: _lyricsTextStyle,
                        ),
                        Text(
                          'Last edit by: ${song.user}',
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
            if (_isPlaying && _isCapo)
              Text(
                'Capo ${_capoLocation == 0 ? 'not needed' : 'on $_capoLocation'}',
                style: _lyricsTextStyle,
              ),
          ],
        ),
      ),
      floatingActionButton: _isPlaying
          ? (_isPaused
              ? FloatingActionButton(
                  mini: !_app.isScreenBig,
                  onPressed: () {
                    _pauseToggle();
                  },
                  child: _playTooltip(
                    'Stop.  Space bar will continue the play.',
                    Icon(
                      Icons.play_arrow,
                      size: _lyricsTable.fontSize,
                    ),
                  ),
                )
              : FloatingActionButton(
                  mini: !_app.isScreenBig,
                  onPressed: () {
                    _stop();
                  },
                  child: _playTooltip(
                    'Escape to stop the play\nor space to next section',
                    Icon(
                      Icons.stop,
                      size: _lyricsTable.fontSize,
                    ),
                  ),
                ))
          : (_scrollController.hasClients && _scrollController.offset > 0
              ? FloatingActionButton(
                  mini: !_app.isScreenBig,
                  onPressed: () {
                    if (_isPlaying) {
                      _stop();
                    }
                  },
                  child: _playTooltip(
                    'Top of song',
                    Icon(
                      Icons.arrow_upward,
                      size: _lyricsTable.fontSize,
                    ),
                  ),
                )
              : FloatingActionButton(
                  mini: !_app.isScreenBig,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: _playTooltip(
                    'Back to song list',
                    Icon(
                      Icons.arrow_back,
                      size: _lyricsTable.fontSize,
                    ),
                  ))),
    );
  }

  void _playerOnKey(RawKeyEvent value) {
    if (value.runtimeType == RawKeyDownEvent) {
      RawKeyDownEvent e = value as RawKeyDownEvent;
      logger.log(
          _playerLogKeyboard,
          '_playerOnKey(): ${e.data.logicalKey}'
          ', ctl: ${e.isControlPressed}'
          ', shf: ${e.isShiftPressed}'
          ', alt: ${e.isAltPressed}');
      //  only deal with new key down events

      if (e.isKeyPressed(LogicalKeyboardKey.space) ||
              e.isKeyPressed(LogicalKeyboardKey.keyB) //  workaround for cheap foot pedal... only outputs b
          ) {
        if (!_isPlaying) {
          _play();
        } else {
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
          logger.d('pop the navigator');
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
    logger.log(_playerLogScroll, '_scrollToSectionByMoment( $songMoment )');
    if (songMoment == null) {
      return;
    }

    _updateSectionLocations();

    if (_sectionLocations.isNotEmpty) {
      double target =
          _sectionLocations[Util.limit(songMoment.lyricSection.index, 0, _sectionLocations.length - 1) as int];
      if (_targetSection(target)) {
        logger.log(_playerLogScroll,
            '_sectionByMomentNumber: $songMoment => section #${songMoment.lyricSection.index} => $target');
      }
    }
  }

  /// bump from one section to the next
  _sectionBump(int bump) {
    if (_lyricSectionRowLocations.isEmpty) {
      _sectionLocations.clear();
      return;
    }

    if (!_scrollController.hasClients) {
      return; //  safety during initial configuration
    }

    //  bump it by units of section
    var index = _sectionIndexAtScrollOffset();
    if (index != null) {
      index = Util.limit(index + bump, 0, _sectionLocations.length - 1) as int;
      var target = _sectionLocations[index];

      if (_targetSection(target)) {
        logger.log(
            _playerLogScroll,
            '_sectionBump: bump: $bump, $index ( $_sectionTarget px)'
            ', section: ${widget.song.lyricSections[index]}');
      }
    }
  }

  bool _targetSection(double target) {
    if (_sectionTarget != target) {
      setState(() {
        _sectionTarget = target;
        _scrollController.animateTo(target, duration: const Duration(milliseconds: 550), curve: Curves.ease);
      });
      return true;
    }
    return false;
  }

  int? _sectionIndexAtScrollOffset() {
    _updateSectionLocations();

    if (_sectionLocations.isNotEmpty) {
      //  find the best location for the current scroll position
      var sortedLocations = _sectionLocations.where((e) => e >= _scrollController.offset).toList()
        ..sort(); //  fixme: improve efficiency
      if (sortedLocations.isNotEmpty) {
        double target = sortedLocations.first;

        //  bump it by units of section
        return Util.limit(_sectionLocations.indexOf(target), 0, _sectionLocations.length - 1) as int;
      }
    }

    return null;
  }

  _updateSectionLocations() {
    //  lazy update
    if (_scrollController.hasClients && _sectionLocations.isEmpty && _lyricSectionRowLocations.isNotEmpty) {
      //  initialize the section locations... after the initial rendering
      double? y0;
      int sectionCount = -1; //  will never match the original, as intended

      _sectionLocations = [];
      for (LyricSectionRowLocation? _rowLocation in _lyricSectionRowLocations) {
        if (_rowLocation == null) {
          continue;
        }
        assert(sectionCount != _rowLocation.sectionCount);
        if (sectionCount == _rowLocation.sectionCount) {
          continue; //  same section, no entry
        }
        sectionCount = _rowLocation.sectionCount;

        GlobalKey key = _rowLocation.key;
        double y = _scrollController.offset; //  safety
        {
          //  deal with possible missing render objects
          var renderObject = key.currentContext?.findRenderObject();
          if (renderObject != null && renderObject is RenderBox) {
            y = renderObject.localToGlobal(Offset.zero).dy;
          } else {
            _sectionLocations.clear();
            return;
          }
        }
        y0 ??= y; //  initialize y0 to first y
        y -= y0;
        _sectionLocations.add(y);
      }
      logger.log(_playerLogScroll, 'raw _sectionLocations: $_sectionLocations');

      //  add half of the deltas to center each selection
      {
        List<double> tmp = [];
        for (int i = 0; i < _sectionLocations.length - 1; i++) {
          if (_centerSelections) {
            tmp.add((_sectionLocations[i] + _sectionLocations[i + 1]) / 2);
          } else {
            tmp.add(_sectionLocations[i]);
          }
        }

        //  average the last with the end of the last
        GlobalKey key = _lyricSectionRowLocations.last!.key;
        double y = _scrollController.offset; //  safety
        {
          //  deal with possible missing render objects
          var renderObject = key.currentContext?.findRenderObject();
          if (renderObject != null && renderObject is RenderBox) {
            y = renderObject.size.height;
          } else {
            _sectionLocations.clear();
            return;
          }
        }
        if (_table != null && _table?.key != null) {
          var globalKey = _table!.key as GlobalKey;
          logger.log(
              _playerLogScroll, '_table height: ${globalKey.currentContext?.findRenderObject()?.paintBounds.height}');
          var tableHeight = globalKey.currentContext?.findRenderObject()?.paintBounds.height ?? y;
          tmp.add((_sectionLocations[_sectionLocations.length - 1] + tableHeight) / 2);
        }

        //  not really required:
        // if (tmp.isNotEmpty) {
        //   tmp.first = 0; //  special for first song moment so it can show the header data
        // }

        _sectionLocations = tmp;
      }

      logger.log(_playerLogScroll, '_sectionLocations: $_sectionLocations');
    }
  }

  /// send a song update to the followers
  void _leaderSongUpdate(int momentNumber) {
    if (!_songUpdateService.isLeader) {
      _lastSongUpdate = null;
      return;
    }
    if (_lastSongUpdate != null) {
      if (_lastSongUpdate!.momentNumber == momentNumber && _lastSongUpdate!.currentKey == _selectedSongKey) {
        return;
      }
    }

    _lastSongUpdate = SongUpdate.createSongUpdate(widget.song.copySong()); //  fixme: copy  required?
    _lastSongUpdate!.currentKey = _selectedSongKey;
    _lastSongUpdate!.momentNumber = momentNumber;
    _lastSongUpdate!.user = _appOptions.user;
    _songUpdateService.issueSongUpdate(_lastSongUpdate!);
    logger.log(_playerLogScroll, '_leadSongUpdate: momentNumber: $momentNumber');
  }

  IconData get _playStopIcon => _isPlaying ? Icons.stop : Icons.play_arrow;

  _play() {
    setState(() {
      _setPlayMode();
      _sectionBump(0);
      logger.log(_playerLogMode, 'play:');
      songMaster.playSong(widget.song);
    });
  }

  _setPlayMode() {
    _isPaused = false;
    _isPlaying = true;
  }

  _stop() {
    setState(() {
      _isPlaying = false;
      _isPaused = true;
      _scrollController.jumpTo(0);
      songMaster.stop();
      logger.log(_playerLogMode, 'stop()');
    });
  }

  void _pauseToggle() {
    logger.log(_playerLogMode, '_pauseToggle():  pre: _isPlaying: $_isPlaying, _isPaused: $_isPaused');
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
    logger.log(_playerLogMode, '_pauseToggle(): post: _isPlaying: $_isPlaying, _isPaused: $_isPaused');
  }

  _setSelectedSongKey(music_key.Key key) {
    logger.log(_playerLogMusicKey, 'key: $key');

    //  add any offset
    music_key.Key newDisplayKey = music_key.Key.getKeyByHalfStep(key.halfStep + _displayKeyOffset);
    logger.log(_playerLogMusicKey, 'offsetKey: $newDisplayKey');

    //  deal with capo
    if (_isCapo) {
      _capoLocation = newDisplayKey.capoLocation;
      newDisplayKey = newDisplayKey.capoKey;
      logger.log(_playerLogMusicKey, 'capo: $newDisplayKey + $_capoLocation');
    }

    //  don't process unless there was a change
    if (_selectedSongKey == key && _displaySongKey == newDisplayKey) {
      return; //  no change required
    }
    _selectedSongKey = key;
    _displaySongKey = newDisplayKey;
    logger.v('_setSelectedSongKey(): _selectedSongKey: $_selectedSongKey, _displaySongKey: $_displaySongKey');

    _forceTableRedisplay();

    _leaderSongUpdate(0);
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
        padding: const EdgeInsets.all(8));
  }

  String _titleAnchor() {
    return anchorUrlStart + Uri.encodeFull('${widget.song.title} ${widget.song.artist}');
  }

  String _artistAnchor() {
    return anchorUrlStart + Uri.encodeFull(widget.song.artist);
  }

  _navigateToEdit(BuildContext context, Song song) async {
    _playerIsOnTop = false;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: song)),
    );
    _playerIsOnTop = true;
    setState(() {
      _table = null;
      widget.song = _app.selectedSong;
    });
  }

  void _forceTableRedisplay() {
    _sectionLocations.clear();
    _table = null;
    setState(() {});
  }

  static const String anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  bool _isPlaying = false;
  bool _isPaused = false;

  double _screenOffset = 0;
  List<LyricSectionRowLocation?> _lyricSectionRowLocations = [];

  Table? _table;
  final LyricsTable _lyricsTable = LyricsTable();

  music_key.Key _displaySongKey = music_key.Key.get(music_key.KeyEnum.C);
  int _displayKeyOffset = 0;

  int _capoLocation = 0;
  final List<DropdownMenuItem<music_key.Key>> _keyDropDownMenuList = [];

  SongMaster songMaster = SongMaster();

  final ScrollController _scrollController = ScrollController();

  double _sectionTarget = 0;
  List<double> _sectionLocations = [];
  static final _appOptions = AppOptions();
  final SongUpdateService _songUpdateService = SongUpdateService();
}
