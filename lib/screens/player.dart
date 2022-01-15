import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/gridCoordinate.dart';
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
import 'package:bsteele_music_flutter/SongMaster.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';
import '../main.dart';

//  fixme: shapes in chromium?  circles become stop signs
//  fixme: compile to armv71

/// Route identifier for this screen.
final playerPageRoute = MaterialPageRoute(builder: (BuildContext context) => Player(App().selectedSong));

//  intentionally global to share with singer screen    fixme?
music_key.Key? playerSelectedSongKey;

/// An observer used to respond to a song update server request.
final RouteObserver<PageRoute> playerRouteObserver = RouteObserver<PageRoute>();

//  player update workaround data
bool _playerIsOnTop = false;
SongUpdate? _songUpdate;
SongUpdate? _lastSongUpdateSent;
_Player? _player;

const int microsecondsPerSecond = 1000 * 1000;

final GlobalKey _stackKey = GlobalKey();

SongMoment? _selectedSongMoment;
List<Rect> _songMomentChordRectangles = [];

//  diagnostic logging enables
const Level _playerLogScroll = Level.debug;
const Level _playerLogMode = Level.debug;
const Level _playerLogKeyboard = Level.debug;
const Level _playerLogMusicKey = Level.debug;
const Level _playerLogLeaderFollower = Level.debug;
const Level _playerLogFontResize = Level.debug;

/// A global function to be called to move the display to the player route with the correct song.
/// Typically this is called by the song update service when the application is in follower mode.
/// Note: This is an awkward move, given that it can happen at any time from any route.
/// Likely the implementation here will require adjustments.
void playerUpdate(BuildContext context, SongUpdate songUpdate) {
  logger.log(_playerLogLeaderFollower,
      'playerUpdate(): start: ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}');

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

  Timer(const Duration(milliseconds: 2), () {
    // ignore: invalid_use_of_protected_member
    logger.log(_playerLogLeaderFollower, 'playerUpdate timer');
    _player?.setPlayState();
  });

  logger.log(_playerLogLeaderFollower,
      'playerUpdate(): end:   ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}');
}

/// Display the song moments in sequential order.
/// Typically the chords will be grouped in lines.
// ignore: must_be_immutable
class Player extends StatefulWidget {
  Player(this._song, {Key? key, music_key.Key? musicKey}) : super(key: key) {
    playerSelectedSongKey = musicKey; //  to be read later at initialization
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
    songUpdateService.addListener(_songUpdateServiceListener);
  }

