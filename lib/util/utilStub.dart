import 'package:bsteele_music_flutter/util/utilWorkaround.dart';

class NullWorkaround implements UtilWorkaround {

  Future<String> writeFileContents(String fileName, String contents) async {
    throw 'Error writing file to \'$fileName\': not implemented!';
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
