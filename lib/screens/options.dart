import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chord.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/pitch.dart';
import 'package:bsteeleMusicLib/songs/bass.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteele_music_flutter/audio/appAudioPlayer.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:logger/logger.dart';

import '../appOptions.dart';

/// Display the song moments in sequential order.
class Options extends StatefulWidget {
  const Options({Key? key}) : super(key: key);

  @override
  _Options createState() => _Options();

  static final String routeName = '/options';
}

class _Options extends State<Options> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    double fontSize = screenInfo.isTooNarrow ? 18 : 36;

    _websocketHostEditingController.text = _appOptions.websocketHost;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Music App Options',
          style: TextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: DefaultTextStyle(
        style: TextStyle(color: Colors.black87, fontSize: fontSize),
        child: SingleChildScrollView(
          //  for phones when horizontal
          child: Container(
            padding: EdgeInsets.all(12.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  Text(
                    'User style: ',
                    style: TextStyle(fontSize: fontSize),
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 30.0),
                    child: Column(
                      children: <Widget>[
                        RadioListTile<UserDisplayStyle>(
                          title: Text('Player', style: TextStyle(fontSize: fontSize)),
                          value: UserDisplayStyle.player,
                          groupValue: _appOptions.userDisplayStyle,
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                _appOptions.userDisplayStyle = value;
                              }
                            });
                          },
                        ),
                        RadioListTile<UserDisplayStyle>(
                          title: Text('Both Player and Singer', style: TextStyle(fontSize: fontSize)),
                          value: UserDisplayStyle.both,
                          groupValue: _appOptions.userDisplayStyle,
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                _appOptions.userDisplayStyle = value;
                              }
                            });
                          },
                        ),
                        RadioListTile<UserDisplayStyle>(
                          title: Text('Singer', style: TextStyle(fontSize: fontSize)),
                          value: UserDisplayStyle.singer,
                          groupValue: _appOptions.userDisplayStyle,
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                _appOptions.userDisplayStyle = value;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Holliday choice: ',
                    style: TextStyle(fontSize: fontSize),
                  ),
                  Container(
                    padding: EdgeInsets.only(left: 30.0),
                    child: Column(
                      children: <Widget>[
                        RadioListTile<bool>(
                          title: Text('Not in a holiday mood', style: TextStyle(fontSize: fontSize)),
                          value: false,
                          groupValue: _appOptions.holiday,
                          onChanged: (value) {
                            setState(() {
                              _appOptions.holiday = value ?? false;
                            });
                          },
                        ),
                        RadioListTile<bool>(
                          title: Text('All holiday, all the time!', style: TextStyle(fontSize: fontSize)),
                          value: true,
                          groupValue: _appOptions.holiday,
                          onChanged: (value) {
                            setState(() {
                              _appOptions.holiday = value ?? true;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  if (!kIsWeb)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 24, bottom: 24.0),
                            child: Text(
                              'Host: ',
                              style: TextStyle(
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _websocketHostEditingController,
                              decoration: InputDecoration(
                                hintText: 'Enter the websocket host IP address.',
                              ),
                              // maxLength: 20,
                              style: TextStyle(
                                fontSize: fontSize,
                              ),
                              onChanged: (value) {
                                _appOptions.websocketHost = value;
                              },
                            ),
                          ),
                        ]),
                  Row(children: <Widget>[
                    Checkbox(
                      value: _appOptions.debug,
                      onChanged: (value) {
                        _appOptions.debug = value;
                        Logger.level = _appOptions.debug ? Level.debug : Level.info;
                        setState(() {});
                      },
                    ),
                    Text(
                      'debug: ',
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ]),
                  Row(children: <Widget>[
                    Checkbox(
                      value: _appOptions.playWithChords,
                      onChanged: (value) {
                        setState(() {
                          _appOptions.playWithChords = value ?? false;
                        });
                      },
                    ),
                    Text(
                      'Playback with chords',
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ]),
                  Row(children: <Widget>[
                    Checkbox(
                      value: _appOptions.playWithBass,
                      onChanged: (value) {
                        setState(() {
                          _appOptions.playWithBass = value ?? true;
                        });
                      },
                    ),
                    Text(
                      'Playback with bass',
                      style: TextStyle(fontSize: fontSize),
                    ),
                  ]),
                  Row(children: <Widget>[
                    Text(
                      'audio test: ',
                      style: TextStyle(fontSize: fontSize),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _stop();
                        });
                      },
                      child: Icon(
                        Icons.stop,
                        size: fontSize * 2,
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
                        size: fontSize * 2,
                      ),
                    ),
                  ]),
                ]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        tooltip: 'Back',
        child: Icon(Icons.arrow_back),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _audioPlayer.stop();
  }

  void _audioTest() async {
    _timer?.cancel();

    _test = 0;
    const int bpm = 50;
    const double timerPeriod = 60 / bpm;

    const int microsecondsPerSecond = 1000000;
    int periodMs = (microsecondsPerSecond * timerPeriod).round();
    logger.d('periodMs: ${periodMs.toString()}');
    logger.d('timerPeriod: ${timerPeriod.toString()}');
    _timerT = _audioPlayer.getCurrentTime() + 2;
    _testType = 'bass';
    final double gap = 0.25;
    _timer = Timer.periodic(Duration(microseconds: periodMs), (timer) {
      try {
        logger.d('_audioTest() ${_testNumber.toString()}.${_test.toString()}');
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

            _audioPlayer.play('audio/${_testType}_$_test.mp3', _timerT, timerPeriod - gap, 1.0);
            _test++;
            break;
          case 1:
            if (_test > 20) {
              _timer?.cancel();
              _timer = null;
            }

            //  guitar and bass
            _audioPlayer.play('audio/bass_$_test.mp3', _timerT, timerPeriod - gap, 1.0 / 4);
            _audioPlayer.play('audio/guitar_$_test.mp3', _timerT, timerPeriod - gap, 1.0 / 4);
            _audioPlayer.play(
                'audio/guitar_${_test + 4 /*half steps to major 3rd*/}.mp3', _timerT, timerPeriod - gap, 1.0 / 4);
            _audioPlayer.play(
                'audio/guitar_${_test + 7 /*half steps to 5th*/}.mp3', _timerT, timerPeriod - gap, 1.0 / 4);

            _test++;
            break;
          case 2:
            if (_test >= _pitches.length) {
              _timer?.cancel();
              _timer = null;
            }

            _audioPlayer.oscillate(_pitches[_test].frequency, _timerT, timerPeriod - gap, 1.0);
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
            _audioPlayer.play(
                'audio/bass_${Bass.mapPitchToBassFret(refPitch)}.mp3', _timerT, timerPeriod - gap, 1.0 / 8);

            //  piano chord
            Chord chord = Chord.byScaleChord(ScaleChord(refPitch.getScaleNote(), chordDescriptor));
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
        }
        _timerT += periodMs / microsecondsPerSecond;
      } catch (e) {
        logger.i('_audioTest() error: ${e.toString()}');
      }
    });
  }

  void _playPianoPitch(Pitch pitch, double duration, double amp) {
    _audioPlayer.play(
        'audio/Piano.mf.${pitch.getScaleNote().toMarkup()}${pitch.number.toString()}.mp3', _timerT, duration, amp);
  }

  TextEditingController _websocketHostEditingController = TextEditingController();

  static final int _testNumber = 3;
  int _test = 0;

  String _testType = 'unknown';
  final List<Pitch> _pitches = Pitch.flats;
  static final Pitch _atOrAbove = Pitch.get(PitchEnum.A3);

  Timer? _timer;
  double _timerT = 0;
  final AppAudioPlayer _audioPlayer = AppAudioPlayer();
  final AppOptions _appOptions = AppOptions();
}
