import 'dart:collection';

import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_lib/songs/chord_component.dart';
import 'package:bsteele_music_lib/songs/chord_descriptor.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/mode.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/scale_chord.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/material.dart';

const double _defaultFontSize = 28;
music_key.Key _key = music_key.Key.getDefault();
ScaleNote _chordRoot = _key.getKeyScaleNote();
music_key.Key _majorKey = music_key.Key.getDefault();
Mode _modeSelected = Mode.ionian;
ScaleChord _scaleChord = ScaleChord(_key.getKeyScaleNote(), ChordDescriptor.defaultChordDescriptor());
const _halfStepsPerOctave = MusicConstants.halfStepsPerOctave;
Color _backgroundColor = Colors.white;
const _padding = EdgeInsets.symmetric(horizontal: 10, vertical: 5);
TextStyle _style = generateAppTextStyle(); //  initial default only
TextStyle _boldStyle = _style.copyWith(fontWeight: .bold);

/// A screen used to explore music theory including scales, chords, major and minor keys.
class TheoryWidget extends StatefulWidget {
  const TheoryWidget({super.key});

  @override
  TheoryState createState() => TheoryState();

  static const String routeName = 'theoryWidget';
}

class TheoryState extends State<TheoryWidget> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    _style = generateAppTextStyle(color: Colors.black87, fontSize: _defaultFontSize);
    _boldStyle = _style.copyWith(fontWeight: .bold);

    _scaleChord = ScaleChord(_chordRoot, chordDescriptor);
    List<ScaleNote> scaleNoteValues = [];
    {
      var scaleNoteSet = SplayTreeSet<ScaleNote>();
      for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
        scaleNoteSet.add(_key.getKeyScaleNoteByHalfStep(i));
      }
      scaleNoteValues = scaleNoteSet.toList(growable: false);
    }

    _backgroundColor = Theme.of(context).colorScheme.surface;

    const tallSpace = const AppSpace(verticalSpace: 4 * AppSpace.defaultSpace);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'Music Theory'),
      body: Stack(
        children: [
          Container(color: App.measureContainerBackgroundColor),
          SingleChildScrollView(
            //controller: _scrollController,
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                const AppSpace(),
                Row(
                  mainAxisAlignment: .center,
                  crossAxisAlignment: .center,
                  children: [
                    Column(
                      crossAxisAlignment: .start,
                      children: [
                        const AppSpace(),
                        _title('Easy Read'),
                        const AppSpace(),
                        Container(color: _backgroundColor, child: _easyReadTable()),
                        tallSpace,
                        _title('Major/Minor Half Steps'),
                        const AppSpace(),
                        Container(
                          color: _backgroundColor,
                          child: Row(
                            children: [
                              Text('Key: ', style: _style),
                              DropdownButton<music_key.Key>(
                                items: music_key.Key.values.toList().reversed.map((music_key.Key value) {
                                  return DropdownMenuItem<music_key.Key>(
                                    key: ValueKey('half${value.getHalfStep()}'),
                                    value: value,
                                    child: Text(
                                      '${value.toMarkup().padRight(3)} ${value.sharpsFlatsToMarkup()}',
                                      style: _style,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null && value != _key) {
                                    setState(() {
                                      _key = value;
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
                        Container(color: _backgroundColor, child: _keyScaleNoteTable()),

                        tallSpace,
                        _title('Chord Notes'),
                        const AppSpace(),
                        Container(
                          color: _backgroundColor,
                          child: Row(
                            children: [
                              Text('Chord root: ', style: _style),
                              DropdownButton<ScaleNote>(
                                items: scaleNoteValues.map((ScaleNote value) {
                                  return DropdownMenuItem<ScaleNote>(
                                    key: ValueKey('root${value.halfStep}'),
                                    value: value,
                                    child: Text(_key.inKey(value).toMarkup(), style: _style),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null && value != _chordRoot) {
                                    setState(() {
                                      _chordRoot = value;
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
                        const AppSpace(),
                        Container(
                          color: _backgroundColor,
                          child: Row(
                            children: [
                              Text('Chord type: ', style: _style),
                              DropdownButton<ChordDescriptor>(
                                items: ChordDescriptor.values.toList().map((ChordDescriptor value) {
                                  return DropdownMenuItem<ChordDescriptor>(
                                    value: value,
                                    child: Text('${value.toString().padRight(3)} (${value.name})', style: _style),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null && value != chordDescriptor) {
                                    setState(() {
                                      chordDescriptor = value;
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
                        const AppSpace(),
                        Container(color: _backgroundColor, child: _chordTable()),
                        Container(height: 20),

                        tallSpace,
                        _title('Modes'),
                        const AppSpace(),
                        Container(
                          color: _backgroundColor,
                          child: Row(
                            children: [
                              Text('Major Key: ', style: _boldStyle),
                              DropdownButton<music_key.Key>(
                                items: music_key.KeyEnum.values.reversed.map((final music_key.KeyEnum value) {
                                  return DropdownMenuItem<music_key.Key>(
                                    key: ValueKey('keyRoot${value.name}'),
                                    value: music_key.Key.get(value),
                                    child: Text(
                                      '${music_key.Key.get(value).toMarkup().padLeft(2)} '
                                      '${music_key.Key.get(value).keyValue == 0 ? '' : ('  ${music_key.Key.get(value).keyValue.abs()}'
                                                '${music_key.Key.get(value).keyValue > 0 ? '#' : 'b'} ')}',
                                      style: _style,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null && value != _majorKey) {
                                    setState(() {
                                      _majorKey = value;
                                    });
                                  }
                                },
                                value: _majorKey,
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
                        Container(
                          color: _backgroundColor,
                          child: Row(
                            children: [
                              Text('Mode: ', style: _boldStyle),
                              DropdownButton<Mode>(
                                items: Mode.values.map((Mode value) {
                                  return DropdownMenuItem<Mode>(
                                    key: ValueKey('mode${value.halfStep}'),
                                    value: value,
                                    child: Text('${Util.firstToUpper(value.name)}', style: _style),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null && value != _chordRoot) {
                                    setState(() {
                                      _modeSelected = value;
                                    });
                                  }
                                },
                                value: _modeSelected,
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
                        Container(color: _backgroundColor, child: _modesTable()),

                        tallSpace,
                        _title('Major Diatonics'),
                        const AppSpace(),
                        Container(color: _backgroundColor, child: _majorDiatonicsTable()),

                        tallSpace,
                        _title('Minor Diatonics'),
                        const AppSpace(),
                        Container(color: _backgroundColor, child: _minorDiatonicsTable()),
                        tallSpace,
                        _title('Instrument Pitches'),
                        const AppSpace(),
                        Container(color: _backgroundColor, child: _instrumentTable()),
                      ],
                    ),
                  ],
                ),
                const AppSpace(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: appWidgetHelper.floatingBack(),
    );
  }

  Widget _title(final String title) {
    return Container(
      color: _backgroundColor,
      padding: _padding,
      child: Text(title, style: _boldStyle),
    );
  }

  Table _keyScaleNoteTable() {
    final children = <TableRow>[];
    const halfSteps = _halfStepsPerOctave * 2;

    List<Widget> row = [];

    //  major half steps
    {
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Major Half Steps', style: _boldStyle),
        ),
      );

      for (var i = 0; i < halfSteps; i++) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('${(i % MusicConstants.halfStepsPerOctave)}', style: _boldStyle),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    music_key.Key rootKey = _key;

    {
      //  compute major scale notes
      // map[0] = 0; //  root
      // map[2] = 1; //  2nd
      // map[4] = 2; //  major 3rd

      //  display scale notes
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('$_key Major Scale Number', style: _style),
        ),
      );
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var scaleNoteNumber = _key.getMajorScaleNumberByHalfStep(halfStep);
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text((scaleNoteNumber != null ? (scaleNoteNumber + 1).toString() : ''), style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    {
      //  compute major scale notes
      var scaleNotes = <ScaleNote>[];
      for (int n = 0; n < MusicConstants.notesPerScale; n++) {
        scaleNotes.add(_key.inKey(rootKey.getMajorScaleByNote(n)));
      }

      //  display scale notes
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('$_key Major Scale', style: _style),
        ),
      );
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text((scaleNotes.contains(scaleNote) ? scaleNote.toString() : ''), style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    {
      //  compute accidental scale notes
      var scaleNotes = <ScaleNote>[];
      for (int n = 0; n < MusicConstants.notesPerScale; n++) {
        scaleNotes.add(_key.inKey(rootKey.getMajorScaleByNote(n)));
      }

      //  display scale notes
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('$_key Accidentals', style: _style),
        ),
      );
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text((scaleNotes.contains(scaleNote) ? '' : scaleNote.toString()), style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    {
      //  compute easy read accidental scale notes
      var scaleNotes = <ScaleNote>[];
      for (int n = 0; n < MusicConstants.notesPerScale; n++) {
        scaleNotes.add(_key.inKey(rootKey.getMajorScaleByNote(n)));
      }

      //  display scale notes
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('$_key Easy Read Accidentals', style: _style),
        ),
      );
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text((scaleNotes.contains(scaleNote) ? '' : scaleNote.asEasyRead().toString()), style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    {
      //  compute easy read notes
      var scaleNotes = <ScaleNote>[];
      for (int n = 0; n < MusicConstants.notesPerScale; n++) {
        scaleNotes.add(_key.inKey(rootKey.getMajorScaleByNote(n)));
      }

      //  display scale notes
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('$_key Easy Read Notes', style: _style),
        ),
      );
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text(scaleNote.asEasyRead().toString(), style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    //  minor half steps
    {
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Minor Half Steps', style: _style),
        ),
      );

      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('${(halfStep + 3) % MusicConstants.halfStepsPerOctave + 1}', style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    {
      var scaleNote = rootKey.getKeyMinorScaleNote();
      //  compute minor scale notes
      // map[0] = 0; //  root
      // map[2] = 1; //  2nd
      // map[3] = 2; //  minor 3rd

      //  display scale notes
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('${scaleNote.toMarkup()} Minor Scale Number', style: _style),
        ),
      );
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var scaleNoteNumber = _key.getMinorScaleNumberByHalfStep(
          halfStep + MusicConstants.halfStepsFromMajorToAssociatedMinorKey,
        );
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text((scaleNoteNumber != null ? (scaleNoteNumber + 1).toString() : ''), style: _style),
          ),
        );
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
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('${scaleNote.toMarkup()} Minor Scale', style: _style),
        ),
      );
      for (var halfStep = 0; halfStep < halfSteps; halfStep++) {
        var originalScaleNote = minorKey.getKeyScaleNoteByHalfStep(halfStep + 3);
        scaleNote = originalScaleNote.asSharp(value: isSharp);
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text((scaleNotes.contains(originalScaleNote) ? scaleNote.toString() : ''), style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < halfSteps + 1; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(children: children, columnWidths: widths, border: TableBorder.all());
  }

  Table _easyReadTable() {
    final children = <TableRow>[];

    List<Widget> row = [];

    //  half steps
    {
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Half Steps', style: _style),
        ),
      );

      for (var i = 0; i < _halfStepsPerOctave; i++) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('$i', style: _style),
          ),
        );
      }
    }
    children.add(TableRow(children: row));

    //  original scale notes
    {
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Original Note', style: _style),
        ),
      );

      for (var i = 0; i < _halfStepsPerOctave; i++) {
        var sharpScaleNote = ScaleNote.getSharpByHalfStep(i);
        ScaleNote flatScaleNote = sharpScaleNote.alias;

        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('$sharpScaleNote${sharpScaleNote != flatScaleNote ? ' or $flatScaleNote' : ''}', style: _style),
          ),
        );
      }
    }
    children.add(TableRow(children: row));

    //  easy read scale notes
    {
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Easy Read', style: _boldStyle),
        ),
      );

      for (var i = 0; i < _halfStepsPerOctave; i++) {
        var scaleNote = ScaleNote.getSharpByHalfStep(i).asEasyRead();
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('$scaleNote', style: _style),
          ),
        );
      }
    }
    children.add(TableRow(children: row));

    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < _halfStepsPerOctave + 1; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(children: children, columnWidths: widths, border: TableBorder.all());
  }

  Table _chordTable() {
    final children = <TableRow>[];

    List<Widget> row = [];

    //  halfsteps
    {
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Half Steps', style: _boldStyle),
        ),
      );

      for (var i = 0; i < 2 * _halfStepsPerOctave; i++) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('$i', style: _boldStyle),
          ),
        );
      }
    }
    children.add(TableRow(children: row));

    //  structure
    row = [];
    row.add(
      Container(
        padding: _padding,
        alignment: .centerRight,
        child: Text('Relative Note', style: _style),
      ),
    );
    for (var halfStep = 0; halfStep < MusicConstants.halfStepsPerOctave; halfStep++) {
      final ChordComponent v = ChordComponent.getByHalfStep(halfStep);
      row.add(
        Container(
          padding: _padding,
          alignment: .center,
          child: Text(v.shortName, style: _style),
        ),
      );
    }
    for (var halfStep = 0; halfStep < MusicConstants.halfStepsPerOctave; halfStep++) {
      final ChordComponent v = ChordComponent.getByHalfStep(halfStep);
      final int number = v.scaleNumber + MusicConstants.notesPerScale;
      final String name =
          '${v.shortName.replaceFirst('${v.scaleNumber}', '$number').replaceFirst('m', 'b').replaceFirst('R', '8')}';
      row.add(
        Container(
          padding: _padding,
          alignment: .center,
          child: Text(name, style: _style),
        ),
      );
    }

    children.add(TableRow(children: row));

    music_key.Key rootKey = music_key.Key.getKeyByHalfStep(_chordRoot.halfStep);

    //  compute scale notes
    var scaleNotes = <ScaleNote>[];
    for (int n = 0; n < MusicConstants.notesPerScale; n++) {
      scaleNotes.add(_key.inKey(rootKey.getMajorScaleByNote(n)));
    }
    // print('scaleNotes: $scaleNotes');

    //  display scale notes
    row = [];
    row.add(
      Container(
        padding: _padding,
        alignment: .centerRight,
        child: Text('Scale Notes', style: _style),
      ),
    );
    for (var halfStep = 0; halfStep < 2 * _halfStepsPerOctave; halfStep++) {
      var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
      row.add(
        Container(
          padding: _padding,
          alignment: .center,
          child: Text(scaleNote.toString(), style: _style),
        ),
      );
    }
    children.add(TableRow(children: row));

    // row = [];
    // row.add(
    //   Container(
    //     padding: _padding,
    //     alignment: .centerRight,
    //     child: Text('Accidentals', style: _style),
    //   ),
    // );
    // for (var halfStep = 0; halfStep < 2 * _halfStepsPerOctave; halfStep++) {
    //   var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
    //   row.add(
    //     Container(
    //       padding: _padding,
    //       alignment: .center,
    //       child: Text((scaleNotes.contains(scaleNote) ? '' : scaleNote.toString()), style: _style),
    //     ),
    //   );
    // }
    // children.add(TableRow(children: row));

    row = [];
    row.add(
      Container(
        padding: _padding,
        alignment: .centerRight,
        child: Text('Chord Notes', style: _style),
      ),
    );

    var chordHalfSteps = _scaleChord.getChordComponents().map((chordComponent) {
      return chordComponent.halfSteps;
    }).toList();
    // print('_scaleChord.getChordComponents(): ${_scaleChord.getChordComponents()}');
    // print('chordHalfSteps: $chordHalfSteps');
    for (var halfStep = 0; halfStep < 2 * _halfStepsPerOctave; halfStep++) {
      var scaleNote = _key.inKey(rootKey.getKeyScaleNoteByHalfStep(halfStep));
      row.add(
        Container(
          padding: _padding,
          alignment: .center,
          child: Text((chordHalfSteps.contains(halfStep) ? scaleNote.toString() : ''), style: _style),
        ),
      );
    }
    children.add(TableRow(children: row));

    //  declare the table widths for each column
    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < 2 * _halfStepsPerOctave + 1; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(children: children, columnWidths: widths, border: TableBorder.all());
  }

  Table _modesTable() {
    final children = <TableRow>[];

    //  notes
    List<Widget> row = [];
    {
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Notes', style: _boldStyle),
        ),
      );

      for (var i = 0; i < MusicConstants.notesPerScale; i++) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('  ${i + 1}  ', style: _boldStyle),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    {
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Formula', style: _boldStyle),
        ),
      );

      var components = getModeChordComponents(_modeSelected);
      for (var i = 0; i < MusicConstants.notesPerScale; i++) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('${i == 0 ? '1' : components[i].shortName}', style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    {
      row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Scale', style: _boldStyle),
        ),
      );

      music_key.Key musicKey = _majorKey;
      for (var i = 0; i < MusicConstants.notesPerScale; i++) {
        ScaleNote scaleNote = getModeNote(musicKey, _modeSelected, i);

        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text('$scaleNote', style: _style),
          ),
        );
      }
      children.add(TableRow(children: row));
    }

    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < MusicConstants.notesPerScale + 1; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(children: children, columnWidths: widths, border: TableBorder.all());
  }

  Table _majorDiatonicsTable() {
    final tableRows = <TableRow>[];

    //  major diatonic names
    {
      List<Widget> row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Major Key', style: _boldStyle),
        ),
      );
      for (var diatonic in MajorDiatonic.values) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text(diatonic.name, style: _boldStyle),
          ),
        );
      }
      tableRows.add(TableRow(children: row));
    }

    for (var key in music_key.Key.values) {
      List<Widget> row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('${key.name} ', style: _style),
        ),
      );
      int diatonicDegrees = MajorDiatonic.values.length;
      for (var diatonicDegree = 0; diatonicDegree < diatonicDegrees; diatonicDegree++) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text(key.getMajorDiatonicByDegree(diatonicDegree).toString(), style: _style),
          ),
        );
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

    return Table(children: tableRows, columnWidths: widths, border: TableBorder.all());
  }

  Table _minorDiatonicsTable() {
    final tableRows = <TableRow>[];

    //  major diatonic names
    {
      List<Widget> row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('Minor Key', style: _boldStyle),
        ),
      );
      for (var diatonic in MinorDiatonic.values) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text(diatonic.name, style: _boldStyle),
          ),
        );
      }
      tableRows.add(TableRow(children: row));
    }

    for (var key in music_key.Key.values) {
      List<Widget> row = [];
      row.add(
        Container(
          padding: _padding,
          alignment: .centerRight,
          child: Text('${key.getMinorKey()} ', style: _style),
        ),
      );
      int diatonicDegrees = MinorDiatonic.values.length;
      for (var diatonicDegree = 0; diatonicDegree < diatonicDegrees; diatonicDegree++) {
        row.add(
          Container(
            padding: _padding,
            alignment: .center,
            child: Text(key.getMinorDiatonicByDegree(diatonicDegree).toString(), style: _style),
          ),
        );
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

    return Table(children: tableRows, columnWidths: widths, border: TableBorder.all());
  }

  Table _instrumentTable() {
    final tableRows = <TableRow>[];

    tableRows.add(
      TableRow(
        children: [
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('Concert Pitch', style: _boldStyle),
          ),
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('Instrument(s)', style: _boldStyle),
          ),
        ],
      ),
    );

    tableRows.add(
      TableRow(
        children: [
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('C  +0 (-0): No Transposition', style: _style),
          ),
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('Piccolo, Flute,  Oboe, Bassoon,  Trombone, Baritone B.C., Tuba', style: _style),
          ),
        ],
      ),
    );

    tableRows.add(
      TableRow(
        children: [
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('Bb +2 (-10): up a major 2nd', style: _style),
          ),
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text(
              'Clarinet, Bass Clarinet, Soprano Saxophone, Tenor Saxophone'
              ', Trumpet, Baritone T.C.',
              style: _style,
            ),
          ),
        ],
      ),
    );

    tableRows.add(
      TableRow(
        children: [
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('Eb +9 (-3):  down a minor 3rd', style: _style),
          ),
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('Soprano Clarinet, Alto Clarinet, Alto Saxophone, Baritone Saxophone', style: _style),
          ),
        ],
      ),
    );

    tableRows.add(
      TableRow(
        children: [
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('F  +7 (-5):   up a perfect 5th', style: _style),
          ),
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('English Horn, French Horn', style: _style),
          ),
        ],
      ),
    );

    tableRows.add(
      TableRow(
        children: [
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('G  +7 (-5):   up a perfect 4th', style: _style),
          ),
          Container(
            padding: _padding,
            alignment: .centerLeft,
            child: Text('Alto Flute', style: _style),
          ),
        ],
      ),
    );

    Map<int, TableColumnWidth> widths = {};
    for (var i = 0; i < 2; i++) {
      widths[i] = const IntrinsicColumnWidth(flex: 1);
    }

    return Table(children: tableRows, columnWidths: widths, border: TableBorder.all());
  }

  late AppWidgetHelper appWidgetHelper;

  ChordDescriptor chordDescriptor = ChordDescriptor.major;
}
