import 'dart:async';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/screens/tempoNotifier.dart';
import 'package:bsteele_music_flutter/songMaster.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/song_update_service.dart';
import 'package:bsteele_music_flutter/util/textWidth.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/grid_coordinate.dart';
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

import '../app/app.dart';
import '../app/appOptions.dart';

//  diagnostic logging enables
const Level _logBuild = Level.debug;

/// Route identifier for this screen.
final leaderPageRoute = MaterialPageRoute(builder: (BuildContext context) => Leader(song: App().selectedSong));

/// An observer used to respond to a song update server request.
final RouteObserver<PageRoute> leaderRouteObserver = RouteObserver<PageRoute>();

SongUpdate? _songUpdate;

//  package level variables
Song _song = Song.theEmptySong;

bool _isCapo = false; //  package level for persistence across player invocations
int _capoLocation = 0; //  fret number of the cap location
bool _showCapo = true; //  package level for all classes in the package

bool _areDrumsMuted = true;

final _playMomentNotifier = PlayMomentNotifier();
final _songMasterNotifier = SongMasterNotifier();
final _lyricSectionNotifier = LyricSectionNotifier();

music_key.Key _selectedSongKey = music_key.Key.C;

/// Display the song moments in sequential order.
/// Typically the chords will be grouped in lines.
// ignore: must_be_immutable
class Leader extends StatefulWidget {
  Leader({this.song, super.key, music_key.Key? musicKey, int? bpm, String? singer}) {
    playerSelectedSongKey = musicKey; //  to be read later at initialization
    playerSelectedBpm = bpm ?? _song.beatsPerMinute;
    playerSinger = singer;
  }

  @override
  State<Leader> createState() => _LeaderState();

  Song? song; //  fixme: not const due to song updates!

  static const String routeName = 'leader';
}

class _LeaderState extends State<Leader> with RouteAware, WidgetsBindingObserver {
  _LeaderState() {
    //  show the update service status
    _songUpdateService.addListener(_songUpdateServiceListener);

    //  show song master play updates
    _songMaster.addListener(_songMasterListener);

    _rawKeyboardListenerFocusNode = FocusNode();

    _songUpdateState = .idle;

    tempoNotifier.addListener(_tempoNotifierListener);
  }

  @override
  initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _displayKeyOffset = app.displayKeyOffset;
    _assignNewSong(widget.song ?? Song.theEmptySong);
    _setSelectedSongKey(playerSelectedSongKey ?? _song.key);
    playerSelectedBpm = playerSelectedBpm ?? _song.beatsPerMinute;
    _playMomentNotifier.playMoment = null;

    WidgetsBinding.instance.scheduleWarmUpFrame();

