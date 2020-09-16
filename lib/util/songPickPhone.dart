import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/util/songPick.dart';
import 'package:file_picker/file_picker.dart';

class _Picker extends FilePicker {}

class SongPickPhone implements SongPick {
  Future<void> filePick() async {
    _Picker picker = _Picker();
    FilePickerResult result = await picker.pickFiles(allowedExtensions: ['.songlyrics']);
    for (final PlatformFile file in result.files) {
      logger.i('file: ${file.name}');
    }
  }
}

SongPick getSongPick() => SongPickPhone();
