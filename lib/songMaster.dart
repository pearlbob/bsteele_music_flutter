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

class SongMaster extends ChangeNotifier {
  static final SongMaster _singleton = SongMaster._internal();

  factory SongMaster() {
    return _singleton;
  }

  SongMaster._internal() {
    _ticker = Ticker((duration) {
      double time = _appAudioPlayer.getCurrentTime();
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
                _songMasterLogTicker,
                'SongMaster stop: ${songTime.toStringAsFixed(3)}'
                ', dt: ${dt.toStringAsFixed(3)}'
                ', moment: ${newMomentNumber.toString()}');
          } else {
            if (newMomentNumber != _momentNumber) {
              _momentNumber = newMomentNumber;
              if (_drumParts != null) {
                _playDrumParts(time, _bpm, _drumParts!); //fixme: one moment late?
              }
              logger.log(
                  _songMasterLogTicker,
                  //   'songTime: ${songTime.toStringAsFixed(3)}'
                  'time: ${time.toStringAsFixed(3)}'
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

      //logger.log(_songMasterLogTicker, 'time: $time, ${dt.toStringAsFixed(3)}');
      _lastTime = time;
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
            'beat: ${drumPart.drumType}: '
            ', time: $time, timing: $timing'
            ', path: $filePath');
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

  int? get momentNumber => _momentNumber; //  can negative during preroll, will be null after the end
  int? _momentNumber; //  for debug

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
