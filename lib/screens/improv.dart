import 'dart:async';
import 'dart:math';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/lyricsEntries.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/key.dart' as musical_key;
import 'package:bsteele_music_lib/songs/measure_node.dart';
import 'package:bsteele_music_lib/songs/phrase.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/section.dart';
import 'package:bsteele_music_lib/songs/section_version.dart';
import 'package:bsteele_music_lib/songs/song_edit_manager.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';

const Level _logTextEntry = Level.info;

const double _defaultChordFontSize = 22;
int _beatsPerBar = 4;

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
    if (_idleTimer != null) {
      _idleTimer!.cancel();
    }

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
    chordFontSize = 4 * _defaultChordFontSize;

    //  build the chords display based on the song chord section grid
    tableKeyId = 0;

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
            onKeyEvent: _improvOnKey,
            child: Column(
              children: [
                app.messageTextWidget(),
                // const AppVerticalSpace(space: 10),
                Expanded(
                  child: GestureDetector(
                    // fixme: put GestureDetector only on chord table
                    child: Scrollbar(
                      thickness: max(16.0, 0.0125 * app.screenInfo.mediaWidth),
                      controller: scrollController,
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, spacing: 10, children: <Widget>[]),
                            const AppSpace(),
                            //  chords
                            AppWrapFullWidth(
                              alignment: WrapAlignment.spaceBetween,
                              children: <Widget>[
                                AppWrap(
                                  spacing: 50,
                                  children: [
                                    editTooltip(
                                      message:
                                          'Validate the chord input.\n'
                                          'This will also reformat the entry.',
                                      child: appButton(
                                        'Validate',
                                        fontSize: _defaultChordFontSize,
                                        onPressed: () {
                                          setState(() {
                                            // validateSongChords(select: true);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            Container(
                              alignment: .topLeft,
                              padding: const EdgeInsets.all(16.0),
                              color: theme.colorScheme.surface,
                              child: AppTextField(
                                controller: proChordTextEditingController,
                                focusNode: proChordTextFieldFocusNode,
                                minLines: 1,
                                maxLines: 1,
                                fontSize: chordFontSize,
                                fontWeight: .normal,
                                width: MediaQuery.of(context).size.width * 0.96,
                                border: .none,
                                onChanged: (value) {
                                  checkSongWhenIdle();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    onTap: () {
                      logger.t('GestureDetector.onTap():');
                      performMeasureEntryCancel();
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void addChordRowNullChildrenUpTo(int columns) {
    //  add children to max columns to keep the table class happy
    while (chordRowChildren.length < columns) {
      chordRowChildren.add(NullWidget());
    }
  }

  void _improvOnKey(KeyEvent e) {}

  void addChordRowChildAtRowEnd(int maxCols, Widget child) {
    //  add children to max columns to keep the table class happy
    addChordRowNullChildrenUpTo(maxCols - 1);
    chordRowChildren.add(child);
  }

  void addChordRowChildrenAndComplete(int maxCols) {
    //  add children to max columns to keep the table class happy
    addChordRowNullChildrenUpTo(maxCols);

    //  add row to table
    chordRows.add(TableRow(key: ValueKey('table${tableKeyId++}'), children: chordRowChildren));

    //  prep for new row
    chordRowChildren = [];
  }

  void addChordRowNullWidget() {
    chordRowChildren.add(NullWidget());
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

  void setEditPoint(EditPoint editPoint) {
    setState(() {
      clearMeasureEntry();
      app.clearMessage();
      selectedEditPoint = editPoint;
      logger.log(_logTextEntry, 'setEditPoint(${editPoint.toString()})');
    });
  }

  void performMeasureEntryCancel() {
    setState(() {
      clearMeasureEntry();
    });
  }

  void clearMeasureEntry() {
    logger.d('_clearMeasureEntry():');
    selectedEditPoint = null;
    measureEntryIsClear = true;
    measureEntryCorrection = null;
    measureEntryValid = false;
  }

  void checkSongWhenIdle() {
    logger.log(_logTextEntry, 'checkSongWhenIdle(): "${proChordTextEditingController.text}"');
    if (_idleTimer != null) {
      _idleTimer!.cancel();
    }

    _idleTimer = Timer(const Duration(milliseconds: 700), () {
      setState(() {
        checkSong();
      });
    });
  }

  bool checkSong() {
    try {
      logger.log(_logTextEntry, 'checkSong: "${proChordTextEditingController.text}"');
      MarkedString markedString = MarkedString(proChordTextEditingController.text);
      Phrase phrase = Phrase.parse(markedString, 0, _beatsPerBar, null);
      logger.log(_logTextEntry, 'phrase: $phrase, markedString: "$markedString"');
      isValidSong = markedString.isEmpty;
      app.errorMessage(isValidSong ? '' : 'not understood: "$markedString"');
    } catch (e) {
      isValidSong = false;
      app.errorMessage(e.toString());
    }
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
  bool isValidSongChordsAndLyrics = false;

  double chordFontSize = 14;

  EditPoint? selectedEditPoint;
  bool hadSelectedEditPoint = false;

  int transpositionOffset = 0;

  Timer? _idleTimer;
  bool measureEntryIsClear = true;
  String? measureEntryCorrection;
  bool measureEntryValid = false;

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

  List<TableRow> chordRows = [];
  List<Widget> chordRowChildren = [];
  int tableKeyId = 0;

  LyricsEntries lyricsEntries = LyricsEntries();

  SectionVersion sectionVersion = SectionVersion.defaultInstance;
  ScaleNote keyChordNote = musical_key.MajorKey.getDefault().getKeyScaleNote();

  final List<ChangeNotifier> disposeList = []; //  fixme: workaround to dispose the text controllers

  final FocusManager focusManager = FocusManager.instance;
  final FocusNode focusNode = FocusNode();
}

/*
v: a b c d, d c g g
C: C G D A, E E E E


Off the top of my head, since the order of flats is
B, E, A, D, G, C and F

We pretty-much never see Gb, Cb and Fb  (because Cb is B and Fb is E)

going the other way, we pretty-much never see A#, E#, and B# (Because E# is F and B# is C)

 */

/*
 final List<DropdownMenuItem<int>> repeatDropDownMenuList = [];

    //
    //  stuff the repeat Drop Down Menu List
    repeatDropDownMenuList.clear();
    repeatDropDownMenuList.add(appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.editRepeatX2, value: 2, child: Text('x2', style: appDropdownListItemTextStyle)));
    repeatDropDownMenuList.add(appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.editRepeatX3, value: 3, child: Text('x3', style: appDropdownListItemTextStyle)));
    repeatDropDownMenuList.add(appDropdownMenuItem(
        appKeyEnum: AppKeyEnum.editRepeatX4, value: 4, child: Text('x4', style: appDropdownListItemTextStyle)));


    editTooltip(
                        message: 'Add a repeat for this row',
                        child: ButtonTheme(
                          alignedDropdown: true,
                          child: DropdownButton<int>(
                            hint: Text(
                              "repeats",
                              style: sectionAppTextStyle,
                            ),
                            items: repeatDropDownMenuList,
                            onChanged: (_value) {
                              setState(() {
                                logger.log(_log, 'repeat at: ${editPoint.location}');
                                song.setRepeat(editPoint.location, _value ?? 1);
                                undoStackPushIfDifferent();
                                clearMeasureEntry();
                              });
                            },
                            itemHeight: null,
                          ),
                        ),
                      ),

 */
