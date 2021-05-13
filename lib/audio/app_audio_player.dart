import 'audio_player_stub.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) 'package:bsteele_music_flutter/audio/mobile_audio_player.dart'
// ignore: uri_does_not_exist
    if (dart.library.html) 'package:bsteele_music_flutter/audio/web_audio_player.dart';

abstract class AppAudioPlayer {
  bool play(String filePath, double when, double duration, double volume);

  bool oscillate(double frequency, double when, double duration, double volume);

  bool stop();

  double getCurrentTime();

  String test();

  /// factory constructor to return the correct implementation.
  factory AppAudioPlayer() => getAudioPlayer();
}
