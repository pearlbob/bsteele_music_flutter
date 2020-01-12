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

import 'appLogger.dart';

/// Display the song in sequential order so it can be played.
class Player extends StatelessWidget {
  final Song song;

  Player(this.song);

  @override
  Widget build(BuildContext context) {
    songs.Key key = song.key;

    logger.d("size: " + MediaQuery.of(context).size.toString());
    double w = MediaQuery.of(context).size.width;
    double chordScaleFactor =  w/ 400;
    bool isTooNarrow = w < 801;
    chordScaleFactor = min(10, max(1, chordScaleFactor));
    double lyricsScaleFactor = max(1, 0.75 * chordScaleFactor);
    logger.d("textScaleFactor: $chordScaleFactor");

    //  build the table from the song moment grid
    Table table;
    Grid<SongMoment> grid = song.songMomentGrid;
    if (grid.isNotEmpty) {
      {
        List<TableRow> rows = List();
        List<Widget> children = List();
        Color color =
            GuiColors.getColorForSection(Section.get(SectionEnum.chorus));

        //  keep track of the section
        ChordSection lastChordSection;
        int lastSectionCount;

        //  map the song moment grid to a flutter table, one row at a time
        for (int r = 0; r < grid.getRowCount(); r++) {
          List<SongMoment> row = grid.getRow(r);

          //  assume col 1 has a chord or comment in it
          if (row.length < 2) continue;

          //  find the first col with data
          //  should normally be col 1 (i.e. the second col)
          SongMoment firstSongMoment;
          for (SongMoment sm in row)
            if (sm == null)
              continue;
            else {
              firstSongMoment = sm;
              break;
            }
          if (firstSongMoment == null) continue;

          ChordSection chordSection = firstSongMoment.getChordSection();
          int sectionCount = firstSongMoment.sectionCount;
          String columnFiller;
          EdgeInsets marginInsets = EdgeInsets.all(4 * chordScaleFactor);
          if (chordSection != lastChordSection ||
              sectionCount != lastSectionCount) {
            //  add the section heading
            columnFiller = chordSection.sectionVersion.toString();
            color = GuiColors.getColorForSection(chordSection.getSection());
          }
          lastChordSection = chordSection;
          lastSectionCount = sectionCount;

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
              if (momentLocation == null)
                momentLocation = sm.momentNumber.toString();
            }

            //  section and lyrics only if on a cell phone
            if ( isTooNarrow)
              break;
          }

          if (momentLocation != null || isTooNarrow) {
            //  lyrics
            children.add(Container(
                margin: marginInsets,
                child: Text(
                  firstSongMoment.lyrics,
                  style: TextStyle(backgroundColor: color),
                  textScaleFactor: lyricsScaleFactor,
                )));

            //  add row to table
            rows.add(
                TableRow(key: ValueKey(r), children: children));
          }

          //  get ready for the next row by clearing the row data
          children = List();
        }

        table = Table(
          defaultColumnWidth: IntrinsicColumnWidth(),
          children: rows,
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              AppBar(
                  //  let the app bar scroll off the screen for more room for the song
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
