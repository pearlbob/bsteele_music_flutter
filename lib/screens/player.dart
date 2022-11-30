import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/drum_measure.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/music_constants.dart';
import 'package:bsteeleMusicLib/songs/ninjam.dart';
import 'package:bsteeleMusicLib/songs/scale_note.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/song_base.dart';
import 'package:bsteeleMusicLib/songs/song_moment.dart';
import 'package:bsteeleMusicLib/songs/song_update.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/drum_screen.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
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
_PlayerState? _player;

//  package level variables
Song _song = Song.createEmptySong();
bool _isPlaying = false;
final LyricsTable _lyricsTable = LyricsTable();
Widget _table = const Text('table missing!');

enum _SongPlayMode {
  idle(Icons.stop),
  manualPlay(Icons.forward),
  autoPlay(Icons.play_arrow),
  pause(Icons.pause);

  const _SongPlayMode(this.iconData);

  final IconData iconData;
}

bool _isCapo = false; //  package level for persistence across player invocations
int _capoLocation = 0;

DrumParts? _drumParts = DrumParts(); //  temp

final _songMomentNotifier = SongMomentNotifier();
final _lyricSectionNotifier = LyricSectionNotifier();

const int _minimumSpaceBarGapMs = 350; //  milliseconds

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

  Timer(const Duration(milliseconds: 2), () {
    // ignore: invalid_use_of_protected_member
    logger.log(_logLeaderFollower, 'playerUpdate timer');
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

    _rawKeyboardListenerFocusNode = FocusNode(onKey: playerOnKey);

    _isPlaying = false;
    songPlayMode = _SongPlayMode.idle;
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
    _drumParts = _drumPartsList.songMatch(_song);
    _songMomentNotifier.songMoment = null;
    _lyricSectionNotifier.index = 0;
    sectionSongMoments.clear();

    logger.log(_logBPM, 'initState() bpm: $playerSelectedBpm');

    leaderSongUpdate(-1);

    WidgetsBinding.instance.scheduleWarmUpFrame();

    playerItemPositionsListener.itemPositions.addListener(itemPositionsListener);

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
        lastSize = size;
      });
    }
  }

  @override
  void dispose() {
    logger.d('player: dispose()');
    _cancelIdleTimer();

    appKeyCallbacksClear();

    _player = null;
    _playerIsOnTop = false;
    _songUpdate = null;
    songUpdateService.removeListener(songUpdateServiceListener);
    _songMaster.removeListener(songMasterListener);
    playerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  //  update the song update service status
  void songUpdateServiceListener() {
    logger.log(_logLeaderFollower, 'songUpdateServiceListener():');
    setState(() {});
  }

  void songMasterListener() {
    logger.log(
        _logSongMaster,
        'songMasterListener:  leader: ${songUpdateService.isLeader}  ${DateTime.now()}'
        ', moment: ${_songMaster.momentNumber}'
        ', lyricSection: ${_song.getSongMoment(_songMaster.momentNumber ?? 0)?.lyricSection.index}');

    if (_songMaster.momentNumber != null) {
      var songMoment = _song.getSongMoment(_songMaster.momentNumber!);
      if (songMoment != null) {
        if (_songMomentNotifier.songMoment != songMoment) {
          setSelectedSongMoment(songMoment);
        }
        scrollToLyricSection(songMoment.lyricSection.index);
      }
    } else if (_isPlaying != _songMaster.isPlaying) {
      setState(() {
        _isPlaying = _songMaster.isPlaying;
        if (!_isPlaying) {
          //  cancel the cell highlight
          _songMomentNotifier.songMoment = null;
        }
        songPlayMode = _isPlaying ? _SongPlayMode.autoPlay : _SongPlayMode.idle;
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
        'player build: $_song, selectedSongMoment: ${_songMomentNotifier.songMoment?.momentNumber}'
        ', isPlaying: $_isPlaying');

    //  deal with song updates
    if (_songUpdate != null) {
      if (!_song.songBaseSameContent(_songUpdate!.song) || displayKeyOffset != app.displayKeyOffset) {
        _song = _songUpdate!.song;
        widget._song = _song;
        _songMomentNotifier.songMoment = _songUpdate?.songMoment;
        selectLyricSection(_songUpdate?.songMoment?.lyricSection.index //
            ??
            _lyricSectionNotifier.index); //  safer to stay on the current index

        if (_songUpdate!.state == SongUpdateState.playing) {
          performPlay();
        } else {
          simpleStop();
        }

        logger.log(
            _logLeaderFollower,
            'player follower: $_song, selectedSongMoment: ${_songMomentNotifier.songMoment?.momentNumber}'
            ' songPlayMode: $songPlayMode'
            ', isPlaying: $_isPlaying');
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

    const hoverColor = App.universalAccentColor;

    logger.log(
        _logScroll,
        ' scrollTarget: $scrollTarget, '
        ' _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}');
    logger.log(_logMode, 'playing: $_isPlaying, pause: $_isPaused');

    bool showCapo = capoIsAvailable() && app.isScreenBig;
    _isCapo = _isCapo && showCapo; //  can't be capo if you cannot show it

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

    if (appOptions.ninJam) {
      _ninJam =
          NinJam(_song, key: _displaySongKey, keyOffset: _displaySongKey.getHalfStep() - _song.getKey().getHalfStep());
    }

    List<Widget> lyricsTableItems = _lyricsTable.lyricsTableItems(
      _song,
      context,
      musicKey: _displaySongKey,
      expanded: !compressRepeats,
    );
    var scrollablePositionedList = appOptions.userDisplayStyle == UserDisplayStyle.banner
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
        : ScrollablePositionedList.builder(
            itemCount: lyricsTableItems.length,
            itemScrollController: _itemScrollController,
            itemPositionsListener: playerItemPositionsListener,
            itemBuilder: (context, index) {
              return lyricsTableItems[Util.limit(index, 0, lyricsTableItems.length) as int];
            },
            scrollDirection: Axis.vertical,
            //minCacheExtent: app.screenInfo.mediaHeight, //  fixme: is this desirable?
          );

    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _songMomentNotifier),
          ChangeNotifierProvider.value(value: _lyricSectionNotifier),
        ],
        builder: (context, child) {
          return RawKeyboardListener(
            focusNode: _rawKeyboardListenerFocusNode,
            autofocus: true,
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: theme.backgroundColor,
                  appBar: appWidgetHelper.backBar(
                      titleWidget: Row(
                        children: [
                          Icon(
                            songPlayMode.iconData,
                            size: appBarTextStyle.fontSize,
                          ),
                          const AppSpace(),
                          Flexible(
                            child: AppTooltip(
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
                        _songMaster
                            .removeListener(songMasterListener); //  avoid race condition with the listener notification
                        _songMaster.stop();
                      }),
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
                                theme.backgroundColor,
                                App.measureContainerBackgroundColor,
                                App.measureContainerBackgroundColor,
                                App.measureContainerBackgroundColor,
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
                      //  player screen
                      Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          textDirection: TextDirection.ltr,
                          children: <Widget>[
                            if (app.message.isNotEmpty)
                              Container(
                                  padding: const EdgeInsets.all(6.0),
                                  child: app.messageTextWidget(AppKeyEnum.playerErrorMessage)),
                            //  top section when idle
                            if (songPlayMode == _SongPlayMode.idle)
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    child: AppWrapFullWidth(alignment: WrapAlignment.end, spacing: fontSize, children: [
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

                                      //  player options
                                      AppWrap(children: [
                                        // if (kDebugMode && app.isScreenBig)
                                        //   AppWrap(children: [
                                        //     //  fixme: there should be a better way.  wrap with flex?
                                        //     AppTooltip(
                                        //       message: 'Back to the previous song in the list',
                                        //       child: appIconButton(
                                        //         appKeyEnum: AppKeyEnum.playerPreviousSong,
                                        //         icon: appIcon(
                                        //           Icons.navigate_before,
                                        //         ),
                                        //         onPressed: () {
                                        //           widget._song = previousSongInTheList();
                                        //           _song = widget._song;
                                        //           selectLyricSection(0);
                                        //           setSelectedSongKey(_song.key);
                                        //           _songMomentNotifier.songMoment = null;
                                        //           adjustDisplay();
                                        //         },
                                        //       ),
                                        //     ),
                                        //     const AppSpace(space: 5),
                                        //     AppTooltip(
                                        //       message: 'Advance to the next song in the list',
                                        //       child: appIconButton(
                                        //         appKeyEnum: AppKeyEnum.playerNextSong,
                                        //         icon: appIcon(
                                        //           Icons.navigate_next,
                                        //         ),
                                        //         onPressed: () {
                                        //           widget._song = nextSongInTheList();
                                        //           _song = widget._song;
                                        //           selectLyricSection(0);
                                        //           setSelectedSongKey(_song.key);
                                        //           _songMomentNotifier.songMoment = null;
                                        //           adjustDisplay();
                                        //         },
                                        //       ),
                                        //     ),
                                        //   ]),
                                        // if (app.isScreenBig)
                                        //   AppWrap(children: [
                                        //     const AppSpace(horizontalSpace: 35),
                                        //     AppTooltip(
                                        //       message: 'Mark the song as good.'
                                        //           '\nYou will find it in the'
                                        //           ' "${myGoodSongNameValue.toShortString()}" list.',
                                        //       child: appIconButton(
                                        //         appKeyEnum: AppKeyEnum.playerSongGood,
                                        //         icon: appIcon(
                                        //           Icons.thumb_up,
                                        //         ),
                                        //         onPressed: () {
                                        //           SongMetadata.addSong(_song, myGoodSongNameValue);
                                        //           SongMetadata.removeFromSong(_song, myBadSongNameValue);
                                        //           appOptions.storeSongMetadata();
                                        //           app.errorMessage('${_song.title} added to'
                                        //               ' ${myGoodSongNameValue.toShortString()}');
                                        //         },
                                        //       ),
                                        //     ),
                                        //     const AppSpace(space: 5),
                                        //     AppTooltip(
                                        //       message: 'Mark the song as bad, that is, in need of correction.'
                                        //           '\nYou will find it in the'
                                        //           ' "${myBadSongNameValue.toShortString()}" list.',
                                        //       child: appIconButton(
                                        //         appKeyEnum: AppKeyEnum.playerSongBad,
                                        //         icon: appIcon(
                                        //           Icons.thumb_down,
                                        //         ),
                                        //         onPressed: () {
                                        //           SongMetadata.addSong(_song, myBadSongNameValue);
                                        //           SongMetadata.removeFromSong(_song, myGoodSongNameValue);
                                        //           appOptions.storeSongMetadata();
                                        //           _songMaster.stop();
                                        //           _cancelIdleTimer();
                                        //           Navigator.pop(context); //  return to main list
                                        //         },
                                        //       ),
                                        //     ),
                                        //   ]),
                                        //  if (app.isEditReady) const AppSpace(horizontalSpace: 35),
                                        //  song edit
                                        if (!_isPlaying && !songUpdateService.isFollowing && app.isEditReady)
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
                                        AppSpace(horizontalSpace: 3.5 * fontSize),
                                      ]),
                                    ]),
                                  ),
                                  //  second top row
                                  AppWrapFullWidth(alignment: WrapAlignment.spaceAround, children: [
                                    //  play button
                                    if (!songUpdateService.isFollowing)
                                      AppTooltip(
                                        message: '''
Click the play button for autoplay.
Space bar or clicking the song area starts manual mode.
Selected section is in the top of the display with a red indicator.
Another space bar or song area hit below the middle advances one section.
Down or right arrow also advances one section.
Up or left arrow backs up one section.
A click or touch above the middle backs up one section.
Scrolling with the mouse wheel selects individual rows.
Enter ends the "play" mode.
With z or q, the app goes back to the play list.''',
                                        child: Container(
                                          padding: const EdgeInsets.only(left: 8, right: 8),
                                          child: appIconButton(
                                            appKeyEnum: AppKeyEnum.playerPlay,
                                            icon: appIcon(
                                              playStopIcon,
                                              size: 1.25 * fontSize,
                                            ),
                                            onPressed: () {
                                              _isPlaying ? performStop() : performPlay();
                                            },
                                          ),
                                        ),
                                      ),
                                    if (app.fullscreenEnabled && !app.isFullScreen)
                                      appButton('Fullscreen', appKeyEnum: AppKeyEnum.playerFullScreen, onPressed: () {
                                        app.requestFullscreen();
                                      }),
                                    AppWrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      children: [
                                        if (!songUpdateService.isFollowing)
                                          //  key change
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
                                                  child: appIconButton(
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
                                                  child: appIconButton(
                                                    appKeyEnum: AppKeyEnum.playerKeyDown,
                                                    icon: appIcon(
                                                      Icons.arrow_downward,
                                                    ),
                                                    onPressed: () {
                                                      if (!_isAnimated) {
                                                        setState(() {
                                                          setSelectedSongKey(_selectedSongKey.previousKeyByHalfStep());
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
                                            ' ($_selectedSongKey${displayKeyOffset > 0 ? '+$displayKeyOffset' : ''}'
                                            '${_isCapo && _capoLocation > 0 ? '-$_capoLocation' : ''}=$_displaySongKey)',
                                            style: headerTextStyle,
                                          ),
                                      ],
                                    ),
                                    if (app.isScreenBig && !songUpdateService.isFollowing)
                                      //  tempo change
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
                                                          _logBPM, '_bpmDropDownMenuList: bpm: $playerSelectedBpm');
                                                    });
                                                  }
                                                },
                                                value: playerSelectedBpm ?? _song.beatsPerMinute,
                                                style: headerTextStyle,
                                                iconSize: headerTextStyle.fontSize ?? appDefaultFontSize,
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
                                                  logger.log(_logBPM, 'speed: bpm: $playerSelectedBpm');
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    if (app.isScreenBig && songUpdateService.isFollowing)
                                      AppTooltip(
                                        message:
                                            'When following the leader, the leader will select the tempo for you.\n'
                                            'To correct this from the main screen: hamburger, Options, Hosts: None',
                                        child: Text(
                                          'Tempo: ${playerSelectedBpm ?? _song.beatsPerMinute}',
                                          style: headerTextStyle,
                                        ),
                                      ),
                                    Text(
                                      'Beats: ${_song.timeSignature.beatsPerBar}',
                                      style: headerTextStyle,
                                      softWrap: false,
                                    ),
                                    if (app.isScreenBig)
                                      //  leader/follower status
                                      Text(
                                        songUpdateService.isConnected
                                            ? (songUpdateService.isLeader
                                                ? 'leading ${songUpdateService.host}'
                                                : (songUpdateService.leaderName == AppOptions.unknownUser
                                                    ? 'on ${songUpdateService.host.replaceFirst('.local', '')}'
                                                    : 'following ${songUpdateService.leaderName}'))
                                            : (songUpdateService.isIdle ? '' : 'lost ${songUpdateService.host}!'),
                                        style: !songUpdateService.isConnected && !songUpdateService.isIdle
                                            ? headerTextStyle.copyWith(color: Colors.red)
                                            : headerTextStyle,
                                      ),
                                  ]),
                                ],
                              ),

                            const AppSpace(),
                            if (app.isScreenBig &&
                                appOptions.ninJam &&
                                _ninJam.isNinJamReady &&
                                songPlayMode == _SongPlayMode.idle)
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
                            //  song chords and lyrics
                            if (lyricsTableItems.isNotEmpty) //  ScrollablePositionedList messes up otherwise
                              Expanded(
                                  child: GestureDetector(
                                      onTapDown: (details) {
                                        //  respond to taps above and below the middle of the screen
                                        if (!_isPlaying && appOptions.userDisplayStyle != UserDisplayStyle.proPlayer) {
                                          if (songPlayMode != _SongPlayMode.manualPlay) {
                                            //  start manual play
                                            scrollToLyricSection(0); //  always start manual play from the beginning
                                            setState(() {
                                              songPlayMode = _SongPlayMode.manualPlay;
                                            });
                                          } else {
                                            //  don't respond above the player song table
                                            var offset = _tableGlobalOffset();
                                            if (details.globalPosition.dy > offset.dy) {
                                              if (details.globalPosition.dy > app.screenInfo.mediaHeight / 2) {
                                                sectionBump(1); //  fixme: when not in play
                                              } else {
                                                sectionBump(-1); //  fixme: when not in play
                                              }
                                            }
                                          }
                                        }
                                      },
                                      child: scrollablePositionedList)),
                          ]),
                      // ),
                    ],
                  ),
                  floatingActionButton: songIsInPlay
                      ? (_isPaused && songPlayMode == _SongPlayMode.autoPlay
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
                                message: 'Type Z or Q to stop the play\nor space to next section',
                                child: appIcon(
                                  Icons.stop,
                                ),
                              ),
                              mini: !app.isScreenBig,
                            ))
                      : (_lyricSectionNotifier.index > 0
                          ? appFloatingActionButton(
                              appKeyEnum: AppKeyEnum.playerFloatingTop,
                              onPressed: () {
                                if (_isPlaying) {
                                  performStop();
                                } else {
                                  setState(() {
                                    setSelectedSongMoment(_song.songMoments.first);
                                  });
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

                //  player settings
                if (!_isPlaying)
                  Column(
                    children: [
                      AppSpace(
                        verticalSpace: AppBar().preferredSize.height,
                      ),
                      AppWrapFullWidth(alignment: WrapAlignment.end, children: [
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: AppTooltip(
                            message: 'Show the player settings dialog.',
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
                        ),
                      ]),
                    ],
                  ),
                _DataReminderWidget(songIsInPlay, appWidgetHelper.toolbarHeight),
              ],
            ),
          );
        });
  }

  KeyEventResult playerOnKey(FocusNode node, RawKeyEvent value) {
    logger.log(_logKeyboard, '_playerOnKey(): event: $value');

    if (!_playerIsOnTop) {
      return KeyEventResult.ignored;
    }
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

            if (songPlayMode != _SongPlayMode.manualPlay) {
              scrollToLyricSection(0); //  always start manual play from the beginning
              setState(() {
                songPlayMode = _SongPlayMode.manualPlay;
              });
            } else {
              sectionBump(1);
            }
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
      logger.log(_logKeyboard, 'arrowUp');
      sectionBump(-1);
      return KeyEventResult.handled;
    } else if (e.isKeyPressed(LogicalKeyboardKey.keyZ) || e.isKeyPressed(LogicalKeyboardKey.keyQ)) {
      if (_isPlaying || songIsInPlay) {
        performStop();
      } else {
        logger.log(_logKeyboard, 'player: pop the navigator');
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
    return min(app.screenInfo.mediaHeight, 1080 /*  limit leader area to hdtv size */) * _sectionCenterLocationFraction;
  }

  /// bump from one section to the next
  sectionBump(int bump) {
    switch (appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        //  banner units are measure
        var index = Util.indexLimit((_songMomentNotifier.songMoment?.momentNumber ?? 0) + bump, _song.songMoments);
        setSelectedSongMoment(_song.songMoments[index]);
        _itemScrollTo(index);
        logger.v('banner bump: $bump to $index: ${_song.songMoments[index]}');
        break;
      default:
        //  units are usually by section
        scrollToLyricSection(_lyricSectionNotifier.index + bump);
        break;
    }
  }

  void itemPositionsListener() {
    switch (appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        break;
      default:
        logger.v('_isAnimated: $_isAnimated, _isPlaying: $_isPlaying');
        if (_isAnimated || _isPlaying) {
          return; //  don't follow scrolling when animated or playing
        }
        var orderedSet = SplayTreeSet<ItemPosition>((e1, e2) {
          return e1.index.compareTo(e2.index);
        })
          ..addAll(playerItemPositionsListener.itemPositions.value);
        if (orderedSet.isNotEmpty) {
          var item = orderedSet.first;
          selectLyricSection(item.index + (item.itemLeadingEdge < -0.02 ? 1 : 0));
          logger.v('playerItemPositionsListener:  length: ${orderedSet.length}'
              ', _lyricSectionNotifier.index: ${_lyricSectionNotifier.index}');
          logger.v('   ${item.index}: ${item.itemLeadingEdge.toStringAsFixed(3)}, ');
        }
        break;
    }
  }

  scrollToLyricSection(int index, {final bool force = false}) {
    if (widget._song.lyricSections.isEmpty) {
      return; //  safety
    }
    index = Util.indexLimit(index, widget._song.lyricSections); //  safety

    final priorIndex = _lyricSectionNotifier.index;
    logger.log(_logScroll, 'scrollToLyricSection(): $index from $priorIndex, _isAnimated: $_isAnimated');
    if (_lyricSectionNotifier.index == index && !force) {
      //  nothing to do
      return;
    }

    selectLyricSection(index);

    if (appOptions.userDisplayStyle == UserDisplayStyle.proPlayer) {
      return; //  pro's never scroll!
    }
    _itemScrollTo(index, force: force, priorIndex: priorIndex);
  }

  _itemScrollTo(int index, {final bool force = false, int? priorIndex}) {
    if (_itemScrollController.isAttached) {
      //  local scroll
      _isAnimated = true;
      var duration = force
          ? const Duration(milliseconds: 20)
          : index >= (priorIndex ?? 0)
              ? const Duration(milliseconds: 1400)
              : const Duration(milliseconds: 400);
      _itemScrollController
          .scrollTo(index: index, duration: duration, curve: Curves.fastLinearToSlowEaseIn)
          .then((value) {
        Future.delayed(duration).then((_) {
          //  fixme: the scrollTo returns prior to the completion of the animation!
          _isAnimated = false;
        });
      });
    }
  }

  selectLyricSection(int index) {
    if (_song.lyricSections.isEmpty) {
      return; //  safety
    }
    index = Util.indexLimit(index, _song.lyricSections); //  safety

    //  update the widgets
    _lyricSectionNotifier.index = index;

    //  remote scroll for followers
    if (songUpdateService.isLeader) {
      var lyricSection = _song.lyricSections[index];
      leaderSongUpdate(_song.firstMomentInLyricSection(lyricSection).momentNumber);
    }
  }

  /// send a leader song update to the followers
  void leaderSongUpdate(int momentNumber) {
    if (!songUpdateService.isLeader) {
      _lastSongUpdateSent = null;
      return;
    }

    SongUpdateState state = SongUpdateState.none;
    switch (songPlayMode) {
      //  fixme: reconcile the enums
      case _SongPlayMode.autoPlay:
        state = SongUpdateState.playing;
        break;
      case _SongPlayMode.pause:
      case _SongPlayMode.manualPlay:
        state = SongUpdateState.manualPlay;
        break;
      case _SongPlayMode.idle:
        state = SongUpdateState.idle;
        break;
    }

    //  don't send the update unless we have to
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
    update.singer = playerSinger ?? 'unknown';
    update.state = state;
    songUpdateService.issueSongUpdate(update);

    logger.log(
        _logLeaderFollower,
        'leaderSongUpdate: momentNumber: $momentNumber'
        ', state: $state');
  }

  IconData get playStopIcon => _isPlaying ? Icons.stop : Icons.play_arrow;

  void performPlay() {
    setState(() {
      setPlayMode();
      setSelectedSongMoment(_song.songMoments.first);
      leaderSongUpdate(-1);
      logger.log(_logMode, 'play:');
      if (!songUpdateService.isFollowing) {
        _songMaster.playSong(widget._song, drumParts: _drumParts, bpm: playerSelectedBpm ?? _song.beatsPerMinute);
      }
    });
  }

  /// Workaround to avoid calling setState() outside of the framework classes
  void setPlayState() {
    if (_songUpdate != null && _song.songMoments.isNotEmpty) {
      int momentNumber = Util.indexLimit(_songUpdate!.momentNumber, _song.songMoments);
      assert(momentNumber >= 0);
      assert(momentNumber < _song.songMoments.length);
      var songMoment = _song.songMoments[momentNumber];

      //  map state to mode   fixme: should reconcile the enums
      _SongPlayMode newSongPlayMode = _SongPlayMode.idle;
      switch (_songUpdate!.state) {
        case SongUpdateState.playing:
          if (!_isPlaying) {
            setPlayMode();
          }
          newSongPlayMode = _SongPlayMode.autoPlay;
          setSelectedSongMoment(songMoment);
          break;
        case SongUpdateState.manualPlay:
          _isPlaying = false;
          newSongPlayMode = _SongPlayMode.manualPlay;
          scrollToLyricSection(songMoment.lyricSection.index);
          break;
        default:
          _isPlaying = false;
          newSongPlayMode = _SongPlayMode.idle;
          scrollToLyricSection(songMoment.lyricSection.index);
          break;
      }
      if (songPlayMode != newSongPlayMode) {
        setState(() {
          songPlayMode = newSongPlayMode;
        });
      }

      logger.log(
          _logLeaderFollower,
          'setPlayState: post state: ${_songUpdate?.state}, isPlaying: $_isPlaying'
          ', moment: ${_songUpdate?.momentNumber}'
          ', songPlayMode: $songPlayMode');
    }
  }

  void setPlayMode() {
    _isPaused = false;
    _isPlaying = true;
    songPlayMode = _SongPlayMode.autoPlay;
  }

  void performStop() {
    setState(() {
      simpleStop();
    });
  }

  void simpleStop() {
    _isPlaying = false;
    _isPaused = true;
    songPlayMode = _SongPlayMode.idle;
    _songMaster.stop();
    _songMomentNotifier.songMoment = null;
    logger.log(_logMode, 'simpleStop()');
    logger.log(_logScroll, 'simpleStop():');
  }

  void pauseToggle() {
    logger.log(_logMode, '_pauseToggle():  pre: _isPlaying: $_isPlaying, _isPaused: $_isPaused');
    setState(() {
      if (_isPlaying) {
        _isPaused = !_isPaused;
        if (_isPaused) {
          _songMaster.pause();
          songPlayMode = _SongPlayMode.pause;
          logger.log(_logScroll, 'pause():');
        } else {
          _songMaster.resume();
          songPlayMode = _SongPlayMode.autoPlay;
        }
      } else {
        _songMaster.resume();
        _isPlaying = true;
        _isPaused = false;
        songPlayMode = _SongPlayMode.autoPlay;
      }
    });
    logger.log(_logMode, '_pauseToggle(): post: _isPlaying: $_isPlaying, _isPaused: $_isPaused');
  }

  /// Adjust the displayed
  setSelectedSongKey(music_key.Key key) {
    logger.log(_logMusicKey, 'key: $key');

    //  add any offset
    music_key.Key newDisplayKey = key.nextKeyByHalfSteps(displayKeyOffset);
    logger.log(_logMusicKey, 'offsetKey: $newDisplayKey');

    //  deal with capo
    if (capoIsAvailable() && _isCapo) {
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

    Future.delayed(const Duration(milliseconds: 30)).then((_) {
      logger.v('after delay: ');
      scrollToLyricSection(_lyricSectionNotifier.index, force: true);
    });
    forceTableRedisplay();

    leaderSongUpdate(-1);
  }

  String titleAnchor() {
    return anchorUrlStart + Uri.encodeFull('${widget._song.title} ${widget._song.artist} ${widget._song.coverArtist}');
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
    widget._song = app.selectedSong;
    _song = widget._song;
    _lyricSectionNotifier.index = 0;
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
      appOptions.drumPartsListJson = _drumPartsList.toJson();
      _drumParts = app.selectedDrumParts;

      logger.v('app.selectedDrumParts: ${app.selectedDrumParts}');
      logger.v('songMatch: ${_drumPartsList.songMatch(song)?.name}');
      logger.v('_drumPartsList: ${_drumPartsList.toJson()}');

      _playerIsOnTop = true;
      widget._song = app.selectedSong;
      _song = widget._song;
      _lyricSectionNotifier.index = 0;
      forceTableRedisplay();
      _resetIdleTimer();
    });
  }

  void forceTableRedisplay() {
    int index = _lyricSectionNotifier.index;
    logger.log(_logBuild, '_forceTableRedisplay()');
    setState(() {});
    scrollToLyricSection(index, force: true);
  }

  void adjustDisplay() {
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
        ', _songPlayerChangeNotifier.songMoment: ${_songMomentNotifier.songMoment?.momentNumber}');

    if (_songMomentNotifier.songMoment != songMoment) {
      _songMomentNotifier.songMoment = songMoment;
      scrollToLyricSection(songMoment?.lyricSection.index ?? 0);

      if (songUpdateService.isLeader) {
        leaderSongUpdate(_songMomentNotifier.songMoment?.momentNumber ?? 0); //  fixme
      }
    }
  }

  bool capoIsAvailable() {
    return !appOptions.isSinger && !(songUpdateService.isConnected && songUpdateService.isLeader);
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
                                        adjustDisplay();
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
                                      adjustDisplay();
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
                                        adjustDisplay();
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
                                      adjustDisplay();
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
                                        adjustDisplay();
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
                                      adjustDisplay();
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
                                        adjustDisplay();
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
                                      adjustDisplay();
                                    });
                                  },
                                  style: popupStyle,
                                ),
                              ]),
                              //  banner
                              AppWrap(children: [
                                Radio<UserDisplayStyle>(
                                  value: UserDisplayStyle.banner,
                                  groupValue: appOptions.userDisplayStyle,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        appOptions.userDisplayStyle = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                appTextButton(
                                  'Banner',
                                  appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                  onPressed: () {
                                    setState(() {
                                      appOptions.userDisplayStyle = UserDisplayStyle.banner;
                                      adjustDisplay();
                                    });
                                  },
                                  style: popupStyle,
                                ),
                              ]),
                            ]),
                        //  const AppSpaceViewportWidth(),
                        AppWrapFullWidth(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: viewportWidth(0.5),
                            children: [
                              appTextButton(
                                'Repeats:',
                                appKeyEnum: AppKeyEnum.playerCompressRepeatsToggle,
                                value: appOptions.compressRepeats,
                                onPressed: () {
                                  setState(() {
                                    compressRepeats = !compressRepeats;
                                    adjustDisplay();
                                  });
                                },
                                style: boldStyle,
                              ),
                              AppWrap(children: [
                                Radio<bool>(
                                  value: true,
                                  groupValue: appOptions.compressRepeats,
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
                                  child: appIconButton(
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
                                  groupValue: appOptions.compressRepeats,
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
                                  child: appIconButton(
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
                                    message: 'Show Nashville notation.',
                                    child: Text(
                                      'Nashville: ',
                                      style: boldStyle,
                                      softWrap: false,
                                    ),
                                  ),
                                  AppRadio<NashvilleSelection>(
                                      text: 'Off',
                                      appKeyEnum: AppKeyEnum.optionsNashville,
                                      value: NashvilleSelection.off,
                                      groupValue: appOptions.nashvilleSelection,
                                      onPressed: () {
                                        setState(() {
                                          appOptions.nashvilleSelection = NashvilleSelection.off;
                                          adjustDisplay();
                                        });
                                      },
                                      style: popupStyle),
                                  AppRadio<NashvilleSelection>(
                                      text: 'both',
                                      appKeyEnum: AppKeyEnum.optionsNashville,
                                      value: NashvilleSelection.both,
                                      groupValue: appOptions.nashvilleSelection,
                                      onPressed: () {
                                        setState(() {
                                          appOptions.nashvilleSelection = NashvilleSelection.both;
                                          adjustDisplay();
                                        });
                                      },
                                      style: popupStyle),
                                  AppRadio<NashvilleSelection>(
                                      text: 'only',
                                      appKeyEnum: AppKeyEnum.optionsNashville,
                                      value: NashvilleSelection.only,
                                      groupValue: appOptions.nashvilleSelection,
                                      onPressed: () {
                                        setState(() {
                                          appOptions.nashvilleSelection = NashvilleSelection.only;
                                          adjustDisplay();
                                        });
                                      },
                                      style: popupStyle),
                                ],
                              ),
                              const AppSpace(
                                horizontalSpace: 20,
                              ),
                              if (appOptions.userDisplayStyle != UserDisplayStyle.singer)
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
                        const AppSpace(),
                        AppWrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(
                            'Volume:',
                            style: popupStyle,
                          ),
                          SizedBox(
                            width: app.screenInfo.mediaWidth * 0.4, // fixme: too fiddly
                            child: Slider(
                              value: appOptions.volume * 10,
                              onChanged: (value) {
                                setState(() {
                                  appOptions.volume = value / 10;
                                });
                              },
                              min: 0,
                              max: 10.0,
                            ),
                          ),
                        ]),
                        const AppSpace(),
                        AppWrapFullWidth(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: viewportWidth(1),
                            children: [
                              AppTooltip(
                                message: 'Select the drums',
                                child: appIconButton(
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
                              Text(_drumParts?.name ?? 'no drum parts', style: popupStyle)
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
                            AppRadio<bool>(
                                text: 'No NinJam aids',
                                appKeyEnum: AppKeyEnum.optionsNinJam,
                                value: false,
                                groupValue: appOptions.ninJam,
                                onPressed: () {
                                  setState(() {
                                    appOptions.ninJam = false;
                                    adjustDisplay();
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
                                    adjustDisplay();
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

    if (delta < 60 / 30 && delta > 60 / 200) {
      int bpm = (_tempoRollingAverage ??= RollingAverage()).average(60 / delta).round();
      if (playerSelectedBpm != bpm) {
        setState(() {
          playerSelectedBpm = bpm;
          logger.log(_logBPM, 'tempoTap(): bpm: $playerSelectedBpm');
        });
      }
    } else {
      //  delta too small or too large
      _tempoRollingAverage = null;
      playerSelectedBpm = null; //  default to song beats per minute
      logger.log(_logBPM, 'tempoTap(): default: bpm: $playerSelectedBpm');
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
      logger.v('idleTimer fired');
      Navigator.of(context).pop();
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  static const String anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  bool get songIsInPlay => songPlayMode == _SongPlayMode.autoPlay || songPlayMode == _SongPlayMode.manualPlay;
  _SongPlayMode songPlayMode = _SongPlayMode.idle;
  bool _isPaused = false;
  int _lastBumpTimeMs = 0;

  late final FocusNode _rawKeyboardListenerFocusNode;

  set compressRepeats(bool value) => appOptions.compressRepeats = value;

  bool get compressRepeats => appOptions.compressRepeats;

  music_key.Key _displaySongKey = music_key.Key.C;
  int displayKeyOffset = 0;

  NinJam _ninJam = NinJam.empty();

  int _lastTempoTap = DateTime.now().microsecondsSinceEpoch;
  RollingAverage? _tempoRollingAverage;

  final SongMaster _songMaster = SongMaster();

  bool _isAnimated = false;

  int sectionIndex = 0; //  index for current lyric section, fixme temp?
  List<SongMoment> sectionSongMoments = []; //  fixme temp?
  double scrollTarget = 0;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final playerItemPositionsListener = ItemPositionsListener.create();

  // double selectedTargetY = 0;   fixme

  late Size lastSize;

  static const _centerSelections = false; //fixme: add later!
  static const _sectionCenterLocationFraction = 1.0 / 8; //  fixme: what is this really doing?
  double boxCenter = 0;
  var headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);

  Timer? _idleTimer;

  final _drumPartsList = DrumPartsList();

  late AppWidgetHelper appWidgetHelper;

  static final appOptions = AppOptions();
  final SongUpdateService songUpdateService = SongUpdateService();
}

class _DataReminderWidget extends StatefulWidget {
  const _DataReminderWidget(this.songIsInPlay, this._toolbarHeight);

  @override
  State<StatefulWidget> createState() {
    return _DataReminderState();
  }

  final bool songIsInPlay;
  final double _toolbarHeight;
}

class _DataReminderState extends State<_DataReminderWidget> {
  @override
  Widget build(BuildContext context) {
    logger.v('_DataReminderState.build(): ${widget.songIsInPlay}');
    return widget.songIsInPlay
        ? SizedBox.expand(
            child: Column(
              children: [
                AppSpace(
                  verticalSpace: widget._toolbarHeight + 2,
                ),
                AppWrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  children: [
                    const AppSpace(
                      horizontalSpace: 60,
                    ),
                    Text(
                      'Key $_selectedSongKey'
                      '     Tempo: ${playerSelectedBpm ?? _song.beatsPerMinute}'
                      '    Beats: ${_song.timeSignature.beatsPerBar}'
                      '${_isCapo ? '    Capo ${_capoLocation == 0 ? 'not needed' : 'on $_capoLocation'}' : ''}'
                      '  ', //  padding at the end
                      style: generateAppTextStyle(
                        fontSize: app.screenInfo.fontSize * 0.7,
                        decoration: TextDecoration.none,
                        backgroundColor: const Color(0xe0eff4fd), //  fake a blended color, semi-opaque
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        : NullWidget();
  }
}
