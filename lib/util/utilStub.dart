import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_metadata.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/widgets.dart';

class NullWorkaround implements UtilWorkaround {
  @override
  Future<String> writeFileContents(String fileName, String contents, {String? fileType}) async {
    throw 'Error writing file to \'$fileName\': not implemented!';
  }

  @override
  Future<List<Song>> songFilePick(BuildContext context) async {
    return Future<List<Song>>(() {
      return [];
    });
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

  @override
  bool get fullscreenEnabled => false;

  @override
  void requestFullscreen() {}

  @override
  void exitFullScreen() {}

  @override
  bool get isFullScreen {
    return false;
  }
}

/// Workaround to implement functionality that is not generic across all platforms at this point.
/// A stub just to force the selection of the correct implementing class for the platform.
UtilWorkaround getUtilWorkaround() {
  return NullWorkaround();
}
