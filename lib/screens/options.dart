import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/pitch.dart';
import 'package:bsteeleMusicLib/songs/bass.dart';
import 'package:bsteele_music_flutter/audio/appAudioPlayer.dart';
import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:logger/logger.dart';

import '../appOptions.dart';

/// Display the song moments in sequential order.
class Options extends StatefulWidget {
  const Options({Key key}) : super(key: key);

  @override
  _Options createState() => _Options();
}

class _Options extends State<Options> {
  @override
  initState() {
    super.initState();
  }

  void onPlayerChanged(bool value) {
    _appOptions.playerDisplay = value;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    double fontSize = screenInfo.isTooNarrow ? 18 : 36;

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
        child: Container(
          padding: EdgeInsets.all(8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Radio<bool>(
                      value: true,
                      groupValue: _appOptions.playerDisplay,
                      onChanged: onPlayerChanged,
                    ),
                    Text(
                      'Player',
                    ),
                    Radio<bool>(
                      value: false,
                      groupValue: _appOptions.playerDisplay,
                      onChanged: onPlayerChanged,
                    ),
                    Text(
                      'Singer',
                    ),
                  ],
                ),
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
                  _timer.cancel();
                  _timer = null;
                }
                break;
            }

            _audioPlayer.play('audio/${_testType}_$_test.mp3', _timerT, timerPeriod - gap, 1.0);
            _test++;
            break;
          case 1:
            if (_test > 20) {
              _timer.cancel();
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
              _timer.cancel();
              _timer = null;
            }

            _audioPlayer.oscillate(_pitches[_test].getFrequency(), _timerT, timerPeriod - gap, 1.0);
            _test++;
            break;
          case 3:
            if ( _test < 12 )
              _test = 3*12;
            if (_test >= _pitches.length - 3*12) {
              _timer.cancel();
              _timer = null;
            }



            Pitch refPitch = _pitches[_test];

            //  guitar and bass
            _audioPlayer.play('audio/bass_${Bass.mapPitchToBass(refPitch)}.mp3', _timerT, timerPeriod - gap, 1.0 / 4);

            int octave = refPitch.getLabelNumber();
            logger.i('${refPitch.getScaleNote().toString()}');
            List<int> chordOffsets = [0, 4, 7];
            for (int i = 0; i < chordOffsets.length; i++) {
              Pitch pitch = refPitch.offsetByHalfSteps(chordOffsets[i]);
              logger.d('audio/Piano.mf.${pitch.getScaleNote().toMarkup()}${pitch.getLabelNumber().toString()}.mp3');
              _audioPlayer.play('audio/Piano.mf.${pitch.getScaleNote().toMarkup()}${octave.toString()}.mp3', _timerT,
                  timerPeriod - gap, 1.0 / chordOffsets.length);
            }

            _test++;
            break;
        }
        _timerT += periodMs / microsecondsPerSecond;
      } catch (e) {
        logger.i('_audioTest() error: ${e.toString()}');
      }
    });
  }

  static final int _testNumber = 3;
  int _test;
  String _testType;
  final List<Pitch> _pitches = Pitch.flats;

  Timer _timer;
  double _timerT;
  final AppAudioPlayer _audioPlayer = AppAudioPlayer();
  final AppOptions _appOptions = AppOptions();
}
