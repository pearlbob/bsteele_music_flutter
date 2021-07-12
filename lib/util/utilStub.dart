import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/widgets.dart';

class NullWorkaround implements UtilWorkaround {
  @override
  Future<String> writeFileContents(String fileName, String contents) async {
    throw 'Error writing file to \'$fileName\': not implemented!';
  }

  @override
  Future<void> songFilePick(BuildContext context) async {
    return Future<void>(() {});
  }

  @override
  Future<List<String>> textFilePickAndRead(BuildContext context) {
    return Future<List<String>>(() {
      return [''];
    });
  }

  @override
  Future<void> songMetadataFilePick(BuildContext context) {
    // TODO: implement songMetadataFilePick
    throw UnimplementedError();
  }
}

/// Workaround to implement functionality that is not generic across all platforms at this point.
/// A stub just to force the selection of the correct implementing class for the platform.
UtilWorkaround getUtilWorkaround() {
  return NullWorkaround();
}
