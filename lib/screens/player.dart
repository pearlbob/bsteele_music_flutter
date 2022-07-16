import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/drumMeasure.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/ninjam.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/songs/songMoment.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:bsteele_music_flutter/widgets/drums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';
import '../main.dart';

/// Route identifier for this screen.
final playerPageRoute = MaterialPageRoute(builder: (BuildContext context) => Player(App().selectedSong));

//  intentionally global to share with singer screen    fixme?
music_key.Key? playerSelectedSongKey;
int? playerSelectedBpm;
String? playerSinger;

/// An observer used to respond to a song update server request.
final RouteObserver<PageRoute> playerRouteObserver = RouteObserver<PageRoute>();

//  player update workaround data
bool _playerIsOnTop = false;
SongUpdate? _songUpdate;
SongUpdate? _lastSongUpdateSent;
PlayerState? _player;
bool _isPlaying = false;
final LyricsTable _lyricsTable = LyricsTable();

bool _isCapo = false; //  package level for persistence across player invocations

DrumParts _drumParts = DrumParts(); //  temp

SongMoment? _selectedSongMoment;
List<Rect> _songMomentChordRectangles = [];

const int _minimumSpaceBarGapMs = 750; //  milliseconds

//  diagnostic logging enables
const Level _playerLogBuild = Level.debug;
const Level _playerLogScroll = Level.debug;
const Level _playerLogMode = Level.debug;
const Level _playerLogKeyboard = Level.debug;
const Level _playerLogMusicKey = Level.debug;
const Level _playerLogLeaderFollower = Level.debug;
const Level _playerLogFontResize = Level.debug;
const Level _playerLogBPM = Level.debug;
const Level _playerLogSongMaster = Level.debug;
const Level _logLocationGrid = Level.debug;

/// A global function to be called to move the display to the player route with the correct song.
/// Typically this is called by the song update service when the application is in follower mode.
/// Note: This is an awkward move, given that it can happen at any time from any route.
/// Likely the implementation here will require adjustments.
void playerUpdate(BuildContext context, SongUpdate songUpdate) {
  logger.log(
      _playerLogLeaderFollower,
      'playerUpdate(): start: ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}'
      ', pbm: ${songUpdate.currentBeatsPerMinute} vs ${songUpdate.song.beatsPerMinute}');

  if (!_playerIsOnTop) {
    Navigator.pushNamedAndRemoveUntil(
        context, Player.routeName, (route) => route.isFirst || route.settings.name == Player.routeName);
  }

  //  listen if anyone else is talking
  _player?.songUpdateService.isLeader = false;

  _songUpdate = songUpdate;
  if (!songUpdate.song.songBaseSameContent(_songUpdate?.song)) {
    _player?.adjustDisplay();
  }
  _lastSongUpdateSent = null;
  _player?.setSelectedSongKey(songUpdate.currentKey);
  playerSelectedBpm = songUpdate.currentBeatsPerMinute;

  Timer(const Duration(milliseconds: 2), () {
    // ignore: invalid_use_of_protected_member
    logger.log(_playerLogLeaderFollower, 'playerUpdate timer');
    _player?.setPlayState();
  });

  logger.log(
      _playerLogLeaderFollower,
      'playerUpdate(): end:   ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}'
      ', pbm: $playerSelectedBpm');
}

/// Display the song moments in sequential order.
/// Typically the chords will be grouped in lines.
// ignore: must_be_immutable
class Player extends StatefulWidget {
  Player(this._song, {super.key, music_key.Key? musicKey, int? bpm, String? singer}) {
    playerSelectedSongKey = musicKey; //  to be read later at initialization
    playerSelectedBpm = bpm ?? _song.beatsPerMinute;
    playerSinger = singer;

    logger.log(_playerLogBPM, 'Player(bpm: $playerSelectedBpm)');
  }

  @override
  State<Player> createState() => PlayerState();

  Song _song; //  fixme: not const due to song updates!

  static const String routeName = '/player';
}

class PlayerState extends State<Player> with RouteAware, WidgetsBindingObserver {
  PlayerState() {
    _player = this;

    //  as leader, distribute current location
    _scrollController.addListener(_scrollControllerListener);

    //  show the update service status
    songUpdateService.addListener(songUpdateServiceListener);

    //  show song master play updates
    _songMaster.addListener(songMasterListener);

    _rawKeyboardListenerFocusNode = FocusNode(onKey: playerOnKey);

    _isPlaying = false;
  }

  @override
  initState() {
    super.initState();

    lastSize = WidgetsBinding.instance.window.physicalSize;
    WidgetsBinding.instance.addObserver(this);

    displayKeyOffset = app.displayKeyOffset;
    _song = widget._song;
    setSelectedSongKey(playerSelectedSongKey ?? _song.key);
    playerSelectedBpm = playerSelectedBpm ?? _song.beatsPerMinute;
    _selectedSongMoment = null;

    logger.log(_playerLogBPM, 'initState() bpm: $playerSelectedBpm');

    leaderSongUpdate(-1);

    // PlatformDispatcher.instance.onMetricsChanged=(){
    //   setState(() {
    //     //  deal with window size change
    //     logger.d('onMetricsChanged: ${DateTime.now()}');
    //   });
    // };

    WidgetsBinding.instance.scheduleWarmUpFrame();

    app.clearMessage();
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
    Size size = WidgetsBinding.instance.window.physicalSize;
    if (size != lastSize) {
      setState(() {
         _table = null;
        lastSize = size;
      });
    }
  }

