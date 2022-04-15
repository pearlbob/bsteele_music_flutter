import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/gridCoordinate.dart';
import 'package:bsteeleMusicLib/songs/drumMeasure.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
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
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:bsteele_music_flutter/widgets/drums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
_Player? _player;

DrumParts _drumParts = DrumParts(); //  temp

GlobalKey _stackKey = GlobalKey();

SongMoment? _selectedSongMoment;
List<Rect> _songMomentChordRectangles = [];

//  diagnostic logging enables
const Level _playerLogBuild = Level.debug;
const Level _playerLogScroll = Level.debug;
const Level _playerLogMode = Level.debug;
const Level _playerLogKeyboard = Level.debug;
const Level _playerLogMusicKey = Level.debug;
const Level _playerLogLeaderFollower = Level.debug;
const Level _playerLogFontResize = Level.debug;
const Level _playerLogBPM = Level.debug;

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
  Player(this._song, {Key? key, music_key.Key? musicKey, int? bpm, String? singer}) : super(key: key) {
    playerSelectedSongKey = musicKey; //  to be read later at initialization
    playerSelectedBpm = bpm ?? _song.beatsPerMinute;
    playerSinger = singer;

    logger.log(_playerLogBPM, 'Player(bpm: $playerSelectedBpm)');
  }

  @override
  State<Player> createState() => _Player();

  Song _song; //  fixme: not const due to song updates!

  static const String routeName = '/player';
}

class _Player extends State<Player> with RouteAware, WidgetsBindingObserver {
  _Player() {
    _player = this;

    //  as leader, distribute current location
    scrollController.addListener(_scrollControllerListener);

    //  show the update service status
    songUpdateService.addListener(songUpdateServiceListener);

    //  show song master play updates
    songMaster.addListener(songMasterListener);
  }

  @override
  initState() {
    super.initState();

    lastSize = WidgetsBinding.instance!.window.physicalSize;
    WidgetsBinding.instance!.addObserver(this);

    displayKeyOffset = app.displayKeyOffset;
    _song = widget._song;
    drums = DrumsWidget(
      drumParts: _drumParts,
      beats: _song.timeSignature.beatsPerBar,
    );
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

    WidgetsBinding.instance?.scheduleWarmUpFrame();

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
    Size size = WidgetsBinding.instance!.window.physicalSize;
    if (size != lastSize) {
      setState(() {
        chordFontSize = null; //  take a shot at adjusting the display of chords and lyrics
        lastSize = size;
      });
    }
  }

