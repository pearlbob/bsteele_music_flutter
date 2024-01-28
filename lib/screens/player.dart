import 'dart:async';
import 'dart:collection';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/drum_screen.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/drum_measure.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/ninjam.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_base.dart';
import 'package:bsteele_music_lib/songs/song_moment.dart';
import 'package:bsteele_music_lib/songs/song_update.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

/// Route identifier for this screen.
final playerPageRoute = MaterialPageRoute(builder: (BuildContext context) => Player(App().selectedSong));

/// An observer used to respond to a song update server request.
final RouteObserver<PageRoute> playerRouteObserver = RouteObserver<PageRoute>();

//  player update workaround data
bool _playerIsOnTop = false;
SongUpdate? _songUpdate;
SongUpdate? _lastSongUpdateSent;
_PlayerState? _player;

//  package level variables
Song _song = Song.theEmptySong;
final LyricsTable _lyricsTable = LyricsTable();
Widget _table = const Text('table missing!');
const double _padding = 16.0;

bool _isCapo = false; //  package level for persistence across player invocations
int _capoLocation = 0; //  fret number of the cap location
bool _showCapo = false; //  package level for all classes in the package

bool _areDrumsMuted = true;

final _playMomentNotifier = PlayMomentNotifier();
final _songMasterNotifier = SongMasterNotifier();
final _lyricSectionNotifier = LyricSectionNotifier();

music_key.Key _selectedSongKey = music_key.Key.C;

//  diagnostic logging enables
const Level _logBuild = Level.debug;
const Level _logScroll = Level.debug;
const Level _logMode = Level.debug;
const Level _logKeyboard = Level.debug;
const Level _logMusicKey = Level.debug;
const Level _logLeaderFollower = Level.debug;
const Level _logBPM = Level.debug;
const Level _logSongMaster = Level.debug;
const Level _logSongMasterBump = Level.debug;
const Level _logLeaderSongUpdate = Level.debug;
const Level _logPlayerItemPositions = Level.debug;
const Level _logScrollAnimation = Level.debug;
const Level _logManualPlayScrollAnimation = Level.debug;
const Level _logDataReminderState = Level.debug;

const String _playStopPauseHints = '''\n
Click the play button for play. You may not see immediate song motion.
Space bar or clicking the song area starts play as well.
Space bar in play selects pause.  Space bar in pause selects play.
Selected section is displayed based on the scroll style selected from the settings pop up (upper right corner gear icon).
Right arrow speeds up the BPM.
Left arrow slows the BPM.
Down arrow also advances one row in play, one section in pause.
Up arrow backs up one row in play, one section in pause.
Enter ends the "play" mode.
With z or q, the play stops and goes back to the play list.''';

/// A global function to be called to move the display to the player route with the correct song.
/// Typically this is called by the song update service when the application is in follower mode.
/// Note: This is an awkward move, given that it can happen at any time from any route.
/// Likely the implementation here will require adjustments.
void playerUpdate(BuildContext context, SongUpdate songUpdate) {
  logger.log(
      _logLeaderFollower,
      'playerUpdate(): start: ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}'
      ', pbm: ${songUpdate.currentBeatsPerMinute} vs ${songUpdate.song.beatsPerMinute}');

  if (!_playerIsOnTop) {
    Navigator.pushNamedAndRemoveUntil(
        context, Player.routeName, (route) => route.isFirst || route.settings.name == Player.routeName);
  }

  //  listen if anyone else is talking
  _player?.songUpdateService.isLeader = false;

  if (!songUpdate.song.songBaseSameContent(_songUpdate?.song)) {
    _player?.adjustDisplay();
  }
  _songUpdate = songUpdate;

  _lastSongUpdateSent = null;
  _player?.setSelectedSongKey(songUpdate.currentKey);
  playerSelectedBpm = songUpdate.currentBeatsPerMinute;

  Timer(const Duration(milliseconds: 16), () {
    // ignore: invalid_use_of_protected_member
    logger.log(_logLeaderFollower, 'playerUpdate timer: $_songUpdate');
    _player?.setPlayState();
  });

  logger.log(
      _logLeaderFollower,
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

    logger.log(_logBPM, 'Player(bpm: $playerSelectedBpm)');
  }

  @override
  State<Player> createState() => _PlayerState();

  Song _song; //  fixme: not const due to song updates!

  static const String routeName = 'player';
}

class _PlayerState extends State<Player> with RouteAware, WidgetsBindingObserver {
  _PlayerState() {
    _player = this;

    //  show the update service status
    songUpdateService.addListener(songUpdateServiceListener);

    //  show song master play updates
    _songMaster.addListener(songMasterListener);

    _rawKeyboardListenerFocusNode = FocusNode(onKey: playerOnRawKey);

    songUpdateState = SongUpdateState.idle;
  }

  @override
  initState() {
    super.initState();

    lastSize = PlatformDispatcher.instance.implicitView?.physicalSize;
    WidgetsBinding.instance.addObserver(this);

    displayKeyOffset = app.displayKeyOffset;
    _assignNewSong(widget._song);
    setSelectedSongKey(playerSelectedSongKey ?? _song.key);
    playerSelectedBpm = playerSelectedBpm ?? _song.beatsPerMinute;
    _drumParts = _drumPartsList.songMatch(_song) ?? defaultDrumParts;
    _playMomentNotifier.playMoment = null;
    _lyricSectionNotifier.setIndexRow(0, 0);
    sectionSongMoments.clear();

    logger.log(_logBPM, 'initState() bpm: $playerSelectedBpm');

    leaderSongUpdate(-3);

    WidgetsBinding.instance.scheduleWarmUpFrame();

    playerItemPositionsListener.itemPositions.addListener(itemPositionsListener);

    app.clearMessage();
  }

  _assignNewSong(final Song song) {
    widget._song = song;
    _song = song;
    _drumParts = _drumPartsList.songMatch(_song) ?? app.selectedDrumParts ?? defaultDrumParts;
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
    var size = PlatformDispatcher.instance.implicitView?.physicalSize; //fixme
    if (size != lastSize) {
      forceTableRedisplay();
      lastSize = size;
    }
  }

  @override
  void dispose() {
    logger.d('player: dispose()');
    _cancelIdleTimer();
    _songMaster.stop();

    _player = null;
    _playerIsOnTop = false;
    _songUpdate = null;
    songUpdateService.removeListener(songUpdateServiceListener);
    _songMaster.removeListener(songMasterListener);
    playerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _rawKeyboardListenerFocusNode.dispose();

    super.dispose();
  }

  //  update the song update service status
  void songUpdateServiceListener() {
    logger.log(_logLeaderFollower, 'songUpdateServiceListener(): $_songUpdate');
    setState(() {});
  }

