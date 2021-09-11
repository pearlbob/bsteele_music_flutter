import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/songs/chordComponent.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:bsteeleMusicLib/songs/measureNode.dart';
import 'package:bsteeleMusicLib/songs/measureRepeat.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/sectionVersion.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songBase.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/songs/timeSignature.dart';
import 'package:bsteeleMusicLib/util/undoStack.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/lyricsEntries.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import 'detail.dart';

late Song _initialSong;

const double _defaultChordFontSize = 28;
const double _defaultFontSize = _defaultChordFontSize * 0.8;

TextStyle _titleTextStyle = generateAppTextStyle();
TextStyle _boldTextStyle = generateAppTextStyle();
TextStyle _textFieldStyle = generateAppTextStyle();
TextStyle _labelTextStyle = generateAppTextStyle();

const double _entryWidth = 18 * _defaultChordFontSize;

const Color _disabledColor = Color(0xFFE0E0E0);
final Section _defaultSection = Section.get(SectionEnum.chorus);
const _addColor = Color(0xFFC8E6C9); //var c = Colors.green[100];

List<DropdownMenuItem<TimeSignature>> _timeSignatureItems = [];

const Level _editLog = Level.debug;
const Level _editEntry = Level.debug;
const Level _editKeyboard = Level.debug;

///   screen to edit a song
class Edit extends StatefulWidget {
  Edit({Key? key, required initialSong}) : super(key: key) {
    _initialSong = initialSong;
  }

  @override
  _Edit createState() => _Edit();
}

class _Edit extends State<Edit> {
  _Edit()
      : _song = _initialSong.copySong(),
        _originalSong = _initialSong.copySong() {
    //  stuff the repeat Drop Down Menu List
    for (var i = 2; i <= 4; i++) {
      DropdownMenuItem<int> item = DropdownMenuItem(
          key: ValueKey('repeatX$i'), value: i, child: Text('x$i', style: appDropdownListItemTextStyle));
      _repeatDropDownMenuList.add(item);
    }

    //  _checkSongStatus();
    _undoStackPush();
  }

  @override
  initState() {
    super.initState();

    _editTextFieldFocusNode = FocusNode();
    _editTextFieldFocusNode?.addListener(() {
      logger.log(_editLog, 'focusNode.listener()');
    });

    _key = _song.key;
    _keyChordNote = _key.getKeyScaleNote(); //  initial value

    _editTextController.addListener(() {
      //  fixme: workaround for loss of focus when pressing an edit button
      TextSelection textSelection = _editTextController.selection;
      if (textSelection.baseOffset >= 0) {
        _lastEditTextSelection = textSelection.copyWith();
      }
      logger.d('_chordTextController.addListener(): "${_editTextController.text}",'
          ' ${_selectedEditDataPoint?.toString()}'
          ', baseOffset: ${textSelection.baseOffset}'
          ', extentOffset: ${textSelection.extentOffset}');

      _preProcessMeasureEntry(_editTextController.text);
      if (_measureEntryValid) {
        bool endOfRow = false;
        switch (_editTextController.text[_editTextController.text.length - 1]) {
          case ',':
            endOfRow = true;
            continue entry;
          entry:
          case ' ': //  space means move on to the next measure, horizontally
            _performEdit(endOfRow: endOfRow);

            break;
          case '\n':
            logger.log(_editLog, 'newline: should _editMeasure() called here?');
            break;
          //  look for TextField.onEditingComplete() for end of entry... but it happens too often!
        }
      }

      logger.d('chordTextController: "${_editTextController.text}"');
    });

    //  known text updates
    _titleTextEditingController.addListener(() {
      _song.title = _titleTextEditingController.text;
      logger.d('_titleTextEditingController.addListener: \'${_titleTextEditingController.text}\''
          ', ${_titleTextEditingController.selection}');
      _checkSongChangeStatus();
    });
    _artistTextEditingController.addListener(() {
      _song.artist = _artistTextEditingController.text;
      _checkSongChangeStatus();
    });
    _coverArtistTextEditingController.addListener(() {
      _song.coverArtist = _coverArtistTextEditingController.text;
      _checkSongChangeStatus();
    });
    _copyrightTextEditingController.addListener(() {
      _song.copyright = _copyrightTextEditingController.text;
      _checkSongChangeStatus();
    });
    _userTextEditingController.addListener(() {
      _song.user = _userTextEditingController.text;
      if (_userTextEditingController.text.isNotEmpty) {
        _appOptions.user = _userTextEditingController.text;
      }
      _song.user = _userTextEditingController.text;
      _checkSongChangeStatus();
      // user  will often be different  _checkSongStatus();
    });

    _bpmTextEditingController.addListener(() {
      try {
        var bpm = int.parse(_bpmTextEditingController.text);
        if (bpm < MusicConstants.minBpm || bpm > MusicConstants.maxBpm) {
          setState(() {
            _app.errorMessage('BPM needs to be a number '
                'from ${MusicConstants.minBpm} to ${MusicConstants.maxBpm}, not: \'$bpm\'');
          });
        } else {
          setState(() {
            _app.clearMessage();
            _song.beatsPerMinute = bpm;
            _checkSongChangeStatus();
          });
        }
      } catch (e) {
        setState(() {
          _app.errorMessage(
              'caught: BPM needs to be a number from ${MusicConstants.minBpm} to ${MusicConstants.maxBpm}');
        });
      }
    });

    //  generate time signature drop down items
    _timeSignatureItems.clear();
    for (final timeSignature in knownTimeSignatures) {
      _timeSignatureItems.add(DropdownMenuItem(value: timeSignature, child: Text(timeSignature.toString())));
    }
  }

  void _loadSong(Song song) {
    _song = song;

    _titleTextEditingController.text = _song.title;
    _artistTextEditingController.text = _song.artist;
    _coverArtistTextEditingController.text = _song.coverArtist;
    _copyrightTextEditingController.text = _song.copyright;
    _userTextEditingController.text = _appOptions.user;
    _bpmTextEditingController.text = _song.beatsPerMinute.toString();

    _lyricsEntries.removeListener(_lyricsEntriesListener);
    _lyricsEntries = _lyricsEntriesFromSong(_song);

    _checkSong();
    _checkSongChangeStatus();
  }

  void _enterSong() async {
    _app.addSong(_song);

    String fileName = _song.title + '.songlyrics'; //  fixme: cover artist?
    String contents = _song.toJsonAsFile();
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    setState(() {
      if (message.toLowerCase().contains('error')) {
        _app.errorMessage(message);
      } else {
        _app.infoMessage(message);
      }
    });

    _checkSongChangeStatus();
  }

  @override
  void dispose() {
    _editTextController.dispose();
    _editTextFieldFocusNode?.dispose();
    for (final focusNode in _disposeList) {
      focusNode.dispose();
    }
    _focusNode.dispose();
    super.dispose();
    logger.d('edit dispose()');
  }

