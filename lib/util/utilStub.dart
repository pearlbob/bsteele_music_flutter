import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/widgets.dart';

class NullWorkaround implements UtilWorkaround {
  @override
  Future<String> writeFileContents(String fileName, String contents, {String? fileType}) async {
    throw 'Error writing file to \'$fileName\': not implemented!';
  }

  @override
  Future<List<Song>> songFilePick(BuildContext context) async {
    return Future<List<Song>>(() { return [];});
  }

  @override
  Future<List<NameValue>> textFilePickAndRead(BuildContext context) {
    // implement songMetadataFilePick
    throw UnimplementedError();
  }

  @override
  Future<String> filePickByExtension(BuildContext context, String extension) {
    // implement songMetadataFilePick
    throw UnimplementedError();
  }
}

/// Workaround to implement functionality that is not generic across all platforms at this point.
/// A stub just to force the selection of the correct implementing class for the platform.
UtilWorkaround getUtilWorkaround() {
  return NullWorkaround();
}
