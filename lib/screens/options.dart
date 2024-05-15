import 'dart:async';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/bass.dart';
import 'package:bsteele_music_lib/songs/chord.dart';
import 'package:bsteele_music_lib/songs/chord_anticipation_or_delay.dart';
import 'package:bsteele_music_lib/songs/chord_descriptor.dart';
import 'package:bsteele_music_lib/songs/pitch.dart';
import 'package:bsteele_music_lib/songs/scale_chord.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/audio/app_audio_player.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

//  diagnostic logging enables
const Level _optionLogAudio = Level.debug;
const Level _logBuild = Level.debug;
const Level _logUserNameEntry = Level.debug;

/// A screen to display controls for the user to manage some of the app's options.
class Options extends StatefulWidget {
  const Options({super.key});

  @override
  OptionsState createState() => OptionsState();

  static const String routeName = 'options';
}

class OptionsState extends State<Options> {
  @override
  initState() {
    super.initState();

    _userTextEditingController.text = _appOptions.user;
    _userTextEditingController.addListener(() {
      if (_userTextEditingController.text.isNotEmpty) {
        _appOptions.user = _userTextEditingController.text;
      }
    });

    _websocketHostEditingController.text =
        _appOptions.websocketHost == AppOptions.idleHost ? '' : _appOptions.websocketHost;

    _songUpdateService.addListener(_songUpdateServiceCallback);

    appLogMessage('options: service host: ${_songUpdateService.host}'
        ', _appOptions.websocketHost: ${_appOptions.websocketHost}');
  }

