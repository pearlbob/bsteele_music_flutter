import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/songs/chordComponent.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/chordSectionGridData.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:bsteeleMusicLib/songs/measureComment.dart';
import 'package:bsteeleMusicLib/songs/measureNode.dart';
import 'package:bsteeleMusicLib/songs/measureRepeat.dart';
import 'package:bsteeleMusicLib/songs/measureRepeatExtension.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/phrase.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/sectionVersion.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songBase.dart';
import 'package:bsteeleMusicLib/songs/songEditManager.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/songs/timeSignature.dart';
import 'package:bsteeleMusicLib/util/undoStack.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/lyricsEntries.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../app/app.dart';
import 'detail.dart';

late Song _initialSong;

const double _defaultChordFontSize = 22;
const double _defaultFontSize = _defaultChordFontSize * 0.8;

TextStyle _titleTextStyle = generateAppTextStyle();
TextStyle _boldTextStyle = generateAppTextStyle();
TextStyle _textFieldStyle = generateAppTextStyle();
TextStyle _labelTextStyle = generateAppTextStyle();
const double _entryWidth = 22 * _defaultChordFontSize;

const Color _disabledColor = Color(0xFFE0E0E0);
const _addColor = Color(0xFFC8E6C9); //var c = Colors.green[100];

List<DropdownMenuItem<TimeSignature>> _timeSignatureItems = [];

final ChordSectionLocation defaultLocation = // last resort, better than null
    ChordSectionLocation(SectionVersion.bySection(Section.get(SectionEnum.chorus)));

const bool _editDebug = kDebugMode && false;
const bool _editDebugVerbose = kDebugMode && false;

const Level _editLog = Level.debug;
const Level _editEditPoint = Level.debug;
const Level _editLyricEntry = Level.debug;
const Level _editKeyboard = Level.debug;

/*
Song notes:

repeats
  25 or 6 to 4

double repeats

odd repeats
  Dublin Blues

odd sized repeats
  Africa
 */

///   screen to edit a song
///   Note: This screen is scaled differently than the others.
///   It is expected that it will only be used on a desktop only
///   and will not be displayed to the musicians on a large screen display.
class Edit extends StatefulWidget {
  Edit({super.key, required initialSong}) {
    _initialSong = initialSong;
  }

  @override
  EditState createState() => EditState();
}

class EditState extends State<Edit> {
  EditState()
      : song = _initialSong.copySong(),
        originalSong = _initialSong.copySong() {
    isProEditInput = appOptions.proEditInput;

    chordSong = song;

    //  _checkSongStatus();

    undoStackPush();
  }

  @override
  initState() {
    super.initState();

    editTextFieldFocusNode = FocusNode();
    editTextFieldFocusNode?.addListener(() {
      logger.log(_editLog, 'focusNode.listener()');
    });

    key = song.key;
    keyChordNote = key.getKeyScaleNote(); //  initial value

    editTextController.addListener(() {
      //  fixme: workaround for loss of focus when pressing an edit button
      TextSelection textSelection = editTextController.selection;
      if (textSelection.baseOffset >= 0) {
        lastEditTextSelection = textSelection.copyWith();
      }
      logger.d('_chordTextController.addListener(): "${editTextController.text}",'
          ' ${selectedEditPoint?.toString()}'
          ', baseOffset: ${textSelection.baseOffset}'
          ', extentOffset: ${textSelection.extentOffset}');

      preProcessMeasureEntry(editTextController.text);
      if (measureEntryValid) {
        bool endOfRow = false;
        switch (editTextController.text[editTextController.text.length - 1]) {
          case ',':
            endOfRow = true;
            continue entry;
          entry:
          case ' ': //  space means move on to the next measure, horizontally
            performEdit(endOfRow: endOfRow);

            break;
          case '\n':
            logger.log(_editLog, 'newline: should _editMeasure() called here?');
            break;
          //  look for TextField.onEditingComplete() for end of entry... but it happens too often!
        }
      }

      logger.d('chordTextController: "${editTextController.text}"');
    });

    //  known text updates
    titleTextEditingController.addListener(() {
      appTextFieldListener(AppKeyEnum.editTitle, titleTextEditingController);
      song.title = titleTextEditingController.text;
      logger.v('_titleTextEditingController listener: \'${titleTextEditingController.text}\''
          ', ${titleTextEditingController.selection}');
      checkSongChangeStatus();
    });
    artistTextEditingController.addListener(() {
      appTextFieldListener(AppKeyEnum.editArtist, artistTextEditingController);
      song.artist = artistTextEditingController.text;
      checkSongChangeStatus();
    });
    coverArtistTextEditingController.addListener(() {
      appTextFieldListener(AppKeyEnum.editCoverArtist, coverArtistTextEditingController);
      song.coverArtist = coverArtistTextEditingController.text;
      checkSongChangeStatus();
    });
    copyrightTextEditingController.addListener(() {
      appTextFieldListener(AppKeyEnum.editCopyright, copyrightTextEditingController);
      song.copyright = copyrightTextEditingController.text;
      checkSongChangeStatus();
    });
    userTextEditingController.addListener(() {
      appTextFieldListener(AppKeyEnum.editUserName, userTextEditingController);
      song.user = userTextEditingController.text;
      if (userTextEditingController.text.isNotEmpty) {
        appOptions.user = userTextEditingController.text;
      }
      song.user = userTextEditingController.text;
      checkSongChangeStatus();
      // user  will often be different  _checkSongStatus();
    });

    bpmTextEditingController.addListener(() {
      try {
        var bpm = int.parse(bpmTextEditingController.text);
        if (bpm < MusicConstants.minBpm || bpm > MusicConstants.maxBpm) {
          setState(() {
            app.errorMessage('BPM needs to be a number '
                'from ${MusicConstants.minBpm} to ${MusicConstants.maxBpm}, not: \'$bpm\'');
          });
        } else {
          setState(() {
            app.clearMessage();
            appTextFieldListener(AppKeyEnum.editBPM, bpmTextEditingController);
            song.beatsPerMinute = bpm;
            checkSongChangeStatus();
          });
        }
      } catch (e) {
        setState(() {
          app.errorMessage(
              'caught: BPM needs to be a number from ${MusicConstants.minBpm} to ${MusicConstants.maxBpm}');
        });
      }
    });

    //  generate time signature drop down items
    _timeSignatureItems = [];
    for (final timeSignature in knownTimeSignatures) {
      _timeSignatureItems.add(appDropdownMenuItem<TimeSignature>(
        appKeyEnum: AppKeyEnum.editEditTimeSignature,
        value: timeSignature,
        child: Text(timeSignature.toString()),
      ));
    }
  }

  void loadSong(final Song songToLoad) {
    logger.log(_editLyricEntry, 'loadSong: ${songToLoad.toMarkup()}');
    selectedEditPoint = null;
    measureEntryIsClear = true;
    measureEntryCorrection = null;
    measureEntryValid = false;
    measureEntryNodes = null;

    song = songToLoad.copySong();

    proChordTextEditingController.text = songToLoad.toMarkup(asEntry: true);
    proLyricsTextEditingController.text = songToLoad.rawLyrics;
    titleTextEditingController.text = song.title;
    artistTextEditingController.text = song.artist;
    coverArtistTextEditingController.text = song.coverArtist;
    copyrightTextEditingController.text = song.copyright;
    userTextEditingController.text = appOptions.user;
    bpmTextEditingController.text = song.beatsPerMinute.toString();

    lyricsEntries.removeListener(lyricsEntriesListener);
    lyricsEntries = lyricsEntriesFromSong(song);

    checkSongChangeStatus();
  }

  void saveSong() async {
    checkSong(); //  collect tiny pro input lyric changes
    app.addSong(song);
    app.selectedSong = song;

    String fileName = '${song.title}.songlyrics'; //  fixme: cover artist?
    String contents = song.toJsonAsFile();
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    setState(() {
      if (message.toLowerCase().contains('error')) {
        app.errorMessage(message);
      } else {
        app.infoMessage = message;
      }
    });

    // a navigation pop is expected, leave the app error message for the next screen.   checkSongChangeStatus();
  }

