import 'audio_player_stub.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) 'package:bsteele_music_flutter/audio/mock_audio_player.dart'
// ignore: uri_does_not_exist
    if (dart.library.html) 'package:bsteele_music_flutter/audio/web_audio_player.dart';

abstract class AppAudioPlayer {
  bool play(String filePath, {required double when, required double duration, required double volume});

  bool oscillate(double frequency, {required double when, required double duration, required double volume});

  bool stop();

  /// current audio time in seconds
  double getCurrentTime();

  String test();

  /// factory constructor to return the correct implementation.
  factory AppAudioPlayer() => getAudioPlayer();
}
