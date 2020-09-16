import 'dart:io';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class _Picker extends FilePicker {}

/// Workaround to implement functionality that is not generic across all platforms at this point.
class UtilLinux implements UtilWorkaround {

  void writeFileContents(String fileName, String contents) async {
    //  not web stuff
    final directory = await getApplicationDocumentsDirectory();
    String path = directory.path;
    logger.d('path: $path');

    File file = File('$path/$fileName');
    logger.d('file: $file');
    await file.writeAsString(contents, flush: true);
  }

  Future<void> filePick() async {
    _Picker picker = _Picker();
    FilePickerResult result = await picker.pickFiles(allowedExtensions: ['.songlyrics']);
    for (final PlatformFile file in result.files) {
      logger.i('file: ${file.name}');
    }
  }
}


UtilWorkaround getUtilWorkaround() => UtilLinux();
