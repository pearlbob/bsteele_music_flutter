import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/drumMeasure.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/widgets/drums.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logger/logger.dart';

import 'audio/app_audio_player.dart';

const Level _songMasterLogTicker = Level.debug;
const Level _songMasterLogDelta = Level.debug;
const Level _songMasterLogMaxDelta = Level.debug;

class SongMaster extends ChangeNotifier {
  static final SongMaster _singleton = SongMaster._internal();

  factory SongMaster() {
    return _singleton;
  }

  SongMaster._internal() {
    _ticker = Ticker((elapsed) {
      double time = _appAudioPlayer.getCurrentTime();
      double dt = time - _lastTime;

      if (_song != null) {
        if (_isPaused) {
          //  prepare for the eventual restart
          if (_momentNumber != null) {
            _songStart = time - (_song?.getSongTimeAtMoment(_momentNumber!) ?? 0);
          }
        } else if (_isPlaying) {
          {
            //  fixme: deal with a changing cadence!
            const double advanceS = 1.0;
            double songTime = time - (_songStart ?? 0) - (60.0 / _song!.beatsPerMinute).floor() + advanceS;
            logger.log(
                _songMasterLogTicker,
                'advance: ${songTime.toStringAsFixed(3)}'
                ' - ${(time - (_songStart ?? 0)).toStringAsFixed(3)}'
                ' = ${(songTime - (time - (_songStart ?? 0))).toStringAsFixed(3)}'
                //
                );
            //  fixme: fix the start of playing!!!!!  after pause?
            int? newAdvancedMomentNumber = _song!.getSongMomentNumberAtSongTime(songTime);
            while (_advancedMomentNumber == null ||
                (newAdvancedMomentNumber != null && newAdvancedMomentNumber >= _advancedMomentNumber!)) {
              _advancedMomentNumber ??= 0;
              if (_drumParts != null) {
                _playDrumParts(
                    (_songStart ?? 0) + _song!.getSongTimeAtMoment(_advancedMomentNumber!), _bpm, _drumParts!);
              }
              logger.log(
                  _songMasterLogTicker,
                  '${(time - (_songStart ?? 0)).toStringAsFixed(3)}: _advancedMomentNumber: $_advancedMomentNumber'
                  ' upto $newAdvancedMomentNumber');
              _advancedMomentNumber = _advancedMomentNumber! + 1;
            }
          }
          {
            double songTime = time - (_songStart ?? 0) - (60.0 / _song!.beatsPerMinute).floor();
            int? newMomentNumber = _song!.getSongMomentNumberAtSongTime(songTime);
            if (newMomentNumber == null) {
              //  stop
              _momentNumber = null;
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
                // if (_drumParts != null && _momentNumber != null) {
                //   _playDrumParts((_songStart ?? 0) + _song!.getSongTimeAtMoment(_momentNumber!), _bpm,
                //       _drumParts!); //fixme: one moment late?
                // }
                logger.log(
                    _songMasterLogTicker,
                    'songTime: ${songTime.toStringAsFixed(3)}'
                    ' time: ${time.toStringAsFixed(3)}'
                    //  ', dt: ${dt.toStringAsFixed(3)}'
                    ', moment: ${newMomentNumber.toString()}');
                notifyListeners();
              }
            }
          }
        } else if (_momentNumber != null) {
          _momentNumber = null;
          _advancedMomentNumber = null;
          notifyListeners();
        }
      } else if (_momentNumber != null) {
        _momentNumber = null;
        _advancedMomentNumber = null;
        notifyListeners();
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

  void playSong(final Song song, //
      {DrumParts? drumParts, //  fixme: temp
      int? bpm}) {
    _song = song.copySong(); //  allow for play modifications
    _bpm = bpm ?? song.beatsPerMinute;
    _song?.setBeatsPerMinute(_bpm);
    _drumParts = drumParts; //  fixme: temp
    _isPlaying = true;
    _isPaused = false;
    _songStart = _appAudioPlayer.getCurrentTime();
    _momentNumber = null;
    notifyListeners();
    logger.d('playSong: _bpm: $_bpm');
  }

  void stop() {
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
    }
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

  void _playDrumParts(double time, int bpm, final DrumParts drumParts) {
    for (var drumPart in drumParts.parts) {
      var filePath = drumTypeToFileMap[drumPart.drumType] ?? 'audio/bass_0.mp3';
      for (var timing in drumPart.timings(time, bpm)) {
        logger.log(
            _songMasterLogTicker,
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
  int _bpm = MusicConstants.minBpm; //  default value only

  DrumParts? _drumParts;
  final AppAudioPlayer _appAudioPlayer = AppAudioPlayer();
}
