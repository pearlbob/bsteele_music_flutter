import 'app_audio_player.dart';

class MockAudioPlayer implements AppAudioPlayer {
  @override
  double getCurrentTime() {
    return DateTime.now().microsecondsSinceEpoch / Duration.microsecondsPerSecond;
  }

  @override
  bool play(String filePath, {required double when, required double duration, required double volume}) {
    return false;
  }

  @override
  bool oscillate(double frequency, {required double when, required double duration, required double volume}) {
    return false;
  }

  @override
  bool stop() {
    return false;
  }

  @override
  String test() {
    return 'MobileAudioPlayer fixme';
  }
}

AppAudioPlayer getAudioPlayer() => MockAudioPlayer();
