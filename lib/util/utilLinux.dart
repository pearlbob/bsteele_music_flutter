import 'dart:convert';
import 'dart:io';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordPro.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

Directory _rootDirectory = Directory(Util.homePath());

/// Workaround to implement functionality that is not generic across all platforms at this point.
class UtilLinux implements UtilWorkaround {
  @override
  Future<String> writeFileContents(String fileName, String contents, {String? fileType}) async {
    //  not web stuff
    String path;
    final applicationDownloadsDirectory = await getDownloadsDirectory();
    if (applicationDownloadsDirectory?.path != null) {
      path = applicationDownloadsDirectory!.path;
    } else {
      try {
        final applicationDocumentsDirectory = await getApplicationDocumentsDirectory();
        path = applicationDocumentsDirectory.path;
      } catch (e) {
        return 'Error: $e';
      }
    }
    logger.i('writeFileContents directory: $path');

    File file = File('$path/$fileName');
    logger.i('file: $file');

    try {
      await file.writeAsString(contents, flush: true);
    } catch (e) {
      return 'Error writing file to \'$file\': $e';
    }
    return '${fileType ?? ''} file written to \'${file.path}\'';
  }

  @override
  Future<List<Song>> songFilePick(BuildContext context) async {
    String? path = await FilesystemPicker.open(
      title: 'Open song file',
      context: context,
      rootDirectory: _rootDirectory,
      fsType: FilesystemType.file,
      allowedExtensions: ['.songlyrics', '.pro', '.chordpro'],
      fileTileSelectMode: FileTileSelectMode.wholeTile,
    );
    List<Song> ret = [];
    if (path != null) {
      var file = File(path);
      if (file.existsSync()) {
        String s = utf8.decode(file.readAsBytesSync());
        if (chordProRegExp.hasMatch(path)) {
          //  chordpro
          var song = ChordPro().parse(s);
          ret.add(song);
        } else {
          //  .songlyrics
          List<Song> songs = Song.songListFromJson(s);
          ret.addAll(songs);
        }
        //  fixme: limits subsequent opens to the selected directory
        _rootDirectory = Directory(file.path.substring(0, file.path.lastIndexOf('/')));
      }
    } else {
      //  reset the root
      _rootDirectory = Directory(Util.homePath());
    }
    //  fixme: FilesystemPicker.open() in linux needs big help
    return ret;
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
      title: 'Open $extension file',
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
