import 'dart:math';

import 'package:bsteele_music_flutter/widgets/drums.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/drum_measure.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_update.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logger/logger.dart';

import 'app/appOptions.dart';
import 'audio/app_audio_player.dart';

const Level _logSongMasterTicker = Level.debug; //kDebugMode ? Level.info : Level.debug;
const Level _songMasterLogTickerDetails = Level.debug;
const Level _songMasterLogDelta = Level.debug;
const Level _songMasterLogMaxDelta = Level.debug;
const Level _songMasterNotify = Level.debug;
const Level _songMasterLogAdvance = Level.debug;
const Level _songMasterBpmChange = Level.debug;
const Level _logRestart = Level.debug;
const Level _logDrums = Level.debug;
const Level _logTime = Level.info;

class SongMaster extends ChangeNotifier {
  static final SongMaster _singleton = SongMaster._internal();

  factory SongMaster() {
    return _singleton;
  }

  SongMaster._internal() {
    _ticker = Ticker((elapsed) {
      final sysTime1 = DateTime.now(); // fixme: temp diagnostic only
      final double time = _appAudioPlayer.getCurrentTime();
      final sysTime2 = DateTime.now(); // fixme: temp diagnostic only
      final double dt = time - _lastTime;
      //logger.i('$time, _lastTime: $_lastTime, dt: $dt');
      _lastTime = time;
      final songTime = time - (_songStart ?? 0);

      int momentNumber;
      switch (songUpdateState) {
        case SongUpdateState.pause:
          momentNumber = _momentNumber ?? -1;
          break;
        case SongUpdateState.drumTempo:
          assert(_bpm >= MusicConstants.minBpm);
          double tempoPeriod = 60.0 / _bpm; //  seconds
          if ((time - _lastDrumTempoT) > tempoPeriod) {
            double nextTempoT = _lastDrumTempoT + 2 * tempoPeriod;

            _appAudioPlayer.play(drumTypeToFileMap[DrumTypeEnum.closedHighHat] ?? 'audio/hihat1.flac',
                when: nextTempoT,
                duration: 0.25, //fixme: temp
                volume: _appOptions.volume);

            //  clean up for the next request
            _lastDrumTempoT = _lastDrumTempoT + tempoPeriod;
            logger.log(
                _logDrums,
                'drumTempo: next: $nextTempoT, _lastDrumTempoT: $_lastDrumTempoT'
                ', dt: ${nextTempoT - _lastDrumTempoT}, tempoPeriod: $tempoPeriod');
            _lastDrumTempoT = _lastDrumTempoT + tempoPeriod;
          }
          return; //  we're done with the song... tempo preview
        default:
          momentNumber = _song?.getSongMomentNumberAtSongTime(songTime, bpm: _bpm) ?? -1;
          break;
      }

      var lyricSectionIndex = momentNumber >= 0 ? _song?.getSongMoment(momentNumber)?.lyricSection.index : null;

      logger.log(
          _logSongMasterTicker,
          'SongMaster: ${songUpdateState.name} $time: dt: ${dt.toStringAsFixed(3)}, songTime: $songTime'
          ', start: $_songStart, momentNumber: $momentNumber, lyricSectionIndex: $lyricSectionIndex');

      //  update the bpm
      if (_newBpm != null) {
        //   logger.i('\n_bpm: $_bpm, _newBpm: $_newBpm');
        if (_song != null && momentNumber >= 0) {
          double beat = (time - (_songStart ?? 0)) * _bpm / 60.0;
          logger.log(_songMasterBpmChange,
              'resetBpm(): beat: $beat, beatNumber: ${_song?.songMoments[momentNumber].beatNumber}');
          logger.log(_songMasterBpmChange, '   old _songStart: $_songStart');
          // 60.0 * beat = (time - (_songStart ?? 0)) * _bpm
          // ( 60.0 * beat ) / _bpm  = time - _songStart
          // ( 60.0 * beat ) / _bpm - time =  - _songStart
          _songStart = time - (60.0 * beat) / _newBpm!;
          logger.log(_songMasterBpmChange, '   new _songStart: $_songStart');
        }

        _bpm = _newBpm!;
        _newBpm = null;
        _song?.setBeatsPerMinute(_bpm);
      }

      //  skip to the moment number scrolled to
      if (_skipToMomentNumber != null) {
        _skipCurrentSection = false;
        _repeatSection = 0; //  cancel any confusion
        momentNumber = _skipToMomentNumber!;
        _skipToMomentNumber = null;
        _resetSongStart(time, momentNumber);
        _advancedMomentNumber = momentNumber; //fixme!!!!!!!!
        logger.log(_songMasterLogAdvance, 'skip to momentNumber:  $momentNumber');
        notifyListeners();
      }

      //  skip the current section if asked
      if (_skipCurrentSection) {
        _skipCurrentSection = false;
        _repeatSection = 0; //  cancel any confusion
        logger.log(_songMasterLogAdvance, 'skip: from $_momentNumber ');
        if (_song != null && momentNumber >= 0) {
          var moment = _song!.getSongMoment(momentNumber);
          if (moment != null) {
            //  find the next lyric section
            var size = _song!.getSongMomentsSize();
            while (moment?.lyricSection.index == lyricSectionIndex) {
              momentNumber++;
              if (momentNumber >= size - 1) {
                break; //  already at last
              }
              moment = _song!.getSongMoment(momentNumber);
              if (moment == null) {
                break;
              }
            }
            logger.log(_songMasterLogAdvance, 'skip: $_momentNumber to ${moment?.momentNumber}');
            if (moment != null) {
              momentNumber = moment.momentNumber;
              _resetSongStart(time, momentNumber);
              _advancedMomentNumber = momentNumber; //fixme!!!!!!!!
              logger.log(_songMasterLogAdvance,
                  'skip from index $lyricSectionIndex to $moment in ${moment.lyricSection.index}');
              notifyListeners();
            }
          }
        }
      }

      //  repeat sections when the current has ended
      if (_repeatSection > 0 && lyricSectionIndex != _lastSectionIndex) {
        logger.log(_songMasterLogAdvance, '_repeatSection: $_repeatSection, lyricSectionIndex: $lyricSectionIndex');
        _repeatSection = Util.intLimit(_repeatSection, 1, 2); //  limit the number of sections to repeat
        while (_repeatSection > 0 && momentNumber > 0) {
          momentNumber--;
          var index = momentNumber >= 0 ? _song?.getSongMoment(momentNumber)?.lyricSection.index : null;
          // logger.log(_songMasterLogAdvance, '_repeatSection: looking: $momentNumber, index: $index');
          if (index != lyricSectionIndex) {
            _repeatSection--;
            lyricSectionIndex = index;
            momentNumber = _song?.getFirstSongMomentInSection(momentNumber)?.momentNumber ?? 0;
          }
        }
        logger.log(_songMasterLogAdvance,
            '_repeatSection: back to section: $lyricSectionIndex at momentNumber: $momentNumber');
        _resetSongStart(time, momentNumber);
      }

      _lastSectionIndex = lyricSectionIndex;
      if (_lastMomentNumber == momentNumber) {
        return;
      }
      _lastMomentNumber = momentNumber;
      logger.log(_logSongMasterTicker,
          'SongMaster: ${songUpdateState.name}:  moment: $momentNumber, lyric: $_lastSectionIndex');

      switch (songUpdateState) {
        case SongUpdateState.none:
        case SongUpdateState.idle:
          _clearMomentNumberIfRequired();
          break;
        case SongUpdateState.drumTempo:
          _clearMomentNumberIfRequired();
          break;
        case SongUpdateState.playing:
          if (_song != null) {
            {
              //  fixme: deal with a changing cadence!

              //  pre-load the song audio by the advance time
              var measureDuration = 60.0 * _song!.timeSignature.beatsPerBar / _song!.beatsPerMinute;
              double advanceTime = time - (_songStart ?? 0) + _advanceS;

              //  fixme: fix the start of playing!!!!!  after pause?
              int? newAdvancedMomentNumber = _song!.getSongMomentNumberAtSongTime(advanceTime, bpm: _bpm);

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
                  logger.t('SongPlayMode.autoPlay: '
                      ' _advancedMomentNumber: ${_advancedMomentNumber!}'
                      //    '${(_songStart ?? 0)} + ${_song!.getSongTimeAtMoment(_advancedMomentNumber!)}'
                      );
                } else if (!drumsAreMuted) {
                  logger.i('no _drumParts!');
                }
                logger.log(
                    _logSongMasterTicker,
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
              int? newMomentNumber = _song!.getSongMomentNumberAtSongTime(songTime, bpm: _bpm);
              if (newMomentNumber == null) {
                //  stop
                _clearMomentNumber();
                songUpdateState = SongUpdateState.idle;
                notifyListeners();
                logger.log(
                    _songMasterNotify,
                    'SongMaster stop: ${songTime.toStringAsFixed(3)}'
                    ', dt: ${dt.toStringAsFixed(3)}'
                    ', moment: ${newMomentNumber.toString()}');
              } else {
                // advance
                momentNumber = newMomentNumber;
              }
            }
          }

          if (momentNumber != _momentNumber) {
            _momentNumber = momentNumber;
            notifyListeners();
          }
          break;

        case SongUpdateState.pause:
          if (_song != null) {
            //  prepare for the eventual restart
            if (_momentNumber != null) {
              _resetSongStart(time, momentNumber);
            }
          }
          break;
      }

      if (dt > 0.2) {
        logger.log(_logSongMasterTicker, 'dt time: $time, ${dt.toStringAsFixed(3)}');
      }

      int deltaUs = elapsed.inMicroseconds - _lastElapsedUs;
      if (deltaUs > _maxDelta) {
        _maxDelta = deltaUs;
        logger.log(
            _songMasterLogMaxDelta,
            '_maxDelta: ${_maxDelta.toDouble() / Duration.microsecondsPerMillisecond} ms'
            //  ', dt: ${dt.toStringAsFixed(3)}'
            ', mode: ${songUpdateState.name}');
        if (_maxDelta > 60 * Duration.microsecondsPerMillisecond) {
          _maxDelta = 0;
        }
      }
      logger.log(_songMasterLogDelta, 'delta: $deltaUs us, dt: ${dt.toStringAsFixed(3)}');
      _lastElapsedUs = elapsed.inMicroseconds;

      //  see how good the timing is
      {
        _timeAcquisitionDelay = sysTime2.microsecondsSinceEpoch - sysTime1.microsecondsSinceEpoch;
        _appAudioPlayerOffset = sysTime1.microsecondsSinceEpoch / Duration.microsecondsPerSecond - time;
        logger.log(
            _logTime,
            'time: _timeAcquisitionDelay: $_timeAcquisitionDelay, '
            '_appAudioPlayerOffset: $_appAudioPlayerOffset, ');
        if (_firstAppAudioPlayerOffset != null) {
          // logger.log(
          //     _logTime,
          print(// fixme!!!!!!!!!!!!!!!!
              'time: offset drift: '
              '${((_appAudioPlayerOffset - _firstAppAudioPlayerOffset!) * Duration.microsecondsPerSecond).toInt()} us');
        } else {
          _firstAppAudioPlayerOffset = _appAudioPlayerOffset;
        }
      }
    });

    _ticker.start();
  }

