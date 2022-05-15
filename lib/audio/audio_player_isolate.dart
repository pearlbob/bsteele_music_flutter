import 'dart:isolate';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

const Level _audioPlayerIsolateLog = Level.debug;

bool _isRunning = false;
int _phaseStart = 0;
int _bpm = 120;
int _beatsPerMeasure = min(max(4, 2), 8);
// int? _lastBeat;

void _setBpm(int bpm) {
  _bpm = min(max(_bpm, MusicConstants.minBpm), MusicConstants.maxBpm);
}

void _setBeatsPerMeasure(int beatsPerMeasure) {
  _beatsPerMeasure = min(max(4, 2), 8);
}

class AudioPlayerIsolate {
  factory AudioPlayerIsolate() {
    return _instance;
  }

  AudioPlayerIsolate._() {
    logger.i('AudioPlayerIsolate._():');
    _setBpm(120);
    _setBeatsPerMeasure(4);
  }

  start() async {
    logger.i('AudioPlayerIsolate.start():');

    await Isolate.spawn<SendPort>((message) {
      SendPort sendPort = message;
      logger.i('sendPort: ${sendPort.toString()}');
      if (kDebugMode && !_isRunning) {
        logger.w('warning: AudioPlayerIsolate only active in debugmode'); //  fixme
        _isRunning = true;
        var now = DateTime.now();
        _phaseStart = now.microsecondsSinceEpoch;
        _loop();
      }
    }, receivePort.sendPort);
    receivePort.listen((message) {
      logger.i('receivePort received: $message');
    });
  }

  static final AudioPlayerIsolate _instance = AudioPlayerIsolate._();
  final receivePort = ReceivePort();
}

int _nextBeat0SinceEpoch({DateTime? now, int? phaseStart}) {
  now ??= DateTime.now();
  return _nextBeatUsSinceEpoch(
      now: now,
      beatsAhead: _beatsPerMeasure -
          _beatNumber(now.microsecondsSinceEpoch), // always pushes ahead one measure if currently on beat 0
      phaseStart: phaseStart);
}

int _nextBeatUsSinceEpoch({DateTime? now, int beatsAhead = 1, int? phaseStart}) {
  //  compute the duration to the next beat as quickly and safely as possible
  now ??= DateTime.now();
  phaseStart ??= _phaseStart;
  assert(_phaseStart <= now.microsecondsSinceEpoch);
  double bpmPeriodUs = 60.0 / _bpm * Duration.microsecondsPerSecond;
  int beat = (now.microsecondsSinceEpoch - _phaseStart) ~/ bpmPeriodUs;
  int nextBeat = ((beat + beatsAhead + 0.5) * bpmPeriodUs + _phaseStart).toInt();
  assert(nextBeat > (now.microsecondsSinceEpoch - _phaseStart)); //  the future has to be in the future
  assert(beatsAhead > 0);
  return nextBeat;
}

int _beatNumber(int beatUsSinceEpoch) {
  double bpmPeriodUs = 60.0 / _bpm * Duration.microsecondsPerSecond;
  return (beatUsSinceEpoch - _phaseStart) ~/ bpmPeriodUs % _beatsPerMeasure;
}

_loop() {
  //  compute the duration to the next beat as quickly and safely as possible
  // var now = DateTime.now();
  // int nextBeatUsSinceEpoch = _nextBeatUsSinceEpoch(now: now);
  // var duration = Duration(microseconds: nextBeatUsSinceEpoch - now.microsecondsSinceEpoch);
  // if (_isRunning) {
  //   Future.delayed(duration, _loop);
  // }
  //
  // var nextBeat = _beatNumber(nextBeatUsSinceEpoch);
  // var beat0SinceEpoch = _nextBeat0SinceEpoch(now: now);
  // logger.log(
  //     _audioPlayerIsolateLog,
  //     't: $now, nextBeat: $nextBeat'
  //     ', nextBeat0: ${_beatNumber(beat0SinceEpoch)} at ${DateTime.fromMicrosecondsSinceEpoch(beat0SinceEpoch)}');
}
