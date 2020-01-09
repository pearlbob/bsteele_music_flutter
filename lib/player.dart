import 'dart:math';

import 'package:bsteele_music_flutter/Grid.dart';
import 'package:bsteele_music_flutter/Gui.dart';
import 'package:bsteele_music_flutter/songs/ChordSection.dart';
import 'package:bsteele_music_flutter/songs/Section.dart';
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

    print("size: " + MediaQuery.of(context).size.toString());
    double chordScaleFactor = MediaQuery.of(context).size.width / 300;
    chordScaleFactor = min(10, max(1, chordScaleFactor));
    double lyricsScaleFactor = max(1, 0.75 * chordScaleFactor);
    print("textScaleFactor: $chordScaleFactor");

    //  build the table from the song moment grid
    Table table;
    Grid<SongMoment> grid = song.songMomentGrid;
    if (grid.isNotEmpty) {
      {
        List<TableRow> rows = List();
        List<Widget> children = List();
        Color color =
            GuiColors.getColorForSection(Section.get(SectionEnum.chorus));
        ChordSection lastChordSection;
        for (int r = 0; r < grid.getRowCount(); r++) {
          List<SongMoment> row = grid.getRow(r);

          //  assume col 1 has a chord in it
          if (row.length < 2 || row[1] == null) continue;
          ChordSection chordSection = row[1].getChordSection();
          String columnFiller;
          EdgeInsets marginInsets = EdgeInsets.all(4 * chordScaleFactor);
          if (chordSection != lastChordSection) {
            //  add the section heading
            columnFiller = chordSection.sectionVersion.toString();
            color = GuiColors.getColorForSection(chordSection.getSection());
          }
          lastChordSection = chordSection;

          String momentLocation;
          for (int c = 0; c < row.length; c++) {
            SongMoment sm = row[c];

            if (sm == null) {
              if (columnFiller == null)
                //  empty cell
                children.add(Container(
                    margin: marginInsets,
                    child: Text(
                      " ",
                    )));
              else
                children.add(Container(
                    margin: marginInsets,
                    child: Text(
                      columnFiller,
                      style: TextStyle(backgroundColor: color),
                      textScaleFactor: chordScaleFactor,
                    )));
              columnFiller = null; //  for subsequent rows
            } else {
              //  moment found
              children.add(Container(
                  margin: marginInsets,
                  child: Text(
                    sm.getMeasure().toJson(),
                    style: TextStyle(backgroundColor: color),
                    textScaleFactor: chordScaleFactor,
                  )));

              //  use the first non-null location for the table value key
              if (momentLocation == null) momentLocation = sm.momentLocation;
            }
          }

          if (momentLocation != null) {
            //  lyrics
            children.add(Container(
                margin: marginInsets,
                child: Text(
                  "row $r lyrics go here\nand here",
                  style: TextStyle(backgroundColor: color),
                  textScaleFactor: lyricsScaleFactor,
                )));

            //  add row to table
            rows.add(
                TableRow(key: ValueKey(momentLocation), children: children));
          }

          children = List();
        }

        table = Table(
          defaultColumnWidth: IntrinsicColumnWidth(),
          children: rows,
        );
      }
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
                textScaleFactor: chordScaleFactor,
              ),
              Text(
                "Key: $key ${key.sharpsFlatsToString()}   BPM: ${song.getBeatsPerMinute()}" +
                    "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}",
                textScaleFactor: chordScaleFactor,
              ),
              Scrollbar(
                child: Center(child: table),
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