  _clearMomentNumberIfRequired() {
    if (_momentNumber != null) {
      _clearMomentNumber();
      notifyListeners();
    }
  }

  _clearMomentNumber() {
    _momentNumber = null;
    _advancedMomentNumber = null;
    _lastDrumTempoT = 0;
  }

  _resetSongStart(final double time, final int momentNumber) {
    if (_momentNumber != momentNumber) {
      logger.log(
          _logRestart, 'resetSongStart(): which moment?  _momentNumber: $_momentNumber,  momentNumber: $momentNumber');
    }
    // var beat = _song?.(time, bpm: _bpm);
    logger.log(_logRestart, 'resetSongStart(): old _songStart: $_songStart, _momentNumber: $_momentNumber');
    var oldSongStart = _songStart;
    _songStart = time - (_song?.getSongTimeAtMoment(momentNumber, beatsPerMinute: _bpm) ?? 0);
    logger.log(
        _logRestart,
        'resetSongStart(): new _songStart: $_songStart,  momentNumber: $momentNumber'
        ', ${(_songStart ?? 0) - (oldSongStart ?? 0)}');
    if (_momentNumber != momentNumber) {
      _momentNumber = momentNumber;
      notifyListeners();
    }

    final newSongTime = time - (_songStart ?? 0);
    var newMomentNumber = _song?.getSongMomentNumberAtSongTime(newSongTime, bpm: _bpm) ?? -1;
    if (newMomentNumber != momentNumber) {
      logger.log(_logRestart, 'newMomentNumber ?= momentNumber: $newMomentNumber != $momentNumber');
    }
  }

