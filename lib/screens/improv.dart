import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/chord.dart';
import 'package:bsteele_music_lib/songs/measure.dart';
import 'package:bsteele_music_lib/songs/measure_node.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/phrase.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/section.dart';
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

TextStyle _chordTextStyle = generateAppTextStyle(fontSize: _defaultChordFontSize, color: Colors.black87);
TextStyle _boldChordTextStyle = generateAppTextStyle(
  fontSize: _defaultChordFontSize,
  color: Colors.black87,
  fontWeight: FontWeight.bold,
);

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
    for (final focusNode in disposeList) {
      focusNode.dispose();
    }
    focusNode.dispose();
    super.dispose();
    logger.d('edit dispose()');
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);
    app.screenInfo.refresh(context);

    //  adjust to screen size
    chordFontSize = 2 * _defaultChordFontSize;

    var theme = Theme.of(context);

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
                            controller: proChordTextEditingController,
                            focusNode: proChordTextFieldFocusNode,
                            minLines: 1,
                            maxLines: 1,
                            fontSize: chordFontSize,
                            fontWeight: .normal,
                            width: MediaQuery.of(context).size.width * 0.55,
                            border: .none,
                            onSubmitted: (value) {
                              checkSong();
                              FocusScope.of(context).requestFocus(proChordTextFieldFocusNode);
                            },
                          ),
                        ),
                        //  search clear
                        appIconButton(
                          icon: const Icon(Icons.clear),
                          iconSize: 1.25 * chordFontSize,
                          onPressed: (() {
                            proChordTextEditingController.clear();
                            app.clearMessage();
                            setState(() {
                              FocusScope.of(context).requestFocus(proChordTextFieldFocusNode);
                              //_lastSelectedSong = null;
                            });
                          }),
                        ),
                      ],
                    ),
                    const AppSpace(),
                    _improvDisplay(),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget titleCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.all(_defaultChordFontSize), // Change size as needed
      child: Center(child: child),
    );
  }

  Widget myCell(Widget child, {ScaleNote? scaleNote}) {
    if (scaleNote == null) {
      return Padding(
        padding: const EdgeInsets.all(8.0), // Change size as needed
        child: Center(child: child),
      );
    }
    return Container(
      color: scaleNoteColors[scaleNote.halfStep],
      child: Padding(
        padding: const EdgeInsets.all(8.0), // Change size as needed
        child: Center(child: child),
      ),
    );
  }

  Widget _improvDisplay() {
    if (!isValidSong) {
      return NullWidget();
    }

    List<Chord?> chordCols = [];
    for (Measure measure in _improvPhrase.measures) {
      if (chordCols.isNotEmpty) {
        chordCols.add(null);
      }
      for (Chord chord in measure.chords) {
        chordCols.add(chord);
      }
    }

    List<TableRow> tableRows = [];

    {
      List<Widget> children = [];
      for (final Chord? chord in chordCols) {
        children.add(titleCell(Text(chord?.toString() ?? '', style: _boldChordTextStyle)));
      }
      TableRow tableRow = TableRow(children: children);
      tableRows.add(tableRow);
    }

    //  pentatonics
    for (int r = 0; r < MusicConstants.halfStepsPerOctave; r++) {
      List<Widget> children = [];

      for (final Chord? chord in chordCols) {
        if (chord == null) {
          children.add(myCell(NullWidget()));
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
        }

        children.add(
          myCell(
            Text('${label != null ? '${scaleNote?.toString()}' : ''}', style: _chordTextStyle),
            scaleNote: scaleNote ,
          ),
        );
      }
      TableRow tableRow = TableRow(children: children);
      tableRows.add(tableRow);
    }

    return Table(
      border: TableBorder.all(color: Colors.grey, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: tableRows,
    );
  }

  Widget nullEditGridDisplayWidget() {
    return const Text(
      '',
      //' null',  //  diagnostic
    );
  }

  void undo() {
    setState(() {
      checkSong();
      // if (undoStack.canUndo) {
      //   app.clearMessage();
      //   clearMeasureEntry();
      //   undoStackLog('pre undo');
      //   loadSong(undoStack.undo()?.copySong() ?? Song.createEmptySong());
      //   undoStackLog('post undo');
      //   logger.t('song key: ${song.key}');
      //   checkSongChangeStatus();
      // } else {
      //   app.errorMessage('cannot undo any more');
      // }
    });
  }

  ///  delete the current measure
  void performDelete() {
    setState(() {});
  }

  bool checkSong() {
    setState(() {
      try {
        logger.log(_logTextEntry, 'checkSong: "${proChordTextEditingController.text}"');
        MarkedString markedString = MarkedString(SongBase.entryToUppercase(proChordTextEditingController.text));
        _improvPhrase = Phrase.parse(markedString, 0, _beatsPerBar, null);
        logger.log(_logTextEntry, 'phrase: $_improvPhrase, markedString: "$markedString"');
        isValidSong = markedString.isEmpty;

        if (isValidSong) {
          app.clearMessage();
          proChordTextEditingController.text = _improvPhrase.toString();
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

  String listSections() {
    var sb = StringBuffer();
    var first = true;
    for (final s in Section.values) {
      if (first) {
        first = false;
      } else {
        sb.write(', ');
      }
      sb.write(s.formalName);
    }
    return sb.toString();
  }

  String listSectionAbbreviations() {
    var sb = StringBuffer();
    var first = true;
    for (final s in Section.values) {
      if (first) {
        first = false;
      } else {
        sb.write(', ');
      }
      s.formalName;
      sb.write('${s.formalName}: \'${s.abbreviation.toLowerCase()}:\'');
      if (s.alternateAbbreviation != null) {
        sb.write(' or \'${s.alternateAbbreviation!.toLowerCase()}:\'');
      }
    }
    return sb.toString();
  }

  /// helper function to generate tool tips
  Widget editTooltip({Key? key, required String message, required Widget child}) {
    return AppTooltip(key: key, message: message, child: child);
  }

  bool isValidSong = false;

  double chordFontSize = 14;

  List<MeasureNode>? measureEntryNodes;
  MeasureNode? displayMeasureEntryNode;

  EdgeInsets marginInsets = const EdgeInsets.all(4);
  EdgeInsets doubleMarginInsets = const EdgeInsets.all(8);
  static const EdgeInsets textPadding = EdgeInsets.all(6);
  static const EdgeInsets appendInsets = EdgeInsets.all(3);
  static const EdgeInsets appendPadding = EdgeInsets.all(3);

  TextEditingController proChordTextEditingController = TextEditingController();
  FocusNode proChordTextFieldFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  final List<ChangeNotifier> disposeList = []; //  fixme: workaround to dispose the text controllers

  final FocusManager focusManager = FocusManager.instance;
  final FocusNode focusNode = FocusNode();
}
