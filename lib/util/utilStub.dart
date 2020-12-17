import 'package:bsteele_music_flutter/util/utilWorkaround.dart';

class NullWorkaround implements UtilWorkaround {

  void writeFileContents(String fileName, String contents) async {
  }

  Future<void> filePick() async {
    return Future<void>((){});
  }
}

/// Workaround to implement functionality that is not generic across all platforms at this point.
/// A stub just to force the selection of the correct implementing class for the platform.
UtilWorkaround getUtilWorkaround() {
  return NullWorkaround();
}