  /// return true if the song is original or the user has acknowledged that their edits will be lost.
  bool canPop() {
    checkSong();
    if (!songHasChanged) {
      return true;
    }

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(
                'Do you really want discard your changes?',
                style: chordBoldTextStyle,
              ),
              actions: [
                appButton('Discard all my changes!', appKeyEnum: AppKeyEnum.editDiscardAllChanges, onPressed: () {
                  app.clearMessage();
                  Navigator.of(context).pop(); //  the dialog
                  Navigator.of(context).pop(); //  the screen
                }),
                const AppSpace(space: 100),
                appButton('Cancel the return... I need to work some more on this.',
                    appKeyEnum: AppKeyEnum.listsCancelDeleteList, onPressed: () {
                  Navigator.of(context).pop();
                  checkSong();
                }),
              ],
              elevation: 24.0,
            ));
    return false;
  }

  /// return true if the song removal was confirmed
  bool removePopup() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(
                'Do you really want remove "${song.title}" by ${song.artist}'
                '${song.coverArtist.isEmpty ? '' : ', cover by ${song.coverArtist}'}?',
                style: chordBoldTextStyle,
              ),
              actions: [
                appButton('Remove the song.', appKeyEnum: AppKeyEnum.editDiscardAllChanges, onPressed: () {
                  app.allSongs.remove(song);
                  app.clearMessage();
                  Navigator.of(context).pop(); //  the dialog
                  Navigator.of(context).pop(); //  the screen
                }),
                const AppSpace(space: 100),
                appButton('Cancel the removal... I need to work some more on this.',
                    appKeyEnum: AppKeyEnum.listsCancelDeleteList, onPressed: () {
                  Navigator.of(context).pop();
                  checkSong();
                }),
              ],
              elevation: 24.0,
            ));
    return false;
  }

  /// return true if the song removal was confirmed
  bool renamePopup() {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(
                'Do you really want rename "${originalSong.title}" by ${originalSong.artist}'
                '${originalSong.coverArtist.isEmpty ? '' : ', cover by ${originalSong.coverArtist}'}'
                '\nto "${song.title}" by ${song.artist}'
                '${song.coverArtist.isEmpty ? '' : ', cover by ${song.coverArtist}'}?',
                style: chordBoldTextStyle,
              ),
              actions: [
                appButton('Rename the song.', appKeyEnum: AppKeyEnum.editDiscardAllChanges, onPressed: () {
                  app.allSongs.remove(originalSong);
                  app.allSongs.add(song);
                  app.selectedSong = song;
                  app.clearMessage();
                  Navigator.of(context).pop(); //  the dialog
                  Navigator.of(context).pop(); //  the screen
                }),
                const AppSpace(space: 100),
                appButton('Cancel the rename... I need to work some more on this.',
                    appKeyEnum: AppKeyEnum.listsCancelDeleteList, onPressed: () {
                  Navigator.of(context).pop();
                  checkSong();
                }),
              ],
              elevation: 24.0,
            ));
    return false;
  }

  bool get songHasChanged =>
      hasChangedFromOriginal ||
      (isProEditInput ? song.rawLyrics != proLyricsTextEditingController.text : lyricsEntries.hasChangedLines());

  @override
  void dispose() {
    editTextController.dispose();
    editTextFieldFocusNode?.dispose();
    titleTextEditingController.dispose();
    artistTextEditingController.dispose();
    coverArtistTextEditingController.dispose();
    copyrightTextEditingController.dispose();
    bpmTextEditingController.dispose();
    userTextEditingController.dispose();
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

    logger.d('edit build: "${song.toMarkup()}"');
    logger.d('edit build: "${song.rawLyrics}"');
    logger.d('edit build: ');

    //  adjust to screen size
    if (screenInfo == null) {
      screenInfo = ScreenInfo(context);
      final double screenWidth = screenInfo!.mediaWidth;

      chordFontSize = _defaultChordFontSize * screenWidth / 800;
      chordFontSize = min(_defaultChordFontSize, max(12, chordFontSize));
      appendFontSize = chordFontSize * 0.75;

      chordBoldTextStyle = generateAppTextStyle(
        fontWeight: FontWeight.bold,
        fontSize: chordFontSize,
      );
      chordTextStyle = generateAppTextStyle(
        fontSize: appendFontSize,
        color: Colors.black87,
      );
      lyricsTextStyle = generateAppTextStyle(
        fontWeight: FontWeight.normal,
        fontSize: chordFontSize,
        color: Colors.black87,
      );
      addRowRepeatTextStyle = generateAppTextStyle(
        fontSize: chordFontSize,
        backgroundColor: _addColor,
      );

      //  don't load the song until we know its font sizes
      loadSong(song);
    }

    //  generate edit text styles
    _titleTextStyle = generateAppTextStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold);
    _boldTextStyle = generateAppTextStyle(
      fontSize: _defaultFontSize,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );
    _textFieldStyle = generateAppTextFieldStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold);
    _labelTextStyle = generateAppTextStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold);

    //  build the chords display based on the song chord section grid
    tableKeyId = 0;

    //  convert a selected edit point of arbitrary edit mode to a replacement
    //  this simplifies the tricky corner conditions on the display formatting in the grid.
    //  the edit is pre-edited on a copy and displayed as if it had already been edited.
    Table displayChordTable;
    if (selectedEditPoint != null) {
      logger.log(
          _editEditPoint,
          'pre  manager: selectedEditPoint: $selectedEditPoint'
          ', chordSong: ${chordSong.toMarkup()}');
      songEditManager = SongEditManager(chordSong);
      chordSong = songEditManager.preEdit(selectedEditPoint!);
      selectedEditPoint = songEditManager.editPoint;
      logger.log(
          _editEditPoint,
          'post manager: selectedEditPoint: $selectedEditPoint'
          ', chordSong: ${chordSong.toMarkup()}');
      hadSelectedEditPoint = true;
    } else if (hadSelectedEditPoint || !identical(song, chordSong)) {
      //  update the lyrics
      hadSelectedEditPoint = false;
      chordSong = song; //  not editing
      lyricsEntries.removeListener(lyricsEntriesListener);
      lyricsEntries = lyricsEntriesFromSong(song);
    }
    logger.log(
        _editEditPoint,
        'display: selectedEditPoint: $selectedEditPoint'
        ', displayMeasureEntryNode: \'${displayMeasureEntryNode?.toMarkup()}\''
        ', lyrics: ${lyricsEntries.hasChangedLines()}'
        ', ${chordSong.toMarkup()}');

    displayChordTable = isProEditInput ? Table() : chordsEntryWidget();

    var theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.appBar(
        appKeyEnum: AppKeyEnum.appBarBack,
        title: 'Edit: ${song.title}',
        leading: appWidgetHelper.back(
            canPop: canPop,
            onPressed: () {
              app.clearMessage();
            }),
      ),
      body:
          //  deal with keyboard strokes flutter is not usually handling
          //  note that return (i.e. enter) is not a keyboard event!
          RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: editOnKey,
        child: GestureDetector(
          // fixme: put GestureDetector only on chord table
          child: SingleChildScrollView(
              controller: ScrollController(),
              padding: const EdgeInsets.all(8.0),
              child: Column(children: [
                const AppVerticalSpace(space: 10),
                AppWrapFullWidth(alignment: WrapAlignment.spaceAround, spacing: 10, children: <Widget>[
                  appEnumeratedButton(
                    songHasChanged
                        ? (isValidSong ? 'Save song on local drive' : 'Fix the song')
                        : 'Nothing has changed',
                    appKeyEnum: AppKeyEnum.editEnterSong,
                    fontSize: _defaultChordFontSize,
                    onPressed: () {
                      saveSong();
                      if (songHasChanged && isValidSong) {
                        Navigator.pop(context);
                      }
                    },
                    backgroundColor: (songHasChanged && isValidSong ? null : _disabledColor),
                  ),
                  app.messageTextWidget(AppKeyEnum.editErrorMessage),
                  AppWrap(alignment: WrapAlignment.spaceBetween, spacing: 25, children: <Widget>[
                    editTooltip(
                      message: undoStack.canUndo ? 'Undo the last edit' : 'There is nothing to undo',
                      child: appEnumeratedButton('Undo',
                          appKeyEnum: AppKeyEnum.editUndo, fontSize: _defaultChordFontSize, onPressed: () {
                        undo();
                      }),
                    ),
                    editTooltip(
                      message: undoStack.canUndo ? 'Redo the last edit undone' : 'There is no edit to redo',
                      child: appEnumeratedButton(
                        'Redo',
                        appKeyEnum: AppKeyEnum.editRedo,
                        fontSize: _defaultChordFontSize,
                        onPressed: () {
                          redo();
                        },
                      ),
                    ),
                    appButton(
                      'Sheet music',
                      appKeyEnum: AppKeyEnum.editScreenDetail,
                      fontSize: _defaultChordFontSize,
                      onPressed: () {
                        setState(() {
                          _navigateToDetail(context);
                        });
                      },
                    ),
                    editTooltip(
                      message: 'Clear all song values to\n'
                          'start entering a new song.',
                      child: appEnumeratedButton(
                        'Clear',
                        appKeyEnum: AppKeyEnum.editClearSong,
                        fontSize: _defaultChordFontSize,
                        onPressed: () {
                          setState(() {
                            song = Song.createSong(
                                '', '', '', music_key.Key.getDefault(), 106, 4, 4, userName, 'V: X', 'V: ');
                            loadSong(song);
                            undoStackPushIfDifferent();
                          });
                        },
                      ),
                    ),
                    if (song.songId == originalSong.songId)
                      editTooltip(
                        message: 'Remove this song from the list of songs.',
                        child: appEnumeratedButton(
                          'Remove',
                          appKeyEnum: AppKeyEnum.editRemoveSong,
                          fontSize: _defaultChordFontSize,
                          onPressed: () {
                            removePopup();
                          },
                        ),
                      ),
                    if (song.songId != originalSong.songId)
                      editTooltip(
                        message: 'Rename this song.'
                            '${kDebugMode ? '\n${song.songId} vs ${originalSong.songId}' : ''}',
                        child: appEnumeratedButton(
                          'Rename the song',
                          appKeyEnum: AppKeyEnum.editRenameSong,
                          fontSize: _defaultChordFontSize,
                          onPressed: () {
                            renamePopup();
                          },
                        ),
                      ),
                    // appIconButton(
                    //        icon: Icon(
                    //          Icons.arrow_left,
                    //          size: 48,
                    //        ),
                    //        label: const Text(
                    //          '',
                    //          style: _boldTextStyle,
                    //        ),
                    //        onPressed: () {
                    //          _errorMessage('bob: fixme: arrow_left');
                    //        },
                    //      ),
                    // appIconButton(
                    //        icon: Icon(
                    //          Icons.arrow_right,
                    //          size: 48,
                    //        ),
                    //        label: Text(
                    //          '',
                    //          style: _buttonTextStyle,
                    //        ),
                    //        onPressed: () {
                    //          _errorMessage('bob: fixme: arrow_right');
                    //        },
                    //      ),
                  ]),
                ]),
                //  attributes
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                        child: Text(
                          'Title: ',
                          style: generateAppTextStyle(
                            fontSize: _defaultChordFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: AppTextField(
                          appKeyEnum: AppKeyEnum.editTitle,
                          controller: titleTextEditingController,
                          hintText: 'Enter the song title.',
                          fontSize: _defaultChordFontSize,
                          onChanged: (value) {
                            logger.i('fixme: AppKeyEnum.editTitle.onChanged');
                          }, //  fixme: ignored
                        ),
                      ),
                    ]),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                        child: Text(
                          'Artist: ',
                          style: _titleTextStyle,
                        ),
                      ),
                      Expanded(
                        child: AppTextField(
                          appKeyEnum: AppKeyEnum.editArtist,
                          controller: artistTextEditingController,
                          hintText: 'Enter the song\'s artist.',
                          fontSize: _defaultChordFontSize,
                          onChanged: (value) {
                            logger.i('fixme: AppKeyEnum.editArtist.onChanged');
                          }, //  fixme: ignored
                        ),
                      ),
                    ]),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                        child: Text(
                          'Cover Artist:',
                          style: _textFieldStyle,
                        ),
                      ),
                      Expanded(
                        child: AppTextField(
                          appKeyEnum: AppKeyEnum.editCoverArtist,
                          controller: coverArtistTextEditingController,
                          hintText: 'Enter the song\'s cover artist.',
                          fontSize: _defaultChordFontSize,
                          onChanged: (value) {}, //  fixme: ignored
                        ),
                      ),
                    ]),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(right: 24, bottom: 24.0),
                        child: Text(
                          'Copyright:',
                          style: _textFieldStyle,
                        ),
                      ),
                      Expanded(
                        child: AppTextField(
                          appKeyEnum: AppKeyEnum.editCopyright,
                          controller: copyrightTextEditingController,
                          hintText: 'Enter the song\'s copyright. Required.',
                          fontSize: _defaultChordFontSize,
                          onChanged: (value) {}, //  fixme: ignored
                        ),
                      ),
                    ]),
                const AppSpace(),
                AppWrapFullWidth(
                  crossAxisAlignment: WrapCrossAlignment.start,
                  spacing: 40,
                  children: <Widget>[
                    AppWrap(children: [
                      Text(
                        "Key: ",
                        style: _labelTextStyle,
                      ),
                      appDropdownButton<music_key.Key>(
                        AppKeyEnum.editEditKeyDropdown,
                        music_key.Key.values.toList().reversed.map((music_key.Key value) {
                          logger.v('keySelectDropdownMenuItems: music_key.Key value: $value');
                          return appDropdownMenuItem<music_key.Key>(
                            appKeyEnum: AppKeyEnum.editMusicKey,
                            value: value,
                            child: Text(
                              '${value.toMarkup().padRight(3)} ${value.sharpsFlatsToMarkup()}',
                              style: _boldTextStyle,
                            ),
                          );
                        }).toList(growable: false),
                        onChanged: (value) {
                          logger.log(_editLog, 'editEditKeyDropdown onChanged: $value');
                          if (song.key != value && value != null) {
                            setState(() {
                              song.key = value;
                              key = value;
                              keyChordNote = key.getKeyScaleNote();
                            });
                          }
                        },
                        value: key,
                        style: _labelTextStyle,
                      ),
                      SizedBox.shrink(
                        child: Text('keyTally_${key.toMarkup()}'),
                      ),
                    ]),
                    AppWrap(children: [
                      AppTooltip(
                        message: 'Enter the song\'s tempo in beats per minute.',
                        child: Text(
                          "   Tempo: ",
                          style: _labelTextStyle,
                        ),
                      ),
                      SizedBox(
                        width: 3 * _defaultChordFontSize,
                        child: AppTextField(
                          appKeyEnum: AppKeyEnum.editBPM,
                          controller: bpmTextEditingController,
                          hintText: 'Enter the song\'s tempo in beats per minute.',
                          fontSize: _defaultChordFontSize,
                          onChanged: (value) {}, //  fixme: ignored
                        ),
                      ),
                    ]),
                    AppWrap(children: [
                      Text(
                        "Time Signature: ",
                        style: _labelTextStyle,
                      ),
                      appDropdownButton<TimeSignature>(
                        AppKeyEnum.editEditTimeSignatureDropdown,
                        _timeSignatureItems,
                        onChanged: (value) {
                          if (value != null && song.timeSignature != value) {
                            song.timeSignature = value;
                            if (!checkSongChangeStatus()) {
                              setState(() {}); //  display the return to original
                            }
                          }
                        },
                        value: song.timeSignature,
                        style: _labelTextStyle,
                      ),
                    ]),
                    AppWrap(children: [
                      Text(
                        "User: ",
                        style: _labelTextStyle,
                      ),
                      SizedBox(
                        width: 300.0,
                        child: AppTextField(
                          appKeyEnum: AppKeyEnum.editUserName,
                          controller: userTextEditingController,
                          hintText: 'Enter your user name.',
                          fontSize: _defaultChordFontSize,
                          onChanged: (value) {}, //  fixme: ignored
                        ),
                      ),
                      const AppSpace(),
                      if (originalSong.user != userTextEditingController.text)
                        Text(
                          '(was ${originalSong.user})',
                          style: _labelTextStyle,
                        ),
                    ]),
                  ],
                ),
                const AppSpace(space: 30),
                //  chords
                AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: <Widget>[
                  Text(
                    "Chords:",
                    style: _titleTextStyle,
                  ),
                  AppWrap(spacing: 50, children: [
                    if (isProEditInput)
                      editTooltip(
                        message: 'Validate the chord input',
                        child: appEnumeratedButton('Validate',
                            appKeyEnum: AppKeyEnum.editValidateChords, fontSize: _defaultChordFontSize, onPressed: () {
                          setState(() {
                            validateSongChords(select: true);
                          });
                        }),
                      ),
                    editTooltip(
                      message: (selectedEditPoint != null ? 'Click outside the chords to cancel editing\n' : '') +
                          (showHints ? 'Click to hide the editing hints' : 'Click for hints about editing.'),
                      child: appEnumeratedButton('Hints',
                          appKeyEnum: AppKeyEnum.editHints, fontSize: _defaultChordFontSize, onPressed: () {
                        setState(() {
                          showHints = !showHints;
                        });
                      }),
                    ),
                    editTooltip(
                      message: proMessage,
                      child: appEnumeratedButton(
                        isProEditInput ? 'Assisted Input' : 'Pro Input',
                        appKeyEnum: AppKeyEnum.editRedo,
                        fontSize: _defaultChordFontSize,
                        onPressed: () {
                          setState(() {
                            if (isProEditInput) {
                              checkSong();
                              if (!isValidSongChordsAndLyrics) {
                                app.errorMessage('Cannot change edit input mode without valid chords and lyrics.');
                                return; //  don't change on invalid input
                              }
                            } else {
                              //  is currently assisted entry
                              proChordTextEditingController.text = song.toMarkup(asEntry: true);
                              proLyricsTextEditingController.text = lyricsEntries.asRawLyrics();
                              selectedEditPoint = null; //  for reentry to assisted
                            }
                            isProEditInput = !isProEditInput;
                            appOptions.proEditInput = isProEditInput;
                          });
                        },
                      ),
                    ),
                  ]),
                ]),
                const Divider(
                  thickness: 8,
                  //color: ,  fixme: should be from css!!!
                ),
                if (!isProEditInput)
                  Container(
                    alignment: Alignment.topLeft,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    color: theme.backgroundColor,
                    child: //  pre-configured table of edit widgets
                        displayChordTable,
                  ),

                if (isProEditInput)
                  Container(
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.all(16.0),
                      color: theme.backgroundColor,
                      child: AppTextField(
                          appKeyEnum: AppKeyEnum.editProChords,
                          controller: proChordTextEditingController,
                          focusNode: proChordTextFieldFocusNode,
                          minLines: 8,
                          maxLines: 100,
                          fontSize: _defaultChordFontSize,
                          fontWeight: FontWeight.normal,
                          width: MediaQuery.of(context).size.width * 0.96,
                          border: InputBorder.none,
                          onChanged: (value) {
                            checkSongWhenIdle();
                          })),
                if (showHints)
                  RichText(
                    text: TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '\n'
                              'Section types are followed by a colon (:).'
                              ' Sections can be entered abbreviated and in lower case.'
                              ' The available section buttons will enter the correct abbreviation.'
                              ' Section types can be followed with a digit to indicate a variation.\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: '\n\nThe sections are: ${listSections()}',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: '\n'
                              'Their abbreviations are: ',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: listSectionAbbreviations(),
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: '.\n\n'
                              'Sections with the same content will automatically be placed in the same declaration.'
                              ' Row commas are not significant in the difference i.e. commas don\'t create a difference.'
                              ' Chords ultimately must be in upper case. If they are not on entry, the app will try to guess'
                              ' the capitalization for your input and place it on the line below the test entry box.'
                              ' What you see in the text below the entry box will be what will be entered into the edit.'
                              ' Note that often as you type, parts of a partial chord entry will be considered a comment,'
                              ' i.e. will be placed in parenthesis in the text below.'
                              ' When the chord entry is correct, the characters will be removed from the comment and will be'
                              ' returned to their correct position in the entry.'
                              '\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: '''A capital X is used to indicate no chord.\n\n''',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: '''Using a lower case b for a flat will work. A sharp sign (#) works as a sharp.\n\n''',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text:
                              'Notice that this can get problematic around the lower case b. Should the entry "bbm7"'
                              ' be a B♭m7 or the chord B followed by a Bm7?'
                              ' The app will assume a B♭m7 but you can force a BBm7 by entering either "BBm7" or "bBm7".\n\n'
                              '',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Limited set of case sensitive chord modifiers can be used: 7sus4,'
                              ' 7sus2, 7sus, 13, 11, mmaj7, m7b5, msus2,  msus4,'
                              ' add9, jazz7b9, 7#5, flat5, 7b5, 7#9, 7b9, 9, 69,'
                              ' 6, dim7, º7, ◦, dim, aug5, aug7, aug, sus7, sus4,'
                              ' sus2, sus, m9, m11, m13, m6, Maj7, maj7, maj9, maj,'
                              ' Δ, M9, M7, 2, 4, 5, m7, 7, m, M and more.'
                              ' And of course the major chord is assumed if there is no modifier!'
                              ' See the "Other chords" selection above or the "Show all chords" section of the Options tab.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text:
                              '''Spaces between chords indicate a new measure. Chords without spaces are within one measure.\n\n''',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Forward slashes (/) can be used to indicate bass notes that differ from the chord.'
                              ' For example A/G would mean a G for the bass, an A chord for the other instruments.'
                              ' The bass note is a single note, not a chord.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Periods (.) can be used to repeat chords on another beat within the same measure. For'
                              ' example, G..A would be three beats of G followed by one beat of A in the same measure.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: '''Sample measures to use:
      A B C G
      A# C# Bb Db
      C7 D7 Dbm Dm Em Dm7 F#m7 A#maj7 Gsus9
      DC D#Bb G#m7Gm7 Am/G G..A\n\n''',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Commas (,) between measures can be used to indicate the end of a row of measures.'
                              ' The maximum number of measures allowed within a single row is 8.'
                              ' If there are no commas within a phrase of 8 or more measures, the phrase will'
                              ' automatically be split into rows of 4 measures.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Minus signs (-) can be used to indicate a repeated measure.'
                              ' There must be a space before and after it.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Row repeats are indicated by a lower case x followed by a number 2 or more.'
                              ' Multiple rows can be repeated by placing an opening square bracket ([) in front of the'
                              ' first measure of the first row and a closing square bracket (]) after the last'
                              ' measure before the x and the digits.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Comments are not allowed in the chord section.'
                              ' Chord input not understood will be placed in parenthesis, eg. "(this is not a chord sequence)".\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Since you can enter the return key to create a new row for your entry,'
                              ' you must us the exit to stop editing.  Clicking outside the entry'
                              ' box or typing escape will work as well.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'The red bar or measure highlight indicate where entry text will be entered.'
                              ' The radio buttons control the fine position of this indicator for inserting, replacing,'
                              ' or appending. To delete a measure, select it and click Replace. This activates the Delete button'
                              ' to delete it. Note that the delete key will always apply to text entry.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Double click a measure to select it for replacement or deletion.'
                              ' Note that if you double click the section type, the entire section will be'
                              ' available on the entry line for modification.'
                              ' If two sections have identical content, they will appear as multiple types for the'
                              ' single content. Define a different section content for one of the multiple sections'
                              ' and it will be separated from the others.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'Control plus the arrow keys can help navigate in the chord entry once selected.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'In the lyrics section, anything else not recognized as a section identifier is'
                              ' considered lyrics to the end of the line.'
                              ' I suggest comments go into parenthesis.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text:
                              'The buttons to the right of the displayed chords are active and there to minimize your typing.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text: 'A trick: Select a section similar to a new section you are about to enter.'
                              ' Copy the text from the entry area. Delete the entry line. Enter the new section identifier'
                              ' (I suggest the section buttons on the right).'
                              ' Paste the old text after the new section. Make edit adjustments in the entry text'
                              ' and press the keyboard enter button.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text:
                              'Another trick: Write the chord section as you like in a text editor, copy the whole song\'s'
                              ' chords and paste into the entry line... complete with newlines. All should be well.\n\n',
                          style: appTextStyle,
                        ),
                        TextSpan(
                          text:
                              'Don\'t forget the undo/redo keys! Undo will even go backwards into the previously edited song.\n\n',
                          style: appTextStyle,
                        ),
                      ],
                    ),
                  ),
                // lyrics
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Lyrics:',
                      style: _titleTextStyle,
                    ),
                    if (!isProEditInput)
                      editTooltip(
                        message: 'Import lyrics from a text file',
                        child: appEnumeratedButton(
                          'Import',
                          appKeyEnum: AppKeyEnum.editImportLyrics,
                          fontSize: _defaultChordFontSize,
                          onPressed: () {
                            import();
                          },
                        ),
                      ),
                  ],
                ),
                const Divider(
                  thickness: 8,
                ),
                if (!isProEditInput)
                  Container(
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.all(16.0),
                      color: theme.backgroundColor,
                      child: lyricsEntryWidget()),
                if (isProEditInput)
                  Container(
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.all(16.0),
                    color: theme.backgroundColor,
                    width: MediaQuery.of(context).size.width,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          proChordsForLyrics(),
                          style: TextStyle(
                            fontSize: _defaultChordFontSize,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey.shade400,
                          ),
                          overflow: TextOverflow.fade,
                          softWrap: false,
                        ),
                        const AppSpace(),
                        AppTextField(
                          appKeyEnum: AppKeyEnum.editProLyrics,
                          controller: proLyricsTextEditingController,
                          focusNode: proLyricsTextFieldFocusNode,
                          minLines: 8,
                          maxLines: 300,
                          width: MediaQuery.of(context).size.width * 0.6,
                          //  fixme: quite arbitrary workaround!
                          fontSize: _defaultChordFontSize,
                          fontWeight: FontWeight.normal,
                          border: InputBorder.none,
                          onChanged: (value) {
                            checkSongWhenIdle();
                          },
                        ),
                      ],
                    ),
                  ),
              ])),
          onTap: () {
            logger.i('GestureDetector.onTap():');
            performMeasureEntryCancel();
          },
        ),
      ),
      floatingActionButton: !songHasChanged
          ? appFloatingActionButton(
              appKeyEnum: AppKeyEnum.editBack,
              onPressed: () {
                Navigator.pop(context);
              },
              child: editTooltip(
                message: 'Back to the song',
                child: appIcon(
                  Icons.arrow_back,
                ),
              ),
              mini: !app.isScreenBig,
            )
          : NullWidget(), //  hide and disable the choice
    );
  }

  bool validateSongChords({select = false}) {
    if (isProEditInput) {
      var markedString =
          SongBase.validateChords(SongBase.entryToUppercase(proChordTextEditingController.text), song.getBeatsPerBar());

      if (markedString != null) {
        var error = markedString.remainingStringLimited(markedString.getNextWhiteSpaceIndex() - markedString.getMark());
        app.errorMessage('Chord entry invalid: "$error"');
        if (select) {
          proChordTextEditingController.selection =
              TextSelection(baseOffset: markedString.getMark(), extentOffset: markedString.getNextWhiteSpaceIndex());
          proChordTextFieldFocusNode.requestFocus();
          logger.i('pro error set: ('
              '${proChordTextEditingController.selection.baseOffset}'
              ',${proChordTextEditingController.selection.extentOffset})');
        }
        return false;
      }

      //  things look good, so format the song
      if (select) {
        song.setChords(SongBase.entryToUppercase(proChordTextEditingController.text));
        checkSong();
        proChordTextEditingController.text = song.toMarkup(asEntry: true);
      }
    }
    return true;
  }

  bool validateSongLyrics() {
    if (isProEditInput) {
      var lyricParseException = song.validateLyrics(proLyricsTextEditingController.text);
      if (lyricParseException != null) {
        app.errorMessage(
            '${lyricParseException.message} at "${lyricParseException.markedString.remainingStringLimited(15)}"');
        return false;
      }
    }
    return true;
  }

  void addChordRowNullChildrenUpTo(int columns) {
    //  add children to max columns to keep the table class happy
    while (chordRowChildren.length < columns) {
      chordRowChildren.add(NullWidget());
    }
  }

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

  void addChordRowSectionAppend(int maxCols, EditPoint editPoint) {
    if (chordRowChildren.isNotEmpty) {
      addChordRowChildrenAndComplete(maxCols);
    }

    //  prep new row
    addChordRowNullChildrenUpTo(1); //  skip entry column
    addChordRowChild(
      _debugWidget(
          plusMeasureEditGridDisplayWidget(editPoint,
              tooltip: 'append another row'
                  '${kDebugMode ? ' $editPoint' : ''}'),
          editPoint),
    );

    addChordRowChildrenAndComplete(maxCols);
  }

  void addChordRowChild(Widget w) {
    //assert( chordRowChildren.length < maxCols);// fixme:
    chordRowChildren.add(
        //  add padding
        Container(
      padding: const EdgeInsets.all(4),
      child: w,
    ));
  }

  void addChordRowNullWidget() {
    chordRowChildren.add(NullWidget());
  }

  Table chordsEntryWidget() {
    //  build the table from the song chord section grid
    Grid<ChordSectionGridData> chordGrid = chordSong.getChordSectionGrid();

    chordRows = [];

    //  find the max row column count
    int maxRowLength = 0;
    for (var r = 0; r < chordGrid.getRowCount(); r++) {
      maxRowLength = max(maxRowLength, chordGrid.rowLength(r));
    }
    int maxEntryColumns = maxRowLength //  the locations
            +
            maxRowLength //  the plus operators
            +
            2 //  row extensions
        ;

    //  entry for each row
    ChordSectionLocation? lastChordSectionLocation;
    ChordSectionLocation? lastMeasureLocation;
    for (var r = 0; r < chordGrid.getRowCount(); r++) {
      var row = chordGrid.getRow(r);
      if (row == null) {
        continue;
      }

      chordRowChildren = [];
      for (var c = 0; c < row.length; c++) {
        var gridData = row[c];

        if (gridData == null) {
          if (c == 0) {
            //  entry column
            addChordRowNullWidget();

            //  plus column
            //  find the next measure on the row in insert in front of it
            ChordSectionLocation? next;
            if (row.length > 1) {
              next = row[c + 1]?.chordSectionLocation ?? lastMeasureLocation;
            }
            var editPoint = EditPoint(next ?? lastMeasureLocation, measureEditType: MeasureEditType.insert);
            addChordRowChild(_debugWidget(
                plusMeasureEditGridDisplayWidget(editPoint,
                    tooltip: 'insert measure at the start of the row'
                        '${kDebugMode ? ' $editPoint' : ''}'),
                editPoint));
          } else if (chordRowChildren.length < maxEntryColumns - 2) {
            //  fill in a blank grid row if required
            //  entry column
            addChordRowNullWidget();
            //  plus column
            addChordRowNullWidget();
          }
          lastMeasureLocation = null;
          continue;
        }

        var location = gridData.chordSectionLocation;
        // var sectionVersion = location.sectionVersion;
        var measureNode = chordSong.findMeasureNodeByLocation(location);
        if (measureNode == null) {
          assert(false);
          continue;
        }

        ChordSection chordSection = gridData.chordSection;

        //  clean up on a section change
        if (lastChordSectionLocation != null &&
            chordSection.sectionVersion != lastChordSectionLocation.sectionVersion &&
            chordSection.isNotEmpty) {
          addChordRowSectionAppend(
              maxEntryColumns,
              EditPoint(lastChordSectionLocation.asPhraseLocation(),
                  measureEditType: MeasureEditType.append, onEndOfRow: true));
        }
        lastChordSectionLocation = location;

        Phrase? phrase = chordSection.findPhrase(measureNode);
        bool isLastOfPhrase = (((phrase?.length ?? -1) - 1) == gridData.chordSectionLocation.measureIndex);
        lastMeasureLocation = location.isMeasure ? location : lastMeasureLocation;
        Measure? measure = measureNode is Measure ? measureNode : null;
        bool endOfRow = (measure?.endOfRow ?? false) || isLastOfPhrase;

        switch (measureNode.measureNodeType) {
          case MeasureNodeType.section:
            {
              //  insist that the section be in the first column
              assert(c == 0);

              //  section entry column
              {
                var editPoint = EditPoint(location, onEndOfRow: endOfRow);
                addChordRowChild(
                  _debugWidget(sectionEditGridDisplayWidget(editPoint), editPoint),
                );
              }

              //  plus column
              if (chordSection.isEmpty) {
                var editPoint = EditPoint(location, measureEditType: MeasureEditType.append);
                addChordRowChild(
                  _debugWidget(
                      plusMeasureEditGridDisplayWidget(editPoint,
                          tooltip: 'append first measure'
                              '${kDebugMode ? ' $editPoint' : ''}'),
                      editPoint),
                );
              } else if (chordSection.phrases.first.isRepeat()) {
                //  special care to insert a new row when the section starts with a repeat
                var editPoint = EditPoint(ChordSectionLocation(location.sectionVersion, phraseIndex: 0),
                    measureEditType: MeasureEditType.insert);
                addChordRowChild(
                  _debugWidget(
                      plusMeasureEditGridDisplayWidget(editPoint,
                          tooltip: 'add a measure in front of the repeat'
                              '${kDebugMode ? ' $editPoint' : ''}'),
                      editPoint),
                );

                addChordRowChildrenAndComplete(maxEntryColumns);

                //  subsequent row: insert at the beginning of the repeat
                addChordRowNullChildrenUpTo(1);
                {
                  var editPoint = EditPoint(
                      ChordSectionLocation(location.sectionVersion, phraseIndex: 0, measureIndex: 0),
                      measureEditType: MeasureEditType.insert);
                  addChordRowChild(
                    _debugWidget(
                        plusMeasureEditGridDisplayWidget(editPoint,
                            tooltip: 'plus section tooltip'
                                '${kDebugMode ? ' $editPoint' : ''}'),
                        editPoint),
                  );
                }
              } else {
                //  note that the append after a section is the same as an insert before the first
                //  note that the section is known to be non-empty
                assert(chordSection.isNotEmpty);
                var editPoint = EditPoint(ChordSectionLocation(location.sectionVersion, phraseIndex: 0),
                    measureEditType: MeasureEditType.insert);
                addChordRowChild(
                  _debugWidget(
                      plusMeasureEditGridDisplayWidget(editPoint,
                          tooltip: 'insert measure'
                              '${kDebugMode ? ' $editPoint' : ''}'),
                      editPoint),
                );
              }
            }
            break;
          case MeasureNodeType.repeat:
            {
              //  entry column
              var editPoint = EditPoint(location);
              //  warning: bumping into next column knowing this is the end of the row
              addChordRowChildAtRowEnd(
                maxEntryColumns,
                _debugWidget(repeatEditGridDisplayWidget(editPoint), editPoint),
              );
              //  plus column already used
            }
            break;
          // case MeasureNodeType.phrase:
          //   {
          //     //  entry column
          //     var editPoint = EditPoint(location);
          //     addChordRowChild(
          //       _debugWidget(repeatEditGridDisplayWidget(editPoint), editPoint),
          //     );
          //     //  plus column
          //         {
          //       var editPoint =
          //       EditPoint(location, measureEditType: MeasureEditType.append, onEndOfRow: endOfRow);
          //       addChordRowChild(_debugWidget(
          //           plusMeasureEditGridDisplayWidget(editPoint,
          //               tooltip: 'add a new measure here'
          //                   '${kDebugMode ? ' $editPoint' : ''}'),
          //           editPoint));
          //     }
          //   }
          //   break;
          case MeasureNodeType.decoration:
            {
              //  entry column
              var editPoint = EditPoint(location);
              addChordRowChild(
                _debugWidget(markerEditGridDisplayWidget(editPoint), editPoint),
              );
              //  plus column
              addChordRowNullWidget();
            }
            break;

          case MeasureNodeType.measure:
            {
              {
                //  entry column
                var editPoint = EditPoint(location, onEndOfRow: endOfRow);
                addChordRowChild(
                  _debugWidget(measureEditGridDisplayWidget(editPoint), editPoint),
                );
              }

              //  plus column
              {
                var editPoint = EditPoint(location, measureEditType: MeasureEditType.append, onEndOfRow: false);
                List<Widget> widgets = [
                  plusMeasureEditGridDisplayWidget(editPoint,
                      tooltip: 'add a new measure here'
                          '${kDebugMode ? ' $editPoint' : ''}')
                ];
                if (endOfRow && selectedEditPoint == null) {
                  widgets.add(plusNewRowWidget(location));

                  if (chordSong.findMeasureNodeByLocation(location.asPhraseLocation())?.measureNodeType ==
                      MeasureNodeType.phrase) {}
                }
                addChordRowChild(_debugWidget(
                    AppWrap(
                      children: widgets,
                    ),
                    editPoint));
                if (endOfRow &&
                    selectedEditPoint == null &&
                    chordSong.findMeasureNodeByLocation(location.asPhraseLocation())?.measureNodeType ==
                        MeasureNodeType.phrase) {
                  //  warning: bumping into next column knowing this is the end of the row
                  addChordRowChildAtRowEnd(maxEntryColumns, _debugWidget(plusRepeatWidget(location), editPoint));
                  //  plus column already used
                }
              }
            }
            break;
          default:
            logger.i('unmanaged MeasureNodeType: ${measureNode.measureNodeType}');
            assert(false);
            break;
        }
      }

      addChordRowChildrenAndComplete(maxEntryColumns);
    }

    //  append to the last section
    if (lastChordSectionLocation != null &&
        (chordSong.findChordSectionBySectionVersion(lastChordSectionLocation.sectionVersion)?.isNotEmpty ?? false)) {
      addChordRowSectionAppend(maxEntryColumns,
          EditPoint(lastChordSectionLocation, measureEditType: MeasureEditType.append, onEndOfRow: true));
    }

    //  add the append for a new section
    if (selectedEditPoint == null) {
      var editPoint = EditPoint(
        null,
        measureEditType: MeasureEditType.append,
      );
      addChordRowChild(_debugWidget(
          Container(
            margin: marginInsets,
            padding: textPadding,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _addColor,
            ),
            child: editTooltip(
              message: 'add new chord section here',
              child: AppInkWell(
                appKeyEnum: AppKeyEnum.editNewChordSection,
                onTap: () {
                  setState(() {
                    chordSong.setCurrentChordSectionLocation(null);
                    chordSong.setCurrentMeasureEditType(MeasureEditType.append);
                    ChordSection cs = song.suggestNewSection();
                    selectedEditPoint = EditPoint.byChordSection(cs, measureEditType: MeasureEditType.append);
                    logger.log(_editEditPoint, 'editNewChordSection: ${chordSong.toMarkup()} + $selectedEditPoint');
                  });
                },
                child: Icon(
                  Icons.add,
                  size: chordFontSize,
                ),
              ),
            ),
          ),
          editPoint));

      addChordRowChildrenAndComplete(maxEntryColumns);
    }

    if (kDebugMode) {
      int? length;
      for (var i = 0; i < chordRows.length; i++) {
        var chordRow = chordRows[i];
        assert(chordRow.children != null);
        length ??= chordRow.children?.length;
        if (length != chordRow.children?.length) {
          //  delayed response to put break point here:
          assert(length == chordRow.children?.length);
        } //  abort before the table does it for us
      }
    }

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: chordRows,
      border:
          // _editDebugVerbose
          //     ? const TableBorder(
          //         top: BorderSide(),
          //         right: BorderSide(),
          //         bottom: BorderSide(),
          //         left: BorderSide(),
          //         horizontalInside: BorderSide(),
          //         verticalInside: BorderSide(),
          //       )
          //     :
          null,
    );
  }

  /// generates the lyrics entry widget
  Widget lyricsEntryWidget() {
    List<TableRow> lyricsRows = [];

    //  find the longest chord row
    var chordMaxColCount = song.getChordSectionLocationGridMaxColCount();
    logger.v('chordMaxColCount: $chordMaxColCount');
    chordMaxColCount = song.chordRowMaxLength();
    chordMaxColCount += 2; //fixme: test!!!!!!!!!!!!!!!!!!
    logger.log(_editLyricEntry, 'chordMaxColCount: $chordMaxColCount');

    //  generate the section pull down data if required
    List<DropdownMenuItem<ChordSection>> sectionItems =
        SplayTreeSet<ChordSection>.from(song.getChordSections()).map((chordSection) {
      return DropdownMenuItem(
        value: chordSection,
        child: Text(
          '${chordSection.sectionVersion}',
          style: generateAppTextStyle(
              fontSize: chordFontSize,
              fontWeight: FontWeight.bold,
              backgroundColor: getBackgroundColorForSectionVersion(chordSection.sectionVersion)),
        ),
      );
    }).toList();

    //  main entries
    var addSection = 0;
    logger.log(_editLyricEntry, '_lyricsEntries: ${lyricsEntries.entries.length}');
    for (final entry in lyricsEntries.entries) {
      //  insert new section above
      {
        var children = <Widget>[];
        children.add(Row(
          children: [
            editTooltip(
              message: 'Add new lyrics section here',
              child: DropdownButton<ChordSection>(
                key: ValueKey('addLyricsSection${addSection++}'),
                hint: Container(
                  margin: marginInsets,
                  padding: textPadding,
                  decoration: const BoxDecoration(
                    // shape: BoxShape.circle,
                    color: _addColor,
                  ),
                  child: Icon(
                    Icons.add,
                    size: chordFontSize,
                  ),
                ),
                items: sectionItems,
                onChanged: (value) {
                  if (value != null) {
                    //logger.log(_editLog, 'addChordSection(${entry.lyricSection.index}, ${value.sectionVersion});');
                    lyricsEntries.insertChordSection(entry, value);
                    pushLyricsEntries();
                  }
                },
              ),
            ),
          ],
        ));
        while (children.length < chordMaxColCount) {
          children.add(NullWidget());
        }

        lyricsRows.add(TableRow(children: children));
      }

      //  chord section headers
      var chordSection = song.getChordSection(entry.lyricSection.sectionVersion);
      var sectionBackgroundColor = getBackgroundColorForSectionVersion(chordSection?.sectionVersion);
      var sectionLyricsBoldTextStyle = chordBoldTextStyle.copyWith(backgroundColor: sectionBackgroundColor);
      {
        var children = <Widget>[];
        children.add(Container(
          margin: marginInsets,
          padding: textPadding,
          color: sectionBackgroundColor,
          child: Text(
            entry.lyricSection.sectionVersion.toString(),
            style: sectionLyricsBoldTextStyle,
          ),
        ));

        while (children.length < chordMaxColCount - 1) {
          children.add(NullWidget());
        }
        children.add(editTooltip(
          message: 'Delete this lyric section',
          child: AppInkWell(
            appKeyEnum: AppKeyEnum.editDeleteLyricsSection,
            onTap: () {
              lyricsEntries.delete(entry);
              pushLyricsEntries();
            },
            child: const Icon(
              Icons.delete,
              size: _defaultChordFontSize,
              color: Colors.black,
            ),
          ),
        ));

        while (children.length < chordMaxColCount) {
          children.add(NullWidget());
        }
        lyricsRows.add(TableRow(children: children));
      }

      //  chord rows and lyrics lines
      final expanded = !appOptions.compressRepeats;
      var chordRowCount = chordSection?.rowCount(expanded: expanded) ?? 0;
      var lineCount = entry.length;
      var limit = max(chordRowCount, lineCount);
      logger.log(_editLyricEntry,
          '\'${chordSection?.toMarkup()}\': chord/lyrics limit: $limit = max($chordRowCount,$lineCount)');
      for (var line = 0; line < limit; line++) {
        var children = <Widget>[];

        // children.add(Text('line:$line/$chordRowCount '));

        //  chord rows
        {
          if (line < chordRowCount) {
            var row = chordSection?.rowAt(line, expanded: expanded);
            logger.log(_editLyricEntry, '   row.length: ${row?.length}/$chordMaxColCount');
            for (final Measure measure in row ?? []) {
              children.add(Container(
                margin: marginInsets,
                padding: textPadding,
                color: sectionBackgroundColor,
                child: Text(
                  measure.transpose(key, 0),
                  style: sectionLyricsBoldTextStyle,
                  maxLines: 1,
                ),
              ));
            }
          }
          while (children.length < chordMaxColCount - 1) {
            children.add(NullWidget());
          }
        }

        assert(children.length < chordMaxColCount);

        if (line == 0 && lineCount == 0) {
          logger.log(_editLyricEntry, '   line == 0 && lineCount == 0');
          children.add(
            Row(
              children: [
                AppInkWell(
                  appKeyEnum: AppKeyEnum.lyricsEntryLineAdd,
                  value: line,
                  onTap: () {
                    lyricsEntries.addBlankLyricsLine(entry);
                    logger.log(_editLyricEntry, 'addBlankLyricsLine: \'$entry\'');
                    pushLyricsEntries();
                  },
                  child: Container(
                      margin: appendInsets,
                      padding: textPadding,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _addColor,
                      ),
                      child: editTooltip(
                        message: 'add a lyric line here',
                        child: Icon(
                          Icons.add,
                          size: chordFontSize,
                        ),
                      )),
                ),
              ],
            ),
          );
        } else if (line < lineCount) {
          var lyricsTextField = entry.textFieldAt(line);

          children.add(Row(
            children: [
              AppInkWell(
                appKeyEnum: AppKeyEnum.lyricsEntryLineUp,
                value: line,
                onTap: () {
                  lyricsEntries.moveLyricLine(entry.lyricSection, line, isUp: true);
                  pushLyricsEntries();
                },
                child: Container(
                    margin: appendInsets,
                    padding: textPadding,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _addColor,
                    ),
                    child: editTooltip(
                      message: 'move the lyric line upwards a section',
                      child: Icon(
                        Icons.arrow_upward,
                        size: chordFontSize,
                      ),
                    )),
              ),
              AppInkWell(
                appKeyEnum: AppKeyEnum.lyricsEntryLineDown,
                value: line,
                onTap: () {
                  lyricsEntries.moveLyricLine(entry.lyricSection, line, isUp: false);
                  pushLyricsEntries();
                },
                child: Container(
                    margin: appendInsets,
                    padding: textPadding,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _addColor,
                    ),
                    child: editTooltip(
                      message: 'move the lyric line downwards a section',
                      child: Icon(
                        Icons.arrow_downward,
                        size: chordFontSize,
                      ),
                    )),
              ),
              const Spacer(),
              Expanded(
                flex: 30,
                child: lyricsTextField,
              ),
              const Spacer(),
              editTooltip(
                message: 'Delete this lyric line',
                child: AppInkWell(
                  appKeyEnum: AppKeyEnum.lyricsEntryLineDelete,
                  value: line,
                  onTap: () {
                    lyricsEntries.deleteLyricLine(
                      entry,
                      line,
                    );
                    pushLyricsEntries();
                  },
                  child: const Icon(
                    Icons.delete,
                    size: _defaultChordFontSize,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ));
        }
        while (children.length < chordMaxColCount) {
          children.add(NullWidget());
        }

        lyricsRows.add(TableRow(children: children));
      }
    }

    //  last append goes here
    {
      var children = <Widget>[];
      children.add(
        editTooltip(
          message: song.getChordSections().isEmpty
              ? 'No lyric section to add!  Add at least one chord section above.'
              : 'Add new lyric section here',
          child: DropdownButton<ChordSection>(
            hint: Container(
              margin: marginInsets,
              padding: textPadding,
              decoration: const BoxDecoration(
                // shape: BoxShape.circle,
                color: _addColor,
              ),
              child: Icon(
                Icons.add,
                size: chordFontSize,
              ),
            ),
            items: sectionItems,
            onChanged: (value) {
              if (value != null) {
                lyricsEntries.addChordSection(value);
                pushLyricsEntries();
              }
            },
            itemHeight: null,
          ),
        ),
      );

      while (children.length < chordMaxColCount) {
        children.add(NullWidget());
      }

      lyricsRows.add(TableRow(children: children));
    }

    //  compute the flex for the columns
    var columnWidths = <int, TableColumnWidth>{};
    for (var i = 0; i < chordMaxColCount - 1; i++) {
      columnWidths[i] = const IntrinsicColumnWidth();
    }
    columnWidths[chordMaxColCount - 1] = const FlexColumnWidth(3);

    return Table(
      children: lyricsRows,
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: columnWidths,
      // border: const TableBorder(
      // top: BorderSide(width: 2),
      // bottom: BorderSide(width: 2),
      // left: BorderSide(width: 2),
      // right: BorderSide(width: 2),
      // horizontalInside: BorderSide(width: 1),
      // verticalInside: BorderSide(width: 1)
      // ),
    );
  }

  Widget _debugWidget(Widget w, EditPoint editPoint) {
    //  debug only
    if (_editDebugVerbose) {
      return AppWrap(
        children: [
          Text('$editPoint'),
          w,
        ],
      );
    }
    return w;
  }

  /// convenience method to push lyrics changes to the song and the display
  void pushLyricsEntries() {
    logger.log(
        _editLyricEntry,
        '_pushLyricsEntries(): _lyricsEntries.asRawLyrics(): ${identityHashCode(song)}:'
        ' \'<${lyricsEntries.asRawLyrics().replaceAll('\n', '\\n')}>\'');
    updateRawLyrics(lyricsEntries.asRawLyrics());
    logger.log(_editLyricEntry, '_pushLyricsEntries(): rawLyrics: ${song.rawLyrics.replaceAll('\n', '\\n')}');
  }

  void updateRawLyrics(String rawLyrics) {
    song.rawLyrics = rawLyrics;
    lyricsEntries.updateEntriesFromSong();
    undoStackPushIfDifferent();
    checkSongChangeStatus();
  }

  LyricsEntries lyricsEntriesFromSong(Song entrySong) {
    LyricsEntries ret = LyricsEntries.fromSong(entrySong,
        onLyricsLineChangedCallback: onLyricsLineChangedCallback, textStyle: lyricsTextStyle);
    ret.addListener(lyricsEntriesListener);
    return ret;
  }

  void onLyricsLineChangedCallback() {
    logger.log(_editLyricEntry, '_onLyricsLineChangedCallback():  ${lyricsEntries.hasChangedLines()}');
  }

  void lyricsEntriesListener() {
    pushLyricsEntries(); //  if low level edits were made by the widget tree
    checkSongChangeStatus();
    logger.log(_editLyricEntry, '_lyricsEntries: _checkSongChangeStatus()');
  }

  String proChordsForLyrics() {
    var sb = StringBuffer();
    var lineCount = 1;
    SectionVersion? lastSectionVersion;
    for (var line in proLyricsTextEditingController.text.split('\n')) {
      try {
        var sectionVersion = SectionVersion.parseString(line);

        if (lastSectionVersion != null) {
          logger.d('proChordsForLyrics(): $lastSectionVersion $lineCount');
          sb.write(
              song.findChordSectionBySectionVersion(lastSectionVersion)?.toMarkupInRows(lineCount, expanded: false));
          lineCount = 1;
        }

        lastSectionVersion = sectionVersion;
      } catch (e) {
        lineCount++;
      }
    }
    if (lastSectionVersion != null) {
      logger.d('proChordsForLyrics(): $lastSectionVersion $lineCount');
      sb.write(song.findChordSectionBySectionVersion(lastSectionVersion)?.toMarkupInRows(lineCount, expanded: false));
    }
    return sb.toString();
  }

  ///  add a row for a plus on the bottom of the section to continue on the next row
  // void addSectionVersionEndToTable(List<TableRow> rows, SectionVersion? sectionVersion, int maxCols) {
  //   if (sectionVersion == null) {
  //     return;
  //   }
  //   ChordSection? chordSection = song.findChordSectionBySectionVersion(sectionVersion);
  //   ChordSectionLocation? loc = song.findLastChordSectionLocation(chordSection);
  //   if (loc != null) {
  //     loc = loc.asPhraseLocation();
  //     EditPoint editPoint =
  //         EditPoint(loc?.asPhraseLocation(), measureEditType: MeasureEditType.append, onEndOfRow: true);
  //
  //     Widget w = plusMeasureEditGridDisplayWidget(editPoint,
  //         tooltip: 'add new measure on a new row'
  //             '${kDebugMode ? ' $editPoint' : ''}');
  //     List<Widget> children = [];
  //     children.add(nullEditGridDisplayWidget()); //  section
  //     children.add(w);
  //
  //     //  add children to max columns to keep the table class happy
  //     while (children.length < maxCols) {
  //       children.add(NullWidget());
  //     }
  //
  //     //  add row to table
  //     rows.add(TableRow(key: ValueKey('table${tableKeyId++}'), children: children));
  //   }
  // }

  /// process the raw keys flutter doesn't want to
  /// this is largely done for the desktop... since phones and tablets usually don't have keyboards
  void editOnKey(RawKeyEvent value) {
    logger.v('editOnKey($value)');
    //  fixme: edit screen does not respond to escape after the detail screen
    if (value.runtimeType == RawKeyDownEvent) {
      RawKeyDownEvent e = value as RawKeyDownEvent;
      logger.log(
          _editKeyboard,
          'edit onKey:'
          //' ${e.data.logicalKey}'
          //', primaryFocus: ${_focusManager.primaryFocus}'
          ', context: ${focusManager.primaryFocus?.context}'
          // ', ctl: ${e.isControlPressed}'
          // ', shf: ${e.isShiftPressed}'
          // ', alt: ${e.isAltPressed}'
          //
          );
      logger.d(
          'isControlPressed?: keyLabel:\'${e.data.logicalKey.keyLabel}\', ${LogicalKeyboardKey.keyZ.keyLabel.toUpperCase()}');
      if (e.isControlPressed) {
        logger.d(
            'isControlPressed: keyLabel:\'${e.data.logicalKey.keyLabel}\', ${LogicalKeyboardKey.keyZ.keyLabel.toUpperCase()}');
        if (e.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
          if (selectedEditPoint != null && measureEntryValid) {
            performEdit(endOfRow: true);
          }
          logger.d('main onKey: found arrowDown');
        } else if (e.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
          if (selectedEditPoint != null && measureEntryValid) {
            performEdit(endOfRow: false);
          }
        } else if (e.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
          logger.d('main onKey: found arrowUp');
        } else if (e.data.logicalKey == LogicalKeyboardKey.undo) {
          //  not that likely
          if (e.isShiftPressed) {
            redo();
          } else {
            undo();
          }
        } else if (e.data.logicalKey.keyLabel == LogicalKeyboardKey.keyZ.keyLabel.toUpperCase()) //fixme
        {
          redo();
        } else if (e.data.logicalKey.keyLabel == LogicalKeyboardKey.keyZ.keyLabel.toLowerCase()) //fixme
        {
          undo();
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
        /// clear editing with the escape key
        // but don't pop from edit screen
        // if (_measureEntryIsClear && !(hasChangedFromOriginal || _lyricsEntries.hasChangedLines())) {
        //   Navigator.pop(context);
        // } else
        {
          performMeasureEntryCancel();
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.enter) || e.isKeyPressed(LogicalKeyboardKey.numpadEnter)) {
        logger.d('e.isKeyPressed(enter)');
        if (isProEditInput) {
          setState(() {
            checkSong();
          });
        } else if (selectedEditPoint != null) //  fixme: this is a poor workaround
        {
          performEdit(done: false, endOfRow: true);
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
        int baseOffset = editTextController.selection.extentOffset;
        if (baseOffset > 0) {
          editTextController.selection = TextSelection(baseOffset: baseOffset - 1, extentOffset: baseOffset - 1);
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        int extentOffset = editTextController.selection.extentOffset;

        //  cancel multi character selection
        if (editTextController.selection.baseOffset < extentOffset) {
          editTextController.selection = TextSelection(baseOffset: extentOffset, extentOffset: extentOffset);
        } else {
          //  move closer to the end
          if (extentOffset < editTextController.text.length) {
            editTextController.selection = TextSelection(baseOffset: extentOffset + 1, extentOffset: extentOffset + 1);
          }
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.delete)) {
        logger.d('main onKey: delete: "${editTextController.text}", ${editTextController.selection}');
        if (editTextController.text.isEmpty) {
          if (selectedEditPoint?.measureEditType == MeasureEditType.replace) {
            performDelete();
          } else {
            performMeasureEntryCancel();
          }
        } else if (editTextController.selection.baseOffset < editTextController.selection.extentOffset) {
          //  do the usual text edit thing    fixme: why is this not done by flutter?
          int loc = editTextController.selection.baseOffset;

          //  selection in a range
          editTextController.text = (editTextController.selection.baseOffset > 0
                  ? editTextController.text.substring(0, editTextController.selection.baseOffset)
                  : '') +
              editTextController.text.substring(editTextController.selection.extentOffset);
          editTextController.selection = TextSelection(baseOffset: loc, extentOffset: loc);
        } else if (editTextController.selection.extentOffset < editTextController.text.length - 1) {
          int loc = editTextController.selection.extentOffset;
          editTextController.text =
              editTextController.text.substring(0, loc) + editTextController.text.substring(loc + 1);
          editTextController.selection = TextSelection(baseOffset: loc, extentOffset: loc);
        }
      }
      // else if (e.isKeyPressed(LogicalKeyboardKey.backspace)) {
      //   BuildContext? context = _editTextFieldFocusNode?.context;
      //   var w = context?.widget;
      //
      //   if (w != null) {
      //     var editableText = w as EditableText;
      //     logger.log(_editLog,'backspace: '
      //         'editableText: $editableText');  // fixme
      //     // var controller = editableText.controller;
      //     // logger.log(_editLog,'backspace:'
      //     //     ' controller: $controller');
      //     // logger.log(_editLog,'backspace:'
      //     //     ' text: ${controller.text}'
      //     //     ', baseOffset: ${controller.selection.baseOffset}'
      //     //     ', extentOffset: ${controller.selection.extentOffset}');
      //     // logger.log(_editLog,'backspace: <${_editTextController.text}>'
      //     //     ' context: ${_editTextFieldFocusNode?.context.toString()}'
      //     //     ' w: $w'
      //     //   // ', enclosingScope: ${_editTextFieldFocusNode?.enclosingScope}'
      //     //     // ', toStringShort: ${_editTextFieldFocusNode?.toStringShort()}'
      //     // );
      //   }
      // }
      else if (e.isKeyPressed(LogicalKeyboardKey.space) && selectedEditPoint != null) {
        logger.log(_editKeyboard, 'main onKey: space: "${editTextController.text}", ${editTextController.selection}');
        int extentOffset = editTextController.selection.extentOffset;

        editTextController.selection =
            TextSelection(baseOffset: 0, extentOffset: extentOffset); // fixme:!!!!!!!!!!!!!!!!!!!!
        preProcessMeasureEntry(editTextController.text);
        if (measureEntryValid && selectedEditPoint != null) {
          performEdit();
        }
      } else {
        logger.d('main onKey: not processed: "${e.data.logicalKey}"');
      }
    }
    logger.d('post edit onKey: value: $value');
  }

  Widget nullEditGridDisplayWidget() {
    return const Text(
      '',
      //' null',  //  diagnostic
    );
  }

  Widget sectionEditGridDisplayWidget(EditPoint editPoint) {
    MeasureNode? measureNode =
        chordSong.findMeasureNodeByLocation(editPoint.location) ?? editPoint.measureNode; //  for new sections
    if (measureNode == null) {
      return const Text('null');
    }

    if (measureNode.measureNodeType != MeasureNodeType.section) {
      return const Text('not_section');
    }

    ChordSection chordSection = measureNode as ChordSection;
    var sectionColor = getBackgroundColorForSectionVersion(chordSection.sectionVersion);
    var sectionChordTextStyle = chordBoldTextStyle.copyWith(backgroundColor: sectionColor);

    if (editPoint.matches(selectedEditPoint)) {
      //  we're editing the section
      if (editTextField == null) {
        String entry = chordSection.sectionVersion.toString();
        editTextController.text = entry;
        editTextController.selection = TextSelection(baseOffset: 0, extentOffset: entry.length);
        editTextField = TextField(
          controller: editTextController,
          focusNode: editTextFieldFocusNode,
          maxLength: null,
          style: _textFieldStyle,
          decoration: const InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            hintText: 'Enter the section.',
          ),
          autofocus: true,
          enabled: true,
        );
      }

      SectionVersion? entrySectionVersion = parsedSectionEntry(editTextController.text);
      bool isValidSectionEntry = (entrySectionVersion != null);

      //  build a list of section version numbers
      List<DropdownMenuItem<int>> sectionVersionNumberDropdownMenuList = [];
      for (int i = 0; i <= 9; i++) {
        sectionVersionNumberDropdownMenuList.add(
          DropdownMenuItem<int>(
            key: ValueKey('sectionVersionNumber.$i'),
            value: i,
            child: Row(
              children: <Widget>[
                Text(
                  (i == 0 ? 'Default' : i.toString()),
                  style: sectionChordTextStyle,
                ),
              ],
            ),
          ),
        );
      }

      return Container(
        color: sectionColor,
        width: _entryWidth,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              //  section entry text field
              Container(margin: marginInsets, padding: textPadding, color: sectionColor, child: editTextField),
              if (measureEntryCorrection != null)
                editTooltip(
                  message: measureEntryValid
                      ? 'This is your adjusted section'
                      : 'Your entry error is in parentheses'
                          '${kDebugMode ? ' $editPoint' : ''}',
                  child: AppWrap(
                    children: <Widget>[
                      Text(
                        measureEntryCorrection ?? '',
                        style: measureEntryValid
                            ? sectionChordTextStyle
                            : sectionChordTextStyle.copyWith(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              //  section entry pull downs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  //  section selection
                  chordSectionVersionDropdownButton(),

                  //  section version selection
                  DropdownButton<int>(
                    value: sectionVersion.version,
                    items: sectionVersionNumberDropdownMenuList,
                    onChanged: (value) {
                      setState(() {
                        if (value != null) {
                          sectionVersion = SectionVersion(sectionVersion.section, value);
                          editTextController.text = sectionVersion.toString();
                        }
                      });
                      logger.v('_sectionVersion = ${sectionVersion.toString()}');
                    },
                    style: sectionChordTextStyle,
                    itemHeight: null,
                  )
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  //  section delete
                  editTooltip(
                    message: 'Delete this section',
                    child: AppInkWell(
                      appKeyEnum: AppKeyEnum.editChordSectionDelete,
                      value: chordSection,
                      onTap: () {
                        performDelete();
                      },
                      child: const Icon(
                        Icons.delete,
                        size: _defaultChordFontSize,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  editTooltip(
                    message: 'Cancel the modification.',
                    child: AppInkWell(
                      appKeyEnum: AppKeyEnum.editChordSectionCancel,
                      value: chordSection,
                      onTap: () {
                        performMeasureEntryCancel();
                      },
                      child: Icon(
                        Icons.cancel,
                        size: _defaultChordFontSize,
                        color: measureEntryValid ? Colors.black : Colors.red,
                      ),
                    ),
                  ),
                  if (isValidSectionEntry)
                    editTooltip(
                      message: 'Accept the modification and add measures to the section.',
                      child: AppInkWell(
                        appKeyEnum: AppKeyEnum.editChordSectionAcceptAndAdd,
                        value: chordSection,
                        onTap: () {
                          performEdit();
                        },
                        child: const Icon(
                          Icons.arrow_forward,
                          size: _defaultChordFontSize,
                        ),
                      ),
                    ),
                  //  section enter
                  if (isValidSectionEntry)
                    editTooltip(
                      message: 'Accept the modification',
                      child: AppInkWell(
                        appKeyEnum: AppKeyEnum.editChordSectionAccept,
                        value: chordSection,
                        onTap: () {
                          logger.d('sectionVersion measureEditType: ${selectedEditPoint?.measureEditType.toString()}');
                          performEdit(done: true, endOfRow: selectedEditPoint!.onEndOfRow); //  section enter
                        },
                        child: const Icon(
                          Icons.check,
                          size: _defaultChordFontSize,
                        ),
                      ),
                    ),
                  //  can't cancel some chordSection that has already been added!
                ],
              ),
            ]),
      );
    }

    var matchingVersions = chordSong.matchingSectionVersions(editPoint.location.sectionVersion);
    var matchingVersionsString = '';
    for (final mv in matchingVersions) {
      matchingVersionsString += mv.toString();
    }

    //  the section is not selected for editing, just display
    return AppInkWell(
      appKeyEnum: AppKeyEnum.editChordDataPoint,
      value: editPoint.location,
      onTap: () {
        sectionVersion = chordSection.sectionVersion;
        editTextController.text = sectionVersion.toString();
        setEditPoint(editPoint);
      },
      child: Container(
          margin: marginInsets,
          padding: textPadding,
          color: sectionColor,
          child: editTooltip(
              message: 'modify or delete the section'
                  '${kDebugMode ? ' $editPoint' : ''}',
              child: Text(
                matchingVersionsString,
                style: sectionChordTextStyle,
              ))),
    );
  }

  Widget measureEditGridDisplayWidget(EditPoint editPoint) {
    Measure? measure;
    Phrase? phrase;
    {
      MeasureNode? measureNode = chordSong.findMeasureNodeByLocation(editPoint.location);
      if (measureNode == null) {
        return const Text('null');
      }

      switch (measureNode.measureNodeType) {
        case MeasureNodeType.section:
          //  insert new measure as measure in front of a section or after the end
          break;
        case MeasureNodeType.measure:
          measure = measureNode.transposeToKey(key) as Measure;
          break;
        default:
          logger.i('failed measureNode.measureNodeType: ${measureNode.measureNodeType}');
          assert(false);
          return Text('false: ${measureNode.measureNodeType}');
      }

      measureNode = chordSong.findMeasureNodeByLocation(editPoint.location.asPhraseLocation());
      if (measureNode is Phrase) {
        phrase = measureNode;
      }
      //  note: can be a chord section location!
    }

    Color sectionColor = getBackgroundColorForSectionVersion(editPoint.location.sectionVersion);
    var sectionChordBoldTextStyle = chordBoldTextStyle.copyWith(backgroundColor: sectionColor);
    var sectionAppTextStyle = appTextStyle.copyWith(backgroundColor: sectionColor);

    Widget ret;
    if (editPoint.matches(selectedEditPoint)) {
      //  editing this measure
      logger.log(
          _editEditPoint,
          '_measureEditGridDisplayWidget pre: (${editTextController.selection.baseOffset}'
          ',${editTextController.selection.extentOffset})'
          ' "${editTextController.text}"');
      if (editTextField == null) {
        if (editTextFieldFocusNode != null) {
          disposeList.add(editTextFieldFocusNode!); //  fixme: dispose of the old?
        }
        //  measure
        // logger.d(
        //     'selectedEditPoint measure: empty: ${_editTextController.text.isEmpty} "${_editTextController.text}"'
        //     ', type: ${selectedEditPoint?._measureEditType}');
        editTextFieldFocusNode = FocusNode();
        editTextField = TextField(
          controller: editTextController,
          focusNode: editTextFieldFocusNode,
          maxLength: null,
          style: _textFieldStyle,
          decoration: InputDecoration(
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            hintText:
                (editTextController.text.isEmpty && (selectedEditPoint?.measureEditType == MeasureEditType.replace))
                    //  fixme: delete of last measure in section should warn about second delete
                    ? 'A second delete will delete this measure' //  fixme: not working?
                    : 'Enter the measure.',
            contentPadding: const EdgeInsets.all(_defaultFontSize / 2),
          ),
          autofocus: true,
          enabled: true,
          autocorrect: false,
        );
      }

      logger.log(
          _editEditPoint,
          '_measureEditGridDisplayWidget post: (${editTextController.selection.baseOffset},${editTextController.selection.extentOffset})'
          ' "${editTextController.text}", ${editTextController.text.isEmpty}');

      if (measureEntryIsClear) {
        measureEntryIsClear = false;
        editTextController.text = measure?.toMarkupWithEnd(null) ?? '';
        measureEntryValid = true; //  should always be!... at least at this moment,  fixme: verify
        editTextController.selection = TextSelection(baseOffset: 0, extentOffset: editTextController.text.length);
        editTextFieldFocusNode?.requestFocus();
        logger.log(
            _editEditPoint,
            '_measureEditGridDisplayWidget post clear: ${editPoint.location}: $measure'
            '  selection: (${editTextController.selection.baseOffset}, ${editTextController.selection.extentOffset})'
            ', ${chordSong.toMarkup()}');
      }

      //  make the key selection drop down list
      List<DropdownMenuItem<ScaleNote>> keyChordDropDownMenuList = [];
      {
        //  list the notes required
        List<ScaleNote> scaleNotes = [];
        for (int i = 0; i < MusicConstants.notesPerScale; i++) {
          scaleNotes.add(key.getMajorScaleByNote(i));
        }

        //  not scale notes
        for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
          final scaleNote = key.getScaleNoteByHalfStep(i);
          if (!scaleNotes.contains(scaleNote)) scaleNotes.add(scaleNote);
        }

        for (final scaleNote in scaleNotes) {
          String s = scaleNote.toMarkup();
          String label =
              "${s.padRight(2)} ${ChordComponent.getByHalfStep(scaleNote.halfStep - key.getHalfStep()).shortName.padLeft(2)}";
          DropdownMenuItem<ScaleNote> item = appDropdownMenuItem(
            appKeyEnum: AppKeyEnum.editScaleNote,
            value: scaleNote,
            child: Text(
              label,
              style: sectionAppTextStyle,
            ),
          );
          keyChordDropDownMenuList.add(item);
          ButtonTheme(
            child: item,
          );
        }
      }

      Widget majorChordButton = editTooltip(
          message: 'Enter the major chord.',
          child: appEnumeratedButton(
            keyChordNote.toString(),
            appKeyEnum: AppKeyEnum.editMajorChord,
            onPressed: () {
              setState(() {
                updateChordText(keyChordNote.toMarkup());
              });
            },
            fontSize: _defaultChordFontSize,
            // backgroundColor: fixme,
          ));
      Widget minorChordButton;
      {
        ScaleChord sc = ScaleChord(
          keyChordNote,
          ChordDescriptor.minor,
        );
        minorChordButton = editTooltip(
            message: 'Enter the minor chord.',
            child: appEnumeratedButton(
              sc.toString(),
              appKeyEnum: AppKeyEnum.editMinorChord,
              onPressed: () {
                setState(() {
                  updateChordText(sc.toMarkup());
                });
              },
              fontSize: _defaultChordFontSize,
            ));
      }
      Widget dominant7ChordButton;
      {
        ScaleChord sc = ScaleChord(keyChordNote, ChordDescriptor.dominant7);
        dominant7ChordButton = editTooltip(
            message: 'Enter the dominant7 chord.',
            child: appEnumeratedButton(
              sc.toString(),
              appKeyEnum: AppKeyEnum.editDominant7Chord,
              onPressed: () {
                setState(() {
                  updateChordText(sc.toMarkup());
                });
              },
              fontSize: _defaultChordFontSize,
            ));
      }

      List<DropdownMenuItem<ScaleChord>> otherChordDropDownMenuList = [];
      {
        // other chords
        for (ChordDescriptor cd in ChordDescriptor.otherChordDescriptorsOrdered) {
          ScaleChord sc = ScaleChord(keyChordNote, cd);
          otherChordDropDownMenuList.add(appDropdownMenuItem<ScaleChord>(
            appKeyEnum: AppKeyEnum.editScaleChord,
            value: sc,
            child: Row(
              children: <Widget>[
                Text(
                  sc.toMarkup(),
                  style: appDropdownListItemTextStyle,
                ),
              ],
            ),
          ));
        }
      }

      List<DropdownMenuItem<ScaleNote>> slashNoteDropDownMenuList = [];
      {
        // slash chords
        for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
          final sc = key.getScaleNoteByHalfStep(i);
          slashNoteDropDownMenuList.add(DropdownMenuItem<ScaleNote>(
            key: ValueKey('scaleNote$sc'),
            value: sc,
            child: Row(
              children: <Widget>[
                Text(
                  sc.toMarkup(),
                  style: appDropdownListItemTextStyle,
                ),
              ],
            ),
          ));
        }
      }

      ret = Container(
          color: sectionColor,
          width: _entryWidth,
          margin: marginInsets,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                //  measure edit text field
                editTooltip(
                  message: 'Enter new chords here'
                      '${kDebugMode ? ' $editPoint' : ''}',
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    color: sectionColor,
                    child: editTextField,
                  ),
                ),
                if (measureEntryCorrection != null)
                  editTooltip(
                    message: measureEntryValid
                        ? 'These are your adjusted chords'
                        : 'Your chord entry error is in parentheses'
                            '${kDebugMode ? ' $editPoint' : ''}',
                    child: Container(
                      margin: doubleMarginInsets,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                        Text(
                          measureEntryCorrection ?? '',
                          style: measureEntryValid
                              ? sectionChordBoldTextStyle
                              : sectionChordBoldTextStyle.copyWith(color: Colors.red),
                        ),
                      ]),
                    ),
                  ),
                //  measure edit chord selection
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
                  editTooltip(
                      message: 'Select other notes from the key scale.',
                      child: ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<ScaleNote>(
                          items: keyChordDropDownMenuList,
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                keyChordNote = value;
                              }
                            });
                          },
                          value: keyChordNote,
                          style: sectionAppTextStyle,
                          itemHeight: null,
                        ),
                      )),
                  majorChordButton,
                  minorChordButton,
                  dominant7ChordButton,
                  editTooltip(
                    message: 'Enter a silent chord.',
                    child: appEnumeratedButton(
                      'X',
                      appKeyEnum: AppKeyEnum.editSilentChord,
                      onPressed: () {
                        setState(() {
                          updateChordText('X');
                        });
                      },
                      fontSize: _defaultChordFontSize,
                    ),
                  ),
                ]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    editTooltip(
                      message: 'Select from other chord descriptors.',
                      child: ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<ScaleChord>(
                          hint: Text(
                            'Other chords',
                            style: sectionAppTextStyle,
                          ),
                          items: otherChordDropDownMenuList,
                          onChanged: (value) {
                            setState(() {
                              updateChordText(value?.toMarkup());
                            });
                          },
                          style: sectionAppTextStyle,
                          itemHeight: null,
                        ),
                      ),
                    ),
                    editTooltip(
                      message: 'Select a slash note',
                      child: ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<ScaleNote>(
                          hint: Text(
                            "/note",
                            style: sectionAppTextStyle,
                          ),
                          items: slashNoteDropDownMenuList,
                          onChanged: (value) {
                            setState(() {
                              updateChordText('/${value?.toMarkup() ?? ''}');
                            });
                          },
                          style: sectionAppTextStyle,
                          itemHeight: null,
                        ),
                      ),
                    ),
                    if ((measure?.endOfRow ?? false) &&
                        phrase != null &&
                        editPoint.location.measureIndex != phrase.length - 1)
                      editTooltip(
                        message: 'Join the row with the row below'
                            '${kDebugMode ? ' $editPoint' : ''}',
                        child: appButton(
                          'Join',
                          appKeyEnum: AppKeyEnum.editRowJoin,
                          onPressed: () {
                            setState(() {
                              song.setCurrentChordSectionLocation(editPoint.location);
                              song.setCurrentChordSectionLocationMeasureEndOfRow(false);
                              undoStackPushIfDifferent();
                            });
                          },
                          fontSize: _defaultChordFontSize,
                        ),
                      ),
                    if (!(measure?.endOfRow ?? false) &&
                        phrase != null &&
                        editPoint.location.measureIndex != phrase.length - 1)
                      editTooltip(
                        message: 'Add new chord row after this measure'
                            '${kDebugMode ? ' $editPoint' : ''}',
                        child: appButton(
                          'Split',
                          appKeyEnum: AppKeyEnum.editRowSplit,
                          onPressed: () {
                            setState(() {
                              song.setCurrentChordSectionLocation(editPoint.location);
                              song.setCurrentChordSectionLocationMeasureEndOfRow(true);
                              undoStackPushIfDifferent();
                            });
                          },
                          fontSize: _defaultChordFontSize,
                        ),
                      ),
                  ],
                ),
                const AppSpace(space: 20),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      if (editPoint.measureEditType == MeasureEditType.replace)
                        editTooltip(
                          message: 'Delete this measure'
                              '${kDebugMode ? ' $editPoint' : ''}',
                          child: AppInkWell(
                            appKeyEnum: AppKeyEnum.editDeleteChordMeasure,
                            onTap: () {
                              performDelete();
                            },
                            child: const Icon(
                              Icons.delete,
                              size: _defaultChordFontSize,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      editTooltip(
                        message: 'Cancel the modification.'
                            '${kDebugMode ? ' $editPoint' : ''}',
                        child: AppInkWell(
                          appKeyEnum: AppKeyEnum.editCancelChordModification,
                          onTap: () {
                            performMeasureEntryCancel();
                          },
                          child: Icon(
                            Icons.cancel,
                            size: _defaultChordFontSize,
                            color: measureEntryValid ? Colors.black : Colors.red,
                          ),
                        ),
                      ),
                      if (measureEntryValid)
                        editTooltip(
                          message: 'Accept the modification and extend the row.'
                              '${kDebugMode ? ' $editPoint' : ''}',
                          child: AppInkWell(
                            appKeyEnum: AppKeyEnum.editAcceptChordModificationAndExtendRow,
                            onTap: () {
                              performEdit(endOfRow: false);
                            },
                            child: const Icon(
                              Icons.arrow_forward,
                              size: _defaultChordFontSize,
                            ),
                          ),
                        ),
                      if (measureEntryValid)
                        editTooltip(
                          message: 'Accept the modification, end the row, and continue editing.'
                              '${kDebugMode ? ' $editPoint' : ''}',
                          child: AppInkWell(
                            appKeyEnum: AppKeyEnum.editAcceptChordModificationAndStartNewRow,
                            onTap: () {
                              performEdit(done: false, endOfRow: true);
                            },
                            child: const Icon(
                              Icons.call_received,
                              size: _defaultChordFontSize,
                            ),
                          ),
                        ),
                      if (measureEntryValid)
                        editTooltip(
                          message: 'Accept the modification.\nFinish adding measures.'
                              '${kDebugMode ? ' $editPoint' : ''}',
                          child: AppInkWell(
                            appKeyEnum: AppKeyEnum.editAcceptChordModificationAndFinish,
                            onTap: () {
                              logger.i(
                                  'endOfRow?:  ${chordSong.findMeasureByChordSectionLocation(selectedEditPoint?.location)?.endOfRow} ');
                              performEdit(
                                  done: true,
                                  endOfRow: chordSong
                                          .findMeasureByChordSectionLocation(selectedEditPoint?.location)
                                          ?.endOfRow ??
                                      false);
                            },
                            child: const Icon(
                              Icons.check,
                              size: _defaultChordFontSize,
                            ),
                          ),
                        ),
                    ]),
                const AppSpace(),
              ]));
    } else {
      //  not editing this measure
      ret = AppInkWell(
        appKeyEnum: AppKeyEnum.editChordSectionLocation,
        value: editPoint.location,
        onTap: () {
          setEditPoint(editPoint);
        },
        child: Container(
            margin: marginInsets,
            padding: textPadding,
            color: sectionColor,
            child: editTooltip(
                message: 'modify or delete the measure'
                    '${kDebugMode ? ' $editPoint ${chordSong.findMeasureNodeByLocation(editPoint.location)}' : ''}',
                child: Text(
                  measure?.transpose(key, transpositionOffset) ?? '',
                  style: sectionChordBoldTextStyle,
                ))),
      );
    }

    return ret;
  }

  Widget repeatEditGridDisplayWidget(EditPoint editPoint) {
    MeasureNode? measureNode = chordSong.findMeasureNodeByLocation(editPoint.location);
    if (measureNode == null || !measureNode.isRepeat()) {
      return Text('is not repeat: ${editPoint.location}: "$measureNode"');
    }
    MeasureRepeat repeat = measureNode as MeasureRepeat;

    Color sectionColor = getBackgroundColorForSectionVersion(editPoint.location.sectionVersion);

    if (editPoint.matches(selectedEditPoint)) {
      var sectionAppTextStyle = appTextStyle.copyWith(backgroundColor: sectionColor);

      return Container(
        color: sectionColor,
        width: _entryWidth,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              //  measure edit chord selection
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                  Text(
                    'Repeat: ',
                    style: sectionAppTextStyle,
                  ),
                  appButton(
                    'x2',
                    appKeyEnum: AppKeyEnum.editRepeatX2,
                    value: editPoint.location,
                    fontSize: _defaultChordFontSize,
                    onPressed: () {
                      song.setRepeat(editPoint.location, 2);
                      undoStackPushIfDifferent();
                      performMeasureEntryCancel();
                    },
                  ),
                  appButton(
                    'x3',
                    appKeyEnum: AppKeyEnum.editRepeatX3,
                    value: editPoint.location,
                    fontSize: _defaultChordFontSize,
                    onPressed: () {
                      song.setRepeat(editPoint.location, 3);
                      undoStackPushIfDifferent();
                      performMeasureEntryCancel();
                    },
                  ),
                  appButton(
                    'x4',
                    appKeyEnum: AppKeyEnum.editRepeatX4,
                    value: editPoint.location,
                    fontSize: _defaultChordFontSize,
                    onPressed: () {
                      song.setRepeat(editPoint.location, 4);
                      undoStackPushIfDifferent();
                      performMeasureEntryCancel();
                    },
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          editTooltip(
                            message: 'Delete this repeat',
                            child: AppInkWell(
                              appKeyEnum: AppKeyEnum.editDeleteRepeat,
                              value: editPoint.location,
                              onTap: () {
                                song.setRepeat(editPoint.location, 1);
                                undoStackPush();
                                performMeasureEntryCancel();
                              },
                              child: const Icon(
                                Icons.delete,
                                size: _defaultChordFontSize,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      editTooltip(
                        message: 'Cancel the modification',
                        child: AppInkWell(
                          appKeyEnum: AppKeyEnum.editRepeatCancel,
                          value: editPoint.location,
                          onTap: () {
                            performMeasureEntryCancel();
                          },
                          child: Icon(
                            Icons.cancel,
                            size: _defaultChordFontSize,
                            color: measureEntryValid ? Colors.black : Colors.red,
                          ),
                        ),
                      ),
                    ]),
              )
            ]),
      );
    }

    var sectionChordBoldTextStyle = chordBoldTextStyle.copyWith(backgroundColor: sectionColor);
    //  not editing this measureNode
    return AppInkWell(
      appKeyEnum: AppKeyEnum.editRepeat,
      value: editPoint.location,
      onTap: () {
        setEditPoint(editPoint);
      },
      child: Container(
          margin: marginInsets,
          padding: textPadding,
          color: sectionColor,
          child: editTooltip(
              message: 'modify or delete the measure',
              child: Text(
                'x${repeat.repeats}',
                style: sectionChordBoldTextStyle,
              ))),
    );
  }

  Widget markerEditGridDisplayWidget(EditPoint editPoint, {MeasureNode? forceMeasureNode}) {
    MeasureNode? measureNode = forceMeasureNode ?? chordSong.findMeasureNodeByLocation(editPoint.location);
    if (measureNode == null || !measureNode.isComment()) {
      return Text('is not comment: ${editPoint.location}: "$measureNode"');
    }

    //  suppress the unnecessary "]"
    if (measureNode is MeasureRepeatExtension &&
        measureNode.marker == ChordSectionLocationMarker.repeatOnOneLineRight) {
      return NullWidget();
    }

    var sectionColor = getBackgroundColorForSectionVersion(editPoint.location.sectionVersion);
    var sectionChordBoldTextStyle = chordBoldTextStyle.copyWith(backgroundColor: sectionColor);

    //  not editing this measureNode
    return Container(
      margin: marginInsets,
      padding: textPadding,
      color: sectionColor,
      child: Text(
        measureNode.toString(),
        style: sectionChordBoldTextStyle,
      ),
    );
  }

  void updateChordText(final String? s) {
    logger.d('_updateChordText(${s.toString()})');

    if (s == null) {
      return;
    }
    String text = editTextController.text;
    editTextFieldFocusNode?.requestFocus();

    if (lastEditTextSelection == null) {
      //  append the string
      editTextController.text = text + s;
      logger.log(
          _editLog,
          '_updateChordText: _lastEditTextSelection is null: '
          '"$text"+"$s"');

      return;
    }
    //  fixme: i'm confused as to why selection extentOffset can be less than baseOffset
    var minOffset = min(lastEditTextSelection!.baseOffset, lastEditTextSelection!.extentOffset);
    var maxOffset = max(lastEditTextSelection!.baseOffset, lastEditTextSelection!.extentOffset);

    logger.log(_editLog, '_updateChordText: ($minOffset, $maxOffset): "$text"');

    if (minOffset < 0) {
      //  append the string
      editTextController.text = text + s;
      int len = text.length + s.length;
      editTextController.selection = lastEditTextSelection!.copyWith(baseOffset: len, extentOffset: len);
      return;
    }

    logger.log(
        _editLog,
        '>=0: "${text.substring(0, minOffset)}"'
        '+"$s"'
        '+"${text.substring(maxOffset)}"');

    editTextController.text = text.substring(0, minOffset) + s + text.substring(maxOffset);
    int len = minOffset + s.length;
    editTextController.selection = lastEditTextSelection!.copyWith(baseOffset: len, extentOffset: len);
  }

  Widget plusRowWidget(ChordSectionLocation? loc) {
    var editPoint = EditPoint(loc?.asPhraseLocation(), measureEditType: MeasureEditType.insert);
    return AppInkWell(
        appKeyEnum: AppKeyEnum.editAddChordRow,
        value: editPoint.location,
        onTap: () {
          if (loc != null) {
            setEditPoint(editPoint);
            logger.d('insert new row above: $selectedEditPoint');
          }
        },
        child: Container(
            margin: appendInsets,
            padding: appendPadding,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _addColor,
            ),
            child: editTooltip(
              message: 'insert new row above'
                  '${kDebugMode ? ' $editPoint' : ''}',
              child: Icon(
                Icons.add,
                size: appendFontSize,
              ),
            )));
  }

  Widget plusRepeatWidget(ChordSectionLocation? loc) {
    var editPoint = EditPoint(loc, measureEditType: MeasureEditType.insert);
    return AppInkWell(
        appKeyEnum: AppKeyEnum.editAddChordRowRepeat,
        value: loc,
        onTap: () {
          if (loc != null) {
            setEditPoint(editPoint);
            song.setRepeat(editPoint.location, 2);
            undoStackPushIfDifferent();
            clearMeasureEntry();
          }
        },
        child: Container(
            margin: appendInsets,
            padding: appendPadding,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _addColor,
            ),
            child: editTooltip(
              message: 'add repeat to this chord row'
                  '${kDebugMode ? ' $editPoint' : ''}',
              child: Icon(
                Icons.repeat,
                size: appendFontSize,
              ),
              //  Text('+x', style: addRowRepeatTextStyle,),
            )));
  }

  Widget plusNewRowWidget(ChordSectionLocation? loc) {
    var editPoint = EditPoint(loc, measureEditType: MeasureEditType.append, onEndOfRow: true);

    return _debugWidget(
        AppInkWell(
            appKeyEnum: AppKeyEnum.editAddChordRowNew,
            value: loc,
            onTap: () {
              setState(() {
                selectedEditPoint = editPoint;
              });
            },
            child: Container(
                margin: appendInsets,
                padding: appendPadding,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _addColor,
                ),
                child: editTooltip(
                  message: 'add a measure on a new chord row'
                      '${kDebugMode ? ' $editPoint' : ''}',
                  child: Icon(
                    Icons.call_received,
                    size: appendFontSize,
                  ),
                ))),
        editPoint);
  }

  Widget plusMeasureEditGridDisplayWidget(EditPoint editPoint, {String? tooltip}) {
    if (editPoint.matches(selectedEditPoint)) {
      logger.log(_editEditPoint, 'plusMeasureEditGridDisplayWidget($editPoint): $selectedEditPoint}');
      return measureEditGridDisplayWidget(editPoint); //  let it do the heavy lifting
    }
    if (selectedEditPoint != null) {
      return NullWidget();
    }

    MeasureNode? measureNode = chordSong.findMeasureNodeByLocation(editPoint.location);
    if (measureNode == null) {
      return NullWidget();
    }

    return AppInkWell(
        appKeyEnum: editPoint.measureEditType == MeasureEditType.insert
            ? AppKeyEnum.editChordPlusInsert
            : AppKeyEnum.editChordPlusAppend,
        value: editPoint.location,
        onTap: () {
          setEditPoint(editPoint);
        },
        child: Container(
            margin: appendInsets,
            padding: appendPadding,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _addColor,
            ),
            child: editTooltip(
              message: tooltip ??
                  ('add new measure on this row'
                      '${kDebugMode ? ' loc: $editPoint' : ''}'),
              child: Icon(
                Icons.add,
                size: appendFontSize,
              ),
            )));
  }

  /// make a drop down list for the next most available, new sectionVersion
  DropdownButton<SectionVersion> chordSectionVersionDropdownButton() {
    //  figure the selection versions to show
    SectionVersion selectedSectionVersion = SectionVersion.defaultInstance;
    List<SectionVersion> sectionVersions = [];
    int selectedWeight = 0;

    for (final SectionEnum sectionEnum in SectionEnum.values) {
      Section section = Section.get(sectionEnum);
      SectionVersion? sectionVersion;

      //  find a version that is not currently in the song
      for (int i = 0; i <= 9; i++) {
        sectionVersion = SectionVersion(section, i);
        if (song.findChordSectionBySectionVersion(sectionVersion) == null) {
          break;
        } else {
          sectionVersion = null;
        }
      }
      if (sectionVersion == null) {
        continue;
      }
      logger.v('sectionVersion: $sectionVersion');

      if (selectedWeight < sectionVersion.weight) {
        selectedWeight = sectionVersion.weight;
        selectedSectionVersion = sectionVersion;
        logger.v('selectedSectionVersion: $selectedSectionVersion');
      }
      sectionVersions.add(sectionVersion);
    }

    //  generate the widgets
    List<DropdownMenuItem<SectionVersion>> ret = [];
    for (final SectionVersion sectionVersion in sectionVersions) {
      var sectionChordTextStyle = chordTextStyle.copyWith(
          backgroundColor: getBackgroundColorForSectionVersion(sectionVersion),
          color: getForegroundColorForSection(sectionVersion.section));

      //fixme: deal with selectedSectionVersion;
      DropdownMenuItem<SectionVersion> dropdownMenuItem = DropdownMenuItem<SectionVersion>(
        value: sectionVersion,
        child: Container(
          color: getBackgroundColorForSectionVersion(sectionVersion),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sectionVersion.toString(),
                style: sectionChordTextStyle,
              ),
              Text(
                '${sectionVersion.section.formalName} '
                '${sectionVersion.version == 0 ? '' : sectionVersion.version.toString()}',
                style: sectionChordTextStyle,
              ),
            ],
          ),
        ),
      );

      ret.add(dropdownMenuItem);
    }

    return DropdownButton<SectionVersion>(
      hint: Text('Other section version', style: chordTextStyle),
      value: selectedSectionVersion,
      items: ret,
      onChanged: (value) {
        setState(() {
          if (value != null) {
            sectionVersion = value;
            editTextController.text = sectionVersion.toString();
          }
        });
      },
      style: generateAppTextStyle(
        color: getBackgroundColorForSectionVersion(selectedSectionVersion),
        textBaseline: TextBaseline.alphabetic,
      ),
      itemHeight: null,
    );
  }

  /// validate the given measure entry string
  List<MeasureNode> validateMeasureEntry(String entry) {
    List<MeasureNode> entries = song.parseChordEntry(SongBase.entryToUppercase(entry));
    measureEntryValid = entries.isNotEmpty;
    for (var measureNode in entries) {
      measureEntryValid = measureEntryValid && measureNode is! MeasureComment;
    }
    measureEntryNodes = measureEntryValid ? entries : null;
    logger.d('_measureEntryValid: $measureEntryValid');
    return entries;
  }

  String formatMeasureNodes(List<MeasureNode> nodes) {
    StringBuffer sb = StringBuffer();
    for (var node in nodes) {
      sb.writeln(node.toEntry());
    }
    return sb.toString();
  }

  SectionVersion? parsedSectionEntry(String? entry) {
    if (entry == null || entry.length < 2) return null;
    try {
      return SectionVersion.parseString(entry);
    } catch (exception) {
      return null;
    }
  }

  ///  speed entry enhancement and validate the entry
  void preProcessMeasureEntry(final String entry) {
    if (entry.isEmpty) {
      measureEntryCorrection = null;
      measureEntryValid = false;
      return;
    }

    //  construct a properly capitalized version of the entry
    String upperEntry = MeasureNode.concatMarkup(validateMeasureEntry(entry));
    upperEntry = upperEntry.trim();
    String minEntry =
        entry.trim().replaceAll("\t", " ").replaceAll(":\n", ":").replaceAll("  ", " ").replaceAll("\n", ",");
    logger.log(_editLog, 'entry: "$minEntry" vs "$upperEntry"');

    //  suggest the corrected input if different
    if (upperEntry == minEntry) {
      if (measureEntryCorrection != null) {
        setState(() {
          measureEntryCorrection = null;
        });
      }
    } else {
      setState(() {
        measureEntryCorrection = upperEntry;
      });
    }
  }

  void undo() {
    setState(() {
      checkSong();
      if (undoStack.canUndo) {
        app.clearMessage();
        clearMeasureEntry();
        undoStackLog('pre undo');
        loadSong(undoStack.undo()?.copySong() ?? Song.createEmptySong());
        undoStackLog('post undo');
        checkSongChangeStatus();
      } else {
        app.errorMessage('cannot undo any more');
      }
    });
  }

  void redo() {
    checkSong();
    setState(() {
      if (undoStack.canRedo) {
        app.clearMessage();
        clearMeasureEntry();
        loadSong(undoStack.redo()?.copySong() ?? Song.createEmptySong());
        undoStackLog('redo');
        checkSongChangeStatus();
      } else {
        app.errorMessage('cannot redo any more');
      }
    });
  }

  ///  don't push an identical copy 1234
  void undoStackPushIfDifferent() {
    if (!(song.songBaseSameContent(undoStack.top))) {
      //  fixme: what was this doing?:  song.lastModifiedTime = originalSong.lastModifiedTime;
      undoStackPush();
      logger.d('undo ${undoStackAllToString()}');
    }
  }

  /// push a copy of the current song onto the undo stack
  void undoStackPush() {
    undoStack.push(song.copySong());
  }

  void undoStackLog(String comment) {
    logger.d('undo $comment: ${undoStackAllToString()}');
  }

  void performEdit({bool done = false, bool endOfRow = false}) {
    setState(() {
      //  commit to the edit
      song = chordSong;
      logger.log(
          _editLog,
          'pre  _performEdit(): done: $done, endOfRow: $endOfRow, selected: $selectedEditPoint'
          ', entry: $measureEntryNodes'
          ', song: ${song.toMarkup()}');
      edit(done: done, endOfRow: endOfRow);
      logger.log(
          _editLog,
          'post _performEdit(): done: $done, endOfRow: $endOfRow, selected: $selectedEditPoint'
          ', entry: $measureEntryNodes'
          ', song: ${song.toMarkup()}');
    });
  }

  /// perform the actual edit to the song
  bool edit({bool done = false, bool endOfRow = false}) {
    if (!measureEntryValid) {
      return false;
    }

    if (selectedEditPoint == null) {
      return false;
    }

    //  setup song for edit
    song.setCurrentChordSectionLocation(selectedEditPoint?.location);
    song.setCurrentMeasureEditType(selectedEditPoint?.measureEditType ?? MeasureEditType.append);

    editLogPre(song, endOfRow);

    //  setup for prior end of row after the edit
    ChordSectionLocation? priorLocation = song.getCurrentChordSectionLocation();

    //  do the edit
    if (song.editList(measureEntryNodes!)) {
      editLogPost(song, endOfRow);

      //  clean up after edit
      ChordSectionLocation? loc = song.getCurrentChordSectionLocation();
      switch (selectedEditPoint!.measureEditType) {
        case MeasureEditType.append:
          if (priorLocation != null && priorLocation.hasMeasureIndex) {
            song.setChordSectionLocationMeasureEndOfRow(priorLocation, selectedEditPoint?.onEndOfRow);
          }
          song.setChordSectionLocationMeasureEndOfRow(loc, endOfRow);
          break;
        case MeasureEditType.replace:
          song.setChordSectionLocationMeasureEndOfRow(loc, endOfRow);
          break;
        case MeasureEditType.insert:
          song.setChordSectionLocationMeasureEndOfRow(loc, endOfRow);
          break;
        case MeasureEditType.delete:
          break;
      }

      //  don't push an identical copy
      undoStackPushIfDifferent();

      clearMeasureEntry();

      if (done) {
        selectedEditPoint = null;
      } else {
        ChordSectionLocation? loc = song.getCurrentChordSectionLocation();
        if (loc != null) {
          selectedEditPoint = EditPoint(loc, onEndOfRow: endOfRow);
          selectedEditPoint!.measureEditType = MeasureEditType.append;
        }
      }

      checkSongChangeStatus();

      return true;
    } else {
      logger.log(_editLog, '_editMeasure(): failed');
      app.errorMessage('edit failed: ${song.message}');
    }

    return false;
  }

  void editLogPre(Song logSong, bool endOfRow) {
    if (_editDebug) {
      //  output to match the TestSong() tests from the library. i.e. bsteeleMusicLib
      logger.i('//  from ${Util.utcNow()}');
      logger.i('ts.startingChords(\'${logSong.toMarkup()}\');');
      logger.i('ts.edit(${logSong.currentMeasureEditType}, \'${logSong.currentChordSectionLocation}\''
          ', \'${logSong.getCurrentMeasureNode()?.toMarkup()}\'' //  measure string
          ', SongBase.entryToUppercase(\'${measureEntryNodes?.toString()}\')'
          ');'
          ' // endOfRow: $endOfRow');
    }
  }

  void editLogPost(Song logSong, bool endOfRow) {
    if (_editDebug) {
      //  output to match the TestSong() tests from the library. i.e. bsteeleMusicLib
      logger.i('ts.resultChords(\'${logSong.toMarkup()}\');');
      logger.i('ts.post(${logSong.currentMeasureEditType},\'${logSong.getCurrentChordSectionLocation()}\''
          ',\'${logSong.getCurrentMeasureNode()?.toMarkup()}\' );'
          ' // endOfRow: $endOfRow');
    }
  }

  String undoStackAllToString() {
    StringBuffer sb = StringBuffer(undoStack);
    sb.writeln('');
    for (var i = undoStack.length - 1; i >= 0; i--) {
      var j = undoStack.length - 1 - i;
      sb.writeln('$i: ${undoStack.get(j)?.toMarkup()}');
    }
    return sb.toString();
  }

  ///  delete the current measure
  void performDelete() {
    setState(() {
      ChordSectionLocation? priorLocation = selectedEditPoint?.location.priorMeasureIndexLocation();
      song.setCurrentChordSectionLocation(selectedEditPoint?.location);
      bool? endOfRow = song.getCurrentChordSectionLocationMeasure()?.endOfRow; //  find the current end of row
      song.setCurrentMeasureEditType(MeasureEditType.delete);
      if (song.editList(measureEntryNodes!)) {
        //  apply the deleted end of row to the prior
        song.setChordSectionLocationMeasureEndOfRow(priorLocation, endOfRow);
        undoStackPush();
      }
      clearMeasureEntry();
    });
  }

  void setEditPoint(EditPoint editPoint) {
    setState(() {
      clearMeasureEntry();
      app.clearMessage();
      selectedEditPoint = editPoint;
      logger.log(_editEditPoint, 'setEditPoint(${editPoint.toString()})');
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

  /// returns true if the was a change of dirty status
  bool checkSongChangeStatus() {
    if (hasChangedFromOriginal) {
      song.resetLastModifiedDateToNow();
      checkSong();
      setState(() {});
      return true;
    }
    song.lastModifiedTime = originalSong.lastModifiedTime;
    checkSong();
    setState(() {});
    return false;
  }

  void checkSongWhenIdle() {
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
      // load pro input before checking song
      {
        //  perform both
        var chords = validateSongChords();
        var lyrics = validateSongLyrics();
        //  valid only if both are valid
        isValidSongChordsAndLyrics = chords && lyrics;
        isValidSong = isValidSongChordsAndLyrics;
      }

      if (isValidSong) {
        if (isProEditInput) {
          song.setChords(SongBase.entryToUppercase(proChordTextEditingController.text));
          song.rawLyrics = proLyricsTextEditingController.text;
        }
        song.checkSong(); //  throws exception on entry error
        song.resetLastModifiedDateToNow();
        undoStackPushIfDifferent();
        app.clearMessage();
      }
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
      sb.write('${s.formalName}: \'${s.abbreviation.toLowerCase()}\'');
      if (s.alternateAbbreviation != null) {
        sb.write(' or \'${s.alternateAbbreviation!.toLowerCase()}\'');
      }
    }
    return sb.toString();
  }

  /// helper function to generate tool tips
  Widget editTooltip({
    Key? key,
    required String message,
    required Widget child,
  }) {
    return AppTooltip(
      key: key,
      message: message,
      child: child,
    );
  }

  void import() async {
    List<NameValue> lyricStrings = await UtilWorkaround().textFilePickAndRead(context);
    for (var nameValue in lyricStrings) {
      updateRawLyrics(song.rawLyrics + nameValue.value);
    }
  }

  _navigateToDetail(BuildContext context) async {
    app.selectedSong = song;
    app.selectedMomentNumber = 0;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Detail()),
    );
  }

  ScreenInfo? screenInfo;
  Song song;
  late SongEditManager songEditManager;

  //  a song copy with the selected edit point activated.  Used to minimize the labor of display construction.
  late Song chordSong;
  Song originalSong;

  bool get hasChangedFromOriginal => !song.songBaseSameContent(originalSong); //  fixme: too fine a line

  bool isValidSong = false;
  bool isValidSongChordsAndLyrics = false;

  music_key.Key key = music_key.Key.getDefault();
  double appendFontSize = 14;
  double chordFontSize = 14;

  EditPoint? selectedEditPoint;
  bool hadSelectedEditPoint = false;

  int transpositionOffset = 0;

  bool isProEditInput = false;
  static const proMessage = 'Select pro input mode.\nThis requires that you know what you are doing,\n'
      'and will not get frustrated if you don\'t.';
  Timer? _idleTimer;
  bool measureEntryIsClear = true;
  String? measureEntryCorrection;
  bool measureEntryValid = false;

  List<MeasureNode>? measureEntryNodes;
  MeasureNode? displayMeasureEntryNode;

  TextStyle chordBoldTextStyle = generateAppTextStyle(fontWeight: FontWeight.bold);

  // TextStyle sectionChordBoldTextStyle = generateAppTextStyle(fontWeight: FontWeight.bold);
  TextStyle chordTextStyle = generateAppTextStyle();
  TextStyle lyricsTextStyle = generateAppTextStyle();
  TextStyle addRowRepeatTextStyle = generateAppTextStyle();

  EdgeInsets marginInsets = const EdgeInsets.all(4);
  EdgeInsets doubleMarginInsets = const EdgeInsets.all(8);
  static const EdgeInsets textPadding = EdgeInsets.all(6);
  static const EdgeInsets appendInsets = EdgeInsets.all(3);
  static const EdgeInsets appendPadding = EdgeInsets.all(3);

  TextField? editTextField;

  final TextEditingController titleTextEditingController = TextEditingController();
  final TextEditingController artistTextEditingController = TextEditingController();
  final TextEditingController coverArtistTextEditingController = TextEditingController();
  final TextEditingController copyrightTextEditingController = TextEditingController();
  final TextEditingController bpmTextEditingController = TextEditingController();
  final TextEditingController userTextEditingController = TextEditingController();
  TextEditingController proChordTextEditingController = TextEditingController();
  FocusNode proChordTextFieldFocusNode = FocusNode();
  TextEditingController proLyricsTextEditingController = TextEditingController();
  int proLyricsLastLineSelected = 0;
  FocusNode proLyricsTextFieldFocusNode = FocusNode();

  final TextEditingController editTextController = TextEditingController();
  FocusNode? editTextFieldFocusNode;
  TextSelection? lastEditTextSelection;

  List<TableRow> chordRows = [];
  List<Widget> chordRowChildren = [];
  int tableKeyId = 0;

  LyricsEntries lyricsEntries = LyricsEntries();

  bool showHints = false;

  SectionVersion sectionVersion = SectionVersion.defaultInstance;
  ScaleNote keyChordNote = music_key.Key.getDefault().getKeyScaleNote();

  final List<ChangeNotifier> disposeList = []; //  fixme: workaround to dispose the text controllers

  final UndoStack<Song> undoStack = UndoStack();

  final FocusManager focusManager = FocusManager.instance;
  final FocusNode focusNode = FocusNode();

  final AppOptions appOptions = AppOptions();
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
                                logger.log(_editLog, 'repeat at: ${editPoint.location}');
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
