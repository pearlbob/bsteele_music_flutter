// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:typed_data';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordPro.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/widgets.dart';

import '../app/app.dart';

/// Workaround to implement functionality that is not generic across all platforms at this point.
class UtilWeb implements UtilWorkaround {
  @override
  Future<String> writeFileContents(String fileName, String contents) async {
    //   web stuff
    Blob blob = Blob([contents], 'text/plain', 'native');

    AnchorElement(
      href: Url.createObjectUrlFromBlob(blob).toString(),
    )
      ..setAttribute("download", fileName)
      ..click();
    return 'file written: \'$fileName\'';
  }

  @override
  Future<void> filePick(BuildContext context) async {
    List<Song> songs = await getSongsAsync();
    for (final Song song in songs) {
      App().addSong(song);
      //print('song: ${song.title.toString()}');
    }
  }

  Future<List<Song>> getSongsAsync() async {
    List<String> fileData = await getFiles();
    logger.i("files.length: ${fileData.length}");
    List<Song> ret = [];
    for (var i = 0; i < fileData.length; i++) {
      File file = files![i];
      final String data64 = fileData[i];

      Uint8List data = const Base64Decoder().convert(data64.split(",").last);

      String s = utf8.decode(data);
      //print('data: ${s.substring(0, min(200, s.length))}');
      if (chordProRegExp.hasMatch(file.name)) {
        //  chordpro encoded songs
        ret.add(ChordPro().parse(s));
      } else {
        //  .songlyrics
        List<Song> addSongs = Song.songListFromJson(s);
        for (final Song song in addSongs) {
          logger.d('add: ${song.toString()}');
          ret.add(song);
        }
      }
    }
    return ret;
  }

  Future<List<String>> getFiles() {
    final completer = Completer<List<String>>();
    final InputElement input = document.createElement('input') as InputElement;
    input
      ..type = 'file'
      ..multiple = true
      ..accept = '.songlyrics';
    input.onChange.listen((e) async {
      files = input.files;
      if (files != null) {
        Iterable<Future<String>> resultsFutures = files!.map((file) {
          final reader = FileReader();
          reader.readAsDataUrl(file);
          reader.onError.listen((error) => completer.completeError(error));
          return reader.onLoad.first.then((_) => reader.result as String);
        });
        final results = await Future.wait(resultsFutures);
        completer.complete(results);
      }
    });
    input.click();
    return completer.future;
  }

  List<File>? files;
  final RegExp chordProRegExp = RegExp(r'pro$');
}

UtilWorkaround getUtilWorkaround() => UtilWeb();
