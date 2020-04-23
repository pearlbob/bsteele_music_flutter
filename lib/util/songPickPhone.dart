import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/util/songPick.dart';
import 'package:file_picker/file_picker.dart';


class SongPickPhone implements SongPick {
  Future<void> filePick() async {
    Map<String, String> fileMap =
    await FilePicker.getMultiFilePath(allowedExtensions: ['.songlyrics']);
    for (final String filename in fileMap.keys) {
      logger.i('file: $filename');
    }
  }
}

SongPick getSongPick() => SongPickPhone();