    app.clearMessage();
  }

  _assignNewSong(final Song song) {
    widget.song = song;
    _song = song;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    leaderRouteObserver.subscribe(this, leaderPageRoute);
  }

  @override
  void dispose() {
    logger.d('player: dispose()');
    _cancelIdleTimer();

    _songUpdate = null;
    _songUpdateService.removeListener(_songUpdateServiceListener);
    _songMaster.removeListener(_songMasterListener);
    tempoNotifier.removeListener(_tempoNotifierListener);
    leaderRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _bpmTextEditingController.dispose();
    _rawKeyboardListenerFocusNode.dispose();

    super.dispose();
  }

  //  update the song update service status
  void _songUpdateServiceListener() {
    setState(() {});
  }

  void _songMasterListener() {
    //  follow the song master moment number
    switch (_songUpdateState) {
      case .none:
      case .idle:
      case .drumTempo:
        if (_songMaster.songUpdateState.isPlaying) {
          //  follow the song master's play mode
          setState(() {
            _songUpdateState = _songMaster.songUpdateState;
            _clearCountIn();
          });
        }
        break;
      case .playing:
      case .playHold:
      case .pause:
        //  find the current measure
        if (_songMaster.momentNumber != null) {
          _setPlayMomentNotifier(
            _songMaster.songUpdateState,
            _songMaster.momentNumber!,
            _song.getSongMoment(_songMaster.momentNumber!),
          );
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
    if (_songUpdateService
            .isLeader //  followers don't care
            &&
        tempoNotifier.songTempoUpdate?.songId ==
            _song
                .songId //  assure the response is correct
                &&
        tempoNotifier.songTempoUpdate?.currentBeatsPerMinute != null) {
      setState(() {
        int bpm = tempoNotifier.songTempoUpdate!.currentBeatsPerMinute;
        playerSelectedBpm = bpm;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _resetIdleTimer();
    app.screenInfo.refresh(context);
    _appWidgetHelper = AppWidgetHelper(context);
    _song = widget.song ?? Song.theEmptySong; //  default only

    logger.log(_logBuild, 'player build: ModalRoute: ${ModalRoute.of(context)?.settings.name}');

    logger.log(
      _logBuild,
      'player build: $_song, ${_song.songId}, playMomentNumber: ${_playMomentNotifier.playMoment?.playMomentNumber}'
      ', songPlayMode: ${_songUpdateState.name}'
      ', $_songUpdate',
    );

    //  deal with song updates
    if (_songUpdate != null) {
      if (!_song.songBaseSameContent(_songUpdate!.song) || _displayKeyOffset != app.displayKeyOffset) {
        _assignNewSong(_songUpdate!.song);
        _setPlayMomentNotifier(_songUpdate!.state, _songUpdate?.songMoment?.momentNumber ?? 0, _songUpdate!.songMoment);
        _selectLyricSection(
          _songUpdate
                  ?.songMoment
                  ?.lyricSection
                  .index //
                  ??
              _lyricSectionNotifier.lyricSectionIndex,
        ); //  safer to stay on the current index
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
        String valueString = value.toMarkup().padRight(
          2,
        ); //  fixme: required by drop down list font bug!  (see the "on ..." below)
        String offsetString = '';
        if (relativeOffset > 0) {
          offsetString = '+${relativeOffset.toString()}';
        } else if (relativeOffset < 0) {
          offsetString = relativeOffset.toString();
        }

        _keyDropDownMenuList.add(
          appDropdownMenuItem<music_key.Key>(
            value: value,
            child: AppWrap(
              children: [
                SizedBox(
                  width: 3 * chordsTextWidth, //  max width of chars expected
                  child: Text(valueString, style: _headerTextStyle, softWrap: false, textAlign: TextAlign.left),
                ),
                SizedBox(
                  width: 2 * chordsTextWidth, //  max width of chars expected
                  child: Text(offsetString, style: _headerTextStyle, softWrap: false, textAlign: TextAlign.right),
                ),
                //  show the first note if it's not the same as the key
                if (app.isScreenBig && firstScaleNote != null)
                  SizedBox(
                    width: onStringWidth + 4 * chordsTextWidth,
                    //  max width of chars expected
                    child: Text(
                      '$onString${scaleNoteByAccidentalExpressionChoice(firstScaleNote.transpose(value, relativeOffset), appOptions.accidentalExpressionChoice, key: _displaySongKey).toMarkup()})',
                      style: _headerTextStyle,
                      softWrap: false,
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }

    _showCapo = _capoIsPossible() && _isCapo;

    var theme = Theme.of(context);
    var appBarTextStyle = generateAppBarLinkTextStyle();

    if (appOptions.ninJam) {
      _ninJam = NinJam(_song, key: _displaySongKey, keyOffset: _displaySongKey.getHalfStep() - _song.key.getHalfStep());
    }

    final backBar = _appWidgetHelper.backBar(
      titleWidget: Row(children: [Text(_song.toString(), style: appBarTextStyle)]),
      actions: [
        //  fix: on small screens, only the title flexes
        Text(' by  ${_song.artist}', style: appBarTextStyle, softWrap: false),
        if (playerSinger != null)
          Flexible(child: Text(', sung by $playerSinger', style: appBarTextStyle, softWrap: false)),
        const AppSpace(),
      ],
    );

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
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              boxMarker = constraints.maxHeight * _scrollAlignment;

              return Stack(
                children: <Widget>[
                  //  smooth background
                  if (appOptions.userDisplayStyle != UserDisplayStyle.highContrast)
                    Container(
                      constraints: constraints,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: .topCenter,
                          end: .bottomCenter,
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
                  if (kDebugMode || appOptions.playerScrollHighlight == PlayerScrollHighlight.off)
                    Column(
                      children: [
                        //  offset the marker
                        Container(color: Colors.cyanAccent, constraints: BoxConstraints.tight(Size(0, boxMarker))),
                        Container(
                          constraints: BoxConstraints.tight(
                            Size(
                              appOptions.playerScrollHighlight == PlayerScrollHighlight.off
                                  ? 16
                                  : constraints.maxWidth, // for testing only
                              4,
                            ),
                          ),
                          decoration: const BoxDecoration(color: Colors.black87),
                        ),
                      ],
                    ),

                  Column(children: [_songControls()]),

                  _songPlayTally(),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _songControls() {
    return Consumer<SongMasterNotifier>(
      builder: (context, songMasterNotifier, child) {
        var songUpdateState = songMasterNotifier.songMaster?.songUpdateState ?? .idle;
        switch (songUpdateState) {
          case .playing:
          case .playHold:
          case .pause:
            return NullWidget();
          default:
            return Padding(
              padding: const EdgeInsets.all(5.0),
              child: Column(
                mainAxisAlignment: .start,
                children: <Widget>[
                  //  control buttons
                  AppWrapFullWidth(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      if (utilWorkaround.fullscreenEnabled && !utilWorkaround.isFullScreen)
                        appButton(
                          'Fullscreen',
                          onPressed: () {
                            utilWorkaround.requestFullscreen();
                          },
                        ),

                      if (app.message.isNotEmpty) app.messageTextWidget(),

                      if (songUpdateState.isPlayingOrPausedOrHold)
                        //  repeat notifications
                        Consumer<SongMasterNotifier>(
                          builder: (context, songMasterNotifier, child) {
                            var style = generateAppTextStyle(
                              fontSize: app.screenInfo.fontSize,
                              decoration: TextDecoration.none,
                              color: Colors.redAccent,
                              backgroundColor: const Color(0xffeff4fd), //  blended color
                            );
                            switch (songMasterNotifier.songMaster?.repeatSection ?? 0) {
                              case 1:
                                return Text('Repeat this section', style: style);
                              case 2:
                                return Text('Repeat the prior section', style: style);
                              default:
                                return NullWidget();
                            }
                          },
                        ),
                    ],
                  ),

                  if (songUpdateState == .idle || songUpdateState == .drumTempo)
                    AppRow(
                      mainAxisAlignment: .spaceAround,
                      children: [
                        //  key change
                        AppWrap(
                          children: [
                            if (!_songUpdateService.isFollowing)
                              //  key change
                              AppWrap(
                                children: [
                                  AppTooltip(
                                    message: 'Transcribe the song to the selected key.',
                                    child: Text('Key: ', style: _headerTextStyle, softWrap: false),
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
                                        icon: appIcon(Icons.arrow_upward),
                                        onPressed: () {
                                          setState(() {
                                            _setSelectedSongKey(_selectedSongKey.nextKeyByHalfStep());
                                          });
                                        },
                                      ),
                                    ),
                                  if (app.isScreenBig) const AppSpace(space: 5),
                                  if (app.isScreenBig)
                                    AppTooltip(
                                      message: 'Move the key one half step down.',
                                      child: appIconWithLabelButton(
                                        icon: appIcon(Icons.arrow_downward),
                                        onPressed: () {
                                          setState(() {
                                            _setSelectedSongKey(_selectedSongKey.previousKeyByHalfStep());
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            if (_songUpdateService.isFollowing)
                              AppTooltip(
                                message:
                                    'When following the leader, the leader will select the key for you.\n'
                                    'To correct this from the main screen: menu (hamburger), Options, Hosts: None',
                                child: Text('Key: $_selectedSongKey', style: _headerTextStyle, softWrap: false),
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
                          AppWrap(children: [Text('BPM:')]),

                        AppTooltip(
                          message:
                              'Beats are a property of the song.\n'
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
                            message:
                                'Control the leader/follower mode from the main menu:\n'
                                'main screen: menu (hamburger), Options, Hosts',
                            child: Text(
                              _songUpdateService.isConnected
                                  ? (_songUpdateService.isLeader
                                      ? 'leading'
                                      : 'following ${_songUpdateService.leaderName}')
                                  : (_songUpdateService.isIdle ? '' : 'lost ${_songUpdateService.host}!'),
                              style:
                                  !_songUpdateService.isConnected && !_songUpdateService.isIdle
                                      ? _headerTextStyle.copyWith(color: Colors.red)
                                      : _headerTextStyle,
                            ),
                          ),
                      ],
                    ),

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
                      appOptions.ninJam &&
                      _ninJam.isNinJamReady &&
                      songUpdateState == .idle)
                    AppWrapFullWidth(
                      spacing: 20,
                      children: [
                        const AppSpace(),
                        AppWrap(
                          spacing: 10 * _fontSize,
                          children: [
                            Text(
                              'Ninjam: BPM: ${playerSelectedBpm ?? _song.beatsPerMinute.toString()}',
                              style: _headerTextStyle,
                              softWrap: false,
                            ),
                            appIconWithLabelButton(
                              icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: '/bpm ${(playerSelectedBpm ?? _song.beatsPerMinute).toString()}'),
                                );
                              },
                            ),
                          ],
                        ),
                        AppWrap(
                          spacing: 10 * _fontSize,
                          children: [
                            Text('Cycle: ${_ninJam.beatsPerInterval}', style: _headerTextStyle, softWrap: false),
                            appIconWithLabelButton(
                              icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: '/bpi ${_ninJam.beatsPerInterval}'));
                              },
                            ),
                          ],
                        ),
                        AppWrap(
                          spacing: 10 * _fontSize,
                          children: [
                            Text('Chords: ${_ninJam.toMarkup()}', style: _headerTextStyle, softWrap: false),
                            appIconWithLabelButton(
                              icon: appIcon(Icons.content_copy_sharp, size: app.screenInfo.fontSize),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _ninJam.toMarkup()));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            );
        }
      },
    );
  }

  Widget _songPlayTally() {
    return Consumer<SongMasterNotifier>(
      builder: (context, songMasterNotifier, child) {
        var songUpdateState = songMasterNotifier.songMaster?.songUpdateState ?? .idle;
        switch (songUpdateState) {
          case .none:
          case .idle:
          case .drumTempo:
            return NullWidget();
          default:
            return Container(
              padding: const EdgeInsets.all(5.0),
              color: (Color.lerp(App.measureContainerBackgroundColor, Colors.white, 0.85) ?? Colors.white).withAlpha(
                128 + 64 + 32 + 8,
              ),
              child: AppWrapFullWidth(
                alignment: WrapAlignment.spaceBetween,
                spacing: _fontSize,
                children: [
                  if (utilWorkaround.fullscreenEnabled && !utilWorkaround.isFullScreen)
                    appButton(
                      'Fullscreen',
                      onPressed: () {
                        utilWorkaround.requestFullscreen();
                      },
                    ),
                  Text('Key: $_selectedSongKey', style: _headerTextStyle, softWrap: false),
                  Text('BPM: ${playerSelectedBpm ?? _song.beatsPerMinute}', style: _headerTextStyle, softWrap: false),
                  Text('Beats: ${_song.timeSignature.beatsPerBar}', style: _headerTextStyle, softWrap: false),
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
                      style:
                          !_songUpdateService.isConnected && !_songUpdateService.isIdle
                              ? _headerTextStyle.copyWith(color: Colors.red)
                              : _headerTextStyle,
                    ),

                  if (app.isScreenBig && _showCapo && _capoLocation > 0)
                    Text('Capo: $_capoLocation', style: _headerTextStyle, softWrap: false),
                  //  last of the wrap
                  Text('  ', style: _headerTextStyle, softWrap: false),
                ],
              ),
            );
        }
      },
    );
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
    // _countIn = countIn;
    logger.t('countIn: $countIn');
    if (countIn > 0 && countIn < countInMax) {
      // _countInWidget = Container(
      //   margin: const EdgeInsets.all(12.0),
      //   padding: const EdgeInsets.symmetric(horizontal: _padding),
      //   color: App.defaultBackgroundColor,
      //   child: Text(
      //     'Count in: $countIn',
      //     style: _lyricsTextStyle,
      //   ),
      // );
    } else {
      _countInWidget = NullWidget();
    }
    logger.t('_countInWidget.runtimeType: ${_countInWidget.runtimeType}');
  }

  _selectLyricSection(int lyricSectionIndex) {
    if (_song.lyricSections.isEmpty) {
      return; //  safety
    }
    lyricSectionIndex = Util.indexLimit(lyricSectionIndex, _song.lyricSections); //  safety
  }

  //  only send updates when required
  _setPlayMomentNotifier(
    final SongUpdateState songUpdateState,
    final int playMomentNumber,
    final SongMoment? songMoment,
  ) {
    List<GridCoordinate> songMomentToGridCoordinate = _song.songMomentToGridCoordinate;
    if (songMomentToGridCoordinate.isNotEmpty) {
      _playMomentNotifier.playMoment = PlayMoment(
        songUpdateState,
        playMomentNumber,
        songMoment,
      );
    }
  }

  /// Adjust the displayed
  _setSelectedSongKey(music_key.Key key) {
    //  add any offset
    music_key.Key newDisplayKey = key.nextKeyByHalfSteps(_displayKeyOffset);

    //  deal with capo
    if (_showCapo) {
      _capoLocation = newDisplayKey.capoLocation;
      newDisplayKey = newDisplayKey.capoKey;
    }

    //  don't process unless there was a change
    if (_selectedSongKey == key && _displaySongKey == newDisplayKey) {
      return; //  no change required
    }
    _selectedSongKey = key;
    playerSelectedSongKey = key;
    _displaySongKey = newDisplayKey;
  }

  // bool _almostEqual(double d1, double d2, double tolerance) {
  //   return (d1 - d2).abs() <= tolerance;
  // }

  bool _capoIsPossible() {
    return !appOptions.isSinger && !(_songUpdateService.isConnected && _songUpdateService.isLeader);
  }

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

  SongUpdateState _songUpdateState = .idle;

  late final FocusNode _rawKeyboardListenerFocusNode;

  music_key.Key _displaySongKey = music_key.Key.C;
  int _displayKeyOffset = 0;

  NinJam _ninJam = NinJam.empty();

  final SongMaster _songMaster = SongMaster();

  // int _countIn = 0;
  Widget _countInWidget = NullWidget();

  final TextEditingController _bpmTextEditingController = TextEditingController();

  static const _scrollAlignment = 0.2;

  double boxMarker = 0;
  double _fontSize = 14;

  var _headerTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);
  List<DropdownMenuItem<music_key.Key>> _keyDropDownMenuList = [];

  Timer? _idleTimer;

  late AppWidgetHelper _appWidgetHelper;
  
  final AppSongUpdateService _songUpdateService = AppSongUpdateService();
}
