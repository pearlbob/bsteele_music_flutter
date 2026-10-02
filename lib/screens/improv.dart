import 'dart:async';
import 'dart:math';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/lyricsEntries.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/key.dart' as musical_key;
import 'package:bsteele_music_lib/songs/measure_node.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/section.dart';
import 'package:bsteele_music_lib/songs/section_version.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_edit_manager.dart';
import 'package:bsteele_music_lib/util/undo_stack.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';

const double _defaultChordFontSize = 22;

const bool _logDebug = kDebugMode && false;
const Level _log = Level.debug;
const Level _logEditPoint = Level.debug;
const Level _logUndoStack = Level.debug;

///   screen to edit a song
///   Note: This screen is scaled differently than the others.
///   It is expected that it will only be used on a desktop only
///   and will not be displayed to the musicians on a large screen display.
class Improv extends StatefulWidget {
  Improv({super.key});

  @override
  ImprovState createState() => ImprovState();

  static const String routeName = 'improv';
}

class ImprovState extends State<Improv> {
  ImprovState() {
    //  _checkSongStatus();

    undoStackPush();
  }

  @override
  initState() {
    super.initState();

    editTextFieldFocusNode = FocusNode();
    editTextFieldFocusNode?.addListener(() {
      logger.log(_log, 'focusNode.listener()');
    });

    editTextController.addListener(() {
      //  fixme: workaround for loss of focus when pressing an edit button
      TextSelection textSelection = editTextController.selection;
      if (textSelection.baseOffset >= 0) {
        lastEditTextSelection = textSelection.copyWith();
      }
    });
  }