  /// tap the given tempo, typically prior to play
  tapTempo(int bpm) {
    switch (songUpdateState) {
      case SongUpdateState.none:
      case SongUpdateState.idle:
        _setBpm(bpm);
        songUpdateState = SongUpdateState.drumTempo;
        break;
      case SongUpdateState.drumTempo:
        _setBpm(bpm);
        break;
      default:
        break;
    }
  }

  _setBpm(int bpm) {
    _bpm = Util.intLimit(bpm, MusicConstants.minBpm, MusicConstants.maxBpm);
  }

  /// Play a song in real time
  playSong(final Song song, //
      {DrumParts? drumParts,
      int? bpm}) {
    _song = song.copySong(); //  allow for play modifications
    _bpm = bpm ?? song.beatsPerMinute;
    _song?.setBeatsPerMinute(_bpm);
    _drumParts = drumParts;
    _songStart = _appAudioPlayer.getCurrentTime() + _advanceS;

    _clearMomentNumber();
    songUpdateState = SongUpdateState.playing;
    notifyListeners();
    logger.d('_playSongMode: ${songUpdateState.name}, _bpm: $_bpm');
  }

  pauseToggle() {
    switch (songUpdateState) {
      case SongUpdateState.playing:
        // songUpdateState = SongUpdateState.pause;
        // notifyListeners();
        pause();
        break;
      case SongUpdateState.pause:
        //  setup for the restart
        resume();
        // _resetSongStart(_appAudioPlayer.getCurrentTime(), _momentNumber ?? -1);
        // songUpdateState = SongUpdateState.playing;
        // notifyListeners();
        break;
      default:
        break;
    }
  }

