import 'dart:async';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/pitch.dart';
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
    const int bpm = 200;
    const double timerPeriod = 60 / bpm;
    const int microsecondsPerSecond = 1000000;
    logger.i('microseconds: ${(microsecondsPerSecond * timerPeriod).toString()}');
    logger.i('timerPeriod: ${timerPeriod.toString()}');
    _testType = 'bass';
    _timer = Timer.periodic(Duration(microseconds: (microsecondsPerSecond * timerPeriod) as int), (timer) {
      try {
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

            _audioPlayer.play('audio/${_testType}_$_test.mp3', 0, timerPeriod - 0.02);
            _test++;
            break;
          case 1:
            if (_test > 20) {
              _timer.cancel();
              _timer = null;
            }

            _audioPlayer.play('audio/bass_$_test.mp3', 0, timerPeriod - 0.02);
            _audioPlayer.play('audio/guitar_$_test.mp3', 0, timerPeriod - 0.02);
            _audioPlayer.play('audio/guitar_${_test + 4}.mp3', 0, timerPeriod - 0.02);
            _audioPlayer.play('audio/guitar_${_test + 7}.mp3', 0, timerPeriod - 0.02);
            _test++;
            break;
          case 2:
            if (_test > _pitches.length) {
              _timer.cancel();
              _timer = null;
            }

            _audioPlayer.oscillate(_pitches[_test].getFrequency(), 0, timerPeriod - 0.02);
            _test++;
            break;
        }
      } catch (e) {
        logger.i('_audioTest() error: ${e.toString()}');
      }
    });
  }

  static final int _testNumber = 1;
  int _test;
  String _testType;
  final List<Pitch> _pitches = Pitch.getPitches();

  Timer _timer;
  final AppAudioPlayer _audioPlayer = AppAudioPlayer();
  final AppOptions _appOptions = AppOptions();
}
