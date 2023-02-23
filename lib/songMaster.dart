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

import 'app/appOptions.dart';
import 'audio/app_audio_player.dart';

const Level _songMasterLogTicker = Level.debug; //kDebugMode ? Level.info : Level.debug;
const Level _songMasterLogTickerDetails = Level.debug;
const Level _songMasterLogDelta = Level.debug;
const Level _songMasterLogMaxDelta = Level.debug;
const Level _songMasterNotify = Level.debug;
const Level _songMasterLogAdvance = Level.debug;
const Level _logDrums = Level.debug;

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
          if (_drumParts != null && !drumsAreMuted) {
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
              var measureDuration = 60.0 * _song!.timeSignature.beatsPerBar / _song!.beatsPerMinute;
              double advanceTime = time - (_songStart ?? 0) + _advanceS;

              //  fixme: fix the start of playing!!!!!  after pause?
              int? newAdvancedMomentNumber = _song!.getSongMomentNumberAtSongTime(advanceTime);

              //  place audio in the audio player one moment (i.e. measure) in advance
              while (_advancedMomentNumber == null ||
                  (newAdvancedMomentNumber != null && newAdvancedMomentNumber >= _advancedMomentNumber!)) {
                _advancedMomentNumber ??= newAdvancedMomentNumber;
                logger.log(
                    _songMasterLogAdvance,
                    'new: $newAdvancedMomentNumber'
                    ', measureDuration: $measureDuration'
                    ', advance: ${advanceTime.toStringAsFixed(3)}'
                    ', mTime: ${((time - (_songStart ?? 0)) / measureDuration).toStringAsFixed(3)}'
                    //
                    );

                if (_drumParts != null && !drumsAreMuted) {
                  _performDrumParts(
                      (_songStart ?? 0) +
                          (_advancedMomentNumber! < 0
                              ? _advancedMomentNumber! * measureDuration
                              : _song!.getSongTimeAtMoment(_advancedMomentNumber!)),
                      _bpm,
                      _drumParts!);
                  logger.v('SongPlayMode.autoPlay: '
                      ' _advancedMomentNumber: ${_advancedMomentNumber!}'
                      //    '${(_songStart ?? 0)} + ${_song!.getSongTimeAtMoment(_advancedMomentNumber!)}'
                      );
                } else if (!drumsAreMuted) {
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
              //  note that this is in "realtime", i.e. slightly delayed, not advanced
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
                    _songMasterNotify,
                    'SongMaster stop: ${songTime.toStringAsFixed(3)}'
                    ', dt: ${dt.toStringAsFixed(3)}'
                    ', moment: ${newMomentNumber.toString()}');
              } else {
                // advance
                if (newMomentNumber != _momentNumber) {
                  _momentNumber = newMomentNumber;
                  notifyListeners();
                  logger.log(
                      _songMasterNotify,
                      'songTime notify: ${songTime.toStringAsFixed(3)}'
                      ' time: ${time.toStringAsFixed(3)}'
                      //  ', dt: ${dt.toStringAsFixed(3)}'
                      ', momentNumber: ${_momentNumber.toString()}');
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
    _measureDuration = 60 * song.timeSignature.beatsPerBar / _bpm;
    _song?.setBeatsPerMinute(_bpm);
    _drumParts = drumParts;
    _songStart =
        _appAudioPlayer.getCurrentTime() + _advanceS + (_appOptions.countIn ? _measureDuration * countInCount : 0);

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
        _appAudioPlayer.stop();
        notifyListeners();
        break;
      case SongPlayMode.manualPlay:
        songPlayMode = SongPlayMode.idle;
        _appAudioPlayer.stop();
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
    logger.v('_performDrumParts: $time - $_songStart = ${time - (_songStart ?? 0)}');
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
            volume: _appOptions.volume);
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

  int? get momentNumber => _momentNumber; //  can negative during count in, will be null after the end
  int? _momentNumber;
  int? _advancedMomentNumber;

  SongPlayMode songPlayMode = SongPlayMode.idle;

  Song? _song;
  double? _songStart;
  static const countInCount = countInMax;
  static const double _advanceS = 1.0;

  int _bpm = MusicConstants.minBpm; //  default value only
  double _measureDuration = 0;

  var drumsAreMuted = true;
  DrumParts? _drumParts;

  final _appOptions = AppOptions();
  final AppAudioPlayer _appAudioPlayer = AppAudioPlayer();
}

class SongMasterScheduler {
  void drum(DrumParts drumParts, int bpm) {
    drumParts = drumParts;
    beats = drumParts.beats;
    this.bpm = bpm;
    barT = Duration.secondsPerMinute * beats / bpm;
  }

  tick(double t) {
    logger.i('   tick: $bpm $beats t: $t s = ${(t / barT).toStringAsFixed(3)} bars'
        ', barT: $barT');
  }

  DrumParts? drumParts;
  double lastT = 0;
  double barT = 1.0;
  var beats = 4;
  var bpm = 160;
}
