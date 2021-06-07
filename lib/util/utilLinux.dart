import 'dart:convert';
import 'dart:io';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordPro.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app.dart';

Directory _rootDirectory = Directory(Util.homePath());

/// Workaround to implement functionality that is not generic across all platforms at this point.
class UtilLinux implements UtilWorkaround {
  @override
  Future<String> writeFileContents(String fileName, String contents) async {
    //  not web stuff
    final directory = await getApplicationDocumentsDirectory();
    String path = directory.path;
    logger.d('path: $path');

    File file = File('$path/$fileName');
    logger.i('file: $file');

    try {
      await file.writeAsString(contents, flush: true);
    } catch (e) {
      return 'Error writing file to \'$file\': $e';
    }
    return 'file written to \'$file\'';
  }

  @override
  Future<void> filePick(BuildContext context) async {
    String? path = await FilesystemPicker.open(
      title: 'Open file',
      context: context,
      rootDirectory: _rootDirectory,
      fsType: FilesystemType.file,
      allowedExtensions: ['.songlyrics', '.pro', '.chordpro'],
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
    if (path != null) {
      var file = File(path);
      if (file.existsSync()) {
        String s = utf8.decode(file.readAsBytesSync());
        if (chordProRegExp.hasMatch(path)) {
          //  chordpro
          var song = ChordPro().parse(s);
          App().addSongs([song]);
        } else {
          //  .songlyrics
          List<Song> songs = Song.songListFromJson(s);
          App().addSongs(songs);
        }
        //  fixme: limits subsequent opens to the selected directory
        _rootDirectory = Directory(file.path.substring(0, file.path.lastIndexOf('/')));
      }
    } else {
      //  reset the root
      _rootDirectory = Directory(Util.homePath());
    }
    //  fixme: FilesystemPicker.open() in linux needs big help
  }

  final RegExp chordProRegExp = RegExp(r'pro$');
}

UtilWorkaround getUtilWorkaround() => UtilLinux();
