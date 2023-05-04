// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/drum_measure.dart';
import 'package:bsteele_music_flutter/audio/app_audio_player.dart';
import 'package:bsteele_music_flutter/util/jsAudioFilePlayer.dart';

import '../widgets/drums.dart';

class WebAudioPlayer implements AppAudioPlayer {
  //  private constructor for singleton
  WebAudioPlayer._privateConstructor() {
    try {
//      for (final Pitch pitch in Pitch.flats) {
//        String s = 'audio/Piano.mf.${pitch.getScaleNote().toMarkup()}${pitch.getLabelNumber().toString()}.mp3';
//        logger.i('piano: $s');
//        _audioFilePlayer.bufferFile(s);
//      }
      for (int i = 0; i < 40; i++) {
        String path = 'audio/bass_$i.mp3';
        _audioFilePlayer.bufferFile(path);
      }
      for (int i = 0; i <= 30; i++) {
        String path = 'audio/guitar_$i.mp3';
        _audioFilePlayer.bufferFile(path);
      }
      const defaultFile = 'audio/hihat1.flac';
      _audioFilePlayer.bufferFile(drumTypeToFileMap[DrumTypeEnum.closedHighHat] ?? defaultFile);
      _audioFilePlayer.bufferFile(drumTypeToFileMap[DrumTypeEnum.openHighHat] ?? defaultFile);
      _audioFilePlayer.bufferFile(drumTypeToFileMap[DrumTypeEnum.kick] ?? defaultFile);
      _audioFilePlayer.bufferFile(drumTypeToFileMap[DrumTypeEnum.bass] ?? defaultFile);
      _audioFilePlayer.bufferFile(drumTypeToFileMap[DrumTypeEnum.snare] ?? defaultFile);

      logger.i('audio: getBaseLatency= ${_audioFilePlayer.getBaseLatency()}');
    } catch (e) {
      logger.e('exception: ${e.toString()}');
    }
  }

  factory WebAudioPlayer() {
    return _instance;
  }

  @override
  double getCurrentTime() {
    return _audioFilePlayer.getCurrentTime();
  }

  @override
  double get latency => _audioFilePlayer.getBaseLatency();

  @override
  bool play(String filePath, {required double when, required double duration, required double volume}) {
    return _audioFilePlayer.play(filePath, when, duration, volume);
  }

  @override
  bool oscillate(double frequency, {required double when, required double duration, required double volume}) {
    return _audioFilePlayer.oscillate(frequency, when, duration, volume);
  }

  @override
  bool stop() {
    return _audioFilePlayer.stop();
  }

  @override
  String test() {
    return 'WebAudioPlayer here';
  }

  static final WebAudioPlayer _instance = WebAudioPlayer._privateConstructor();
  final JsAudioFilePlayer _audioFilePlayer = JsAudioFilePlayer();

  //  fixme: bogus use of dart html to keep android studio happy with conditional compile workaround
  final File? file = null;
}

AppAudioPlayer getAudioPlayer() => WebAudioPlayer();
