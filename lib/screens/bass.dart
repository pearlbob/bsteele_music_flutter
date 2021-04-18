import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordComponent.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as musicKey;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

final _white = Paint()..color = Colors.white;
final _black = Paint()..color = Colors.black;
final _blackOutline = Paint()
  ..color = Colors.black
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1;
final _grey = Paint()..color = Colors.grey;
final _dotColor = Paint()..color = Colors.blue[100] ?? Colors.blue;
final _rootColor = Paint()..color = Colors.red;
final _3Color = Paint()..color = Color(0xffffb28f);
final _5Color = Paint()..color = Color(0xffffa500);
final _7Color = Paint()..color = Color(0xffffff00);


/// the bass study tool
class BassWidget extends StatefulWidget {
  const BassWidget({Key? key}) : super(key: key);

  @override
  _State createState() => _State();
}

class _State extends State<BassWidget> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    final double fontSize = screenInfo.isTooNarrow ? 16 : 24;

    _style = TextStyle(color: Colors.black87, fontSize: fontSize);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Bass Study Tool',
          style: TextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 10,
          ),
          CustomPaint(
            painter: _FretBoardPainter(),
            isComplex: true,
            willChange: false,
            child: SizedBox(
              width: double.infinity,
              height: 200.0,
            ),
          ),
          SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Key: ',
                        style: _style,
                      ),
                      DropdownButton<musicKey.Key>(
                        items: musicKey.Key.values.toList().reversed.map((musicKey.Key value) {
                          return new DropdownMenuItem<musicKey.Key>(
                            key: ValueKey('half' + value.getHalfStep().toString()),
                            value: value,
                            child: new Text(
                              '${value.toMarkup().padRight(3)} ${value.sharpsFlatsToMarkup()}',
                              style: _style,
                            ),
                          );
                        }).toList(),
                        onChanged: (_value) {
                          if (_value != null && _value != _key) {
                            setState(() {
                              _key = _value;
                            });
                          }
                        },
                        value: _key,
                        style: TextStyle(
                          //  size controlled by textScaleFactor above
                          color: Colors.black,
                          textBaseline: TextBaseline.ideographic,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Chord: ',
                        style: _style,
                      ),
                      DropdownButton<ChordDescriptor>(
                        items: ChordDescriptor.values.toList().map((ChordDescriptor value) {
                          return new DropdownMenuItem<ChordDescriptor>(
                            //key: ValueKey('half' + value.getHalfStep().toString()),
                            value: value,
                            child: new Text(
                              '${value.toString().padRight(3)} (${value.name})',
                              style: _style,
                            ),
                          );
                        }).toList(),
                        onChanged: (_value) {
                          if (_value != null && _value != chordDescriptor) {
                            setState(() {
                              chordDescriptor = _value;
                            });
                          }
                        },
                        value: chordDescriptor,
                        style: TextStyle(
                          //  size controlled by textScaleFactor above
                          color: Colors.black,
                          textBaseline: TextBaseline.ideographic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 10,
              ),
              _keyTable(),
            ],
          ),
          SizedBox(
            height: 10,
          ),
                 ],
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

  Table _keyTable() {
    final children = <TableRow>[];
    final padding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    const halfSteps = MusicConstants.halfStepsPerOctave;

    List<Widget> row = [];
    row.add(Container(
      padding: padding,
      alignment: Alignment.centerRight,
      child: Text(
        'Half Steps',
        style: _style,
      ),
    ));
    for (var i = 0; i < halfSteps; i++) {
      row.add(Container(
          padding: padding,
          alignment: Alignment.center,
          child: Text(
            '$i',
            style: _style,
          )));
    }
    children.add(TableRow(children: row));

    row = [];
    row.add(Container(
      padding: padding,
      alignment: Alignment.centerRight,
      child: Text(
        'Structure',
        style: _style,
      ),
    ));
    for (var v in ChordComponent.values) {
      row.add(Container(
          padding: padding,
          alignment: Alignment.center,
          child: Text(
            v.shortName,
            style: _style,
          )));
    }
    children.add(TableRow(children: row));

    row = [];
    row.add(Container(
      padding: padding,
      alignment: Alignment.centerRight,
      child: Text(
        'Scale Notes',
        style: _style,
      ),
    ));
    var scaleNotes = <ScaleNote>[];
    for (int n = 0; n < MusicConstants.notesPerScale; n++) {
      scaleNotes.add(_key.getMajorScaleByNote(n));
    }

    for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
      var scaleNote = _key.getKeyScaleNoteByHalfStep(halfStep);
      row.add(Container(
          padding: padding,
          alignment: Alignment.center,
          child: Text(
            (scaleNotes.contains(scaleNote) ? scaleNote.toString() : ''),
            style: _style,
          )));
    }
    children.add(TableRow(children: row));

    row = [];
    row.add(Container(
      padding: padding,
      alignment: Alignment.centerRight,
      child: Text(
        'Accidentals',
        style: _style,
      ),
    ));
    for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
      var scaleNote = _key.getKeyScaleNoteByHalfStep(halfStep);
      row.add(Container(
          padding: padding,
          alignment: Alignment.center,
          child: Text(
            (scaleNotes.contains(scaleNote) ? '' : scaleNote.toString()),
            style: _style,
          )));
    }
    children.add(TableRow(children: row));

    row = [];
    row.add(Container(
      padding: padding,
      alignment: Alignment.centerRight,
      child: Text(
        'Chord Notes',
        style: _style,
      ),
    ));
    var scaleChord = ScaleChord(_key.getKeyScaleNote(), chordDescriptor);
    var chordHalfSteps = scaleChord.getChordComponents().map((chordComponent) {
      return chordComponent.halfSteps;
    }).toList();
    for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
      var scaleNote = _key.getKeyScaleNoteByHalfStep(halfStep);
      row.add(Container(
          padding: padding,
          alignment: Alignment.center,
          child: Text(
            (chordHalfSteps.contains(halfStep) ? scaleNote.toString() : ''),
            style: _style,
          )));
    }
    children.add(TableRow(children: row));

    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < halfSteps + 1; i++) {
      widths[i] = IntrinsicColumnWidth(flex: 1);
    }

    return Table(
      children: children,
      columnWidths: widths,
      border: TableBorder.all(),
    );
  }

  ChordDescriptor chordDescriptor = ChordDescriptor.major;
  TextStyle _style = TextStyle();
  musicKey.Key _key = musicKey.Key.getDefault();
}

