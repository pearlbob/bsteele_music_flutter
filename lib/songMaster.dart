import 'dart:math';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/drum_measure.dart';
import 'package:bsteeleMusicLib/songs/music_constants.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/widgets/drums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logger/logger.dart';

import 'audio/app_audio_player.dart';

const Level _songMasterLogTicker = Level.debug;
const Level _songMasterLogTickerDetails = Level.debug;
const Level _songMasterLogDelta = Level.debug;
const Level _songMasterLogMaxDelta = Level.debug;
const Level _songMasterNotify = Level.debug;
const Level _songMasterLogAdvance = Level.debug;
const Level _logDrums = Level.info;

class SongMaster extends ChangeNotifier {
  static final SongMaster _singleton = SongMaster._internal();

  factory SongMaster() {
    return _singleton;
  }

  SongMaster._internal() {
    _ticker = Ticker((elapsed) {
      double time = _appAudioPlayer.getCurrentTime();
      double dt = time - _lastTime;

      switch (songPlayMode) {
        case SongPlayMode.idle:
          if (_momentNumber != null) {
            _clearMomentNumber();
            notifyListeners();
          }
          break;
        case SongPlayMode.manualPlay:
          //  play drums only
          if (_drumParts != null) {
            var drumTime = time - (_songStart ?? time);
            var measureDuration = 60.0 / _bpm * _drumParts!.beats;
            if (drumTime > measureDuration) {
              _songStart = (_songStart ?? time) + measureDuration;
              logger.log(_logDrums, 'play: $_drumParts at $_bpm at ${_songStart! + _advanceS} from $time');
              _performDrumParts(_songStart! + _advanceS, _bpm, _drumParts!);
            }
          }
          break;
        case SongPlayMode.autoPlay:
          if (_song != null) {
            {
              //  fixme: deal with a changing cadence!

              //  pre-load the song audio by the advance time
              double advanceTime = time - (_songStart ?? 0) - (60.0 / _song!.beatsPerMinute).floor() + _advanceS;

              //  fixme: fix the start of playing!!!!!  after pause?
              int? newAdvancedMomentNumber = _song!.getSongMomentNumberAtSongTime(advanceTime);
              logger.log(
                  _songMasterLogAdvance,
                  'new: $newAdvancedMomentNumber'
                  ', advance: ${advanceTime.toStringAsFixed(3)}'
                  ' - ${(time - (_songStart ?? 0)).toStringAsFixed(3)}'
                  ' = ${(advanceTime - (time - (_songStart ?? 0))).toStringAsFixed(3)}'
                  //
                  );
              while (_advancedMomentNumber == null ||
                  (newAdvancedMomentNumber != null && newAdvancedMomentNumber >= _advancedMomentNumber!)) {
                _advancedMomentNumber ??= 0;
                if (_drumParts != null) {
                  _performDrumParts(
                      (_songStart ?? 0) + _song!.getSongTimeAtMoment(_advancedMomentNumber!), _bpm, _drumParts!);
                } else {
                  logger.i('no _drumParts!');
                }
                logger.log(
                    _songMasterLogTicker,
                    '${(time - (_songStart ?? 0)).toStringAsFixed(3)}: _advancedMomentNumber: $_advancedMomentNumber'
                    ' upto $newAdvancedMomentNumber');
                _advancedMomentNumber = _advancedMomentNumber! + 1;
              }
            }
            {
              //  notify the listeners that the play has made progress
              double songTime = time -
                  (_songStart ?? 0) -
                  (60.0 / _song!.beatsPerMinute).floor() +
                  _appAudioPlayer.latency; //  only a rude adjustment to average the appearance of being on time.
              int? newMomentNumber = _song!.getSongMomentNumberAtSongTime(songTime);
              if (newMomentNumber == null) {
                //  stop
                _clearMomentNumber();
                songPlayMode = SongPlayMode.idle;
                notifyListeners();
                logger.log(
                    _songMasterLogTicker,
                    'SongMaster stop: ${songTime.toStringAsFixed(3)}'
                    ', dt: ${dt.toStringAsFixed(3)}'
                    ', moment: ${newMomentNumber.toString()}');
              } else {
                // advance
                if (newMomentNumber != _momentNumber) {
                  _momentNumber = newMomentNumber;
                  logger.log(
                      _songMasterNotify,
                      'songTime notify: ${songTime.toStringAsFixed(3)}'
                      ' time: ${time.toStringAsFixed(3)}'
                      //  ', dt: ${dt.toStringAsFixed(3)}'
                      ', moment: ${newMomentNumber.toString()}');
                  notifyListeners();
                }
              }
            }
          }
          break;
        case SongPlayMode.pause:
          if (_song != null) {
            //  prepare for the eventual restart
            if (_momentNumber != null) {
              _songStart = time - (_song?.getSongTimeAtMoment(_momentNumber!) ?? 0);
            }
          }
          break;
      }

      if (dt > 0.2) {
        logger.log(_songMasterLogTicker, 'dt time: $time, ${dt.toStringAsFixed(3)}');
      }
      _lastTime = time;
      int delta = elapsed.inMicroseconds - _lastElapsedUs;
      if (delta > _maxDelta) {
        _maxDelta = delta;
        logger.log(
            _songMasterLogMaxDelta,
            '_maxDelta: ${_maxDelta.toDouble() / Duration.microsecondsPerMillisecond} ms'
            //  ', dt: ${dt.toStringAsFixed(3)}'
            ', mode: ${songPlayMode.name}');
        if (_maxDelta > 60 * Duration.microsecondsPerMillisecond) {
          _maxDelta = 0;
        }
      }
      logger.log(_songMasterLogDelta, 'delta: $delta ms, dt: ${dt.toStringAsFixed(3)}');
      _lastElapsedUs = elapsed.inMicroseconds;
    });

    _ticker.start();
  }