  @override
  void dispose() {
    logger.d('player: dispose()');
    _cancelIdleTimer();
    _player = null;
    _playerIsOnTop = false;
    _songUpdate = null;
    _scrollController.removeListener(_scrollControllerListener);
    songUpdateService.removeListener(songUpdateServiceListener);
    _songMaster.removeListener(songMasterListener);
    playerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scrollControllerListener() {
    _resetIdleTimer();

    logger.log(
        _playerLogScroll,
        'scrollControllerListener: ${_scrollController.offset}'
        ', section: ${sectionIndexAtScrollOffset()}');
  }

  void _scrollControllerCompletionCallback() {
    //  worry about when to update the floating button
    bool scrollIsZero = _scrollController.offset == 0; //  no check for has client in a client!... we are the client
    if (scrollWasZero != scrollIsZero) {
      setState(() {
        logger.log(_playerLogScroll, 'scrollWasZero != scrollIsZero: $scrollWasZero vs. $scrollIsZero');
      });
    }
    scrollWasZero = scrollIsZero;

    //  follow the leader
    if (_songMomentChordRectangles.isNotEmpty) {
      double stopAt = max(_songMomentChordRectangles.last.bottom - boxCenter, 0);
      if (_scrollController.offset > stopAt) {
        //  cancels any animation
        logger.log(_playerLogScroll, 'scrollController.offset stop at: $stopAt');
        _scrollController.jumpTo(stopAt);
      }

      //  follow the leader's scroll
      if (_table != null && songUpdateService.isLeader && !_isPlaying) {
        RenderObject? renderObject = (_table?.key as GlobalKey).currentContext?.findRenderObject();
        assert(renderObject != null && renderObject is RenderTable);
        RenderTable renderTable = renderObject as RenderTable;

        BoxHitTestResult result = BoxHitTestResult();
        Offset position = Offset(20, boxCenter + _scrollController.offset);
        if (renderTable.hitTestChildren(result, position: position)) {
          logger.log(_playerLogScroll, '_scrollControllerListener(): hitTest $position: ${result.path.last}');
          assert(_songMomentChordRectangles.length == _song.songMoments.length);

          //  find the moment past the marker
          var rect = _songMomentChordRectangles.firstWhere((rect) => rect.bottom >= position.dy,
              orElse: () => _songMomentChordRectangles.last);
          var songMomentIndex = _songMomentChordRectangles.indexOf(rect);
          setSelectedSongMoment(_song.songMoments[songMomentIndex]); //  leader distribution done here
        }
      }
    }
  }

  //  update the song update service status
  void songUpdateServiceListener() {
    logger.log(_playerLogLeaderFollower, 'songUpdateServiceListener():');
    setState(() {});
  }

  void songMasterListener() {
    logger.log(
        _playerLogSongMaster,
        'songMasterListener:  leader: ${songUpdateService.isLeader}  ${DateTime.now()}'
        ', moment: ${_songMaster.momentNumber}');

    if (_songMaster.momentNumber != null) {
      var songMoment = _song.getSongMoment(_songMaster.momentNumber!);
      if (songMoment != null && _selectedSongMoment != songMoment) {
        setState(() {
          {
            setSelectedSongMoment(songMoment);
            // _selectedSongMoment = _song.getSongMoment(songMaster.momentNumber!);
            // setTargetYToSongMoment(_selectedSongMoment);
            // leaderSongUpdate(songMaster.momentNumber!);
          }
          //logger.i('songMaster event:  $_selectedSongMoment');
        });
      }
    } else if (_isPlaying != _songMaster.isPlaying) {
      setState(() {
        _isPlaying = _songMaster.isPlaying;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _resetIdleTimer();
    app.screenInfo.refresh(context);
    appWidgetHelper = AppWidgetHelper(context);
    _song = widget._song; //  default only

    logger.log(
        _playerLogBuild, 'player build: $_song, selectedSongMoment: $_selectedSongMoment, isPlaying: $_isPlaying');

    //  deal with song updates
    if (_songUpdate != null) {
      if (!_song.songBaseSameContent(_songUpdate!.song) || displayKeyOffset != app.displayKeyOffset) {
        _song = _songUpdate!.song;
        widget._song = _song;
        adjustDisplay();
        if (_songUpdate!.state == SongUpdateState.playing) {
          performPlay();
        } else {
          simpleStop();
        }
      }
      setSelectedSongKey(_songUpdate!.currentKey);
    }

    displayKeyOffset = app.displayKeyOffset;

    final lyricsTextStyle = _lyricsTable.lyricsTextStyle;

    logger.log(_playerLogBuild, '_lyricsTextStyle.fontSize: ${lyricsTextStyle.fontSize?.toStringAsFixed(2)}');

    if (_selectedSongMoment == null) {
      //  fixme
      setSelectedSongMoment(_song.songMoments.first);
    }

    if (_table == null) {
      logger.log(_playerLogBuild, 'table rebuild: selectedSongMoment: $_selectedSongMoment');

      _table = _lyricsTable.lyricsTable(
        _song, context,
        musicKey: _displaySongKey,
        expanded: !compressRepeats,
        lyricsFraction: _lyricsFraction ?? (appOptions.userDisplayStyle == UserDisplayStyle.player ? 0.20 : 0.35),
        //  givenSelectedSongMoments: selectedSongMoments
      );
      sectionLocations.clear(); //  clear any previous song cached data
      _songMomentChordRectangles.clear();
    }

    final fontSize = _lyricsTable.lyricsFontSize;
    headerTextStyle = headerTextStyle.copyWith(fontSize: fontSize);

    final List<DropdownMenuItem<music_key.Key>> keyDropDownMenuList = [];
    {
      //  generate the rolled key list
      //  higher pitch on top
      //  lower pit on bottom
      const int steps = MusicConstants.halfStepsPerOctave;
      const int halfOctave = steps ~/ 2;
      ScaleNote? firstScaleNote = _song.getSongMoment(0)?.measure.chords[0].scaleChord.scaleNote;
      if (firstScaleNote != null && _song.key.getKeyScaleNote() == firstScaleNote) {
        firstScaleNote = null; //  not needed
      }
      List<music_key.Key?> rolledKeyList = List.generate(steps, (i) {
        return null;
      });

      List<music_key.Key> list = music_key.Key.keysByHalfStepFrom(_song.key); //temp loc
      for (int i = 0; i <= halfOctave; i++) {
        rolledKeyList[i] = list[halfOctave - i];
      }
      for (int i = halfOctave + 1; i < steps; i++) {
        rolledKeyList[i] = list[steps - i + halfOctave];
      }

      final double chordsTextWidth = textWidth(context, headerTextStyle, 'G'); //  something sane
      const String onString = '(on ';
      final double onStringWidth = textWidth(context, lyricsTextStyle, onString);

      for (int i = 0; i < steps; i++) {
        music_key.Key value = rolledKeyList[i] ?? _selectedSongKey;

        //  deal with the Gb/F# duplicate issue
        if (value.halfStep == _selectedSongKey.halfStep) {
          value = _selectedSongKey;
        }

        //logger.log(_playerLogMusicKey, 'key value: $value');

        int relativeOffset = halfOctave - i;
        String valueString =
            value.toMarkup().padRight(2); //  fixme: required by drop down list font bug!  (see the "on ..." below)
        String offsetString = '';
        if (relativeOffset > 0) {
          offsetString = '+${relativeOffset.toString()}';
        } else if (relativeOffset < 0) {
          offsetString = relativeOffset.toString();
        }

        keyDropDownMenuList.add(appDropdownMenuItem<music_key.Key>(
            appKeyEnum: AppKeyEnum.playerMusicKey,
            value: value,
            child: AppWrap(children: [
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
              if (app.isScreenBig && firstScaleNote != null)
                SizedBox(
                  width: onStringWidth + 4 * chordsTextWidth,
                  //  max width of chars expected
                  child: Text(
                    '$onString${firstScaleNote.transpose(value, relativeOffset).toMarkup()})',
                    style: headerTextStyle,
                    softWrap: false,
                    textAlign: TextAlign.right,
                  ),
                )
            ])));
      }
    }

    List<DropdownMenuItem<int>> bpmDropDownMenuList = [];
    {
      final int bpm = playerSelectedBpm ?? _song.beatsPerMinute;

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
          appDropdownMenuItem<int>(
            appKeyEnum: AppKeyEnum.playerBPM,
            value: value,
            child: Text(
              value.toString().padLeft(3),
              style: headerTextStyle,
            ),
          ),
        );
      }

      bpmDropDownMenuList = bpmList;
    }

    boxCenter = boxCenterHeight();
    final double boxOffset = boxCenter;

    final hoverColor = Colors.blue[700]; //  fixme with css

    logger.log(
        _playerLogScroll,
        ' sectionTarget: $scrollTarget, '
        ' _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}');
    logger.log(_playerLogMode, 'playing: $_isPlaying, pause: $_isPaused');

    bool showCapo = capoIsAvailable() && app.isScreenBig;
    _isCapo = _isCapo && showCapo; //  can't be capo if you cannot show it

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

    if (appOptions.ninJam) {
      _ninJam =
          NinJam(_song, key: _displaySongKey, keyOffset: _displaySongKey.getHalfStep() - _song.getKey().getHalfStep());
    }

    // var showBeatWidget = const ShowBeatWidget();

    return RawKeyboardListener(
      focusNode: _rawKeyboardListenerFocusNode,
      autofocus: true,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: theme.backgroundColor,
            appBar: appWidgetHelper.backBar(
                titleWidget: AppTooltip(
                  message: 'Click to hear the song on youtube.com',
                  child: InkWell(
                    onTap: () {
                      openLink(titleAnchor());
                    },
                    hoverColor: hoverColor,
                    child: Text(
                      _song.titleWithCover,
                      style: appBarTextStyle,
                    ),
                  ),
                ),
                actions: <Widget>[
                  AppTooltip(
                    message: 'Click to hear the artist on youtube.com',
                    child: InkWell(
                      onTap: () {
                        openLink(artistAnchor());
                      },
                      hoverColor: hoverColor,
                      child: Text(
                        ' by  ${_song.artist}',
                        style: appBarTextStyle,
                        softWrap: false,
                      ),
                    ),
                  ),
                  if (playerSinger != null)
                    Text(
                      ', sung by $playerSinger',
                      style: appBarTextStyle,
                      softWrap: false,
                    ),
                  if (_isPlaying && _isCapo)
                    Text(
                      ',  Capo ${_capoLocation == 0 ? 'not needed' : 'on $_capoLocation'}',
                      style: appBarTextStyle,
                      softWrap: false,
                    ),
                  const AppSpace(),
                ],
                onPressed: () {
                  _songMaster
                      .removeListener(songMasterListener); //  avoid race condition with the listener notification
                  _songMaster.stop();
                }),
            body: Stack(
              children: <Widget>[
                //  smooth background
                Positioned(
                  top: boxCenter - boxOffset,
                  child: Container(
                    constraints: BoxConstraints.loose(Size(_lyricsTable.screenWidth, app.screenInfo.mediaHeight)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          theme.backgroundColor,
                          measureContainerBackgroundColor(),
                          measureContainerBackgroundColor(),
                          measureContainerBackgroundColor(),
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
                      constraints: BoxConstraints.loose(Size(app.screenInfo.mediaWidth / 64, 6)),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                      ),
                    ),
                  ),

                GestureDetector(
                  onTapDown: (details) {
                    if (!_isPlaying && appOptions.userDisplayStyle != UserDisplayStyle.proPlayer) {
                      //  don't respond above the player song table     fixme: this is likely not the best
                      RenderFlex renderObject = (_table?.key as GlobalKey).currentContext?.findRenderObject()
                          as RenderFlex; //  fixme: a presumption

                      if (details.globalPosition.dy > renderObject.localToGlobal(Offset.zero).dy) {
                        if (details.globalPosition.dy > app.screenInfo.mediaHeight / 2) {
                          sectionBump(1); //  fixme: when not in play
                        } else {
                          sectionBump(-1); //  fixme: when not in play
                        }
                      }
                    }
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      child: Stack(children: [
                        if (appOptions.userDisplayStyle != UserDisplayStyle.proPlayer)
                          CustomPaint(
                            painter: _ChordHighlightPainter(), //  fixme: optimize with builder
                            isComplex: true,
                            willChange: false,
                            child: SizedBox(
                              width: app.screenInfo.mediaWidth,
                              height: max(app.screenInfo.mediaHeight, 200), // fixme: temp
                            ),
                          ),

                        //  diagnostic for location grid
                        if (kDebugMode && _logLocationGrid.index >= Level.info.index)
                          CustomPaint(
                            painter: _LocationGridDebugPainter(), //  fixme: optimize with builder
                            isComplex: true,
                            willChange: false,
                            child: SizedBox(
                              width: app.screenInfo.mediaWidth,
                              height: max(app.screenInfo.mediaHeight, 200), // fixme: temp
                            ),
                          ),

                        Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            textDirection: TextDirection.ltr,
                            children: <Widget>[
                              if (app.message.isNotEmpty)
                                Container(
                                    padding: const EdgeInsets.all(6.0),
                                    child: app.messageTextWidget(AppKeyEnum.playerErrorMessage)),
                              Container(
                                padding: const EdgeInsets.all(12),
                                child: AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
                                  //  hints
                                  AppTooltip(
                                    message: '''
Space bar or clicking the song area starts "play" mode.
    Selected section is in the top or middle of the display.
Another space bar or song area hit advances one section.
Down or right arrow also advances one section.
Up or left arrow backs up one section.
Scrolling with the mouse wheel works as well.
Enter ends the "play" mode.
With escape, the app goes back to the play list.''',
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      child: Text(
                                        'Hints',
                                        style: headerTextStyle,
                                      ),
                                      onPressed: () {},
                                    ),
                                  ),
                                  beatStatefulWidget,
                                  if (showCapo)
                                    AppWrap(
                                      children: [
                                        if (_isCapo && _capoLocation > 0)
                                          Text(
                                            'Capo on $_capoLocation',
                                            style: headerTextStyle,
                                            softWrap: false,
                                          ),
                                        if (_isCapo && _capoLocation == 0)
                                          Text(
                                            'No capo needed',
                                            style: headerTextStyle,
                                            softWrap: false,
                                          ),
                                      ],
                                    ),
                                  // //  recommend a blues harp
                                  // Text(
                                  //   'Blues harp: ${selectedSongKey.nextKeyByFifth()}',
                                  //   style: headerTextStyle,
                                  //   softWrap: false,
                                  // ),

                                  AppWrap(children: [
                                    if (app.isScreenBig)
                                      AppWrap(children: [
                                        //  fixme: there should be a better way.  wrap with flex?
                                        AppTooltip(
                                          message: 'Back to the previous song in the list',
                                          child: appIconButton(
                                            appKeyEnum: AppKeyEnum.playerPreviousSong,
                                            icon: appIcon(
                                              Icons.navigate_before,
                                            ),
                                            onPressed: () {
                                              widget._song = previousSongInTheList();
                                              _song = widget._song;
                                              setSelectedSongKey(_song.key);
                                              _selectedSongMoment = null;
                                              adjustDisplay();
                                            },
                                          ),
                                        ),
                                        const AppSpace(space: 5),
                                        AppTooltip(
                                          message: 'Advance to the next song in the list',
                                          child: appIconButton(
                                            appKeyEnum: AppKeyEnum.playerNextSong,
                                            icon: appIcon(
                                              Icons.navigate_next,
                                            ),
                                            onPressed: () {
                                              widget._song = nextSongInTheList();
                                              _song = widget._song;
                                              setSelectedSongKey(_song.key);
                                              _selectedSongMoment = null;
                                              adjustDisplay();
                                            },
                                          ),
                                        ),
                                      ]),
                                    if (app.isScreenBig)
                                      AppWrap(children: [
                                        const AppSpace(horizontalSpace: 35),
                                        AppTooltip(
                                          message: 'Mark the song as good.'
                                              '\nYou will find it in the'
                                              ' "${myGoodSongNameValue.toShortString()}" list.',
                                          child: appIconButton(
                                            appKeyEnum: AppKeyEnum.playerSongGood,
                                            icon: appIcon(
                                              Icons.thumb_up,
                                            ),
                                            onPressed: () {
                                              SongMetadata.addSong(_song, myGoodSongNameValue);
                                              SongMetadata.removeSong(_song, myGoodSongNameValue);
                                              appOptions.storeSongMetadata();
                                              app.errorMessage('${_song.title} added to'
                                                  ' ${myGoodSongNameValue.toShortString()}');
                                            },
                                          ),
                                        ),
                                        const AppSpace(space: 5),
                                        AppTooltip(
                                          message: 'Mark the song as bad, that is, in need of correction.'
                                              '\nYou will find it in the'
                                              ' "${myBadSongNameValue.toShortString()}" list.',
                                          child: appIconButton(
                                            appKeyEnum: AppKeyEnum.playerSongBad,
                                            icon: appIcon(
                                              Icons.thumb_down,
                                            ),
                                            onPressed: () {
                                              SongMetadata.addSong(_song, myBadSongNameValue);
                                              appOptions.storeSongMetadata();
                                              _songMaster.stop();
                                              _cancelIdleTimer();
                                              Navigator.pop(context); //  return to main list
                                            },
                                          ),
                                        ),
                                      ]),
                                    if (app.isEditReady) const AppSpace(horizontalSpace: 35),
                                    if (app.isEditReady)
                                      AppTooltip(
                                        message: 'Edit the song',
                                        child: appIconButton(
                                          appKeyEnum: AppKeyEnum.playerEdit,
                                          icon: appIcon(
                                            Icons.edit,
                                          ),
                                          onPressed: () {
                                            navigateToEdit(context, _song);
                                          },
                                        ),
                                      ),
                                    const AppSpaceViewportWidth(horizontalSpace: 3.0),
                                    AppTooltip(
                                      message: 'Player settings',
                                      child: appIconButton(
                                        appKeyEnum: AppKeyEnum.playerSettings,
                                        icon: appIcon(
                                          Icons.settings,
                                          size: 1.5 * fontSize,
                                        ),
                                        onPressed: () {
                                          _settingsPopup();
                                        },
                                      ),
                                    ),
                                  ]),
                                ]),
                              ),
                              AppWrapFullWidth(alignment: WrapAlignment.spaceAround, children: [
                                if (app.fullscreenEnabled && !app.isFullScreen)
                                  appEnumeratedButton('Fullscreen', appKeyEnum: AppKeyEnum.playerFullScreen,
                                      onPressed: () {
                                    app.requestFullscreen();
                                  }),
                                if (!songUpdateService.isFollowing)
                                  Container(
                                    padding: const EdgeInsets.only(left: 8, right: 8),
                                    child: appIconButton(
                                      appKeyEnum: AppKeyEnum.playerPlay,
                                      icon: appIcon(
                                        playStopIcon,
                                        size: 2 * fontSize,
                                      ),
                                      onPressed: () {
                                        _isPlaying ? performStop() : performPlay();
                                      },
                                    ),
                                  ),
                                AppWrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  children: [
                                    if (!songUpdateService.isFollowing)
                                      AppWrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        children: [
                                          AppTooltip(
                                            message: 'Transcribe the song to the selected key.',
                                            child: Text(
                                              'Key: ',
                                              style: headerTextStyle,
                                              softWrap: false,
                                            ),
                                          ),
                                          DropdownButton<music_key.Key>(
                                            items: keyDropDownMenuList,
                                            onChanged: (value) {
                                              setState(() {
                                                if (value != null) {
                                                  setSelectedSongKey(value);
                                                }
                                              });
                                            },
                                            value: _selectedSongKey,
                                            style: headerTextStyle,
                                            iconSize: lookupIconSize(),
                                            itemHeight: max(headerTextStyle.fontSize ?? kMinInteractiveDimension,
                                                kMinInteractiveDimension),
                                          ),
                                          if (app.isScreenBig) const AppSpace(),
                                          if (app.isScreenBig)
                                            AppTooltip(
                                              message: 'Move the key one half step up.',
                                              child: appIconButton(
                                                appKeyEnum: AppKeyEnum.playerKeyUp,
                                                icon: appIcon(
                                                  Icons.arrow_upward,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    setSelectedSongKey(_selectedSongKey.nextKeyByHalfStep());
                                                  });
                                                },
                                              ),
                                            ),
                                          if (app.isScreenBig) const AppSpace(space: 5),
                                          if (app.isScreenBig)
                                            AppTooltip(
                                              message: 'Move the key one half step down.',
                                              child: appIconButton(
                                                appKeyEnum: AppKeyEnum.playerKeyDown,
                                                icon: appIcon(
                                                  Icons.arrow_downward,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    setSelectedSongKey(_selectedSongKey.previousKeyByHalfStep());
                                                  });
                                                },
                                              ),
                                            ),
                                        ],
                                      ),
                                    if (songUpdateService.isFollowing)
                                      AppTooltip(
                                        message: 'When following the leader, the leader will select the key for you.\n'
                                            'To correct this from the main screen: hamburger, Options, Hosts: None',
                                        child: Text(
                                          'Key: $_selectedSongKey',
                                          style: headerTextStyle,
                                          softWrap: false,
                                        ),
                                      ),
                                    const AppSpace(),
                                    if (displayKeyOffset > 0 || (showCapo && _isCapo && _capoLocation > 0))
                                      Text(
                                        ' ($_selectedSongKey${displayKeyOffset > 0 ? '+$displayKeyOffset' : ''}${_isCapo && _capoLocation > 0 ? '-$_capoLocation' : ''}=$_displaySongKey)',
                                        style: headerTextStyle,
                                      ),
                                  ],
                                ),
                                if (app.isScreenBig && !songUpdateService.isFollowing)
                                  AppWrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      AppTooltip(
                                        message: 'Beats per minute.  Tap here or hold control and tap space\n'
                                            ' for tap to tempo.',
                                        child: appButton(
                                          'Tempo:',
                                          appKeyEnum: AppKeyEnum.playerTempoTap,
                                          onPressed: () {
                                            tempoTap();
                                          },
                                        ),
                                      ),
                                      const AppSpace(),
                                      AppWrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        children: [
                                          DropdownButton<int>(
                                            items: bpmDropDownMenuList,
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  playerSelectedBpm = value;
                                                  logger.log(
                                                      _playerLogBPM, '_bpmDropDownMenuList: bpm: $playerSelectedBpm');
                                                });
                                              }
                                            },
                                            value: playerSelectedBpm ?? _song.beatsPerMinute,
                                            style: headerTextStyle,
                                            iconSize: lookupIconSize(),
                                            itemHeight: max(headerTextStyle.fontSize ?? kMinInteractiveDimension,
                                                kMinInteractiveDimension),
                                          ),
                                        ],
                                      ),
                                      if (kDebugMode) const AppSpace(),
                                      if (kDebugMode)
                                        appButton(
                                          'speed',
                                          appKeyEnum: AppKeyEnum.playerSpeed,
                                          onPressed: () {
                                            setState(() {
                                              playerSelectedBpm = MusicConstants.maxBpm;
                                              logger.log(_playerLogBPM, 'speed: bpm: $playerSelectedBpm');
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                if (app.isScreenBig && songUpdateService.isFollowing)
                                  AppTooltip(
                                    message: 'When following the leader, the leader will select the tempo for you.\n'
                                        'To correct this from the main screen: hamburger, Options, Hosts: None',
                                    child: Text(
                                      'Tempo: ${playerSelectedBpm ?? _song.beatsPerMinute}',
                                      style: headerTextStyle,
                                    ),
                                  ),
                                Text(
                                  '${_song.timeSignature.beatsPerBar} beats per measure',
                                  style: headerTextStyle,
                                  softWrap: false,
                                ),
                                if (app.isScreenBig)
                                  Text(
                                    songUpdateService.isConnected
                                        ? (songUpdateService.isLeader
                                            ? 'leading ${songUpdateService.host}'
                                            : (songUpdateService.leaderName == AppOptions.unknownUser
                                                ? 'on ${songUpdateService.host}'
                                                : 'following ${songUpdateService.leaderName}'))
                                        : (songUpdateService.isIdle ? '' : 'lost ${songUpdateService.host}!'),
                                    style: !songUpdateService.isConnected && !songUpdateService.isIdle
                                        ? headerTextStyle.copyWith(color: Colors.red)
                                        : headerTextStyle,
                                  ),
                              ]),
                              const AppSpace(),
                              if (app.isScreenBig && appOptions.ninJam && _ninJam.isNinJamReady)
                                AppWrapFullWidth(spacing: 20, children: [
                                  const AppSpace(),
                                  AppWrap(spacing: 10, children: [
                                    Text(
                                      'Ninjam: BPM: ${playerSelectedBpm ?? _song.beatsPerMinute.toString()}',
                                      style: headerTextStyle,
                                      softWrap: false,
                                    ),
                                    appIconButton(
                                      appKeyEnum: AppKeyEnum.playerCopyNinjamBPM,
                                      icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                            text: '/bpm ${(playerSelectedBpm ?? _song.beatsPerMinute).toString()}'));
                                      },
                                    ),
                                  ]),
                                  AppWrap(spacing: 10, children: [
                                    Text(
                                      'Cycle: ${_ninJam.beatsPerInterval}',
                                      style: headerTextStyle,
                                      softWrap: false,
                                    ),
                                    appIconButton(
                                      appKeyEnum: AppKeyEnum.playerCopyNinjamCycle,
                                      icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: '/bpi ${_ninJam.beatsPerInterval}'));
                                      },
                                    ),
                                  ]),
                                  AppWrap(spacing: 10, children: [
                                    Text(
                                      'Chords: ${_ninJam.toMarkup()}',
                                      style: headerTextStyle,
                                      softWrap: false,
                                    ),
                                    appIconButton(
                                      appKeyEnum: AppKeyEnum.playerCopyNinjamChords,
                                      icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: _ninJam.toMarkup()));
                                      },
                                    ),
                                  ]),
                                ]),
                              const AppSpace(),
                              _table ?? const Text('table missing!'),

                              Text(
                                'Copyright: ${_song.copyright}',
                                style: headerTextStyle,
                              ),
                              // Text(
                              //   'Last edit by: ${song.user}',
                              //   style: headerTextStyle,
                              // ),
                              //  allow for scrolling to a relatively high box center
                              SizedBox(
                                height: app.screenInfo.mediaHeight - boxCenter,
                              ),
                            ]),

                        if (selectedTargetY > 0 && !_isPlaying)
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            AppVerticalSpace(
                                space: selectedTargetY -
                                    (
                                            // _chordFontSize ??
                                            app.screenInfo.fontSize) /
                                        2),
                            AppWrap(children: [
                              appIcon(
                                Icons.play_arrow,
                                size: _lyricsTable.chordFontSize,
                                color: Colors.redAccent,
                              ),
                            ] //, crossAxisAlignment: WrapCrossAlignment.start
                                ),
                          ]),
                        // if (isPlaying) showBeatWidget,
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: _isPlaying
                ? (_isPaused
                    ? appFloatingActionButton(
                        appKeyEnum: AppKeyEnum.playerFloatingPlay,
                        onPressed: () {
                          pauseToggle();
                        },
                        child: AppTooltip(
                          message: 'Stop.  Space bar will continue the play.',
                          child: appIcon(
                            Icons.play_arrow,
                          ),
                          // fontSize: headerTextStyle.fontSize,
                        ),
                        mini: !app.isScreenBig,
                      )
                    : appFloatingActionButton(
                        appKeyEnum: AppKeyEnum.playerFloatingStop,
                        onPressed: () {
                          performStop();
                        },
                        child: AppTooltip(
                          message: 'Escape to stop the play\nor space to next section',
                          child: appIcon(
                            Icons.stop,
                          ),
                        ),
                        mini: !app.isScreenBig,
                      ))
                : (_scrollController.hasClients && _scrollController.offset > 0
                    ? appFloatingActionButton(
                        appKeyEnum: AppKeyEnum.playerFloatingTop,
                        onPressed: () {
                          if (_isPlaying) {
                            performStop();
                          } else {
                            _scrollController.jumpTo(0);
                          }
                        },
                        child: AppTooltip(
                          message: 'Top of song',
                          child: appIcon(
                            Icons.arrow_upward,
                          ),
                        ),
                        mini: !app.isScreenBig,
                      )
                    : appFloatingActionButton(
                        appKeyEnum: AppKeyEnum.playerBack,
                        onPressed: () {
                          _songMaster.stop();
                          Navigator.pop(context);
                        },
                        child: AppTooltip(
                          message: 'Back to song list',
                          child: appIcon(
                            Icons.arrow_back,
                          ),
                        ),
                        mini: !app.isScreenBig,
                      )),
          ),
          if (_scrollController.hasClients && _scrollController.offset > 0)
            Column(
              children: [
                AppSpace(
                  verticalSpace: AppBar().preferredSize.height,
                ),
                AppWrap(
                  children: [
                    const AppSpace(
                      horizontalSpace: 10,
                    ),
                    //
                    Text(
                      'Key $_selectedSongKey'
                      '     Tempo: ${playerSelectedBpm ?? _song.beatsPerMinute}'
                      '    ${_song.timeSignature.beatsPerBar} beats per measure'
                      '${_isCapo ? '    Capo ${_capoLocation == 0 ? 'not needed' : 'on $_capoLocation'}' : ''}'
                      '  ', //  padding at the end
                      style: generateAppTextStyle(
                        decoration: TextDecoration.none,
                        backgroundColor: const Color(0xe0eff4fd), //  fake a blended color, semi-opaque
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  KeyEventResult playerOnKey(FocusNode node, RawKeyEvent value) {
    logger.log(_playerLogKeyboard, '_playerOnKey(): event: $value');

    if (!_playerIsOnTop) {
      return KeyEventResult.ignored;
    }
    if (value.runtimeType != RawKeyDownEvent) {
      return KeyEventResult.ignored;
    }
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
      if (e.isControlPressed) {
        tempoTap();
      } else {
        if (!_isPlaying) {
          var nowMs = DateTime.now().millisecondsSinceEpoch;
          logger.d('ms gap: ${nowMs - _lastBumpTimeMs}');
          if (nowMs - _lastBumpTimeMs > _minimumSpaceBarGapMs) {
            _lastBumpTimeMs = nowMs;
            sectionBump(1);
          }
        } else {
          pauseToggle();
        }
      }
      return KeyEventResult.handled;
    } else if ((!_isPlaying || _isPaused) &&
        (e.isKeyPressed(LogicalKeyboardKey.arrowDown) || e.isKeyPressed(LogicalKeyboardKey.arrowRight))) {
      logger.d('arrowDown');
      sectionBump(1);
      return KeyEventResult.handled;
    } else if ((!_isPlaying || _isPaused) &&
        (e.isKeyPressed(LogicalKeyboardKey.arrowUp) || e.isKeyPressed(LogicalKeyboardKey.arrowLeft))) {
      logger.log(_playerLogKeyboard, 'arrowUp');
      sectionBump(-1);
      return KeyEventResult.handled;
    } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
      if (_isPlaying) {
        performStop();
      } else {
        logger.log(_playerLogKeyboard, 'player: pop the navigator');
        _songMaster.stop();
        _cancelIdleTimer();
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    } else if (e.isKeyPressed(LogicalKeyboardKey.numpadEnter) || e.isKeyPressed(LogicalKeyboardKey.enter)) {
      if (_isPlaying) {
        performStop();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  double boxCenterHeight() {
    return min(
        app.screenInfo.mediaHeight * _sectionCenterLocationFraction, 0.8 * 1080 / 2 //  limit leader area to hdtv size
        );
  }

  /// bump from one section to the next
  sectionBump(int bump) {
    if (_selectedSongMoment == null) {
      assert(false);
      return;
    }
    logger.log(
        _playerLogScroll,
        'sectionBump(): bump = $bump'
        ', lyricSection.index: ${_selectedSongMoment!.lyricSection.index}');
    scrollToLyricsSectionIndex(_selectedSongMoment!.lyricSection.index + bump);
  }

  /// Scroll to the given section
  void scrollToLyricsSectionIndex(int index) {
    logger.log(_playerLogScroll, 'scrollToLyricsSectionIndex(): index: $index');
    if (sectionSongMoments.isEmpty) {
      return;
    }
    logger.log(
        _playerLogScroll, 'scrollToLyricsSectionIndex(): sectionSongMoments.length: ${sectionSongMoments.length}');
    index = Util.intLimit(index, 0, sectionSongMoments.length - 1);
    sectionIndex = index;
    setSelectedSongMoment(sectionSongMoments[index]);
  }

  /// Scroll to the given y target
  bool scrollToTargetY(double targetY) {
    double adjustedTarget = max(0, targetY - boxCenter);
    if (scrollTarget != adjustedTarget) {
      logger.log(
          _playerLogScroll, 'scrollToTargetY(): scrollTarget != adjustedTarget, $scrollTarget != $adjustedTarget');
      setState(() {
        selectedTargetY = targetY;
        scrollTarget = adjustedTarget;
        if (_scrollController.hasClients && _scrollController.offset != adjustedTarget) {
          logger.log(_playerLogScroll, 'scrollToTargetY(): isScrolling to: $scrollTarget');
          _scrollController.animateTo(adjustedTarget, duration: scrollDuration, curve: Curves.ease).whenComplete(() {
            _scrollControllerCompletionCallback();
            logger.log(_playerLogScroll, 'scrollController animation complete.`');
          }).onError((error, stackTrace) => _scrollControllerCompletionCallback());
        }
      });
      return true;
    }
    if (selectedTargetY != targetY) {
      logger.log(_playerLogScroll, 'scrollToTargetY(): selectedTargetY != target, $selectedTargetY != $targetY');
      setState(() {
        selectedTargetY = targetY;
      });
      return true;
    }
    logger.log(_playerLogScroll, 'scrollToTargetY(): false, $selectedTargetY == $targetY');
    return false;
  }

  /// Find the section under the current scroll position
  int? sectionIndexAtScrollOffset() {
    if (sectionLocations.isNotEmpty) {
      //  find the best location for the current scroll position
      double offset = _scrollController.offset + boxCenter;
      var index = 0;
      double error = double.maxFinite;
      for (int i = 0; i < sectionLocations.length - 1; i++) {
        double e = (sectionLocations[i] - offset).abs();
        if (e < error) {
          error = e;
          index = i;
        }
        if (sectionLocations[i] >= offset) {
          break;
        }
      }

      logger.d('sectionIndexAtScrollOffset(): scrollController: ${_scrollController.offset}'
          ', offset: $offset'
          ', index: $index'
          ', target: ${sectionLocations[index]}'
          ' (${offset - sectionLocations[index]})');

      //  bump it by units of section
      return index;
    }

    return null;
  }

  /// send a leader song update to the followers
  void leaderSongUpdate(int momentNumber) {
    logger.log(_playerLogLeaderFollower, 'leaderSongUpdate($momentNumber):');
    if (!songUpdateService.isLeader) {
      _lastSongUpdateSent = null;
      return;
    }

    SongUpdateState state = _isPlaying ? SongUpdateState.playing : SongUpdateState.none;
    if (_lastSongUpdateSent != null) {
      if (_lastSongUpdateSent!.song == widget._song &&
          _lastSongUpdateSent!.momentNumber == momentNumber &&
          _lastSongUpdateSent!.state == state &&
          _lastSongUpdateSent!.currentKey == _selectedSongKey) {
        return;
      }
    }

    var update = SongUpdate.createSongUpdate(widget._song.copySong()); //  fixme: copy  required?
    _lastSongUpdateSent = update;
    update.currentKey = _selectedSongKey;
    playerSelectedSongKey = _selectedSongKey;
    update.currentBeatsPerMinute = playerSelectedBpm ?? update.song.beatsPerMinute;
    update.momentNumber = momentNumber;
    update.user = appOptions.user;
    update.setState(state);
    songUpdateService.issueSongUpdate(update);

    logger.log(_playerLogLeaderFollower, 'leadSongUpdate: momentNumber: $momentNumber');
  }

  IconData get playStopIcon => _isPlaying ? Icons.stop : Icons.play_arrow;

  void performPlay() {
    setState(() {
      setPlayMode();
      setSelectedSongMoment(_song.songMoments.first);
      sectionBump(0);
      leaderSongUpdate(-1);
      logger.log(_playerLogMode, 'play:');
      if (!songUpdateService.isFollowing) {
        _songMaster.playSong(widget._song, drumParts: _drumParts, bpm: playerSelectedBpm ?? _song.beatsPerMinute);
      }
    });
  }

  /// Workaround to avoid calling setState() outside of the framework classes
  void setPlayState() {
    if (_songUpdate == null) {
      return;
    }
    setState(() {
      switch (_songUpdate!.state) {
        case SongUpdateState.playing:
          setPlayMode();
          break;
        default:
          break;
      }

      int momentNumber = Util.intLimit(_songUpdate!.momentNumber, 0, _song.songMoments.length - 1);
      assert(momentNumber >= 0);
      assert(momentNumber < _song.songMoments.length);
      setSelectedSongMoment(_song.songMoments[momentNumber]);
      logger.log(
          _playerLogLeaderFollower,
          'post songUpdate?.state: ${_songUpdate?.state}, isPlaying: $_isPlaying'
          ', moment: ${_songUpdate?.momentNumber}'
          ', scroll: ${_scrollController.offset}');
    });
  }

  void setPlayMode() {
    _isPaused = false;
    _isPlaying = true;
  }

  void performStop() {
    setState(() {
      simpleStop();
    });
  }

  void simpleStop() {
    _isPlaying = false;
    _isPaused = true;
    // scrollController.jumpTo(0);   //  too rash
    _songMaster.stop();
    logger.log(_playerLogMode, 'simpleStop()');
    logger.log(_playerLogScroll, 'simpleStop():');
  }

  void pauseToggle() {
    logger.log(_playerLogMode, '_pauseToggle():  pre: _isPlaying: $_isPlaying, _isPaused: $_isPaused');
    setState(() {
      if (_isPlaying) {
        _isPaused = !_isPaused;
        if (_isPaused) {
          _songMaster.pause();
          _scrollController.jumpTo(_scrollController.offset);
          logger.log(_playerLogScroll, 'pause():');
        } else {
          _songMaster.resume();
        }
      } else {
        _songMaster.resume();
        _isPlaying = true;
        _isPaused = false;
      }
    });
    logger.log(_playerLogMode, '_pauseToggle(): post: _isPlaying: $_isPlaying, _isPaused: $_isPaused');
  }

  /// Adjust the displayed
  setSelectedSongKey(music_key.Key key) {
    logger.log(_playerLogMusicKey, 'key: $key');

    //  add any offset
    music_key.Key newDisplayKey = key.nextKeyByHalfSteps(displayKeyOffset);
    logger.log(_playerLogMusicKey, 'offsetKey: $newDisplayKey');

    //  deal with capo
    if (capoIsAvailable() && _isCapo) {
      _capoLocation = newDisplayKey.capoLocation;
      newDisplayKey = newDisplayKey.capoKey;
      logger.log(_playerLogMusicKey, 'capo: $newDisplayKey + $_capoLocation');
    }

    //  don't process unless there was a change
    if (_selectedSongKey == key && _displaySongKey == newDisplayKey) {
      return; //  no change required
    }
    _selectedSongKey = key;
    playerSelectedSongKey = key;
    _displaySongKey = newDisplayKey;
    logger.log(_playerLogMusicKey,
        '_setSelectedSongKey(): _selectedSongKey: $_selectedSongKey, _displaySongKey: $_displaySongKey');

    forceTableRedisplay();

    leaderSongUpdate(-1);
  }

  String titleAnchor() {
    return anchorUrlStart + Uri.encodeFull('${widget._song.title} ${widget._song.artist}');
  }

  String artistAnchor() {
    return anchorUrlStart + Uri.encodeFull(widget._song.artist);
  }

  void navigateToEdit(BuildContext context, Song song) async {
    _playerIsOnTop = false;
    _cancelIdleTimer();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: song)),
    );
    //  return to list if song was removed
    if (!app.allSongs.contains(_song)) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    _playerIsOnTop = true;
    widget._song = app.selectedSong;
    _song = widget._song;
    forceTableRedisplay();
    _resetIdleTimer();
  }

  void forceTableRedisplay() {
    sectionLocations.clear();
    _songMomentChordRectangles.clear();
    _table = null;
    logger.log(_playerLogFontResize, '_forceTableRedisplay');
    setState(() {});
  }

  //  for use in popup
  void forcePlayerSetState() {
    setState(() {});
  }

  void adjustDisplay() {
    _lyricsFraction = null;
    forceTableRedisplay();
  }

  bool almostEqual(double d1, double d2, double tolerance) {
    return (d1 - d2).abs() <= tolerance;
  }

  void setSelectedSongMoment(SongMoment? songMoment, {force = false}) {
    logger.log(_playerLogScroll, 'setSelectedSongMoment(): $songMoment, _selectedSongMoment: $_selectedSongMoment');
    logger.log(_playerLogScroll, 'setSelectedSongMoment():  selectedTargetY: $selectedTargetY');
    if (songMoment == null || (force == false && _selectedSongMoment == songMoment)) {
      return;
    }
    _selectedSongMoment = songMoment;

    if (songUpdateService.isLeader) {
      leaderSongUpdate(_selectedSongMoment!.momentNumber);
    }

    if (_songMomentChordRectangles.isNotEmpty) {
      setSelectedSongMoment(songMoment);
      var y = _songMomentChordRectangles[songMoment.momentNumber].center.dy;
      scrollToTargetY(y);
      logger.log(
          _playerLogScroll,
          'scrollToSectionByMoment: ${songMoment.momentNumber}: '
          '$songMoment => section #${songMoment.lyricSection.index} => $y');
    }

    logger.log(_playerLogScroll, 'selectedSongMoment: $_selectedSongMoment');
  }

  bool capoIsAvailable() {
    return !appOptions.isSinger && !(songUpdateService.isConnected && songUpdateService.isLeader);
  }

  Future<void> _settingsPopup() async {
    var popupStyle = headerTextStyle.copyWith(fontSize: (headerTextStyle.fontSize ?? app.screenInfo.fontSize) * 0.7);
    var boldStyle = popupStyle.copyWith(fontWeight: FontWeight.bold);
    _drums = DrumsWidget(
      drumParts: _drumParts,
      beats: _song.timeSignature.beatsPerBar,
      headerStyle: boldStyle,
    );
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
              insetPadding: EdgeInsets.zero,
              title: Text(
                'Player settings:',
                style: boldStyle,
              ),
              content: SizedBox(
                width: app.screenInfo.mediaWidth * 0.7,
                child: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppWrapFullWidth(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: viewportWidth(0.5),
                          children: [
                            Text(
                              'User style: ',
                              style: boldStyle,
                            ),
                            //  pro player
                            AppWrap(children: [
                              Radio<UserDisplayStyle>(
                                value: UserDisplayStyle.proPlayer,
                                groupValue: appOptions.userDisplayStyle,
                                onChanged: (value) {
                                  setState(() {
                                    if (value != null) {
                                      appOptions.userDisplayStyle = value;
                                      forceTableRedisplay();
                                    }
                                  });
                                },
                              ),
                              appTextButton(
                                'Pro',
                                appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                onPressed: () {
                                  setState(() {
                                    appOptions.userDisplayStyle = UserDisplayStyle.proPlayer;
                                    forceTableRedisplay();
                                  });
                                },
                                style: popupStyle,
                              ),
                            ]),
                            //  player
                            AppWrap(children: [
                              Radio<UserDisplayStyle>(
                                value: UserDisplayStyle.player,
                                groupValue: appOptions.userDisplayStyle,
                                onChanged: (value) {
                                  setState(() {
                                    if (value != null) {
                                      appOptions.userDisplayStyle = value;
                                      forceTableRedisplay();
                                    }
                                  });
                                },
                              ),
                              appTextButton(
                                'Player',
                                appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                onPressed: () {
                                  setState(() {
                                    appOptions.userDisplayStyle = UserDisplayStyle.player;
                                    forceTableRedisplay();
                                  });
                                },
                                style: popupStyle,
                              ),
                            ]),
                            //  both
                            AppWrap(children: [
                              Radio<UserDisplayStyle>(
                                value: UserDisplayStyle.both,
                                groupValue: appOptions.userDisplayStyle,
                                onChanged: (value) {
                                  setState(() {
                                    if (value != null) {
                                      appOptions.userDisplayStyle = value;
                                      forceTableRedisplay();
                                    }
                                  });
                                },
                              ),
                              appTextButton(
                                'Both Player and Singer',
                                appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                onPressed: () {
                                  setState(() {
                                    appOptions.userDisplayStyle = UserDisplayStyle.both;
                                    forceTableRedisplay();
                                  });
                                },
                                style: popupStyle,
                              ),
                            ]),
                            //  singer
                            AppWrap(children: [
                              Radio<UserDisplayStyle>(
                                value: UserDisplayStyle.singer,
                                groupValue: appOptions.userDisplayStyle,
                                onChanged: (value) {
                                  setState(() {
                                    if (value != null) {
                                      appOptions.userDisplayStyle = value;
                                      forceTableRedisplay();
                                    }
                                  });
                                },
                              ),
                              appTextButton(
                                'Singer',
                                appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                onPressed: () {
                                  setState(() {
                                    appOptions.userDisplayStyle = UserDisplayStyle.singer;
                                    forceTableRedisplay();
                                  });
                                },
                                style: popupStyle,
                              ),
                            ]),
                          ]),
                      const AppSpaceViewportWidth(),
                      AppWrapFullWidth(crossAxisAlignment: WrapCrossAlignment.center, children: [
                        AppWrap(
                          children: [
                            AppTooltip(
                              message: 'For a guitar, show the capo location and\n'
                                  'chords to match the current key.',
                              child: Text(
                                'Capo',
                                style: boldStyle,
                                softWrap: false,
                              ),
                            ),
                            appSwitch(
                              appKeyEnum: AppKeyEnum.playerCapo,
                              onChanged: (value) {
                                setState(() {
                                  _isCapo = !_isCapo;
                                  setSelectedSongKey(_selectedSongKey);
                                  forceTableRedisplay();
                                });
                              },
                              value: _isCapo,
                            ),
                          ],
                        ),
                        const AppSpaceViewportWidth(space: 1),
                        appTextButton(
                          'Repeats:',
                          appKeyEnum: AppKeyEnum.playerCompressRepeatsLabel,
                          onPressed: () {
                            setState(() {
                              compressRepeats = !compressRepeats;
                              forceTableRedisplay();
                            });
                          },
                          style: boldStyle,
                        ),
                        AppTooltip(
                          message: '${compressRepeats ? 'Expand' : 'Compress'} the repeats on this song',
                          child: appIconButton(
                            appKeyEnum: AppKeyEnum.playerCompressRepeats,
                            icon: appIcon(
                              compressRepeats ? Icons.expand : Icons.compress,
                            ),
                            value: compressRepeats,
                            onPressed: () {
                              setState(() {
                                compressRepeats = !compressRepeats;
                                forceTableRedisplay();
                              });
                            },
                          ),
                        ),
                      ]),
                      const AppSpace(),
                      if (app.isScreenBig) _drums,
                      const AppSpace(),
                      AppWrapFullWidth(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: viewportWidth(1),
                        children: [
                          Text(
                            'NinJam choice:',
                            style: boldStyle,
                          ),
                          AppRadio<bool>(
                              text: 'No NinJam aids',
                              appKeyEnum: AppKeyEnum.optionsNinJam,
                              value: false,
                              groupValue: appOptions.ninJam,
                              onPressed: () {
                                setState(() {
                                  appOptions.ninJam = false;
                                  forcePlayerSetState();
                                });
                              },
                              style: popupStyle),
                          AppRadio<bool>(
                              text: 'Show NinJam aids',
                              appKeyEnum: AppKeyEnum.optionsNinJam,
                              value: true,
                              groupValue: appOptions.ninJam,
                              onPressed: () {
                                setState(() {
                                  appOptions.ninJam = true;
                                  forcePlayerSetState();
                                });
                              },
                              style: popupStyle),
                        ],
                      ),
                      const AppVerticalSpace(),
                      AppWrapFullWidth(children: <Widget>[
                        Text(
                          'Display key offset: ',
                          style: boldStyle,
                        ),
                        appDropdownButton<int>(
                          AppKeyEnum.playerKeyOffset,
                          keyOffsetItems,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                app.displayKeyOffset = value;
                                forcePlayerSetState();
                              });
                            }
                          },
                          style: popupStyle,
                          value: app.displayKeyOffset,
                        ),
                      ]),
                      const AppVerticalSpace(space: 35),
                    ],
                  );
                }),
              ),
              actions: [
                const AppSpace(),
                AppWrapFullWidth(spacing: viewportWidth(1), alignment: WrapAlignment.end, children: [
                  AppTooltip(
                    message: 'Click here or outside of the popup to return to the player screen.',
                    child: appButton('Return',
                        appKeyEnum: AppKeyEnum.playerReturnFromSettings, fontSize: popupStyle.fontSize, onPressed: () {
                      Navigator.of(context).pop();
                    }),
                  ),
                ]),
              ],
              actionsAlignment: MainAxisAlignment.start,
              elevation: 24.0,
            ));

    adjustDisplay();
  }

  void tempoTap() {
    //  tap to tempo
    final tempoTap = DateTime.now().microsecondsSinceEpoch;
    double delta = (tempoTap - _lastTempoTap) / Duration.microsecondsPerSecond;
    _lastTempoTap = tempoTap;

    if (delta < 60 / 30 && delta > 60 / 200) {
      int bpm = (_tempoRollingAverage ??= RollingAverage()).average(60 / delta).round();
      if (playerSelectedBpm != bpm) {
        setState(() {
          playerSelectedBpm = bpm;
          logger.log(_playerLogBPM, 'tempoTap(): bpm: $playerSelectedBpm');
        });
      }
    } else {
      //  delta too small or too large
      _tempoRollingAverage = null;
      playerSelectedBpm = null; //  default to song beats per minute
      logger.log(_playerLogBPM, 'tempoTap(): default: bpm: $playerSelectedBpm');
    }
  }

  final List<DropdownMenuItem<int>> keyOffsetItems = [
    DropdownMenuItem(key: appKey(AppKeyEnum.playerKeyOffset0), value: 0, child: const Text('normal: (no key offset)')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset1),
        value: 1,
        child: const Text('+1   (-11) halfsteps = scale  ${MusicConstants.flatChar}2')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset2),
        value: 2,
        child: const Text('+2   (-10) halfsteps = scale   2, B${MusicConstants.flatChar} instrument')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset3),
        value: 3,
        child: const Text('+3   (-9)   halfsteps = scale  ${MusicConstants.flatChar}3')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset4), value: 4, child: const Text('+4   (-8)   halfsteps = scale   3')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset5),
        value: 5,
        child: const Text('+5   (-7)   halfsteps = scale   4, baritone guitar')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset6),
        value: 6,
        child: const Text('+6   (-6)   halfsteps = scale  ${MusicConstants.flatChar}5')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset7),
        value: 7,
        child: const Text('+7   (-5)   halfsteps = scale   5, F instrument')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset8),
        value: 8,
        child: const Text('+8   (-4)   halfsteps = scale  ${MusicConstants.flatChar}6')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset9),
        value: 9,
        child: const Text('+9   (-3)   halfsteps = scale   6, E${MusicConstants.flatChar} instrument')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset10),
        value: 10,
        child: const Text('+10 (-2)   halfsteps = scale  ${MusicConstants.flatChar}7')),
    DropdownMenuItem(
        key: appKey(AppKeyEnum.playerKeyOffset11), value: 11, child: const Text('+11 (-1)   halfsteps = scale   7')),
  ];

  void _resetIdleTimer() {
    _cancelIdleTimer();
    _idleTimer = Timer(const Duration(minutes: 60), () {
      logger.i('idleTimer fired');
      Navigator.of(context).pop();
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
  }

  static const String anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  bool _isPaused = false;
  int _lastBumpTimeMs = 0;

  Widget? _table;

  double? _lyricsFraction;

  late final FocusNode _rawKeyboardListenerFocusNode;

  BeatStatefulWidget beatStatefulWidget = const BeatStatefulWidget();

  set compressRepeats(bool value) => appOptions.compressRepeats = value;

  bool get compressRepeats => appOptions.compressRepeats;

  music_key.Key _selectedSongKey = music_key.Key.C;
  music_key.Key _displaySongKey = music_key.Key.C;
  int displayKeyOffset = 0;

  DrumsWidget _drums = DrumsWidget();

  NinJam _ninJam = NinJam.empty();

  int _lastTempoTap = DateTime.now().microsecondsSinceEpoch;
  RollingAverage? _tempoRollingAverage;

  int _capoLocation = 0;

  Song _song = Song.createEmptySong();
  final SongMaster _songMaster = SongMaster();

  final ScrollController _scrollController = ScrollController();
  bool scrollWasZero = true;
  static const scrollDuration = Duration(milliseconds: 850);

  int sectionIndex = 0; //  index for current lyric section, fixme temp?
  List<SongMoment> sectionSongMoments = []; //  fixme temp?
  double scrollTarget = 0;
  double selectedTargetY = 0;
  List<double> sectionLocations = [];

  late Size lastSize;

  static const _centerSelections = false; //fixme: add later!
  static const _sectionCenterLocationFraction = 0.35;
  double boxCenter = 0;
  var headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);

  Timer? _idleTimer;

  late AppWidgetHelper appWidgetHelper;

  static final appOptions = AppOptions();
  final SongUpdateService songUpdateService = SongUpdateService();
}

