import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/drum_screen.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/screens/tempoNotifier.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/openLink.dart';
import 'package:bsteele_music_flutter/util/song_update_service.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/grid_coordinate.dart';
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
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

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

GamePad _gamePad = GamePad();

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
const Level _logCenter = Level.debug;
const Level _logLeaderSongUpdate = Level.debug;
const Level _logPlayerItemPositions = Level.debug;
const Level _logScrollListener = Level.debug;
const Level _logScrollAnimation = Level.debug;
const Level _logListView = Level.debug;
const Level _logManualPlayScrollAnimation = Level.debug;
const Level _logDataReminderState = Level.debug;
const Level _logTempoListener = Level.debug;

const String _playStopPauseHints = '''\n
Click the play button for play. You may not see immediate song motion.
Space bar or clicking the song area starts play as well.
Space bar in play selects pause.  Space bar in pause selects play.
Number 0 or a period toggles pause.
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
  //  disregard tempo update from tempo listener
  if (songUpdate.user == _PlayerState._appOptions.user && _player == null) {
    return;
  }

  logger.log(
      _logLeaderFollower,
      'playerUpdate(): start: ${songUpdate.song.title}: ${songUpdate.songMoment?.momentNumber}'
      ', bpm: ${songUpdate.currentBeatsPerMinute} vs ${songUpdate.song.beatsPerMinute}'
      ', state: ${songUpdate.state.name}');

  if (!_playerIsOnTop) {
    Navigator.pushNamedAndRemoveUntil(
        context, Player.routeName, (route) => route.isFirst || route.settings.name == Player.routeName);
  }

  //  listen if anyone else is talking
  _player?._songUpdateService.isLeader = songUpdate.user == _PlayerState._appOptions.user;

  if (!songUpdate.song.songBaseSameContent(_songUpdate?.song) ||
      songUpdate.currentBeatsPerMinute != _songUpdate?.currentBeatsPerMinute) {
    _player?._adjustDisplay();
  }
  _songUpdate = songUpdate;

  _lastSongUpdateSent = null;
  _player?._setSelectedSongKey(songUpdate.currentKey);
  playerSelectedBpm = songUpdate.currentBeatsPerMinute;

  Timer(const Duration(milliseconds: 16), () {
    // ignore: invalid_use_of_protected_member
    logger.log(_logLeaderFollower, 'playerUpdate timer: $_songUpdate');
    _player?._setPlayState();
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
    _songUpdateService.addListener(_songUpdateServiceListener);

    //  show song master play updates
    _songMaster.addListener(_songMasterListener);

    _rawKeyboardListenerFocusNode = FocusNode();

    _songUpdateState = SongUpdateState.idle;

    if (_songUpdateService.isLeader) {
      tempoNotifier.addListener(_tempoNotifierListener);
    } else {
      tempoNotifier.removeListener(_tempoNotifierListener);
    }
  }

  @override
  initState() {
    super.initState();

    _lastSize = PlatformDispatcher.instance.implicitView?.physicalSize;
    WidgetsBinding.instance.addObserver(this);

    _displayKeyOffset = app.displayKeyOffset;
    _assignNewSong(widget._song);
    _setSelectedSongKey(playerSelectedSongKey ?? _song.key);
    playerSelectedBpm = playerSelectedBpm ?? _song.beatsPerMinute;
    _drumParts = _drumPartsList.songMatch(_song) ?? _defaultDrumParts;
    _playMomentNotifier.playMoment = null;
    _setIndexRow(0, 0);

    logger.log(_logBPM, 'initState() bpm: $playerSelectedBpm');

    _leaderSongUpdate(-3);

    WidgetsBinding.instance.scheduleWarmUpFrame();

    _listScrollController.addListener(_listScrollListener);

    app.clearMessage();

    _gamePad.addListener(() {
      _forwardSwitchPressed();
    });
  }

  _assignNewSong(final Song song) {
    widget._song = song;
    _song = song;
    _drumParts = _drumPartsList.songMatch(_song) ?? app.selectedDrumParts ?? _defaultDrumParts;
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
    if (size != _lastSize) {
      _forceTableRedisplay();
      _lastSize = size;
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
    _songUpdateService.removeListener(_songUpdateServiceListener);
    _songMaster.removeListener(_songMasterListener);
    tempoNotifier.removeListener(_tempoNotifierListener);
    playerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _bpmTextEditingController.dispose();
    _listScrollController.removeListener(_listScrollListener);
    _listScrollController.dispose();
    _rawKeyboardListenerFocusNode.dispose();
    _gamePad.cancel();

    super.dispose();
  }

  //  update the song update service status
  void _songUpdateServiceListener() {
    logger.log(_logLeaderFollower, 'songUpdateServiceListener(): $_songUpdate');
    setState(() {});
  }

  void _songMasterListener() {
    _songMasterNotifier.songMaster = _songMaster;
    if (_songMaster.momentNumber == null) {
      logger.log(_logSongMaster, '_songMaster.momentNumber == null');
    }
    logger.log(
        _logSongMaster,
        'songMasterListener:  leader: ${_songUpdateService.isLeader}  ${DateTime.now()}'
        ', songPlayMode: ${_songMaster.songUpdateState.name}'
        ', moment: ${_songMaster.momentNumber}'
        ', lyricSection: ${_song.getSongMoment(_songMaster.momentNumber ?? 0)?.lyricSection.index}');

    //  follow the song master moment number
    switch (_songUpdateState) {
      case SongUpdateState.none:
      case SongUpdateState.idle:
      case SongUpdateState.drumTempo:
        if (_songMaster.songUpdateState.isPlaying) {
          //  cancel the cell highlight
          _playMomentNotifier.playMoment = null;

          //  follow the song master's play mode
          setState(() {
            _songUpdateState = _songMaster.songUpdateState;
            _clearCountIn();
          });
        }
        if (_songMaster.momentNumber != null && _songMaster.momentNumber! >= 0) {
          var row = _lyricsTable.songMomentNumberToGridRow(_songMaster.momentNumber);
          _itemScrollToRow(row, priorIndex: _lyricsTable.songMomentNumberToGridRow(_songMaster.lastMomentNumber));
        }
        break;
      case SongUpdateState.playing:
      case SongUpdateState.playHold:
      case SongUpdateState.pause:
        //  find the current measure
        if (_songMaster.momentNumber != null) {
          //  tell the followers to follow, including the count in
          _leaderSongUpdate(_songMaster.momentNumber!);
          _setPlayMomentNotifier(
              _songMaster.songUpdateState, _songMaster.momentNumber!, _song.getSongMoment(_songMaster.momentNumber!));

          if (_songMaster.momentNumber! >= 0) {
            var row = _lyricsTable.songMomentNumberToGridRow(_songMaster.momentNumber);
            //  scroll to a new row
            if (row != _lastRowIndex) {
              _setIndexRow(_lyricsTable.rowToLyricSectionIndex(row), row);
              _itemScrollToRow(row, priorIndex: _lyricsTable.songMomentNumberToGridRow(_songMaster.lastMomentNumber));
              logger.log(_logSongMaster,
                  'songMasterListener:  play/pause: row: $row, _songMaster.momentNumber: ${_songMaster.momentNumber}');
            }
          }
        }
        break;
    }
    if (_songUpdateState != _songMaster.songUpdateState) {
      setState(() {
        _songUpdateState = _songMaster.songUpdateState;
      });
    }
  }

  void _tempoNotifierListener() {
    if (_songUpdateService.isLeader //  followers don't care
        &&
        tempoNotifier.songTempoUpdate?.songId == _song.songId //  assure the response is correct
        &&
        tempoNotifier.songTempoUpdate?.currentBeatsPerMinute != null) {
      setState(() {
        int bpm = tempoNotifier.songTempoUpdate!.currentBeatsPerMinute;
        _songMaster.setBpm(bpm);
        playerSelectedBpm = bpm;
      });
      logger.log(_logTempoListener, 'player _tempoNotifierListener: $tempoNotifier');
    }
  }

  @override
  Widget build(BuildContext context) {
    _resetIdleTimer();
    app.screenInfo.refresh(context);
    _appWidgetHelper = AppWidgetHelper(context);
    _song = widget._song; //  default only

    logger.log(_logBuild, 'player build: ModalRoute: ${ModalRoute.of(context)?.settings.name}');

    logger.log(
        _logBuild,
        'player build: $_song, ${_song.songId}, playMomentNumber: ${_playMomentNotifier.playMoment?.playMomentNumber}'
        ', songPlayMode: ${_songUpdateState.name}');

    //  deal with song updates
    if (_songUpdate != null) {
      if (_songUpdateService.isLeader) {
        _songMaster.setBpm(_songUpdate?.currentBeatsPerMinute ?? _song.beatsPerMinute);
      }
      if (!_song.songBaseSameContent(_songUpdate!.song) || _displayKeyOffset != app.displayKeyOffset) {
        _assignNewSong(_songUpdate!.song);
        _setPlayMomentNotifier(_songUpdate!.state, _songUpdate?.songMoment?.momentNumber ?? 0, _songUpdate!.songMoment);
        _selectLyricSection(_songUpdate?.songMoment?.lyricSection.index //
            ??
            _lyricSectionNotifier.lyricSectionIndex); //  safer to stay on the current index

        if (_songUpdate!.state == SongUpdateState.playing) {
          _performPlay();
        } else {
          _simpleStop();
        }

        logger.log(
            _logLeaderFollower,
            'player follower: $_song, selectedSongMoment: ${_playMomentNotifier.playMoment?.songMoment?.momentNumber}'
            ' songPlayMode: $_songUpdateState');
      }
      _setSelectedSongKey(_songUpdate!.currentKey);
    }

    _displayKeyOffset = app.displayKeyOffset;

    _fontSize = app.screenInfo.fontSize;
    _headerTextStyle = _headerTextStyle.copyWith(fontSize: _fontSize);

    _keyDropDownMenuList = [];
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

      final double chordsTextWidth = textWidth(context, _headerTextStyle, 'G'); //  something sane
      const String onString = '(on ';
      final double onStringWidth = textWidth(context, _headerTextStyle, onString);

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

        _keyDropDownMenuList.add(appDropdownMenuItem<music_key.Key>(
            value: value,
            child: AppWrap(children: [
              SizedBox(
                width: 3 * chordsTextWidth, //  max width of chars expected
                child: Text(
                  valueString,
                  style: _headerTextStyle,
                  softWrap: false,
                  textAlign: TextAlign.left,
                ),
              ),
              SizedBox(
                width: 2 * chordsTextWidth, //  max width of chars expected
                child: Text(
                  offsetString,
                  style: _headerTextStyle,
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
                    '$onString${scaleNoteByAccidentalExpressionChoice(firstScaleNote.transpose(value, relativeOffset), _appOptions.accidentalExpressionChoice, key: _displaySongKey).toMarkup()})',
                    style: _headerTextStyle,
                    softWrap: false,
                    textAlign: TextAlign.right,
                  ),
                )
            ])));
      }
    }

    const hoverColor = App.universalAccentColor;

    logger.log(
        _logScroll,
        ' boxMarker: $boxMarker'
        ', _scrollAlignment: $_scrollAlignment'
        ', _songUpdate?.momentNumber: ${_songUpdate?.momentNumber}');
    logger.log(_logMode, 'playMode: $_songUpdateState');

    _showCapo = _capoIsPossible() && _isCapo;

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

    if (_appOptions.ninJam) {
      _ninJam = NinJam(_song, key: _displaySongKey, keyOffset: _displaySongKey.getHalfStep() - _song.key.getHalfStep());
    }

    List<Widget> lyricsTableItems = _lyricsTable.lyricsTableItems(
      _song,
      musicKey: _displaySongKey,
    );

    switch (_appOptions.userDisplayStyle) {
      case UserDisplayStyle.banner:
        _listView ??= ListView.builder(
          itemCount: _song.songMoments.length + 1,
          controller: _listScrollController,
          itemBuilder: (context, index) {
            logger.log(_logListView, '_listView($index)');
            return lyricsTableItems[Util.intLimit(index, 0, lyricsTableItems.length)];
          },
          scrollDirection: Axis.horizontal,
        );
        break;
      case UserDisplayStyle.highContrast:
        _listView ??= ListView.builder(
            itemCount: lyricsTableItems.length,
            controller: _listScrollController,
            itemBuilder: (BuildContext context, int index) {
              logger.log(_logListView, '_listView($index)');
              return lyricsTableItems[index];
            });
        break;
      default:
        //  all other display styles
        _listView ??= ListView.builder(
          itemCount: lyricsTableItems.length,
          controller: _listScrollController,
          scrollDirection: Axis.vertical,
          itemBuilder: (context, index) {
            logger.log(_logListView, '_listView($index) ${_song.title}');
            return lyricsTableItems[index];
          },
        );
        break;
    }

    final backBar = _appWidgetHelper.backBar(
        titleWidget: Row(
          children: [
            Flexible(
              child: AppTooltip(
                message: 'Click to hear the song on youtube.com',
                child: InkWell(
                  onTap: () {
                    openLink(_titleAnchor());
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
                  openLink(_artistAnchor());
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
          _songMaster.removeListener(_songMasterListener);
          _songMaster.stop();
        });

    _bpmTextEditingController.text = (playerSelectedBpm ?? _song.beatsPerMinute).toString();

    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _playMomentNotifier),
          ChangeNotifierProvider.value(value: _songMasterNotifier),
          ChangeNotifierProvider.value(value: _lyricSectionNotifier),
        ],
        builder: (context, child) {
          return Scaffold(
              backgroundColor: theme.colorScheme.surface,
              appBar: backBar,
              body: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
                boxMarker = constraints.maxHeight * _scrollAlignment;
                logger.log(
                    _logCenter,
                    'LayoutBuilder constraints: (${constraints.maxWidth},${constraints.maxHeight})'
                    ', boxMarker: ${boxMarker.toStringAsFixed(1)}');

                return Stack(
                  children: <Widget>[
                    //  smooth background
                    if (_appOptions.userDisplayStyle != UserDisplayStyle.highContrast)
                      Container(
                        constraints: constraints,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const <Color>[
                              App.screenBackgroundColor,
                              App.measureContainerBackgroundColor,
                              App.screenBackgroundColor,
                            ],
                            stops: [0.0, boxMarker / constraints.maxHeight, 1.0],
                          ),
                        ),
                      ),

                    //  center marker
                    if (kDebugMode || _appOptions.playerScrollHighlight == PlayerScrollHighlight.off)
                      Column(
                        children: [
                          //  offset the marker
                          Container(
                            color: Colors.cyanAccent,
                            constraints: BoxConstraints.tight(Size(0, boxMarker)),
                          ),
                          Container(
                            constraints: BoxConstraints.tight(Size(
                                _appOptions.playerScrollHighlight == PlayerScrollHighlight.off
                                    ? 16
                                    : constraints.maxWidth, // for testing only
                                4)),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                    Column(
                      children: [
                        if (_appOptions.userDisplayStyle != UserDisplayStyle.highContrast) //
                          _songControls(),

                        //  song chords and lyrics
                        if (lyricsTableItems.isNotEmpty)
                          Expanded(
                            child: Focus(
                              focusNode: _rawKeyboardListenerFocusNode,
                              onKeyEvent: _playerOnKeyEvent,
                              autofocus: true,
                              child: GestureDetector(
                                  onTapDown: (details) {
                                    //  doesn't apply to pro display style
                                    if (_appOptions.userDisplayStyle == UserDisplayStyle.proPlayer) {
                                      return;
                                    }

                                    //  respond to taps above and below the middle of the screen
                                    if (_appOptions.tapToAdvance == TapToAdvance.upOrDown) {
                                      if (_songUpdateState != SongUpdateState.playing) {
                                        //  start manual play
                                        _setStatePlay();
                                      } else {
                                        //  while playing:
                                        var offset = _tableGlobalOffset();
                                        if (details.globalPosition.dx < app.screenInfo.mediaWidth / 4) {
                                          //  tablet left arrow
                                          _bpmBump(-1);
                                        } else if (details.globalPosition.dx > app.screenInfo.mediaWidth * 3 / 4) {
                                          //  tablet right arrow
                                          _bpmBump(1);
                                        } else {
                                          if (details.globalPosition.dy > offset.dy) {
                                            if (details.globalPosition.dy < constraints.maxHeight / 2) {
                                              //  tablet up arrow
                                              _songMaster.repeatSectionIncrement();
                                            } else {
                                              //  tablet down arrow
                                              _songMaster.skipToCurrentSection();
                                            }
                                          }
                                        }
                                      }
                                    }
                                  },
                                  child: _listView),
                            ),
                          ),
                      ],
                    ),

                    _songPlayTally(),
                  ],
                );
              }));
        });
  }

  //  play mode selection
  Widget _playModeSegmentedButton(SongUpdateState songUpdateState) {
    return SegmentedButton<SongUpdateState>(
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.disabled)) {
              return App.disabledColor;
            }
            return App.universalAccentColor;
          },
        ),
        visualDensity: const VisualDensity(vertical: VisualDensity.minimumDensity),
      ),
      segments: <ButtonSegment<SongUpdateState>>[
        ButtonSegment<SongUpdateState>(
          value: SongUpdateState.idle,
          icon: appIcon(
            Icons.stop,
            size: 1.75 * _fontSize,
            color: songUpdateState == SongUpdateState.idle ? Colors.red : Colors.white,
          ),
          tooltip: _appOptions.toolTips ? 'Stop playing the song.$_playStopPauseHints' : null,
          enabled: !_songUpdateService.isFollowing,
        ),
        if (songUpdateState == SongUpdateState.drumTempo)
          ButtonSegment<SongUpdateState>(
            value: SongUpdateState.drumTempo,
            label: Text(
              'Tempo',
              style: _headerTextStyle.copyWith(color: Colors.white),
            ),
            tooltip: _appOptions.toolTips ? 'Play the song.$_playStopPauseHints' : null,
            enabled: !_songUpdateService.isFollowing,
          ),
        ButtonSegment<SongUpdateState>(
          value: SongUpdateState.playing,
          icon: appIcon(
            Icons.play_arrow,
            size: 1.75 * _fontSize,
            color: songUpdateState == SongUpdateState.playing
                ? Colors.greenAccent
                : (songUpdateState == SongUpdateState.playHold ? Colors.red : Colors.white),
          ),
          tooltip: _appOptions.toolTips ? 'Play the song.$_playStopPauseHints' : null,
          enabled: !_songUpdateService.isFollowing,
        ),
        //  hide the pause unless we are in play
        if (songUpdateState == SongUpdateState.playing || songUpdateState == SongUpdateState.pause)
          ButtonSegment<SongUpdateState>(
            value: SongUpdateState.pause,
            icon: appIcon(
              Icons.pause,
              size: 1.75 * _fontSize,
              color: songUpdateState == SongUpdateState.pause ? Colors.red : Colors.white,
            ),
            tooltip: _appOptions.toolTips ? 'Pause the playing.$_playStopPauseHints' : null,
            enabled: !_songUpdateService.isFollowing,
          ),
      ],
      selected: <SongUpdateState>{songUpdateState},
      onSelectionChanged: (Set<SongUpdateState> newSelection) {
        // logger.i('onSelectionChanged: $newSelection');
        switch (newSelection.first) {
          case SongUpdateState.none:
          case SongUpdateState.idle:
          case SongUpdateState.drumTempo:
            _performStop();
            break;
          case SongUpdateState.playing:
            _performPlay();
            break;
          case SongUpdateState.playHold:
            _performHoldContinue();
            break;
          case SongUpdateState.pause:
            _performPause();
            break;
        }
      },
    );
  }

  Widget _songControls() {
    return Consumer<SongMasterNotifier>(builder: (context, songMasterNotifier, child) {
      var songUpdateState = songMasterNotifier.songMaster?.songUpdateState ?? SongUpdateState.idle;
      switch (songUpdateState) {
        case SongUpdateState.playing:
        case SongUpdateState.playHold:
        case SongUpdateState.pause:
          return NullWidget();
        default:
          return Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
              //  control buttons
              AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
                if (!_songUpdateService.isFollowing) _playModeSegmentedButton(songUpdateState),

                if (app.fullscreenEnabled && !app.isFullScreen)
                  appButton('Fullscreen', onPressed: () {
                    app.requestFullscreen();
                  }),

                if (app.message.isNotEmpty) app.messageTextWidget(),

                if (songUpdateState.isPlayingOrPausedOrHold)
                  //  repeat notifications
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

                if (songUpdateState.isPlayingOrPausedOrHold)
                  _DataReminderWidget(songUpdateState.isPlayingOrPausedOrHold, _songMaster),

                //  player settings
                if (!songUpdateState.isPlayingOrPausedOrHold)
                  AppWrap(children: [
                    //  song edit
                    AppTooltip(
                      message: songUpdateState.isPlaying
                          ? 'Song is playing'
                          : (_songUpdateService.isFollowing
                              ? 'Followers cannot edit.\nDisable following back on the main Options\n'
                                  ' to allow editing.'
                              : (app.isEditReady ? 'Edit the song' : 'Device is not edit ready')),
                      child: appIconWithLabelButton(
                        icon: appIcon(
                          Icons.edit,
                        ),
                        onPressed: (!songUpdateState.isPlaying && !_songUpdateService.isFollowing && app.isEditReady)
                            ? () {
                                _navigateToEdit(context, _song);
                              }
                            : null,
                      ),
                    ),
                    AppSpace(horizontalSpace: _fontSize),
                    AppTooltip(
                      message: 'Show the player settings dialog.',
                      child: appIconWithLabelButton(
                        icon: appIcon(
                          Icons.settings,
                          size: 1.5 * _fontSize,
                        ),
                        onPressed: () {
                          _settingsPopup();
                        },
                      ),
                    ),
                  ]),
              ]),

              //  other top sections when idle
              if (_showCapo &&
                  (songUpdateState == SongUpdateState.idle || songUpdateState == SongUpdateState.drumTempo))
                //  capo
                AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, spacing: _fontSize, children: [
                  if (_showCapo)
                    Text(
                      _capoLocation > 0 ? 'Capo on $_capoLocation' : 'No capo needed',
                      style: _headerTextStyle,
                      softWrap: false,
                    ),
                  // //  recommend a blues harp
                  // Text(
                  //   'Blues harp: ${selectedSongKey.nextKeyByFifth()}',
                  //   style: headerTextStyle,
                  //   softWrap: false,
                  // ),
                ]),

              if (songUpdateState == SongUpdateState.idle || songUpdateState == SongUpdateState.drumTempo)
                AppRow(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  //  key change
                  AppWrap(
                    children: [
                      if (!_songUpdateService.isFollowing)
                        //  key change
                        AppWrap(
                          children: [
                            AppTooltip(
                              message: 'Transcribe the song to the selected key.',
                              child: Text(
                                'Key: ',
                                style: _headerTextStyle,
                                softWrap: false,
                              ),
                            ),
                            appDropdownButton<music_key.Key>(
                              _keyDropDownMenuList,
                              onChanged: (value) {
                                setState(() {
                                  if (value != null) {
                                    _setSelectedSongKey(value);
                                  }
                                });
                              },
                              value: _selectedSongKey,
                              style: _headerTextStyle,
                              // iconSize: lookupIconSize(),
                              // itemHeight: max(headerTextStyle.fontSize ?? kMinInteractiveDimension,
                              //     kMinInteractiveDimension),
                            ),
                            if (app.isScreenBig) const AppSpace(),
                            if (app.isScreenBig)
                              AppTooltip(
                                message: 'Move the key one half step up.',
                                child: appIconWithLabelButton(
                                  icon: appIcon(
                                    Icons.arrow_upward,
                                  ),
                                  onPressed: () {
                                    if (!_isAnimated) {
                                      setState(() {
                                        _setSelectedSongKey(_selectedSongKey.nextKeyByHalfStep());
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
                                  icon: appIcon(
                                    Icons.arrow_downward,
                                  ),
                                  onPressed: () {
                                    if (!_isAnimated) {
                                      setState(() {
                                        _setSelectedSongKey(_selectedSongKey.previousKeyByHalfStep());
                                      });
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      if (_songUpdateService.isFollowing)
                        AppTooltip(
                          message: 'When following the leader, the leader will select the key for you.\n'
                              'To correct this from the main screen: menu (hamburger), Options, Hosts: None',
                          child: Text(
                            'Key: $_selectedSongKey',
                            style: _headerTextStyle,
                            softWrap: false,
                          ),
                        ),
                      const AppSpace(),
                      if (_displayKeyOffset > 0 || (_showCapo && _capoLocation > 0))
                        Text(
                          ' ($_selectedSongKey${_displayKeyOffset > 0 ? '+$_displayKeyOffset' : ''}'
                          '${_showCapo && _capoLocation > 0 ? '-$_capoLocation' : ''}=$_displaySongKey)',
                          style: _headerTextStyle,
                        ),
                    ],
                  ),
                  if (app.isScreenBig && !_songUpdateService.isFollowing)
                    //  tempo change
                    AppWrap(
                      children: [
                        AppTooltip(
                          message: 'Beats per minute.  Mouse click here or tap the m key\n'
                              ' to generate the tempo.',
                          child: appButton(
                            'BPM:',
                            onPressed: () {
                              _tempoTap(force: true);
                            },
                          ),
                        ),
                        const AppSpace(),
                        SizedBox(
                          width: 3 * app.screenInfo.fontSize,
                          child: AppTextField(
                            hintText: 'bpm',
                            controller: _bpmTextEditingController,
                            fontSize: app.screenInfo.fontSize,
                            onChanged: (value) {
                              var bpm = int.tryParse(_bpmTextEditingController.text);
                              if (bpm != null && bpm >= MusicConstants.minBpm) {
                                _changeBPM(bpm);
                              }
                            }, //  fixme: ignored
                          ),
                        ),
                        const AppSpace(),
                        AppTooltip(
                            message: 'Increment the selected beats per minute.',
                            child: appIconWithLabelButton(
                                icon: const Icon(Icons.arrow_upward),
                                onPressed: () {
                                  _changeBPM((playerSelectedBpm ?? _song.beatsPerMinute) + 1);
                                })),
                        const AppSpace(space: 5),
                        AppTooltip(
                            message: 'Decrement the selected beats per minute.',
                            child: appIconWithLabelButton(
                                icon: const Icon(Icons.arrow_downward_outlined),
                                onPressed: () {
                                  _changeBPM((playerSelectedBpm ?? _song.beatsPerMinute) - 1);
                                })),
                        const AppSpace(),
                        if (kDebugMode) const AppSpace(),
                        if (kDebugMode)
                          appButton(
                            'speed',
                            onPressed: () {
                              setState(() {
                                playerSelectedBpm = MusicConstants.maxBpm;
                                logger.log(_logBPM, 'speed: bpm: $playerSelectedBpm');
                              });
                            },
                          ),
                      ],
                    ),
                  if (app.isScreenBig && _songUpdateService.isFollowing)
                    AppTooltip(
                      message: 'When following the leader, the leader will select the tempo (BPM) for you.\n'
                          'To correct this from the main screen: menu (hamburger), Options, Hosts: None',
                      child: Text(
                        'BPM: ${playerSelectedBpm ?? _song.beatsPerMinute}',
                        style: _headerTextStyle,
                      ),
                    ),
                  AppTooltip(
                    message: 'Beats are a property of the song.\n'
                        'Edit the song to change.',
                    child: Text(
                      'Beats: ${_song.timeSignature.beatsPerBar}',
                      style: _headerTextStyle,
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
                  if (app.isScreenBig)
                    //  leader/follower status
                    AppTooltip(
                      message: 'Control the leader/follower mode from the main menu:\n'
                          'main screen: menu (hamburger), Options, Hosts',
                      child: Text(
                        _songUpdateService.isConnected
                            ? (_songUpdateService.isLeader
                                ? 'leading ${_songUpdateService.host}'
                                :
                                // (_songUpdateService.leaderName == Song.defaultUser
                                //             ? 'on ${_songUpdateService.host.replaceFirst('.local', '')}'
                                //             : 'following ${_songUpdateService.leaderName}')
                                'following ${_songUpdateService.leaderName}')
                            : (_songUpdateService.isIdle ? '' : 'lost ${_songUpdateService.host}!'),
                        style: !_songUpdateService.isConnected && !_songUpdateService.isIdle
                            ? _headerTextStyle.copyWith(color: Colors.red)
                            : _headerTextStyle,
                      ),
                    ),
                ]),

              // //  chords used
              // if (app.isScreenBig ) //  fixme: make scale chords used an option
              //   Column(
              //     children: [
              //       const AppSpace(),
              //       AppWrapFullWidth(
              //         children: [
              //           Text(
              //             'Chords used: ',
              //             style: _headerTextStyle,
              //           ),
              //           Text(
              //             _song.scaleChordsUsed().toString(),
              //             style: _headerTextStyle,
              //           )
              //         ],
              //       ),
              //     ],
              //   ),

              //  ninjam aid
              if (app.isScreenBig &&
                  _appOptions.ninJam &&
                  _ninJam.isNinJamReady &&
                  songUpdateState == SongUpdateState.idle)
                AppWrapFullWidth(spacing: 20, children: [
                  const AppSpace(),
                  AppWrap(spacing: 10 * _fontSize, children: [
                    Text(
                      'Ninjam: BPM: ${playerSelectedBpm ?? _song.beatsPerMinute.toString()}',
                      style: _headerTextStyle,
                      softWrap: false,
                    ),
                    appIconWithLabelButton(
                      icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: '/bpm ${(playerSelectedBpm ?? _song.beatsPerMinute).toString()}'));
                      },
                    ),
                  ]),
                  AppWrap(spacing: 10 * _fontSize, children: [
                    Text(
                      'Cycle: ${_ninJam.beatsPerInterval}',
                      style: _headerTextStyle,
                      softWrap: false,
                    ),
                    appIconWithLabelButton(
                      icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '/bpi ${_ninJam.beatsPerInterval}'));
                      },
                    ),
                  ]),
                  AppWrap(spacing: 10 * _fontSize, children: [
                    Text(
                      'Chords: ${_ninJam.toMarkup()}',
                      style: _headerTextStyle,
                      softWrap: false,
                    ),
                    appIconWithLabelButton(
                      icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _ninJam.toMarkup()));
                      },
                    ),
                  ]),
                ]),
            ]),
          );
      }
    });
  }

  Widget _songPlayTally() {
    return Consumer<SongMasterNotifier>(builder: (context, songMasterNotifier, child) {
      var songUpdateState = songMasterNotifier.songMaster?.songUpdateState ?? SongUpdateState.idle;
      switch (songUpdateState) {
        case SongUpdateState.none:
        case SongUpdateState.idle:
        case SongUpdateState.drumTempo:
          return NullWidget();
        default:
          return Container(
            padding: const EdgeInsets.all(5.0),
            color: (Color.lerp(App.measureContainerBackgroundColor, Colors.white, 0.85) ?? Colors.white)
                .withAlpha(128 + 64 + 32 + 8),
            child: AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, spacing: _fontSize, children: [
              _playModeSegmentedButton(songUpdateState),
              if (app.fullscreenEnabled && !app.isFullScreen)
                appButton('Fullscreen', onPressed: () {
                  app.requestFullscreen();
                }),
              Text(
                'Key: $_selectedSongKey',
                style: _headerTextStyle,
                softWrap: false,
              ),
              Text(
                'BPM: ${playerSelectedBpm ?? _song.beatsPerMinute}',
                style: _headerTextStyle,
                softWrap: false,
              ),
              Text(
                'Beats: ${_song.timeSignature.beatsPerBar}',
                style: _headerTextStyle,
                softWrap: false,
              ),
              if (app.isScreenBig && !_songUpdateService.isIdle)
                //  leader/follower status
                Text(
                  _songUpdateService.isConnected
                      ? (_songUpdateService.isLeader
                          ? 'leading ${_songUpdateService.host}'
                          :
                          // (_songUpdateService.leaderName == Song.defaultUser
                          //             ? 'on ${_songUpdateService.host.replaceFirst('.local', '')}'
                          //             : 'following ${_songUpdateService.leaderName}')
                          'following ${_songUpdateService.leaderName}')
                      : 'lost ${_songUpdateService.host}!',
                  style: !_songUpdateService.isConnected && !_songUpdateService.isIdle
                      ? _headerTextStyle.copyWith(color: Colors.red)
                      : _headerTextStyle,
                ),

              if (app.isScreenBig && _showCapo && _capoLocation > 0)
                Text(
                  'Capo: $_capoLocation',
                  style: _headerTextStyle,
                  softWrap: false,
                ),
              //  last of the wrap
              Text(
                '  ',
                style: _headerTextStyle,
                softWrap: false,
              ),
            ]),
          );
      }
    });
  }

  KeyEventResult _playerOnKeyEvent(FocusNode node, KeyEvent e) {
    logger.log(_logKeyboard, '_playerOnKeyEvent(): ${e.runtimeType}: ${e.logicalKey.keyLabel}');

    if (!_playerIsOnTop) {
      return KeyEventResult.ignored;
    }

    //  only deal with new key down or repeat events
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    /*
    stomp box mapping
    <->     arrowLeft/arrowRight
    up/down arrowUp/arrowDown
    page    pageUp/pageDown
    space   space/enter
    */

    var keyboard = HardwareKeyboard();
    logger.log(
        _logKeyboard,
        '_playerOnKey(): ${e.logicalKey}'
        ', ctl: ${keyboard.isControlPressed}'
        ', shf: ${keyboard.isShiftPressed}'
        ', alt: ${keyboard.isAltPressed}');

    if (e.logicalKey == LogicalKeyboardKey.keyM) {
      _tempoTap();
      return KeyEventResult.handled;
    } else if (e.logicalKey == LogicalKeyboardKey.space) {
      switch (_songUpdateState) {
        case SongUpdateState.idle:
        case SongUpdateState.none:
        case SongUpdateState.drumTempo:
          //  start manual play
          _setStatePlay();
          break;
        case SongUpdateState.playing:
          _sectionBump(1);
          break;
        case SongUpdateState.playHold:
          _rowBump(1);
          _songMaster.resume();
          break;
        case SongUpdateState.pause:
          _sectionBump(1);
          _songMaster.resume();
          break;
      }
      return KeyEventResult.handled;
    } else if (
        //  workaround for cheap foot pedal... only outputs b
        e.logicalKey == LogicalKeyboardKey.keyB) {
      _forwardSwitchPressed();
      return KeyEventResult.handled;
    } else if (!_songUpdateService.isFollowing) {
      if (e.logicalKey == LogicalKeyboardKey.arrowDown || e.logicalKey == LogicalKeyboardKey.numpadAdd) {
        _bump(1);
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.arrowUp || e.logicalKey == LogicalKeyboardKey.numpadSubtract) {
        _bump(-1);
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        _bpmBump(1);
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _bpmBump(-1);
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.pageUp) {
        _sectionBump(-1);
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.pageDown) {
        _sectionBump(1);
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.keyZ || e.logicalKey == LogicalKeyboardKey.keyQ) {
        if (_songUpdateState.isPlaying) {
          _performStop();
        } else {
          logger.log(_logKeyboard, 'player: pop the navigator');
          _songMaster.stop();
          _cancelIdleTimer();
          Navigator.pop(context);
        }
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.numpadEnter || e.logicalKey == LogicalKeyboardKey.enter) {
        switch (_songUpdateState) {
          case SongUpdateState.none:
          case SongUpdateState.idle:
          case SongUpdateState.drumTempo:
            _performPlay();
            break;
          case SongUpdateState.playing:
            _rowBump(1);
            break;
          case SongUpdateState.playHold:
            _rowBump(1);
            _songMaster.resume();
            break;
          case SongUpdateState.pause:
            if (!_songUpdateService.isFollowing) {
              setState(() {
                //  select start of next section
                _sectionBump(1);
                _songMaster.resume();
              });
            }
            break;
        }
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.numpad0 ||
          e.logicalKey == LogicalKeyboardKey.digit0 ||
          e.logicalKey == LogicalKeyboardKey.period) {
        switch (_songUpdateState) {
          case SongUpdateState.playing:
            _performPlayHold();
            break;
          case SongUpdateState.playHold:
            _performHoldContinue();
            break;
          default:
            _performPlay();
            break;
        }
        return KeyEventResult.handled;
      }
    }
    logger.log(_logKeyboard, '_playerOnKey(): ignored');
    return KeyEventResult.ignored;
  }

  void _forwardSwitchPressed() {
    switch (_songUpdateState) {
      case SongUpdateState.idle:
      case SongUpdateState.none:
      case SongUpdateState.drumTempo:
        //  start manual play
        _setStatePlay();
        _performPause();
        break;
      case SongUpdateState.playing:
        _rowBump(1);
        break;
      case SongUpdateState.playHold:
        _rowBump(1);
        _performHoldContinue();
        break;
      case SongUpdateState.pause:
        //  stay in pause, that is, manual mode
        _bump(1);
        break;
    }
  }

  _playDrums() {
    _songMaster.playDrums(widget._song, _drumParts, bpm: playerSelectedBpm ?? _song.beatsPerMinute);
  }

  double boxCenterHeight() {
    // fixme: this is might be wrong, but is a reasonable initial guess
    var height = app.screenInfo.mediaHeight * _scrollAlignment;
    return height;
  }

  _clearCountIn() {
    _updateCountIn(_areDrumsMuted ? 0 : -countInMax);
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
  _bpmBump(final int bump) {
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
    switch (_songUpdateState) {
      case SongUpdateState.idle:
      case SongUpdateState.none:
      case SongUpdateState.pause:
        _sectionBump(bump);
        break;

      case SongUpdateState.playing:
      case SongUpdateState.playHold:
      case SongUpdateState.drumTempo:
        _rowBump(bump);
        break;
    }
  }

  _sectionBump(final int bump) {
    logger.log(_logSongMasterBump, '  _sectionBump($bump): moment: ${_songMaster.momentNumber}');

    var lyricSectionIndex = _song.getSongMoment(_songMaster.momentNumber ?? 0)?.lyricSection.index;
    if (lyricSectionIndex != null) {
      lyricSectionIndex += bump;
      logger.log(_logSongMasterBump,
          '  _sectionBump($bump): moment: ${_songMaster.momentNumber}, to section: $lyricSectionIndex');
      var moment = _song.getFirstSongMomentAtLyricSectionIndex(lyricSectionIndex);
      if (moment != null) {
        _songMaster.skipToMomentNumber(_song, moment.momentNumber);
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
          _songMaster.skipToMomentNumber(_song, moment.momentNumber);
        }
      } else {
        //  bump backwards
        SongMoment? moment = _song.getFirstSongMomentAtPriorRow(_songMaster.momentNumber!);
        if (moment != null) {
          logger.log(_logSongMasterBump, '  _rowBump($bump): moment: ${_songMaster.momentNumber} to moment: $moment');
          _songMaster.skipToMomentNumber(_song, moment.momentNumber);
        }
      }
    }
  }

  _listScrollListener() {
    logger.log(
        _logScrollListener,
        'raw offset: ${_listScrollController.offset.toStringAsFixed(1)}, _isAnimated: $_isAnimated'
        ', offset: ${(_listScrollController.offset + boxMarker).toStringAsFixed(1)}');

    if (_isAnimated || !_songUpdateService.isLeader) {
      //  fixme: temp!!!!!!!!!!!!!!!!
      //  don't follow the animation
      return;
    }

    //  move to the scrolled to location, if scrolled by the leader
    switch (_songUpdateState) {
      case SongUpdateState.idle:
      case SongUpdateState.none:
      case SongUpdateState.pause:
      case SongUpdateState.drumTempo:
        //  followers get to follow even if not in play
        switch (_appOptions.userDisplayStyle) {
          case UserDisplayStyle.banner:
            break; //  fixme
          case UserDisplayStyle.highContrast:
            logger.log(
                _logScrollListener,
                'highContrast: ${_listScrollController.offset}'
                ', momentNumber: ${_lyricsTable.displayOffsetToSongMomentNumber(_listScrollController.offset)}');
            break;
          default:
            var offset = _listScrollController.offset + boxMarker; //  fixme!!!!!!!!!!!!!!!!!!!
            _leaderSongUpdate(_lyricsTable.displayOffsetToSongMomentNumber(offset));
            logger.log(
                _logPlayerItemPositions,
                '_itemPositionsListener(): offset: ${offset.toStringAsFixed(1)}'
                ' (${_listScrollController.offset.toStringAsFixed(1)})'
                ' moment: ${_lyricsTable.displayOffsetToSongMomentNumber(offset)}, ');
            break;
        }
        break;
      case SongUpdateState.playing:
      case SongUpdateState.playHold:
        //  following done by the song update service
        break;
    }
  }

  _scrollToLyricSection(int index, {final bool force = false}) {
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

  _itemScrollToRow(final int row, {final bool force = false, int? priorIndex}) {
    //logger.i('_itemScrollToRow($row, $force, $priorIndex):');
    if (_listScrollController.hasClients) {
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

      //  guess a duration based on the song and the row
      double rowTime = _song.displayRowBeats(row) * 60.0 / (playerSelectedBpm ?? _song.beatsPerMinute);
      priorIndex ??= _lastRowIndex;
      _lastRowIndex = row;
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

      var duration = force //
              ||
              _isAnimated //  compound scroll, perform quickly
          ? const Duration(milliseconds: 200)
          : (row >= priorIndex && _songMaster.songUpdateState.isPlaying
              ? Duration(milliseconds: (0.3 * rowTime * Duration.millisecondsPerSecond).toInt())
              : const Duration(milliseconds: 500));

      double offset = _lyricsTable.rowToDisplayOffset(row);

      logger.log(
          _logScrollAnimation,
          'scrollTo(): row: $row'
          ', offset: ${offset.toStringAsFixed(1)}'
          ', boxMarker: $boxMarker'
          ', songMoment: ${_song.getFirstSongMomentAtRow(row)}'
          // ', _lastRowIndex: $_lastRowIndex, priorIndex: $priorIndex'
          ', duration: $duration, rowTime: ${rowTime.toStringAsFixed(3)}'
          //
          );
      // logger.log(_logScrollAnimation, 'scrollTo(): ${StackTrace.current}');

      //  local scroll
      _isAnimated = true;
      _listScrollController
          .animateTo(max(minScrollOffset, offset - boxMarker), duration: duration, curve: Curves.linear)
          .then((value) {
        _isAnimated = false;
        logger.log(
            _logScrollAnimation,
            'scrollTo(): post: _lastRowIndex: $row'
            ', offset: ${max(minScrollOffset, offset - boxMarker).toStringAsFixed(1)}'
            ' + marker: ${max(minScrollOffset, offset).toStringAsFixed(1)}'
            ', boxMarker: $boxMarker');
      });
    }
  }

  _selectMoment(final int momentNumber) {
    var moment = _song.getSongMoment(momentNumber);
    if (moment == null) {
      return;
    }

    //  update the widgets
    var row = _lyricsTable.songMomentNumberToGridRow(momentNumber);
    _setIndexRow(moment.lyricSection.index, row);
    _itemScrollToRow(row);
    logger.log(_logManualPlayScrollAnimation, 'manualPlay sectionRequest: index: $_lyricSectionNotifier');

    //  remote scroll for followers
    if (_songUpdateService.isLeader) {
      switch (_songUpdateState) {
        case SongUpdateState.playing:
          break;
        default:
          _leaderSongUpdate(momentNumber);
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
    _setIndexRow(lyricSectionIndex, _lyricsTable.lyricSectionIndexToRow(lyricSectionIndex));
    logger.log(_logManualPlayScrollAnimation,
        'manualPlay sectionRequest: index: $lyricSectionIndex, row: ${_lyricsTable.lyricSectionIndexToRow(lyricSectionIndex)}');

    //  remote scroll for followers
    if (_songUpdateService.isLeader) {
      switch (_songUpdateState) {
        case SongUpdateState.playing:
          break;
        default:
          {
            var lyricSection = _song.lyricSections[lyricSectionIndex];
            _leaderSongUpdate(_song.firstMomentInLyricSection(lyricSection).momentNumber);
          }
          break;
      }
    }
  }

  //  only send updates when required
  _setIndexRow(final int index, final int row) {
    switch (AppOptions().playerScrollHighlight) {
      case PlayerScrollHighlight.off:
        break;
      case PlayerScrollHighlight.chordRow:
        _lyricSectionNotifier.setIndexRow(index, row);
        break;
      case PlayerScrollHighlight.measure:
        break;
    }
  }

  //  only send updates when required
  _setPlayMomentNotifier(
      final SongUpdateState songUpdateState, final int playMomentNumber, final SongMoment? songMoment) {
    List<GridCoordinate> songMomentToGridCoordinate = _song.songMomentToGridCoordinate;
    if (songMomentToGridCoordinate.isNotEmpty) {
      _playMomentNotifier.playMoment = PlayMoment(
          songUpdateState, playMomentNumber, songMoment, songMomentToGridCoordinate[songMoment?.momentNumber ?? 0].row);
    }
  }

  /// send a leader song update to the followers
  void _leaderSongUpdate(int momentNumber) {
    logger.log(_logLeaderSongUpdate, 'leaderSongUpdate( $momentNumber ), isLeader: ${_songUpdateService.isLeader}');

    if (!_songUpdateService.isLeader) {
      _lastSongUpdateSent = null;
      return;
    }

    //  don't send the update unless we have to
    if (_lastSongUpdateSent != null) {
      if (_lastSongUpdateSent!.song == widget._song &&
          _lastSongUpdateSent!.momentNumber == momentNumber &&
          _lastSongUpdateSent!.state == _songUpdateState &&
          _lastSongUpdateSent!.currentKey == _selectedSongKey) {
        return;
      }
    }

    var update = SongUpdate.createSongUpdate(widget._song.copySong());
    _lastSongUpdateSent = update;
    update.currentKey = _selectedSongKey;
    playerSelectedSongKey = _selectedSongKey;
    update.currentBeatsPerMinute = playerSelectedBpm ?? update.song.beatsPerMinute;
    update.momentNumber = momentNumber;
    update.user = _appOptions.user;
    update.singer = playerSinger ?? 'unknown';
    update.state = _songUpdateState;
    update.beatsPerMeasure = widget._song.beatsPerBar;
    _songUpdateService.issueSongUpdate(update);

    logger.log(
        _logLeaderFollower,
        'leaderSongUpdate: momentNumber: $momentNumber'
        ', state: $_songUpdateState');
  }

  // IconData get playStopIcon => songUpdateState.isPlaying ? Icons.stop : Icons.play_arrow;

  _performPlay() {
    logger.log(_logMode, 'manualPlay:');
    switch (_songUpdateState) {
      case SongUpdateState.pause:
        if (!_songUpdateService.isFollowing) {
          _songMaster.resume();
        }
        break;
      default:
        _songUpdateState = SongUpdateState.playing;
        _lastRowIndex = -1;
        _setSelectedSongMoment(_song.songMoments.first);

        if (!_songUpdateService.isFollowing) {
          _setPlayMomentNotifier(SongUpdateState.playing, _songMaster.momentNumber ?? 0, _song.songMoments.first);
          _songMaster.playSong(widget._song, drumParts: _drumParts, bpm: playerSelectedBpm ?? _song.beatsPerMinute);
        }
        break;
    }
  }

  _performPlayHold() {
    logger.log(_logMode, 'playHold:');
    _songUpdateState = SongUpdateState.playHold;
    _songMaster.hold();
    logger.log(_logMode, '_performPlayHold(): playing to hold');
  }

  _performHoldContinue() {
    logger.log(_logMode, 'autoPlay: holdContinue');
    switch (_songUpdateState) {
      case SongUpdateState.pause:
      case SongUpdateState.playHold:
        if (!_songUpdateService.isFollowing) {
          _songMaster.resume();
        }
        break;
      default:
        break;
    }
  }

  _setStatePlay() {
    setState(() {
      _scrollToLyricSection(0); //  always start manual play from the beginning
      _playDrums();
      _performPlay();
    });
  }

  /// Workaround to avoid calling setState() outside of the framework classes
  void _setPlayState() {
    if (_songUpdate != null && _song.songMoments.isNotEmpty) {
      var update = _songUpdate!;
      int momentNumber = Util.indexLimit(update.momentNumber, _song.songMoments);
      assert(momentNumber >= 0);
      assert(momentNumber < _song.songMoments.length);
      var songMoment = _song.songMoments[momentNumber];

      //  map state to mode   fixme: should reconcile the enums
      SongUpdateState newSongUpdateState = SongUpdateState.idle;
      switch (update.state) {
        case SongUpdateState.playing:
          if (!_songUpdateState.isPlaying) {
            _setPlayMode();
          }
          newSongUpdateState = SongUpdateState.playing;
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
          newSongUpdateState = SongUpdateState.idle;
          _scrollToLyricSection(songMoment.lyricSection.index);
          break;
      }
      update.state = newSongUpdateState;
      _setPlayMomentNotifier(update.state, update.momentNumber, songMoment);

      logger.log(
          _logLeaderFollower,
          'setPlayState: post state: ${update.state}, songPlayMode: ${_songUpdateState.name}'
          ', _countIn: $_countIn'
          ', moment: ${update.momentNumber}');
    }
  }

  void _setPlayMode() {
    _songUpdateState = SongUpdateState.playing;
  }

  void _performStop() {
    setState(() {
      _simpleStop();
    });
  }

  void _simpleStop() {
    _songUpdateState = SongUpdateState.idle;
    _songMaster.stop();
    _playMomentNotifier.playMoment = null;
    logger.log(_logMode, 'simpleStop()');
    logger.log(_logScroll, 'simpleStop():');
  }

  void _performPause() {
    setState(() {
      switch (_songUpdateState) {
        case SongUpdateState.playing:
          _songUpdateState = SongUpdateState.pause;
          _songMaster.pause();
          logger.log(_logMode, 'performPause(): playing to pause');
          break;
        default:
          break;
      }
    });
  }

  /// Adjust the displayed
  _setSelectedSongKey(music_key.Key key) {
    logger.log(_logMusicKey, 'key: $key');

    //  add any offset
    music_key.Key newDisplayKey = key.nextKeyByHalfSteps(_displayKeyOffset);
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
    _forceTableRedisplay();
    _leaderSongUpdate(_lastSongUpdateSent?.momentNumber ?? 0);
  }

  String _titleAnchor() {
    //  remove the old "cover by" in title or artist
    //  otherwise there are poor matches on youtube
    String s = '${widget._song.title} ${widget._song.artist}'
            ' ${widget._song.coverArtist}'
        .replaceAll('cover by', '');
    return _anchorUrlStart + Uri.encodeFull(s);
  }

  String _artistAnchor() {
    return _anchorUrlStart + Uri.encodeFull(widget._song.artist);
  }

  void _navigateToEdit(final BuildContext context, Song song) async {
    _playerIsOnTop = false;
    _cancelIdleTimer();
    Navigator.pushNamed(context, Edit.routeName).then((value) {
      //  return to list if song was removed
      if (!app.allSongs.contains(_song)) {
        if (mounted) Navigator.pop(context);
        return;
      }
      _playerIsOnTop = true;
      _assignNewSong(app.selectedSong);
      _setIndexRow(0, 0);
      _forceTableRedisplay();
      _resetIdleTimer();
    });
  }

  Future<void> _navigateToDrums(BuildContext context, Song song) {
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
      _setIndexRow(0, 0);
      _forceTableRedisplay();
      _resetIdleTimer();
    });
  }

  void _forceTableRedisplay() {
    logger.log(_logBuild, 'forceTableRedisplay():');
    setState(() {
      _listView = null;
    });
  }

  void _adjustDisplay() {
    logger.log(_logBuild, 'adjustDisplay():');
    _forceTableRedisplay();
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

  // bool _almostEqual(double d1, double d2, double tolerance) {
  //   return (d1 - d2).abs() <= tolerance;
  // }

  void _setSelectedSongMoment(SongMoment? songMoment) {
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
      _setPlayMomentNotifier(_songUpdateState, songMoment.momentNumber, songMoment);
      _scrollToLyricSection(songMoment.lyricSection.index);
      //
      // if (songUpdateService.isLeader) {
      //   leaderSongUpdate(_playMomentNotifier.playMoment?.songMoment?.momentNumber ?? 0); //  fixme
      // }
    }
  }

  bool _capoIsPossible() {
    return !_appOptions.isSinger && !(_songUpdateService.isConnected && _songUpdateService.isLeader);
  }

  Future<void> _settingsPopup() async {
    var popupStyle = _headerTextStyle.copyWith(fontSize: (_headerTextStyle.fontSize ?? app.screenInfo.fontSize));
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
                            // AppTooltip(
                            //   message: 'Select the display style for the song.',
                            //   child: Text(
                            //     'Display style: ',
                            //     style: boldStyle,
                            //   ),
                            // ),
                            //       //  pro player
                            //       AppWrap(children: [
                            //         Radio<UserDisplayStyle>(
                            //           value: UserDisplayStyle.proPlayer,
                            //           groupValue: _appOptions.userDisplayStyle,
                            //           onChanged: (value) {
                            //             setState(() {
                            //               if (value != null) {
                            //                 _appOptions.userDisplayStyle = value;
                            //                 _adjustDisplay();
                            //               }
                            //             });
                            //           },
                            //         ),
                            //         AppTooltip(
                            //           message: 'Display the song using the professional player style.\n'
                            //               'This condenses the song chords to a minimum presentation without lyrics.',
                            //           child: appTextButton(
                            //             'Pro',
                            //             appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                            //             value: UserDisplayStyle.proPlayer,
                            //             onPressed: () {
                            //               setState(() {
                            //                 _appOptions.userDisplayStyle = UserDisplayStyle.proPlayer;
                            //                 _adjustDisplay();
                            //               });
                            //             },
                            //             style: popupStyle,
                            //           ),
                            //         ),
                            //       ]),
                            //       //  player
                            //       AppWrap(children: [
                            //         Radio<UserDisplayStyle>(
                            //           value: UserDisplayStyle.player,
                            //           groupValue: _appOptions.userDisplayStyle,
                            //           onChanged: (value) {
                            //             setState(() {
                            //               if (value != null) {
                            //                 _appOptions.userDisplayStyle = value;
                            //                 _adjustDisplay();
                            //               }
                            //             });
                            //           },
                            //         ),
                            //         AppTooltip(
                            //           message: 'Display the song using the player style.\n'
                            //               'This favors the chords over the lyrics,\n'
                            //               'to the point that the lyrics maybe clipped.',
                            //           child: appTextButton(
                            //             'Player',
                            //             appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                            //             value: UserDisplayStyle.player,
                            //             onPressed: () {
                            //               setState(() {
                            //                 _appOptions.userDisplayStyle = UserDisplayStyle.player;
                            //                 _adjustDisplay();
                            //               });
                            //             },
                            //             style: popupStyle,
                            //           ),
                            //         ),
                            //       ]),
                            // //  both
                            // AppWrap(children: [
                            //   Radio<UserDisplayStyle>(
                            //     value: UserDisplayStyle.both,
                            //     groupValue: _appOptions.userDisplayStyle,
                            //     onChanged: (value) {
                            //       setState(() {
                            //         if (value != null) {
                            //           _appOptions.userDisplayStyle = value;
                            //           _adjustDisplay();
                            //         }
                            //       });
                            //     },
                            //   ),
                            //   AppTooltip(
                            //     message: 'Display the song showing all chords and lyrics.\n'
                            //         'This is the most typical display mode.',
                            //     child: appTextButton(
                            //       'Both Player and Singer',
                            //       value: UserDisplayStyle.both,
                            //       onPressed: () {
                            //         setState(() {
                            //           _appOptions.userDisplayStyle = UserDisplayStyle.both;
                            //           _adjustDisplay();
                            //         });
                            //       },
                            //       style: popupStyle,
                            //     ),
                            //   ),
                            // ]),
                            //       //  singer
                            //       AppWrap(children: [
                            //         Radio<UserDisplayStyle>(
                            //           value: UserDisplayStyle.singer,
                            //           groupValue: _appOptions.userDisplayStyle,
                            //           onChanged: (value) {
                            //             setState(() {
                            //               if (value != null) {
                            //                 _appOptions.userDisplayStyle = value;
                            //                 _adjustDisplay();
                            //               }
                            //             });
                            //           },
                            //         ),
                            //         AppTooltip(
                            //           message: 'Display the song showing all the lyrics.\n'
                            //               'The display of chords is minimized.',
                            //           child: appTextButton(
                            //             'Singer',
                            //             appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                            //             value: UserDisplayStyle.singer,
                            //             onPressed: () {
                            //               setState(() {
                            //                 _appOptions.userDisplayStyle = UserDisplayStyle.singer;
                            //                 _adjustDisplay();
                            //               });
                            //             },
                            //             style: popupStyle,
                            //           ),
                            //         ),
                            //       ]),
                            //       //  banner
                            //       // AppWrap(children: [
                            //       //   Radio<UserDisplayStyle>(
                            //       //     value: UserDisplayStyle.banner,
                            //       //     groupValue: _appOptions.userDisplayStyle,
                            //       //     onChanged: (value) {
                            //       //       setState(() {
                            //       //         if (value != null) {
                            //       //           _appOptions.userDisplayStyle = value;
                            //       //           adjustDisplay();
                            //       //         }
                            //       //       });
                            //       //     },
                            //       //   ),
                            //       //   AppTooltip(
                            //       //     message: 'Display the song in banner (piano scroll) mode.',
                            //       //     child: appTextButton(
                            //       //       'Banner',
                            //       //       appKeyEnum: AppKeyEnum.optionsUserDisplayStyle,
                            //       //       value: UserDisplayStyle.banner,
                            //       //       onPressed: () {
                            //       //         setState(() {
                            //       //           _appOptions.userDisplayStyle = UserDisplayStyle.banner;
                            //       //           adjustDisplay();
                            //       //         });
                            //       //       },
                            //       //       style: popupStyle,
                            //       //     ),
                            //       //   ),
                            //       // ]),
                            //     ]),
                            //  const AppSpaceViewportWidth(),
                            //  PlayerScrollHighlight
                            AppWrapFullWidth(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: viewportWidth(0.5),
                                children: [
                                  AppTooltip(
                                    message: 'Select the highlight style while auto scrolling in play.',
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
                                            _adjustDisplay();
                                          }
                                        });
                                      },
                                    ),
                                    AppTooltip(
                                      message: 'No play highlight.',
                                      child: appTextButton(
                                        'Off',
                                        value: PlayerScrollHighlight.off,
                                        onPressed: () {
                                          setState(() {
                                            _appOptions.playerScrollHighlight = PlayerScrollHighlight.off;
                                            _adjustDisplay();
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
                                            _adjustDisplay();
                                          }
                                        });
                                      },
                                    ),
                                    AppTooltip(
                                      message: 'Highlight the current row.',
                                      child: appTextButton(
                                        'Row',
                                        value: PlayerScrollHighlight.chordRow,
                                        onPressed: () {
                                          setState(() {
                                            _appOptions.playerScrollHighlight = PlayerScrollHighlight.chordRow;
                                            _adjustDisplay();
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
                                            _adjustDisplay();
                                          }
                                        });
                                      },
                                    ),
                                    AppTooltip(
                                      message: 'Highlight the current measure.',
                                      child: appTextButton(
                                        'Measure',
                                        value: PlayerScrollHighlight.measure,
                                        onPressed: () {
                                          setState(() {
                                            _appOptions.playerScrollHighlight = PlayerScrollHighlight.measure;
                                            _adjustDisplay();
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
                                            value: NashvilleSelection.off,
                                            groupValue: _appOptions.nashvilleSelection,
                                            onPressed: () {
                                              setState(() {
                                                _appOptions.nashvilleSelection = NashvilleSelection.off;
                                                _adjustDisplay();
                                              });
                                            },
                                            style: popupStyle),
                                      ),
                                      AppTooltip(
                                        message: 'Show both the chords and Nashville notation.',
                                        child: AppRadio<NashvilleSelection>(
                                            text: 'both',
                                            value: NashvilleSelection.both,
                                            groupValue: _appOptions.nashvilleSelection,
                                            onPressed: () {
                                              setState(() {
                                                _appOptions.nashvilleSelection = NashvilleSelection.both;
                                                _adjustDisplay();
                                              });
                                            },
                                            style: popupStyle),
                                      ),
                                      AppTooltip(
                                        message: 'Show only the Nashville notation.',
                                        child: AppRadio<NashvilleSelection>(
                                            text: 'only',
                                            value: NashvilleSelection.only,
                                            groupValue: _appOptions.nashvilleSelection,
                                            onPressed: () {
                                              setState(() {
                                                _appOptions.nashvilleSelection = NashvilleSelection.only;
                                                _adjustDisplay();
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
                                        if (!_songUpdateService.isLeader)
                                          AppTooltip(
                                            message: 'For a guitar, show the capo location and\n'
                                                'chords to match the current key.',
                                            child: appTextButton(
                                              'Capo',

                                              value: _isCapo,
                                              style: boldStyle,
                                              onPressed: () {
                                                setState(
                                                  () {
                                                    _isCapo = !_isCapo;
                                                    _setSelectedSongKey(_selectedSongKey);
                                                    _adjustDisplay();
                                                  },
                                                );
                                              },
                                              //softWrap: false,
                                            ),
                                          ),
                                        if (!_songUpdateService.isLeader)
                                          appSwitch(
                                            value: _isCapo,
                                            onChanged: (value) {
                                              setState(() {
                                                _isCapo = !_isCapo;
                                                _setSelectedSongKey(_selectedSongKey);
                                                _adjustDisplay();
                                              });
                                            },
                                          ),
                                        if (_songUpdateService.isLeader)
                                          Text(
                                            'Capo: not available to the leader',
                                            style: popupStyle,
                                          ),
                                      ],
                                    ),
                                ]),
                            if (!_songUpdateService.isFollowing && kIsWeb && !app.screenInfo.isTooNarrow)
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
                            if (!_songUpdateService.isFollowing && kIsWeb && !app.screenInfo.isTooNarrow)
                              AppWrapFullWidth(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: viewportWidth(1),
                                  children: [
                                    AppTooltip(
                                      message: _areDrumsMuted
                                          ? 'Click to unmute and select the drums'
                                          : 'Click to mute the drums',
                                      child: appButton(_areDrumsMuted ? 'Drums are muted' : 'Mute the Drums',
                                          onPressed: () {
                                        setState(() {
                                          _areDrumsMuted = !_areDrumsMuted;
                                          _songMaster.drumsAreMuted = _areDrumsMuted;
                                          // logger.i('drums mute: $_areDrumsMuted');
                                        });
                                      }, backgroundColor: _areDrumsMuted ? Colors.red : null),
                                    ),
                                    const AppSpace(),
                                    if (!_areDrumsMuted)
                                      AppTooltip(
                                        message: 'Select the drums',
                                        child: appIconWithLabelButton(
                                            label: 'Drums',
                                            fontSize: popupStyle.fontSize,
                                            icon: appIcon(
                                              Icons.edit,
                                            ),
                                            onPressed: () {
                                              _navigateToDrums(context, _song).then((value) => setState(() {}));
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
                                      value: false,
                                      groupValue: _appOptions.ninJam,
                                      onPressed: () {
                                        setState(() {
                                          _appOptions.ninJam = false;
                                          _adjustDisplay();
                                        });
                                      },
                                      style: popupStyle),
                                ),
                                AppTooltip(
                                  message: 'Turn on the Ninjam aids',
                                  child: AppRadio<bool>(
                                      text: 'Show NinJam aids',
                                      value: true,
                                      groupValue: _appOptions.ninJam,
                                      onPressed: () {
                                        setState(() {
                                          _appOptions.ninJam = true;
                                          _adjustDisplay();
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
                                  _keyOffsetItems,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        app.displayKeyOffset = value;
                                        _adjustDisplay();
                                      });
                                    }
                                  },
                                  style: popupStyle,
                                  value: app.displayKeyOffset,
                                ),
                              ]),
                            const AppVerticalSpace(space: 35),
                          ],
                        ),
                      ],
                    ));
              }),
              actions: [
                const AppSpace(),
                AppWrapFullWidth(spacing: viewportWidth(1), alignment: WrapAlignment.end, children: [
                  AppTooltip(
                    message: 'Click here or outside of the popup to return to the player screen.',
                    child: appButton('Return', fontSize: popupStyle.fontSize, onPressed: () {
                      Navigator.of(context).pop();
                    }),
                  ),
                ]),
              ],
              actionsAlignment: MainAxisAlignment.start,
              elevation: 24.0,
            ));

    _adjustDisplay();
  }

  void _tempoTap({bool force = false}) {
    //  tap to tempo
    final tempoTap = DateTime.now().microsecondsSinceEpoch;
    double delta = (tempoTap - _lastTempoTap) / Duration.microsecondsPerSecond;
    _lastTempoTap = tempoTap;

    if (delta <= 60 / MusicConstants.minBpm && delta >= 60 / MusicConstants.maxBpm) {
      int bpm = (_tempoRollingAverage ??= RollingAverage(windowSize: 5)).average(60 / delta).round();
      _changeBPM(bpm, force: force);
    } else {
      //  delta too small or too large
      _tempoRollingAverage = null;
      _changeBPM(_song.beatsPerMinute, force: force); //  default to song beats per minute
      logger.log(_logBPM, 'tempoTap(): default: bpm: $playerSelectedBpm');
    }
  }

  _changeBPM(int newBpm, {bool force = false}) {
    newBpm = Util.intLimit(newBpm, MusicConstants.minBpm, MusicConstants.maxBpm);
    if (playerSelectedBpm != newBpm || force) {
      setState(() {
        playerSelectedBpm = newBpm;
        _songMaster.tapTempo(newBpm);
        logger.log(_logBPM, '_changeBPM( $playerSelectedBpm )');
      });
    }
  }

  final List<DropdownMenuItem<int>> _keyOffsetItems = [
    appDropdownMenuItem(value: 0, child: const Text('normal: (no key offset)')),
    appDropdownMenuItem(value: 1, child: const Text('+1   (-11) half steps = scale  ${MusicConstants.flatChar}2')),
    appDropdownMenuItem(
        value: 2, child: const Text('+2   (-10) half steps = scale   2, B${MusicConstants.flatChar} instrument')),
    appDropdownMenuItem(value: 3, child: const Text('+3   (-9)   half steps = scale  ${MusicConstants.flatChar}3')),
    appDropdownMenuItem(value: 4, child: const Text('+4   (-8)   half steps = scale   3')),
    appDropdownMenuItem(value: 5, child: const Text('+5   (-7)   half steps = scale   4, baritone guitar')),
    appDropdownMenuItem(value: 6, child: const Text('+6   (-6)   half steps = scale  ${MusicConstants.flatChar}5')),
    appDropdownMenuItem(value: 7, child: const Text('+7   (-5)   half steps = scale   5, F instrument')),
    appDropdownMenuItem(value: 8, child: const Text('+8   (-4)   half steps = scale  ${MusicConstants.flatChar}6')),
    appDropdownMenuItem(
        value: 9, child: const Text('+9   (-3)   half steps = scale   6, E${MusicConstants.flatChar} instrument')),
    appDropdownMenuItem(value: 10, child: const Text('+10 (-2)   half steps = scale  ${MusicConstants.flatChar}7')),
    appDropdownMenuItem(value: 11, child: const Text('+11 (-1)   half steps = scale   7')),
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

  DrumParts? get _defaultDrumParts => _drumPartsList.findByName(DrumPartsList.defaultName);

  static const String _anchorUrlStart = 'https://www.youtube.com/results?search_query=';

  SongUpdateState _songUpdateState = SongUpdateState.idle;

  late final FocusNode _rawKeyboardListenerFocusNode;

  music_key.Key _displaySongKey = music_key.Key.C;
  int _displayKeyOffset = 0;

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

  Widget? _listView;
  final ScrollController _listScrollController = ScrollController();
  bool _isAnimated = false;
  int _lastRowIndex = 0;
  double minScrollOffset = 0;

  Size? _lastSize;

  final TextEditingController _bpmTextEditingController = TextEditingController();

  // static const _centerSelections = true;
  static const _scrollAlignment = 0.35;

  double boxMarker = 0;
  double _fontSize = 14;

  var _headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);
  List<DropdownMenuItem<music_key.Key>> _keyDropDownMenuList = [];

  Timer? _idleTimer;

  final _drumPartsList = DrumPartsList();

  DrumParts? _drumParts;

  late AppWidgetHelper _appWidgetHelper;

  static final _appOptions = AppOptions();
  final AppSongUpdateService _songUpdateService = AppSongUpdateService();
}

/// Display data on the song while in auto or manual play mode
class _DataReminderWidget extends StatefulWidget {
  const _DataReminderWidget(this._songIsInPlayOrPaused, this._songMaster);

  @override
  State<StatefulWidget> createState() {
    return _DataReminderState();
  }

  final bool _songIsInPlayOrPaused;
  final SongMaster _songMaster;
}

class _DataReminderState extends State<_DataReminderWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PlayMomentNotifier>(builder: (context, playMomentNotifier, child) {
      int? bpm = playerSelectedBpm;
      bpm ??= (widget._songIsInPlayOrPaused ? widget._songMaster.bpm : null);
      bpm ??= _song.beatsPerMinute;
      logger.log(_logDataReminderState,
          '_DataReminderState.build(): ${widget._songIsInPlayOrPaused}, bpm: $bpm, playerSelectedBpm: $playerSelectedBpm');

      if (widget._songIsInPlayOrPaused) {
        return Text(
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
        );
      } else {
        return NullWidget();
      }
    });
  }
}

class GamePad {
  factory GamePad() {
    return _singleton;
  }

  addListener(VoidCallback forwardCallback) {
    this.forwardCallback = forwardCallback;
    _subscribe();
  }

  cancel() {
    if (_subscription != null) {
      _subscription!.cancel();
    }
  }

  void _onData(GamepadEvent e) {
    //  closures only
    if (e.value == 1.0) {
      switch (e.key) {
        case '0':
          forwardCallback?.call();
          break;
        case '1':
          logger.i('GamepadEvent backward not implemented: $e');
          break;
        default:
          logger.i('Gamepad bad event: $e');
          break;
      }
    }
  }

  //  private constructor
  GamePad._internal() {
    _subscribe();
  }

  void _subscribe() {
    cancel(); //  safety

    if (kIsWeb) {
      return;
    }
    if (Platform.isLinux || Platform.isMacOS) {
      _subscription = Gamepads.events.listen(_onData);
    }
  }

  VoidCallback? forwardCallback;
  static final GamePad _singleton = GamePad._internal();
  StreamSubscription<GamepadEvent>? _subscription;
}
