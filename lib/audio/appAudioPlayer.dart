import 'audioPlayerStub.dart'
// ignore: uri_does_not_exist
    if (dart.library.io) 'package:bsteele_music_flutter/audio/mobileAudioPlayer.dart'
// ignore: uri_does_not_exist
    if (dart.library.html) 'package:bsteele_music_flutter/audio/webAudioPlayer.dart';

abstract class AppAudioPlayer {
  bool play(String filePath, double when, double duration);

  bool oscillate(double frequency, double when, double duration);

  bool stop();

  double getCurrentTime();

  String test();

  /// factory constructor to return the correct implementation.
  factory AppAudioPlayer() => getAudioPlayer();
}
