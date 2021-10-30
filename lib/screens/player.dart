import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/gridCoordinate.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
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

//  fixme: shapes in chromium?  circles become stop signs
//  fixme: compile to armv71

/// Route identifier for this screen.
final playerPageRoute = MaterialPageRoute(builder: (BuildContext context) => Player(App().selectedSong));

/// An observer used to respond to a song update server request.
final RouteObserver<PageRoute> playerRouteObserver = RouteObserver<PageRoute>();

const _lightBlue = Color(0xFF4FC3F7);

//  player update workaround data
bool _playerIsOnTop = false;
SongUpdate? _songUpdate;
SongUpdate? _lastSongUpdate;
_Player? _player;

const Level _playerLogScroll = Level.debug;
const Level _playerLogMode = Level.debug;
const Level _playerLogKeyboard = Level.debug;
const Level _playerLogMusicKey = Level.debug;
const Level _playerLogLeaderFollower = Level.debug;

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
  _player?.songUpdateService.isLeader = false;

  _songUpdate = songUpdate;
  if (!songUpdate.song.songBaseSameContent(_songUpdate?.song)) {
    _player?.adjustDisplay();
  }
  _lastSongUpdate = null;
  _player?.setSelectedSongKey(songUpdate.currentKey);

  Timer(const Duration(milliseconds: 2), () {
    // ignore: invalid_use_of_protected_member
    logger.log(_playerLogLeaderFollower, 'playerUpdate timer');
    _player?.setPlayState();
  });

  logger.log(
      _playerLogLeaderFollower, 'playerUpdate: ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}');
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
    setSelectedSongKey(_song.key);

    leaderSongUpdate(0);

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
    logger.d('scrollControllerListener: ${scrollController.offset}'
        ', section: ${sectionIndexAtScrollOffset()}');

    if (songMomentLocations.isNotEmpty) {
      double stopAt = max(songMomentLocations.last.dy - 2 * boxCenter, 0);
      if (scrollController.offset > stopAt) {
        //  cancels any animation
        logger.log(_playerLogScroll, 'scrollController.offset stop at: $stopAt');
        scrollController.jumpTo(stopAt);
      }
    }

    //  follow the leader's scroll
    if (table != null && songUpdateService.isLeader) {
      RenderObject? renderObject = (table?.key as GlobalKey).currentContext?.findRenderObject();
      assert(renderObject != null && renderObject is RenderTable);
      RenderTable renderTable = renderObject as RenderTable;

      BoxHitTestResult result = BoxHitTestResult();
      Offset position = Offset(20, boxCenter + scrollController.offset);
      if (renderTable.hitTestChildren(result, position: position)) {
        logger.d('hitTest $position: ${result.path.last}');
        assert(songMomentLocations.isNotEmpty);
        assert(songMomentLocations.length == _song.songMoments.length);

        //  find the moment past the marker
        var offset =
            songMomentLocations.firstWhere((loc) => loc.dy >= position.dy, orElse: () => songMomentLocations.last);
        var index = songMomentLocations.indexOf(offset);
        selectedSongMoment = _song.songMoments[index];

        // //  see if the section above is closer
        // {
        //   var sectionLocationIndex = sectionLocationIndexForSongMoment(songMoment);
        //   if (sectionLocationIndex > 0) {
        //     var delta1 = sectionLocations[index - 1] - position.dy;
        //     var delta2 = sectionLocations[index] - position.dy;
        //     if (delta1.abs() < delta2.abs()) {
        //       songMoment = _song.songMoments[index - 1];
        //     }
        //   }
        // }
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
        if (chordFontSize == null) {
          var length = renderTable.size.width;
          if (length > 0 && lyricsTable.chordFontSize != null) {
            var lastChordFontSize = chordFontSize ?? 0;
            var fontSize = lyricsTable.chordFontSize! * app.screenInfo.widthInLogicalPixels / length;
            logger.d('fontSize: $fontSize = ${fontSize / app.screenInfo.widthInLogicalPixels}'
                ' of ${app.screenInfo.widthInLogicalPixels}');
            fontSize = Util.limit(fontSize, 8.0, _maxFontSizeFraction * app.screenInfo.widthInLogicalPixels) as double;
            logger.d('limited : $fontSize = ${fontSize / app.screenInfo.widthInLogicalPixels}'
                ' of ${app.screenInfo.widthInLogicalPixels}');
            {
              var width = renderTable.row(0).last.size.width;
              logger.d('lyrics column width: $width = ${width / app.screenInfo.widthInLogicalPixels}');
            }

            if ((fontSize - lastChordFontSize).abs() > 1) {
              chordFontSize = fontSize;

              forceTableRedisplay();
              logger.d('table width: ${length.toStringAsFixed(1)}'
                  '/${app.screenInfo.widthInLogicalPixels.toStringAsFixed(1)}'
                  ', sectionIndex = $sectionIndex'
                  ', chord fontSize: ${lyricsTable.chordTextStyle.fontSize?.toStringAsFixed(1)}'
                  ', lyrics fontSize: ${lyricsTable.lyricsTextStyle.fontSize?.toStringAsFixed(1)}'
                  ', _lyricsTable.chordFontSize: ${lyricsTable.chordFontSize?.toStringAsFixed(1)}'
                  ', _chordFontSize: ${chordFontSize?.toStringAsFixed(1)} ='
                  ' ${(100 * chordFontSize! / app.screenInfo.widthInLogicalPixels).toStringAsFixed(1)}vw');
            }
          }
        } else {
          //  table is now final size
          logger.d('_chordFontSize: ${chordFontSize?.toStringAsFixed(1)} ='
              ' ${(100 * chordFontSize! / app.screenInfo.widthInLogicalPixels).toStringAsFixed(1)}vw'
              ', table at: ${renderTable.localToGlobal(Offset.zero)}'
              ', scroll: ${scrollController.offset}');

          {
            songMomentToGridList = lyricsTable.songMomentToGridList;

            sectionLocations = [];
            songMomentLocations = [];
            sectionSongMoments = [];

            LyricSection? lastLyricSection; //  starts as null
            logger.d('scrollController.offset: ${scrollController.offset}');
            for (var songMoment in _song.songMoments) {
              GridCoordinate coord = songMomentToGridList[songMoment.momentNumber];
              var renderBox = renderTable.row(coord.row).elementAt(coord.col);
              var offset = renderBox.localToGlobal(Offset(0, scrollController.offset)); //  compensate for scroll offset
              var y = offset.dy;
              songMomentLocations.add(offset);

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
          //  logger.log(_playerLogScroll, '_sectionLocations set: $sectionLocations');
          // for (int i = 1; i < sectionLocations.length; i++) {
          //   logger.d('positionAfterBuild(): sectionLocations[$i]: ${sectionLocations[i] - sectionLocations[i - 1]}');
          // }
          // for (int i = 0; i < songMomentLocations.length; i++) {
          //   logger.d('moment $i: ${songMomentLocations[i]}');
          // }

          //  for (var r = 0; r < renderTable.rows; r++) {
          //    var row = renderTable.row(r);
          //    for (var c = 0; c < row.length; c++) {
          //      var renderBox = row.elementAt(c);
          //      logger.d('($r,$c): size: ${renderBox.size} loc: ${renderBox.localToGlobal(Offset.zero)}');
          //    }
          //  }
          //  logger.d('renderTable.paintBounds: ${renderTable.paintBounds}');
          // for ( var rowLocation in  lyricsTable.lyricSectionRowLocations )
          //   {
          //     logger.d('rowLocation: $rowLocation');
          //   }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    _song = widget._song; //  default only

    logger.d('player build: $_song, selectedSongMoment: $_selectedSongMoment');

    //  deal with song updates
    if (_songUpdate != null) {
      if (!_song.songBaseSameContent(_songUpdate!.song) || displayKeyOffset != app.displayKeyOffset) {
        _song = _songUpdate!.song;
        widget._song = _song;
        chordFontSize == null;
        forceTableRedisplay();
        performPlay();
      }
      setSelectedSongKey(_songUpdate!.currentKey);
    }

    displayKeyOffset = app.displayKeyOffset;

    final _lyricsTextStyle = lyricsTable.lyricsTextStyle;
    final headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);
    logger.d('_lyricsTextStyle.fontSize: ${_lyricsTextStyle.fontSize}');

    if (_selectedSongMoment == null) {
      //  fixme
      selectedSongMoment = _song.songMoments.first;
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
        expanded: !appOptions.compressRepeats,
        chordFontSize: chordFontSize,
        //  givenSelectedSongMoments: selectedSongMoments
      );
      sectionLocations.clear(); //  clear any previous song cached data
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
              if (firstScaleNote != null)
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
    const Color blue300 = Color(0xFF64B5F6); //  fixme with css

    logger.log(
        _playerLogScroll,
        ' sectionTarget: $scrollTarget, '
        ' _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}'
        //', scroll: ${scrollController.offset}'
        );
    logger.log(_playerLogMode, 'playing: $isPlaying, pause: $isPaused');

    var rawKeyboardListenerFocusNode = FocusNode();

    bool showCapo = !appOptions.isSinger;

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

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
              _song.title,
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
                  constraints: BoxConstraints.loose(Size(app.screenInfo.widthInLogicalPixels / 64, 6)),
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
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: TextDirection.ltr,
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.only(top: 16, right: 12),
                              child: appWrapFullWidth([
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
                                      primary: _lightBlue, //  fixme
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
                                      appSwitch(
                                        appKeyEnum: AppKeyEnum.playerCapo,
                                        onChanged: (value) {
                                          setState(() {
                                            isCapo = !isCapo;
                                            setSelectedSongKey(selectedSongKey);
                                          });
                                        },
                                        value: isCapo,
                                      ),
                                      if (isCapo && capoLocation > 0)
                                        Text(
                                          'on $capoLocation',
                                          style: headerTextStyle,
                                          softWrap: false,
                                        ),
                                      if (isCapo && capoLocation == 0)
                                        Text(
                                          'no capo needed',
                                          style: headerTextStyle,
                                          softWrap: false,
                                        ),
                                    ],
                                  ),
                                //  recommend blues harp
                                Text(
                                  'Blues harp: ${selectedSongKey.nextKeyByFifth()}',
                                  style: headerTextStyle,
                                  softWrap: false,
                                ),
                                if (app.isEditReady)
                                  appTooltip(
                                    message: 'Edit the song',
                                    child: appIconButton(
                                      appKeyEnum: AppKeyEnum.playerEdit,
                                      icon: appIcon(
                                        Icons.edit,
                                      ),
                                      onPressed: () {
                                        appLogAppKey(AppKeyEnum.playerEdit);
                                        navigateToEdit(context, _song);
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
                                  child: appIconButton(
                                    appKeyEnum: AppKeyEnum.playerPlay,
                                    icon: appIcon(
                                      playStopIcon,
                                      size: 1.75 * app.screenInfo.fontSize, //  fixme: why is this required?
                                    ),
                                    onPressed: () {
                                      isPlaying ? performStop() : performPlay();
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
                                  items: keyDropDownMenuList,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        setSelectedSongKey(value);
                                        FocusScope.of(context).requestFocus(rawKeyboardListenerFocusNode);
                                      }
                                    });
                                  },
                                  value: selectedSongKey,
                                  style: headerTextStyle,
                                  iconSize: lookupIconSize(),
                                  itemHeight: null,
                                ),
                                appSpace(
                                  space: 5,
                                ),
                                if (displayKeyOffset > 0 || (showCapo && isCapo && capoLocation > 0))
                                  Text(
                                    ' ($selectedSongKey' +
                                        (displayKeyOffset > 0 ? '+$displayKeyOffset' : '') +
                                        (isCapo && capoLocation > 0 ? '-$capoLocation' : '') //  indicate: "maps to"
                                        +
                                        '=$displaySongKey)',
                                    style: headerTextStyle,
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
                                if (app.isScreenBig)
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
                                  )
                                else
                                  Text(
                                    _song.beatsPerMinute.toString(),
                                    style: _lyricsTextStyle,
                                  ),
                              ]),
                              appTooltip(
                                message: 'time signature',
                                child: Text(
                                  '  Time: ${_song.timeSignature}',
                                  style: headerTextStyle,
                                  softWrap: false,
                                ),
                              ),
                              Text(
                                songUpdateService.isConnected
                                    ? (songUpdateService.isLeader
                                        ? 'I\'m the leader'
                                        : (songUpdateService.leaderName == AppOptions.unknownUser
                                            ? ''
                                            : 'following ${songUpdateService.leaderName}'))
                                    : (songUpdateService.isIdle ? '' : 'lost ${songUpdateService.authority}!'),
                                style: headerTextStyle,
                              ),
                            ], alignment: WrapAlignment.spaceAround),
                          ],
                        ),
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
                          height: app.screenInfo.heightInLogicalPixels - boxCenter,
                        ),
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
            //  mask future sections for the leader to force them to stay on the current section
            //  this minimizes the errors seen by followers with smaller displays.
            if (isPlaying && songUpdateService.isLeader)
              Positioned(
                top: boxCenter + boxOffset,
                child: Container(
                  constraints: BoxConstraints.loose(
                      Size(lyricsTable.screenWidth, app.screenInfo.heightInLogicalPixels - boxHeight)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.grey.withAlpha(0),
                        Colors.grey[850] ?? Colors.grey,
                      ],
                    ),
                  ),
                ),
              ),
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
                    fontSize: headerTextStyle.fontSize,
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
                    fontSize: headerTextStyle.fontSize,
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
                    fontSize: headerTextStyle.fontSize,
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
                    fontSize: headerTextStyle.fontSize,
                  ),
                  mini: !app.isScreenBig,
                )),
    );
  }

  void playerOnKey(RawKeyEvent value) {
    if (!_playerIsOnTop) {
      return;
    }
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
        if (!isPlaying) {
          performPlay();
        } else {
          sectionBump(1);
        }
      } else if (isPlaying &&
          !isPaused &&
          (e.isKeyPressed(LogicalKeyboardKey.arrowDown) || e.isKeyPressed(LogicalKeyboardKey.arrowRight))) {
        logger.i('arrowDown');
        sectionBump(1);
      } else if (isPlaying &&
          !isPaused &&
          (e.isKeyPressed(LogicalKeyboardKey.arrowUp) || e.isKeyPressed(LogicalKeyboardKey.arrowLeft))) {
        logger.i('arrowUp');
        sectionBump(-1);
      } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
        if (isPlaying) {
          performStop();
        } else {
          logger.i('player: pop the navigator');
          Navigator.pop(context);
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.numpadEnter) || e.isKeyPressed(LogicalKeyboardKey.enter)) {
        if (isPlaying) {
          performStop();
        }
      }
    }
  }

  double boxCenterHeight() {
    return min(app.screenInfo.heightInLogicalPixels * _sectionCenterLocationFraction,
        0.8 * 1080 / 2 //  limit leader area to hdtv size
        );
  }

  RenderObject renderTableObjectAt(SongMoment songMoment) {
    RenderObject? renderObject = (table?.key as GlobalKey).currentContext?.findRenderObject();
    assert(renderObject != null && renderObject is RenderTable);
    RenderTable renderTable = renderObject as RenderTable;

    GridCoordinate coord = songMomentToGridList[songMoment.momentNumber];
    return renderTable.row(coord.row).elementAt(coord.col);
  }

  scrollToSectionByMoment(SongMoment? songMoment) {
    logger.log(_playerLogScroll, 'scrollToSectionByMoment( $songMoment )');
    if (songMoment == null) {
      return;
    }

    if (songMomentLocations.isNotEmpty) {
      selectedSongMoment = songMoment;
      Offset offset = songMomentLocations[songMoment.momentNumber];
      scrollToTarget(offset.dy);
      logger.log(_playerLogScroll,
          '_sectionByMomentNumber: $songMoment => section #${songMoment.lyricSection.index} => ${offset.dy}');
    }
  }

  /// bump from one section to the next
  sectionBump(int bump) {
    if (_selectedSongMoment == null) {
      assert(false);
      return;
    }

    scrollToSectionIndex(_selectedSongMoment!.lyricSection.index + bump);
  }

  void scrollToSectionIndex(int index) {
    if (sectionSongMoments.isEmpty) {
      return;
    }
    index = Util.intLimit(index, 0, sectionSongMoments.length - 1);
    sectionIndex = index;
    scrollToSectionByMoment(sectionSongMoments[index]);
  }

  bool scrollToTarget(double target) {
    if (scrollTarget != target) {
      logger.log(_playerLogScroll, 'scrollTarget != target, $scrollTarget != $target');
      setState(() {
        scrollTarget = target;
        scrollController.animateTo(target - boxCenter, duration: const Duration(milliseconds: 550), curve: Curves.ease);
      });
      return true;
    }
    return false;
  }

  int sectionLocationIndexForSongMoment(SongMoment songMoment) {
    Offset offset = songMomentLocations[songMoment.momentNumber];
    return sectionLocations.indexWhere((e) => e >= offset.dy);
  }

  int? sectionIndexAtScrollOffset() {
    if (sectionLocations.isNotEmpty) {
      //  find the best location for the current scroll position
      double offset = scrollController.offset + boxCenter;
      var index = 0;
      double error = 10e10;
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

  // updateSectionLocations() {
  //   logger.d('updateSectionLocations(): empty: ${sectionLocations.isEmpty}');
  //
  //   //  lazy update
  //   if (scrollController.hasClients && sectionLocations.isEmpty && lyricSectionRowLocations.isNotEmpty) {
  //     //  initialize the section locations... after the initial rendering
  //     double? y0;
  //     int sectionCount = -1; //  will never match the original, as intended
  //
  //     sectionLocations = [];
  //     for (LyricSectionRowLocation? _rowLocation in lyricSectionRowLocations) {
  //       if (_rowLocation == null) {
  //         continue;
  //       }
  //       assert(sectionCount != _rowLocation.sectionCount);
  //       if (sectionCount == _rowLocation.sectionCount) {
  //         continue; //  same section, no entry
  //       }
  //       sectionCount = _rowLocation.sectionCount;
  //
  //       GlobalKey key = _rowLocation.key;
  //       double y = scrollController.offset; //  safety
  //       {
  //         //  deal with possible missing render objects
  //         var renderObject = key.currentContext?.findRenderObject();
  //         if (renderObject != null && renderObject is RenderBox) {
  //           y = renderObject.localToGlobal(Offset.zero).dy;
  //         } else {
  //           sectionLocations.clear();
  //           return;
  //         }
  //       }
  //       y0 ??= y; //  initialize y0 to first y
  //       y -= y0;
  //       sectionLocations.add(y);
  //     }
  //     logger.log(_playerLogScroll, 'raw _sectionLocations: $sectionLocations');
  //
  //     //  add half of the deltas to center each selection
  //     {
  //       List<double> tmp = [];
  //       for (int i = 0; i < sectionLocations.length - 1; i++) {
  //         if (_centerSelections) {
  //           tmp.add((sectionLocations[i] + sectionLocations[i + 1]) / 2);
  //         } else {
  //           tmp.add(sectionLocations[i]);
  //         }
  //       }
  //
  //       //  average the last with the end of the last
  //       GlobalKey key = lyricSectionRowLocations.last!.key;
  //       double y = scrollController.offset; //  safety
  //       {
  //         //  deal with possible missing render objects
  //         var renderObject = key.currentContext?.findRenderObject();
  //         if (renderObject != null && renderObject is RenderBox) {
  //           y = renderObject.size.height;
  //         } else {
  //           sectionLocations.clear();
  //           return;
  //         }
  //       }
  //       if (table != null && table?.key != null) {
  //         var globalKey = table!.key as GlobalKey;
  //         logger.log(
  //             _playerLogScroll, '_table height: ${globalKey.currentContext?.findRenderObject()?.paintBounds.height}');
  //         var tableHeight = globalKey.currentContext?.findRenderObject()?.paintBounds.height ?? y;
  //         tmp.add((sectionLocations[sectionLocations.length - 1] + tableHeight) / 2);
  //       }
  //
  //       //  not really required:
  //       // if (tmp.isNotEmpty) {
  //       //  tmp.first = 0; //  special for first song moment so it can show the header data
  //       // }
  //
  //       sectionLocations = tmp;
  //     }
  //
  //     logger.log(_playerLogScroll, '_sectionLocations: $sectionLocations');
  //   }
  // }

  /// send a song update to the followers
  void leaderSongUpdate(int momentNumber) {
    logger.log(_playerLogLeaderFollower, 'leaderSongUpdate($momentNumber):');
    if (!songUpdateService.isLeader) {
      _lastSongUpdate = null;
      return;
    }
    if (_lastSongUpdate != null) {
      if (_lastSongUpdate!.song == widget._song &&
          _lastSongUpdate!.momentNumber == momentNumber &&
          _lastSongUpdate!.currentKey == selectedSongKey) {
        return;
      }
    }

    var update = SongUpdate.createSongUpdate(widget._song.copySong()); //  fixme: copy  required?
    _lastSongUpdate = update;
    update.currentKey = selectedSongKey;
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
      selectedSongMoment = _song.songMoments.first;
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
    scrollController.jumpTo(0);
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
    if (!appOptions.isSinger && isCapo) {
      capoLocation = newDisplayKey.capoLocation;
      newDisplayKey = newDisplayKey.capoKey;
      logger.log(_playerLogMusicKey, 'capo: $newDisplayKey + $capoLocation');
    }

    //  don't process unless there was a change
    if (selectedSongKey == key && displaySongKey == newDisplayKey) {
      return; //  no change required
    }
    selectedSongKey = key;
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

  navigateToEdit(BuildContext context, Song song) async {
    _playerIsOnTop = false;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: song)),
    );
    _playerIsOnTop = true;
    widget._song = app.selectedSong;
    forceTableRedisplay();
  }

  void forceTableRedisplay() {
    sectionLocations.clear();
    table = null;
    logger.d('_forceTableRedisplay');
    setState(() {});
  }

  void adjustDisplay() {
    chordFontSize = null; //  take a shot at adjusting the display of chords and lyrics
  }

  bool almostEqual(double d1, double d2, double tolerance) {
    return (d1 - d2).abs() <= tolerance;
  }

  set selectedSongMoment(SongMoment songMoment) {
    if (_selectedSongMoment == songMoment) {
      return;
    }
    _selectedSongMoment = songMoment;

    if (songUpdateService.isLeader) {
      leaderSongUpdate(_selectedSongMoment!.momentNumber);
    }

    forceTableRedisplay();
    logger.log(_playerLogScroll, 'selectedSongMoment: $_selectedSongMoment');
  }

  static const String anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  bool isPlaying = false;
  bool isPaused = false;

  Table? table;
  double? chordFontSize;
  final LyricsTable lyricsTable = LyricsTable();
  List<GridCoordinate> songMomentToGridList = [];

  music_key.Key selectedSongKey = music_key.Key.get(music_key.KeyEnum.C);
  music_key.Key displaySongKey = music_key.Key.get(music_key.KeyEnum.C);
  int displayKeyOffset = 0;

  int capoLocation = 0;
  final List<DropdownMenuItem<music_key.Key>> keyDropDownMenuList = [];

  Song _song = Song.createEmptySong();
  SongMaster songMaster = SongMaster();

  final ScrollController scrollController = ScrollController();

  SongMoment? _selectedSongMoment;
  int sectionIndex = 0; //  index for current lyric section, fixme temp?
  List<SongMoment> sectionSongMoments = []; //  fixme temp?
  double scrollTarget = 0; //  targeted scroll position for lyric section
  List<double> sectionLocations = [];
  List<Offset> songMomentLocations = [];

  late Size lastSize;

  bool isCapo = false;

  static const _centerSelections = true; //fixme: add later!
  static const _maxFontSizeFraction = 0.035;
  static const _sectionCenterLocationFraction = 0.35;
  double boxCenter = 0;

  late AppWidgetHelper appWidgetHelper;

  static final appOptions = AppOptions();
  final SongUpdateService songUpdateService = SongUpdateService();
}
