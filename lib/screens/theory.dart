import 'dart:collection';

import 'package:bsteeleMusicLib/songs/chordComponent.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';

const double _defaultFontSize = 28;
music_key.Key _key = music_key.Key.getDefault();
ScaleNote _chordRoot = _key.getKeyScaleNote();
ScaleChord _scaleChord = ScaleChord(_key.getKeyScaleNote(), ChordDescriptor.defaultChordDescriptor());
const _halfStepsPerOctave = MusicConstants.halfStepsPerOctave;

/// A screen used to explore music theory including scales, chords, major and minor keys.
class TheoryWidget extends StatefulWidget {
  const TheoryWidget({Key? key}) : super(key: key);

  @override
  _State createState() => _State();
}

class _State extends State<TheoryWidget> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    _style = generateAppTextStyle(color: Colors.black87, fontSize: _defaultFontSize);

    _scaleChord = ScaleChord(_chordRoot, chordDescriptor);
    List<ScaleNote> scaleNoteValues = [];
    {
      var scaleNoteSet = SplayTreeSet<ScaleNote>();
      for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
        scaleNoteSet.add(_key.getKeyScaleNoteByHalfStep(i));
      }
      scaleNoteValues = scaleNoteSet.toList(growable: false);
    }

    var backgroundColor = Theme.of(context).backgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'Music Theory'),
      body: Stack(children: [
        Container(
          color: measureContainerBackgroundColor(),
        ),
        SingleChildScrollView(
          //controller: _scrollController,
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              const AppSpace(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        color: backgroundColor,
                        child: Row(
                          children: [
                            Text(
                              'Key: ',
                              style: _style,
                            ),
                            DropdownButton<music_key.Key>(
                              items: music_key.Key.values.toList().reversed.map((music_key.Key value) {
                                return DropdownMenuItem<music_key.Key>(
                                  key: ValueKey('half' + value.getHalfStep().toString()),
                                  value: value,
                                  child: Text(
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
                              style: generateAppTextStyle(
                                color: Colors.black,
                                textBaseline: TextBaseline.ideographic,
                              ),
                              itemHeight: null,
                            ),
                          ],
                        ),
                      ),
                      const AppSpace(),
                      Container(color: backgroundColor, child: _keyScaleNoteTable()),
                      const AppSpace(),
                      Container(
                        color: backgroundColor,
                        child: Row(
                          children: [
                            Text(
                              'Chord root: ',
                              style: _style,
                            ),
                            DropdownButton<ScaleNote>(
                              items: scaleNoteValues.map((ScaleNote value) {
                                return DropdownMenuItem<ScaleNote>(
                                  key: ValueKey('root' + value.halfStep.toString()),
                                  value: value,
                                  child: Text(
                                    _key.inKey(value).toMarkup(),
                                    style: _style,
                                  ),
                                );
                              }).toList(),
                              onChanged: (_value) {
                                if (_value != null && _value != _chordRoot) {
                                  setState(() {
                                    _chordRoot = _value;
                                  });
                                }
                              },
                              value: _chordRoot,
                              style: generateAppTextStyle(
                                color: Colors.black,
                                textBaseline: TextBaseline.ideographic,
                              ),
                              itemHeight: null,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        color: backgroundColor,
                        child: Row(
                          children: [
                            Text(
                              'Chord type: ',
                              style: _style,
                            ),
                            DropdownButton<ChordDescriptor>(
                              items: ChordDescriptor.values.toList().map((ChordDescriptor value) {
                                return DropdownMenuItem<ChordDescriptor>(
                                  value: value,
                                  child: Text(
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
                              style: generateAppTextStyle(
                                color: Colors.black,
                                textBaseline: TextBaseline.ideographic,
                              ),
                              itemHeight: null,
                            ),
                          ],
                        ),
                      ),
                      Container(color: backgroundColor, child: _keyTable()),
                      Container(
                        height: 20,
                      ),
                      Container(color: backgroundColor, child: _majorDiatonicsTable()),
                      Container(
                        height: 20,
                      ),
                      Container(color: backgroundColor, child: _minorDiatonicsTable())
                    ],
                  ),
                ],
              ),
              const AppSpace(),
            ],
          ),
        ),
      ]),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.theoryBack),
    );
  }

  Table _keyScaleNoteTable() {
    final children = <TableRow>[];
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    const halfSteps = _halfStepsPerOctave * 2 + 1;

    List<Widget> row = [];

    //  major half steps
    {
      var boldStyle = _style.copyWith(fontWeight: FontWeight.bold);
      row.add(Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          'Half Steps',
          style: boldStyle,
        ),
      ));

      for (var i = 0; i < halfSteps; i++) {
        row.add(Container(
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              '${i % MusicConstants.halfStepsPerOctave}',
              style: boldStyle,
            )));
      }
      children.add(TableRow(children: row));
    }

    music_key.Key rootKey = _key;

    {
      //  compute major scale notes
      var scaleNotes = <ScaleNote>[];
      for (int n = 0; n < MusicConstants.notesPerScale; n++) {
        scaleNotes.add(_key.inKey(rootKey.getMajorScaleByNote(n)));
      }

      //  display scale notes
      row = [];
      row.add(Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          '$_key Major Scale',
          style: _style,
        ),
      ));
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
        row.add(Container(
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              (scaleNotes.contains(scaleNote) ? scaleNote.toString() : ''),
              style: _style,
            )));
      }
      children.add(TableRow(children: row));
    }

    //  major half steps
    {
      row = [];
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
              '${(i + 3) % MusicConstants.halfStepsPerOctave}',
              style: _style,
            )));
      }
      children.add(TableRow(children: row));
    }

    {
      //  compute minor scale notes
      var minorKey = rootKey.getMinorKey();
      var scaleNote = rootKey.getKeyMinorScaleNote();
      var isSharp = scaleNote.isSharp;
      var scaleNotes = <ScaleNote>[];
      for (int n = 0; n < MusicConstants.notesPerScale; n++) {
        scaleNotes.add(minorKey.inKey(minorKey.getMinorScaleByNote(n)));
      }

      //  display scale notes
      row = [];
      row.add(Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          '${scaleNote.toMarkup()} Minor Scale',
          style: _style,
        ),
      ));
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var originalScaleNote = minorKey.getKeyScaleNoteByHalfStep(halfStep + 3);
        scaleNote = originalScaleNote.asSharp(value: isSharp);
        row.add(Container(
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              (scaleNotes.contains(originalScaleNote) ? scaleNote.toString() : ''),
              style: _style,
            )));
      }
      children.add(TableRow(children: row));
    }

    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < halfSteps + 1; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(
      children: children,
      columnWidths: widths,
      border: TableBorder.all(),
    );
  }

  Table _keyTable() {
    final children = <TableRow>[];
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);

    List<Widget> row = [];

    //  halfsteps
    {
      var boldStyle = _style.copyWith(fontWeight: FontWeight.bold);
      row.add(Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          'Half Steps',
          style: boldStyle,
        ),
      ));

      for (var i = 0; i < _halfStepsPerOctave; i++) {
        row.add(Container(
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              '$i',
              style: boldStyle,
            )));
      }
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

    music_key.Key rootKey = music_key.Key.getKeyByHalfStep(_chordRoot.halfStep);

    //  compute scale notes
    var scaleNotes = <ScaleNote>[];
    for (int n = 0; n < MusicConstants.notesPerScale; n++) {
      scaleNotes.add(_key.inKey(rootKey.getMajorScaleByNote(n)));
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
    for (var halfStep = 0; halfStep < _halfStepsPerOctave; halfStep++) {
      var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
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
    for (var halfStep = 0; halfStep < _halfStepsPerOctave; halfStep++) {
      var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
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

    var chordHalfSteps = _scaleChord.getChordComponents().map((chordComponent) {
      return chordComponent.halfSteps;
    }).toList();
    for (var halfStep = 0; halfStep < _halfStepsPerOctave; halfStep++) {
      var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
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
    for (var i = 0; i < _halfStepsPerOctave + 1; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(
      children: children,
      columnWidths: widths,
      border: TableBorder.all(),
    );
  }

  Table _majorDiatonicsTable() {
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    final tableRows = <TableRow>[];

    //  major diatonic names
    {
      var boldStyle = _style.copyWith(fontWeight: FontWeight.bold);
      List<Widget> row = [];
      row.add(Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          'Major Key',
          style: boldStyle,
        ),
      ));
      for (var diatonic in MajorDiatonic.values) {
        row.add(Container(
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              Util.enumName(diatonic),
              style: boldStyle,
            )));
      }
      tableRows.add(TableRow(children: row));
    }

    for (var key in music_key.Key.values) {
      List<Widget> row = [];
      row.add(Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          '${key.name} ',
          style: _style,
        ),
      ));
      int diatonicDegrees = MajorDiatonic.values.length;
      for (var diatonicDegree = 0; diatonicDegree < diatonicDegrees; diatonicDegree++) {
        row.add(Container(
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              key.getMajorDiatonicByDegree(diatonicDegree).toString(),
              style: _style,
            )));
      }
      tableRows.add(TableRow(children: row));
    }
    // sb.append("<tr><td style=\"padding: 15px; \">" + key.toString() + " " + key.sharpsFlatsToString() +
    // "</td>");
    // for (MusicConstant.MajorDiatonic majorDiatonic : MusicConstant.MajorDiatonic.values()) {
    //
    // ScaleChord builtScaleChord = key.getMajorDiatonicByDegree(majorDiatonic.ordinal());
    //
    // ArrayList<ScaleChord> scaleChords = new ArrayList<>();
    // scaleChords.add(builtScaleChord);
    //
    // sb.append("<td style=\"padding: 15px; \">"
    // + builtScaleChord.toString()
    // + "</td>");
    // }
    // sb.append("</tr>\n");
    // }
    // sb.append("  </table>\n");
    // sb.append("<p> </p>\n");
    //
    // //  major chord details
    // sb.append(
    // "<table border=\"2\" style=\"border-collapse: collapse;\">\n" +
    // "<tr><th>Key</th>" +
    // "<th>Tonic</th>" +
    // "<th>Chord</th>" +
    // "<th>Formula</th>" +
    // "<th>Notes</th>" +
    // "</tr>");
    //
    // String style = " style=\"padding-left: 15px; padding-right: 15px;\"";
    // for (Key key : Key.values()) {
    // for (MusicConstant.MajorDiatonic majorDiatonic : MusicConstant.MajorDiatonic.values()) {
    //
    // ScaleChord builtScaleChord = key.getMajorDiatonicByDegree(majorDiatonic.ordinal());
    //
    // ArrayList<ScaleChord> scaleChords = new ArrayList<>();
    // scaleChords.add(builtScaleChord);
    //
    // sb.append("<tr><td" + style + ">" + key.toString() + " " + key.sharpsFlatsToString() + "</td><td>"
    // + majorDiatonic.name()
    // + "</td><td" + style + ">"
    // + builtScaleChord.toString()
    // + "</td><td" + style + ">");
    // boolean first = true;
    // for (ChordComponent chordComponent : builtScaleChord.getChordComponents()) {
    // if (first)
    // first = false;
    // else
    // sb.append(" ");
    // sb.append(chordComponent.getShortName());
    // }
    // sb.append("</td><td" + style + ">\n");
    //
    // sb.append(chordComponentScaleNotesToString(key, builtScaleChord.getScaleNote().getHalfStep(), builtScaleChord));
    // sb.append("</td></tr>\n");
    // }
    // }
    // sb.append(
    // "  </table>\n");
    //
    // //  minor
    // sb.append(
    // "<p>Minor</p>"
    // + "<table border=\"2\" style=\"border-collapse: collapse;\">\n" +
    // "<tr><th>Key</th><th>i</th>" +
    // "<th>ii</th>" +
    // "<th>III</th>" +
    // "<th>iv</th>" +
    // "<th>v</th>" +
    // "<th>VI</th>" +
    // "<th>VII</th>" +
    // "</tr>");
    //
    // for (Key key : Key.values()) {
    // sb.append("<tr><td style=\"padding: 15px; \">" + key.getMinorScaleChord().toString()
    // + " " + key.sharpsFlatsToString() + "</td>");
    //
    // for (MusicConstant.MinorDiatonic minorDiatonic : MusicConstant.MinorDiatonic.values()) {
    //
    // ScaleChord builtScaleChord = key.getMinorDiatonicByDegree(minorDiatonic.ordinal());
    //
    // ArrayList<ScaleChord> scaleChords = new ArrayList<>();
    // scaleChords.add(builtScaleChord);
    //
    // sb.append("<td style=\"padding: 15px; \">"
    // + builtScaleChord.toString()
    // + "</td>");
    // }
    // sb.append("</tr>\n");
    // }
    // sb.append("  </table>\n");
    // sb.append("<p> </p>\n");
    //
    //
    // //  details
    // sb.append(
    // "<table border=\"2\" style=\"border-collapse: collapse;\">\n" +
    // "<tr><th>Key</th>" +
    // "<th>Tonic</th>" +
    // "<th>Chord</th>" +
    // "<th>Formula</th>" +
    // "<th>Notes</th>" +
    // "</tr>");
    //
    // style = " style=\"padding-left: 15px; padding-right: 15px;\"";
    // for (Key key : Key.values()) {
    // for (MusicConstant.MinorDiatonic minorDiatonic : MusicConstant.MinorDiatonic.values()) {
    //
    // ScaleChord builtScaleChord = key.getMinorDiatonicByDegree(minorDiatonic.ordinal());
    //
    // ArrayList<ScaleChord> scaleChords = new ArrayList<>();
    // scaleChords.add(builtScaleChord);
    //
    // sb.append("<tr><td" + style + ">" + key.getMinorScaleChord().toString() + " " + key
    //     .sharpsFlatsToString() + "</td><td>"
    // + minorDiatonic.name()
    // + "</td><td" + style + ">"
    // + builtScaleChord.toString()
    // + "</td><td" + style + ">");
    // boolean first = true;
    // for (ChordComponent chordComponent : builtScaleChord.getChordComponents()) {
    // if (first)
    // first = false;
    // else
    // sb.append(" ");
    // sb.append(chordComponent.getShortName());
    // }
    // sb.append("</td><td" + style + ">\n");
    //
    // sb.append(chordComponentScaleNotesToString(key, builtScaleChord.getScaleNote().getHalfStep(), builtScaleChord));
    // sb.append("</td></tr>\n");
    // }
    // }
    // sb.append(
    // "  </table>\n");
    // return sb.toString();

    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < MajorDiatonic.values.length + 1; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(
      children: tableRows,
      columnWidths: widths,
      border: TableBorder.all(),
    );
  }

  Table _minorDiatonicsTable() {
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
    final tableRows = <TableRow>[];

    //  major diatonic names
    {
      var boldStyle = _style.copyWith(fontWeight: FontWeight.bold);
      List<Widget> row = [];
      row.add(Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          'Minor Key',
          style: boldStyle,
        ),
      ));
      for (var diatonic in MinorDiatonic.values) {
        row.add(Container(
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              Util.enumName(diatonic),
              style: boldStyle,
            )));
      }
      tableRows.add(TableRow(children: row));
    }

    for (var key in music_key.Key.values) {
      List<Widget> row = [];
      row.add(Container(
        padding: padding,
        alignment: Alignment.centerRight,
        child: Text(
          '${key.getMinorKey()} ',
          style: _style,
        ),
      ));
      int diatonicDegrees = MinorDiatonic.values.length;
      for (var diatonicDegree = 0; diatonicDegree < diatonicDegrees; diatonicDegree++) {
        row.add(Container(
            padding: padding,
            alignment: Alignment.center,
            child: Text(
              key.getMinorDiatonicByDegree(diatonicDegree).toString(),
              style: _style,
            )));
      }
      tableRows.add(TableRow(children: row));
    }
    // sb.append("<tr><td style=\"padding: 15px; \">" + key.toString() + " " + key.sharpsFlatsToString() +
    // "</td>");
    // for (MusicConstant.MajorDiatonic majorDiatonic : MusicConstant.MajorDiatonic.values()) {
    //
    // ScaleChord builtScaleChord = key.getMajorDiatonicByDegree(majorDiatonic.ordinal());
    //
    // ArrayList<ScaleChord> scaleChords = new ArrayList<>();
    // scaleChords.add(builtScaleChord);
    //
    // sb.append("<td style=\"padding: 15px; \">"
    // + builtScaleChord.toString()
    // + "</td>");
    // }
    // sb.append("</tr>\n");
    // }
    // sb.append("  </table>\n");
    // sb.append("<p> </p>\n");
    //
    // //  major chord details
    // sb.append(
    // "<table border=\"2\" style=\"border-collapse: collapse;\">\n" +
    // "<tr><th>Key</th>" +
    // "<th>Tonic</th>" +
    // "<th>Chord</th>" +
    // "<th>Formula</th>" +
    // "<th>Notes</th>" +
    // "</tr>");
    //
    // String style = " style=\"padding-left: 15px; padding-right: 15px;\"";
    // for (Key key : Key.values()) {
    // for (MusicConstant.MajorDiatonic majorDiatonic : MusicConstant.MajorDiatonic.values()) {
    //
    // ScaleChord builtScaleChord = key.getMajorDiatonicByDegree(majorDiatonic.ordinal());
    //
    // ArrayList<ScaleChord> scaleChords = new ArrayList<>();
    // scaleChords.add(builtScaleChord);
    //
    // sb.append("<tr><td" + style + ">" + key.toString() + " " + key.sharpsFlatsToString() + "</td><td>"
    // + majorDiatonic.name()
    // + "</td><td" + style + ">"
    // + builtScaleChord.toString()
    // + "</td><td" + style + ">");
    // boolean first = true;
    // for (ChordComponent chordComponent : builtScaleChord.getChordComponents()) {
    // if (first)
    // first = false;
    // else
    // sb.append(" ");
    // sb.append(chordComponent.getShortName());
    // }
    // sb.append("</td><td" + style + ">\n");
    //
    // sb.append(chordComponentScaleNotesToString(key, builtScaleChord.getScaleNote().getHalfStep(), builtScaleChord));
    // sb.append("</td></tr>\n");
    // }
    // }
    // sb.append(
    // "  </table>\n");
    //
    // //  minor
    // sb.append(
    // "<p>Minor</p>"
    // + "<table border=\"2\" style=\"border-collapse: collapse;\">\n" +
    // "<tr><th>Key</th><th>i</th>" +
    // "<th>ii</th>" +
    // "<th>III</th>" +
    // "<th>iv</th>" +
    // "<th>v</th>" +
    // "<th>VI</th>" +
    // "<th>VII</th>" +
    // "</tr>");
    //
    // for (Key key : Key.values()) {
    // sb.append("<tr><td style=\"padding: 15px; \">" + key.getMinorScaleChord().toString()
    // + " " + key.sharpsFlatsToString() + "</td>");
    //
    // for (MusicConstant.MinorDiatonic minorDiatonic : MusicConstant.MinorDiatonic.values()) {
    //
    // ScaleChord builtScaleChord = key.getMinorDiatonicByDegree(minorDiatonic.ordinal());
    //
    // ArrayList<ScaleChord> scaleChords = new ArrayList<>();
    // scaleChords.add(builtScaleChord);
    //
    // sb.append("<td style=\"padding: 15px; \">"
    // + builtScaleChord.toString()
    // + "</td>");
    // }
    // sb.append("</tr>\n");
    // }
    // sb.append("  </table>\n");
    // sb.append("<p> </p>\n");
    //
    //
    // //  details
    // sb.append(
    // "<table border=\"2\" style=\"border-collapse: collapse;\">\n" +
    // "<tr><th>Key</th>" +
    // "<th>Tonic</th>" +
    // "<th>Chord</th>" +
    // "<th>Formula</th>" +
    // "<th>Notes</th>" +
    // "</tr>");
    //
    // style = " style=\"padding-left: 15px; padding-right: 15px;\"";
    // for (Key key : Key.values()) {
    // for (MusicConstant.MinorDiatonic minorDiatonic : MusicConstant.MinorDiatonic.values()) {
    //
    // ScaleChord builtScaleChord = key.getMinorDiatonicByDegree(minorDiatonic.ordinal());
    //
    // ArrayList<ScaleChord> scaleChords = new ArrayList<>();
    // scaleChords.add(builtScaleChord);
    //
    // sb.append("<tr><td" + style + ">" + key.getMinorScaleChord().toString() + " " + key
    //     .sharpsFlatsToString() + "</td><td>"
    // + minorDiatonic.name()
    // + "</td><td" + style + ">"
    // + builtScaleChord.toString()
    // + "</td><td" + style + ">");
    // boolean first = true;
    // for (ChordComponent chordComponent : builtScaleChord.getChordComponents()) {
    // if (first)
    // first = false;
    // else
    // sb.append(" ");
    // sb.append(chordComponent.getShortName());
    // }
    // sb.append("</td><td" + style + ">\n");
    //
    // sb.append(chordComponentScaleNotesToString(key, builtScaleChord.getScaleNote().getHalfStep(), builtScaleChord));
    // sb.append("</td></tr>\n");
    // }
    // }
    // sb.append(
    // "  </table>\n");
    // return sb.toString();

    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < MajorDiatonic.values.length + 1; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(
      children: tableRows,
      columnWidths: widths,
      border: TableBorder.all(),
    );
  }

  late AppWidgetHelper appWidgetHelper;

  ChordDescriptor chordDescriptor = ChordDescriptor.major;
  TextStyle _style = generateAppTextStyle(); //  initial default only
}
