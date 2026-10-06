import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/grid.dart';
import 'package:bsteele_music_lib/songs/chord.dart';
import 'package:bsteele_music_lib/songs/measure.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/phrase.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/song_base.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';

const Level _logTextEntry = Level.debug;

Phrase _improvPhrase = Phrase([], 0);
List<String?> _majorPentatonicHalfStepLabels = [
  '1', //  0
  null,
  '2', //  2
  null,
  '3', //  4
  null,
  null,
  '5', // 7
  null,
  '6', //  9
  null,
  null, //  11
];
List<String?> _minorPentatonicHalfStepLabels = [
  '1', //  0
  null,
  null,
  'b3', //  3
  null,
  '4', //  5
  null,
  '5', // 7
  null,
  null,
  'b7', //  10
  null,
];

const double _defaultChordFontSize = 22;
int _beatsPerBar = 4;
const double _rowHeight = 66;
List<Chord?> _chordCols = [];
Grid<ScaleNote> _scaleNoteGrid = Grid();

final List<Color> scaleNoteColors = [
  Color.fromARGB(255, 255, 99, 0), //  A
  Color.fromARGB(255, 242, 178, 4), //  A#
  Color.fromARGB(255, 166, 225, 3), //  B
  Color.fromARGB(240, 0, 255, 13), // C
  Color.fromARGB(255, 0, 255, 232), //  C#
  Color.fromARGB(255, 20, 200, 255), //  D
  Color.fromARGB(255, 20, 100, 255), //  D#
  Color.fromARGB(255, 137, 80, 255), //  E
  Color.fromARGB(255, 176, 20, 180), //  F
  Color.fromARGB(255, 200, 40, 100), //  F#
  Color.fromARGB(255, 240, 30, 50), //  G
  Color.fromARGB(255, 255, 40, 0), //  G#
];

TextStyle _chordTextStyle = generateAppTextStyle(fontSize: 1.5 * _defaultChordFontSize, color: Colors.black87);

///   screen to facilitate an improv session
class Improv extends StatefulWidget {
  Improv({super.key});

  @override
  ImprovState createState() => ImprovState();

  static const String routeName = 'improv';
}