  void _songUpdateServiceCallback() {
    setState(() {
      _ipAddress = _songUpdateService.ipAddress;
    });
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    app.screenInfo.refresh(context);

    logger.log(_logBuild, 'options build: ${_songUpdateService.isConnected}');
    var style = generateAppTextStyle();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appWidgetHelper.backBar(title: 'bsteeleMusicApp Options'),
      body: DefaultTextStyle(
        //  fixme: necessary?
        style: style,
        child: SingleChildScrollView(
          //  for phones when horizontal
          child: Container(
            padding: const EdgeInsets.all(12.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  if (app.fullscreenEnabled)
                    Row(
                      children: <Widget>[
                        appButton('Enter fullscreen', appKeyEnum: AppKeyEnum.optionsFullScreen, onPressed: () {
                          app.requestFullscreen();
                        }),
                      ],
                    ),

                  const AppSpace(),
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                          child: const Text(
                            'User name: ',
                          ),
                        ),
                        AppTextField(
                          appKeyEnum: AppKeyEnum.optionsUserName,
                          controller: _userTextEditingController,
                          hintText: 'Enter your user name.',
                          width: (style.fontSize ?? appDefaultFontSize) * 40,
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              logger.log(_logUserNameEntry, 'user name onChanged: $value');
                              setState(() {
                                _appOptions.user = value;
                              });
                            }
                          },
                        ),
                      ]),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(right: 24),
                        child: const Text(
                          'Host IP: ',
                        ),
                      ),
                      SizedBox(
                        width: app.screenInfo.mediaWidth / 3,
                        child: AppTextField(
                          appKeyEnum: AppKeyEnum.optionsWebsocketIP,
                          controller: _websocketHostEditingController,
                          hintText: 'address here',
                          onChanged: (value) {
                            _appOptions.websocketHost = value;
                          },
                        ),
                      ),
                      const AppSpace(),
                      Text(
                        _ipAddress.isEmpty || _ipAddress == _websocketHostEditingController.text
                            ? ''
                            : 'Address found: $_ipAddress',
                        style: style,
                      ),
                    ],
                  ),
                  const AppSpace(),
                  AppWrapFullWidth(
                    spacing: 15,
                    children: [
                      const Text('Hosts:'),
                      AppTooltip(
                        message: 'No leader/follower',
                        child: appButton(
                          'None',
                          appKeyEnum: AppKeyEnum.optionsWebsocketNone,
                          onPressed: () {
                            _appOptions.websocketHost = AppOptions.idleHost;
                            _websocketHostEditingController.text = '';
                          },
                        ),
                      ),
                      AppTooltip(
                        message: 'You are in the Community Jams studio.',
                        child: appButton(
                          'Studio',
                          appKeyEnum: AppKeyEnum.optionsWebsocketCJ,
                          onPressed: () {
                            _appOptions.websocketHost = 'cj.local';
                            _websocketHostEditingController.text = _appOptions.websocketHost;
                          },
                        ),
                      ),
                      //  no longer appropriate:
                      // AppTooltip(
                      //   message: 'You are in the Community Jams studio with an old ipad.',
                      //   child: appButton(
                      //     'Studio and old Ipad',
                      //     appKeyEnum: AppKeyEnum.optionsWebsocketCJ,
                      //     onPressed: () {
                      //       _appOptions.websocketHost = '10.1.10.50';
                      //       _websocketHostEditingController.text = _appOptions.websocketHost;
                      //     },
                      //   ),
                      // ),
                      AppTooltip(
                        message: 'You are in the park.',
                        child: appButton(
                          'Park',
                          appKeyEnum: AppKeyEnum.optionsWebsocketPark,
                          onPressed: () {
                            _appOptions.websocketHost = parkFixedIpAddress;
                            _websocketHostEditingController.text = _appOptions.websocketHost;
                          },
                        ),
                      ),
                      AppTooltip(
                        message: 'You have a local raspberry pi from bob.',
                        child: appButton(
                          'Bob\'spi',
                          appKeyEnum: AppKeyEnum.optionsWebsocketBobsPi,
                          onPressed: () {
                            _appOptions.websocketHost = 'bobspi.local';
                            _websocketHostEditingController.text = _appOptions.websocketHost;
                          },
                        ),
                      ),
                      if (hostIsWebsocketHost)
                        AppTooltip(
                          message: 'Your web server should have a leader/follower connection.'
                              '\nClick here to use it.',
                          child: appButton(
                            'This host',
                            appKeyEnum: AppKeyEnum.optionsWebsocketThisHost,
                            onPressed: () {
                              _appOptions.websocketHost = host;
                              _websocketHostEditingController.text = _appOptions.websocketHost;
                            },
                          ),
                        ),
                      if (kDebugMode)
                        appButton('bob\'s place', appKeyEnum: AppKeyEnum.optionsWebsocketBob, onPressed: () {
                          _appOptions.websocketHost = 'bob'; //'bobspi.local';
                          _websocketHostEditingController.text = _appOptions.websocketHost;
                        }),
                    ],
                  ),
                  const AppSpace(),
                  Row(children: <Widget>[
                    const Text(
                      'Song Update: ',
                    ),
                    Text(
                      (_songUpdateService.isConnected
                          ? 'Connected'
                          : (_songUpdateService.isIdle ? 'Idle' : 'Retrying ${_songUpdateService.host}')),
                      style: generateAppTextStyle(
                        fontWeight: FontWeight.bold,
                        backgroundColor: _songUpdateService.isConnected || _songUpdateService.isIdle
                            ? Colors.green
                            : Colors.red[300],
                      ),
                    ),
                    const AppSpace(),
                    if (_songUpdateService.isConnected)
                      appButton(
                        _songUpdateService.isLeader ? 'Abdicate my leadership' : 'Make me the leader',
                        appKeyEnum: AppKeyEnum.optionsLeadership,
                        onPressed: () {
                          setState(() {
                            if (_songUpdateService.isConnected) {
                              _songUpdateService.isLeader = !_songUpdateService.isLeader;
                            }
                          });
                        },
                      ),
                  ]),
                  const AppSpace(verticalSpace: 30),
                  AppWrapFullWidth(
                    spacing: 15,
                    children: [
                      const Text('Accidental Notes:'),
                      SegmentedButton<AccidentalExpressionChoice>(
                        segments: <ButtonSegment<AccidentalExpressionChoice>>[
                          ButtonSegment<AccidentalExpressionChoice>(
                            value: AccidentalExpressionChoice.byKey,
                            label: Text('By Key', style: buttonTextStyle()),
                            tooltip: _appOptions.toolTips
                                ? 'When required, accidentals notes are expressed as a sharp or flat\n'
                                    'based on the song\'s key.'
                                : null,
                          ),
                          ButtonSegment<AccidentalExpressionChoice>(
                            value: AccidentalExpressionChoice.easyRead,
                            label: Text('Easy Read', style: buttonTextStyle()),
                            tooltip: _appOptions.toolTips
                                ? 'When required, accidental notes are expressed as an easy to read expression.'
                                : null,
                          ),
                          // ButtonSegment<AccidentalExpressionChoice>(
                          //   value: AccidentalExpressionChoice.alwaysSharp,
                          //   label: Text('Always Sharp', style: buttonTextStyle()),
                          //   tooltip: _appOptions.toolTips
                          //       ? 'When required, accidental notes are always expressed as a sharp.'
                          //       : null,
                          // ),
                          // ButtonSegment<AccidentalExpressionChoice>(
                          //   value: AccidentalExpressionChoice.alwaysFlat,
                          //   label: Text('Always Flat', style: buttonTextStyle()),
                          //   tooltip: _appOptions.toolTips
                          //       ? 'When required, accidental notes are always expressed as a flat.'
                          //       : null,
                          // ),
                        ],
                        selected: <AccidentalExpressionChoice>{_appOptions.accidentalExpressionChoice},
                        onSelectionChanged: (Set<AccidentalExpressionChoice> newSelection) {
                          setState(() {
                            // By default there is only a single segment that can be
                            // selected at one time, so its value is always the first
                            // item in the selected set.
                            _appOptions.accidentalExpressionChoice = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),

                  const AppSpace(verticalSpace: 30),
                  AppWrapFullWidth(
                    spacing: 15,
                    children: [
                      const Text('Nashville beats:'),
                      SegmentedButton<bool>(
                        segments: <ButtonSegment<bool>>[
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Reduced', style: buttonTextStyle()),
                            tooltip: _appOptions.toolTips
                                ? 'Show Nashville beats only when they are absolutely required.\n'
                                    'This will not happen if the measure is full length.\n'
                                    'Typically the period convention will be used.'
                                : null,
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Always', style: buttonTextStyle()),
                            tooltip: _appOptions.toolTips
                                ? 'Show Nashville beats any time the beats are not a full measure.'
                                : null,
                          ),
                        ],
                        selected: <bool>{_appOptions.reducedNashvilleDots},
                        onSelectionChanged: (Set<bool> newSelection) {
                          setState(() {
                            // By default there is only a single segment that can be
                            // selected at one time, so its value is always the first
                            // item in the selected set.
                            _appOptions.reducedNashvilleDots = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),

                  const AppSpace(verticalSpace: 30),
                  AppWrap(children: [
                    AppTooltip(
                      message: 'Enable Tooltips',
                      child: appButton(
                        'Tooltips',
                        appKeyEnum: AppKeyEnum.optionsToolTipsTextButton,
                        onPressed: () {
                          setState(() {
                            _appOptions.toolTips = !_appOptions.toolTips;
                          });
                        },
                        // softWrap: false,
                      ),
                    ),
                    appSwitch(
                      appKeyEnum: AppKeyEnum.optionsToolTips,
                      value: _appOptions.toolTips,
                      onChanged: (value) {
                        setState(() {
                          _appOptions.toolTips = value;
                        });
                      },
                    ),
                  ]),
                  const AppSpace(),
                  AppWrap(
                    alignment: WrapAlignment.start,
                    children: [
                      const Text('Player Clicks:'),
                      const AppSpace(),
                      AppTooltip(
                        message: 'On the player screen:\n\n'
                            'Never: never advance the section on a click or tap\n'
                            'Up or down: Tap on the bottom half of the screen to advance a section.\n'
                            '     Tap on the top half to go back a section.\n'
                            'Always down: advance the section on any click or tap, anywhere',
                        child: DropdownButton<TapToAdvance>(
                          items: TapToAdvance.values.toList().map((TapToAdvance value) {
                            return DropdownMenuItem<TapToAdvance>(
                              key: ValueKey(value.name),
                              value: value,
                              child: Text(
                                Util.firstToUpper(Util.camelCaseToLowercaseSpace(value.name)),
                                style: style,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null && value != _appOptions.tapToAdvance) {
                              setState(() {
                                _appOptions.tapToAdvance = value;
                              });
                            }
                          },
                          value: _appOptions.tapToAdvance,
                          style: generateAppTextStyle(
                            color: Colors.black,
                            textBaseline: TextBaseline.ideographic,
                          ),
                          itemHeight: null,
                        ),
                      ),
                      // appSwitch(
                      //   appKeyEnum: AppKeyEnum.optionsTapToAdvance,
                      //   value: _appOptions.tapToAdvance,
                      //   onChanged: (value) {
                      //     setState(() {
                      //       _appOptions.tapToAdvance = !_appOptions.tapToAdvance;
                      //     });
                      //   },
                      // ),
                    ],
                  ),

                  //  fixme: audio!
                  if (kDebugMode) const AppSpace(verticalSpace: 30),
                  if (kDebugMode)
                    Row(children: <Widget>[
                      appWidgetHelper.checkbox(
                        value: _appOptions.playWithChords,
                        onChanged: (value) {
                          setState(() {
                            _appOptions.playWithChords = value ?? false;
                          });
                        },
                      ),
                      const Text(
                        'Playback with chords',
                        //    style: AppTextStyle(fontSize: fontSize),
                      ),
                    ]),
                  if (kDebugMode)
                    Row(children: <Widget>[
                      appWidgetHelper.checkbox(
                        value: _appOptions.playWithBass,
                        onChanged: (value) {
                          setState(() {
                            _appOptions.playWithBass = value ?? true;
                          });
                        },
                      ),
                      const Text(
                        'Playback with bass',
                        //   style: AppTextStyle(fontSize: fontSize),
                      ),
                    ]),
                  if (kDebugMode)
                    Row(children: <Widget>[
                      const Text(
                        'audio test: ',
                        //   style: AppTextStyle(fontSize: fontSize),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _stop();
                          });
                        },
                        child: Icon(
                          Icons.stop,
                          size: app.screenInfo.fontSize * 2,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _audioTest();
                          });
                        },
                        child: Icon(
                          Icons.play_arrow,
                          size: app.screenInfo.fontSize * 2,
                        ),
                      ),
                    ]),
                  if (kDebugMode)
                    Row(children: <Widget>[
                      appWidgetHelper.checkbox(
                        value: _appOptions.debug,
                        onChanged: (value) {
                          _appOptions.debug = value;
                          Logger.level = _appOptions.debug ? Level.debug : Level.info;
                          setState(() {});
                        },
                      ),
                      const Text(
                        'debug',
                      ),
                    ]),
                  const AppSpace(verticalSpace: 30),
                  Row(children: <Widget>[
                    appButton(
                      'Clear all local stored options',
                      appKeyEnum: AppKeyEnum.optionsClearOptionsTextButton,
                      onPressed: () {
                        setState(() {
                          _appOptions.clear();
                        });
                      },
                      // softWrap: false,
                    ),
                  ]),
                ]),
          ),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.optionsBack),
    );
  }

  @override
  void dispose() {
    _songUpdateService.removeListener(_songUpdateServiceCallback);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    //_audioPlayer.stop();
  }

  void _audioTest() async {
    _timer?.cancel();

    _test = 0;
    const int bpm = 50;
    const double timerPeriod = 60 / bpm;

    const int microsecondsPerSecond = 1000000;
    int periodMs = (microsecondsPerSecond * timerPeriod).round();
    logger.log(_optionLogAudio, 'periodMs: ${periodMs.toString()}');
    logger.log(_optionLogAudio, 'timerPeriod: ${timerPeriod.toString()}, _testType: $_testType');
    _timerT = _audioPlayer.getCurrentTime() + 2;
    _testType = 'bass';
    const double gap = 0.25;
    _timer = Timer.periodic(Duration(microseconds: periodMs), (timer) {
      try {
        logger.log(_optionLogAudio, '_audioTest() $_testNumber.$_test');
        switch (_testNumber) {
          case 0:
            switch (_testType) {
              case 'bass':
                if (_test > 39) {
                  _testType = 'guitar';
                  _test = 0;
                }
                break;
              case 'guitar':
                if (_test > 30) {
                  _timer?.cancel();
                  _timer = null;
                }
                break;
            }

            _audioPlayer.play('audio/${_testType}_$_test.mp3', when: _timerT, duration: timerPeriod - gap, volume: 1.0);
            _test++;
            break;
          case 1:
            if (_test > 20) {
              _timer?.cancel();
              _timer = null;
            }

            //  guitar and bass
            _audioPlayer.play('audio/bass_$_test.mp3', when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 4);
            _audioPlayer.play('audio/guitar_$_test.mp3', when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 4);
            _audioPlayer.play('audio/guitar_${_test + 4 /*half steps to major 3rd*/}.mp3',
                when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 4);
            _audioPlayer.play('audio/guitar_${_test + 7 /*half steps to 5th*/}.mp3',
                when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 4);

            _test++;
            break;
          case 2:
            if (_test >= _pitches.length) {
              _timer?.cancel();
              _timer = null;
            }

            _audioPlayer.oscillate(_pitches[_test].frequency, when: _timerT, duration: timerPeriod - gap, volume: 1.0);
            _test++;
            break;
          case 3:
            if (_test < 12) _test = 3 * 12;
            if (_test >= _pitches.length - 3 * 12) {
              _timer?.cancel();
              _timer = null;
            }

            ChordDescriptor chordDescriptor = ChordDescriptor.minor;
            Pitch refPitch = _pitches[_test];

            //  guitar and bass
            _audioPlayer.play('audio/bass_${Bass.mapPitchToBassFret(refPitch)}.mp3',
                when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 8);

            //  piano chord
            Chord chord = Chord(ScaleChord(refPitch.getScaleNote(), chordDescriptor), 4, 4, null,
                ChordAnticipationOrDelay.defaultValue, false);
            List<Pitch> pitches = chord.getPitches(_atOrAbove);
            double duration = timerPeriod - gap;
            double amp = 1.0 / (pitches.length + 2);
            for (final Pitch pitch in pitches) {
              _playPianoPitch(pitch, duration, amp);
            }
            Pitch octaveLower = pitches[0].octaveLower();
            _playPianoPitch(octaveLower, duration, amp);
            _playPianoPitch(octaveLower.octaveLower(), duration, amp);

            _test++;
            break;

          case 4:
            _audioPlayer.play('audio/snare_4406.flac', when: _timerT, duration: timerPeriod - gap, volume: 1.0 / 4);
            break;
        }
        _timerT += periodMs / microsecondsPerSecond;
      } catch (e) {
        logger.log(_optionLogAudio, '_audioTest() error: ${e.toString()}');
      }
    });
  }

  void _playPianoPitch(Pitch pitch, double duration, double amp) {
    _audioPlayer.play('audio/Piano.mf.${pitch.getScaleNote().toMarkup()}${pitch.number.toString()}.mp3',
        when: _timerT, duration: duration, volume: amp);
  }

  final TextEditingController _userTextEditingController = TextEditingController();
  final TextEditingController _websocketHostEditingController = TextEditingController();

  static const int _testNumber = 4;
  int _test = 0;

  String _testType = 'unknown';
  final List<Pitch> _pitches = Pitch.flats;
  static final Pitch _atOrAbove = Pitch.get(PitchEnum.A3);

  late AppWidgetHelper appWidgetHelper;

  Timer? _timer;

  double _timerT = 0;
  final SongUpdateService _songUpdateService = SongUpdateService();
  String _ipAddress = '';

  final AppAudioPlayer _audioPlayer = AppAudioPlayer();
  final AppOptions _appOptions = AppOptions();
  final App app = App();
}
