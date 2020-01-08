import 'dart:math';

import 'package:bsteele_music_flutter/GridCoordinate.dart';
import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:bsteele_music_flutter/songs/SongMoment.dart';
import 'package:bsteele_music_flutter/songs/key.dart' as songs;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class Player extends StatelessWidget {
  final Song song;

  Player(this.song);

  @override
  Widget build(BuildContext context) {
    songs.Key key = song.key;

    print("size: " + MediaQuery
        .of(context)
        .size
        .toString());
    double textScaleFactor = MediaQuery
        .of(context)
        .size
        .width / 640;
    textScaleFactor = min(4, max(1, textScaleFactor));
    print("textScaleFactor: $textScaleFactor");

    //  build the table from the song moments
    Table table;
    {
      int lastRow;
      int maxCol = 0;
      for (SongMoment songMoment in song.songMoments) {
        maxCol = max(
            maxCol,
            song
                .getMomentGridCoordinateFromMomentNumber(
                songMoment.getMomentNumber())
                .col);
      }
      List<TableRow> rows = List();
      List<Widget> children = List();
      GridCoordinate gridCoordinate;
      for (SongMoment songMoment in song.songMoments) {
        songMoment.getChordSectionLocation();
        gridCoordinate = song.getMomentGridCoordinateFromMomentNumber(
            songMoment.getMomentNumber());
        if (lastRow != null && lastRow != gridCoordinate.row) {
          if (children.isNotEmpty) {
            while (children.length < maxCol)
              children.add(Text(
                " ",
                textScaleFactor: textScaleFactor,
              ));
            rows.add(TableRow(
                key: ValueKey(songMoment.momentLocation), children: children));
          }
          children = List();
        }
        songMoment.getChordSectionLocation();
        children.add(Text(
          songMoment.getMeasure().toMarkup(),
          textScaleFactor: textScaleFactor,
        ));
        lastRow = gridCoordinate.row;
      }
      //  add the last row
      if (children.isNotEmpty) {
        while (children.length < maxCol)
          children.add(Text(
            " ",
            textScaleFactor: textScaleFactor,
          ));
        rows.add(
            TableRow(key: ValueKey(gridCoordinate.row), children: children));
      }
      table = Table(
        children: rows,
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              AppBar(
                  title: Text(
                    '${song.title}',
                    textScaleFactor: 1.4,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  )),
              Text(
                song.artist,
                textScaleFactor: textScaleFactor,
              ),
              Text(
                "Key: $key ${key.sharpsFlatsToString()}   BPM: ${song
                    .getBeatsPerMinute()}" +
                    "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}",
                textScaleFactor: textScaleFactor,
              ),
              Scrollbar(
                child: table,
              ),
            ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        tooltip: 'Back',
        child: Icon(Icons.arrow_back),
      ),
    );
  }
}