class _FretBoardPainter extends CustomPainter {
  @override
  void paint(Canvas aCanvas, Size size) {
    canvas = aCanvas;
    var width = size.width;
    var height = size.height;

    var margin = width * 0.1;
    bassFretX = margin;
    bassFretY = 0;
    bassFretHeight = height;
    bassScale = width - 2 * margin;

    //  clear the fretboard
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), _white);

    //  frets
    _black.strokeWidth = 2;
    {
      var fretYmin = bassFretY + bassFretHeight / 16;
      var fretYmax = bassFretY + bassFretHeight - bassFretHeight / 16;
      for (var fret = 0; fret <= 12; fret++) {
        _black.strokeWidth = fret == 0 ? 6 : 2;
        var x = fretLoc(fret);
        canvas.drawLine(Offset(x, fretYmin), Offset(x, fretYmax), _black);
      }
    }

    //  strings
    for (var s = 0; s < 4; s++) {
      _grey.strokeWidth = (4 - s) * 2;

      var y = bassFretY + bassFretHeight - bassFretHeight * s / 4 - bassFretHeight / 8;
      canvas.drawLine(Offset(bassFretX, y), Offset(bassFretX + bassScale, y), _grey);
    }

    //  dots on frets 3, 5, 7, 9
    {
      _dotColor.strokeWidth = 3;
      double dotRadius = 10;
      for (var i = 0; i < 4; i++) {
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset((fretLoc(2 + 2 * i) + fretLoc(2 + 2 * i + 1)) / 2, bassFretY + bassFretHeight / 2),
                width: 2 * dotRadius,
                height: 2 * dotRadius),
            0,
            2 * pi,
            true,
            _dotColor);
      }
      //  double dots on fret 12
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset((fretLoc(11) + fretLoc(12)) / 2, bassFretY + bassFretHeight / 4),
              width: 2 * dotRadius,
              height: 2 * dotRadius),
          0,
          2 * pi,
          true,
          _dotColor);
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset((fretLoc(11) + fretLoc(12)) / 2, bassFretY + bassFretHeight * 3 / 4),
              width: 2 * dotRadius,
              height: 2 * dotRadius),
          0,
          2 * pi,
          true,
          _dotColor);
    }

    //  temp
    {
      final paints = <Paint>[_rootColor, _3Color, _5Color, _7Color];
      var paintIndex = 0;
      for (var fret = 0; fret <= 12; fret++) {
        for (var bassString = 0; bassString < 4; bassString++) {
          press(paints[paintIndex], bassString, fret);
          paintIndex = (paintIndex + 1) % paints.length;
        }
      }
    }
  }

  void press(Paint paint, int bassString, int fret) {
    fret = max(0, min(12, fret));
    bassString = max(0, min(3, bassString));
    final double pressRadius = 15;
    canvas.drawCircle(
        Offset(fretLoc(fret) - pressRadius - 4,
            bassFretY + bassFretHeight - bassFretHeight * bassString / 4 - bassFretHeight / 8),
        pressRadius,
        paint);
    canvas.drawCircle(
        Offset(fretLoc(fret) - pressRadius - 4,
            bassFretY + bassFretHeight - bassFretHeight * bassString / 4 - bassFretHeight / 8),
        pressRadius,
        _blackOutline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //  fixme optimize?
  }

  double fretLoc(int n) {
    n = max(0, min(12, n));

    if (fretLocs.isEmpty) {
      for (var i = 0; i <= 12; i++) {
        fretLocs.add(bassFretX + 2 * (bassScale - ((bassScale / pow(2, i / 12)))));
      }
    }
    return fretLocs[n];
  }

  double fretWidth(int n) {
    n = max(0, min(12, n));

    if (fretWidths.isEmpty) {
      fretWidths.add(fretLoc(1) - fretLoc(0)); //  at 0
      for (var i = 0; i < 12; i++) {
        fretWidths.add(fretLoc(i + 1) - fretLoc(i));
      }
    }
    return fretWidths[n];
  }

  late Canvas canvas;
  final List<double> fretLocs = [];
  final List<double> fretWidths = [];
  double bassFretHeight = 200;
  double bassFretY = 0;
  double bassFretX = 63;
  double bassScale = 2000;
}