  _clearMomentNumber() {
    _momentNumber = null;
    _advancedMomentNumber = null;
  }

  /// Play a song in real time
  void playSong(final Song song, //
      {DrumParts? drumParts,
      int? bpm}) {
    _song = song.copySong(); //  allow for play modifications
    _bpm = bpm ?? song.beatsPerMinute;
    _song?.setBeatsPerMinute(_bpm);
    _drumParts = drumParts;
    _songStart = _appAudioPlayer.getCurrentTime() + _advanceS;
    _clearMomentNumber();
    songPlayMode = SongPlayMode.autoPlay;
    notifyListeners();
    logger.d('playSong: _bpm: $_bpm');
  }

  /// Play a drums in real time
  void playDrums(final DrumParts? drumParts, {int? bpm}) {
    _song = null;
    _bpm = bpm ?? MusicConstants.defaultBpm;
    _drumParts = drumParts;
    _songStart ??= _appAudioPlayer.getCurrentTime(); //   sync with existing if it's running
    _clearMomentNumber();
    songPlayMode = SongPlayMode.manualPlay;
    notifyListeners();
    logger.d('playSong: _bpm: $_bpm');
  }

  void stop() {
    switch (songPlayMode) {
      case SongPlayMode.autoPlay:
      case SongPlayMode.pause:
        songPlayMode = SongPlayMode.idle;
        _clearMomentNumber();
        notifyListeners();
        break;
      case SongPlayMode.manualPlay:
        songPlayMode = SongPlayMode.idle;
        notifyListeners();
        break;
      case SongPlayMode.idle:
        break;
    }
    _drumParts = null; //  stop the drums
  }

  void pause() {
    if (songPlayMode != SongPlayMode.pause) {
      songPlayMode = SongPlayMode.pause;
      notifyListeners();
    }
  }

  void resume() {
    if (songPlayMode == SongPlayMode.pause) {
      songPlayMode = SongPlayMode.autoPlay;
      notifyListeners();
    }
  }

  void _performDrumParts(double time, int bpm, final DrumParts drumParts) {
    //  fixme:  even beat parts likely don't work on 3/4 or 6/8
    int beats = min(_song?.timeSignature.beatsPerBar ?? DrumBeat.values.length, drumParts.beats);
    for (var drumPart in drumParts.parts) {
      var filePath = drumTypeToFileMap[drumPart.drumType] ?? 'audio/bass_0.mp3';
      for (var timing in drumPart.timings(time, bpm, beats)) {
        logger.log(
            _songMasterLogTickerDetails,
            'beat: ${drumPart.drumType.name}: '
            ' time: $time'
            ', timing: $timing'
            // ', path: $filePath'
            ', advance: ${time - _appAudioPlayer.getCurrentTime()}'
            //
            );
        _appAudioPlayer.play(filePath,
            when: timing,
            duration: 0.25, //fixme: temp
            volume: drumParts.volume);
      }
    }
    logger.log(
        _songMasterLogTicker,
        ' time: $time'
        ', beats: $beats'
        ', bpm: $_bpm'
        ', $drumParts'
        ', advance: ${time - _appAudioPlayer.getCurrentTime()}'
        //
        );
  }

  double? get songTime {
    double? ret = _song?.getSongTimeAtMoment(_momentNumber ?? 0);
    if (ret == null) {
      return null;
    }
    return ret + (_songStart ?? 0);
  }

  @override
  String toString() {
    return 'SongMaster{mode: ${songPlayMode.name}, _song: $_song, _moment: $_momentNumber }';
  }

  late Ticker _ticker;
  double _lastTime = 0;
  int _lastElapsedUs = 0;
  int _maxDelta = 0;

  int? get momentNumber => _momentNumber; //  can negative during preroll, will be null after the end
  int? _momentNumber;
  int? _advancedMomentNumber;

  SongPlayMode songPlayMode = SongPlayMode.idle;

  Song? _song;
  double? _songStart;
  static const double _advanceS = 1.0;

  int _bpm = MusicConstants.minBpm; //  default value only

  DrumParts? _drumParts;
  final AppAudioPlayer _appAudioPlayer = AppAudioPlayer();
}
