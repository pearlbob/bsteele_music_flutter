import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logger/logger.dart';

import 'audio/app_audio_player.dart';

const Level _loggerLevel = Level.debug;

class SongMaster extends ChangeNotifier {
  static final SongMaster _singleton = SongMaster._internal();

  factory SongMaster() {
    return _singleton;
  }

  SongMaster._internal() {
    _ticker = Ticker((duration) {
      double time = appAudioPlayer.getCurrentTime();
      double dt = time - _lastTime;

      if (_song != null) {
        if (_isPaused) {
          //  prepare for the eventual restart
          if (_momentNumber != null) {
            _songStart = time - (_song?.getSongTimeAtMoment(_momentNumber!) ?? 0);
          }
        } else if (_isPlaying) {
          double songTime = time - (_songStart ?? 0);
          int? newMomentNumber = _song!.getSongMomentNumberAtSongTime(songTime);
          if (newMomentNumber == null) {
            _momentNumber = null;
            _isPlaying = false;
            notifyListeners();
            logger.log(
                _loggerLevel,
                'SongMaster stop: ${songTime.toStringAsFixed(3)}'
                ', dt: ${dt.toStringAsFixed(3)}'
                ', moment: ${newMomentNumber.toString()}');
          } else {
            if (newMomentNumber != _momentNumber) {
              _momentNumber = newMomentNumber;
              logger.log(
                  _loggerLevel,
                  'songTime: ${songTime.toStringAsFixed(3)}'
                  ', dt: ${dt.toStringAsFixed(3)}'
                  ', moment: ${newMomentNumber.toString()}');
              notifyListeners();
            }
          }
        } else if (_momentNumber != null) {
          _momentNumber = null;
          notifyListeners();
        }
      } else if (_momentNumber != null) {
        _momentNumber = null;
        notifyListeners();
      }

      //logger.log(_loggerLevel, 'time: $time, ${dt.toStringAsFixed(3)}');
      _lastTime = time;
    });

    _ticker.start();
  }

  void playSong(Song song) {
    _song = song;
    _isPlaying = true;
    _isPaused = false;
    _songStart = appAudioPlayer.getCurrentTime();
    _momentNumber = null;
    notifyListeners();
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

  @override
  String toString() {
    return 'SongMaster{_song: $_song, _moment: $_momentNumber, _isPlaying: $_isPlaying, _isPaused: $_isPaused, }';
  }

  late Ticker _ticker;
  double _lastTime = 0;

  int? get momentNumber => _momentNumber; //  can negative during preroll, will be null after the end
  int? _momentNumber; //  for debug

  AppAudioPlayer appAudioPlayer = AppAudioPlayer();

  bool get isPlaying => _isPlaying;
  bool _isPlaying = false;

  bool get isPaused => _isPaused;
  bool _isPaused = false;
  Song? _song;
  double? _songStart;
}
