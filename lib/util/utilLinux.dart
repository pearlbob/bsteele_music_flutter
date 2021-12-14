import 'dart:convert';
import 'dart:io';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordPro.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app.dart';

Directory _rootDirectory = Directory(Util.homePath());

/// Workaround to implement functionality that is not generic across all platforms at this point.
class UtilLinux implements UtilWorkaround {
  @override
  Future<String> writeFileContents(String fileName, String contents, {String? fileType}) async {
    //  not web stuff
    final directory = await getApplicationDocumentsDirectory();
    String path = directory.path;
    logger.d('path: $path');

    File file = File('$path/$fileName');
    logger.d('file: $file');

    try {
      await file.writeAsString(contents, flush: true);
    } catch (e) {
      return 'Error writing file to \'$file\': $e';
    }
    return '${fileType ?? ''} file written to \'${file.path}\'';
  }

  @override
  Future<void> songFilePick(BuildContext context) async {
    String? path = await FilesystemPicker.open(
      title: 'Open song file',
      context: context,
      rootDirectory: _rootDirectory,
      fsType: FilesystemType.file,
      allowedExtensions: ['.songlyrics', '.pro', '.chordpro'],
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
    if (path != null) {
      var file = File(path);
      final app = App();
      if (file.existsSync()) {
        String s = utf8.decode(file.readAsBytesSync());
        if (chordProRegExp.hasMatch(path)) {
          //  chordpro
          var song = ChordPro().parse(s);
          app.addSongs([song]);
        } else {
          //  .songlyrics
          List<Song> songs = Song.songListFromJson(s);
          app.addSongs(songs);
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

  @override
  Future<List<NameValue>> textFilePickAndRead(BuildContext context) async {
    String? path = await FilesystemPicker.open(
      title: 'Open file',
      context: context,
      rootDirectory: _rootDirectory,
      fsType: FilesystemType.file,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
    if (path != null) {
      var file = File(path);
      if (file.existsSync()) {
        String s = utf8.decode(file.readAsBytesSync());
        //  fixme: limits subsequent opens to the selected directory
        _rootDirectory = Directory(file.path.substring(0, file.path.lastIndexOf('/')));
        return [NameValue(path, s)];
      }
    } else {
      //  reset the root
      _rootDirectory = Directory(Util.homePath());
    }
    //  fixme: FilesystemPicker.open() in linux needs big help
    return [];
  }

  @override
  Future<String> filePickByExtension(BuildContext context, String extension) async {
    String? path = await FilesystemPicker.open(
      title: 'Open metadata file',
      context: context,
      rootDirectory: _rootDirectory,
      fsType: FilesystemType.file,
      allowedExtensions: [
        extension,
      ],
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
    if (path != null) {
      var file = File(path);
      if (file.existsSync()) {
        String s = utf8.decode(file.readAsBytesSync());

        //  fixme: limits subsequent opens to the selected directory
        _rootDirectory = Directory(file.path.substring(0, file.path.lastIndexOf('/')));
        return s;
      }
      return '';
    } else {
      //  reset the root
      _rootDirectory = Directory(Util.homePath());
      return '';
    }
    //  fixme: FilesystemPicker.open() in linux needs big help
  }
}

UtilWorkaround getUtilWorkaround() => UtilLinux();
