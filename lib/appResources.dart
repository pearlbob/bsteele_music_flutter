import 'dart:convert' show JsonDecoder, utf8;

import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:logger/logger.dart';
import 'package:resource/resource.dart' show Resource;

main() async {
  Logger.level = Level.info;

  var resource = new Resource(
      "package:bsteele_music_flutter/resources/allSongs.songlyrics");
  var s = await resource.readAsString(encoding: utf8);

  JsonDecoder jsonDecoder = JsonDecoder();
  try {

    List<Song> songList =  Song.songListFromJson(s);

    for ( Song song in songList) {
      print("");
      print(song.toString());
      print("\t${song.toMarkup()}");
    }
  } catch (fe) {
    print(fe.toString());
  }
}
