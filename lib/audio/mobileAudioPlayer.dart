import 'appAudioPlayer.dart';


class MobileAudioPlayer implements AppAudioPlayer {

  @override
  double getCurrentTime() {
    return 0;
  }

  @override
  bool play(String filePath, double when, double duration, double volume) {
    return false;
  }

  @override
  bool oscillate(double frequency, double when, double duration, double volume) {
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

AppAudioPlayer getAudioPlayer() => MobileAudioPlayer();