  skipCurrentSection() {
    _skipCurrentSection = true;
  }

  skipToMomentNumber(final int momentNumber) {
    _skipToMomentNumber = Util.intLimit(momentNumber, 0, (_song?.getSongMomentsSize() ?? 0) - 1);
  }

  /// Play a drums in real time
  void playDrums(final DrumParts? drumParts, {int? bpm}) {
    _song = null;
    _bpm = bpm ?? _song?.beatsPerMinute ?? MusicConstants.defaultBpm;
    _drumParts = drumParts;
    _songStart ??= _appAudioPlayer.getCurrentTime(); //   sync with existing if it's running
    _clearMomentNumber();
    songUpdateState = SongUpdateState.playing;
    notifyListeners();
    logger.d('playSong: _bpm: $_bpm');
  }

  void stop() {
    switch (songUpdateState) {
      case SongUpdateState.playing:
      case SongUpdateState.pause:
        songUpdateState = SongUpdateState.idle; //  for the running play
        _clearMomentNumber();
        _appAudioPlayer.stop();
        notifyListeners();
        break;
      case SongUpdateState.none:
      case SongUpdateState.idle:
        _clearMomentNumberIfRequired();
        break;
      case SongUpdateState.drumTempo:
        _clearMomentNumber();
        break;
    }
    songUpdateState = SongUpdateState.idle;
    _drumParts = null; //  stop the drums
  }

  void pause() {
    if (songUpdateState != SongUpdateState.pause) {
      songUpdateState = SongUpdateState.pause;
      notifyListeners();
    }
  }

  void resume() {
    if (songUpdateState == SongUpdateState.pause) {
      _resetSongStart(_appAudioPlayer.getCurrentTime(), _momentNumber ?? -1);
      songUpdateState = SongUpdateState.playing;
      notifyListeners();
    }
  }

  repeatSectionIncrement() {
    _repeatSection = Util.intLimit(_repeatSection + 1, 1, 2); //  limit the number of sections to repeat
  }

  void _performDrumParts(double time, int bpm, final DrumParts drumParts) {
    //  fixme:  even beat parts likely don't work on 3/4 or 6/8
    logger.t('_performDrumParts: $time - $_songStart = ${time - (_songStart ?? 0)}');
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
        _logSongMasterTicker,
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
    return 'SongMaster{mode: ${songUpdateState.name}, _song: $_song, _moment: $_momentNumber }';
  }

  late Ticker _ticker;
  double _lastTime = 0;
  int _lastElapsedUs = 0;
  int _maxDelta = 0;
  int _timeAcquisitionDelay = 0;
  double _appAudioPlayerOffset = 0; // in seconds
  double? _firstAppAudioPlayerOffset;

  int? get momentNumber => _momentNumber; //  can negative during count in, will be null after the end
  int? _momentNumber;

  int? get lastMomentNumber => _lastMomentNumber; //  can negative during count in, will be null after the end
  int? _lastMomentNumber;
  int? _advancedMomentNumber;
  bool _skipCurrentSection = false;
  int? _skipToMomentNumber;

  SongUpdateState songUpdateState = SongUpdateState.idle;

  Song? _song;
  double? _songStart;
  static const countInCount = countInMax;
  static const double _advanceS = 1.0;

  int get bpm => _bpm;
  int _bpm = MusicConstants.minBpm; //  default value only
  int? _newBpm;
  double _lastDrumTempoT = 0;

  int get repeatSection => _repeatSection;
  int _repeatSection = 0;
  int? _lastSectionIndex;

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
