import 'dart:math';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/drum_measure.dart';
import 'package:bsteeleMusicLib/songs/music_constants.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/widgets/drums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logger/logger.dart';

import 'audio/app_audio_player.dart';

const Level _songMasterLogTicker = Level.info;
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

      // int beats = _song?.timeSignature.beatsPerBar ?? _drumParts?.beats ?? 4;
      // int tempMomentNumber = //
      //     _songStart == null
      //         ? -4
      //         : (_songStart! > time
      //             ? // preroll, should be negative
      //             ((time - _songStart!) ~/ (_song?.secondsPerMeasure ?? (60.0 * beats / _bpm)))
      //             : _song?.getSongMomentNumberAtSongTime(time-_songStart!) ?? 0);
      // logger.i('tempMomentNumber: $tempMomentNumber, songtime: ${time-(_songStart??0)}');

      if (_song != null) {
        if (_isPaused) {
          //  prepare for the eventual restart
          if (_momentNumber != null) {
            _songStart = time - (_song?.getSongTimeAtMoment(_momentNumber!) ?? 0);
          }
        } else if (_isPlaying) {
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
              _isPlaying = false;
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
        } else if (_momentNumber != null) {
          _clearMomentNumber();
          notifyListeners();
        }
      } else if (_momentNumber != null) {
        _clearMomentNumber();
        notifyListeners();
      }

      //  play drums only
      if (_song == null && _drumParts != null) {
        var drumTime = time - (_songStart ?? time);
        var measureDuration = 60.0 / _bpm * _drumParts!.beats;
        if (drumTime > measureDuration) {
          _songStart = (_songStart ?? time) + measureDuration;
          logger.log(_logDrums, 'play: $_drumParts at $_bpm at ${_songStart! + _advanceS} from $time');
          _performDrumParts(_songStart! + _advanceS, _bpm, _drumParts!);
        }
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
            ', _isPlaying: $_isPlaying');
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
    _isPaused = false;
    _isPlaying = true;
    notifyListeners();
    logger.d('playSong: _bpm: $_bpm');
  }

  /// Play a drums in real time
  void playDrums(DrumParts? drumParts, {int? bpm}) {
    _song = null;
    _bpm = bpm ?? MusicConstants.defaultBpm;
    _drumParts = drumParts;
    _songStart ??= _appAudioPlayer.getCurrentTime(); //   sync with existing if it's running
    _clearMomentNumber();
    _isPaused = false;
    _isPlaying = true;
    notifyListeners();
    logger.d('playSong: _bpm: $_bpm');
  }

  void stop() {
    if (_isPlaying) {
      _isPlaying = false;
      _clearMomentNumber();
      notifyListeners();
    }
    _drumParts = null; //  stop the drums
  }

  void pause() {
    if (!_isPaused) {
      _isPaused = true;
      notifyListeners();
    }
  }

  void resume() {
    if (_isPaused) {
      _isPaused = false;
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
    return 'SongMaster{_song: $_song, _moment: $_momentNumber, _isPlaying: $_isPlaying, _isPaused: $_isPaused, }';
  }

  late Ticker _ticker;
  double _lastTime = 0;
  int _lastElapsedUs = 0;
  int _maxDelta = 0;

  int? get momentNumber => _momentNumber; //  can negative during preroll, will be null after the end
  int? _momentNumber;
  int? _advancedMomentNumber;

  bool get isPlaying => _isPlaying;
  bool _isPlaying = false;

  bool get isPaused => _isPaused;
  bool _isPaused = false;
  Song? _song;
  double? _songStart;
  static const double _advanceS = 1.0;

  int _bpm = MusicConstants.minBpm; //  default value only

  DrumParts? _drumParts;
  final AppAudioPlayer _appAudioPlayer = AppAudioPlayer();
}