  @override
  initState() {
    super.initState();

    lastSize = WidgetsBinding.instance!.window.physicalSize;
    WidgetsBinding.instance!.addObserver(this);

    displayKeyOffset = app.displayKeyOffset;
    _song = widget._song;
    setSelectedSongKey(playerSelectedSongKey ?? _song.key);

    leaderSongUpdate(0);

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
    songUpdateService.removeListener(_songUpdateServiceListener);
    playerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  void _scrollControllerListener() {
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
          logger.d('hitTest $position: ${result.path.last}');
          assert(_songMomentChordRectangles.length == _song.songMoments.length);

          //  find the moment past the marker
          var rect = _songMomentChordRectangles.firstWhere((rect) => rect.bottom >= position.dy,
              orElse: () => _songMomentChordRectangles.last);
          var songMomentIndex = _songMomentChordRectangles.indexOf(rect);
          setSelectedSongMoment(_song.songMoments[songMomentIndex]); //  leader distribution done here
          logger.log(_playerLogLeaderFollower, 'leader scroll: $_selectedSongMoment');
        }
      }
    }
  }

  //  update the song update service status
  void _songUpdateServiceListener() {
    logger.log(_playerLogLeaderFollower, '_songUpdateServiceListener():');
    setState(() {});
  }

  void positionAfterBuild() {
    logger.d('positionAfterBuild():');

    //  look at the rendered table size, resize if required
    {
      RenderObject? renderObject = (table?.key as GlobalKey).currentContext?.findRenderObject();
      assert(renderObject != null && renderObject is RenderTable);
      if (renderObject != null && renderObject is RenderTable) {
        RenderTable renderTable = renderObject;
        final width = renderTable.size.width;

        if (chordFontSize == null) {
          final pixels = app.screenInfo.mediaWidth * 0.965;
          if (width > 0 && lyricsTable.chordFontSize != null) {
            var lastChordFontSize = chordFontSize ?? 0;
            var newFontSize = lyricsTable.chordFontSize! * pixels / width;
            newFontSize = Util.limit(newFontSize, 8.0, _maxFontSizeFraction * pixels) as double;
            renderTableLeft = 0;
            logger.log(_playerLogFontResize, 'newFontSize : $newFontSize = ${newFontSize / pixels} of $pixels');

            if (appOptions.userDisplayStyle == UserDisplayStyle.both) {
              var fontSizeFraction = newFontSize / lyricsTable.chordFontSize!;
              var newLyricsWidth = renderTable.row(0).last.size.width //  lyrics are last!
                  *
                  fontSizeFraction;
              var newWidth = width * fontSizeFraction;
              lyricsFraction = (1 - (newWidth - newLyricsWidth) / pixels);
              logger.log(
                  _playerLogFontResize,
                  'lyrics column new width: ${newLyricsWidth.toStringAsFixed(2)}'
                  ' = ${(newLyricsWidth / pixels).toStringAsFixed(2)}'
                  ', lyricsFraction: ${lyricsFraction!.toStringAsFixed(2)}');
            }

            if ((newFontSize - lastChordFontSize).abs() > 1) {
              //  resize the font based on initial rendering
              chordFontSize = newFontSize;
              forceTableRedisplay();
            }
          }
        } else {
          //  table is now final size
          logger.log(
              _playerLogFontResize,
              '_chordFontSize: ${chordFontSize?.toStringAsFixed(1)} ='
              ' ${(100 * chordFontSize! / app.screenInfo.mediaWidth).toStringAsFixed(1)}vw'
              ', table at: ${renderTable.localToGlobal(Offset.zero)}'
              ', scroll: ${scrollController.offset}');

          Offset renderTableOffset = renderTable.localToGlobal(Offset(0, scrollController.offset));
          renderTableLeft = renderTableOffset.dx;

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
            ', _chordFontSize: ${chordFontSize?.toStringAsFixed(1)} ='
            ' ${(100 * chordFontSize! / app.screenInfo.mediaWidth).toStringAsFixed(1)}vw');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    _song = widget._song; //  default only

    logger.v('player build: $_song, selectedSongMoment: $_selectedSongMoment');

    //  deal with song updates
    if (_songUpdate != null) {
      if (!_song.songBaseSameContent(_songUpdate!.song) || displayKeyOffset != app.displayKeyOffset) {
        _song = _songUpdate!.song;
        widget._song = _song;
        adjustDisplay();
        performPlay();
      }
      setSelectedSongKey(_songUpdate!.currentKey);
    }

    displayKeyOffset = app.displayKeyOffset;

    final _lyricsTextStyle = lyricsTable.lyricsTextStyle;

    logger.d('_lyricsTextStyle.fontSize: ${_lyricsTextStyle.fontSize}');

    if (_selectedSongMoment == null) {
      //  fixme
      setSelectedSongMoment(_song.songMoments.first);
    }

    if (table == null || chordFontSize != lyricsTable.chordFontSize) {
      // var selectedSongMoments = <SongMoment>[];
      // if (_selectedSongMoment != null) {
      //   if (true) {
      //     selectedSongMoments.add(_selectedSongMoment!);
      //   }
      //   // else {
      //   //   for (var songMoment in _song.songMoments) {
      //   //     if (songMoment.lyricSection == _selectedSongMoment!.lyricSection) {
      //   //       selectedSongMoments.add(songMoment);
      //   //     }
      //   //   }
      //   // }
      // }
      logger.d('table rebuild: selectedSongMoment: $_selectedSongMoment');

      table = lyricsTable.lyricsTable(
        _song, context,
        musicKey: displaySongKey,
        expanded: !compressRepeats,
        chordFontSize: chordFontSize,
        lyricsFraction: lyricsFraction,
        //  givenSelectedSongMoments: selectedSongMoments
      );
      sectionLocations.clear(); //  clear any previous song cached data
      _songMomentChordRectangles.clear();
      logger.d('_table clear: index: $sectionIndex');
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        // executes after build
        positionAfterBuild();
      });
    }

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

      keyDropDownMenuList.clear();
      final double chordsTextWidth = textWidth(context, headerTextStyle, 'G'); //  something sane
      const String onString = '(on ';
      final double onStringWidth = textWidth(context, _lyricsTextStyle, onString);

      for (int i = 0; i < steps; i++) {
        music_key.Key value = rolledKeyList[i] ?? selectedSongKey;

        //  deal with the Gb/F# duplicate issue
        if (value.halfStep == selectedSongKey.halfStep) {
          value = selectedSongKey;
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
      final int bpm = _song.beatsPerMinute;

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
    final double boxHeight = boxCenter * 2;
    final double boxOffset = boxCenter;

    final hoverColor = Colors.blue[700]; //  fixme with css
    Color centerBackgroundColor = app.themeData.colorScheme.secondary;

    logger.log(
        _playerLogScroll,
        ' sectionTarget: $scrollTarget, '
        ' _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}');
    logger.log(_playerLogMode, 'playing: $isPlaying, pause: $isPaused');

    var rawKeyboardListenerFocusNode = playerOnKeyFocusNode();

    bool showCapo = capoIsAvailable() && app.isScreenBig;
    isCapo = isCapo && showCapo; //  can't be capo if you cannot show it

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

    if (appOptions.ninJam) {
      ninJam =
          NinJam(_song, key: displaySongKey, keyOffset: displaySongKey.getHalfStep() - _song.getKey().getHalfStep());
    }

    return Scaffold(
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
          if (isPlaying && isCapo)
            Text(
              ',  Capo ${capoLocation == 0 ? 'not needed' : 'on $capoLocation'}',
              style: appBarTextStyle,
              softWrap: false,
            ),
          appSpace(),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: rawKeyboardListenerFocusNode,
        onKey: playerOnKey,
        autofocus: true,
        child: Stack(
          children: <Widget>[
            //  smooth background
            Positioned(
              top: boxCenter - boxOffset,
              child: Container(
                constraints: BoxConstraints.loose(Size(lyricsTable.screenWidth, boxHeight)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      theme.backgroundColor,
                      centerBackgroundColor,
                      centerBackgroundColor,
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
                  constraints: BoxConstraints.loose(Size(app.screenInfo.mediaWidth / 64, 6)),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                  ),
                ),
              ),

            GestureDetector(
              child: SingleChildScrollView(
                controller: scrollController,
                scrollDirection: Axis.vertical,
                child: SizedBox(
                  child: Stack(key: _stackKey, children: [
                    if (selectedTargetY > 0)
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        appSpace(space: selectedTargetY - (chordFontSize ?? 0) / 2),
                        appWrap([
                          SizedBox(height: 0, width: max(0, renderTableLeft - (chordFontSize ?? 0))),
                          appIcon(
                            Icons.play_arrow,
                            size: chordFontSize,
                            color: Colors.redAccent,
                          ),
                        ], crossAxisAlignment: WrapCrossAlignment.center),
                      ]),
                    CustomPaint(
                      painter: _ChordHighlightPainter(),
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
                          Column(
                            //  fixme: why is this column in a column?   remnant of limited scrolling?
                            children: <Widget>[
                              if (app.message.isNotEmpty)
                                Container(
                                    padding: const EdgeInsets.all(6.0),
                                    child: app.messageTextWidget(AppKeyEnum.playerErrorMessage)),
                              //  fullscreen, hints, capo,
                              if (app.isScreenBig)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  child: appWrapFullWidth([
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

                                    if (app.isScreenBig)
                                      appWrap([
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
                                                adjustDisplay();
                                              },
                                            ),
                                          ),
                                        ]),
                                        appSpace(space: 35),
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
                                              Navigator.pop(context); //  return to main list
                                            },
                                          ),
                                        ),
                                        if (app.isEditReady) appSpace(space: 35),
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
                                        appSpace(space: 35),
                                        appSpace(space: 35),
                                        appTooltip(
                                          message: 'Player settings',
                                          child: appIconButton(
                                            appKeyEnum: AppKeyEnum.playerSettings,
                                            icon: appIcon(
                                              Icons.settings,
                                            ),
                                            onPressed: () {
                                              settingsPopup();
                                            },
                                          ),
                                        ),
                                        appSpace(),
                                      ]),
                                  ], alignment: WrapAlignment.spaceBetween),
                                ),
                              appWrapFullWidth([
                                if (app.fullscreenEnabled && !app.isFullScreen)
                                  appEnumeratedButton('Fullscreen', appKeyEnum: AppKeyEnum.optionsFullScreen,
                                      onPressed: () {
                                    app.requestFullscreen();
                                  }),
                                Container(
                                  padding: const EdgeInsets.only(left: 8, right: 8),
                                  child: appTooltip(
                                    message: app.isPhone
                                        ? ''
                                        : 'Tip: Use the space bar to start playing.\n'
                                            'Use the space bar to advance the section while playing.',
                                    child: appIconButton(
                                      appKeyEnum: AppKeyEnum.playerPlay,
                                      icon: appIcon(
                                        playStopIcon,
                                        size: 1.5 * app.screenInfo.fontSize, //  fixme: why is this required?
                                      ),
                                      onPressed: () {
                                        isPlaying ? performStop() : performPlay();
                                      },
                                    ),
                                  ),
                                ),
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
                                      itemHeight: null,
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
                                if (app.isScreenBig)
                                  appWrap(
                                    [
                                      appTooltip(
                                        message: 'Beats per minute.  Tap here or hold control and tap space\n'
                                            ' for tap to tempo.',
                                        child: appButton(
                                          'BPM:',
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
                                                  _song.setBeatsPerMinute(value);
                                                });
                                              }
                                            },
                                            value: _song.beatsPerMinute,
                                            style: headerTextStyle,
                                            iconSize: lookupIconSize(),
                                            itemHeight: null,
                                          ),
                                          // appTooltip(
                                          //   message: 'Move the beats per minute (BPM) one count up.',
                                          //   child: appIconButton(
                                          //     appKeyEnum: AppKeyEnum.playerKeyUp,
                                          //     icon: appIcon(
                                          //       Icons.arrow_upward,
                                          //     ),
                                          //     onPressed: () {
                                          //       setState(() {
                                          //         _song.setBeatsPerMinute(_song.beatsPerMinute + 1);
                                          //       });
                                          //     },
                                          //   ),
                                          // ),
                                          // appSpace(space: 5),
                                          // appTooltip(
                                          //   message: 'Move the beats per minute (BPM) one count down.',
                                          //   child: appIconButton(
                                          //     appKeyEnum: AppKeyEnum.playerKeyDown,
                                          //     icon: appIcon(
                                          //       Icons.arrow_downward,
                                          //     ),
                                          //     onPressed: () {
                                          //       setState(() {
                                          //         _song.setBeatsPerMinute(_song.beatsPerMinute - 1);
                                          //       });
                                          //     },
                                          //   ),
                                          // ),
                                        ],
                                        alignment: WrapAlignment.spaceBetween,
                                      )
                                    ],
                                    alignment: WrapAlignment.spaceBetween,
                                  ),
                                appTooltip(
                                  message: 'time signature',
                                  child: Text(
                                    '  Time: ${_song.timeSignature}',
                                    style: headerTextStyle,
                                    softWrap: false,
                                  ),
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
                            ],
                          ),
                          appSpace(),
                          if (app.isScreenBig && appOptions.ninJam && ninJam.isNinJamReady)
                            appWrapFullWidth([
                              appSpace(),
                              appWrap([
                                Text(
                                  'Ninjam: BPM: ${_song.beatsPerMinute.toString()}',
                                  style: headerTextStyle,
                                  softWrap: false,
                                ),
                                appIconButton(
                                  appKeyEnum: AppKeyEnum.playerCopyNinjamBPM,
                                  icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: '/bpm ${_song.beatsPerMinute.toString()}'));
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
                            child: table ?? const Text('_table missing!'),
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
                  ]),
                ),
              ),
              onTap: () {
                if (isPlaying) {
                  sectionBump(1);
                } else {
                  performPlay();
                }
              },
            ),
            // //  mask future sections for the leader to force them to stay on the current section
            // //  this minimizes the errors seen by followers with smaller displays.
            //  this doesn't seem to help... so it's not used
            // if (isPlaying && songUpdateService.isLeader)
            //   Positioned(
            //     top: boxCenter + boxOffset,
            //     child: Container(
            //       constraints: BoxConstraints.loose(
            //           Size(lyricsTable.screenWidth, app.screenInfo.mediaHeight - boxHeight)),
            //       decoration: BoxDecoration(
            //         gradient: LinearGradient(
            //           begin: Alignment.topCenter,
            //           end: Alignment.bottomCenter,
            //           colors: <Color>[
            //             Colors.grey.withAlpha(0),
            //             Colors.grey[850] ?? Colors.grey,
            //           ],
            //         ),
            //       ),
            //     ),
            //   ),
          ],
        ),
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
    );
  }

  FocusNode playerOnKeyFocusNode() {
    //  note: must be manually aligned with the playerOnKey() method below!
    return FocusNode(onKey: (FocusNode node, RawKeyEvent event) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyB ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    });
  }

  void playerOnKey(RawKeyEvent value) {
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
          performPlay();
        } else {
          sectionBump(1);
        }
      }
    } else if (isPlaying &&
        !isPaused &&
        (e.isKeyPressed(LogicalKeyboardKey.arrowDown) || e.isKeyPressed(LogicalKeyboardKey.arrowRight))) {
      logger.d('arrowDown');
      sectionBump(1);
    } else if (isPlaying &&
        !isPaused &&
        (e.isKeyPressed(LogicalKeyboardKey.arrowUp) || e.isKeyPressed(LogicalKeyboardKey.arrowLeft))) {
      logger.log(_playerLogKeyboard, 'arrowUp');
      sectionBump(-1);
    } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
      if (isPlaying) {
        performStop();
      } else {
        logger.log(_playerLogKeyboard, 'player: pop the navigator');
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

  RenderObject renderTableObjectAt(SongMoment songMoment) {
    RenderObject? renderObject = (table?.key as GlobalKey).currentContext?.findRenderObject();
    assert(renderObject != null && renderObject is RenderTable);
    RenderTable renderTable = renderObject as RenderTable;

    GridCoordinate coord = songMomentToGridList[songMoment.momentNumber];
    return renderTable.row(coord.row).elementAt(coord.col);
  }

  void scrollToSectionByMoment(SongMoment? songMoment) {
    logger.log(_playerLogScroll, 'scrollToSectionByMoment( $songMoment )');
    if (songMoment == null) {
      return;
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
  }

  void setTargetYToSongMoment(SongMoment? songMoment) {
    if (songMoment == null) {
      return;
    }

    if (_songMomentChordRectangles.isNotEmpty) {
      setSelectedSongMoment(songMoment);
      var y = _songMomentChordRectangles[songMoment.momentNumber].center.dy;
      selectedTargetY = y;
    }
  }

  /// bump from one section to the next
  sectionBump(int bump) {
    if (_selectedSongMoment == null) {
      assert(false);
      return;
    }

    scrollToLyricsSectionIndex(_selectedSongMoment!.lyricSection.index + bump);
  }

  void scrollToLyricsSectionIndex(int index) {
    if (sectionSongMoments.isEmpty) {
      return;
    }
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
        if (scrollController.offset != adjustedTarget) {
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
    if (_lastSongUpdateSent != null) {
      if (_lastSongUpdateSent!.song == widget._song &&
          _lastSongUpdateSent!.momentNumber == momentNumber &&
          _lastSongUpdateSent!.currentKey == selectedSongKey) {
        return;
      }
    }

    var update = SongUpdate.createSongUpdate(widget._song.copySong()); //  fixme: copy  required?
    _lastSongUpdateSent = update;
    update.currentKey = selectedSongKey;
    playerSelectedSongKey = selectedSongKey;
    update.momentNumber = momentNumber;
    update.user = appOptions.user;
    update.setState(isPlaying ? SongUpdateState.playing : SongUpdateState.none);
    songUpdateService.issueSongUpdate(update);

    logger.log(_playerLogLeaderFollower, 'leadSongUpdate: momentNumber: $momentNumber');
  }

  IconData get playStopIcon => isPlaying ? Icons.stop : Icons.play_arrow;

  void performPlay() {
    setState(() {
      setPlayMode();
      setSelectedSongMoment(_song.songMoments.first);
      sectionBump(0);
      leaderSongUpdate(0);
      logger.log(_playerLogMode, 'play:');
      songMaster.playSong(widget._song);
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

      assert(_songUpdate!.momentNumber >= 0);
      assert(_songUpdate!.momentNumber < _song.songMoments.length);
      scrollToSectionByMoment(_song.songMoments[_songUpdate!.momentNumber]);
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
    logger.v('_setSelectedSongKey(): _selectedSongKey: $selectedSongKey, _displaySongKey: $displaySongKey');

    forceTableRedisplay();

    leaderSongUpdate(0);
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
    logger.d('_forceTableRedisplay');
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

  void setSelectedSongMoment(SongMoment? songMoment) {
    if (songMoment == null || _selectedSongMoment == songMoment) {
      return;
    }
    _selectedSongMoment = songMoment;

    if (songUpdateService.isLeader) {
      leaderSongUpdate(_selectedSongMoment!.momentNumber);
    }

    // scrollToSectionByMoment(_selectedSongMoment);
    // forceTableRedisplay();
    logger.log(_playerLogScroll, 'selectedSongMoment: $_selectedSongMoment');
  }

  bool capoIsAvailable() {
    return !appOptions.isSinger && !(songUpdateService.isConnected && songUpdateService.isLeader);
  }

  Future<void> settingsPopup() async {
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text(
                'Player settings:',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                return
                    // SingleChildScrollView(
                    //   child:
                    Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    appWrapFullWidth([
                      Text(
                        'User style: ',
                        style: headerTextStyle,
                      ),
                      Container(
                        padding: const EdgeInsets.only(left: 30.0),
                        child: appWrapFullWidth(<Widget>[
                          appWrap(
                            [
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
                            ],
                            spacing: 10,
                          ),
                          appWrap(
                            [
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
                            ],
                            spacing: 10,
                          ),
                          appWrap(
                            [
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
                            ],
                            spacing: 10,
                          ),
                        ], spacing: 30),
                      ),
                    ], spacing: 20),
                    appSpace(),
                    appWrapFullWidth(
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
                    appSpace(),
                    appWrapFullWidth([
                      appTextButton(
                        'Repeats:',
                        appKeyEnum: AppKeyEnum.playerCompressRepeatsLabel,
                        onPressed: () {
                          setState(() {
                            compressRepeats = !compressRepeats;
                            forceTableRedisplay();
                          });
                        },
                        style: headerTextStyle,
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
                    appWrapFullWidth(
                      [
                        Text(
                          'NinJam choice:',
                          style: headerTextStyle,
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 30.0),
                          child: appWrapFullWidth(
                            <Widget>[
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
                            spacing: 30,
                          ),
                        ),
                      ], spacing:  10,
                    ),
                  ],
                );
              }),
              actions: [
                appSpace(),
                appWrapFullWidth([
                  appTooltip(
                    message: 'Click here or outside of the popup to return to the player screen.',
                    child: appButton('Return', appKeyEnum: AppKeyEnum.songsCancelSongAllAdds, onPressed: () {
                      Navigator.of(context).pop();
                    }),
                  ),
                ], spacing: 20, alignment: WrapAlignment.end),
              ],
              actionsAlignment: MainAxisAlignment.start,
              elevation: 24.0,
            ));
  }

  void tempoTap() {
    //  tap to tempo
    final tempoTap = DateTime.now().microsecondsSinceEpoch;
    double delta = (tempoTap - _lastTempoTap) / microsecondsPerSecond;
    _lastTempoTap = tempoTap;

    if (delta < 60 / 30 && delta > 60 / 200) {
      int bpm = (tempoRollingAverage ??= RollingAverage()).average(60 / delta).round();
      if (_song.beatsPerMinute != bpm) {
        setState(() {
          _song.beatsPerMinute = bpm;
        });
      }
    } else {
      //  delta too small or too large
      tempoRollingAverage = null;
    }
  }

  static const String anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  bool isPlaying = false;
  bool isPaused = false;

  Table? table;
  double? chordFontSize;
  double? lyricsFraction;
  final LyricsTable lyricsTable = LyricsTable();
  List<GridCoordinate> songMomentToGridList = [];
  double renderTableLeft = 0;

  set compressRepeats(bool value) => appOptions.compressRepeats = value;
  bool get compressRepeats => appOptions.compressRepeats;

  music_key.Key selectedSongKey = music_key.Key.get(music_key.KeyEnum.C);
  music_key.Key displaySongKey = music_key.Key.get(music_key.KeyEnum.C);
  int displayKeyOffset = 0;

  NinJam ninJam = NinJam.empty();

  int _lastTempoTap = DateTime.now().microsecondsSinceEpoch;
  RollingAverage? tempoRollingAverage;

  int capoLocation = 0;
  final List<DropdownMenuItem<music_key.Key>> keyDropDownMenuList = [];

  Song _song = Song.createEmptySong();
  SongMaster songMaster = SongMaster();

  final ScrollController scrollController = ScrollController();
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
  static const _maxFontSizeFraction = 0.035;
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
    // const overlap = 3;
    //
    // //  clear the layer
    // canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.transparent);
    //
    // if (_songMomentChordRectangles.isNotEmpty && _selectedSongMoment != null) {
    //   final rect = _songMomentChordRectangles[_selectedSongMoment!.momentNumber];
    //   canvas.drawRect(
    //       Rect.fromLTWH(rect.left - overlap, rect.top - overlap, rect.width + 2 * overlap, rect.height + 2 * overlap),
    //       highlightColor);
    // }

    logger.v('_ChordHighlightPainter.paint: $size');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //  fixme optimize?
  }

// static final highlightColor = Paint()..color = Colors.red;
}
