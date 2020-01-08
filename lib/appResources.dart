import 'dart:convert' show utf8;

import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:logger/logger.dart';
import 'package:resource/resource.dart' show Resource;

main() async {
  Logger.level = Level.info;

  //  read an asset in dart.... doesn't work in flutter, use rootbundle there
  var resource =
      new Resource("package:bsteele_music_flutter/assets/allSongs.songlyrics");
  String s = await resource.readAsString(encoding: utf8);

  try {
    List<Song> songList = Song.songListFromJson(s);

    for (Song song in songList) {
      print("");
      print(song.toString());
      print("\t${song.toMarkup()}");
    }
  } catch (fe) {
    print(fe.toString());
  }
}
