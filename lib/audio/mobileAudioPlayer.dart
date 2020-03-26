import 'appAudioPlayer.dart';


class MobileAudioPlayer implements AppAudioPlayer {

  @override
  double getCurrentTime() {
    // TODO: implement getCurrentTime
    throw UnimplementedError('MobileAudioPlayer');
  }

  @override
  bool play(String filePath, double when, double duration) {
    // TODO: implement play
    throw UnimplementedError('MobileAudioPlayer');
  }

  @override
  bool oscillate(double frequency, double when, double duration) {
    throw UnimplementedError('MobileAudioPlayer');
  }

  @override
  bool stop() {
    // TODO: implement stop
    throw UnimplementedError('MobileAudioPlayer');
  }

  @override
  String test() {
    // TODO: implement test
    throw UnimplementedError('MobileAudioPlayer');
  }
  
}

AppAudioPlayer getAudioPlayer() => MobileAudioPlayer();
