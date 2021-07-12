import 'package:bsteele_music_flutter/main.dart' as bsteele_music_app;
import 'package:flutter_driver/driver_extension.dart';

void main() {
  // This line enables the extension.
  enableFlutterDriverExtension();

  // Call the `main()` function of the app, or call `runApp` with
  // any widget you are interested in testing.
  bsteele_music_app.main();
}