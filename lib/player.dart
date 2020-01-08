import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:bsteele_music_flutter/songs/key.dart' as songs;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Player extends StatelessWidget {
  final Song song;

  Player(this.song);

  @override
  Widget build(BuildContext context) {
    songs.Key key = song.key;

    int i =0;
    Table table = Table(
      children: [
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
        TableRow(key: ValueKey(i), children: [Text((i++).toString()), Text((i++).toString())]),
      ],
    );

    return Scaffold(
      appBar: AppBar(
          title: Text(
        '${song.title}',
        textScaleFactor: 1.2,
        style: TextStyle(fontWeight: FontWeight.bold),
      )),
      body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: TextDirection.ltr,
          children: <Widget>[
            Text(
              "by ${song.artist}",
            ),
            Text(
                "Key: $key ${key.sharpsFlatsToString()}   BPM: ${song.getBeatsPerMinute()}" +
                    "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}"),
            table,
          ]),
    );
  }
}
