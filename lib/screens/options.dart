import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import '../app/appOptions.dart';

/// A screen to display controls for the user to manage some of the app's options.
class Options extends StatefulWidget {
  const Options({Key? key}) : super(key: key);

  @override
  _Options createState() => _Options();

  static const String routeName = '/options';
}

class _Options extends State<Options> {
  @override
  initState() {
    super.initState();

    _userTextEditingController.text = _appOptions.user;
    _userTextEditingController.addListener(() {
      if (_userTextEditingController.text.isNotEmpty) {
        _appOptions.user = _userTextEditingController.text;
      }
    });

    _websocketHostEditingController.text = _appOptions.websocketHost;

    _songUpdateService.addListener(_songUpdateServiceCallback);
  }

  void _songUpdateServiceCallback() {
    logger.v('_songUpdateServiceCallback()');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    appWidget.context = context; //	required on every build

    final double fontSize = _app.screenInfo.fontSize;
    logger.v('options build: ${_songUpdateService.isConnected}');
    var style = generateAppTextStyle();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appWidget.backBar('bsteele Music App Options'),
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
                  Text(
                    'User style: ',
                    style: style,
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 30.0),
                    child: Column(
                      children: <Widget>[
                        RadioListTile<UserDisplayStyle>(
                          title: Text('Player', style: style),
                          value: UserDisplayStyle.player,
                          groupValue: _appOptions.userDisplayStyle,
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                _appOptions.userDisplayStyle = value;
                              }
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<UserDisplayStyle>(
                          title: Text('Both Player and Singer', style: style),
                          value: UserDisplayStyle.both,
                          groupValue: _appOptions.userDisplayStyle,
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                _appOptions.userDisplayStyle = value;
                              }
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<UserDisplayStyle>(
                          title: Text('Singer', style: style),
                          value: UserDisplayStyle.singer,
                          groupValue: _appOptions.userDisplayStyle,
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                _appOptions.userDisplayStyle = value;
                              }
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Holiday choice: ',
                    style: style,
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 30.0),
                    child: Column(
                      children: <Widget>[
                        RadioListTile<bool>(
                          title: Text('Not in a holiday mood', style: style),
                          value: false,
                          groupValue: _appOptions.holiday,
                          onChanged: (value) {
                            setState(() {
                              _appOptions.holiday = value ?? false;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<bool>(
                          title: Text('All holiday, all the time!', style: style),
                          value: true,
                          groupValue: _appOptions.holiday,
                          onChanged: (value) {
                            setState(() {
                              _appOptions.holiday = value ?? true;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Repeat display choice: ',
                    style: style,
                  ),
                  Container(
                    padding: const EdgeInsets.only(left: 30.0),
                    child: Column(
                      children: <Widget>[
                        RadioListTile<bool>(
                          title: Text('Compress all repeats (for example: x4)', style: style),
                          value: true,
                          groupValue: _appOptions.compressRepeats,
                          onChanged: (value) {
                            setState(() {
                              _appOptions.compressRepeats = value ?? true;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<bool>(
                          title: Text('Expand all repeat repetitions', style: style),
                          value: false,
                          groupValue: _appOptions.compressRepeats,
                          onChanged: (value) {
                            setState(() {
                              _appOptions.compressRepeats = value ?? false;
                            });
                          },
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                          child: Text(
                            'User name: ',
                            style: style,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _userTextEditingController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your user name.',
                            ),
                            // maxLength: 20,
                            style: style,
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                _appOptions.user = value;
                              }
                            },
                          ),
                        ),
                      ]),
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                          child: Text(
                            'Host IP: ',
                            style: style,
                          ),
                        ),
                        Expanded(
                          flex: 16,
                          child: TextField(
                            controller: _websocketHostEditingController,
                            decoration: const InputDecoration(
                              hintText: 'Enter the websocket host IP address.',
                            ),
                            // maxLength: 20,
                            style: style,
                            onChanged: (value) {
                              _appOptions.websocketHost = value;
                            },
                          ),
                        ),
                      ]),
                  appWrapFullWidth([
                    const Text('Hosts:'),
                    appSpace(),
                    appTooltip(
                      message: 'No leader/follower',
                      child: appButton(
                        'None',
                        fontSize: fontSize,
                        onPressed: () {
                          _appOptions.websocketHost = '';
                          _websocketHostEditingController.text = _appOptions.websocketHost;
                        },
                      ),
                    ),
                    appSpace(),
                    appTooltip(
                      message: 'You are in the Community Jams studio.',
                      child: appButton(
                        'Studio',
                        fontSize: fontSize,
                        onPressed: () {
                          _appOptions.websocketHost = 'cj';
                          _websocketHostEditingController.text = _appOptions.websocketHost;
                        },
                      ),
                    ),
                    appSpace(),
                    appTooltip(
                      message: 'You are in the park.',
                      child: appButton(
                        'Park',
                        fontSize: fontSize,
                        onPressed: () {
                          _appOptions.websocketHost = parkFixedIpAddress;
                          _websocketHostEditingController.text = _appOptions.websocketHost;
                        },
                      ),
                    ),
                    if (kDebugMode) appSpace(),
                    if (kDebugMode)
                      appButton('bob\'s place', fontSize: fontSize, onPressed: () {
                        _appOptions.websocketHost = 'bobspi.local';
                        _websocketHostEditingController.text = _appOptions.websocketHost;
                      }),
                  ]),
                  appSpace(),
                  Row(children: <Widget>[
                    Text(
                      'Song Update: ',
                      style: style,
                    ),
                    Text(
                      (_songUpdateService.isConnected
                          ? 'Connected'
                          : (_songUpdateService.authority.isNotEmpty
                              ? 'Retrying ${_songUpdateService.authority}'
                              : 'Idle')),
                      style: generateAppTextStyle(
                        fontWeight: FontWeight.bold,
                        backgroundColor: _songUpdateService.isConnected || _songUpdateService.authority.isEmpty
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    appSpace(),
                    if (_songUpdateService.isConnected)
                      ElevatedButton(
                        child: Text(
                          _songUpdateService.isLeader ? 'Abdicate my leadership' : 'Make me the leader',
                          style: generateAppTextStyle(
                            fontWeight: FontWeight.bold,
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                        ),
                        onPressed: () {
                          if (_songUpdateService.isConnected) {
                            _songUpdateService.isLeader = !_songUpdateService.isLeader;
                          } else {
                            _songUpdateService.open(context);
                          }
                          setState(() {});
                        },
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all(
                              _songUpdateService.isConnected || _songUpdateService.authority.isEmpty
                                  ? Theme.of(context).primaryColor
                                  : Colors.red),
                        ),
                      ),
                  ]),
                  appSpace(space: 30),
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                          child: Text(
                            'Display key offset: ',
                            style: style,
                          ),
                        ),
                        DropdownButton<int>(
                          items: _keyOffsetItems,
                          onChanged: (_value) {
                            if (_value != null) {
                              setState(() {
                                _app.displayKeyOffset = _value;
                                logger.d('key offset: $_value');
                              });
                            }
                          },
                          style: generateAppTextStyle(color: const Color(0xFF424242)),
                          value: _app.displayKeyOffset,
                        ),
                      ]),
                  Row(children: <Widget>[
                    appWidget.checkbox(
                      value: _appOptions.debug,
                      onChanged: (value) {
                        _appOptions.debug = value;
                        Logger.level = _appOptions.debug ? Level.debug : Level.info;
                        setState(() {});
                      },
                    ),
                    Text(
                      'debug: ',
                      style: style,
                    ),
                  ]),
                  //  //  fixme: audio!
                  // Row(children: <Widget>[
                  //   appWidget.checkbox(
                  //     value: _appOptions.playWithChords,
                  //     onChanged: (value) {
                  //       setState(() {
                  //         _appOptions.playWithChords = value ?? false;
                  //       });
                  //     },
                  //   ),
                  //   Text(
                  //     'Playback with chords',
                  //     style: AppTextStyle(fontSize: fontSize),
                  //   ),
                  // ]),
                  // Row(children: <Widget>[
                  //   appWidget.checkbox(
                  //     value: _appOptions.playWithBass,
                  //     onChanged: (value) {
                  //       setState(() {
                  //         _appOptions.playWithBass = value ?? true;
                  //       });
                  //     },
                  //   ),
                  //   Text(
                  //     'Playback with bass',
                  //     style: AppTextStyle(fontSize: fontSize),
                  //   ),
                  // ]),
                  // Row(children: <Widget>[
                  //   Text(
                  //     'audio test: ',
                  //     style: AppTextStyle(fontSize: fontSize),
                  //   ),
                  //   InkWell(
                  //     onTap: () {
                  //       setState(() {
                  //         _stop();
                  //       });
                  //     },
                  //     child: Icon(
                  //       Icons.stop,
                  //       size: fontSize * 2,
                  //     ),
                  //   ),
                  //   InkWell(
                  //     onTap: () {
                  //       setState(() {
                  //         _audioTest();
                  //       });
                  //     },
                  //     child: Icon(
                  //       Icons.play_arrow,
                  //       size: fontSize * 2,
                  //     ),
                  //   ),
                  // ]),
                ]),
          ),
        ),
      ),
      floatingActionButton: appWidget.floatingBack(),
    );
  }

  @override
  void dispose() {
    _songUpdateService.removeListener(_songUpdateServiceCallback);
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  // void _stop() {
  //   _timer?.cancel();
  //   _timer = null;
  //   //_audioPlayer.stop();
  // }

  // void _audioTest() async {
  //   _timer?.cancel();
  //
  //   _test = 0;
  //   const int bpm = 50;
  //   const double timerPeriod = 60 / bpm;
  //
  //   const int microsecondsPerSecond = 1000000;
  //   int periodMs = (microsecondsPerSecond * timerPeriod).round();
  //   logger.d('periodMs: ${periodMs.toString()}');
  //   logger.d('timerPeriod: ${timerPeriod.toString()}');
  //   _timerT = _audioPlayer.getCurrentTime() + 2;
  //   _testType = 'bass';
  //   const double gap = 0.25;
  //   _timer = Timer.periodic(Duration(microseconds: periodMs), (timer) {
  //     try {
  //       logger.d('_audioTest() ${_testNumber.toString()}.${_test.toString()}');
  //       switch (_testNumber) {
  //         case 0:
  //           switch (_testType) {
  //             case 'bass':
  //               if (_test > 39) {
  //                 _testType = 'guitar';
  //                 _test = 0;
  //               }
  //               break;
  //             case 'guitar':
  //               if (_test > 30) {
  //                 _timer?.cancel();
  //                 _timer = null;
  //               }
  //               break;
  //           }
  //
  //           _audioPlayer.play('audio/${_testType}_$_test.mp3', _timerT, timerPeriod - gap, 1.0);
  //           _test++;
  //           break;
  //         case 1:
  //           if (_test > 20) {
  //             _timer?.cancel();
  //             _timer = null;
  //           }
  //
  //           //  guitar and bass
  //           _audioPlayer.play('audio/bass_$_test.mp3', _timerT, timerPeriod - gap, 1.0 / 4);
  //           _audioPlayer.play('audio/guitar_$_test.mp3', _timerT, timerPeriod - gap, 1.0 / 4);
  //           _audioPlayer.play(
  //               'audio/guitar_${_test + 4 /*half steps to major 3rd*/}.mp3', _timerT, timerPeriod - gap, 1.0 / 4);
  //           _audioPlayer.play(
  //               'audio/guitar_${_test + 7 /*half steps to 5th*/}.mp3', _timerT, timerPeriod - gap, 1.0 / 4);
  //
  //           _test++;
  //           break;
  //         case 2:
  //           if (_test >= _pitches.length) {
  //             _timer?.cancel();
  //             _timer = null;
  //           }
  //
  //           _audioPlayer.oscillate(_pitches[_test].frequency, _timerT, timerPeriod - gap, 1.0);
  //           _test++;
  //           break;
  //         case 3:
  //           if (_test < 12) _test = 3 * 12;
  //           if (_test >= _pitches.length - 3 * 12) {
  //             _timer?.cancel();
  //             _timer = null;
  //           }
  //
  //           ChordDescriptor chordDescriptor = ChordDescriptor.minor;
  //           Pitch refPitch = _pitches[_test];
  //
  //           //  guitar and bass
  //           _audioPlayer.play(
  //               'audio/bass_${Bass.mapPitchToBassFret(refPitch)}.mp3', _timerT, timerPeriod - gap, 1.0 / 8);
  //
  //           //  piano chord
  //           Chord chord = Chord.byScaleChord(ScaleChord(refPitch.getScaleNote(), chordDescriptor));
  //           List<Pitch> pitches = chord.getPitches(_atOrAbove);
  //           double duration = timerPeriod - gap;
  //           double amp = 1.0 / (pitches.length + 2);
  //           for (final Pitch pitch in pitches) {
  //             _playPianoPitch(pitch, duration, amp);
  //           }
  //           Pitch octaveLower = pitches[0].octaveLower();
  //           _playPianoPitch(octaveLower, duration, amp);
  //           _playPianoPitch(octaveLower.octaveLower(), duration, amp);
  //
  //           _test++;
  //           break;
  //       }
  //       _timerT += periodMs / microsecondsPerSecond;
  //     } catch (e) {
  //       logger.d('_audioTest() error: ${e.toString()}');
  //     }
  //   });
  // }
  //
  // void _playPianoPitch(Pitch pitch, double duration, double amp) {
  //   _audioPlayer.play(
  //       'audio/Piano.mf.${pitch.getScaleNote().toMarkup()}${pitch.number.toString()}.mp3', _timerT, duration, amp);
  // }

  final List<DropdownMenuItem<int>> _keyOffsetItems = [
    const DropdownMenuItem(key: ValueKey('keyOffset0'), value: 0, child: Text('normal: (no key offset)')),
    const DropdownMenuItem(
        key: ValueKey('keyOffset1'),
        value: 1,
        child: Text('+1   (-11) halfsteps = scale  ${MusicConstants.flatChar}2')),
    const DropdownMenuItem(key: ValueKey('keyOffset2'), value: 2, child: Text('+2   (-10) halfsteps = scale   2')),
    const DropdownMenuItem(
        key: ValueKey('keyOffset3'),
        value: 3,
        child:
            Text('+3   (-9)   halfsteps = scale  ${MusicConstants.flatChar}3, E${MusicConstants.flatChar} instrument')),
    const DropdownMenuItem(key: ValueKey('keyOffset4'), value: 4, child: Text('+4   (-8)   halfsteps = scale   3')),
    const DropdownMenuItem(key: ValueKey('keyOffset5'), value: 5, child: Text('+5   (-7)   halfsteps = scale   4')),
    const DropdownMenuItem(
        key: ValueKey('keyOffset6'),
        value: 6,
        child: Text('+6   (-6)   halfsteps = scale  ${MusicConstants.flatChar}5')),
    const DropdownMenuItem(
        key: ValueKey('keyOffset7'), value: 7, child: Text('+7   (-5)   halfsteps = scale   5, baritone guitar')),
    const DropdownMenuItem(
        key: ValueKey('keyOffset8'),
        value: 8,
        child: Text('+8   (-4)   halfsteps = scale  ${MusicConstants.flatChar}6')),
    const DropdownMenuItem(key: ValueKey('keyOffset9'), value: 9, child: Text('+9   (-3)   halfsteps = scale   6')),
    const DropdownMenuItem(
        key: ValueKey('keyOffset10'),
        value: 10,
        child:
            Text('+10 (-2)   halfsteps = scale  ${MusicConstants.flatChar}7, B${MusicConstants.flatChar} instrument')),
    const DropdownMenuItem(key: ValueKey('keyOffset10'), value: 11, child: Text('+11 (-1)   halfsteps = scale   7')),
  ];

  final TextEditingController _userTextEditingController = TextEditingController();
  final TextEditingController _websocketHostEditingController = TextEditingController();

  // static const int _testNumber = 3;
  // int _test = 0;
  //
  // String _testType = 'unknown';
  // final List<Pitch> _pitches = Pitch.flats;
  // static final Pitch _atOrAbove = Pitch.get(PitchEnum.A3);

  final AppWidget appWidget = AppWidget();

  Timer? _timer;

  //double _timerT = 0;
  final SongUpdateService _songUpdateService = SongUpdateService();

  //final AppAudioPlayer _audioPlayer = AppAudioPlayer();
  final AppOptions _appOptions = AppOptions();
  final App _app = App();
}
