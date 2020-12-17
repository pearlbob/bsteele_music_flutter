// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:typed_data';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';


/// Workaround to implement functionality that is not generic across all platforms at this point.
class UtilWeb implements UtilWorkaround {

  void writeFileContents(String fileName, String contents) {
    //   web stuff
    Blob blob = Blob([contents], 'text/plain', 'native');

    AnchorElement(
      href: Url.createObjectUrlFromBlob(blob).toString(),
    )
      ..setAttribute("download", fileName)
      ..click();
  }

  Future<void> filePick() async {
    List<Song> songs = await getSongsAsync();
    for (final Song song in songs) {
      addSong(song);
      //print('song: ${song.title.toString()}');
    }
  }

  Future<List<Song>> getSongsAsync() async {
    List<String> files = await getFiles();
    print("files.length: ${files.length}");
    List<Song> ret = [];
    for (final String data64 in files) {
      Uint8List data = Base64Decoder().convert(data64.split(",").last);
      String s = utf8.decode(data);
      List<Song> addSongs = Song.songListFromJson(s);
      for (final Song song in addSongs) {
        logger.d('add: ${song.toString()}');
        ret.add(song);
      }
    }
    return ret;
  }

  Future<List<String>> getFiles() {
    final completer = new Completer<List<String>>();
    final InputElement input = document.createElement('input') as InputElement;
    input
      ..type = 'file'
      ..multiple = true
      ..accept = '.songlyrics';
    input.onChange.listen((e) async {
      final List<File> files = input.files;
      if ( files != null ) {
        Iterable<Future<String>> resultsFutures = files.map((file) {
          final reader = new FileReader();
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
}


UtilWorkaround getUtilWorkaround() => UtilWeb();