class _ChordHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    //  clear the layer
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.transparent);

    logger.v('_ChordHighlightPainter.paint: _isPlaying: $_isPlaying');

    if (_isPlaying && _songMomentChordRectangles.isNotEmpty && _selectedSongMoment != null) {
      int index = _selectedSongMoment!.momentNumber;
      final rect = _songMomentChordRectangles[index];
      final outlineRect = Rect.fromLTWH(rect.left - defaultTableGap, rect.top - defaultTableGap,
          rect.width + 2 * defaultTableGap, rect.height + 2 * defaultTableGap);
      canvas.drawRect(outlineRect, highlightColor);
      // if (index < _songMomentChordRectangles.length - 1) {
      //   final nextRect = _songMomentChordRectangles[index + 1];
      //   if (rect.bottom < nextRect.bottom) {
      //     // we're moving down
      //     //canvas.drawRect(Rect.fromLTRB(0, rect.bottom, rect.left - overlap, nextRect.bottom), highlightColor);
      //     var vertices = ui.Vertices(VertexMode.triangles,
      //         [Offset(0, rect.bottom), Offset(nextRect.left, rect.bottom), Offset(nextRect.left / 2, nextRect.bottom)]);
      //     canvas.drawVertices(vertices, BlendMode.srcOver, highlightColor);
      //   }
      // }
      canvas.drawRect(
          Rect.fromLTWH(
              0,
              rect.top + defaultTableGap,
              _songMomentChordRectangles[0].left + defaultTableGap, //  used as a width
              rect.height *
                      (_selectedSongMoment!.repeatMax == 0
                          ? 1.0
                          : (_selectedSongMoment!.repeat + 1) / _selectedSongMoment!.repeatMax) -
                  2 * defaultTableGap),
          highlightColor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //  fixme optimize?
  }

  static final highlightColor = Paint()..color = Colors.redAccent;
}

