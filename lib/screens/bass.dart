import 'dart:math';
import 'dart:ui' as ui;

import 'package:bsteeleMusicLib/songs/chordComponent.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as musicKey;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
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
final _scaleBlackOutline = Paint()
  ..color = Colors.black38
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1;
final _grey = Paint()..color = Colors.grey;
final _dotColor = Paint()..color = Colors.blue[100] ?? Colors.blue;
final _rootColor = Paint()..color = Colors.red;
final _thirdColor = Paint()..color = Color(0xffffb390);
final _fifthColor = Paint()..color = Color(0xffffa500);
final _seventhColor = Paint()..color = Color(0xffffff00);
final _scaleColor = Paint()..color = Color(0x80ffffff);
double _fontSize = 24;

musicKey.Key _key = musicKey.Key.getDefault();

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
    _fontSize = screenInfo.isTooNarrow ? 16 : 24;

    _style = TextStyle(color: Colors.black87, fontSize: _fontSize);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Bass Study Tool',
          style: TextStyle(color: Colors.black87, fontSize: _fontSize, fontWeight: FontWeight.bold),
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

    //  halfsteps
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

    //  structure
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

    //  compute scale notes
    var scaleNotes = <ScaleNote>[];
    for (int n = 0; n < MusicConstants.notesPerScale; n++) {
      scaleNotes.add(_key.getMajorScaleByNote(n));
    }

    //  display scale notes
    row = [];
    row.add(Container(
      padding: padding,
      alignment: Alignment.centerRight,
      child: Text(
        'Scale Notes',
        style: _style,
      ),
    ));
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

    {
      //  compute scale notes
      var scaleNotes = <ScaleNote>[];
      for (int n = 0; n < MusicConstants.notesPerScale; n++) {
        scaleNotes.add(_key.getMajorScaleByNote(n));
      }

      for (var fret = 0; fret <= 12; fret++) {
        for (var bassString = 0; bassString < 4; bassString++) {
          var halfStep = (bassString * 5 + fret) % MusicConstants.halfStepsPerOctave;
          var scaleNote = keyE.getKeyScaleNoteByHalfStep(halfStep);

          if (scaleNotes.contains(scaleNote)) {
            var halfStepOff = (scaleNote.halfStep - _key.halfStep) % MusicConstants.halfStepsPerOctave;
            var chordComponent = ChordComponent.values[halfStepOff];
            Paint paint;
            if (chordComponent == ChordComponent.root) {
              paint = _rootColor;
            } else if (chordComponent == ChordComponent.minorThird || chordComponent == ChordComponent.third) {
              paint = _thirdColor;
            } else if (chordComponent == ChordComponent.flatFifth || chordComponent == ChordComponent.fifth) {
              paint = _fifthColor;
            } else if (chordComponent == ChordComponent.minorSeventh || chordComponent == ChordComponent.seventh) {
              paint = _seventhColor;
            } else {
              paint = _scaleColor;
            }
            press(paint, bassString, fret, chordComponent.shortName);
          }
        }
      }
    }
  }

  void press(Paint paint, int bassString, int fret, String noteChar) {
    fret = max(0, min(12, fret));
    bassString = max(0, min(3, bassString));
    final double pressRadius = 15;
    var offset = Offset(fretLoc(fret) - pressRadius - 4,
        bassFretY + bassFretHeight - bassFretHeight * bassString / 4 - bassFretHeight / 8);
    canvas.drawCircle(offset, pressRadius, paint);
    canvas.drawCircle(offset, pressRadius, _blackOutline);
    if (noteChar.isNotEmpty) {
      // To create a paragraph of text, we use ParagraphBuilder.
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textDirection: ui.TextDirection.ltr),
      )
        ..pushStyle(ui.TextStyle(color: Colors.black, fontSize: _fontSize, fontWeight: FontWeight.bold))
        ..addText(noteChar);
      var paragraph = builder.build()..layout(ui.ParagraphConstraints(width: 4 * _fontSize));
      canvas.drawParagraph(paragraph, Offset(offset.dx - paragraph.maxIntrinsicWidth / 2, offset.dy - pressRadius));
    }
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

  final musicKey.Key keyE = musicKey.Key.get(musicKey.KeyEnum.E);

  late Canvas canvas;
  final List<double> fretLocs = [];
  final List<double> fretWidths = [];
  double bassFretHeight = 200;
  double bassFretY = 0;
  double bassFretX = 63;
  double bassScale = 2000;
}
