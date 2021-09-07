import 'dart:async';
import 'dart:collection';
import 'dart:ui';

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
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
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

/// Route identifier for this screen.
final playerPageRoute = MaterialPageRoute(builder: (BuildContext context) => Player(App().selectedSong));

/// An observer used to respond to a song update server request.
final RouteObserver<PageRoute> playerRouteObserver = RouteObserver<PageRoute>();

const _lightBlue = Color(0xFF4FC3F7);

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

/// A global function to be called to move the display to the player route with the correct song.
/// Typically this is called by the song update service when the application is in follower mode.
/// Note: This is an awkward move, given that it can happen at any time from any route.
/// Likely the implementation here will require adjustments.
void playerUpdate(BuildContext context, SongUpdate songUpdate) {
  logger.d('playerUpdate');

  if (!_playerIsOnTop) {
    Navigator.pushNamedAndRemoveUntil(
        context, Player.routeName, (route) => route.isFirst || route.settings.name == Player.routeName);
  }

  //  listen if anyone else is talking
  _player?._songUpdateService.isLeader = false;

  _songUpdate = songUpdate;
  if (!songUpdate.song.songBaseSameContent(_songUpdate?.song)) {
    _player?._adjustDisplay();
  }
  _lastSongUpdate = null;
  _player?._setSelectedSongKey(songUpdate.currentKey);

  Timer(const Duration(milliseconds: 2), () {
    // ignore: invalid_use_of_protected_member
    logger.d('playerUpdate timer');
    _player?._setPlayState();
  });

  logger.d('playerUpdate: ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}');
}

/// Display the song moments in sequential order.
/// Typically the chords will be grouped in lines.
// ignore: must_be_immutable
class Player extends StatefulWidget {
  Player(this._song, {Key? key}) : super(key: key);

  @override
  State<Player> createState() => _Player();

  Song _song; //  fixme: not const due to song updates!

  static const String routeName = '/player';
}

