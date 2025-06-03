@JS()
library;

import 'dart:js_interop';

extension type AudioFilePlayer._(JSObject _) implements JSObject {
  /// JavaScript audio file player dart interface for web/js/AudioFilePlayer.js
  external factory AudioFilePlayer();

  external bool bufferFile(String path);

  external bool play(String filePath, double when, double duration, double volume);

  external bool oscillate(double frequency, double when, double duration, double volume);

  external bool stop();

  external double getCurrentTime();

  external double getBaseLatency();

  external double getOutputLatency();

  external String test();
}
