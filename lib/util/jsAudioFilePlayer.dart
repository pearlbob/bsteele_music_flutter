@JS()
library js_audio_file_player;

import 'package:js/js.dart';

@JS('AudioFilePlayer')
class JsAudioFilePlayer {

  external factory JsAudioFilePlayer();

  external bool bufferFile(String path);

  external bool play(String filePath, double when, double duration);

  external bool oscillate(double frequency, double when, double duration);

  external bool stop();

  external double getCurrentTime();

  external double getBaseLatency();

  external double getOutputLatency();

  external String test();
}