  @override
  Widget build(BuildContext context) {
    appWidget.context = context; //	required on every build
    logger.d('edit build: "${_song.rawLyrics}"');
    logger.d('edit build: ');

    _appOptions = Provider.of<AppOptions>(context);

    //  adjust to screen size
    if (_screenInfo == null) {
      _screenInfo = ScreenInfo(context);
      final double _screenWidth = _screenInfo!.widthInLogicalPixels;

      _chordFontSize = _defaultChordFontSize * _screenWidth / 800;
      _chordFontSize = min(_defaultChordFontSize, max(12, _chordFontSize));
      _appendFontSize = _chordFontSize * 0.75;

      _chordBoldTextStyle = generateAppTextStyle(
        fontWeight: FontWeight.bold,
        fontSize: _chordFontSize,
      );
      _chordTextStyle = generateAppTextStyle(
        fontSize: _appendFontSize,
        color: Colors.black87,
      );
      _lyricsTextStyle = generateAppTextStyle(
        fontWeight: FontWeight.normal,
        fontSize: _chordFontSize,
        color: Colors.black87,
      );

      //  don't load the song until we know its font sizes
      _loadSong(_song);
    }

    //  generate edit text styles
    _titleTextStyle = generateAppTextStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold);
    _boldTextStyle = generateAppTextStyle(
      fontSize: _defaultFontSize,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );
    _textFieldStyle = generateAppTextFieldStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold);
    _labelTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, fontWeight: FontWeight.bold);

    //  build the chords display based on the song chord section grid
    Table? _chordTable;
    _tableKeyId = 0;
    int maxCols = 0;
    {
      logger.d('size: ' + MediaQuery.of(context).size.toString());

      //  build the table from the song chord section grid
      Grid<ChordSectionLocation> chordGrid = _song.getChordSectionLocationGrid();
      Grid<_EditDataPoint> editDataPoints = Grid();

      if (chordGrid.isNotEmpty) {
        List<TableRow> rows = [];
        List<Widget> children = [];

        //  compute transposition offset from base key
        _transpositionOffset = 0; //_key.getHalfStep() - _song.getKey().getHalfStep();

        //  compute the maximum number of columns to even out the table rows

        {
          for (int r = 0; r < chordGrid.getRowCount(); r++) {
            List<ChordSectionLocation?>? row = chordGrid.getRow(r);
            maxCols = max(maxCols, row?.length ?? 0);

            // //  test for no end of row
            // if (row != null && row.isNotEmpty) {
            //   for (int c = 0; c < row.length; c++) {
            //     ChordSectionLocation? loc = row[c];
            //     // ChordSectionLocation? loc = row.last;
            //     logger.log(_editLog,'   missing endOfRow: $loc');
            //
            //     MeasureNode? mn = _song.findMeasureNodeByGrid(GridCoordinate(r, c));
            //     logger.log(_editLog,'   ($r, $c): $loc: ${mn?.getMeasureNodeType()}  ${mn?.toS:q

            //     if (m != null //&& m.endOfRow != true
            //     ) {
            //       logger.log(_editLog,'   missing endOfRow: $loc: ${m.getMeasureNodeType()} $m');
            //     }
            //   }
            // }
          }
        }

        //  keep track of the section
        SectionVersion? lastSectionVersion;

        //  map the song chord section grid to a flutter table, one row at a time
        for (int r = 0; r < chordGrid.getRowCount(); r++) {
          List<ChordSectionLocation?>? row = chordGrid.getRow(r);
          if (row == null) {
            continue;
          }

          ChordSectionLocation? firstChordSectionLocation;
          //       String columnFiller;
          _marginInsets = EdgeInsets.all(_chordFontSize / 4);
          _doubleMarginInsets = EdgeInsets.all(_chordFontSize / 2);

          //  find the first col with data
          //  should normally be col 1 (i.e. the second col)
          //  use its section version for the row
          {
            for (final ChordSectionLocation? loc in row) {
              if (loc == null) {
                continue;
              } else {
                firstChordSectionLocation = loc;
                break;
              }
            }
            if (firstChordSectionLocation == null) continue;

            SectionVersion? sectionVersion = firstChordSectionLocation.sectionVersion;
            if (sectionVersion == null) {
              continue;
            }

            if (sectionVersion != lastSectionVersion) {
              //  add a plus for appending a new row to the section
              _addSectionVersionEndToTable(rows, lastSectionVersion, 2 * maxCols /*col+add markers*/);

              var sectionBackgroundColor = getBackgroundColorForSection(sectionVersion.section);
              _sectionChordBoldTextStyle = _chordBoldTextStyle.copyWith(backgroundColor: sectionBackgroundColor);

              //  add the section heading
              //           columnFiller = sectionVersion.toString();
              lastSectionVersion = sectionVersion;
            }
          }

          {
            //  for each column of the song grid, create the appropriate widget
            for (int c = 0; c < row.length; c++) {
              ChordSectionLocation? loc = row[c];
              logger.v('loc: ($r,$c): ${loc.toString()}, marker: ${loc?.marker.toString()}');

              //  main elements
              Widget w;
              _EditDataPoint editDataPoint = _EditDataPoint(loc);
              if (loc == null) {
                w = _nullEditGridDisplayWidget();
              } else if (loc.isSection) {
                w = _sectionEditGridDisplayWidget(editDataPoint);
              } else if (loc.isMeasure) {
                w = _measureEditGridDisplayWidget(editDataPoint);
              } else if (loc.isRepeat) {
                w = _repeatEditGridDisplayWidget(editDataPoint);
              } else if (loc.isMarker) {
                w = _markerEditGridDisplayWidget(editDataPoint);
              } else {
                w = _nullEditGridDisplayWidget();
              }
              children.add(w);
              editDataPoints.set(r, c * 2, editDataPoint);

              //  + elements
              editDataPoint = _EditDataPoint(loc);
              editDataPoint._measureEditType = MeasureEditType.append; //  default
              if (loc == null) {
                if (c == 0 && row.length > 1) {
                  //  insert in front of first measure of the row
                  editDataPoint._measureEditType = MeasureEditType.insert;
                  editDataPoint.location = row[1];
                  w = _plusMeasureEditGridDisplayWidget(editDataPoint);
                } else {
                  w = _nullEditGridDisplayWidget();
                }
              } else if (loc.isSection) {
                if (c == 0) {
                  if (row.length > 1) {
                    //  insert in front of first measure of the section
                    editDataPoint._measureEditType = MeasureEditType.insert;
                    editDataPoint.location = row[1];
                    w = _plusMeasureEditGridDisplayWidget(editDataPoint);
                  } else {
                    //  append to an empty section
                    editDataPoint._measureEditType = MeasureEditType.append;
                    editDataPoint.location = loc;
                    w = _plusMeasureEditGridDisplayWidget(editDataPoint);
                  }
                } else {
                  w = _nullEditGridDisplayWidget();
                }
              } else if (loc.isMeasure) {
                w = _plusMeasureEditGridDisplayWidget(editDataPoint);
              } else {
                w = _nullEditGridDisplayWidget();
              }
              children.add(w);
              editDataPoints.set(r, c * 2 + 1, editDataPoint);
            }

            //  add children to max columns to keep the table class happy
            while (children.length < 2 * maxCols) {
              children.add(Container());
            }

            //  add row to table
            rows.add(TableRow(key: ValueKey('table${_tableKeyId++}'), children: children));

            //  get ready for the next row by clearing the row data
            children = [];
          }
        }

        //  end for last section
        _addSectionVersionEndToTable(rows, lastSectionVersion, 2 * maxCols);

        //  add the append for a new section
        {
          Widget child;
          if (_selectedEditDataPoint?.isSection ?? false) {
            child = _sectionEditGridDisplayWidget(_selectedEditDataPoint!);
          } else {
            child = Container(
                margin: _marginInsets,
                padding: _textPadding,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _addColor,
                ),
                child: _editTooltip(
                    'add new chord section here',
                    InkWell(
                      onTap: () {
                        setState(() {
                          _song.setCurrentChordSectionLocation(null);
                          _song.setCurrentMeasureEditType(MeasureEditType.append);
                          ChordSection cs = _suggestNewSection();
                          _selectedEditDataPoint = _EditDataPoint.byMeasureNode(_song, cs);
                          logger.d('${_song.toMarkup()} + $_selectedEditDataPoint');
                        });
                      },
                      child: Icon(
                        Icons.add,
                        size: _chordFontSize,
                      ),
                    ),
                    key: const ValueKey('newChordSection')));
          }
          children.add(child);

          //  add children to max columns to keep the table class happy
          while (children.length < 2 * maxCols) {
            children.add(Container());
          }

          //  add row to table
          rows.add(TableRow(key: ValueKey('table${_tableKeyId++}'), children: children));
        }

        _chordTable = Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: rows,
        );

        logger.v(editDataPoints.toMultiLineString());
      }
    }

    List<DropdownMenuItem<music_key.Key>> keySelectDropdownMenuItems = [];
    {
      keySelectDropdownMenuItems.addAll(music_key.Key.values.toList().reversed.map((music_key.Key value) {
        return DropdownMenuItem<music_key.Key>(
          key: ValueKey('key_' + value.toMarkup()),
          value: value,
          child: Text(
            '${value.toMarkup().padRight(3)} ${value.sharpsFlatsToMarkup()}',
            style: _boldTextStyle,
          ),
          onTap: () {
            logger.log(_editLog, 'item onTap: ${value.runtimeType} $value');
            if (_song.key != value) {
              setState(() {
                _song.key = value;
                _key = value;
                _keyChordNote = _key.getKeyScaleNote();
              }); //  display the return to original
            }
          },
        );
      }));
    }

    bool songHasChanged = hasChangedFromOriginal || _lyricsEntries.hasChangedLines();
    var theme = Theme.of(context);

    return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body:
            //  deal with keyboard strokes flutter is not usually handling
            //  note that return (i.e. enter) is not a keyboard event!
            RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: _editOnKey,
          child: GestureDetector(
            // fixme: put GestureDetector only on chord table
            child: SingleChildScrollView(
              key: const ValueKey('singleChildScrollView'),
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  //  note: let the app bar scroll off the screen for more room for the song
                  appWidget.appBar(
                    title: 'Edit',
                    leading: appWidget.back(),
                  ),
                  appSpace(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      textDirection: TextDirection.ltr,
                      children: <Widget>[
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              appButton(
                                songHasChanged ? (_isValidSong ? 'Enter song' : 'Fix the song') : 'Nothing has changed',
                                backgroundColor: (songHasChanged && _isValidSong ? null : _disabledColor),
                                onPressed: () {
                                  if (songHasChanged && _isValidSong) {
                                    _enterSong();
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                              _app.messageTextWidget(),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    appButton(
                                      'Sheet music',
                                      key: const ValueKey('screenDetail'),
                                      onPressed: () {
                                        setState(() {
                                          _navigateToDetail(context);
                                        });
                                      },
                                    ),
                                    appSpace(
                                      space: 50,
                                    ),
                                    appTooltip(
                                      message: 'Clear all song values to\n'
                                          'start entering a new song.',
                                      child: appButton(
                                        'Clear',
                                        onPressed: () {
                                          setState(() {
                                            _song = Song.createEmptySong();
                                            _loadSong(_song);
                                            _undoStackPushIfDifferent();
                                          });
                                        },
                                      ),
                                    ),
                                    appSpace(),
                                    // appButton(
                                    //   'Remove',
                                    //   onPressed: () {
                                    //     logger.log(_editLog, 'fixme: Remove song'); // fixme
                                    //   },
                                    // ),
                                    // TextButton.icon(
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
                                    // TextButton.icon(
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
                                child: TextField(
                                  key: const ValueKey('title'),
                                  controller: _titleTextEditingController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter the song title.',
                                  ),
                                  maxLength: null,
                                  style: generateAppTextFieldStyle(
                                      fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold),
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
                                child: TextField(
                                  key: const ValueKey('artist'),
                                  controller: _artistTextEditingController,
                                  decoration: const InputDecoration(hintText: 'Enter the song\'s artist.'),
                                  maxLength: null,
                                  style: _textFieldStyle,
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
                                child: TextField(
                                  key: const ValueKey('coverArtist'),
                                  controller: _coverArtistTextEditingController,
                                  decoration: const InputDecoration(hintText: 'Enter the song\'s cover artist.'),
                                  maxLength: null,
                                  style: _textFieldStyle,
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
                                child: TextField(
                                  key: const ValueKey('copyright'),
                                  controller: _copyrightTextEditingController,
                                  decoration: const InputDecoration(hintText: 'Enter the song\'s copyright. Required.'),
                                  maxLength: null,
                                  style: _textFieldStyle,
                                ),
                              ),
                            ]),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Text(
                                "Key: ",
                                style: _labelTextStyle,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: DropdownButton<music_key.Key>(
                                key: const ValueKey('editKeyDropdown'),
                                items: keySelectDropdownMenuItems,
                                onChanged: (_value) {
                                  logger.log(_editLog, 'DropdownButton onChanged: $_value');
                                },
                                value: _key,
                                style: generateAppTextStyle(
                                  textBaseline: TextBaseline.ideographic,
                                ),
                                itemHeight: null,
                              ),
                            ),
                            SizedBox.shrink(
                              key: ValueKey('keyTally_' + _key.toMarkup()),
                            ), //  tally for testing only
                            Container(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Text(
                                "   BPM: ",
                                style: _labelTextStyle,
                              ),
                            ),
                            SizedBox(
                              width: 3 * _defaultFontSize,
                              child: TextField(
                                controller: _bpmTextEditingController,
                                decoration: const InputDecoration(hintText: 'Enter the song\'s beats per minute.'),
                                maxLength: null,
                                style: _textFieldStyle,
                                onEditingComplete: () {
                                  logger.log(_editLog, 'bpm: onEditingComplete: ${_bpmTextEditingController.text}');
                                },
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: Text(
                                "Time: ",
                                style: _labelTextStyle,
                              ),
                            ),
                            DropdownButton<TimeSignature>(
                              items: _timeSignatureItems,
                              onChanged: (_value) {
                                if (_value != null && _song.timeSignature != _value) {
                                  _song.timeSignature = _value;
                                  if (!_checkSongChangeStatus()) {
                                    setState(() {}); //  display the return to original
                                  }
                                }
                              },
                              value: _song.timeSignature,
                              style: generateAppTextStyle(
                                  textBaseline: TextBaseline.alphabetic,
                                  fontSize: _defaultFontSize,
                                  fontWeight: FontWeight.bold),
                              itemHeight: null,
                            ),

                            Container(
                              padding: const EdgeInsets.only(left: 24, bottom: 24.0),
                              child: Text(
                                "User: ",
                                style: _labelTextStyle,
                              ),
                            ),
                            SizedBox(
                              width: 300.0,
                              child: TextField(
                                controller: _userTextEditingController,
                                decoration: const InputDecoration(hintText: 'Enter your user name.'),
                                maxLength: null,
                                style: _textFieldStyle,
                              ),
                            ),
                            appSpace(),
                            if (_originalSong.user != _userTextEditingController.text)
                              Text(
                                '(was ${_originalSong.user})',
                                style: _labelTextStyle,
                              ),
                          ],
                        ),
                        Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Flexible(
                                flex: 1,
                                child: Text(
                                  "Chords:",
                                  style: _titleTextStyle,
                                ),
                              ),
                              Flexible(
                                flex: 1,
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  _editTooltip(
                                    _undoStack.canUndo ? 'Undo the last edit' : 'There is nothing to undo',
                                    appButton(
                                      'Undo',
                                      onPressed: () {
                                        _undo();
                                      },
                                    ),
                                  ),
                                  _editTooltip(
                                    _undoStack.canUndo ? 'Reo the last edit undone' : 'There is no edit to redo',
                                    appButton(
                                      'Redo',
                                      onPressed: () {
                                        _redo();
                                      },
                                    ),
                                  ),
                                  _editTooltip(
                                    (_selectedEditDataPoint != null
                                            ? 'Click outside the chords to cancel editing\n'
                                            : '') +
                                        (_showHints
                                            ? 'Click to hide the editing hints'
                                            : 'Click for hints about editing.'),
                                    appButton('Hints', onPressed: () {
                                      setState(() {
                                        _showHints = !_showHints;
                                      });
                                    }),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                          margin: const EdgeInsets.all(4),
                        ),
                        const Divider(
                          thickness: 8,
                          //color: ,  fixme: should be from css!!!
                        ),
                        if (_chordTable != null)
                          Container(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                              //  pre-configured table of edit widgets
                              _chordTable,
                            ]),
                            padding: const EdgeInsets.all(16.0),
                            color: theme.backgroundColor,
                          ),
                        if (_showHints)
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
                                  text: '\n\n'
                                          'The sections are: ' +
                                      _listSections(),
                                  style: appTextStyle,
                                ),
                                TextSpan(
                                  text: '\n'
                                      'Their abbreviations are: ',
                                  style: appTextStyle,
                                ),
                                TextSpan(
                                  text: _listSectionAbbreviations(),
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
                                  text:
                                      '''Using a lower case b for a flat will work. A sharp sign (#) works as a sharp.\n\n''',
                                  style: appTextStyle,
                                ),
                                TextSpan(
                                  text:
                                      //  todo: fix the font, ♭ is not represented properly
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
                                  text:
                                      'Forward slashes (/) can be used to indicate bass notes that differ from the chord.'
                                      ' For example A/G would mean a G for the bass, an A chord for the other instruments.'
                                      ' The bass note is a single note, not a chord.\n\n',
                                  style: appTextStyle,
                                ),
                                TextSpan(
                                  text:
                                      'Periods (.) can be used to repeat chords on another beat within the same measure. For'
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
                                  text:
                                      'Commas (,) between measures can be used to indicate the end of a row of measures.'
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
                                  text:
                                      'Control plus the arrow keys can help navigate in the chord entry once selected.\n\n',
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
                        Container(
                          margin: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                "Lyrics:",
                                style: _titleTextStyle,
                              ),
                              Flexible(
                                flex: 1,
                                child: _editTooltip(
                                  'Import lyrics from a text file',
                                  appButton(
                                    'Import',
                                    onPressed: () {
                                      _import();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          thickness: 8,
                        ),
                        Container(
                          child: _lyricsEntryWidget(),
                          padding: const EdgeInsets.all(16.0),
                          color: theme.backgroundColor,
                        ),
                        // Container(
                        //   padding: EdgeInsets.all(16.0),
                        //   child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        //     //  pre-configured table of edit widgets
                        //     _lyricsTable.lyricsTable(
                        //       _song,
                        //       sectionHeaderWidget: _editSectionHeaderWidget,
                        //       textWidget: _editLyricsTextWidget,
                        //       lyricEndWidget: _lyricEndWidget,
                        //       requestedFontSize: _chordFontSize,
                        //     ),
                        //   ]),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            onTap: () {
              _performMeasureEntryCancel();
            },
          ),
        ));
  }

  /// generates the lyrics entry widget
  Widget _lyricsEntryWidget() {
    List<TableRow> rows = [];

    //  find the longest chord row
    var chordMaxColCount = _song.getChordSectionLocationGridMaxColCount();
    logger.v('chordMaxColCount: $chordMaxColCount');
    chordMaxColCount = _song.chordRowMaxLength();

    //  generate the section pull down data if required
    List<DropdownMenuItem<ChordSection>> sectionItems =
        SplayTreeSet<ChordSection>.from(_song.getChordSections()).map((chordSection) {
      return DropdownMenuItem(
        value: chordSection,
        child: Text(
          '${chordSection.sectionVersion}',
          style: generateAppTextStyle(
              fontSize: _chordFontSize,
              fontWeight: FontWeight.bold,
              backgroundColor: getBackgroundColorForSection(chordSection.sectionVersion.section)),
        ),
      );
    }).toList();

    //  main entries
    var addSection = 0;
    logger.log(_editLog, '_lyricsEntries: ${_lyricsEntries.entries.length}');
    for (final entry in _lyricsEntries.entries) {
      //  insert new section above
      {
        var children = <Widget>[];
        children.add(Row(
          children: [
            _editTooltip(
              'Add new lyrics section here',
              DropdownButton<ChordSection>(
                key: ValueKey('addLyricsSection${addSection++}'),
                hint: Container(
                  margin: _marginInsets,
                  padding: _textPadding,
                  decoration: const BoxDecoration(
                    // shape: BoxShape.circle,
                    color: _addColor,
                  ),
                  child: Icon(
                    Icons.add,
                    size: _chordFontSize,
                  ),
                ),
                items: sectionItems,
                onChanged: (value) {
                  if (value != null) {
                    logger.log(_editLog, 'addChordSection(${entry.lyricSection.index}, ${value.sectionVersion});');
                    _lyricsEntries.insertChordSection(entry, value);
                    _pushLyricsEntries();
                  }
                },
                itemHeight: null,
              ),
            ),
          ],
        ));
        for (var c = 0; c < chordMaxColCount - 1 + 1; c++) {
          children.add(const Text(''));
        }
        rows.add(TableRow(children: children));
      }

      //  chord section headers
      var chordSection = _song.getChordSection(entry.lyricSection.sectionVersion);
      var sectionBackgroundColor = getBackgroundColorForSection(chordSection?.sectionVersion.section);
      _sectionChordBoldTextStyle = _chordBoldTextStyle.copyWith(backgroundColor: sectionBackgroundColor);
      {
        var children = <Widget>[];
        children.add(Container(
          margin: _marginInsets,
          padding: _textPadding,
          color: sectionBackgroundColor,
          child: Text(
            entry.lyricSection.sectionVersion.toString(),
            style: _sectionChordBoldTextStyle,
          ),
        ));

        for (var c = 0; c < chordMaxColCount - 1; c++) {
          children.add(const Text(''));
        }
        children.add(_editTooltip(
          'Delete this lyric section',
          InkWell(
            child: const Icon(
              Icons.delete,
              size: _defaultChordFontSize,
              color: Colors.black,
            ),
            onTap: () {
              _lyricsEntries.delete(entry);
              _pushLyricsEntries();
            },
          ),
        ));

        rows.add(TableRow(children: children));
      }

      //  chord rows and lyrics lines
      final expanded = !_appOptions.compressRepeats;
      var chordRowCount = chordSection?.rowCount(expanded: expanded) ?? 0;
      var lineCount = entry.length;
      var limit = max(chordRowCount, lineCount);
      logger.log(_editLog, '$chordSection: chord/lyrics limit: $limit = max($chordRowCount,$lineCount)');
      for (var i = 0; i < limit; i++) {
        var children = <Widget>[];

        //  chord rows
        {
          var c = 0;
          if (i < chordRowCount) {
            var row = chordSection?.rowAt(i, expanded: expanded);
            logger.d('row.length: ${row?.length}/$chordMaxColCount');
            for (final Measure measure in row ?? []) {
              children.add(Container(
                margin: _marginInsets,
                padding: _textPadding,
                color: sectionBackgroundColor,
                child: Text(
                  measure.transpose(_key, 0),
                  style: _sectionChordBoldTextStyle,
                  maxLines: 1,
                ),
              ));
              c++;
            }
          }
          for (; c < chordMaxColCount; c++) {
            children.add(const Text(''));
          }
        }

        if (i < lineCount) {
          var lyricsTextField = entry.textFieldAt(i);

          children.add(Row(
            children: [
              InkWell(
                child: Container(
                    margin: appendInsets,
                    padding: _textPadding,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _addColor,
                    ),
                    child: _editTooltip(
                      'move the lyric line upwards a section',
                      Icon(
                        Icons.arrow_upward,
                        size: _chordFontSize,
                      ),
                    )),
                onTap: () {
                  _lyricsEntries.moveLyricLine(entry.lyricSection, i, isUp: true);
                  _pushLyricsEntries();
                },
              ),
              InkWell(
                child: Container(
                    margin: appendInsets,
                    padding: _textPadding,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _addColor,
                    ),
                    child: _editTooltip(
                      'move the lyric line downwards a section',
                      Icon(
                        Icons.arrow_downward,
                        size: _chordFontSize,
                      ),
                    )),
                onTap: () {
                  _lyricsEntries.moveLyricLine(entry.lyricSection, i, isUp: false);
                  _pushLyricsEntries();
                },
              ),
              const Spacer(),
              Expanded(
                child: lyricsTextField,
                flex: 30,
              ),
              const Spacer(),
              _editTooltip(
                'Delete this lyric line',
                InkWell(
                  child: const Icon(
                    Icons.delete,
                    size: _defaultChordFontSize,
                    color: Colors.black,
                  ),
                  onTap: () {
                    _lyricsEntries.deleteLyricLine(
                      entry,
                      i,
                    );
                    _pushLyricsEntries();
                  },
                ),
              ),
            ],
          ));
        } else if (i == 0 && lineCount == 0) {
          children.add(
            Row(
              children: [
                InkWell(
                  child: Container(
                      margin: appendInsets,
                      padding: _textPadding,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _addColor,
                      ),
                      child: _editTooltip(
                        'add a lyric line here',
                        Icon(
                          Icons.add,
                          size: _chordFontSize,
                        ),
                      )),
                  onTap: () {
                    _lyricsEntries.addBlankLyricsLine(entry);
                    logger.log(_editLog, 'addBlankLyricsLine: $entry');
                    _pushLyricsEntries();
                  },
                ),
              ],
            ),
          );
        } else {
          children.add(const Text(''));
        }
        rows.add(TableRow(children: children));
      }
    }

    //  last append goes here
    {
      var children = <Widget>[];
      children.add(
        _editTooltip(
          _song.getChordSections().isEmpty
              ? 'No lyric section to add!  Add at least one chord section above.'
              : 'Add new lyric section here at the end',
          DropdownButton<ChordSection>(
            hint: Container(
              margin: _marginInsets,
              padding: _textPadding,
              decoration: const BoxDecoration(
                // shape: BoxShape.circle,
                color: _addColor,
              ),
              child: Icon(
                Icons.add,
                size: _chordFontSize,
              ),
            ),
            items: sectionItems,
            onChanged: (value) {
              if (value != null) {
                _lyricsEntries.addChordSection(value);
                _pushLyricsEntries();
              }
            },
            itemHeight: null,
          ),
        ),
      );

      for (var c = 0; c < chordMaxColCount; c++) {
        children.add(const Text(''));
      }
      rows.add(TableRow(children: children));
    }

    //  compute the flex for the columns
    var columnWidths = <int, TableColumnWidth>{};
    for (var i = 0; i < chordMaxColCount; i++) {
      columnWidths[i] = const IntrinsicColumnWidth();
    }
    columnWidths[chordMaxColCount] = const FlexColumnWidth(3);

    return Table(
      children: rows,
      defaultColumnWidth: const IntrinsicColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: columnWidths,
      // border: TableBorder(
      // top: BorderSide(width: 2),
      // bottom: BorderSide(width: 2),
      // left: BorderSide(width: 2),
      // right: BorderSide(width: 2),
      // horizontalInside: BorderSide(width: 1),
      // verticalInside: BorderSide(width: 1)),
    );
  }

  /// convenience method to push lyrics changes to the song and the display
  void _pushLyricsEntries() {
    logger.log(
        _editEntry,
        '_pushLyricsEntries(): _lyricsEntries.asRawLyrics():'
        ' <${_lyricsEntries.asRawLyrics().replaceAll('\n', '\\n')}>');
    _updateRawLyrics(_lyricsEntries.asRawLyrics());
    logger.log(_editEntry, '_pushLyricsEntries: rawLyrics: ${_song.rawLyrics.replaceAll('\n', '\\n')}');
  }

  void _updateRawLyrics(String rawLyrics) {
    _song.rawLyrics = rawLyrics;
    _lyricsEntries.updateEntriesFromSong();
    _undoStackPushIfDifferent();
    _checkSongChangeStatus();
  }

  LyricsEntries _lyricsEntriesFromSong(Song song) {
    LyricsEntries ret = LyricsEntries.fromSong(song,
        onLyricsLineChangedCallback: _onLyricsLineChangedCallback, textStyle: _lyricsTextStyle);
    ret.addListener(_lyricsEntriesListener);
    return ret;
  }

  void _onLyricsLineChangedCallback() {
    logger.i('_onLyricsLineChangedCallback():  ${_lyricsEntries.hasChangedLines()}');
  }

  void _lyricsEntriesListener() {
    _pushLyricsEntries(); //  if low level edits were made by the widget tree
    _checkSongChangeStatus();
    logger.log(_editEntry, '_lyricsEntries: _checkSongChangeStatus()');
  }

  ///  add a row for a plus on the bottom of the section to continue on the next row
  void _addSectionVersionEndToTable(List<TableRow> rows, SectionVersion? sectionVersion, int maxCols) {
    if (sectionVersion == null) {
      return;
    }
    ChordSection? chordSection = _song.findChordSectionBySectionVersion(sectionVersion);
    ChordSectionLocation? loc = _song.findLastChordSectionLocation(chordSection);
    if (loc != null) {
      loc = ChordSectionLocation(loc.sectionVersion, phraseIndex: loc.phraseIndex);
      _EditDataPoint editDataPoint = _EditDataPoint(loc, onEndOfRow: true);
      editDataPoint._measureEditType = MeasureEditType.append;
      Widget w = _plusMeasureEditGridDisplayWidget(editDataPoint,
          tooltip: 'add new measure on a new row'
              '${kDebugMode ? ' loc: ${loc.toString()} ${describeEnum(editDataPoint._measureEditType)}' : ''}');
      List<Widget> children = [];
      children.add(_nullEditGridDisplayWidget());
      children.add(w);

      //  add children to max columns to keep the table class happy
      while (children.length < maxCols) {
        children.add(const Text(''));
      }

      //  add row to table
      rows.add(TableRow(key: ValueKey('table${_tableKeyId++}'), children: children));
    }
  }

  /// process the raw keys flutter doesn't want to
  /// this is largely done for the desktop... since phones and tablets usually don't have keyboards
  void _editOnKey(RawKeyEvent value) {
    //  fixme: edit screen does not respond to escape after the detail screen
    if (value.runtimeType == RawKeyDownEvent) {
      RawKeyDownEvent e = value as RawKeyDownEvent;
      logger.log(
          _editKeyboard,
          'edit onkey:'
          //' ${e.data.logicalKey}'
          //', primaryFocus: ${_focusManager.primaryFocus}'
          ', context: ${_focusManager.primaryFocus?.context}'
          // ', ctl: ${e.isControlPressed}'
          // ', shf: ${e.isShiftPressed}'
          // ', alt: ${e.isAltPressed}'
          //
          );
      if (e.isControlPressed) {
        logger.v('isControlPressed');
        if (e.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
          if (_selectedEditDataPoint != null && _measureEntryValid) {
            _performEdit(endOfRow: true);
          }
          logger.d('main onkey: found arrowDown');
        } else if (e.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
          if (_selectedEditDataPoint != null && _measureEntryValid) {
            _performEdit(endOfRow: false);
          }
        } else if (e.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
          logger.d('main onkey: found arrowUp');
        } else if (e.data.logicalKey == LogicalKeyboardKey.undo) {
          //  not that likely
          if (e.isShiftPressed) {
            _redo();
          } else {
            _undo();
          }
        } else if (e.data.logicalKey.keyLabel == LogicalKeyboardKey.keyZ.keyLabel.toUpperCase()) //fixme
        {
          _redo();
        } else if (e.data.logicalKey.keyLabel == LogicalKeyboardKey.keyZ.keyLabel.toLowerCase()) //fixme
        {
          _undo();
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
        /// clear editing with the escape key
        if (_measureEntryIsClear && !(hasChangedFromOriginal || _lyricsEntries.hasChangedLines())) {
          Navigator.pop(context);
        } else {
          _performMeasureEntryCancel();
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.enter) || e.isKeyPressed(LogicalKeyboardKey.numpadEnter)) {
        if (_selectedEditDataPoint != null) //  fixme: this is a poor workaround
        {
          _performEdit(done: false, endOfRow: true);
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
        int baseOffset = _editTextController.selection.extentOffset;
        if (baseOffset > 0) {
          _editTextController.selection = TextSelection(baseOffset: baseOffset - 1, extentOffset: baseOffset - 1);
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        int extentOffset = _editTextController.selection.extentOffset;

        //  cancel multi character selection
        if (_editTextController.selection.baseOffset < extentOffset) {
          _editTextController.selection = TextSelection(baseOffset: extentOffset, extentOffset: extentOffset);
        } else {
          //  move closer to the end
          if (extentOffset < _editTextController.text.length) {
            _editTextController.selection = TextSelection(baseOffset: extentOffset + 1, extentOffset: extentOffset + 1);
          }
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.delete)) {
        logger.d('main onkey: delete: "${_editTextController.text}", ${_editTextController.selection}');
        if (_editTextController.text.isEmpty) {
          if (_selectedEditDataPoint?._measureEditType == MeasureEditType.replace) {
            _performDelete();
          } else {
            _performMeasureEntryCancel();
          }
        } else if (_editTextController.selection.baseOffset < _editTextController.selection.extentOffset) {
          //  do the usual text edit thing    fixme: why is this not done by flutter?
          int loc = _editTextController.selection.baseOffset;

          //  selection in a range
          _editTextController.text = (_editTextController.selection.baseOffset > 0
                  ? _editTextController.text.substring(0, _editTextController.selection.baseOffset)
                  : '') +
              _editTextController.text.substring(_editTextController.selection.extentOffset);
          _editTextController.selection = TextSelection(baseOffset: loc, extentOffset: loc);
        } else if (_editTextController.selection.extentOffset < _editTextController.text.length - 1) {
          int loc = _editTextController.selection.extentOffset;
          _editTextController.text =
              _editTextController.text.substring(0, loc) + _editTextController.text.substring(loc + 1);
          _editTextController.selection = TextSelection(baseOffset: loc, extentOffset: loc);
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
      else if (e.isKeyPressed(LogicalKeyboardKey.space) && _selectedEditDataPoint != null) {
        logger.d('main onkey: space: "${_editTextController.text}", ${_editTextController.selection}');
        int extentOffset = _editTextController.selection.extentOffset;

        _editTextController.selection =
            TextSelection(baseOffset: 0, extentOffset: extentOffset); // fixme:!!!!!!!!!!!!!!!!!!!!
        _preProcessMeasureEntry(_editTextController.text);
        if (_measureEntryValid && _selectedEditDataPoint != null) {
          switch (_selectedEditDataPoint!._measureEditType) {
            case MeasureEditType.replace:
              _selectedEditDataPoint!._measureEditType = MeasureEditType.insert;
              break;
            default:
              break;
          }
          _performEdit();
        }
      } else {
        logger.d('main onkey: not processed: "${e.data.logicalKey}"');
      }
    }
    logger.d('main onkey: text:"${_editTextController.text}"'
        ', f:${_editTextFieldFocusNode?.hasFocus}'
        ', pf:${_editTextFieldFocusNode?.hasPrimaryFocus}');
  }

  Widget _nullEditGridDisplayWidget() {
    return const Text(
      '',
      //' null',  //  diagnostic
    );
  }

  Widget _sectionEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode? measureNode =
        _song.findMeasureNodeByLocation(editDataPoint.location) ?? editDataPoint.measureNode; //  for new sections
    if (measureNode == null) {
      return const Text('null');
    }

    if (measureNode.getMeasureNodeType() != MeasureNodeType.section) {
      return const Text('not_section');
    }

    ChordSection chordSection = measureNode as ChordSection;
    var sectionColor = getBackgroundColorForSection(chordSection.sectionVersion.section);
    var sectionChordTextStyle = _chordBoldTextStyle.copyWith(backgroundColor: sectionColor);

    if (_selectedEditDataPoint == editDataPoint) {
      //  we're editing the section
      if (_editTextField == null) {
        String entry = chordSection.sectionVersion.toString();
        _editTextController.text = entry;
        _editTextController.selection = TextSelection(baseOffset: 0, extentOffset: entry.length);
        _editTextField = TextField(
          controller: _editTextController,
          focusNode: _editTextFieldFocusNode,
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
          onSubmitted: (_) {
            logger.d('onSubmitted: ($_)');
          },
          onEditingComplete: () {
            logger.d('onEditingComplete()');
          },
        );
      }

      SectionVersion? entrySectionVersion = _parsedSectionEntry(_editTextController.text);
      bool isValidSectionEntry = (entrySectionVersion != null);

      //  build a list of section version numbers
      List<DropdownMenuItem<int>> sectionVersionNumberDropdownMenuList = [];
      for (int i = 0; i <= 9; i++) {
        sectionVersionNumberDropdownMenuList.add(
          DropdownMenuItem<int>(
            key: ValueKey('sectionVersionNumber' + i.toString()),
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
              Container(margin: _marginInsets, padding: _textPadding, color: sectionColor, child: _editTextField),
              //  section entry pull downs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  //  section selection
                  _sectionVersionDropdownButton(),

                  //  section version selection
                  DropdownButton<int>(
                    value: _sectionVersion.version,
                    items: sectionVersionNumberDropdownMenuList,
                    onChanged: (value) {
                      setState(() {
                        if (value != null) {
                          _sectionVersion = SectionVersion(_sectionVersion.section, value);
                          _editTextController.text = _sectionVersion.toString();
                        }
                      });
                      logger.v('_sectionVersion = ${_sectionVersion.toString()}');
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
                  _editTooltip(
                    'Delete this section',
                    InkWell(
                      child: const Icon(
                        Icons.delete,
                        size: _defaultChordFontSize,
                        color: Colors.black,
                      ),
                      onTap: () {
                        _performMeasureEntryCancel();
                      },
                    ),
                  ),
                  _editTooltip(
                    'Cancel the modification.',
                    InkWell(
                      child: Icon(
                        Icons.cancel,
                        size: _defaultChordFontSize,
                        color: _measureEntryValid ? Colors.black : Colors.red,
                      ),
                      onTap: () {
                        _performMeasureEntryCancel();
                      },
                    ),
                  ),
                  if (isValidSectionEntry)
                    _editTooltip(
                      'Accept the modification and add measures to the section.',
                      InkWell(
                        child: const Icon(
                          Icons.arrow_forward,
                          size: _defaultChordFontSize,
                        ),
                        onTap: () {
                          _performEdit(endOfRow: false);
                        },
                      ),
                    ),
                  //  section enter
                  if (isValidSectionEntry)
                    _editTooltip(
                      'Accept the modification',
                      InkWell(
                        child: const Icon(
                          Icons.check,
                          size: _defaultChordFontSize,
                        ),
                        onTap: () {
                          logger.d(
                              'sectionVersion measureEditType: ${_selectedEditDataPoint?._measureEditType.toString()}');
                          _performEdit(done: true); //  section enter
                        },
                      ),
                    ),
                  //  can't cancel some chordSection that has already been added!
                ],
              ),
            ]),
      );
    }

    var matchingVersions = _song.matchingSectionVersions(editDataPoint.location?.sectionVersion);
    var matchingVersionsString = '';
    for (final mv in matchingVersions) {
      matchingVersionsString += mv.toString();
    }

    //  the section is not selected for editing, just display
    return InkWell(
      onTap: () {
        _sectionVersion = chordSection.sectionVersion;
        _editTextController.text = _sectionVersion.toString();
        _setEditDataPoint(editDataPoint);
      },
      child: Container(
          margin: _marginInsets,
          padding: _textPadding,
          color: sectionColor,
          child: _editTooltip(
              'modify or delete the section',
              Text(
                matchingVersionsString,
                style: sectionChordTextStyle,
              ))),
    );
  }

// Measure _getLocationMeasure(ChordSectionLocation location) {
//   if (location == null) {
//     return null;
//   }
//   MeasureNode measureNode = _song.findMeasureNodeByLocation(location);
//   if (measureNode == null) {
//     return null;
//   }
//   if (measureNode.getMeasureNodeType() != MeasureNodeType.measure) {
//     return null;
//   }
//   return measureNode as Measure;
// }

  Widget _measureEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode? measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null) {
      return const Text('null');
    }
    Measure? measure;
    if (measureNode.getMeasureNodeType() == MeasureNodeType.measure) {
      measure = measureNode.transposeToKey(_key) as Measure;
    }

    Color sectionColor = getBackgroundColorForSection(editDataPoint.location?.sectionVersion?.section);
    var sectionChordBoldTextStyle = _chordBoldTextStyle.copyWith(backgroundColor: sectionColor);
    var sectionAppTextStyle = appTextStyle.copyWith(backgroundColor: sectionColor);

    if (_selectedEditDataPoint == editDataPoint) {
      //  editing this measure
      logger.v('pre : (${_editTextController.selection.baseOffset},${_editTextController.selection.extentOffset})'
          ' "${_editTextController.text}');
      if (_editTextField == null) {
        if (_editTextFieldFocusNode != null) {
          _disposeList.add(_editTextFieldFocusNode!); //  fixme: dispose of the old?
        }
        //  measure
        _editTextFieldFocusNode = FocusNode();
        _editTextField = TextField(
          controller: _editTextController,
          focusNode: _editTextFieldFocusNode,
          maxLength: null,
          style: _textFieldStyle,
          decoration: InputDecoration(
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            hintText: (_editTextController.text.isEmpty &&
                    (_selectedEditDataPoint?._measureEditType == MeasureEditType.replace))
                //  fixme: delete of last measure in section should warn about second delete
                ? 'Second delete will delete this measure' //  fixme: not working?
                : 'Enter the measure.',
            contentPadding: const EdgeInsets.all(_defaultFontSize / 2),
          ),
          autofocus: true,
          enabled: true,
          autocorrect: false,
          onEditingComplete: () {
            logger.d('_editTextField.onEditingComplete(): "${_editTextField?.controller?.text}"');
          },
          onSubmitted: (_) {
            logger.d('_editTextField.onSubmitted: ($_)');
          },
        );
      }

      logger.d('post: (${_editTextController.selection.baseOffset},${_editTextController.selection.extentOffset})'
          ' "${_editTextController.text}", ${_editTextController.text.isEmpty}');

      if (_measureEntryIsClear) {
        _measureEntryIsClear = false;
        _editTextController.text = measure?.toMarkupWithEnd(null) ?? '';
        _measureEntryValid = true; //  should always be!... at least at this moment,  fixme: verify
        _editTextController.selection = TextSelection(baseOffset: 0, extentOffset: _editTextController.text.length);
        _editTextFieldFocusNode?.requestFocus();
        logger.d('post: ${editDataPoint.location}: $measure'
            '  selection: (${_editTextController.selection.baseOffset}, ${_editTextController.selection.extentOffset})'
            ', ${_song.toMarkup()}');
      }

      //  make the key selection drop down list
      List<DropdownMenuItem<ScaleNote>> _keyChordDropDownMenuList = [];
      {
        //  list the notes required
        List<ScaleNote> scaleNotes = [];
        for (int i = 0; i < MusicConstants.notesPerScale; i++) {
          scaleNotes.add(_key.getMajorScaleByNote(i));
        }

        //  not scale notes
        for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
          ScaleNote scaleNote = _key.getScaleNoteByHalfStep(i);
          if (!scaleNotes.contains(scaleNote)) scaleNotes.add(scaleNote);
        }

        for (final ScaleNote scaleNote in scaleNotes) {
          String s = scaleNote.toMarkup();
          String label = s.padRight(2) +
              " " +
              ChordComponent.getByHalfStep(scaleNote.halfStep - _key.getHalfStep()).shortName.padLeft(2);
          DropdownMenuItem<ScaleNote> item = DropdownMenuItem(
            key: ValueKey('scaleNote' + scaleNote.toMarkup()),
            value: scaleNote,
            child: Text(
              label,
              style: sectionAppTextStyle,
            ),
          );
          _keyChordDropDownMenuList.add(item);
          ButtonTheme(
            child: item,
          );
        }
      }

      Widget _majorChordButton = _editTooltip(
          'Enter the major chord.',
          appButton(
            _keyChordNote.toString(),
            fontSize: _defaultChordFontSize,
            onPressed: () {
              setState(() {
                _updateChordText(_keyChordNote.toMarkup());
              });
            },
            // backgroundColor: fixme,
          ));
      Widget minorChordButton;
      {
        ScaleChord sc = ScaleChord(
          _keyChordNote,
          ChordDescriptor.minor,
        );
        minorChordButton = _editTooltip(
            'Enter the minor chord.',
            appButton(
              sc.toString(),
              fontSize: _defaultChordFontSize,
              onPressed: () {
                setState(() {
                  _updateChordText(sc.toMarkup());
                });
              },
            ));
      }
      Widget dominant7ChordButton;
      {
        ScaleChord sc = ScaleChord(_keyChordNote, ChordDescriptor.dominant7);
        dominant7ChordButton = _editTooltip(
            'Enter the dominant7 chord.',
            appButton(
              sc.toString(),
              fontSize: _defaultChordFontSize,
              onPressed: () {
                setState(() {
                  _updateChordText(sc.toMarkup());
                });
              },
            ));
      }

      List<DropdownMenuItem<ScaleChord>> _otherChordDropDownMenuList = [];
      {
        // other chords
        for (ChordDescriptor cd in ChordDescriptor.otherChordDescriptorsOrdered) {
          ScaleChord sc = ScaleChord(_keyChordNote, cd);
          _otherChordDropDownMenuList.add(DropdownMenuItem<ScaleChord>(
            key: ValueKey('scaleChord' + sc.toString()),
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

      List<DropdownMenuItem<ScaleNote>> _slashNoteDropDownMenuList = [];
      {
        // slash chords
        for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
          ScaleNote sc = _key.getScaleNoteByHalfStep(i);
          _slashNoteDropDownMenuList.add(DropdownMenuItem<ScaleNote>(
            key: ValueKey('scaleNote' + sc.toString()),
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

      return Container(
          color: sectionColor,
          width: _entryWidth,
          margin: _marginInsets,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                //  measure edit text field
                Container(
                  margin: const EdgeInsets.all(2),
                  color: sectionColor,
                  child: _editTextField,
                ),
                if (_measureEntryCorrection != null)
                  Container(
                    margin: _doubleMarginInsets,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                      Text(
                        _measureEntryCorrection ?? '',
                        style: _measureEntryValid
                            ? sectionChordBoldTextStyle
                            : sectionChordBoldTextStyle.copyWith(color: Colors.red),
                      ),
                    ]),
                  ),
                //  measure edit chord selection
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
                  _editTooltip(
                      'Select other notes from the key scale.',
                      ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<ScaleNote>(
                          items: _keyChordDropDownMenuList,
                          onChanged: (value) {
                            setState(() {
                              if (value != null) {
                                _keyChordNote = value;
                              }
                            });
                          },
                          value: _keyChordNote,
                          style: sectionAppTextStyle,
                          itemHeight: null,
                        ),
                      )),
                  _majorChordButton,
                  minorChordButton,
                  dominant7ChordButton,
                  _editTooltip(
                    'Enter a silent chord.',
                    appButton(
                      'X',
                      fontSize: _defaultChordFontSize,
                      onPressed: () {
                        setState(() {
                          _updateChordText('X');
                        });
                      },
                    ),
                  ),
                ]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _editTooltip(
                      'Select from other chord descriptors.',
                      ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<ScaleChord>(
                          hint: Text(
                            'Other chords',
                            style: sectionAppTextStyle,
                          ),
                          items: _otherChordDropDownMenuList,
                          onChanged: (_value) {
                            setState(() {
                              _updateChordText(_value?.toMarkup());
                            });
                          },
                          style: sectionAppTextStyle,
                          itemHeight: null,
                        ),
                      ),
                    ),
                    _editTooltip(
                      'Select a slash note',
                      ButtonTheme(
                        alignedDropdown: true,
                        child: DropdownButton<ScaleNote>(
                          hint: Text(
                            "/note",
                            style: sectionAppTextStyle,
                          ),
                          items: _slashNoteDropDownMenuList,
                          onChanged: (_value) {
                            setState(() {
                              _updateChordText('/' + (_value?.toMarkup() ?? ''));
                            });
                          },
                          style: sectionAppTextStyle,
                          itemHeight: null,
                        ),
                      ),
                    ),
                    if (_measureEntryValid)
                      _editTooltip(
                        'Add a repeat for this row',
                        ButtonTheme(
                          alignedDropdown: true,
                          child: DropdownButton<int>(
                            hint: Text(
                              "repeats",
                              style: sectionAppTextStyle,
                            ),
                            items: _repeatDropDownMenuList,
                            onChanged: (_value) {
                              setState(() {
                                logger.log(_editLog, 'repeat at: ${editDataPoint.location}');
                                _song.setRepeat(editDataPoint.location!, _value ?? 1);
                                _undoStackPush();
                                _performMeasureEntryCancel();
                              });
                            },
                            itemHeight: null,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      if (measure != null && editDataPoint._measureEditType == MeasureEditType.replace)
                        _editTooltip(
                          'Delete this measure',
                          InkWell(
                            child: const Icon(
                              Icons.delete,
                              size: _defaultChordFontSize,
                              color: Colors.black,
                            ),
                            onTap: () {
                              _performDelete();
                            },
                          ),
                        ),
                      _editTooltip(
                        'Cancel the modification.',
                        InkWell(
                          child: Icon(
                            Icons.cancel,
                            size: _defaultChordFontSize,
                            color: _measureEntryValid ? Colors.black : Colors.red,
                          ),
                          onTap: () {
                            _performMeasureEntryCancel();
                          },
                        ),
                      ),
                      if (_measureEntryValid)
                        _editTooltip(
                          'Accept the modification and extend the row.',
                          InkWell(
                            child: const Icon(
                              Icons.arrow_forward,
                              size: _defaultChordFontSize,
                            ),
                            onTap: () {
                              _performEdit(endOfRow: false);
                            },
                          ),
                        ),
                      if (_measureEntryValid)
                        _editTooltip(
                          'Accept the modification, end the row, and continue editing.',
                          InkWell(
                            child: const Icon(
                              Icons.call_received,
                              size: _defaultChordFontSize,
                            ),
                            onTap: () {
                              _performEdit(done: false, endOfRow: true);
                            },
                          ),
                        ),
                      if (_measureEntryValid)
                        _editTooltip(
                          'Accept the modification.\nFinished adding measures.',
                          InkWell(
                            child: const Icon(
                              Icons.check,
                              size: _defaultChordFontSize,
                            ),
                            onTap: () {
                              logger.v(
                                  'endOfRow?:  ${_song.findMeasureByChordSectionLocation(_selectedEditDataPoint?.location)?.endOfRow} ');
                              _performEdit(
                                  done: true,
                                  endOfRow: _song
                                          .findMeasureByChordSectionLocation(_selectedEditDataPoint?.location)
                                          ?.endOfRow ??
                                      false);
                            },
                          ),
                        ),
                    ]),
              ]));
    }

    //  not editing this measure
    return InkWell(
      onTap: () {
        _setEditDataPoint(editDataPoint);
      },
      child: Container(
          margin: _marginInsets,
          padding: _textPadding,
          color: sectionColor,
          child: _editTooltip(
              'modify or delete the measure',
              Text(
                measure?.transpose(_key, _transpositionOffset) ?? ' ',
                style: sectionChordBoldTextStyle,
              ))),
    );
  }

  Widget _repeatEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode? measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null || !measureNode.isRepeat()) {
      return Text('is not repeat: ${editDataPoint.location}: "$measureNode"');
    }
    MeasureRepeat repeat = measureNode as MeasureRepeat;

    Color sectionColor = getBackgroundColorForSection(editDataPoint.location?.sectionVersion?.section);

    if (_selectedEditDataPoint == editDataPoint) {
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
                    fontSize: _defaultChordFontSize,
                    onPressed: () {
                      _song.setRepeat(editDataPoint.location!, 2);
                      _undoStackPushIfDifferent();
                      _performMeasureEntryCancel();
                    },
                  ),
                  appButton(
                    'x3',
                    fontSize: _defaultChordFontSize,
                    onPressed: () {
                      _song.setRepeat(editDataPoint.location!, 3);
                      _undoStackPushIfDifferent();
                      _performMeasureEntryCancel();
                    },
                  ),
                  appButton(
                    'x4',
                    fontSize: _defaultChordFontSize,
                    onPressed: () {
                      _song.setRepeat(editDataPoint.location!, 4);
                      _undoStackPushIfDifferent();
                      _performMeasureEntryCancel();
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
                          _editTooltip(
                            'Delete this repeat',
                            InkWell(
                              child: const Icon(
                                Icons.delete,
                                size: _defaultChordFontSize,
                                color: Colors.black,
                              ),
                              onTap: () {
                                _song.setRepeat(editDataPoint.location!, 1);
                                _undoStackPush();
                                _performMeasureEntryCancel();
                              },
                            ),
                          ),
                        ],
                      ),
                      _editTooltip(
                        'Cancel the modification',
                        InkWell(
                          child: Icon(
                            Icons.cancel,
                            size: _defaultChordFontSize,
                            color: _measureEntryValid ? Colors.black : Colors.red,
                          ),
                          onTap: () {
                            _performMeasureEntryCancel();
                          },
                        ),
                      ),
                    ]),
              )
            ]),
      );
    }

    var sectionChordBoldTextStyle = _chordBoldTextStyle.copyWith(backgroundColor: sectionColor);
    //  not editing this measureNode
    return InkWell(
      onTap: () {
        _setEditDataPoint(editDataPoint);
      },
      child: Container(
          margin: _marginInsets,
          padding: _textPadding,
          color: sectionColor,
          child: _editTooltip(
              'modify or delete the measureNode',
              Text(
                'x${repeat.repeats}',
                style: sectionChordBoldTextStyle,
              ))),
    );
  }

  Widget _markerEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode? measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null || !measureNode.isComment()) {
      return Text('is not comment: ${editDataPoint.location}: "$measureNode"');
    }

    Color color = getBackgroundColorForSection(editDataPoint.location?.sectionVersion?.section);

    //  not editing this measureNode
    return InkWell(
      onTap: () {
        _setEditDataPoint(editDataPoint);
      },
      child: Container(
          margin: _marginInsets,
          padding: _textPadding,
          color: color,
          child: _editTooltip(
              'modify or delete the measureNode',
              Text(
                measureNode.toString(),
                style: _sectionChordBoldTextStyle,
              ))),
    );
  }

  void _updateChordText(final String? s) {
    logger.d('_updateChordText(${s.toString()})');

    if (s == null) {
      return;
    }
    String text = _editTextController.text;
    _editTextFieldFocusNode?.requestFocus();

    if (_lastEditTextSelection == null) {
      //  append the string
      _editTextController.text = text + s;
      logger.log(
          _editLog,
          '_updateChordText: _lastEditTextSelection is null: '
          '"$text"+"$s"');

      return;
    }
    //  fixme: i'm confused as to why selection extentOffset can be less than baseOffset
    var minOffset = min(_lastEditTextSelection!.baseOffset, _lastEditTextSelection!.extentOffset);
    var maxOffset = max(_lastEditTextSelection!.baseOffset, _lastEditTextSelection!.extentOffset);

    logger.log(_editLog, '_updateChordText: ($minOffset, $maxOffset): "$text"');

    if (minOffset < 0) {
      //  append the string
      _editTextController.text = text + s;
      int len = text.length + s.length;
      _editTextController.selection = _lastEditTextSelection!.copyWith(baseOffset: len, extentOffset: len);
      return;
    }

    logger.log(
        _editLog,
        '>=0: "${text.substring(0, minOffset)}"'
        '+"$s"'
        '+"${text.substring(maxOffset)}"');

    _editTextController.text = text.substring(0, minOffset) + s + text.substring(maxOffset);
    int len = minOffset + s.length;
    _editTextController.selection = _lastEditTextSelection!.copyWith(baseOffset: len, extentOffset: len);
  }

  Widget _plusMeasureEditGridDisplayWidget(_EditDataPoint editDataPoint, {String? tooltip}) {
    if (_selectedEditDataPoint == editDataPoint) {
      return _measureEditGridDisplayWidget(editDataPoint); //  let it do the heavy lifting
    }

    MeasureNode? measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null) {
      return const Text('null');
    }

    return InkWell(
        onTap: () {
          _setEditDataPoint(editDataPoint);
        },
        child: Container(
            margin: appendInsets,
            padding: appendPadding,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _addColor,
            ),
            child: _editTooltip(
              tooltip ??
                  ('add new measure on this row'
                      '${kDebugMode ? ' loc: ${editDataPoint.toString()}' : ''}'),
              Icon(
                Icons.add,
                size: _appendFontSize,
              ),
            )));
  }

  /// make a drop down list for the next most available, new sectionVersion
  DropdownButton<SectionVersion> _sectionVersionDropdownButton() {
    //  figure the selection versions to show
    SectionVersion selectedSectionVersion = SectionVersion.getDefault();
    List<SectionVersion> sectionVersions = [];
    int selectedWeight = 0;

    for (final SectionEnum sectionEnum in SectionEnum.values) {
      Section section = Section.get(sectionEnum);
      SectionVersion? sectionVersion;

      //  find a version that is not currently in the song
      for (int i = 0; i <= 9; i++) {
        sectionVersion = SectionVersion(section, i);
        if (_song.findChordSectionBySectionVersion(sectionVersion) == null) {
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
      var sectionChordTextStyle = _chordTextStyle.copyWith(
          backgroundColor: getBackgroundColorForSection(sectionVersion.section),
          color: getForegroundColorForSection(sectionVersion.section));

      //fixme: deal with selectedSectionVersion;
      DropdownMenuItem<SectionVersion> dropdownMenuItem = DropdownMenuItem<SectionVersion>(
        value: sectionVersion,
        child: Container(
          color: getBackgroundColorForSection(sectionVersion.section),
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
      hint: Text('Other section version', style: _chordTextStyle),
      value: selectedSectionVersion,
      items: ret,
      onChanged: (value) {
        setState(() {
          if (value != null) {
            _sectionVersion = value;
            _editTextController.text = _sectionVersion.toString();
          }
        });
      },
      style: generateAppTextStyle(
        color: getBackgroundColorForSection(selectedSectionVersion.section),
        textBaseline: TextBaseline.alphabetic,
      ),
      itemHeight: null,
    );
  }

  /// validate the given measure entry string
  List<MeasureNode> _validateMeasureEntry(String entry) {
    List<MeasureNode> entries = _song.parseChordEntry(SongBase.entryToUppercase(entry));
    _measureEntryValid = (entries.length == 1 && entries[0].getMeasureNodeType() != MeasureNodeType.comment);
    _measureEntryNode = (_measureEntryValid ? entries[0] : null);
    logger.d('_measureEntryValid: $_measureEntryValid');
    return entries;
  }

  SectionVersion? _parsedSectionEntry(String? entry) {
    if (entry == null || entry.length < 2) return null;
    try {
      return SectionVersion.parseString(entry);
    } catch (exception) {
      return null;
    }
  }

  ///  speed entry enhancement and validate the entry
  void _preProcessMeasureEntry(final String entry) {
    if (entry.isEmpty) {
      _measureEntryCorrection = null;
      _measureEntryValid = false;
      return;
    }

    //  construct a properly capitalized version of the entry
    String upperEntry = MeasureNode.concatMarkup(_validateMeasureEntry(entry));
    upperEntry = upperEntry.trim();
    String minEntry =
        entry.trim().replaceAll("\t", " ").replaceAll(":\n", ":").replaceAll("  ", " ").replaceAll("\n", ",");
    logger.v('entry: "$minEntry" vs "$upperEntry"');

    //  suggest the corrected input if different
    if (upperEntry == minEntry) {
      if (_measureEntryCorrection != null) {
        setState(() {
          _measureEntryCorrection = null;
        });
      }
    } else {
      setState(() {
        _measureEntryCorrection = upperEntry;
      });
    }
  }

//  preferred sections by order of priority
  final List<SectionVersion> _suggestedSectionVersions = [
    SectionVersion.bySection(Section.get(SectionEnum.verse)),
    SectionVersion.bySection(Section.get(SectionEnum.chorus)),
    SectionVersion.bySection(Section.get(SectionEnum.intro)),
    SectionVersion.bySection(Section.get(SectionEnum.bridge)),
    SectionVersion.bySection(Section.get(SectionEnum.outro)),
    SectionVersion.bySection(Section.get(SectionEnum.tag)),
    SectionVersion.bySection(Section.get(SectionEnum.a)),
    SectionVersion.bySection(Section.get(SectionEnum.b)),
  ];

  /// suggest a new chord section (that doesn't currently exist
  ChordSection _suggestNewSection() {
    //  generate the set of the song's section versions
    SplayTreeSet<SectionVersion> songSectionVersions = SplayTreeSet();
    for (final ChordSection cs in _song.getChordSections()) {
      songSectionVersions.add(cs.sectionVersion);
    }

    //  see if one of the suggested default section versions is missing
    for (final SectionVersion sv in _suggestedSectionVersions) {
      if (songSectionVersions.contains(sv)) {
        continue;
      }
      return ChordSection(sv, null);
    }

    //  see if one of the suggested numbered section versions is missing
    for (final SectionVersion sv in _suggestedSectionVersions) {
      for (int i = 1; i <= 9; i++) {
        SectionVersion svn = SectionVersion(sv.section, i);
        if (songSectionVersions.contains(svn)) {
          continue;
        }
        return ChordSection(svn, null);
      }
    }

    //  punt
    return ChordSection(SectionVersion(_defaultSection, 0), null);
  }

  /// helper function to generate tool tips
  Widget _editTooltip(
    String message,
    Widget child, {
    Key? key,
  }) {
    // String debug = '';
    // if (Logger.level.index <= Level.debug.index && _selectedEditDataPoint != null) {
    //   debug = '  edit: ${_selectedEditDataPoint.toString()}}';
    // }
    return Tooltip(
        // message: message + debug,
        key: key,
        message: message,
        child: child,
        textStyle: generateAppTextStyle(
          backgroundColor: tooltipColor,
          fontSize: _defaultChordFontSize / 2,
        ),

        //  fixme: why is this broken on web?
        //waitDuration: Duration(seconds: 1, milliseconds: 200),

        verticalOffset: 50,
        decoration: BoxDecoration(
            color: tooltipColor,
            border: Border.all(),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            boxShadow: const [BoxShadow(color: Colors.grey, offset: Offset(8, 8), blurRadius: 10)]),
        padding: const EdgeInsets.all(8));
  }

  void _undo() {
    setState(() {
      if (_undoStack.canUndo) {
        _app.clearMessage();
        _clearMeasureEntry();
        _loadSong(_undoStack.undo()?.copySong() ?? Song.createEmptySong());
        _undoStackLog();
        _checkSongChangeStatus();
      } else {
        _app.errorMessage('cannot undo any more');
      }
    });
  }

  void _redo() {
    setState(() {
      if (_undoStack.canRedo) {
        _app.clearMessage();
        _clearMeasureEntry();
        _loadSong(_undoStack.redo()?.copySong() ?? Song.createEmptySong());
        _undoStackLog();
        _checkSongChangeStatus();
      } else {
        _app.errorMessage('cannot redo any more');
      }
    });
  }

  ///  don't push an identical copy
  void _undoStackPushIfDifferent() {
    if (!(_song.songBaseSameContent(_undoStack.top))) {
      _undoStackPush();
    }
  }

  /// push a copy of the current song onto the undo stack
  void _undoStackPush() {
    _undoStack.push(_song.copySong());
    _undoStackLog();
  }

  void _undoStackLog() {
    if (Logger.level.index <= Level.debug.index) {
      for (int i = 0;; i++) {
        Song? s = _undoStack.get(i);
        if (s == null) {
          break;
        }
        logger.d('undo $i: "${s.toMarkup()}"');
      }
    } else {
      logger.d('undo ${_undoStack.pointer}: "${_undoStack.top?.toMarkup()}"');
    }
  }

  void _performEdit({bool done = false, bool endOfRow = false}) {
    setState(() {
      _edit(done: done, endOfRow: endOfRow);
      logger.log(_editLog, '_performEdit() done');
    });
  }

  /// perform the actual edit to the song
  bool _edit({bool done = false, bool endOfRow = false}) {
    if (!_measureEntryValid) {
      return false;
    }

    if (_selectedEditDataPoint == null) {
      return false;
    }

    //  setup song for edit
    _song.setCurrentChordSectionLocation(_selectedEditDataPoint?.location);
    _song.setCurrentMeasureEditType(_selectedEditDataPoint?._measureEditType ?? MeasureEditType.append);

    //  setup for prior end of row after the edit
    ChordSectionLocation? priorLocation = _song.getCurrentChordSectionLocation();
    logger.log(
        _editLog,
        'pre edit: prior: $priorLocation'
        ' "${_song.findMeasureByChordSectionLocation(priorLocation)}"'
        ', done: $done'
        ', endOfRow: $endOfRow'
        ', selectedEditDataPoint: $_selectedEditDataPoint');

    //  do the edit
    if (_song.editMeasureNode(_measureEntryNode)) {
      MeasureEditType measureEditType = _selectedEditDataPoint!._measureEditType;
      Measure? priorMeasure = _song.findMeasureByChordSectionLocation(priorLocation);
      logger.log(
          _editLog,
          'post edit: location: ${_song.getCurrentChordSectionLocation()} '
          '"${_song.findMeasureByChordSectionLocation(_song.getCurrentChordSectionLocation())}"'
          ', prior: $priorLocation "$priorMeasure"'
          ', endOfRow: $endOfRow'
          ', selectedEditDataPoint: $_selectedEditDataPoint');

      //  clean up after edit
      ChordSectionLocation? loc = _song.getCurrentChordSectionLocation();
      switch (measureEditType) {
        case MeasureEditType.append:
          logger.log(
              _editLog,
              'post append: location: ${_song.getCurrentChordSectionLocation()} '
              '"${_song.findMeasureByChordSectionLocation(_song.getCurrentChordSectionLocation())}"'
              ', prior: $priorLocation "${_song.findMeasureByChordSectionLocation(priorLocation)}"'
              ', selectedEditDataPoint: $_selectedEditDataPoint'
              ', endOfRow: $endOfRow');
          _song.setChordSectionLocationMeasureEndOfRow(priorLocation, _selectedEditDataPoint!.onEndOfRow);
          _song.setChordSectionLocationMeasureEndOfRow(loc, endOfRow);
          break;
        case MeasureEditType.replace:
          _song.setChordSectionLocationMeasureEndOfRow(loc, endOfRow);
          break;
        case MeasureEditType.insert:
          _song.setChordSectionLocationMeasureEndOfRow(loc, endOfRow);
          break;
        case MeasureEditType.delete:
          break;
      }

      //  don't push an identical copy
      _undoStackPushIfDifferent();
      logger.d('undo top: ${_undoStack.pointer}: "${_undoStack.top?.toMarkup()}"');

      _EditDataPoint? _lastEditDataPoint = _selectedEditDataPoint;
      _clearMeasureEntry();

      if (done) {
        _selectedEditDataPoint = null;
      } else {
        ChordSectionLocation? loc = _song.getCurrentChordSectionLocation();
        if (loc != null) {
          if (endOfRow) {
            if (priorMeasure != null) {
              _selectedEditDataPoint = _EditDataPoint(loc, onEndOfRow: true);
              _selectedEditDataPoint!._measureEditType = MeasureEditType.append;
              logger.log(_editLog, '$_selectedEditDataPoint $priorMeasure   append at end of section?');
            } else {
              loc = loc.nextMeasureIndexLocation();
              _selectedEditDataPoint = _EditDataPoint(loc);
              _selectedEditDataPoint!._measureEditType = MeasureEditType.insert;
            }
          } else if (_lastEditDataPoint!._measureEditType == MeasureEditType.insert ||
              _lastEditDataPoint._measureEditType == MeasureEditType.append) {
            _selectedEditDataPoint = _EditDataPoint(loc, onEndOfRow: endOfRow);
            _selectedEditDataPoint!._measureEditType = MeasureEditType.append;
          } else {
            _selectedEditDataPoint = _EditDataPoint(loc, onEndOfRow: endOfRow);
          }
        }
      }
      logger.log(_editLog, '_selectedEditDataPoint: $_selectedEditDataPoint');

      _checkSongChangeStatus();

      return true;
    } else {
      logger.log(_editLog, '_editMeasure(): failed');
      _app.errorMessage('edit failed: ${_song.message}');
    }

    return false;
  }

  ///  delete the current measure
  void _performDelete() {
    setState(() {
      ChordSectionLocation? priorLocation = _selectedEditDataPoint?.location?.priorMeasureIndexLocation();
      _song.setCurrentChordSectionLocation(_selectedEditDataPoint?.location);
      bool? endOfRow = _song.getCurrentChordSectionLocationMeasure()?.endOfRow; //  find the current end of row
      _song.setCurrentMeasureEditType(MeasureEditType.delete);
      if (_song.editMeasureNode(_measureEntryNode)) {
        //  apply the deleted end of row to the prior
        _song.setChordSectionLocationMeasureEndOfRow(priorLocation, endOfRow);
        _undoStackPush();
        _clearMeasureEntry();
      }
    });
  }

  void _setEditDataPoint(_EditDataPoint editDataPoint) {
    setState(() {
      _clearMeasureEntry();
      _app.clearMessage();
      _selectedEditDataPoint = editDataPoint;
      logger.d('_setEditDataPoint(${editDataPoint.toString()})');
    });
  }

  void _performMeasureEntryCancel() {
    setState(() {
      _clearMeasureEntry();
    });
  }

  void _clearMeasureEntry() {
    logger.v('_clearMeasureEntry()');
    _editTextField = null;
    _selectedEditDataPoint = null;
    _measureEntryIsClear = true;
    _measureEntryCorrection = null;
    _measureEntryValid = false;
  }

  /// returns true if the was a change of dirty status
  bool _checkSongChangeStatus() {
    if (hasChangedFromOriginal) {
      _song.resetLastModifiedDateToNow();
      _checkSong();
      setState(() {});
      return true;
    }
    _song.lastModifiedTime = _originalSong.lastModifiedTime;
    _checkSong();
    setState(() {});
    return false;
  }

  void _checkSong() {
    try {
      _song.checkSong();
      _isValidSong = true;
      _app.clearMessage();
    } catch (e) {
      _isValidSong = false;
      _app.errorMessage(e.toString());
    }
  }

  String _listSections() {
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

  String _listSectionAbbreviations() {
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

  void _import() async {
    List<NameValue> lyricStrings = await UtilWorkaround().textFilePickAndRead(context);
    for (var nameValue in lyricStrings) {
      _updateRawLyrics(_song.rawLyrics + nameValue.value);
    }
  }

  _navigateToDetail(BuildContext context) async {
    _app.selectedSong = _song;
    _app.selectedMomentNumber = 0;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Detail()),
    );
  }

  ScreenInfo? _screenInfo;
  Song _song;
  final Song _originalSong;

  bool get hasChangedFromOriginal => !_song.songBaseSameContent(_originalSong); //  fixme: too fine a line
  bool _isValidSong = false;

  music_key.Key get musicKey => _key; //  for testing
  music_key.Key _key = music_key.Key.getDefault();
  double _appendFontSize = 14;
  double _chordFontSize = 14;

  _EditDataPoint? _selectedEditDataPoint;

  int _transpositionOffset = 0;

  bool _measureEntryIsClear = true;
  String? _measureEntryCorrection;
  bool _measureEntryValid = false;
  final App _app = App();

  MeasureNode? _measureEntryNode;

  TextStyle _chordBoldTextStyle = generateAppTextStyle(fontWeight: FontWeight.bold);
  TextStyle _sectionChordBoldTextStyle = generateAppTextStyle(fontWeight: FontWeight.bold);
  TextStyle _chordTextStyle = generateAppTextStyle();
  TextStyle _lyricsTextStyle = generateAppTextStyle();
  EdgeInsets _marginInsets = const EdgeInsets.all(4);
  EdgeInsets _doubleMarginInsets = const EdgeInsets.all(8);
  static const EdgeInsets _textPadding = EdgeInsets.all(6);
  static const EdgeInsets appendInsets = EdgeInsets.all(0);
  static const EdgeInsets appendPadding = EdgeInsets.all(0);

  TextField? _editTextField;

  final TextEditingController _titleTextEditingController = TextEditingController();
  final TextEditingController _artistTextEditingController = TextEditingController();
  final TextEditingController _coverArtistTextEditingController = TextEditingController();
  final TextEditingController _copyrightTextEditingController = TextEditingController();
  final TextEditingController _bpmTextEditingController = TextEditingController();
  final TextEditingController _userTextEditingController = TextEditingController();

  final TextEditingController _editTextController = TextEditingController();
  FocusNode? _editTextFieldFocusNode;
  TextSelection? _lastEditTextSelection;
  int _tableKeyId = 0;

  LyricsEntries _lyricsEntries = LyricsEntries();

  bool _showHints = false;

  SectionVersion _sectionVersion = SectionVersion.getDefault();
  ScaleNote _keyChordNote = music_key.Key.getDefault().getKeyScaleNote();

  final List<DropdownMenuItem<int>> _repeatDropDownMenuList = [];

  final List<ChangeNotifier> _disposeList = []; //  fixme: workaround to dispose the text controllers

  final UndoStack<Song> _undoStack = UndoStack();

  final FocusManager _focusManager = FocusManager.instance;
  final FocusNode _focusNode = FocusNode();

  final AppWidget appWidget = AppWidget();

  static const tooltipColor = Color(0xFFE8F5E9);
  late AppOptions _appOptions;
}

// class _LyricsTextField {
//   _LyricsTextField(
//     this.entry,
//     this.line, {
//     controller,
//     style,
//     decoration,
//     onSubmitted,
//     onEditingComplete,
//     onChanged,
//   }) {
//     if (controller != null) {
//       _textField = TextField(
//           controller: controller,
//           style: style,
//           decoration: decoration,
//           onSubmitted: onSubmitted,
//           onEditingComplete: onEditingComplete,
//           onChanged: onChanged,
//           onTap: () {
//             logger.log(_editLog,'onTap(): ${this.toString()}  /// temp only!!!!!');
//             _selectedLyricsTextField = this;
//           },
//           maxLines: null);
//     }
//   }
//
//   @override
//   String toString() {
//     return '_LyricsTextField{entry: $entry, line: $line, _textField: \'${_textField?.controller?.text}\'';
//   }
//
//   final LyricsDataEntry entry;
//   final int line;
//
//   get controller => _textField?.controller;
//
//   get textField => _textField ?? Text('');
//   TextField? _textField;
// }

//  internal class to hold handy data for each point in the chord section edit display
class _EditDataPoint {
  _EditDataPoint(this.location, {this.onEndOfRow = false});

  _EditDataPoint.byMeasureNode(final Song song, this.measureNode, {this.onEndOfRow = false}) {
    location = song.findChordSectionLocation(measureNode);
  }

  @override
  String toString() {
    return '_EditDataPoint{'
        ' loc: ${location?.toString()}'
        ', editType: ${describeEnum(_measureEditType)}'
        ', onEndOfRow: $onEndOfRow'
        '${(measureNode == null ? '' : ', measureNode: $measureNode')}'
        '}';
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! _EditDataPoint) {
      return false;
    }
    _EditDataPoint o = other;
    return location == o.location &&
        _measureEditType == o._measureEditType &&
        onEndOfRow == o.onEndOfRow &&
        measureNode == o.measureNode;
  }

  bool get isSection => measureNode != null && measureNode?.getMeasureNodeType() == MeasureNodeType.section;

  @override
  int get hashCode => hashValues(location, _measureEditType, measureNode);

  ChordSectionLocation? location;
  bool onEndOfRow = false;
  MeasureEditType _measureEditType = MeasureEditType.replace; //  default
  MeasureNode? measureNode;
}

/*
v: a b c d, d c g g
C: C G D A, E E E E


Off the top of my head, since the order of flats is
B, E, A, D, G, C and F

We pretty-much never see Gb, Cb and Fb  (because Cb is B and Fb is E)

going the other way, we pretty-much never see A#, E#, and B# (Because E# is F and B# is C)

 */
