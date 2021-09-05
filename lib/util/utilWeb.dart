// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:typed_data';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordPro.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
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
  Future<void> songFilePick(BuildContext context) async {
    List<Song> songs = await getSongsAsync();
    for (final Song song in songs) {
      App().addSong(song);
      //logger.d('song: ${song.title.toString()}');
    }
  }

  Future<List<Song>> getSongsAsync() async {
    List<NameValue> fileData = await getFiles('.songlyrics');
    logger.d("files.length: ${fileData.length}");
    List<Song> ret = [];
    for (var nameValue in fileData) {
      Uint8List data = const Base64Decoder().convert(nameValue.value.split(",").last);

      String s = utf8.decode(data);
      //logger.d('data: ${s.substring(0, min(200, s.length))}');
      if (chordProRegExp.hasMatch(nameValue.name)) {
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

  Future<List<NameValue>> getFiles(String? accept) {
    final completer = Completer<List<NameValue>>();
    final InputElement input = document.createElement('input') as InputElement;
    input
      ..type = 'file'
      ..multiple = true;
    if (accept != null) {
      input.accept = accept;
    }
    input.onChange.listen((e) async {
      files = input.files;
      if (files != null) {
        Iterable<Future<NameValue>> resultsFutures = files!.map((file) {
          logger.d('file: ${file.name}');
          final reader = FileReader();
          reader.readAsDataUrl(file);
          reader.onError.listen((error) => completer.completeError(error));
          return reader.onLoad.first.then((_) => NameValue(file.name, reader.result as String));
        });
        final results = await Future.wait(resultsFutures);
        completer.complete(results);
      }
    });
    input.click();
    return completer.future;
  }

  @override
  Future<List<NameValue>> textFilePickAndRead(BuildContext context) async {
    List<NameValue> fileData = await getFiles(null);
    logger.d("files.length: ${fileData.length}");
    List<NameValue> ret = [];
    for (var nameValue in fileData) {
      final String data64 = nameValue.value;

      Uint8List data = const Base64Decoder().convert(data64.split(",").last);

      ret.add(NameValue(nameValue.name, utf8.decode(data)));
    }
    return ret;
  }

  List<File>? files;
  final RegExp chordProRegExp = RegExp(r'pro$');

  @override
  Future<String> songMetadataFilePick(BuildContext context) async {
    for (NameValue nameValue in await getFiles('.songmetadata')) {
      Uint8List data = const Base64Decoder().convert(nameValue.value.split(",").last);
      String s = utf8.decode(data);
      SongMetadata.fromJson(s);
      return 'Song metadata read from ${nameValue.name}';
    }
    return '';
  }
}

UtilWorkaround getUtilWorkaround() => UtilWeb();
