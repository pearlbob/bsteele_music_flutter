import 'dart:async';
import 'dart:collection';
import 'dart:math';

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
const Level _logLeaderSongUpdate = Level.debug;
const Level _logPlayerItemPositions = Level.debug;
const Level _logScrollAnimation = Level.debug;
const Level _logManualPlayScrollAnimation = Level.debug;
const Level _logDataReminderState = Level.debug;

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
    var size = PlatformDispatcher.instance.implicitView?.physicalSize;
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
    logger.log(
        _logSongMaster,
        'songMasterListener:  leader: ${songUpdateService.isLeader}  ${DateTime.now()}'
        ', songPlayMode: ${_songMaster.songUpdateState.name}'
        ', moment: ${_songMaster.momentNumber}'
        ', lyricSection: ${_song.getSongMoment(_songMaster.momentNumber ?? 0)?.lyricSection.index}');

    //  follow the song master moment number
    switch (songUpdateState) {
      case SongUpdateState.none:
      case SongUpdateState.pause:
      case SongUpdateState.idle:
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
        //  select the current measure
        if (_songMaster.momentNumber != null) {
          //  tell the followers to follow, including the count in
          leaderSongUpdate(_songMaster.momentNumber!);
          _playMomentNotifier.playMoment = PlayMoment(
              SongUpdateState.playing, _songMaster.momentNumber!, _song.getSongMoment(_songMaster.momentNumber!));

          if (_songMaster.momentNumber! >= 0) {
            var row = _lyricsTable.songMomentNumberToRow(_songMaster.momentNumber!);
            _lyricSectionNotifier.setIndexRow(_lyricsTable.rowToLyricSectionIndex(row), row);
            _itemScrollToRow(row);
          }
        }
        break;
    }
    songUpdateState = _songMaster.songUpdateState;
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
    logger.log(_logMode, 'playMode: $songUpdateState');

    _showCapo = capoIsPossible() && _isCapo;

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

    if (appOptions.ninJam) {
      _ninJam = NinJam(_song, key: _displaySongKey, keyOffset: _displaySongKey.getHalfStep() - _song.key.getHalfStep());
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

    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _playMomentNotifier),
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
                  appBar: appWidgetHelper.backBar(
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
                                theme.colorScheme.background,
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
                            constraints: BoxConstraints.loose(Size(app.screenInfo.mediaWidth / 128, 3)),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      //  player screen
                      Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            textDirection: TextDirection.ltr,
                            children: <Widget>[
                              //  top section when idle
                              if (songUpdateState == SongUpdateState.idle)
                                Column(
                                  children: [
                                    AppWrapFullWidth(
                                        alignment: WrapAlignment.spaceBetween,
                                        spacing: fontSize,
                                        children: [
                                          //  play button
                                          AppTooltip(
                                            message: songUpdateService.isFollowing
                                                ? 'Cannot play if following' //fixme:  ${songUpdateService.leaderName}
                                                : '''
Click the button for play.
Space bar or clicking the song area starts play as well.
Selected section is in the top of the display with a red indicator.
Another space bar or song area hit below the middle advances one section.
Down arrow also advances one section.
Up arrow backs up one section.
Right arrow speeds up the BPM.
Left arrow slows the BPM.
Scrolling with the mouse wheel selects individual rows.
Enter ends the "play" mode.
With z or q, the play stops and goes back to the play list top.''',
                                            child: Container(
                                              padding: const EdgeInsets.only(left: 8, right: 8),
                                              child: appIconWithLabelButton(
                                                appKeyEnum: AppKeyEnum.playerPlay,
                                                icon: appIcon(
                                                  playStopIcon,
                                                  size: 1.25 * fontSize,
                                                ),
                                                onPressed: songUpdateService.isFollowing
                                                    ? null
                                                    : () {
                                                        app.clearMessage();
                                                        songUpdateState.isPlaying ? performStop() : performPlay();
                                                      },
                                              ),
                                            ),
                                          ),
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
                                            //           _assignNewSong( previousSongInTheList());
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
                                            //           _assignNewSong( nextSongInTheList());
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
                                            AppTooltip(
                                              message: songUpdateState.isPlaying
                                                  ? 'Song is playing'
                                                  : (songUpdateService.isFollowing
                                                      ? 'Followers cannot edit.\nDisable following back on the main Options\n'
                                                          ' to allow editing.'
                                                      : (app.isEditReady
                                                          ? 'Edit the song'
                                                          : 'Device is not edit ready')),
                                              child: appIconWithLabelButton(
                                                appKeyEnum: AppKeyEnum.playerEdit,
                                                icon: appIcon(
                                                  Icons.edit,
                                                ),
                                                onPressed: (!songUpdateState.isPlaying &&
                                                        !songUpdateService.isFollowing &&
                                                        app.isEditReady)
                                                    ? () {
                                                        navigateToEdit(context, _song);
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            AppSpace(horizontalSpace: 3.5 * fontSize),
                                          ]),
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
                                  appOptions.ninJam &&
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
                              //  song chords and lyrics
                              if (lyricsTableItems.isNotEmpty) //  ScrollablePositionedList messes up otherwise
                                Expanded(
                                    child: GestureDetector(
                                        onTapDown: (details) {
                                          //  respond to taps above and below the middle of the screen
                                          if ((appOptions.tapToAdvance == TapToAdvance.upOrDown) &&
                                              songUpdateState != SongUpdateState.playing &&
                                              appOptions.userDisplayStyle != UserDisplayStyle.proPlayer) {
                                            if (songUpdateState != SongUpdateState.playing) {
                                              //  start manual play
                                              scrollToLyricSection(0); //  always start manual play from the beginning
                                              setState(() {
                                                performPlay();
                                              });
                                            } else if (appOptions.tapToAdvance == TapToAdvance.upOrDown) {
                                              //  don't respond above the player song table
                                              var offset = _tableGlobalOffset();
                                              if (details.globalPosition.dy > offset.dy) {
                                                if (details.globalPosition.dy > app.screenInfo.mediaHeight / 2) {
                                                  bpmBump(1); //  fixme: when not in play
                                                } else {
                                                  bpmBump(-1); //  fixme: when not in play
                                                }
                                              }
                                            }
                                          }
                                        },
                                        child: scrollablePositionedList)),
                            ]),
                      ),
                      // ),
                    ],
                  ),
                ),

                //  player settings
                if (!songUpdateState.isPlaying)
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
                        ),
                      ]),
                    ],
                  ),

                if (songUpdateState.isPlaying)
                  Column(
                    children: [
                      AppSpace(
                        verticalSpace: appWidgetHelper.toolbarHeight + 8,
                      ),
                      AppWrapFullWidth(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.start,
                          children: [
                            AppTooltip(
                              message: 'Stop the song playing.',
                              child: Container(
                                padding: const EdgeInsets.only(left: 8, right: 8),
                                child: appIconWithLabelButton(
                                  appKeyEnum: AppKeyEnum.playerStop,
                                  icon: appIcon(
                                    Icons.stop,
                                    size: 1.25 * fontSize,
                                  ),
                                  onPressed: () {
                                    app.clearMessage();
                                    performStop();
                                  },
                                ),
                              ),
                            ),
                            _DataReminderWidget(songUpdateState.isPlaying, _songMaster),
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

    if (e.isKeyPressed(LogicalKeyboardKey.space) ||
        //  workaround for cheap foot pedal... only outputs b
        e.isKeyPressed(LogicalKeyboardKey.keyB)) {
      if (e.isControlPressed) {
        tempoTap();
      } else {
        switch (songUpdateState) {
          case SongUpdateState.idle:
          case SongUpdateState.none:
            //  start manual play
            scrollToLyricSection(0); //  always start manual play from the beginning
            playDrums();
            setState(() {
              performPlay();
            });
            break;
          case SongUpdateState.playing:
          case SongUpdateState.pause:
            break;
        }
      }
      return KeyEventResult.handled;
    } else if (!songUpdateService.isFollowing) {
      if (e.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
        logger.d('arrowDown');
        _songMaster.skipCurrentSection();
        return KeyEventResult.handled;
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
        logger.log(_logKeyboard, 'arrowUp');
        _songMaster.repeatSection();
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

  double boxCenterHeight() {
    return min(app.screenInfo.mediaHeight, 1080 /*  limit leader area to hdtv size */) * _scrollAlignment * 2;
  }

  _clearCountIn() {
    _updateCountIn(-countInMax);
  }

  _updateCountIn(int countIn) {
    _countIn = countIn;
    logger.v('countIn: $countIn');
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
    logger.v('_countInWidget.runtimeType: ${_countInWidget.runtimeType}');
  }

  /// bump the bpm up or down
  bpmBump(final int bump) {
    logger.log(_logBPM, 'BPM bump($bump)');
    _changeBPM((playerSelectedBpm ?? _song.beatsPerMinute) + bump);
  }

  void itemPositionsListener() {
    switch (songUpdateState) {
      case SongUpdateState.idle:
      case SongUpdateState.none:
      case SongUpdateState.pause:
        //  followers get to follow even if not playing
        var orderedSet = SplayTreeSet<ItemPosition>((e1, e2) {
          return e1.index.compareTo(e2.index);
        })
          ..addAll(playerItemPositionsListener.itemPositions.value);
        if (orderedSet.isNotEmpty) {
          var item = orderedSet.first;
          var momentNumber = _lyricsTable.rowToMomentNumber(item.index + (item.itemLeadingEdge < -0.04 ? 1 : 0));
          logger.log(_logPlayerItemPositions, 'itemPositionsListener(): $item, momentNumber: $momentNumber');
          if (momentNumber != 0 || item.index <= 0) {
            leaderSongUpdate(momentNumber);
          }
        }

        // switch (appOptions.userDisplayStyle) {
        //   case UserDisplayStyle.banner:
        //     break;
        //   default:
        //     logger.v('_isAnimated: $_isAnimated, playMode: $songUpdateState');
        //     if (_isAnimated || songUpdateState.isPlaying) {
        //       return; //  don't follow scrolling when animated or playing
        //     }
        //     var orderedSet = SplayTreeSet<ItemPosition>((e1, e2) {
        //       return e1.index.compareTo(e2.index);
        //     })
        //       ..addAll(playerItemPositionsListener.itemPositions.value);
        //     if (orderedSet.isNotEmpty) {
        //       var item = orderedSet.first;
        //       _selectMomentByRow(item.index + (item.itemLeadingEdge < -0.04 ? 1 : 0));
        //       logger.log(
        //           _logPlayerItemPositions,
        //           'playerItemPositionsListener:  length: ${orderedSet.length}'
        //           ', _lyricSectionNotifier.index: ${_lyricSectionNotifier.lyricSectionIndex}');
        //       logger.log(
        //           _logPlayerItemPositions,
        //           '   ${item.index}: ${item.itemLeadingEdge.toStringAsFixed(3)}'
        //           ' to ${item.itemTrailingEdge.toStringAsFixed(3)}');
        //     }
        //     break;
        // }
        break;
      case SongUpdateState.playing:
      //  following done by the song update service
        break;
    }
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

    if (appOptions.userDisplayStyle == UserDisplayStyle.proPlayer) {
      //  notify lyrics of selection... even if there is no scroll
      logger.v('proPlayer: _lyricSectionNotifier.index: ${_lyricSectionNotifier.lyricSectionIndex}');
      return; //  pro's never scroll!
    }
    _itemScrollToRow(_lyricsTable.lyricSectionIndexToRow(index), force: force, priorIndex: priorIndex);
  }

  _itemScrollToRow(int row, {final bool force = false, int? priorIndex}) {
    if (_itemScrollController.isAttached) {
      if (_isAnimated) {
        logger.log(_logScrollAnimation, 'scrollTo(): double animation!, force: $force, priorIndex: $priorIndex');
      }

      //  local scroll
      _isAnimated = true;

      //  guess a duration based on the song and the row
      var secondsPerMeasure = _song.beatsPerBar * 60.0 / _song.beatsPerMinute;
      var rowMomentNumber = _lyricsTable.rowToMomentNumber(row);
      var nextRowMomentNumber = _lyricsTable.rowToMomentNumber(row + 1);
      if (nextRowMomentNumber == 0) {
        nextRowMomentNumber = _lyricsTable.rowToMomentNumber(row + 2);
      }
      double rowTime = secondsPerMeasure; // safety
      if (nextRowMomentNumber > rowMomentNumber) {
        rowTime = ((_song.getSongMoment(nextRowMomentNumber)?.beatNumber ?? 0) -
            (_song.getSongMoment(rowMomentNumber)?.beatNumber ?? 0)) *
            60.0 /
            _song.beatsPerMinute;
      }
      var duration = force
          ? const Duration(milliseconds: 20)
          : row >= (priorIndex ?? 0)
          ? Duration(milliseconds: (0.4 * rowTime * Duration.millisecondsPerSecond).toInt())
          : const Duration(milliseconds: 400);
      logger.log(
          _logScrollAnimation, 'scrollTo(): index: $row, duration: $duration, rowTime: ${rowTime.toStringAsFixed(3)}');
      // logger.log(_logScrollAnimation, 'scrollTo(): ${StackTrace.current}');
      _itemScrollController
          .scrollTo(index: row, duration: duration, alignment: _scrollAlignment, curve: Curves.linear)
          .then((value) {
        Future.delayed(duration).then((_) {
          //  fixme: the scrollTo returns prior to the completion of the animation!
          _isAnimated = false;
        });
      });
    }
  }

  _selectMomentByRow(final int row) {
    _selectMoment(_lyricsTable.rowToMomentNumber(row));
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
    update.user = appOptions.user;
    update.singer = playerSinger ?? 'unknown';
    update.state = songUpdateState;
    songUpdateService.issueSongUpdate(update);

    logger.log(
        _logLeaderFollower,
        'leaderSongUpdate: momentNumber: $momentNumber'
        ', state: $songUpdateState');
  }

  IconData get playStopIcon => songUpdateState.isPlaying ? Icons.stop : Icons.play_arrow;

  performPlay() {
    logger.log(_logMode, 'manualPlay:');
    setState(() {
      songUpdateState = SongUpdateState.playing;
      setSelectedSongMoment(_song.songMoments.first);

      if (!songUpdateService.isFollowing) {
        _playMomentNotifier.playMoment =
            PlayMoment(SongUpdateState.playing, _songMaster.momentNumber ?? 0, _song.songMoments.first);
        _songMaster.playSong(widget._song, drumParts: _drumParts, bpm: playerSelectedBpm ?? _song.beatsPerMinute);
      }
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

    Future.delayed(const Duration(milliseconds: 30)).then((_) {
      logger.v('after delay: ');
      scrollToLyricSection(_lyricSectionNotifier.lyricSectionIndex, force: true);
    });
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
      appOptions.drumPartsListJson = _drumPartsList.toJson();

      logger.v('app.selectedDrumParts: ${app.selectedDrumParts}');
      logger.v('songMatch: ${_drumPartsList.songMatch(song)?.name}');
      logger.v('_drumPartsList: ${_drumPartsList.toJson()}');

      _playerIsOnTop = true;
      _assignNewSong(app.selectedSong);
      _lyricSectionNotifier.setIndexRow(0, 0);
      forceTableRedisplay();
      _resetIdleTimer();
    });
  }

  void forceTableRedisplay() {
    int index = _lyricSectionNotifier.lyricSectionIndex;
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
                        //  UserDisplayStyle
                        AppWrapFullWidth(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: viewportWidth(0.5),
                            children: [
                              Text(
                                'Display style: ',
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
                                AppTooltip(
                                  message: 'Display the song using the professional player style.\n'
                                      'This condenses the song chords to a minimum presentation without lyrics.',
                                  child: appTextButton(
                                    'Pro',
                                    appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                    value: UserDisplayStyle.proPlayer,
                                    onPressed: () {
                                      setState(() {
                                        appOptions.userDisplayStyle = UserDisplayStyle.proPlayer;
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
                                        appOptions.userDisplayStyle = UserDisplayStyle.player;
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
                                AppTooltip(
                                  message: 'Display the song showing all chords and lyrics.\n'
                                      'This is the most typical display mode.',
                                  child: appTextButton(
                                    'Both Player and Singer',
                                    appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                    value: UserDisplayStyle.both,
                                    onPressed: () {
                                      setState(() {
                                        appOptions.userDisplayStyle = UserDisplayStyle.both;
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
                                AppTooltip(
                                  message: 'Display the song showing all the lyrics.\n'
                                      'The display of chords is minimized.',
                                  child: appTextButton(
                                    'Singer',
                                    appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                    value: UserDisplayStyle.singer,
                                    onPressed: () {
                                      setState(() {
                                        appOptions.userDisplayStyle = UserDisplayStyle.singer;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
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
                                AppTooltip(
                                  message: 'Display the song in banner (piano scroll) mode.',
                                  child: appTextButton(
                                    'Banner',
                                    appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                                    value: UserDisplayStyle.banner,
                                    onPressed: () {
                                      setState(() {
                                        appOptions.userDisplayStyle = UserDisplayStyle.banner;
                                        adjustDisplay();
                                      });
                                    },
                                    style: popupStyle,
                                  ),
                                ),
                              ]),
                            ]),
                        //  const AppSpaceViewportWidth(),
                        //  PlayerScrollHighlight
                        AppWrapFullWidth(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: viewportWidth(0.5),
                            children: [
                              Text(
                                'Scroll style: ',
                                style: boldStyle,
                              ),
                              //  off
                              AppWrap(children: [
                                Radio<PlayerScrollHighlight>(
                                  value: PlayerScrollHighlight.off,
                                  groupValue: appOptions.playerScrollHighlight,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        appOptions.playerScrollHighlight = value;
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
                                        appOptions.playerScrollHighlight = PlayerScrollHighlight.off;
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
                                  groupValue: appOptions.playerScrollHighlight,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        appOptions.playerScrollHighlight = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Highlight the row.',
                                  child: appTextButton(
                                    'Row',
                                    appKeyEnum: AppKeyEnum.optionsPlayerScrollHighlightChordRow,
                                    value: PlayerScrollHighlight.chordRow,
                                    onPressed: () {
                                      setState(() {
                                        appOptions.playerScrollHighlight = PlayerScrollHighlight.chordRow;
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
                                  groupValue: appOptions.playerScrollHighlight,
                                  onChanged: (value) {
                                    setState(() {
                                      if (value != null) {
                                        appOptions.playerScrollHighlight = value;
                                        adjustDisplay();
                                      }
                                    });
                                  },
                                ),
                                AppTooltip(
                                  message: 'Highlight the measure.',
                                  child: appTextButton(
                                    'Measure',
                                    appKeyEnum: AppKeyEnum.optionsPlayerScrollHighlightMeasure,
                                    value: PlayerScrollHighlight.measure,
                                    onPressed: () {
                                      setState(() {
                                        appOptions.playerScrollHighlight = PlayerScrollHighlight.measure;
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
                                    message: 'Show Nashville notation.',
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
                                        groupValue: appOptions.nashvilleSelection,
                                        onPressed: () {
                                          setState(() {
                                            appOptions.nashvilleSelection = NashvilleSelection.off;
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
                                        groupValue: appOptions.nashvilleSelection,
                                        onPressed: () {
                                          setState(() {
                                            appOptions.nashvilleSelection = NashvilleSelection.both;
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
                                        groupValue: appOptions.nashvilleSelection,
                                        onPressed: () {
                                          setState(() {
                                            appOptions.nashvilleSelection = NashvilleSelection.only;
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
                                  groupValue: appOptions.ninJam,
                                  onPressed: () {
                                    setState(() {
                                      appOptions.ninJam = false;
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
                                  groupValue: appOptions.ninJam,
                                  onPressed: () {
                                    setState(() {
                                      appOptions.ninJam = true;
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
                                  'not concert pitch instruments.',
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
      playerSelectedBpm = null; //  default to song beats per minute
      logger.log(_logBPM, 'tempoTap(): default: bpm: $playerSelectedBpm');
    }
  }

  _changeBPM(int newBpm) {
    newBpm = Util.intLimit(newBpm, MusicConstants.minBpm, MusicConstants.maxBpm);
    if (playerSelectedBpm != newBpm) {
      setState(() {
        playerSelectedBpm = newBpm;
        _songMaster.bpm = newBpm;
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
      logger.v('idleTimer fired');
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

  set compressRepeats(bool value) => appOptions.compressRepeats = value;

  bool get compressRepeats => appOptions.compressRepeats;

  music_key.Key _displaySongKey = music_key.Key.C;
  int displayKeyOffset = 0;

  NinJam _ninJam = NinJam.empty();

  int _lastTempoTap = DateTime.now().microsecondsSinceEpoch;
  RollingAverage? _tempoRollingAverage;

  final SongMaster _songMaster = SongMaster();
  int _countIn = 0;
  Widget _countInWidget = NullWidget();

  List<SongMoment> sectionSongMoments = []; //  fixme temp?
  double scrollTarget = 0;

  final ItemScrollController _itemScrollController = ItemScrollController();
  bool _isAnimated = false;
  final playerItemPositionsListener = ItemPositionsListener.create();

  // double selectedTargetY = 0;   fixme

  Size? lastSize;

  static const _centerSelections = true;
  static const _scrollAlignment = 0.15;
  double boxCenter = 0;
  var headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);

  Timer? _idleTimer;

  final _drumPartsList = DrumPartsList();

  DrumParts? _drumParts;

  late AppWidgetHelper appWidgetHelper;

  static final appOptions = AppOptions();
  final SongUpdateService songUpdateService = SongUpdateService();
}

/// Display data on the song while in auto or manual play mode
class _DataReminderWidget extends StatefulWidget {
  const _DataReminderWidget(this.songIsInPlay, this.songMaster);

  @override
  State<StatefulWidget> createState() {
    return _DataReminderState();
  }

  final bool songIsInPlay;
  final SongMaster songMaster;
}

class _DataReminderState extends State<_DataReminderWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PlayMomentNotifier>(builder: (context, playMomentNotifier, child) {
      int? bpm = playerSelectedBpm;
      bpm ??= (widget.songIsInPlay ? widget.songMaster.bpm : null);
      bpm ??= _song.beatsPerMinute;
      logger.log(_logDataReminderState,
          '_DataReminderState.build(): ${widget.songIsInPlay}, bpm: $bpm, playerSelectedBpm: $playerSelectedBpm');

      return widget.songIsInPlay
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
                    fontSize: app.screenInfo.fontSize * 0.7,
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
