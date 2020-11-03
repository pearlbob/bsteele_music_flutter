import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:flutter/scheduler.dart';

// import 'audio/appAudioPlayer.dart';

class SongMaster {
  static final SongMaster _singleton = SongMaster._internal();

  factory SongMaster() {
    return _singleton;
  }

  SongMaster._internal() {
    _ticker = Ticker((duration) {
      // double time = appAudioPlayer.getCurrentTime();
      // double dt = time - _lastTime;
      //
      // if (_song != null) {
      //   if (_isPlaying) {
      //     if (_isPaused) {
      //     } else {
      //       double songTime = time - _songStart;
      //       int moment = _song.getSongMomentNumberAtSongTime(songTime);
      //       logger.v('moment: ${moment.toString()}');
      //     }
      //   }
      // }
      //
      // logger.v('dt $_tickerCount: ${dt.toStringAsFixed(3)}');
      // _lastTime = time;
      _tickerCount++;
    });
    _ticker.start();
  }

  void playSong(Song song) {
    _song = song;
    _isPlaying = true;
    _isPaused = false;
    //_songStart = appAudioPlayer.getCurrentTime();
  }

  void stop() {
    _isPlaying = false;
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  Ticker _ticker;
  static int _tickerCount = 0;
  double _lastTime = 0;

  //AppAudioPlayer appAudioPlayer = AppAudioPlayer();

  get isPlaying => _isPlaying;
  bool _isPlaying = false;

  get isPaused => _isPaused;
  bool _isPaused = false;
  Song _song;
  double _songStart;
}
