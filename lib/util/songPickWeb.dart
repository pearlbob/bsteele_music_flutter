import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:typed_data';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/Song.dart';
import 'package:bsteele_music_flutter/util/songPick.dart';

import '../main.dart';

class SongPickWeb implements SongPick {
  Future<void> filePick() async {
    List<Song> songs = await getSongsAsync();
    for (Song song in songs) {
      addSong(song);
      //print('song: ${song.title.toString()}');
    }
  }

  Future<List<Song>> getSongsAsync() async {
    List<String> files = await getFiles();
    print("files.length: ${files.length}");
    List<Song> ret = [];
    for (String data64 in files) {
      Uint8List data = Base64Decoder().convert(data64.split(",").last);
      String s = utf8.decode(data);
      print('\tfile: $s');
      List<Song> addSongs = Song.songListFromJson(s);
      for (Song song in addSongs) {
        logger.d('add: ${song.toString()}');
        ret.add(song);
      }
    }
    return ret;
  }

  Future<List<String>> getFiles() {
    final completer = new Completer<List<String>>();
    final InputElement input = document.createElement('input');
    input
      ..type = 'file'
      ..multiple = true
      ..accept = '.songlyrics';
    input.onChange.listen((e) async {
      final List<File> files = input.files;
      Iterable<Future<String>> resultsFutures = files.map((file) {
        final reader = new FileReader();
        reader.readAsDataUrl(file);
        reader.onError.listen((error) => completer.completeError(error));
        return reader.onLoad.first.then((_) => reader.result as String);
      });
      final results = await Future.wait(resultsFutures);
      completer.complete(results);
    });
    input.click();
    return completer.future;
  }
}

SongPick getSongPick() => SongPickWeb();