class _Player extends State<Player> with RouteAware, WidgetsBindingObserver {
  _Player() {
    _player = this;

    //  as leader, distribute current location
    _scrollController.addListener(() {
      logger.d('_scrollController.addListener()');
      if (_songUpdateService.isLeader) {
        var sectionTarget = _sectionIndexAtScrollOffset();
        if (sectionTarget != null) {
          LyricSection? lyricSection = _lyricSectionRowLocations[sectionTarget]?.lyricSection;
          if (lyricSection != null) {
            for (var songMoment in widget._song.songMoments) {
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

    _lastSize = WidgetsBinding.instance!.window.physicalSize;
    WidgetsBinding.instance!.addObserver(this);

    _displayKeyOffset = _app.displayKeyOffset;
    _setSelectedSongKey(widget._song.key);

    _leaderSongUpdate(0);

    // PlatformDispatcher.instance.onMetricsChanged=(){
    //   setState(() {
    //     //  deal with window size change
    //     logger.d('onMetricsChanged: ${DateTime.now()}');
    //   });
    // };

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
  void didChangeMetrics() {
    Size size = WidgetsBinding.instance!.window.physicalSize;
    if (size != _lastSize) {
      setState(() {
        _chordFontSize = null; //  take a shot at adjusting the display of chords and lyrics
        _lastSize = size;
      });
    }
  }

  @override
  void dispose() {
    _player = null;
    _playerIsOnTop = false;
    _songUpdate = null;
    playerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  void _positionAfterBuild() {
    logger.d('_positionAfterBuild():');
    if (_songUpdate != null && _isPlaying) {
      logger.d('_positionAfterBuild(): _scrollToSectionByMoment: ${_songUpdate!.songMoment?.momentNumber}');
      _scrollToSectionByMoment(_songUpdate!.songMoment);
    }

    //  look at the rendered table size
    if (_chordFontSize == null) {
      RenderObject? renderObject = (_table?.key as GlobalKey).currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderTable) {
        RenderTable renderTable = renderObject;
        var length = renderTable.size.width;
        if (length > 0 && _lyricsTable.chordFontSize != null) {
          var lastChordFontSize = _chordFontSize ?? 0;
          var fontSize = _lyricsTable.chordFontSize! * _app.screenInfo.widthInLogicalPixels / length;
          fontSize = Util.limit(fontSize, 8.0, 150.0) as double;

          if ((fontSize - lastChordFontSize).abs() > 1) {
            _chordFontSize = fontSize;

            setState(() {
              _table = null; //  rebuild table at new size
            });
            logger.d('table width: ${length.toStringAsFixed(1)}'
                '/${_app.screenInfo.widthInLogicalPixels.toStringAsFixed(1)}'
                ', sectionIndex = $_sectionIndex'
                ', chord fontSize: ${_lyricsTable.chordTextStyle.fontSize?.toStringAsFixed(1)}'
                ', lyrics fontSize: ${_lyricsTable.lyricsTextStyle.fontSize?.toStringAsFixed(1)}'
                ', _lyricsTable.chordFontSize: ${_lyricsTable.chordFontSize?.toStringAsFixed(1)}'
                ', _chordFontSize: ${_chordFontSize?.toStringAsFixed(1)} ='
                ' ${(100 * _chordFontSize! / _app.screenInfo.widthInLogicalPixels).toStringAsFixed(1)}vw');
          }
        }
      }
    } else {
      logger.d('_chordFontSize: ${_chordFontSize?.toStringAsFixed(1)} ='
          ' ${(100 * _chordFontSize! / _app.screenInfo.widthInLogicalPixels).toStringAsFixed(1)}vw');
    }
  }

  @override
  Widget build(BuildContext context) {
    appWidget.context = context; //	required on every build
    Song song = widget._song; //  default only

    //  deal with song updates
    if (_songUpdate != null) {
      if (!song.songBaseSameContent(_songUpdate!.song) || _displayKeyOffset != _app.displayKeyOffset) {
        song = _songUpdate!.song;
        widget._song = song;
        _table = null; //  force re-eval
        _chordFontSize == null;
        _play();
      }
      _setSelectedSongKey(_songUpdate!.currentKey);
    }
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      // executes after build
      _positionAfterBuild();
    });

    _displayKeyOffset = _app.displayKeyOffset;

    var _lyricsTextStyle = _lyricsTable.lyricsTextStyle;
    var _chordsTextStyle = _lyricsTable.chordTextStyle;
    var headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);
    logger.d('_lyricsTextStyle.fontSize: ${_lyricsTextStyle.fontSize}');

    const sectionCenterLocationFraction = 0.35;

    if (_table == null || _chordFontSize != _lyricsTable.chordFontSize) {
      _table = _lyricsTable.lyricsTable(song, context,
          musicKey: _displaySongKey, expandRepeats: !_appOptions.compressRepeats, chordFontSize: _chordFontSize);
      _lyricSectionRowLocations = _lyricsTable.lyricSectionRowLocations;
      _screenOffset = _centerSelections ? _lyricsTable.screenHeight * sectionCenterLocationFraction : 0;
      _sectionLocations.clear(); //  clear any previous song cached data
      logger.d('_table clear: index: $_sectionIndex');
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
                  style: headerTextStyle,
                  softWrap: false,
                  textAlign: TextAlign.left,
                ),
              ),
              SizedBox(
                width: 2 * chordsTextWidth, //  max width of chars expected
                child: Text(
                  offsetString,
                  style: headerTextStyle,
                  softWrap: false,
                  textAlign: TextAlign.right,
                ),
              ),
              //  show the first note if it's not the same as the key
              if (firstScaleNote != null)
                SizedBox(
                  width: onStringWidth + 4 * chordsTextWidth, //  max width of chars expected
                  child: Text(
                    onString + '${firstScaleNote.transpose(value, relativeOffset).toMarkup()})',
                    style: headerTextStyle,
                    softWrap: false,
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
              style: headerTextStyle,
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
    final showTopOfDisplay = !_isPlaying; //|| (_sectionLocations.isNotEmpty && _sectionTarget <= _sectionLocations[0]);
    logger.log(
        _playerLogScroll,
        'showTopOfDisplay: $showTopOfDisplay,'
        ' sectionTarget: $_sectionTarget, '
        ' _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}');
    logger.log(_playerLogMode, 'playing: $_isPlaying, pause: $_isPaused');

    var rawKeyboardListenerFocusNode = FocusNode();

    bool showCapo = !_appOptions.isSinger;

    var theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: RawKeyboardListener(
        focusNode: rawKeyboardListenerFocusNode,
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
                      theme.backgroundColor,
                      blue300,
                      blue300,
                      theme.backgroundColor,
                    ],
                  ),
                ),
              ),
            ),

            //  center marker
            if (_centerSelections)
              Positioned(
                top: boxCenter,
                child: Container(
                  constraints: BoxConstraints.loose(Size(_app.screenInfo.widthInLogicalPixels / 8, 6)),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                  ),
                ),
              ),
            if (_isPlaying && _isCapo)
              Text(
                'Capo ${_capoLocation == 0 ? 'not needed' : 'on $_capoLocation'}',
                style: headerTextStyle,
                softWrap: false,
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
                              appWidget.backBar(
                                //  let the app bar scroll off the screen for more screen for the song
                                titleWidget: appTooltip(
                                  message: 'Click to hear the song on youtube.com',
                                  child: InkWell(
                                    onTap: () {
                                      openLink(_titleAnchor());
                                    },
                                    child: Text(
                                      song.title,
                                      style: generateAppTextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: appbarColor(),
                                        backgroundColor: Colors.transparent,
                                      ),
                                    ),
                                    hoverColor: hoverColor,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.only(top: 16, right: 12),
                                child: appWrapFullWidth([
                                  appTooltip(
                                    message: 'Click to hear the artist on youtube.com',
                                    child: InkWell(
                                      onTap: () {
                                        openLink(_artistAnchor());
                                      },
                                      child: Text(
                                        ' by  ${song.artist}',
                                        style: headerTextStyle,
                                        softWrap: false,
                                      ),
                                      hoverColor: hoverColor,
                                    ),
                                  ),
                                  appTooltip(
                                    message: '''
Space bar or clicking the song area starts "play" mode.
    First section is in the middle of the display.
    Display items on the top will be missing.
Another space bar or song area hit advances one section.
Down or right arrow also advances one section.
Up or left arrow backs up one section.
Scrolling with the mouse wheel works as well.
Enter ends the "play" mode.
With escape, the app goes back to the play list.''',
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        primary: _lightBlue,
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      child: Text(
                                        'Hints',
                                        style: headerTextStyle,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ),
                                  if (showCapo)
                                    appWrap(
                                      [
                                        appTooltip(
                                          message: 'For a guitar, show the capo location and\n'
                                              'chords to match the current key.',
                                          child: Text(
                                            'Capo',
                                            style: headerTextStyle,
                                            softWrap: false,
                                          ),
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
                                            style: headerTextStyle,
                                            softWrap: false,
                                          ),
                                        if (_isCapo && _capoLocation == 0)
                                          Text(
                                            'no capo needed',
                                            style: headerTextStyle,
                                            softWrap: false,
                                          ),
                                      ],
                                    ),
                                  //  recommend blues harp
                                  Text(
                                    'Blues harp: ${_selectedSongKey.nextKeyByFifth()}',
                                    style: headerTextStyle,
                                    softWrap: false,
                                  ),
                                  if (_app.isEditReady)
                                    appTooltip(
                                      message: 'Edit the song',
                                      child: TextButton.icon(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.all(8),
                                          primary: Colors.green,
                                        ),
                                        icon: appIcon(
                                          Icons.edit,
                                          color: Colors.green, //  fixme:
                                        ),
                                        label: const Text(''),
                                        onPressed: () {
                                          _navigateToEdit(context, song);
                                        },
                                      ),
                                    ),
                                ], alignment: WrapAlignment.spaceBetween),
                              ),
                              appWrapFullWidth([
                                Container(
                                  padding: const EdgeInsets.only(left: 8, right: 8),
                                  child: appTooltip(
                                    message: 'Tip: Use the space bar to start playing.\n'
                                        'Use the space bar to advance the section while playing.',
                                    child: TextButton.icon(
                                      style: TextButton.styleFrom(
                                        primary: _isPlaying ? Colors.red : Colors.green, //fixme:
                                      ),
                                      icon: appIcon(
                                        _playStopIcon,
                                        color: Colors.green, //  fixme:
                                        size: 2 * _app.screenInfo.fontSize,   //  fixme: why is this required?
                                      ),
                                      label: const Text(''),
                                      onPressed: () {
                                        _isPlaying ? _stop() : _play();
                                      },
                                    ),
                                  ),
                                ),
                                appWrap([
                                  appTooltip(
                                    message: 'Transcribe the song to the selected key.',
                                    child: Text(
                                      'Key: ',
                                      style: headerTextStyle,
                                      softWrap: false,
                                    ),
                                  ),
                                  DropdownButton<music_key.Key>(
                                    items: _keyDropDownMenuList,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value != null) {
                                          _setSelectedSongKey(value);
                                          FocusScope.of(context).requestFocus(rawKeyboardListenerFocusNode);
                                        }
                                      });
                                    },
                                    value: _selectedSongKey,
                                    style: headerTextStyle,
                                    iconSize: lookupIconSize(),
                                    itemHeight: 1.2 * kMinInteractiveDimension,
                                  ),
                                  appSpace(
                                    space: 5,
                                  ),
                                  if (_displayKeyOffset > 0 || (showCapo && _isCapo && _capoLocation > 0))
                                    Text(
                                      '($_selectedSongKey' +
                                          (_displayKeyOffset > 0 ? '+$_displayKeyOffset' : '') +
                                          (_isCapo && _capoLocation > 0
                                              ? '-$_capoLocation'
                                              : '') //  indicate: "maps to"
                                          +
                                          '=$_displaySongKey)',
                                      style: _lyricsTextStyle,
                                    ),
                                ], alignment: WrapAlignment.spaceBetween),
                                appWrap([
                                  appTooltip(
                                    message: 'Beats per minute',
                                    child: Text(
                                      'BPM: ',
                                      style: headerTextStyle,
                                    ),
                                  ),
                                  if (_app.isScreenBig)
                                    DropdownButton<int>(
                                      items: _bpmDropDownMenuList,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            song.setBeatsPerMinute(value);
                                          });
                                        }
                                      },
                                      value: song.beatsPerMinute,
                                      style: headerTextStyle,
                                      iconSize: lookupIconSize(),
                                      itemHeight: 1.2 * kMinInteractiveDimension,
                                    )
                                  else
                                    Text(
                                      song.beatsPerMinute.toString(),
                                      style: _lyricsTextStyle,
                                    ),
                                ]),
                                appTooltip(
                                  message: 'time signature',
                                  child: Text(
                                    '  Time: ${song.timeSignature}',
                                    style: headerTextStyle,
                                    softWrap: false,
                                  ),
                                ),
                                Text(
                                  _songUpdateService.isConnected
                                      ? (_songUpdateService.isLeader
                                          ? 'I\'m the leader'
                                          : (_songUpdateService.leaderName == AppOptions.unknownUser
                                              ? ''
                                              : 'following ${_songUpdateService.leaderName}'))
                                      : '',
                                  style: headerTextStyle,
                                ),
                              ], alignment: WrapAlignment.spaceAround),
                            ],
                          )
                        else
                          SizedBox(
                            height: _screenOffset,
                          ),
                        Center(
                          child: _table ?? const Text('_table missing!'),
                        ),
                        Text(
                          'Copyright: ${song.copyright}',
                          style: headerTextStyle,
                        ),
                        Text(
                          'Last edit by: ${song.user}',
                          style: headerTextStyle,
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
            //  mask future sections for the leader to force them to stay on the current section
            //  this minimizes the errors seen by followers with smaller displays.
            if (_isPlaying && _songUpdateService.isLeader)
              Positioned(
                top: boxCenter + boxOffset,
                child: Container(
                  constraints: BoxConstraints.loose(
                      Size(_lyricsTable.screenWidth, _app.screenInfo.heightInLogicalPixels - boxHeight)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.grey.withAlpha(0),
                        Colors.grey[700] ?? Colors.grey,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _isPlaying
          ? (_isPaused
              ? appFloatingActionButton(
                  mini: !_app.isScreenBig,
                  onPressed: () {
                    _pauseToggle();
                  },
                  child: appTooltip(
                    message: 'Stop.  Space bar will continue the play.',
                    child: appIcon(
                      Icons.play_arrow,
                    ),
                    fontSize: headerTextStyle.fontSize,
                  ),
                )
              : appFloatingActionButton(
                  mini: !_app.isScreenBig,
                  onPressed: () {
                    _stop();
                  },
                  child: appTooltip(
                    message: 'Escape to stop the play\nor space to next section',
                    child: appIcon(
                      Icons.stop,
                    ),
                    fontSize: headerTextStyle.fontSize,
                  ),
                ))
          : (_scrollController.hasClients && _scrollController.offset > 0
              ? appFloatingActionButton(
                  mini: !_app.isScreenBig,
                  onPressed: () {
                    if (_isPlaying) {
                      _stop();
                    } else {
                      _scrollController.jumpTo(0);
                    }
                  },
                  child: appTooltip(
                    message: 'Top of song',
                    child: appIcon(
                      Icons.arrow_upward,
                    ),
                    fontSize: headerTextStyle.fontSize,
                  ),
                )
              : appFloatingActionButton(
                  mini: !_app.isScreenBig,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: appTooltip(
                    message: 'Back to song list',
                    child: appIcon(
                      Icons.arrow_back,
                    ),
                    fontSize: headerTextStyle.fontSize,
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
      _sectionIndex = Util.limit(songMoment.lyricSection.index, 0, _sectionLocations.length - 1) as int;
      double target = _sectionLocations[_sectionIndex];
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
      _scrollToSectionIndex(index);
    }
  }

  void _scrollToSectionIndex(int index) {
    _updateSectionLocations();

    _sectionIndex = index;
    var target = _sectionLocations[index];

    if (_targetSection(target)) {
      logger.log(
          _playerLogScroll,
          '_targetSectionIndex: $index ( $_sectionTarget px)'
          ', section: ${widget._song.lyricSections[index]}'
          ', sectionIndex: $_sectionIndex');
    }
  }

  bool _targetSection(double target) {
    if (_sectionTarget != target) {
      logger.d('_sectionTarget != target, $_sectionTarget != $target');
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
    logger.d('_updateSectionLocations(): empty: ${_sectionLocations.isEmpty}');

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

    _lastSongUpdate = SongUpdate.createSongUpdate(widget._song.copySong()); //  fixme: copy  required?
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
      songMaster.playSong(widget._song);
    });
  }

  /// Workaround to avoid calling setState() outside of the framework classes
  void _setPlayState() {
    setState(() {
      _player?._setPlayMode();
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
    if (!_appOptions.isSinger && _isCapo) {
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

  String _titleAnchor() {
    return anchorUrlStart + Uri.encodeFull('${widget._song.title} ${widget._song.artist}');
  }

  String _artistAnchor() {
    return anchorUrlStart + Uri.encodeFull(widget._song.artist);
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
      widget._song = _app.selectedSong;
    });
  }

  void _forceTableRedisplay() {
    _sectionLocations.clear();
    _table = null;
    logger.d('_forceTableRedisplay');
    setState(() {});
  }

  void _adjustDisplay() {
    _chordFontSize = null; //  take a shot at adjusting the display of chords and lyrics
  }

  bool almostEqual(double d1, double d2, double tolerance) {
    return (d1 - d2).abs() <= tolerance;
  }

  static const String anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  bool _isPlaying = false;
  bool _isPaused = false;

  double _screenOffset = 0;
  List<LyricSectionRowLocation?> _lyricSectionRowLocations = [];

  Table? _table;
  double? _chordFontSize;
  final LyricsTable _lyricsTable = LyricsTable();

  music_key.Key _displaySongKey = music_key.Key.get(music_key.KeyEnum.C);
  int _displayKeyOffset = 0;

  int _capoLocation = 0;
  final List<DropdownMenuItem<music_key.Key>> _keyDropDownMenuList = [];

  SongMaster songMaster = SongMaster();

  final ScrollController _scrollController = ScrollController();

  int _sectionIndex = 0; //  index for current lyric section
  double _sectionTarget = 0; //  targeted scroll position for lyric section
  List<double> _sectionLocations = [];

  late Size _lastSize;

  final AppWidget appWidget = AppWidget();

  static final _appOptions = AppOptions();
  final SongUpdateService _songUpdateService = SongUpdateService();
}