  @override
  void dispose() {
    logger.d('player: dispose()');
    _player = null;
    _playerIsOnTop = false;
    _songUpdate = null;
    scrollController.removeListener(_scrollControllerListener);
    songUpdateService.removeListener(songUpdateServiceListener);
    songMaster.removeListener(songMasterListener);
    playerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  void _scrollControllerListener() {
    //  don't fool with the location if we're moving to a known location
    if (isScrolling) {
      return;
    }

    logger.log(
        _playerLogScroll,
        'scrollControllerListener: ${scrollController.offset}'
        ', section: ${sectionIndexAtScrollOffset()}');

    //  worry about when to update the floating button
    bool scrollIsZero = scrollController.offset == 0; //  no check for has client in a client!... we are the client
    if (scrollWasZero != scrollIsZero) {
      logger.d('scrollWasZero != scrollIsZero: $scrollWasZero vs. $scrollIsZero');
      setState(() {});
    }
    scrollWasZero = scrollIsZero;

    //  follow the leader
    if (_songMomentChordRectangles.isNotEmpty) {
      double stopAt = max(_songMomentChordRectangles.last.bottom - boxCenter, 0);
      if (scrollController.offset > stopAt) {
        //  cancels any animation
        logger.log(_playerLogScroll, 'scrollController.offset stop at: $stopAt');
        scrollController.jumpTo(stopAt);
      }

      //  follow the leader's scroll
      if (table != null && songUpdateService.isLeader && !isPlaying) {
        RenderObject? renderObject = (table?.key as GlobalKey).currentContext?.findRenderObject();
        assert(renderObject != null && renderObject is RenderTable);
        RenderTable renderTable = renderObject as RenderTable;

        BoxHitTestResult result = BoxHitTestResult();
        Offset position = Offset(20, boxCenter + scrollController.offset);
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
    logger.d('songMasterListener event:  leader: ${songUpdateService.isLeader}');
    setState(() {
      if (songMaster.momentNumber != null) {
        setSelectedSongMoment(_song.getSongMoment(songMaster.momentNumber!));
        // _selectedSongMoment = _song.getSongMoment(songMaster.momentNumber!);
        // setTargetYToSongMoment(_selectedSongMoment);
        // leaderSongUpdate(songMaster.momentNumber!);
      }
      //logger.i('songMaster event:  $_selectedSongMoment');
      isPlaying = songMaster.isPlaying;
    });
  }

  void positionAfterBuild() {
    logger.log(_playerLogFontResize, 'positionAfterBuild(): chordFontSize: ${chordFontSize!.toStringAsFixed(2)}');

    //  look at the rendered table size, resize if required
    if (table?.key != null) {
      assert(chordFontSize != null);

      RenderObject? renderObject = (table?.key as GlobalKey).currentContext?.findRenderObject();
      assert(renderObject != null && renderObject is RenderTable);
      if (renderObject != null && renderObject is RenderTable) {
        RenderTable renderTable = renderObject;
        final width = renderTable.size.width;

        //  fixme: singer mode??
        //  fixme: player mode??

        final targetRatio = appOptions.userDisplayStyle == UserDisplayStyle.player ? .75 : 0.6;
        final double chordRatio = _globalPaintBounds(renderTable.column(renderTable.columns - 1).first).left / width;
        final double correction = targetRatio / chordRatio;
        if (correction < 1.0) {
          chordFontSize = chordFontSize! * correction;
          forceTableRedisplay();
        }

        logger.log(
            _playerLogFontResize,
            'positionAfterBuild(): renderTable.size.width: $width'
            ', lyricsTable.chordFontSize: ${lyricsTable.chordFontSize}'
            ', chordRatio: ${chordRatio.toStringAsFixed(3)}'
            ', correction: ${correction.toStringAsFixed(3)}');

        {
          //  table is now final size
          logger.log(
              _playerLogFontResize,
              'chordFontSize: ${chordFontSize?.toStringAsFixed(1)} ='
              ' ${(100 * chordFontSize! / app.screenInfo.mediaWidth).toStringAsFixed(1)}vw'
              ', table at: ${renderTable.localToGlobal(Offset.zero)}'
              ', scroll: ${scrollController.offset}');

          Offset stackOffset;
          {
            RenderObject? renderObject = _stackKey.currentContext?.findRenderObject();
            assert(renderObject != null);
            stackOffset = (renderObject as RenderStack).localToGlobal(Offset(0, scrollController.offset));
          }

          {
            songMomentToGridList = lyricsTable.songMomentToGridList;

            sectionLocations = [];
            _songMomentChordRectangles.clear();
            sectionSongMoments = [];

            LyricSection? lastLyricSection; //  starts as null
            logger.d('scrollController.offset: ${scrollController.offset}');
            for (var songMoment in _song.songMoments) {
              GridCoordinate coord = songMomentToGridList[songMoment.momentNumber];
              var renderBox = renderTable.row(coord.row).elementAt(coord.col);

              var offset = renderBox.localToGlobal(Offset(0, scrollController.offset)); //  compensate for scroll offset
              var rect = (offset - stackOffset) & renderBox.size;
              _songMomentChordRectangles.add(rect);

              var y = offset.dy;

              if (lastLyricSection == songMoment.lyricSection) {
                continue; //  not a new lyric section
              }
              lastLyricSection = songMoment.lyricSection;

              sectionLocations.add(y);
              sectionSongMoments.add(songMoment);
              logger.d(
                  'positionAfterBuild()#2: ${songMoment.momentNumber}: ${songMoment.lyricSection}, ${sectionLocations.last}'
                  // ', ${renderBox.paintBounds}'
                      ', coord: $coord'
                      ', global: ${renderBox.localToGlobal(Offset.zero)}');
            }
            setSelectedSongMoment(_selectedSongMoment, force: true);
          }
        }

        logger.log(
            _playerLogFontResize,
            'table width: ${width.toStringAsFixed(1)}'
                '/${app.screenInfo.mediaWidth.toStringAsFixed(1)}'
                ', sectionIndex = $sectionIndex'
            ', lyricsFraction = $lyricsFraction'
            // ', chord fontSize: ${lyricsTable.chordTextStyle.fontSize?.toStringAsFixed(1)}'
            // ', lyrics fontSize: ${lyricsTable.lyricsTextStyle.fontSize?.toStringAsFixed(1)}'
            // ', _lyricsTable.chordFontSize: ${lyricsTable.chordFontSize?.toStringAsFixed(1)}'
            ', chordFontSize: ${chordFontSize?.toStringAsFixed(1)} ='
            ' ${(100 * (chordFontSize ?? 0) / app.screenInfo.mediaWidth).toStringAsFixed(1)}vw');
      }
    }
  }

  Rect _globalPaintBounds(final RenderObject renderObject) {
    final translation = renderObject.getTransformTo(null).getTranslation();
    final offset = Offset(translation.x, translation.y);
    return renderObject.paintBounds.shift(offset);
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    _song = widget._song; //  default only

    logger.log(
        _playerLogBuild, 'player build: $_song, selectedSongMoment: $_selectedSongMoment, isPlaying: $isPlaying');

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

    final _lyricsTextStyle = lyricsTable.lyricsTextStyle;

    logger.log(
        _playerLogBuild,
        '_lyricsTextStyle.fontSize: ${_lyricsTextStyle.fontSize?.toStringAsFixed(2)}'
        ', chordFontSize: ${chordFontSize?.toStringAsFixed(2)}');

    if (_selectedSongMoment == null) {
      //  fixme
      setSelectedSongMoment(_song.songMoments.first);
    }

    if (table == null || chordFontSize != lyricsTable.chordFontSize) {
      logger.log(_playerLogBuild, 'table rebuild: selectedSongMoment: $_selectedSongMoment');

      table = lyricsTable.lyricsTable(
        _song, context,
        musicKey: displaySongKey,
        expanded: !compressRepeats,
        chordFontSize: chordFontSize,
        lyricsFraction: lyricsFraction ?? (appOptions.userDisplayStyle == UserDisplayStyle.player ? 0.20 : 0.35),
        //  givenSelectedSongMoments: selectedSongMoments
      );
      chordFontSize ??= lyricsTable.chordFontSize;
      sectionLocations.clear(); //  clear any previous song cached data
      _songMomentChordRectangles.clear();
      logger.d('_table clear: index: $sectionIndex');
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        // executes after build
        positionAfterBuild();
      });
    }

    final fontSize = lyricsTable.lyricsFontSize;
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
      final double onStringWidth = textWidth(context, _lyricsTextStyle, onString);

      for (int i = 0; i < steps; i++) {
        music_key.Key value = rolledKeyList[i] ?? selectedSongKey;

        //  deal with the Gb/F# duplicate issue
        if (value.halfStep == selectedSongKey.halfStep) {
          value = selectedSongKey;
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
              if (app.isScreenBig && firstScaleNote != null)
                SizedBox(
                  width: onStringWidth + 4 * chordsTextWidth,
                  //  max width of chars expected
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

      _bpmDropDownMenuList = bpmList;
    }

    boxCenter = boxCenterHeight();
    final double boxOffset = boxCenter;

    final hoverColor = Colors.blue[700]; //  fixme with css

    logger.log(
        _playerLogScroll,
        ' sectionTarget: $scrollTarget, '
        ' _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}');
    logger.log(_playerLogMode, 'playing: $isPlaying, pause: $isPaused');

    bool showCapo = capoIsAvailable() && app.isScreenBig;
    isCapo = isCapo && showCapo; //  can't be capo if you cannot show it

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

    if (appOptions.ninJam) {
      ninJam =
          NinJam(_song, key: displaySongKey, keyOffset: displaySongKey.getHalfStep() - _song.getKey().getHalfStep());
    }

    return RawKeyboardListener(
      focusNode: _rawKeyboardListenerFocusNode,
      onKey: playerOnKey,
      autofocus: true,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: appWidgetHelper.backBar(
            titleWidget: appTooltip(
              message: 'Click to hear the song on youtube.com',
              child: InkWell(
                onTap: () {
                  openLink(titleAnchor());
                },
                child: Text(
                  _song.titleWithCover,
                  style: appBarTextStyle,
                ),
                hoverColor: hoverColor,
              ),
            ),
            actions: <Widget>[
              appTooltip(
                message: 'Click to hear the artist on youtube.com',
                child: InkWell(
                  onTap: () {
                    openLink(artistAnchor());
                  },
                  child: Text(
                    ' by  ${_song.artist}',
                    style: appBarTextStyle,
                    softWrap: false,
                  ),
                  hoverColor: hoverColor,
                ),
              ),
              if (playerSinger != null)
                Text(
                  ', sung by $playerSinger',
                  style: appBarTextStyle,
                  softWrap: false,
                ),
              if (isPlaying && isCapo)
                Text(
                  ',  Capo ${capoLocation == 0 ? 'not needed' : 'on $capoLocation'}',
                  style: appBarTextStyle,
                  softWrap: false,
                ),
              appSpace(),
            ],
            onPressed: () {
              songMaster.removeListener(songMasterListener); //  avoid race condition with the listener notification
              songMaster.stop();
            }),
        body: Stack(
          children: <Widget>[
            //  smooth background
            Positioned(
              top: boxCenter - boxOffset,
              child: Container(
                constraints: BoxConstraints.loose(Size(lyricsTable.screenWidth, app.screenInfo.mediaHeight)),
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
                if (!isPlaying) {
                  //  don't respond above the player song table     fixme: this is likely not the best
                  RenderTable renderTable = (table?.key as GlobalKey).currentContext?.findRenderObject() as RenderTable;
                  if (details.globalPosition.dy > renderTable.localToGlobal(Offset.zero).dy) {
                    if (details.globalPosition.dy > app.screenInfo.mediaHeight / 2) {
                      sectionBump(1); //  fixme: when not in play
                    } else {
                      sectionBump(-1); //  fixme: when not in play
                    }
                  }
                }
              },
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (end) {
                  isScrolling = false;
                  // Return true to cancel the notification bubbling. Return false to allow the
                  // notification to continue to be dispatched to further ancestors.
                  return false;
                },
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    child: Stack(key: _stackKey = GlobalKey(), children: [
                      if (isPlaying)
                        CustomPaint(
                          painter: _ChordHighlightPainter(), //  fixme: optimize with builder
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
                              child: appWrapFullWidth(children: [
                                appTooltip(
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
                                if (showCapo)
                                  appWrap(
                                    [
                                      if (isCapo && capoLocation > 0)
                                        Text(
                                          'Capo on $capoLocation',
                                          style: headerTextStyle,
                                          softWrap: false,
                                        ),
                                      if (isCapo && capoLocation == 0)
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

                                appWrap([
                                  if (app.isScreenBig)
                                    appWrap([
                                      //  fixme: there should be a better way.  wrap with flex?
                                      appTooltip(
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
                                      appSpace(space: 5),
                                      appTooltip(
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
                                    appWrap([
                                      appSpace(horizontalSpace: 35),
                                      appTooltip(
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
                                      appSpace(space: 5),
                                      appTooltip(
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
                                            songMaster.stop();
                                            Navigator.pop(context); //  return to main list
                                          },
                                        ),
                                      ),
                                    ]),
                                  if (app.isEditReady) appSpace(horizontalSpace: 35),
                                  if (app.isEditReady)
                                    appTooltip(
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
                                  appSpaceViewportWidth(horizontalSpace: 3.0),
                                  appTooltip(
                                    message: 'Player settings',
                                    child: appIconButton(
                                      appKeyEnum: AppKeyEnum.playerSettings,
                                      icon: appIcon(
                                        Icons.settings,size: 1.5*fontSize,
                                      ),
                                      onPressed: () {
                                        _settingsPopup();
                                      },
                                    ),
                                  ),
                                ]),
                              ], alignment: WrapAlignment.spaceBetween),
                            ),
                            appWrapFullWidth(children: [
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
                                      isPlaying ? performStop() : performPlay();
                                    },
                                  ),
                                ),
                              appWrap(
                                [
                                  if (!songUpdateService.isFollowing)
                                    appWrap(
                                      [
                                        appTooltip(
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
                                          value: selectedSongKey,
                                          style: headerTextStyle,
                                          iconSize: lookupIconSize(),
                                          itemHeight: max(headerTextStyle.fontSize ?? kMinInteractiveDimension,
                                              kMinInteractiveDimension),
                                        ),
                                        if (app.isScreenBig) appSpace(),
                                        if (app.isScreenBig)
                                          appTooltip(
                                            message: 'Move the key one half step up.',
                                            child: appIconButton(
                                              appKeyEnum: AppKeyEnum.playerKeyUp,
                                              icon: appIcon(
                                                Icons.arrow_upward,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  setSelectedSongKey(selectedSongKey.nextKeyByHalfStep());
                                                });
                                              },
                                            ),
                                          ),
                                        if (app.isScreenBig) appSpace(space: 5),
                                        if (app.isScreenBig)
                                          appTooltip(
                                            message: 'Move the key one half step down.',
                                            child: appIconButton(
                                              appKeyEnum: AppKeyEnum.playerKeyDown,
                                              icon: appIcon(
                                                Icons.arrow_downward,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  setSelectedSongKey(selectedSongKey.previousKeyByHalfStep());
                                                });
                                              },
                                            ),
                                          ),
                                      ],
                                      alignment: WrapAlignment.spaceBetween,
                                    ),
                                  if (songUpdateService.isFollowing)
                                    appTooltip(
                                      message: 'When following the leader, the leader will select the key for you.\n'
                                          'To correct this from the main screen: hamburger, Options, Hosts: None',
                                      child: Text(
                                        'Key: $selectedSongKey',
                                        style: headerTextStyle,
                                        softWrap: false,
                                      ),
                                    ),
                                  appSpace(),
                                  if (displayKeyOffset > 0 || (showCapo && isCapo && capoLocation > 0))
                                    Text(
                                      ' ($selectedSongKey' +
                                          (displayKeyOffset > 0 ? '+$displayKeyOffset' : '') +
                                          (isCapo && capoLocation > 0 ? '-$capoLocation' : '') //  indicate: "maps to"
                                          +
                                          '=$displaySongKey)',
                                      style: headerTextStyle,
                                    ),
                                ],
                                alignment: WrapAlignment.spaceBetween,
                              ),
                              if (app.isScreenBig && !songUpdateService.isFollowing)
                                appWrap(
                                  [
                                    appTooltip(
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
                                    appSpace(),
                                    appWrap(
                                      [
                                        DropdownButton<int>(
                                          items: _bpmDropDownMenuList,
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
                                      alignment: WrapAlignment.spaceBetween,
                                    ),
                                    if (kDebugMode) appSpace(),
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
                                  alignment: WrapAlignment.spaceBetween,
                                ),
                              if (app.isScreenBig && songUpdateService.isFollowing)
                                appTooltip(
                                  message: 'When following the leader, the leader will select the tempo for you.\n'
                                      'To correct this from the main screen: hamburger, Options, Hosts: None',
                                  child: Text(
                                    'Tempo: ${playerSelectedBpm ?? _song.beatsPerMinute}',
                                    style: headerTextStyle,
                                  ),
                                ),
                              Text(
                                '  Beats per Measure: ${_song.timeSignature.beatsPerBar}',
                                style: headerTextStyle,
                                softWrap: false,
                              ),
                              if (app.isScreenBig)
                                Text(
                                  songUpdateService.isConnected
                                      ? (songUpdateService.isLeader
                                          ? 'leading ${songUpdateService.authority}'
                                          : (songUpdateService.leaderName == AppOptions.unknownUser
                                              ? 'on ${songUpdateService.authority}'
                                              : 'following ${songUpdateService.leaderName}'))
                                      : (songUpdateService.isIdle ? '' : 'lost ${songUpdateService.authority}!'),
                                  style: !songUpdateService.isConnected && !songUpdateService.isIdle
                                      ? headerTextStyle.copyWith(color: Colors.red)
                                      : headerTextStyle,
                                ),
                            ], alignment: WrapAlignment.spaceAround),
                            appSpace(),
                            if (app.isScreenBig && appOptions.ninJam && ninJam.isNinJamReady)
                              appWrapFullWidth(children: [
                                appSpace(),
                                appWrap([
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
                                ], spacing: 10),
                                appWrap([
                                  Text(
                                    'Cycle: ${ninJam.beatsPerInterval}',
                                    style: headerTextStyle,
                                    softWrap: false,
                                  ),
                                  appIconButton(
                                    appKeyEnum: AppKeyEnum.playerCopyNinjamCycle,
                                    icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: '/bpi ${ninJam.beatsPerInterval}'));
                                    },
                                  ),
                                ], spacing: 10),
                                appWrap([
                                  Text(
                                    'Chords: ${ninJam.toMarkup()}',
                                    style: headerTextStyle,
                                    softWrap: false,
                                  ),
                                  appIconButton(
                                    appKeyEnum: AppKeyEnum.playerCopyNinjamChords,
                                    icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: ninJam.toMarkup()));
                                    },
                                  ),
                                ], spacing: 10),
                              ], spacing: 20),
                            appSpace(),
                            Center(
                              child: table ?? const Text('table missing!'),
                            ),

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
                      if (selectedTargetY > 0)
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          appSpace(space: selectedTargetY - (chordFontSize ?? app.screenInfo.fontSize) / 2),
                          appWrap([
                            appSpace(horizontalSpace: max(renderTableLeft - ((chordFontSize ?? 0) / 4), 0)),
                            appIcon(
                              Icons.play_arrow,
                              size: chordFontSize,
                              color: Colors.redAccent,
                            ),
                          ], crossAxisAlignment: WrapCrossAlignment.start),
                        ]),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: isPlaying
            ? (isPaused
                ? appFloatingActionButton(
                    appKeyEnum: AppKeyEnum.playerFloatingPlay,
                    onPressed: () {
                      pauseToggle();
                    },
                    child: appTooltip(
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
                    child: appTooltip(
                      message: 'Escape to stop the play\nor space to next section',
                      child: appIcon(
                        Icons.stop,
                      ),
                    ),
                    mini: !app.isScreenBig,
                  ))
            : (scrollController.hasClients && scrollController.offset > 0
                ? appFloatingActionButton(
                    appKeyEnum: AppKeyEnum.playerFloatingTop,
                    onPressed: () {
                      if (isPlaying) {
                        performStop();
                      } else {
                        scrollController.jumpTo(0);
                      }
                    },
                    child: appTooltip(
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
                      songMaster.stop();
                      Navigator.pop(context);
                    },
                    child: appTooltip(
                      message: 'Back to song list',
                      child: appIcon(
                        Icons.arrow_back,
                      ),
                    ),
                    mini: !app.isScreenBig,
                  )),
      ),
    );
  }

  // FocusNode playerOnKeyFocusNode() {
  //   //  note: must be manually aligned with the playerOnKey() method below!
  //   return FocusNode(onKey: (FocusNode node, RawKeyEvent event) {
  //     if (event.logicalKey == LogicalKeyboardKey.escape ||
  //         event.logicalKey == LogicalKeyboardKey.keyB ||
  //         event.logicalKey == LogicalKeyboardKey.arrowDown ||
  //         event.logicalKey == LogicalKeyboardKey.arrowRight ||
  //         event.logicalKey == LogicalKeyboardKey.arrowUp ||
  //         event.logicalKey == LogicalKeyboardKey.arrowLeft ||
  //         event.logicalKey == LogicalKeyboardKey.numpadEnter ||
  //         event.logicalKey == LogicalKeyboardKey.enter) {
  //       return KeyEventResult.handled;
  //     }
  //     return KeyEventResult.ignored;
  //   });
  // }

  void playerOnKey(RawKeyEvent value) {
    logger.log(_playerLogKeyboard, '_playerOnKey(): event: $value');

    if (!_playerIsOnTop) {
      return;
    }
    if (value.runtimeType != RawKeyDownEvent) {
      return;
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
        if (!isPlaying) {
          sectionBump(1);
        } else {
          pauseToggle();
        }
      }
    } else if ((!isPlaying || isPaused) &&
        (e.isKeyPressed(LogicalKeyboardKey.arrowDown) || e.isKeyPressed(LogicalKeyboardKey.arrowRight))) {
      logger.d('arrowDown');
      sectionBump(1);
    } else if ((!isPlaying || isPaused) &&
        (e.isKeyPressed(LogicalKeyboardKey.arrowUp) || e.isKeyPressed(LogicalKeyboardKey.arrowLeft))) {
      logger.log(_playerLogKeyboard, 'arrowUp');
      sectionBump(-1);
    } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
      if (isPlaying) {
        performStop();
      } else {
        logger.log(_playerLogKeyboard, 'player: pop the navigator');
        songMaster.stop();
        Navigator.pop(context);
      }
    } else if (e.isKeyPressed(LogicalKeyboardKey.numpadEnter) || e.isKeyPressed(LogicalKeyboardKey.enter)) {
      if (isPlaying) {
        performStop();
      }
    }
  }

  double boxCenterHeight() {
    return min(
        app.screenInfo.mediaHeight * _sectionCenterLocationFraction, 0.8 * 1080 / 2 //  limit leader area to hdtv size
        );
  }

  bool scrollToSectionByMoment(SongMoment? songMoment) {
    logger.log(_playerLogScroll, 'scrollToSectionByMoment( $songMoment )');
    if (songMoment != null && _songMomentChordRectangles.isNotEmpty) {
      setSelectedSongMoment(songMoment);
      var y = _songMomentChordRectangles[songMoment.momentNumber].center.dy;
      scrollToTargetY(y);
      logger.log(
          _playerLogScroll,
          'scrollToSectionByMoment: ${songMoment.momentNumber}: '
          '$songMoment => section #${songMoment.lyricSection.index} => $y');
      return true;
    }
    return false;
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

  void scrollToLyricsSectionIndex(int index) {
    logger.log(_playerLogScroll, 'scrollToLyricsSectionIndex(): index: $index');
    if (sectionSongMoments.isEmpty) {
      return;
    }
    logger.log(
        _playerLogScroll, 'scrollToLyricsSectionIndex(): sectionSongMoments.length: ${sectionSongMoments.length}');
    index = Util.intLimit(index, 0, sectionSongMoments.length - 1);
    sectionIndex = index;
    scrollToSectionByMoment(sectionSongMoments[index]);
  }

  bool scrollToTargetY(double targetY) {
    double adjustedTarget = max(0, targetY - boxCenter);
    if (scrollTarget != adjustedTarget) {
      logger.log(_playerLogScroll, 'scrollTarget != adjustedTarget, $scrollTarget != $adjustedTarget');
      setState(() {
        selectedTargetY = targetY;
        scrollTarget = adjustedTarget;
        if (scrollController.hasClients && scrollController.offset != adjustedTarget) {
          isScrolling = true;
          scrollController.animateTo(adjustedTarget, duration: scrollDuration, curve: Curves.ease);
        }
      });
      return true;
    }
    if (selectedTargetY != targetY) {
      logger.log(_playerLogScroll, 'selectedTargetY != target, $selectedTargetY != $targetY');
      setState(() {
        selectedTargetY = targetY;
      });
      return true;
    }
    return false;
  }

  int? sectionIndexAtScrollOffset() {
    if (sectionLocations.isNotEmpty) {
      //  find the best location for the current scroll position
      double offset = scrollController.offset + boxCenter;
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

      logger.d('sectionIndexAtScrollOffset(): scrollController: ${scrollController.offset}'
          ', offset: $offset'
          ', index: $index'
          ', target: ${sectionLocations[index]}'
          ' (${offset - sectionLocations[index]})');

      //  bump it by units of section
      return index;
    }

    return null;
  }

  /// send a song update to the followers
  void leaderSongUpdate(int momentNumber) {
    logger.log(_playerLogLeaderFollower, 'leaderSongUpdate($momentNumber):');
    if (!songUpdateService.isLeader) {
      _lastSongUpdateSent = null;
      return;
    }

    SongUpdateState state = isPlaying ? SongUpdateState.playing : SongUpdateState.none;
    if (_lastSongUpdateSent != null) {
      if (_lastSongUpdateSent!.song == widget._song &&
          _lastSongUpdateSent!.momentNumber == momentNumber &&
          _lastSongUpdateSent!.state == state &&
          _lastSongUpdateSent!.currentKey == selectedSongKey) {
        return;
      }
    }

    var update = SongUpdate.createSongUpdate(widget._song.copySong()); //  fixme: copy  required?
    _lastSongUpdateSent = update;
    update.currentKey = selectedSongKey;
    playerSelectedSongKey = selectedSongKey;
    update.currentBeatsPerMinute = playerSelectedBpm ?? update.song.beatsPerMinute;
    update.momentNumber = momentNumber;
    update.user = appOptions.user;
    update.setState(state);
    songUpdateService.issueSongUpdate(update);

    logger.log(_playerLogLeaderFollower, 'leadSongUpdate: momentNumber: $momentNumber');
  }

  IconData get playStopIcon => isPlaying ? Icons.stop : Icons.play_arrow;

  void performPlay() {
    setState(() {
      setPlayMode();
      setSelectedSongMoment(_song.songMoments.first);
      sectionBump(0);
      leaderSongUpdate(-1);
      logger.log(_playerLogMode, 'play:');
      if (!songUpdateService.isFollowing) {
        songMaster.playSong(widget._song, drumParts: _drumParts, bpm: playerSelectedBpm ?? _song.beatsPerMinute);
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
      scrollToSectionByMoment(_song.songMoments[momentNumber]);
      logger.log(
          _playerLogLeaderFollower,
          'post songUpdate?.state: ${_songUpdate?.state}, isPlaying: $isPlaying'
          ', moment: ${_songUpdate?.momentNumber}'
          ', scroll: ${scrollController.offset}');
    });
  }

  void setPlayMode() {
    isPaused = false;
    isPlaying = true;
  }

  void performStop() {
    setState(() {
      simpleStop();
    });
  }

  void simpleStop() {
    isPlaying = false;
    isPaused = true;
    // scrollController.jumpTo(0);   //  too rash
    songMaster.stop();
    logger.log(_playerLogMode, 'simpleStop()');
    logger.log(_playerLogScroll, 'simpleStop():');
  }

  void pauseToggle() {
    logger.log(_playerLogMode, '_pauseToggle():  pre: _isPlaying: $isPlaying, _isPaused: $isPaused');
    setState(() {
      if (isPlaying) {
        isPaused = !isPaused;
        if (isPaused) {
          songMaster.pause();
          scrollController.jumpTo(scrollController.offset);
          logger.log(_playerLogScroll, 'pause():');
        } else {
          songMaster.resume();
        }
      } else {
        songMaster.resume();
        isPlaying = true;
        isPaused = false;
      }
    });
    logger.log(_playerLogMode, '_pauseToggle(): post: _isPlaying: $isPlaying, _isPaused: $isPaused');
  }

  setSelectedSongKey(music_key.Key key) {
    logger.log(_playerLogMusicKey, 'key: $key');

    //  add any offset
    music_key.Key newDisplayKey = music_key.Key.getKeyByHalfStep(key.halfStep + displayKeyOffset);
    logger.log(_playerLogMusicKey, 'offsetKey: $newDisplayKey');

    //  deal with capo
    if (capoIsAvailable() && isCapo) {
      capoLocation = newDisplayKey.capoLocation;
      newDisplayKey = newDisplayKey.capoKey;
      logger.log(_playerLogMusicKey, 'capo: $newDisplayKey + $capoLocation');
    }

    //  don't process unless there was a change
    if (selectedSongKey == key && displaySongKey == newDisplayKey) {
      return; //  no change required
    }
    selectedSongKey = key;
    playerSelectedSongKey = key;
    displaySongKey = newDisplayKey;
    logger.log(_playerLogMusicKey,
        '_setSelectedSongKey(): _selectedSongKey: $selectedSongKey, _displaySongKey: $displaySongKey');

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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: song)),
    );
    _playerIsOnTop = true;
    widget._song = app.selectedSong;
    _song = widget._song;
    forceTableRedisplay();
  }

  void forceTableRedisplay() {
    sectionLocations.clear();
    table = null;
    renderTableLeft = 20;
    logger.log(_playerLogFontResize, '_forceTableRedisplay');
    setState(() {});
  }

  //  for use in popup
  void forcePlayerSetState() {
    setState(() {});
  }

  void adjustDisplay() {
    chordFontSize = null; //  take a shot at adjusting the display of chords and lyrics
    lyricsFraction = null;
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

    scrollToSectionByMoment(_selectedSongMoment);
    // forceTableRedisplay();
    logger.log(_playerLogScroll, 'selectedSongMoment: $_selectedSongMoment');
  }

  bool capoIsAvailable() {
    return !appOptions.isSinger && !(songUpdateService.isConnected && songUpdateService.isLeader);
  }

  Future<void> _settingsPopup() async {
    var boldStyle = headerTextStyle.copyWith(fontWeight: FontWeight.bold);
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(
                'Player settings:',
                style: boldStyle,
              ),
              content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                return
                    // SingleChildScrollView(
                    //   child:
                    Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    appWrapFullWidth(children: [
                      Text(
                        'User style: ',
                        style: boldStyle,
                      ),
                      appWrap([
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
                          style: headerTextStyle,
                        ),
                      ]),
                      appWrap([
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
                          style: headerTextStyle,
                        ),
                      ]),
                      appWrap([
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
                          style: headerTextStyle,
                        ),
                      ]),
                    ], spacing: viewportWidth(0.5)),
                    appSpaceViewportWidth(),
                    appWrapFullWidth(children: [
                      appWrap(
                        [
                          appTooltip(
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
                                isCapo = !isCapo;
                                setSelectedSongKey(selectedSongKey);
                                forceTableRedisplay();
                              });
                            },
                            value: isCapo,
                          ),
                        ],
                      ),
                      appSpaceViewportWidth(space: 1),
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
                      appTooltip(
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
                    appSpace(),
                    if (app.isScreenBig) drums,
                    appSpace(),
                    appWrapFullWidth(
                      children: [
                        Text(
                          'NinJam choice:',
                          style: boldStyle,
                        ),
                        appRadio<bool>('No NinJam aids',
                            appKeyEnum: AppKeyEnum.optionsNinJam,
                            value: false,
                            groupValue: appOptions.ninJam, onPressed: () {
                          setState(() {
                            appOptions.ninJam = false;
                            forcePlayerSetState();
                          });
                        }, style: headerTextStyle),
                        appRadio<bool>('Show NinJam aids',
                            appKeyEnum: AppKeyEnum.optionsNinJam,
                            value: true,
                            groupValue: appOptions.ninJam, onPressed: () {
                          setState(() {
                            appOptions.ninJam = true;
                            forcePlayerSetState();
                          });
                        }, style: headerTextStyle),
                      ],
                      spacing: viewportWidth(1),
                    ),
                    appVerticalSpace(),
                    appWrapFullWidth(children: <Widget>[
                      Text(
                        'Display key offset: ',
                        style: boldStyle,
                      ),
                      appDropdownButton<int>(
                        AppKeyEnum.playerKeyOffset,
                        keyOffsetItems,
                        onChanged: (_value) {
                          if (_value != null) {
                            setState(() {
                              app.displayKeyOffset = _value;
                              forcePlayerSetState();
                            });
                          }
                        },
                        style: headerTextStyle,
                        value: app.displayKeyOffset,
                      ),
                    ]),
                    appVerticalSpace(space: 35),
                  ],
                );
              }),
              actions: [
                appSpace(),
                appWrapFullWidth(children: [
                  appTooltip(
                    message: 'Click here or outside of the popup to return to the player screen.',
                    child: appButton('Return', appKeyEnum: AppKeyEnum.playerReturnFromSettings, onPressed: () {
                      Navigator.of(context).pop();
                    }),
                  ),
                ], spacing: viewportWidth(1), alignment: WrapAlignment.end),
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
      int bpm = (tempoRollingAverage ??= RollingAverage()).average(60 / delta).round();
      if (playerSelectedBpm != bpm) {
        setState(() {
          playerSelectedBpm = bpm;
          logger.log(_playerLogBPM, 'tempoTap(): bpm: $playerSelectedBpm');
        });
      }
    } else {
      //  delta too small or too large
      tempoRollingAverage = null;
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

  static const String anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  bool isPlaying = false;
  bool isPaused = false;

  Table? table;
  double? chordFontSize;
  double? lyricsFraction;
  final LyricsTable lyricsTable = LyricsTable();
  List<GridCoordinate> songMomentToGridList = [];
  double renderTableLeft = 0;

  final FocusNode _rawKeyboardListenerFocusNode = FocusNode();

  set compressRepeats(bool value) => appOptions.compressRepeats = value;

  bool get compressRepeats => appOptions.compressRepeats;

  music_key.Key selectedSongKey = music_key.Key.get(music_key.KeyEnum.C);
  music_key.Key displaySongKey = music_key.Key.get(music_key.KeyEnum.C);
  int displayKeyOffset = 0;

  DrumsWidget drums = DrumsWidget();

  NinJam ninJam = NinJam.empty();

  int _lastTempoTap = DateTime.now().microsecondsSinceEpoch;
  RollingAverage? tempoRollingAverage;

  int capoLocation = 0;

  Song _song = Song.createEmptySong();
  SongMaster songMaster = SongMaster();

  final ScrollController scrollController = ScrollController();
  bool isScrolling = false;
  bool scrollWasZero = true;
  static const scrollDuration = Duration(milliseconds: 850);

  int sectionIndex = 0; //  index for current lyric section, fixme temp?
  List<SongMoment> sectionSongMoments = []; //  fixme temp?
  double scrollTarget = 0;
  double selectedTargetY = 0;
  List<double> sectionLocations = [];

  late Size lastSize;

  bool isCapo = false;

  static const _centerSelections = false; //fixme: add later!
  static const _sectionCenterLocationFraction = 0.35;
  double boxCenter = 0;
  var headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);

  late AppWidgetHelper appWidgetHelper;

  static final appOptions = AppOptions();
  final SongUpdateService songUpdateService = SongUpdateService();
}

class _ChordHighlightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const overlap = 3;

    //  clear the layer
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.transparent);

    if (_songMomentChordRectangles.isNotEmpty && _selectedSongMoment != null) {
      final rect = _songMomentChordRectangles[_selectedSongMoment!.momentNumber];
      canvas.drawRect(
          Rect.fromLTWH(rect.left - overlap, rect.top - overlap, rect.width + 2 * overlap, rect.height + 2 * overlap),
          highlightColor);
    }

    logger.v('_ChordHighlightPainter.paint: $size');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //  fixme optimize?
  }

  static final highlightColor = Paint()..color = Colors.red;
}