class _LocationGridDebugPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    //  clear the layer
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.transparent);

    Offset offset = const Offset(defaultTableGap, 187); //  fixme soon!

    var grid = _lyricsTable.locationGrid;
    for (var r = 0; r < grid.getRowCount(); r++) {
      var cLen = grid.rowLength(r);
      for (var c = 0; c < cLen; c++) {
        var cell = grid.get(r, c);
        if (cell == null) {
          continue;
        }
        canvas.drawRect(cell.rect.shift(offset).inflate(1.0), highlightColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //  fixme optimize?
  }

// static final highlightColor = Paint()..color = Colors.lightBlueAccent..color.withAlpha( 100)..style = PaintingStyle.stroke;
  static final highlightColor = Paint()
    ..color = Colors.yellowAccent //.withAlpha(200)
    ..style = PaintingStyle.stroke;
}

class BeatStatefulWidget extends StatefulWidget {
  const BeatStatefulWidget({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BeatState();
  }
}

class _BeatState extends State<BeatStatefulWidget> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() {
        _elapsed = elapsed;
      });
    });
    // 5. start ticker
    _ticker.start();
  }

  @override
  void dispose() {
    //  don't forget to dispose it
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying || _player?._song == null) {
      return NullWidget();
    }
    final period = Duration.microsecondsPerSecond *
        Duration.secondsPerMinute ~/
        (playerSelectedBpm ?? _player!._song.beatsPerMinute);
    assert(period > 0);
    var phase = (_elapsed.inMicroseconds % period) / period;
    // return Text(phase.toStringAsPrecision(6));
    return SizedBox(
      width: 20,
      height: 20,
      child: ColoredBox(color: Colors.red.withOpacity(phase > 0.33 ? 0.0 : 1.0)),
    );
  }

  Duration _elapsed = Duration.zero;
  late final Ticker _ticker;
}

// class ShowBeatWidget extends StatefulWidget {
//   const ShowBeatWidget({Key? key}) : super(key: key);
//
//   @override
//   State<ShowBeatWidget> createState() => ShowBeatState();
// }
//
// class ShowBeatState extends State<ShowBeatWidget> {
//   final _textStyle = generateAppTextStyle(backgroundColor: Colors.transparent, fontSize: 30);
//
//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       'beat here',
//       style: _textStyle,
//     );
//   }
// }