  @override
  void dispose() {
    editTextController.dispose();
    editTextFieldFocusNode?.dispose();
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
    chordFontSize = 5 * _defaultChordFontSize;
    appendFontSize = chordFontSize * 0.75;

    chordBoldTextStyle = generateAppTextStyle(fontWeight: .bold, fontSize: chordFontSize);
    chordTextStyle = generateAppTextStyle(fontSize: appendFontSize, color: Colors.black87);

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
                                AppWrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 25,
                                  children: <Widget>[
                                    editTooltip(
                                      message: undoStack.canUndo ? 'Undo the last edit' : 'There is nothing to undo',
                                      child: appButton(
                                        'Undo',
                                        fontSize: _defaultChordFontSize,
                                        onPressed: () {
                                          undo();
                                        },
                                      ),
                                    ),
                                    editTooltip(
                                      message: undoStack.canUndo
                                          ? 'Redo the last edit undone'
                                          : 'There is no edit to redo',
                                      child: appButton(
                                        'Redo',
                                        fontSize: _defaultChordFontSize,
                                        onPressed: () {
                                          redo();
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
                                fontSize: 4 * _defaultChordFontSize,
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
      // checkSong();
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

  void redo() {
    // checkSong();
    setState(() {
      // if (undoStack.canRedo) {
      //   app.clearMessage();
      //   clearMeasureEntry();
      //   loadSong(undoStack.redo()?.copySong() ?? Song.createEmptySong());
      //   undoStackLog('redo');
      //   logger.t('song key: ${song.key}');
      //   checkSongChangeStatus();
      // } else {
      //   app.errorMessage('cannot redo any more');
      // }
    });
  }

  ///  don't push an identical copy 1234
  void undoStackPushIfDifferent() {
    // if (!(song.songBaseSameContent(undoStack.top))) {
    //   //  fixme: what was this doing?:  song.lastModifiedTime = originalSong.lastModifiedTime;
    //   undoStackPush();
    //   logger.log(_logUndoStack, 'undoStackPushIfDifferent ${undoStackAllToString()}');
    // }
  }

  /// push a copy of the current song onto the undo stack
  void undoStackPush() {
    logger.log(_logUndoStack, 'undo push(): ${undoStackAllToString()}');
    // undoStack.push(song.copySong());
  }

  void undoStackLog(String comment) {
    logger.log(_logUndoStack, 'undo $comment: ${undoStackAllToString()}');
  }

  void editLogPre(Song logSong, bool endOfRow) {
    if (_logDebug) {
      //  output to match the TestSong() tests from the library. i.e. bsteeleMusicLib
      logger.t('//  from ${Util.utcNow()}');
      logger.t('ts.startingChords(\'${logSong.toMarkup()}\');');
      logger.t(
        'ts.edit(${logSong.currentMeasureEditType}, \'${logSong.currentChordSectionLocation}\''
        ', \'${logSong.getCurrentMeasureNode()?.toMarkup()}\'' //  measure string
        ', SongBase.entryToUppercase(\'${measureEntryNodes?.toString()}\')'
        ');'
        ' // endOfRow: $endOfRow',
      );
    }
  }

  void editLogPost(Song logSong, bool endOfRow) {
    if (_logDebug) {
      //  output to match the TestSong() tests from the library. i.e. bsteeleMusicLib
      logger.t('ts.resultChords(\'${logSong.toMarkup()}\');');
      logger.t(
        'ts.post(${logSong.currentMeasureEditType},\'${logSong.getCurrentChordSectionLocation()}\''
        ',\'${logSong.getCurrentMeasureNode()?.toMarkup()}\' );'
        ' // endOfRow: $endOfRow',
      );
    }
  }

  String undoStackAllToString() {
    StringBuffer sb = StringBuffer(undoStack);
    sb.writeln('');
    for (var i = undoStack.length - 1; i >= 0; i--) {
      var j = undoStack.length - 1 - i;
      sb.writeln('$i: ${undoStack.get(j)?.key.toMarkup()}');
    }
    return sb.toString();
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
      logger.log(_logEditPoint, 'setEditPoint(${editPoint.toString()})');
    });
  }

  void performMeasureEntryCancel() {
    setState(() {
      clearMeasureEntry();
    });
  }

  void clearMeasureEntry() {
    logger.d('_clearMeasureEntry():');
    editTextField = null;
    selectedEditPoint = null;
    measureEntryIsClear = true;
    measureEntryCorrection = null;
    measureEntryValid = false;
  }

  void checkSongWhenIdle() {
    if (_idleTimer != null) {
      _idleTimer!.cancel();
    }

    _idleTimer = Timer(const Duration(milliseconds: 700), () {
      setState(() {
        // checkSong();
      });
    });
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

  double appendFontSize = 14;
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

  TextStyle chordBoldTextStyle = generateAppTextStyle(fontWeight: .bold);

  // TextStyle sectionChordBoldTextStyle = generateAppTextStyle(fontWeight: .bold);
  TextStyle chordTextStyle = generateAppTextStyle();

  EdgeInsets marginInsets = const EdgeInsets.all(4);
  EdgeInsets doubleMarginInsets = const EdgeInsets.all(8);
  static const EdgeInsets textPadding = EdgeInsets.all(6);
  static const EdgeInsets appendInsets = EdgeInsets.all(3);
  static const EdgeInsets appendPadding = EdgeInsets.all(3);

  TextField? editTextField;

  TextEditingController proChordTextEditingController = TextEditingController();
  FocusNode proChordTextFieldFocusNode = FocusNode();
  TextEditingController proLyricsTextEditingController = TextEditingController();
  int proLyricsLastLineSelected = 0;
  FocusNode proLyricsTextFieldFocusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  final TextEditingController editTextController = TextEditingController();
  FocusNode? editTextFieldFocusNode;
  TextSelection? lastEditTextSelection;

  List<TableRow> chordRows = [];
  List<Widget> chordRowChildren = [];
  int tableKeyId = 0;

  LyricsEntries lyricsEntries = LyricsEntries();

  SectionVersion sectionVersion = SectionVersion.defaultInstance;
  ScaleNote keyChordNote = musical_key.MajorKey.getDefault().getKeyScaleNote();

  final List<ChangeNotifier> disposeList = []; //  fixme: workaround to dispose the text controllers

  final UndoStack<Song> undoStack = UndoStack();

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