class ImprovState extends State<Improv> {
  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
    logger.d('edit dispose()');
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);
    app.screenInfo.refresh(context);

    //  adjust to screen size
    chordFontSize = _defaultChordFontSize;

    var theme = Theme.of(context);

    _computePentatonics();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appWidgetHelper.appBar(
        title: 'Improv',
        leading: appWidgetHelper.back(
          onPressed: () {
            app.clearMessage();
          },
        ),
      ),
      body:
          //  deal with keyboard strokes flutter is not usually handling
          //  note that return (i.e. enter) is not a keyboard event!
          KeyboardListener(
            focusNode: FocusNode(),
            child: Column(
              children: [
                app.messageTextWidget(),
                // const AppVerticalSpace(space: 10),
                Column(
                  children: [
                    AppWrapFullWidth(
                      alignment: WrapAlignment.start,
                      spacing: 2,
                      children: <Widget>[
                        const AppSpace(),
                        Text('Improv measures:', style: _chordTextStyle),
                        const AppSpace(),

                        Container(
                          // alignment: .topLeft,
                          padding: const EdgeInsets.all(16.0),
                          color: theme.colorScheme.surface,
                          child: AppTextField(
                            controller: improvEntryController,
                            focusNode: improvEntryFocusNode,
                            minLines: 1,
                            maxLines: 1,
                            fontSize: chordFontSize,
                            fontWeight: .normal,
                            width: MediaQuery.of(context).size.width * 0.55,
                            border: .none,
                            onSubmitted: (value) {
                              checkSong();
                              FocusScope.of(context).requestFocus(improvEntryFocusNode);
                            },
                          ),
                        ),
                        //  search clear
                        appIconButton(
                          icon: const Icon(Icons.clear),
                          iconSize: 1.25 * chordFontSize,
                          onPressed: (() {
                            improvEntryController.clear();
                            app.clearMessage();
                            setState(() {
                              FocusScope.of(context).requestFocus(improvEntryFocusNode);
                              //_lastSelectedSong = null;
                            });
                          }),
                        ),
                      ],
                    ),
                    Center(
                      child: CustomPaint(
                        size: Size(1900, 14 * _rowHeight), // Specify the canvas boundaries
                        painter: ImprovPainter(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _computePentatonics() {
    _chordCols.clear();
    if (!isValidSong) {
      return;
    }

    for (Measure measure in _improvPhrase.measures) {
      if (_chordCols.isNotEmpty) {
        _chordCols.add(null);
      }
      for (Chord chord in measure.chords) {
        _chordCols.add(chord);
      }
    }

    _scaleNoteGrid = Grid();

    //  pentatonic rows
    for (int r = 0; r < MusicConstants.halfStepsPerOctave; r++) {
      for (int c = 0; c < _chordCols.length; c++) {
        final Chord? chord = _chordCols[c];
        if (chord == null) {
          continue;
        }

        String? label;
        ScaleNote? scaleNote;

        if (chord.scaleChord.chordDescriptor.isMajor()) {
          label = _majorPentatonicHalfStepLabels[r];
        } else if (chord.scaleChord.chordDescriptor.isMinor()) {
          label = _minorPentatonicHalfStepLabels[r];
        } else {
          scaleNote = ScaleNote.X; //  showcase an error!
        }
        if (label != null) {
          scaleNote = ScaleNote.getFlatByHalfStep(chord.scaleChord.scaleNote.halfStep + r);
          _scaleNoteGrid.set(r, c, scaleNote);
        }
      }
    }
  }

  bool checkSong() {
    setState(() {
      try {
        logger.log(_logTextEntry, 'checkSong: "${improvEntryController.text}"');
        MarkedString markedString = MarkedString(SongBase.entryToUppercase(improvEntryController.text));
        _improvPhrase = Phrase.parse(markedString, 0, _beatsPerBar, null);
        logger.log(_logTextEntry, 'phrase: $_improvPhrase, markedString: "$markedString"');
        isValidSong = markedString.isEmpty;

        if (isValidSong) {
          app.clearMessage();
          improvEntryController.text = _improvPhrase.toString();
        } else {
          app.errorMessage('not understood: "$markedString"');
        }
      } catch (e) {
        isValidSong = false;
        app.errorMessage(e.toString());
      }
      logger.log(_logTextEntry, 'app.error: ${app.error}');
    });
    return isValidSong;
  }

  bool isValidSong = false;

  double chordFontSize = 14;

  TextEditingController improvEntryController = TextEditingController();
  FocusNode improvEntryFocusNode = FocusNode();

  final FocusManager focusManager = FocusManager.instance;
  final FocusNode focusNode = FocusNode();
}

class ImprovPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final brush = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 5;
    const double radius = 50;
    const double measureWidth = 250;

    //  draw the relationships in the background
    for (int r = 0; r < MusicConstants.halfStepsPerOctave; r++) {
      for (int c = 0; c < _chordCols.length; c++) {
        ScaleNote? scaleNote = _scaleNoteGrid.get(r, c);
        if (scaleNote != null) {
          final Offset offset = Offset(radius + c * measureWidth + radius, r * _rowHeight + radius);
          brush.color = scaleNoteColors[scaleNote.halfStep % MusicConstants.halfStepsPerOctave];

          //  find the next use of the scale note
          {
            int nextC;
            for (nextC = c + 1; nextC < _chordCols.length; nextC++) {
              if (_scaleNoteGrid.get(0, nextC) != null) {
                break;
              }
            }
            final nextX = radius + nextC * measureWidth + radius; //  loop to the first
            if ( nextC == _chordCols.length){
              nextC = 0;
            }

            for (int nextR = 0; nextR < MusicConstants.halfStepsPerOctave; nextR++) {
              ScaleNote? nextScaleNote = _scaleNoteGrid.get(nextR, nextC);
              if (scaleNote == nextScaleNote) {
                canvas.drawLine(
                  offset,
                  Offset(nextX, nextR * _rowHeight + radius),
                  brush,
                );
              }
            }
          }
        }
      }
    }

    //  draw the scale notes
    for (int r = 0; r < MusicConstants.halfStepsPerOctave; r++) {
      for (int c = 0; c < _chordCols.length; c++) {
        ScaleNote? scaleNote = _scaleNoteGrid.get(r, c);
        if (scaleNote != null) {
          final double x = radius + c * measureWidth + radius;
          final double y = r * _rowHeight + radius;
          final Offset offset = Offset(x, y);
          brush.color = scaleNoteColors[scaleNote.halfStep % MusicConstants.halfStepsPerOctave];
          canvas.drawCircle(offset, radius, brush);

          final textSpan = TextSpan(
            text: scaleNote.toString(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 3 * _defaultChordFontSize,
              fontWeight: FontWeight.bold,
            ),
          );

          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr, // Text direction is required
          );

          textPainter.layout(
            minWidth: 0,
            maxWidth: size.width, // Prevents text from overflowing the canvas width
          );

          textPainter.paint(canvas, offset - Offset(textPainter.width / 2, textPainter.height / 2));
        }
      }
    }

    //  repeat the first scale notes without the scale note labels
    for (int r = 0; r < MusicConstants.halfStepsPerOctave; r++) {
     int c = 0;
        ScaleNote? scaleNote = _scaleNoteGrid.get(r, c);
        if (scaleNote != null) {
          final double x = radius + _chordCols.length * measureWidth + radius;
          final double y = r * _rowHeight + radius;
          final Offset offset = Offset(x, y);
          brush.color = scaleNoteColors[scaleNote.halfStep % MusicConstants.halfStepsPerOctave];
          canvas.drawCircle(offset, radius, brush);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false; // Return true if your configuration properties change dynamically
  }
}