  void songMasterListener() {
    _songMasterNotifier.songMaster = _songMaster;
    logger.log(
        _logSongMaster,
        'songMasterListener:  leader: ${songUpdateService.isLeader}  ${DateTime.now()}'
        ', songPlayMode: ${_songMaster.songUpdateState.name}'
        ', moment: ${_songMaster.momentNumber}'
        ', lyricSection: ${_song.getSongMoment(_songMaster.momentNumber ?? 0)?.lyricSection.index}');

    //  follow the song master moment number
    switch (songUpdateState) {
      case SongUpdateState.none:
      case SongUpdateState.idle:
      case SongUpdateState.drumTempo:
        if (_songMaster.songUpdateState.isPlaying) {
          //  cancel the cell highlight
          _playMomentNotifier.playMoment = null;

          //  follow the song master's play mode
          setState(() {
            songUpdateState = _songMaster.songUpdateState;
            _clearCountIn();
          });
        }
        break;
      case SongUpdateState.playing:
      case SongUpdateState.pause:
        //  select the current measure
        if (_songMaster.momentNumber != null) {
          //  tell the followers to follow, including the count in
          leaderSongUpdate(_songMaster.momentNumber!);
          _playMomentNotifier.playMoment = PlayMoment(
              SongUpdateState.playing, _songMaster.momentNumber!, _song.getSongMoment(_songMaster.momentNumber!));

          if (_songMaster.momentNumber! >= 0) {
            var row = _lyricsTable.songMomentNumberToRow(_songMaster.momentNumber);
            _lyricSectionNotifier.setIndexRow(_lyricsTable.rowToLyricSectionIndex(row), row);
            _itemScrollToRow(row, priorIndex: _lyricsTable.songMomentNumberToRow(_songMaster.lastMomentNumber));
          }
        }
        break;
    }
    if (songUpdateState != _songMaster.songUpdateState) {
      setState(() {
        songUpdateState = _songMaster.songUpdateState;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    appKeyCallbacksClear();
    _resetIdleTimer();
    app.screenInfo.refresh(context);
    appWidgetHelper = AppWidgetHelper(context);
    _song = widget._song; //  default only

    logger.log(_logBuild, 'player build: ModalRoute: ${ModalRoute.of(context)?.settings.name}');

    logger.log(
        _logBuild,
        'player build: $_song, ${_song.songId}, playMomentNumber: ${_playMomentNotifier.playMoment?.playMomentNumber}'
        ', songPlayMode: ${songUpdateState.name}');

    //  deal with song updates
    if (_songUpdate != null) {
      if (!_song.songBaseSameContent(_songUpdate!.song) || displayKeyOffset != app.displayKeyOffset) {
        _assignNewSong(_songUpdate!.song);
        _playMomentNotifier.playMoment =
            PlayMoment(_songUpdate!.state, _songUpdate?.songMoment?.momentNumber ?? 0, _songUpdate!.songMoment);
        _selectLyricSection(_songUpdate?.songMoment?.lyricSection.index //
            ??
            _lyricSectionNotifier.lyricSectionIndex); //  safer to stay on the current index

        if (_songUpdate!.state == SongUpdateState.playing) {
          performPlay();
        } else {
          simpleStop();
        }

        logger.log(
            _logLeaderFollower,
            'player follower: $_song, selectedSongMoment: ${_playMomentNotifier.playMoment?.songMoment?.momentNumber}'
            ' songPlayMode: $songUpdateState');
      }
      setSelectedSongKey(_songUpdate!.currentKey);
    }

    displayKeyOffset = app.displayKeyOffset;

    final fontSize = app.screenInfo.fontSize;
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
      final double onStringWidth = textWidth(context, headerTextStyle, onString);

      for (int i = 0; i < steps; i++) {
        music_key.Key value = rolledKeyList[i] ?? _selectedSongKey;

        //  deal with the Gb/F# duplicate issue
        if (value.halfStep == _selectedSongKey.halfStep) {
          value = _selectedSongKey;
        }

        //logger.log(_logMusicKey, 'key value: $value');

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
        if (value < MusicConstants.minBpm || value > MusicConstants.maxBpm) {
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

    const hoverColor = App.universalAccentColor;

    logger.log(
        _logScroll,
        // ' boxMarker: $boxMarker'
        ', _scrollAlignment: $_scrollAlignment'
        ', _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}');
    logger.log(_logMode, 'playMode: $songUpdateState');

    _showCapo = capoIsPossible() && _isCapo;

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

    if (_appOptions.ninJam) {
      _ninJam = NinJam(_song, key: _displaySongKey, keyOffset: _displaySongKey.getHalfStep() - _song.key.getHalfStep());
    }

    List<Widget> lyricsTableItems = _lyricsTable.lyricsTableItems(
      _song,
      context,
      musicKey: _displaySongKey,
      expanded: !compressRepeats,
    );
    _scrollablePositionedList ??= _appOptions.userDisplayStyle == UserDisplayStyle.banner
        ? ScrollablePositionedList.builder(
            itemCount: _song.songMoments.length + 1,
            itemScrollController: _itemScrollController,
            itemPositionsListener: playerItemPositionsListener,
            itemBuilder: (context, index) {
              return lyricsTableItems[Util.limit(index, 0, lyricsTableItems.length) as int];
            },
            scrollDirection: Axis.horizontal,
            //minCacheExtent: app.screenInfo.mediaHeight, //  fixme: is this desirable?
          )
        : //  all other display styles
        ScrollablePositionedList.builder(
            itemCount: lyricsTableItems.length,
            itemScrollController: _itemScrollController,
            itemPositionsListener: playerItemPositionsListener,
            itemBuilder: (context, index) {
              return lyricsTableItems[Util.limit(index, 0, lyricsTableItems.length) as int];
            },
            scrollDirection: Axis.vertical,
            //minCacheExtent: app.screenInfo.mediaHeight, //  fixme: is this desirable?
          );

    final backBar = appWidgetHelper.backBar(
        titleWidget: Row(
          children: [
            Flexible(
              child: AppTooltip(
                message: 'Click to hear the song on youtube.com',
                child: InkWell(
                  onTap: () {
                    openLink(titleAnchor());
                  },
                  hoverColor: hoverColor,
                  child: Text(
                    _song.toString(),
                    style: appBarTextStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          //  fix: on small screens, only the title flexes
          Flexible(
            child: AppTooltip(
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
          ),
          if (playerSinger != null)
            Flexible(
              child: Text(
                ', sung by $playerSinger',
                style: appBarTextStyle,
                softWrap: false,
              ),
            ),
          const AppSpace(),
        ],
        //  for the leading, i.e. the left most icon
        onPressed: () {
          //  avoid race condition with the listener notification
          _songMaster.removeListener(songMasterListener);
          _songMaster.stop();
        });

    // boxMarker = boxCenterHeight(AppBar().preferredSize.height );

    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _playMomentNotifier),
          ChangeNotifierProvider.value(value: _songMasterNotifier),
          ChangeNotifierProvider.value(value: _lyricSectionNotifier),
        ],
        builder: (context, child) {
          return RawKeyboardListener(
            focusNode: _rawKeyboardListenerFocusNode,
            autofocus: true,
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: theme.colorScheme.background,
                  appBar: backBar,
                  body: Stack(
                    children: <Widget>[
                      //  smooth background
                      Positioned(
                        top: 0,
                        child: Container(
                          constraints:
                              BoxConstraints.loose(Size(app.screenInfo.mediaWidth, app.screenInfo.mediaHeight)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                theme.colorScheme.background,
                                App.measureContainerBackgroundColor,
                                App.measureContainerBackgroundColor,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // //  center marker
                      // if (_centerSelections &&
                      //     (_appOptions.playerScrollHighlight == PlayerScrollHighlight.off || kDebugMode))
                      //   Positioned(
                      //     top: boxMarker,
                      //     child: Container(
                      //       constraints: BoxConstraints.loose(Size(app.screenInfo.mediaWidth / 128, 3)),
                      //       decoration: const BoxDecoration(
                      //         color: Colors.black87,
                      //       ),
                      //     ),
                      //   ),

                      //  song chords and lyrics
                      Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          textDirection: TextDirection.ltr,
                          children: <Widget>[
                            //  song chords and lyrics
                            if (lyricsTableItems.isNotEmpty) //  ScrollablePositionedList messes up otherwise
                              Expanded(
                                  child: GestureDetector(
                                      onTapDown: (details) {
                                        //  doesn't apply to pro display style
                                        if (_appOptions.userDisplayStyle == UserDisplayStyle.proPlayer) {
                                          return;
                                        }

                                        //  respond to taps above and below the middle of the screen
                                        if (_appOptions.tapToAdvance == TapToAdvance.upOrDown) {
                                          if (songUpdateState != SongUpdateState.playing) {
                                            //  start manual play
                                            setStatePlay();
                                          } else {
                                            //  while playing:
                                            var offset = _tableGlobalOffset();
                                            if (details.globalPosition.dx < app.screenInfo.mediaWidth / 4) {
                                              //  tablet left arrow
                                              bpmBump(-1);
                                            } else if (details.globalPosition.dx > app.screenInfo.mediaWidth * 3 / 4) {
                                              //  tablet right arrow
                                              bpmBump(1);
                                            } else {
                                              if (details.globalPosition.dy > offset.dy) {
                                                if (details.globalPosition.dy < app.screenInfo.mediaHeight / 2) {
                                                  //  tablet up arrow
                                                  _songMaster.repeatSectionIncrement();
                                                } else {
                                                  //  tablet down arrow
                                                  _songMaster.skipCurrentSection();
                                                }
                                              }
                                            }
                                          }
                                        }
                                      },
                                      child: _scrollablePositionedList)),
                          ]),
                      //  controls
                      Container(
                        padding: const EdgeInsets.all(6.0),
                        color: const Color(0xf0e4ecfc), //  light blue with a little transparency
                        //            theme.colorScheme.background.withAlpha(230),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            textDirection: TextDirection.ltr,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              //  top section
                              if (songUpdateService.isFollowing)
                                Text(
                                  'Following ${songUpdateService.leaderName}',
                                  style: headerTextStyle,
                                ),

                              if (!songUpdateService.isFollowing)
                                //  play mode selection
                                SegmentedButton<SongUpdateState>(
                                  showSelectedIcon: false,
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                      (Set<MaterialState> states) {
                                        if (states.contains(MaterialState.disabled)) {
                                          return App.disabledColor;
                                        }
                                        return App.appBackgroundColor;
                                      },
                                    ),
                                    visualDensity: const VisualDensity(vertical: VisualDensity.minimumDensity),
                                  ),
                                  segments: <ButtonSegment<SongUpdateState>>[
                                    ButtonSegment<SongUpdateState>(
                                      value: SongUpdateState.idle,
                                      icon: appIcon(
                                        Icons.stop,
                                        size: 1.75 * fontSize,
                                        color: songUpdateState == SongUpdateState.idle ? Colors.red : Colors.white,
                                      ),
                                      tooltip:
                                          _appOptions.toolTips ? 'Stop playing the song.$_playStopPauseHints' : null,
                                      enabled: !songUpdateService.isFollowing,
                                    ),
                                    ButtonSegment<SongUpdateState>(
                                      value: SongUpdateState.playing,
                                      icon: appIcon(
                                        Icons.play_arrow,
                                        size: 1.75 * fontSize,
                                        color: songUpdateState == SongUpdateState.playing ? Colors.red : Colors.white,
                                      ),
                                      tooltip: _appOptions.toolTips ? 'Play the song.$_playStopPauseHints' : null,
                                      enabled: !songUpdateService.isFollowing,
                                    ),
                                    //  hide the pause unless we are in play
                                    if (songUpdateState == SongUpdateState.playing ||
                                        songUpdateState == SongUpdateState.pause)
                                      ButtonSegment<SongUpdateState>(
                                        value: SongUpdateState.pause,
                                        icon: appIcon(
                                          Icons.pause,
                                          size: 1.75 * fontSize,
                                          color: songUpdateState == SongUpdateState.pause
                                              ? Colors.yellowAccent
                                              : Colors.white,
                                        ),
                                        tooltip: _appOptions.toolTips ? 'Pause the playing.$_playStopPauseHints' : null,
                                        enabled: !songUpdateService.isFollowing,
                                      ),
                                  ],
                                  selected: <SongUpdateState>{songUpdateState},
                                  onSelectionChanged: (Set<SongUpdateState> newSelection) {
                                    // logger.i('onSelectionChanged: $newSelection');
                                    switch (newSelection.first) {
                                      case SongUpdateState.none:
                                      case SongUpdateState.idle:
                                      case SongUpdateState.drumTempo:
                                        performStop();
                                        break;
                                      case SongUpdateState.playing:
                                        performPlay();
                                        break;
                                      case SongUpdateState.pause:
                                        performPause();
                                        break;
                                    }
                                  },
                                ),

                              //  top section when idle
                              if (songUpdateState == SongUpdateState.idle)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppWrapFullWidth(
                                        alignment: WrapAlignment.spaceBetween,
                                        spacing: fontSize,
                                        children: [
                                          if (app.message.isNotEmpty)
                                            app.messageTextWidget(AppKeyEnum.playerErrorMessage),
                                          if (_showCapo)
                                            Text(
                                              _capoLocation > 0 ? 'Capo on $_capoLocation' : 'No capo needed',
                                              style: headerTextStyle,
                                              softWrap: false,
                                            ),
                                          // //  recommend a blues harp
                                          // Text(
                                          //   'Blues harp: ${selectedSongKey.nextKeyByFifth()}',
                                          //   style: headerTextStyle,
                                          //   softWrap: false,
                                          // ),
                                        ]),
                                    //  second top row
                                    AppRow(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                                      if (app.fullscreenEnabled && !app.isFullScreen)
                                        appButton('Fullscreen', appKeyEnum: AppKeyEnum.playerFullScreen, onPressed: () {
                                          app.requestFullscreen();
                                        }),
                                      AppRow(
                                        children: [
                                          if (!songUpdateService.isFollowing)
                                            //  key change
                                            AppRow(
                                              children: [
                                                AppTooltip(
                                                  message: 'Transcribe the song to the selected key.',
                                                  child: Text(
                                                    'Key: ',
                                                    style: headerTextStyle,
                                                    softWrap: false,
                                                  ),
                                                ),
                                                appDropdownButton<music_key.Key>(
                                                  AppKeyEnum.playerMusicKey,
                                                  keyDropDownMenuList,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      if (value != null) {
                                                        setSelectedSongKey(value);
                                                      }
                                                    });
                                                  },
                                                  value: _selectedSongKey,
                                                  style: headerTextStyle,
                                                  // iconSize: lookupIconSize(),
                                                  // itemHeight: max(headerTextStyle.fontSize ?? kMinInteractiveDimension,
                                                  //     kMinInteractiveDimension),
                                                ),
                                                if (app.isScreenBig) const AppSpace(),
                                                if (app.isScreenBig)
                                                  AppTooltip(
                                                    message: 'Move the key one half step up.',
                                                    child: appIconWithLabelButton(
                                                      appKeyEnum: AppKeyEnum.playerKeyUp,
                                                      icon: appIcon(
                                                        Icons.arrow_upward,
                                                      ),
                                                      onPressed: () {
                                                        if (!_isAnimated) {
                                                          setState(() {
                                                            setSelectedSongKey(_selectedSongKey.nextKeyByHalfStep());
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                if (app.isScreenBig) const AppSpace(space: 5),
                                                if (app.isScreenBig)
                                                  AppTooltip(
                                                    message: 'Move the key one half step down.',
                                                    child: appIconWithLabelButton(
                                                      appKeyEnum: AppKeyEnum.playerKeyDown,
                                                      icon: appIcon(
                                                        Icons.arrow_downward,
                                                      ),
                                                      onPressed: () {
                                                        if (!_isAnimated) {
                                                          setState(() {
                                                            setSelectedSongKey(
                                                                _selectedSongKey.previousKeyByHalfStep());
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          if (songUpdateService.isFollowing)
                                            AppTooltip(
                                              message:
                                                  'When following the leader, the leader will select the key for you.\n'
                                                  'To correct this from the main screen: menu (hamburger), Options, Hosts: None',
                                              child: Text(
                                                'Key: $_selectedSongKey',
                                                style: headerTextStyle,
                                                softWrap: false,
                                              ),
                                            ),
                                          const AppSpace(),
                                          if (displayKeyOffset > 0 || (_showCapo && _capoLocation > 0))
                                            Text(
                                              ' ($_selectedSongKey${displayKeyOffset > 0 ? '+$displayKeyOffset' : ''}'
                                              '${_showCapo && _capoLocation > 0 ? '-$_capoLocation' : ''}=$_displaySongKey)',
                                              style: headerTextStyle,
                                            ),
                                        ],
                                      ),
                                      if (app.isScreenBig && !songUpdateService.isFollowing)
                                        //  tempo change
                                        AppRow(
                                          children: [
                                            AppTooltip(
                                              message: 'Beats per minute.  Mouse click here or tap the m key\n'
                                                  ' to generate the tempo.',
                                              child: appButton(
                                                'BPM:',
                                                appKeyEnum: AppKeyEnum.playerTempoTap,
                                                onPressed: () {
                                                  tempoTap();
                                                },
                                              ),
                                            ),
                                            const AppSpace(),
                                            AppRow(
                                              children: [
                                                appDropdownButton<int>(
                                                  AppKeyEnum.playerBPM,
                                                  bpmDropDownMenuList,
                                                  onChanged: (value) {
                                                    if (value != null) {
                                                      setState(() {
                                                        playerSelectedBpm = value;
                                                        _songMaster.tapTempo(playerSelectedBpm!);
                                                        logger.log(
                                                            _logBPM, '_bpmDropDownMenuList: bpm: $playerSelectedBpm');
                                                      });
                                                    }
                                                  },
                                                  value: playerSelectedBpm ?? _song.beatsPerMinute,
                                                  style: headerTextStyle,
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
                                                    logger.log(_logBPM, 'speed: bpm: $playerSelectedBpm');
                                                  });
                                                },
                                              ),
                                          ],
                                        ),
                                      if (app.isScreenBig && songUpdateService.isFollowing)
                                        AppTooltip(
                                          message:
                                              'When following the leader, the leader will select the tempo (BPM) for you.\n'
                                              'To correct this from the main screen: menu (hamburger), Options, Hosts: None',
                                          child: Text(
                                            'BPM: ${playerSelectedBpm ?? _song.beatsPerMinute}',
                                            style: headerTextStyle,
                                          ),
                                        ),
                                      AppTooltip(
                                        message: 'Beats are a property of the song.\n'
                                            'Edit the song to change.',
                                        child: Text(
                                          'Beats: ${_song.timeSignature.beatsPerBar}',
                                          style: headerTextStyle,
                                          softWrap: false,
                                        ),
                                      ),
                                      // if (app.isScreenBig && !songUpdateService.isFollowing)
                                      //   AppTooltip(
                                      //     message: 'Select drums using the player setting\'s dialog, the gear icon',
                                      //     child: Text(
                                      //       'Drums: ${_songMaster.drumsAreMuted ? 'Muted' : _drumParts?.name ?? ''}',
                                      //       style: headerTextStyle,
                                      //       softWrap: false,
                                      //     ),
                                      //   ),
                                      // if (app.isScreenBig)
                                      //   //  leader/follower status
                                      //   AppTooltip(
                                      //     message: 'Control the leader/follower mode from the main menu:\n'
                                      //         'main screen: menu (hamburger), Options, Hosts',
                                      //     child: Text(
                                      //       songUpdateService.isConnected
                                      //           ? (songUpdateService.isLeader
                                      //               ? 'leading ${songUpdateService.host}'
                                      //               : (songUpdateService.leaderName == Song.defaultUser
                                      //                   ? 'on ${songUpdateService.host.replaceFirst('.local', '')}'
                                      //                   : 'following ${songUpdateService.leaderName}'))
                                      //           : (songUpdateService.isIdle ? '' : 'lost ${songUpdateService.host}!'),
                                      //       style: !songUpdateService.isConnected && !songUpdateService.isIdle
                                      //           ? headerTextStyle.copyWith(color: Colors.red)
                                      //           : headerTextStyle,
                                      //     ),
                                      //   ),
                                    ]),
                                  ],
                                ),

                              // //  chords used
                              // if (app.isScreenBig ) //  fixme: make scale chords used an option
                              //   Padding(
                              //     padding: const EdgeInsets.fromLTRB(_padding, _padding, _padding, 0.0),
                              //     child: Column(
                              //       children: [
                              //         const AppSpace(),
                              //         AppWrapFullWidth(
                              //           children: [
                              //             Text(
                              //               'Chords used: ',
                              //               style: headerTextStyle,
                              //             ),
                              //             Text(
                              //               _song.scaleChordsUsed().toString(),
                              //               style: headerTextStyle,
                              //             )
                              //           ],
                              //         ),
                              //       ],
                              //     ),
                              //   ),
                              //   const AppSpace(),
                              if (app.isScreenBig &&
                                  _appOptions.ninJam &&
                                  _ninJam.isNinJamReady &&
                                  songUpdateState == SongUpdateState.idle)
                                AppWrapFullWidth(spacing: 20, children: [
                                  const AppSpace(),
                                  AppWrap(spacing: 10, children: [
                                    Text(
                                      'Ninjam: BPM: ${playerSelectedBpm ?? _song.beatsPerMinute.toString()}',
                                      style: headerTextStyle,
                                      softWrap: false,
                                    ),
                                    appIconWithLabelButton(
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
                                    appIconWithLabelButton(
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
                                    appIconWithLabelButton(
                                      appKeyEnum: AppKeyEnum.playerCopyNinjamChords,
                                      icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: _ninJam.toMarkup()));
                                      },
                                    ),
                                  ]),
                                ]),
                              // const AppSpace(),
                              // _countInWidget,
                            ]),
                      ),

                      // ),
                    ],
                  ),
                ),

                //  player settings
                if (!songUpdateState.isPlayingOrPaused)
                  Column(
                    children: [
                      AppSpace(
                        verticalSpace: AppBar().preferredSize.height + fontSize / 4,
                      ),
                      AppWrapFullWidth(alignment: WrapAlignment.end, children: [
                        //  player options
                        AppWrap(children: [
                          //  song edit
                          AppTooltip(
                            message: songUpdateState.isPlaying
                                ? 'Song is playing'
                                : (songUpdateService.isFollowing
                                    ? 'Followers cannot edit.\nDisable following back on the main Options\n'
                                        ' to allow editing.'
                                    : (app.isEditReady ? 'Edit the song' : 'Device is not edit ready')),
                            child: appIconWithLabelButton(
                              appKeyEnum: AppKeyEnum.playerEdit,
                              icon: appIcon(
                                Icons.edit,
                              ),
                              onPressed:
                                  (!songUpdateState.isPlaying && !songUpdateService.isFollowing && app.isEditReady)
                                      ? () {
                                          navigateToEdit(context, _song);
                                        }
                                      : null,
                            ),
                          ),
                          AppSpace(horizontalSpace: fontSize),
                        ]),
                        AppTooltip(
                          message: 'Show the player settings dialog.',
                          child: appIconWithLabelButton(
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
                        AppSpace(horizontalSpace: fontSize),
                      ]),
                    ],
                  ),

                if (songUpdateState.isPlayingOrPaused)
                  Column(
                    children: [
                      AppSpace(
                        verticalSpace: appWidgetHelper.toolbarHeight,
                      ),
                      AppWrapFullWidth(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            AppWrap(
                              children: [
                                Consumer<SongMasterNotifier>(builder: (context, songMasterNotifier, child) {
                                  var style = generateAppTextStyle(
                                    fontSize: app.screenInfo.fontSize,
                                    decoration: TextDecoration.none,
                                    color: Colors.redAccent,
                                    backgroundColor: const Color(0xffeff4fd), //  blended color
                                  );
                                  switch (songMasterNotifier.songMaster?.repeatSection ?? 0) {
                                    case 1:
                                      return Text(
                                        'Repeat this section',
                                        style: style,
                                      );
                                    case 2:
                                      return Text(
                                        'Repeat the prior section',
                                        style: style,
                                      );
                                    default:
                                      return NullWidget();
                                  }
                                }),
                              ],
                            ),
                            _DataReminderWidget(songUpdateState.isPlayingOrPaused, _songMaster),
                          ]),
                    ],
                  ),
              ],
            ),
          );
        });
  }

  KeyEventResult playerOnRawKey(FocusNode node, RawKeyEvent value) {
    logger.log(_logKeyboard, 'playerOnRawKey(): event: $value');

    if (!_playerIsOnTop) {
      return KeyEventResult.ignored;
    }

    //  only deal with new key down events
    if (value.runtimeType != RawKeyDownEvent) {
      return KeyEventResult.ignored;
    }
    RawKeyDownEvent e = value as RawKeyDownEvent;
    logger.log(
        _logKeyboard,
        '_playerOnKey(): ${e.data.logicalKey}'
        ', ctl: ${e.isControlPressed}'
        ', shf: ${e.isShiftPressed}'
        ', alt: ${e.isAltPressed}');

    if (e.isKeyPressed(LogicalKeyboardKey.keyM)) {
      tempoTap();
      return KeyEventResult.handled;
    } else if (e.isKeyPressed(LogicalKeyboardKey.space)) {
      switch (songUpdateState) {
        case SongUpdateState.idle:
        case SongUpdateState.none:
        case SongUpdateState.drumTempo:
          //  start manual play
          setStatePlay();
          break;
        case SongUpdateState.playing:
        case SongUpdateState.pause:
          //  toggle pause, that is, play to pause or pause to play
          _songMaster.pauseToggle();
          break;
      }
      return KeyEventResult.handled;
    } else if (
        //  workaround for cheap foot pedal... only outputs b
        e.isKeyPressed(LogicalKeyboardKey.keyB)) {
      switch (songUpdateState) {
        case SongUpdateState.idle:
        case SongUpdateState.none:
        case SongUpdateState.drumTempo:
          //  start manual play
          setStatePlay();
          break;
        case SongUpdateState.playing:
        case SongUpdateState.pause:
          //  stay in pause, that is, manual mode
          _bump(1);
          break;
      }
      return KeyEventResult.handled;
    } else if (!songUpdateService.isFollowing) {
      if (e.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
        logger.d('arrowDown');
        _bump(1);
        return KeyEventResult.handled;
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
        logger.log(_logKeyboard, 'arrowUp');
        _bump(-1);
        return KeyEventResult.handled;
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        logger.d('arrowRight');
        bpmBump(1);
        return KeyEventResult.handled;
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
        logger.log(_logKeyboard, 'arrowLeft');
        bpmBump(-1);
        return KeyEventResult.handled;
      } else if (e.isKeyPressed(LogicalKeyboardKey.keyZ) || e.isKeyPressed(LogicalKeyboardKey.keyQ)) {
        if (songUpdateState.isPlaying) {
          performStop();
        } else {
          logger.log(_logKeyboard, 'player: pop the navigator');
          _songMaster.stop();
          _cancelIdleTimer();
          Navigator.pop(context);
        }
        return KeyEventResult.handled;
      } else if (e.isKeyPressed(LogicalKeyboardKey.numpadEnter) || e.isKeyPressed(LogicalKeyboardKey.enter)) {
        if (songUpdateState.isPlaying) {
          performStop();
          return KeyEventResult.handled;
        }
      }
    }
    logger.i('_playerOnKey(): ignored');
    return KeyEventResult.ignored;
  }

  playDrums() {
    _songMaster.playDrums(_drumParts, bpm: playerSelectedBpm ?? _song.beatsPerMinute);
  }

  // double boxCenterHeight(final double toolbarHeight) {
  //  fixme: this is wrong
  //   return 2*toolbarHeight + app.screenInfo.mediaHeight * _scrollAlignment;
  // }

  _clearCountIn() {
    _updateCountIn(-countInMax);
  }

  _updateCountIn(int countIn) {
    _countIn = countIn;
    logger.t('countIn: $countIn');
    if (countIn > 0 && countIn < countInMax) {
      _countInWidget = Container(
        margin: const EdgeInsets.all(12.0),
        padding: const EdgeInsets.symmetric(horizontal: _padding),
        color: App.defaultBackgroundColor,
        child: Text('Count in: $countIn',
            style: _lyricsTable.lyricsTextStyle
                .copyWith(color: App.defaultForegroundColor, backgroundColor: App.defaultBackgroundColor)),
      );
      _playMomentNotifier.playMoment = null;
    } else {
      _countInWidget = NullWidget();
    }
    logger.t('_countInWidget.runtimeType: ${_countInWidget.runtimeType}');
  }

  /// bump the bpm up or down
  bpmBump(final int bump) {
    int nowUs = DateTime.now().microsecondsSinceEpoch;

    if (nowUs - _lastBpmBumpUs < 0.5 * Duration.microsecondsPerSecond) {
      if (bump.sign == _lastBpmBump.sign) {
        _bpmBumpStep++;
      } else {
        _lastBpmBump = 0;
        _bpmBumpStep = 0;
      }
    } else {
      _bpmBumpStep = 0;
    }

    _lastBpmBumpUs = nowUs;
    _lastBpmBump = bump;

    _changeBPM((playerSelectedBpm ?? _song.beatsPerMinute) +
        bump.sign * _bumpSteps[Util.indexLimit(_bpmBumpStep, _bumpSteps)]);

    logger.log(
        _logBPM,
        'BPM bump($bump): $_bpmBumpStep/${_bumpSteps.length}'
        ': ${_bumpSteps[Util.indexLimit(_bpmBumpStep, _bumpSteps)]}');
  }

  /// bump by section only if paused
  _bump(final int bump) {
    switch (songUpdateState) {
      case SongUpdateState.pause:
        _sectionBump(bump);
        break;
      case SongUpdateState.idle:
      case SongUpdateState.none:
      case SongUpdateState.playing:
      case SongUpdateState.drumTempo:
        _rowBump(bump);
        break;
    }
  }

  _sectionBump(final int bump) {
    logger.log(_logSongMasterBump, '  _sectionBump($bump): moment: ${_songMaster.momentNumber}');

    var lyricSectionIndex = _song.getSongMoment(_songMaster.momentNumber ?? -1)?.lyricSection.index;
    if (lyricSectionIndex != null) {
      lyricSectionIndex += bump;
      logger.log(_logSongMasterBump,
          '  _sectionBump($bump): moment: ${_songMaster.momentNumber}, to section: $lyricSectionIndex');
      var moment = _song.getFirstSongMomentAtLyricSectionIndex(lyricSectionIndex);
      if (moment != null) {
        _songMaster.skipToMomentNumber(moment.momentNumber);
      }
    }
  }

  /// note: only bumps one row at a time
  _rowBump(final int bump) {
    logger.log(_logSongMasterBump, '  _rowBump($bump): moment: ${_songMaster.momentNumber}');
    if (_songMaster.momentNumber != null) {
      if (bump > 0) {
        //  bump forwards
        SongMoment? moment = _song.getFirstSongMomentAtNextRow(_songMaster.momentNumber!);
        if (moment != null) {
          logger.log(_logSongMasterBump, '  _rowBump($bump): moment: ${_songMaster.momentNumber} to moment: $moment');
          _songMaster.skipToMomentNumber(moment.momentNumber);
        }
      } else {
        //  bump backwards
        SongMoment? moment = _song.getFirstSongMomentAtPriorRow(_songMaster.momentNumber!);
        if (moment != null) {
          logger.log(_logSongMasterBump, '  _rowBump($bump): moment: ${_songMaster.momentNumber} to moment: $moment');
          _songMaster.skipToMomentNumber(moment.momentNumber);
        }
      }
    }
  }

  void itemPositionsListener() {
    if (_isAnimated || !songUpdateService.isLeader) {
      //  don't follow the animation
      return;
    }

    //  move to the scrolled to location, if scrolled
    var orderedSet = SplayTreeSet<ItemPosition>((e1, e2) {
      return e1.index.compareTo(e2.index);
    })
      ..addAll(playerItemPositionsListener.itemPositions.value);
    if (orderedSet.isNotEmpty) {
      var firstItem = orderedSet.first;
      if (firstItem.index > 0) {
        //  find the index at the scroll alignment
        var selectedItem = firstItem;
        {
          for (ItemPosition item in orderedSet) {
            if (item.itemLeadingEdge < _scrollAlignment + 0.04 /*tolerance*/) {
              selectedItem = item;
            }
          }
        }
        var songMasterIndex = _lyricsTable.songMomentNumberToRow(_songMaster.momentNumber);
        logger.log(
            _logPlayerItemPositions,
            'itemPositionsListener():  skip to: ${firstItem.index}'
            ', selectedItem: ${selectedItem.index} at ${_lyricsTable.rowToMomentNumber(selectedItem.index)}'
            ', _songMaster: $songMasterIndex at ${_songMaster.momentNumber}'
            ', isAnimated: $_isAnimated'
            //
            );

        //  move the song to the scrolled location
        if (selectedItem.index != songMasterIndex) {
          _songMaster.skipToMomentNumber(_lyricsTable.rowToMomentNumber(selectedItem.index));
        }
      }
    }

    // switch (songUpdateState) {
    //   case SongUpdateState.idle:
    //   case SongUpdateState.none:
    //   case SongUpdateState.pause:
    //     //  followers get to follow even if not in play
    //
    //     // switch (appOptions.userDisplayStyle) {
    //     //   case UserDisplayStyle.banner:
    //     //     break;
    //     //   default:
    //     //     logger.t('_isAnimated: $_isAnimated, playMode: $songUpdateState');
    //     //     if (_isAnimated || songUpdateState.isPlaying) {
    //     //       return; //  don't follow scrolling when animated or playing
    //     //     }
    //     //     var orderedSet = SplayTreeSet<ItemPosition>((e1, e2) {
    //     //       return e1.index.compareTo(e2.index);
    //     //     })
    //     //       ..addAll(playerItemPositionsListener.itemPositions.value);
    //     //     if (orderedSet.isNotEmpty) {
    //     //       var item = orderedSet.first;
    //     //       _selectMomentByRow(item.index + (item.itemLeadingEdge < -0.04 ? 1 : 0));
    //     //       logger.log(
    //     //           _logPlayerItemPositions,
    //     //           'playerItemPositionsListener:  length: ${orderedSet.length}'
    //     //           ', _lyricSectionNotifier.index: ${_lyricSectionNotifier.lyricSectionIndex}');
    //     //       logger.log(
    //     //           _logPlayerItemPositions,
    //     //           '   ${item.index}: ${item.itemLeadingEdge.toStringAsFixed(3)}'
    //     //           ' to ${item.itemTrailingEdge.toStringAsFixed(3)}');
    //     //     }
    //     //     break;
    //     // }
    //     break;
    //   case SongUpdateState.playing:
    //     //  following done by the song update service
    //     break;
    // }
  }

  scrollToLyricSection(int index, {final bool force = false}) {
    if (widget._song.lyricSections.isEmpty) {
      return; //  safety
    }
    index = Util.indexLimit(index, widget._song.lyricSections); //  safety

    final priorIndex = _lyricSectionNotifier.lyricSectionIndex;
    logger.log(_logScroll, 'scrollToLyricSection(): $index from $priorIndex, _isAnimated: $_isAnimated');
    if (_lyricSectionNotifier.lyricSectionIndex == index && !force) {
      //  nothing to do
      return;
    }

    _selectLyricSection(index);

    if (_appOptions.userDisplayStyle == UserDisplayStyle.proPlayer) {
      //  notify lyrics of selection... even if there is no scroll
      logger.t('proPlayer: _lyricSectionNotifier.index: ${_lyricSectionNotifier.lyricSectionIndex}');
      return; //  pro's never scroll!
    }
    _itemScrollToRow(_lyricsTable.lyricSectionIndexToRow(index), force: force, priorIndex: priorIndex);
  }

  _itemScrollToRow(int row, {final bool force = false, int? priorIndex}) {
    //logger.i('_itemScrollToRow($row, $force, $priorIndex):');
    if (_itemScrollController.isAttached) {
      if (_isAnimated) {
        logger.log(_logScrollAnimation, 'scrollTo(): double animation!, force: $force, priorIndex: $priorIndex');
        return;
      }
      if (row < 0) {
        return;
      }
      if (row == _lastRowIndex) {
        //logger.i('row == _lastRowIndex: $row');
        return; //fixme: why?
      }

      //  limit the scrolling at the start of the play list
      // var alignment =   _scrollAlignment;
      //   {
      //     SplayTreeSet<ItemPosition> set = SplayTreeSet<ItemPosition>((key1, key2) {
      //       return key1.index.compareTo(key2.index);
      //     })
      //       ..addAll(playerItemPositionsListener.itemPositions.value);
      //     if (set.isNotEmpty && set.first.index == 0 && _songMaster.repeatSection == 0) {
      //       for (var itemPosition in set) {
      //         logger.i('  $row: $itemPosition < $_scrollAlignment, boxCenter: $boxMarker');
      //         //  don't scroll backwards past the beginning
      //         if (row == itemPosition.index && itemPosition.itemLeadingEdge < _scrollAlignment) {
      //           //  deal with bounce on mac browsers
      //           //  fixme: may not work on all songs and all mac browsers if the intro is tiny
      //           logger.i('row == _lastRowIndex: $row, _songMaster.repeatSection: ${_songMaster.repeatSection}');
      //           alignment = itemPosition.itemLeadingEdge;
      //         }
      //         if ( itemPosition.itemLeadingEdge > _scrollAlignment){
      //           break;
      //         }
      //       }
      //     }
      //     logger.i('  end: ${set.last}, row: $row/${_lyricsTable.rowCount}');
      //   }

      //  limit the scrolling at the end of the play list
      if (row >= _lyricsTable.rowCount) {
        //  assumes the outro is sane with respect to the vertical space below the scroll alignment
        return;
      }

      //  local scroll
      _isAnimated = true;

      //  guess a duration based on the song and the row
      var secondsPerMeasure = _song.beatsPerBar * 60.0 / _song.beatsPerMinute;
      // var rowMomentNumber = _lyricsTable.rowToMomentNumber(row);
      // var nextRowMomentNumber = _lyricsTable.rowToMomentNumber(row + 1);
      // if (nextRowMomentNumber == 0) {
      //   nextRowMomentNumber = _lyricsTable.rowToMomentNumber(row + 2);
      // }
      double rowTime = secondsPerMeasure;
      priorIndex ??= _lastRowIndex;
      // if (row > priorIndex && nextRowMomentNumber > rowMomentNumber) {
      //   rowTime = ((_song.getSongMoment(nextRowMomentNumber)?.beatNumber ?? 0) -
      //           (_song.getSongMoment(rowMomentNumber)?.beatNumber ?? 0)) *
      //       60.0 /
      //       _song.beatsPerMinute;
      //   logger.log(
      //       _logScrollAnimation,
      //       'scrollTo(): index: $row, rowMomentNumber: $rowMomentNumber to $nextRowMomentNumber: '
      //           ' rowTime: ${rowTime.toStringAsFixed(3)}');
      // }

      var duration = force
          ? const Duration(milliseconds: 20)
          : (row >= priorIndex
              ? Duration(milliseconds: (0.8 * rowTime * Duration.millisecondsPerSecond).toInt())
              : const Duration(milliseconds: 400));
      logger.log(
          _logScrollAnimation,
          'scrollTo(): index: $row, _lastRowIndex: $_lastRowIndex, priorIndex: $priorIndex'
          ', duration: $duration, rowTime: ${rowTime.toStringAsFixed(3)}');
      // logger.log(_logScrollAnimation, 'scrollTo(): ${StackTrace.current}');

      _itemScrollController
          .scrollTo(index: row, duration: duration, alignment: _scrollAlignment, curve: Curves.decelerate)
          .then((value) {
        // Future.delayed(const Duration(milliseconds: 400)).then((_) {
        _lastRowIndex = row;
        _isAnimated = false;
        logger.log(_logScrollAnimation, 'scrollTo(): post: _lastRowIndex: $row');
        // });
      });
    }
  }

  _selectMoment(final int momentNumber) {
    var moment = _song.getSongMoment(momentNumber);
    if (moment == null) {
      return;
    }

    //  update the widgets
    var row = _lyricsTable.songMomentNumberToRow(momentNumber);
    _lyricSectionNotifier.setIndexRow(moment.lyricSection.index, row);
    _itemScrollToRow(row);
    logger.log(_logManualPlayScrollAnimation, 'manualPlay sectionRequest: index: $_lyricSectionNotifier');

    //  remote scroll for followers
    if (songUpdateService.isLeader) {
      switch (songUpdateState) {
        case SongUpdateState.playing:
          break;
        default:
          leaderSongUpdate(momentNumber);
          break;
      }
    }
  }

  _selectLyricSection(int lyricSectionIndex) {
    if (_song.lyricSections.isEmpty) {
      return; //  safety
    }
    lyricSectionIndex = Util.indexLimit(lyricSectionIndex, _song.lyricSections); //  safety

    //  update the widgets
    _lyricSectionNotifier.setIndexRow(lyricSectionIndex, _lyricsTable.lyricSectionIndexToRow(lyricSectionIndex));
    logger.log(_logManualPlayScrollAnimation,
        'manualPlay sectionRequest: index: $lyricSectionIndex, row: ${_lyricsTable.lyricSectionIndexToRow(lyricSectionIndex)}');

    //  remote scroll for followers
    if (songUpdateService.isLeader) {
      switch (songUpdateState) {
        case SongUpdateState.playing:
          break;
        default:
          {
            var lyricSection = _song.lyricSections[lyricSectionIndex];
            leaderSongUpdate(_song.firstMomentInLyricSection(lyricSection).momentNumber);
          }
          break;
      }
    }
  }

  /// send a leader song update to the followers
  void leaderSongUpdate(int momentNumber) {
    logger.log(_logLeaderSongUpdate, 'leaderSongUpdate( $momentNumber ), isLeader: ${songUpdateService.isLeader}');

    if (!songUpdateService.isLeader) {
      _lastSongUpdateSent = null;
      return;
    }

    //  don't send the update unless we have to
    if (_lastSongUpdateSent != null) {
      if (_lastSongUpdateSent!.song == widget._song &&
          _lastSongUpdateSent!.momentNumber == momentNumber &&
          _lastSongUpdateSent!.state == songUpdateState &&
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
    update.user = _appOptions.user;
    update.singer = playerSinger ?? 'unknown';
    update.state = songUpdateState;
    songUpdateService.issueSongUpdate(update);

    logger.log(
        _logLeaderFollower,
        'leaderSongUpdate: momentNumber: $momentNumber'
        ', state: $songUpdateState');
  }

  // IconData get playStopIcon => songUpdateState.isPlaying ? Icons.stop : Icons.play_arrow;

  performPlay() {
    logger.log(_logMode, 'manualPlay:');
    setState(() {
      switch (songUpdateState) {
        case SongUpdateState.pause:
          if (!songUpdateService.isFollowing) {
            _songMaster.resume();
          }
          break;
        default:
          songUpdateState = SongUpdateState.playing;
          _lastRowIndex = -1;
          setSelectedSongMoment(_song.songMoments.first);

          if (!songUpdateService.isFollowing) {
            _playMomentNotifier.playMoment =
                PlayMoment(SongUpdateState.playing, _songMaster.momentNumber ?? 0, _song.songMoments.first);
            _songMaster.playSong(widget._song, drumParts: _drumParts, bpm: playerSelectedBpm ?? _song.beatsPerMinute);
          }
          break;
      }
    });
  }

  setStatePlay() {
    setState(() {
      scrollToLyricSection(0); //  always start manual play from the beginning
      playDrums();
      performPlay();
    });
  }

  /// Workaround to avoid calling setState() outside of the framework classes
  void setPlayState() {
    if (_songUpdate != null && _song.songMoments.isNotEmpty) {
      var update = _songUpdate!;
      int momentNumber = Util.indexLimit(update.momentNumber, _song.songMoments);
      assert(momentNumber >= 0);
      assert(momentNumber < _song.songMoments.length);
      var songMoment = _song.songMoments[momentNumber];

      //  map state to mode   fixme: should reconcile the enums
      SongUpdateState newSongPlayMode = SongUpdateState.idle;
      switch (update.state) {
        case SongUpdateState.playing:
          if (!songUpdateState.isPlaying) {
            setPlayMode();
          }
          newSongPlayMode = SongUpdateState.playing;
          if (update.momentNumber <= 0) {
            setState(() {
              //  note: clear the countIn if zero
              _updateCountIn(-update.momentNumber);
            });
          }
          if (update.momentNumber >= 0) {
            _selectMoment(update.momentNumber);
          }
          break;
        default:
          newSongPlayMode = SongUpdateState.idle;
          scrollToLyricSection(songMoment.lyricSection.index);
          break;
      }
      if (songUpdateState != newSongPlayMode) {
        setState(() {
          songUpdateState = newSongPlayMode;
        });
      }
      _playMomentNotifier.playMoment = PlayMoment(update.state, update.momentNumber, songMoment);

      logger.log(
          _logLeaderFollower,
          'setPlayState: post state: ${update.state}, songPlayMode: ${songUpdateState.name}'
          ', _countIn: $_countIn'
          ', moment: ${update.momentNumber}');
    }
  }

  void setPlayMode() {
    songUpdateState = SongUpdateState.playing;
  }

  void performStop() {
    setState(() {
      simpleStop();
    });
  }

  void simpleStop() {
    songUpdateState = SongUpdateState.idle;
    _songMaster.stop();
    _playMomentNotifier.playMoment = null;
    logger.log(_logMode, 'simpleStop()');
    logger.log(_logScroll, 'simpleStop():');
  }

  void performPause() {
    setState(() {
      switch (songUpdateState) {
        case SongUpdateState.playing:
          songUpdateState = SongUpdateState.pause;
          _songMaster.pause();
          logger.log(_logMode, 'performPause(): playing to pause');
          break;
        default:
          break;
      }
    });
  }

  /// Adjust the displayed
  setSelectedSongKey(music_key.Key key) {
    logger.log(_logMusicKey, 'key: $key');

    //  add any offset
    music_key.Key newDisplayKey = key.nextKeyByHalfSteps(displayKeyOffset);
    logger.log(_logMusicKey, 'offsetKey: $newDisplayKey');

    //  deal with capo
    if (_showCapo) {
      _capoLocation = newDisplayKey.capoLocation;
      newDisplayKey = newDisplayKey.capoKey;
      logger.log(_logMusicKey, 'capo: $newDisplayKey + $_capoLocation');
    }

    //  don't process unless there was a change
    if (_selectedSongKey == key && _displaySongKey == newDisplayKey) {
      return; //  no change required
    }
    _selectedSongKey = key;
    playerSelectedSongKey = key;
    _displaySongKey = newDisplayKey;
    logger.log(
        _logMusicKey, '_setSelectedSongKey(): _selectedSongKey: $_selectedSongKey, _displaySongKey: $_displaySongKey');
    forceTableRedisplay();
    //
    // leaderSongUpdate(-1);
  }

  String titleAnchor() {
    //  remove the old "cover by" in title or artist
    //  otherwise there are poor matches on youtube
    String s = '${widget._song.title} ${widget._song.artist}'
            ' ${widget._song.coverArtist}'
        .replaceAll('cover by', '');
    return anchorUrlStart + Uri.encodeFull(s);
  }

  String artistAnchor() {
    return anchorUrlStart + Uri.encodeFull(widget._song.artist);
  }

  void navigateToEdit(BuildContext context, Song song) async {
    _playerIsOnTop = false;
    _cancelIdleTimer();
    await Navigator.pushNamed(
      context,
      Edit.routeName,
    );

    //  return to list if song was removed
    if (!app.allSongs.contains(_song)) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    _playerIsOnTop = true;
    _assignNewSong(app.selectedSong);
    _lyricSectionNotifier.setIndexRow(0, 0);
    forceTableRedisplay();
    _resetIdleTimer();
  }

  Future<void> navigateToDrums(BuildContext context, Song song) {
    _playerIsOnTop = false;
    _cancelIdleTimer();

    return Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => DrumScreen(
                song: song,
                isEditing: false,
              )),
    ).then((value) {
      _drumPartsList.match(song, app.selectedDrumParts);
      _appOptions.drumPartsListJson = _drumPartsList.toJson();

      logger.t('app.selectedDrumParts: ${app.selectedDrumParts}');
      logger.t('songMatch: ${_drumPartsList.songMatch(song)?.name}');
      logger.t('_drumPartsList: ${_drumPartsList.toJson()}');

      _playerIsOnTop = true;
      _assignNewSong(app.selectedSong);
      _lyricSectionNotifier.setIndexRow(0, 0);
      forceTableRedisplay();
      _resetIdleTimer();
    });
  }

  void forceTableRedisplay() {
    logger.log(_logBuild, 'forceTableRedisplay():');
    setState(() {
      _scrollablePositionedList = null;
    });
  }

  void adjustDisplay() {
    logger.log(_logBuild, 'adjustDisplay():');
    sectionSongMoments.clear();
    forceTableRedisplay();
  }

  /// only useful after the widget tree has been built!
  Offset _tableGlobalOffset() {
    if (_table.key == null) {
      return Offset.zero;
    }
    RenderObject? renderObject = (_table.key as GlobalKey).currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.localToGlobal(Offset.zero);
    }
    return Offset.zero;
  }

  bool almostEqual(double d1, double d2, double tolerance) {
    return (d1 - d2).abs() <= tolerance;
  }

  void setSelectedSongMoment(SongMoment? songMoment) {
    logger.log(
        _logScroll,
        'setSelectedSongMoment(): ${songMoment?.momentNumber}'
        ', _songPlayerChangeNotifier.songMoment: ${_playMomentNotifier.playMoment?.songMoment?.momentNumber}'
        ', _songUpdate: $_songUpdate'
        //
        );

    if (songMoment == null) {
      _playMomentNotifier.playMoment = null;
    } else if (_playMomentNotifier.playMoment?.songMoment != songMoment) {
      _playMomentNotifier.playMoment = PlayMoment(songUpdateState, songMoment.momentNumber, songMoment);
      scrollToLyricSection(songMoment.lyricSection.index);
      //
      // if (songUpdateService.isLeader) {
      //   leaderSongUpdate(_playMomentNotifier.playMoment?.songMoment?.momentNumber ?? 0); //  fixme
      // }
    }
  }

  bool capoIsPossible() {
    return !_appOptions.isSinger && !(songUpdateService.isConnected && songUpdateService.isLeader);
  }

  Future<void> _settingsPopup() async {
    var popupStyle = headerTextStyle.copyWith(fontSize: (headerTextStyle.fontSize ?? app.screenInfo.fontSize) * 0.7);
    var boldStyle = popupStyle.copyWith(fontWeight: FontWeight.bold);

    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
              insetPadding: EdgeInsets.zero,
              title: Text(
                'Player settings:',
                style: boldStyle,
              ),
              content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                return SizedBox(
                    width: app.screenInfo.mediaWidth * 0.7,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        //  UserDisplayStyle
                        AppWrapFullWidth(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: viewportWidth(0.5),
                            children: [
                              AppTooltip(
                                message: 'Select the display style for the song.',
                                child: Text(
                                  'Display style: ',
                                  style: boldStyle,
                                ),
                              ),
                              //  pro player
                              AppWrap(children: [
                                Radio<UserDisplayStyle>(
                                  value: UserDisplayStyle.proPlayer,
                                  groupValue: _appOptions.userDisplayStyle,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        _appOptions.userDisplayStyle = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Display the song using the professional player style.\n'
                                      'This condenses the song chords to a minimum presentation without lyrics.',
                                  child: appTextButton(
                                    'Pro',
                                    appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                    value: UserDisplayStyle.proPlayer,
                                    onPressed: () {
                                      setState(() {
                                        _appOptions.userDisplayStyle = UserDisplayStyle.proPlayer;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
                                ),
                              ]),
                              //  player
                              AppWrap(children: [
                                Radio<UserDisplayStyle>(
                                  value: UserDisplayStyle.player,
                                  groupValue: _appOptions.userDisplayStyle,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        _appOptions.userDisplayStyle = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Display the song using the player style.\n'
                                      'This favors the chords over the lyrics,\n'
                                      'to the point that the lyrics maybe clipped.',
                                  child: appTextButton(
                                    'Player',
                                    appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                    value: UserDisplayStyle.player,
                                    onPressed: () {
                                      setState(() {
                                        _appOptions.userDisplayStyle = UserDisplayStyle.player;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
                                ),
                              ]),
                              //  both
                              AppWrap(children: [
                                Radio<UserDisplayStyle>(
                                  value: UserDisplayStyle.both,
                                  groupValue: _appOptions.userDisplayStyle,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        _appOptions.userDisplayStyle = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Display the song showing all chords and lyrics.\n'
                                      'This is the most typical display mode.',
                                  child: appTextButton(
                                    'Both Player and Singer',
                                    appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                    value: UserDisplayStyle.both,
                                    onPressed: () {
                                      setState(() {
                                        _appOptions.userDisplayStyle = UserDisplayStyle.both;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
                                ),
                              ]),
                              //  singer
                              AppWrap(children: [
                                Radio<UserDisplayStyle>(
                                  value: UserDisplayStyle.singer,
                                  groupValue: _appOptions.userDisplayStyle,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        _appOptions.userDisplayStyle = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Display the song showing all the lyrics.\n'
                                      'The display of chords is minimized.',
                                  child: appTextButton(
                                    'Singer',
                                    appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                    value: UserDisplayStyle.singer,
                                    onPressed: () {
                                      setState(() {
                                        _appOptions.userDisplayStyle = UserDisplayStyle.singer;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
                                ),
                              ]),
                              //  banner
                              // AppWrap(children: [
                              //   Radio<UserDisplayStyle>(
                              //     value: UserDisplayStyle.banner,
                              //     groupValue: _appOptions.userDisplayStyle,
                              //     onChanged: (value) {
                              //       setState(() {
                              //         if (value != null) {
                              //           _appOptions.userDisplayStyle = value;
                              //           adjustDisplay();
                              //         }
                              //       });
                              //     },
                              //   ),
                              //   AppTooltip(
                              //     message: 'Display the song in banner (piano scroll) mode.',
                              //     child: appTextButton(
                              //       'Banner',
                              //       appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                              //       value: UserDisplayStyle.banner,
                              //       onPressed: () {
                              //         setState(() {
                              //           _appOptions.userDisplayStyle = UserDisplayStyle.banner;
                              //           adjustDisplay();
                              //         });
                              //       },
                              //       style: popupStyle,
                              //     ),
                              //   ),
                              // ]),
                            ]),
                        //  const AppSpaceViewportWidth(),
                        //  PlayerScrollHighlight
                        AppWrapFullWidth(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: viewportWidth(0.5),
                            children: [
                              AppTooltip(
                                message: 'Select the highlight style while scrolling in play.',
                                child: Text(
                                  'Scroll style: ',
                                  style: boldStyle,
                                ),
                              ),
                              //  off
                              AppWrap(children: [
                                Radio<PlayerScrollHighlight>(
                                  value: PlayerScrollHighlight.off,
                                  groupValue: _appOptions.playerScrollHighlight,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        _appOptions.playerScrollHighlight = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'No play highlight.',
                                  child: appTextButton(
                                    'Off',
                                    appKeyEnum: AppKeyEnum.optionsPlayerScrollHighlightOff,
                                    value: PlayerScrollHighlight.off,
                                    onPressed: () {
                                      setState(() {
                                        _appOptions.playerScrollHighlight = PlayerScrollHighlight.off;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
                                ),
                              ]),
                              //  row
                              AppWrap(children: [
                                Radio<PlayerScrollHighlight>(
                                  value: PlayerScrollHighlight.chordRow,
                                  groupValue: _appOptions.playerScrollHighlight,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        _appOptions.playerScrollHighlight = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Highlight the current row.',
                                  child: appTextButton(
                                    'Row',
                                    appKeyEnum: AppKeyEnum.optionsPlayerScrollHighlightChordRow,
                                    value: PlayerScrollHighlight.chordRow,
                                    onPressed: () {
                                      setState(() {
                                        _appOptions.playerScrollHighlight = PlayerScrollHighlight.chordRow;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
                                ),
                              ]),
                              //  measure
                              AppWrap(children: [
                                Radio<PlayerScrollHighlight>(
                                  value: PlayerScrollHighlight.measure,
                                  groupValue: _appOptions.playerScrollHighlight,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        _appOptions.playerScrollHighlight = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Highlight the current measure.',
                                  child: appTextButton(
                                    'Measure',
                                    appKeyEnum: AppKeyEnum.optionsPlayerScrollHighlightMeasure,
                                    value: PlayerScrollHighlight.measure,
                                    onPressed: () {
                                      setState(() {
                                        _appOptions.playerScrollHighlight = PlayerScrollHighlight.measure;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
                                ),
                              ]),
                            ]),
                        AppWrapFullWidth(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: viewportWidth(0.5),
                            children: [
                              AppTooltip(
                                message: 'Select how the repeats are displayed in the song.',
                                child: appTextButton(
                                  'Repeats:',
                                  appKeyEnum: AppKeyEnum.playerCompressRepeatsToggle,
                                  value: _appOptions.compressRepeats,
                                  onPressed: () {
                                    setState(() {
                                      compressRepeats = !compressRepeats;
                                      adjustDisplay();
                                    });
                                  },
                                  style: boldStyle,
                                ),
                              ),
                              AppWrap(children: [
                                Radio<bool>(
                                  value: true,
                                  groupValue: _appOptions.compressRepeats,
                                  onChanged: (value) {
                                    setState(() {
                                      setState(() {
                                        compressRepeats = true;
                                        adjustDisplay();
                                      });
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Compress the repeats on this song',
                                  child: appIconWithLabelButton(
                                    appKeyEnum: AppKeyEnum.playerCompressRepeats,
                                    icon: appIcon(Icons.compress),
                                    value: compressRepeats,
                                    onPressed: () {
                                      setState(() {
                                        compressRepeats = true;
                                        adjustDisplay();
                                      });
                                    },
                                  ),
                                ),
                              ]),
                              AppWrap(children: [
                                Radio<bool>(
                                  value: false,
                                  groupValue: _appOptions.compressRepeats,
                                  onChanged: (value) {
                                    setState(() {
                                      setState(() {
                                        compressRepeats = false;
                                        adjustDisplay();
                                      });
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Expand the repeats on this song',
                                  child: appIconWithLabelButton(
                                    appKeyEnum: AppKeyEnum.playerCompressRepeats,
                                    icon: appIcon(Icons.expand),
                                    value: compressRepeats,
                                    onPressed: () {
                                      setState(() {
                                        compressRepeats = false;
                                        adjustDisplay();
                                      });
                                    },
                                  ),
                                ),
                              ]),
                              const AppSpace(
                                horizontalSpace: 20,
                              ),
                              AppWrap(
                                alignment: WrapAlignment.start,
                                children: [
                                  AppTooltip(
                                    message: 'Select how the Nashville notation is shown.',
                                    child: Text(
                                      'Nashville: ',
                                      style: boldStyle,
                                      softWrap: false,
                                    ),
                                  ),
                                  AppTooltip(
                                    message: 'Turn Nashville notation off.',
                                    child: AppRadio<NashvilleSelection>(
                                        text: 'Off',
                                        appKeyEnum: AppKeyEnum.optionsNashville,
                                        value: NashvilleSelection.off,
                                        groupValue: _appOptions.nashvilleSelection,
                                        onPressed: () {
                                          setState(() {
                                            _appOptions.nashvilleSelection = NashvilleSelection.off;
                                            adjustDisplay();
                                          });
                                        },
                                        style: popupStyle),
                                  ),
                                  AppTooltip(
                                    message: 'Show both the chords and Nashville notation.',
                                    child: AppRadio<NashvilleSelection>(
                                        text: 'both',
                                        appKeyEnum: AppKeyEnum.optionsNashville,
                                        value: NashvilleSelection.both,
                                        groupValue: _appOptions.nashvilleSelection,
                                        onPressed: () {
                                          setState(() {
                                            _appOptions.nashvilleSelection = NashvilleSelection.both;
                                            adjustDisplay();
                                          });
                                        },
                                        style: popupStyle),
                                  ),
                                  AppTooltip(
                                    message: 'Show only the Nashville notation.',
                                    child: AppRadio<NashvilleSelection>(
                                        text: 'only',
                                        appKeyEnum: AppKeyEnum.optionsNashville,
                                        value: NashvilleSelection.only,
                                        groupValue: _appOptions.nashvilleSelection,
                                        onPressed: () {
                                          setState(() {
                                            _appOptions.nashvilleSelection = NashvilleSelection.only;
                                            adjustDisplay();
                                          });
                                        },
                                        style: popupStyle),
                                  ),
                                ],
                              ),
                              const AppSpace(
                                horizontalSpace: 20,
                              ),
                              if (_appOptions.userDisplayStyle != UserDisplayStyle.singer)
                                AppWrap(
                                  alignment: WrapAlignment.start,
                                  children: [
                                    if (!songUpdateService.isLeader)
                                      AppTooltip(
                                        message: 'For a guitar, show the capo location and\n'
                                            'chords to match the current key.',
                                        child: appTextButton(
                                          'Capo',
                                          appKeyEnum: AppKeyEnum.playerCapoLabel,
                                          value: _isCapo,
                                          style: boldStyle,
                                          onPressed: () {
                                            setState(
                                              () {
                                                _isCapo = !_isCapo;
                                                setSelectedSongKey(_selectedSongKey);
                                                adjustDisplay();
                                              },
                                            );
                                          },
                                          //softWrap: false,
                                        ),
                                      ),
                                    if (!songUpdateService.isLeader)
                                      appSwitch(
                                        appKeyEnum: AppKeyEnum.playerCapo,
                                        value: _isCapo,
                                        onChanged: (value) {
                                          setState(() {
                                            _isCapo = !_isCapo;
                                            setSelectedSongKey(_selectedSongKey);
                                            adjustDisplay();
                                          });
                                        },
                                      ),
                                    if (songUpdateService.isLeader)
                                      Text(
                                        'Capo: not available to the leader',
                                        style: popupStyle,
                                      ),
                                  ],
                                ),
                            ]),
                        if (!songUpdateService.isFollowing && kIsWeb && !app.screenInfo.isTooNarrow)
                          AppWrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                            AppTooltip(
                              message: 'Adjust drum playback volume.',
                              child: Text(
                                'Volume:',
                                style: popupStyle,
                              ),
                            ),
                            SizedBox(
                              width: app.screenInfo.mediaWidth * 0.4,
                              // fixme: too fiddly
                              child: AppTooltip(
                                message: 'Adjust drum playback volume.',
                                child: Slider(
                                  value: _appOptions.volume * 10,
                                  onChanged: (value) {
                                    setState(() {
                                      _appOptions.volume = value / 10;
                                    });
                                  },
                                  min: 0,
                                  max: 10.0,
                                ),
                              ),
                            ),
                          ]),
                        const AppSpace(),
                        if (!songUpdateService.isFollowing && kIsWeb && !app.screenInfo.isTooNarrow)
                          AppWrapFullWidth(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: viewportWidth(1),
                              children: [
                                AppTooltip(
                                  message: _areDrumsMuted
                                      ? 'Click to unmute and select the drums'
                                      : 'Click to mute the drums',
                                  child: appButton(_areDrumsMuted ? 'Drums are muted' : 'Mute the Drums',
                                      appKeyEnum: _areDrumsMuted
                                          ? AppKeyEnum.playerDrumsMuted
                                          : AppKeyEnum.playerDrumsUnmuted, onPressed: () {
                                    setState(() {
                                      _areDrumsMuted = !_areDrumsMuted;
                                      _songMaster.drumsAreMuted = _areDrumsMuted;
                                      logger.i('drums mute: $_areDrumsMuted');
                                    });
                                  }, backgroundColor: _areDrumsMuted ? Colors.red : null),
                                ),
                                const AppSpace(),
                                if (!_areDrumsMuted)
                                  AppTooltip(
                                    message: 'Select the drums',
                                    child: appIconWithLabelButton(
                                        appKeyEnum: AppKeyEnum.playerEditDrums,
                                        label: 'Drums',
                                        fontSize: popupStyle.fontSize,
                                        icon: appIcon(
                                          Icons.edit,
                                        ),
                                        onPressed: () {
                                          navigateToDrums(context, _song).then((value) => setState(() {}));
                                        }),
                                  ),
                                if (!_areDrumsMuted)
                                  AppTooltip(
                                    message: 'The currently selected drum parts for this song.',
                                    child: Text(_drumParts?.name ?? 'No drum parts', style: popupStyle),
                                  )
                              ]),
                        const AppSpace(),
                        AppWrapFullWidth(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: viewportWidth(1),
                          children: [
                            Text(
                              'NinJam choice:',
                              style: boldStyle,
                            ),
                            AppTooltip(
                              message: 'Turn off the Ninjam aids',
                              child: AppRadio<bool>(
                                  text: 'No NinJam aids',
                                  appKeyEnum: AppKeyEnum.optionsNinJam,
                                  value: false,
                                  groupValue: _appOptions.ninJam,
                                  onPressed: () {
                                    setState(() {
                                      _appOptions.ninJam = false;
                                      adjustDisplay();
                                    });
                                  },
                                  style: popupStyle),
                            ),
                            AppTooltip(
                              message: 'Turn on the Ninjam aids',
                              child: AppRadio<bool>(
                                  text: 'Show NinJam aids',
                                  appKeyEnum: AppKeyEnum.optionsNinJam,
                                  value: true,
                                  groupValue: _appOptions.ninJam,
                                  onPressed: () {
                                    setState(() {
                                      _appOptions.ninJam = true;
                                      adjustDisplay();
                                    });
                                  },
                                  style: popupStyle),
                            ),
                          ],
                        ),
                        const AppVerticalSpace(),
                        if (!app.screenInfo.isWayTooNarrow)
                          AppWrapFullWidth(children: <Widget>[
                            AppTooltip(
                              message: 'Offset the key displayed in the local display\n'
                                  'to transcribe the chords for instruments that are\n'
                                  'not Concert Pitch Instruments.\n'
                                  'C pitched instruments include piano, most guitars,\n'
                                  'flute, oboe, bassoon, and trombone.',
                              child: Text(
                                'Display key offset: ',
                                style: boldStyle,
                              ),
                            ),
                            appDropdownButton<int>(
                              AppKeyEnum.playerKeyOffset,
                              keyOffsetItems,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    app.displayKeyOffset = value;
                                    adjustDisplay();
                                  });
                                }
                              },
                              style: popupStyle,
                              value: app.displayKeyOffset,
                            ),
                          ]),
                        const AppVerticalSpace(space: 35),
                      ],
                    ));
              }),
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

    if (delta < 60 / MusicConstants.minBpm && delta > 60 / MusicConstants.maxBpm) {
      int bpm = (_tempoRollingAverage ??= RollingAverage()).average(60 / delta).round();
      _changeBPM(bpm);
    } else {
      //  delta too small or too large
      _tempoRollingAverage = null;
      _changeBPM(_song.beatsPerMinute); //  default to song beats per minute
      logger.log(_logBPM, 'tempoTap(): default: bpm: $playerSelectedBpm');
    }
  }

  _changeBPM(int newBpm) {
    newBpm = Util.intLimit(newBpm, MusicConstants.minBpm, MusicConstants.maxBpm);
    if (playerSelectedBpm != newBpm) {
      setState(() {
        playerSelectedBpm = newBpm;
        _songMaster.tapTempo(newBpm);
        logger.log(_logBPM, '_changeBPM( $playerSelectedBpm )');
      });
    }
  }

  final List<DropdownMenuItem<int>> keyOffsetItems = [
    appDropdownMenuItem(appKeyEnum: AppKeyEnum.playerKeyOffset, value: 0, child: const Text('normal: (no key offset)')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 1,
        child: const Text('+1   (-11) half steps = scale  ${MusicConstants.flatChar}2')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 2,
        child: const Text('+2   (-10) half steps = scale   2, B${MusicConstants.flatChar} instrument')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 3,
        child: const Text('+3   (-9)   half steps = scale  ${MusicConstants.flatChar}3')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset, value: 4, child: const Text('+4   (-8)   half steps = scale   3')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 5,
        child: const Text('+5   (-7)   half steps = scale   4, baritone guitar')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 6,
        child: const Text('+6   (-6)   half steps = scale  ${MusicConstants.flatChar}5')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 7,
        child: const Text('+7   (-5)   half steps = scale   5, F instrument')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 8,
        child: const Text('+8   (-4)   half steps = scale  ${MusicConstants.flatChar}6')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 9,
        child: const Text('+9   (-3)   half steps = scale   6, E${MusicConstants.flatChar} instrument')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset,
        value: 10,
        child: const Text('+10 (-2)   half steps = scale  ${MusicConstants.flatChar}7')),
    appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.playerKeyOffset, value: 11, child: const Text('+11 (-1)   half steps = scale   7')),
  ];

  void _resetIdleTimer() {
    _cancelIdleTimer();
    _idleTimer = Timer(const Duration(minutes: 60), () {
      logger.t('idleTimer fired');
      Navigator.of(context).pop();
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  DrumParts? get defaultDrumParts => _drumPartsList.findByName(DrumPartsList.defaultName);

  static const String anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  SongUpdateState songUpdateState = SongUpdateState.idle;

  late final FocusNode _rawKeyboardListenerFocusNode;

  set compressRepeats(bool value) => _appOptions.compressRepeats = value;

  bool get compressRepeats => _appOptions.compressRepeats;

  music_key.Key _displaySongKey = music_key.Key.C;
  int displayKeyOffset = 0;

  NinJam _ninJam = NinJam.empty();

  int _lastTempoTap = DateTime.now().microsecondsSinceEpoch;
  RollingAverage? _tempoRollingAverage;

  int _bpmBumpStep = 0;
  int _lastBpmBump = 0;
  int _lastBpmBumpUs = 0;
  static final _bumpSteps = [1, 2, 4];

  final SongMaster _songMaster = SongMaster();
  int _countIn = 0;
  Widget _countInWidget = NullWidget();

  List<SongMoment> sectionSongMoments = []; //  fixme temp?

  ScrollablePositionedList? _scrollablePositionedList;
  final ItemScrollController _itemScrollController = ItemScrollController();
  bool _isAnimated = false;
  int _lastRowIndex = 0;
  final playerItemPositionsListener = ItemPositionsListener.create();

  Size? lastSize;

  // static const _centerSelections = true;
  static const _scrollAlignment = 0.25;

  // double boxMarker = 0;
  var headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);

  Timer? _idleTimer;

  final _drumPartsList = DrumPartsList();

  DrumParts? _drumParts;

  late AppWidgetHelper appWidgetHelper;

  static final _appOptions = AppOptions();
  final SongUpdateService songUpdateService = SongUpdateService();
}

/// Display data on the song while in auto or manual play mode
class _DataReminderWidget extends StatefulWidget {
  const _DataReminderWidget(this.songIsInPlayOrPaused, this.songMaster);

  @override
  State<StatefulWidget> createState() {
    return _DataReminderState();
  }

  final bool songIsInPlayOrPaused;
  final SongMaster songMaster;
}

class _DataReminderState extends State<_DataReminderWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PlayMomentNotifier>(builder: (context, playMomentNotifier, child) {
      int? bpm = playerSelectedBpm;
      bpm ??= (widget.songIsInPlayOrPaused ? widget.songMaster.bpm : null);
      bpm ??= _song.beatsPerMinute;
      logger.log(_logDataReminderState,
          '_DataReminderState.build(): ${widget.songIsInPlayOrPaused}, bpm: $bpm, playerSelectedBpm: $playerSelectedBpm');

      return widget.songIsInPlayOrPaused
          ? AppWrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                if (app.fullscreenEnabled && !app.isFullScreen)
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: _padding),
                      child: appButton('Fullscreen', appKeyEnum: AppKeyEnum.playerFullScreen, onPressed: () {
                        app.requestFullscreen();
                      })),
                Text(
                  'Key $_selectedSongKey'
                  '     BPM: $bpm'
                  '    Beats: ${_song.timeSignature.beatsPerBar}'
                  '${_showCapo ? '    Capo ${_capoLocation == 0 ? 'not needed' : 'on $_capoLocation'}' : ''}'
                  '  ', //  padding at the end
                  style: generateAppTextStyle(
                    fontSize: app.screenInfo.fontSize,
                    decoration: TextDecoration.none,
                    backgroundColor: const Color(0xe0eff4fd), //  fake a blended color, semi-opaque
                  ),
                ),
              ],
            )
          : NullWidget();
    });
  }
}
