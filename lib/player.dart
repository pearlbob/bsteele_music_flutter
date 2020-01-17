import 'dart:math';

import 'package:bsteele_music_flutter/Grid.dart';
import 'package:bsteele_music_flutter/Gui.dart';
import 'package:bsteele_music_flutter/songs/ChordSection.dart';
import 'package:bsteele_music_flutter/songs/Section.dart';
import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:bsteele_music_flutter/songs/SongMoment.dart';
import 'package:bsteele_music_flutter/songs/Key.dart' as songs;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'appLogger.dart';

/// Display the song moments in sequential order.
class Player extends StatefulWidget {
  const Player({Key key, @required this.song}) : super(key: key);

  @override
  _Player createState() => _Player();

  final Song song;
}

class _Player extends State<Player> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Song song = widget.song;

    logger.d("size: " + MediaQuery.of(context).size.toString());
    double w = MediaQuery.of(context).size.width;
    double chordScaleFactor = w / 400;
    bool isTooNarrow = w <= 800;
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

        //  compute transposition offset from base key
        int tranOffset = _key.getHalfStep() - song.getKey().getHalfStep();

        //  keep track of the section
        ChordSection lastChordSection;
        int lastSectionCount;

        //  map the song moment grid to a flutter table, one row at a time
        for (int r = 0; r < grid.getRowCount(); r++) {
          List<SongMoment> row = grid.getRow(r);

          //  assume col 1 has a chord or comment in it
          if (row.length < 2) {
            continue;
          }

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
                    sm.getMeasure().transpose(_key, tranOffset),
                    style: TextStyle(backgroundColor: color),
                    textScaleFactor: chordScaleFactor,
                  )));

              //  use the first non-null location for the table value key
              if (momentLocation == null)
                momentLocation = sm.momentNumber.toString();
            }

            //  section and lyrics only if on a cell phone
            if (isTooNarrow) break;
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
            rows.add(TableRow(key: ValueKey(r), children: children));
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
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
              ),
              Text(
                ' by  ${song.artist}',
                textScaleFactor: lyricsScaleFactor,
              ),
              Row(
                children: <Widget>[
                  Text(
                    "Key: ",
                    textScaleFactor: lyricsScaleFactor,
                  ),
                  DropdownButton<songs.Key>(
                    items: songs.Key.values.toList().map((songs.Key value) {
                      return new DropdownMenuItem<songs.Key>(
                        key: ValueKey(value.getHalfStep()),
                        value: value,
                        child: new Text(
                          '${value.toString()} ${value.sharpsFlatsToString()}',
                          textScaleFactor: lyricsScaleFactor, //  note well
                        ),
                      );
                    }).toList(),
                    onChanged: (_value) {
                      setState(() {
                        _key = _value;
                      });
                    },
                    value: _key,
                    style: TextStyle(
                      //  size controlled by textScaleFactor above
                      color: Colors.black87,
                      textBaseline: TextBaseline.ideographic,
                    ),
                    iconSize: lyricsScaleFactor * 24,
                    itemHeight: lyricsScaleFactor * kMinInteractiveDimension,
                  ),
                  Text(
                    "   BPM: ${song.getBeatsPerMinute()}" +
                        "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}",
                    textScaleFactor: lyricsScaleFactor,
                  ),
                ],
              ),
              Scrollbar(
                child: Center(child: table),
              ),
              _KeyboardListener(),
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

  songs.Key _key = songs.Key.get(songs.KeyEnum.C);
}

class _KeyboardListener extends StatefulWidget {
  _KeyboardListener();

  @override
  _KeyboardListenerState createState() => new _KeyboardListenerState();
}

class _KeyboardListenerState extends State<_KeyboardListener> {
  handleKey(RawKeyEventData key) {
    logger.i('KeyCode: ${key.keyLabel} ${key.toString()}');
  }

  @override
  Widget build(BuildContext context) {
    _textFocusNode.requestFocus();
    return RawKeyboardListener(
      focusNode: _textFocusNode,
      onKey: (key) => handleKey(key.data),
      child: Visibility(
        visible: false,
        child: TextField(),
      ),
    );
  }

  FocusNode _textFocusNode = new FocusNode();
}
