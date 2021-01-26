import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/songs/chordComponent.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as songs;
import 'package:bsteeleMusicLib/songs/lyricSection.dart';
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
import 'package:bsteeleMusicLib/util/undoStack.dart';
import 'package:bsteele_music_flutter/gui.dart';
import 'package:bsteele_music_flutter/screens/lyricsTable.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

///   screen to edit a song
class Edit extends StatefulWidget {
  const Edit({Key? key, required this.initialSong}) : super(key: key);

  @override
  _Edit createState() => _Edit(initialSong);

  final Song initialSong;
}

const double _defaultChordFontSize = 28;
const double _defaultFontSize = _defaultChordFontSize * 0.8;

const TextStyle _boldTextStyle = const TextStyle(
    fontSize: _defaultFontSize, fontWeight: FontWeight.bold, color: Colors.black87, backgroundColor: Color(0xFFF5F5F5));
const TextStyle _labelTextStyle = const TextStyle(fontSize: _defaultFontSize, fontWeight: FontWeight.bold);
const TextStyle _buttonTextStyle =
    TextStyle(fontSize: _defaultFontSize, fontWeight: FontWeight.bold, color: Colors.black);
const TextStyle _textStyle = const TextStyle(fontSize: _defaultFontSize, color: Color(0xFF424242));
const TextStyle _errorTextStyle = const TextStyle(fontSize: _defaultFontSize, color: Colors.red);
const double _entryWidth = 18 * _defaultChordFontSize;

const Color _defaultColor = const Color(0xFFB3E5FC);
const Color _hoverColor = const Color(0xFF4FC3F7);
const Color _disabledColor = const Color(0xFFE0E0E0);
final Section _defaultSection = Section.get(SectionEnum.chorus);

/// helper class to manage a RaisedButton
class _AppContainedButton extends RaisedButton {
  _AppContainedButton(
    String text, {
    Color? color,
    VoidCallback? onPressed,
  }) : super(
          shape: RoundedRectangleBorder(
            borderRadius: new BorderRadius.circular(_defaultChordFontSize / 3),
          ),
          color: color ?? _defaultColor,
          textColor: Colors.black,
          disabledTextColor: Colors.grey[400],
          disabledColor: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          hoverColor: _hoverColor,
          child: Text(
            text,
            style: _buttonTextStyle,
          ),
          onPressed: onPressed,
        );
}

/// helper class to manage an OutlineButton
class _AppOutlineButton extends OutlineButton {
  _AppOutlineButton(
    String _text, {
    VoidCallback? onPressed,
  }) : super(
          shape: new RoundedRectangleBorder(
            borderRadius: new BorderRadius.circular(12.0),
          ),
          color: _defaultColor,
          textColor: Colors.black87,
          hoverColor: _hoverColor,
          disabledTextColor: Colors.grey[400],
          borderSide: BorderSide(width: 1.66, color: Colors.black54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: new Text(
            _text,
            style: _buttonTextStyle,
          ),
          onPressed: onPressed,
        );
}

class _Edit extends State<Edit> {
  _Edit(Song initialSong)
      : _song = initialSong.copySong(),
        _originalSong = initialSong.copySong() {
    //  _checkSongStatus();
    _undoStackPush();
  }

  @override
  initState() {
    super.initState();

    _editTextFieldFocusNode = FocusNode();

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
            logger.i('newline: should _editMeasure() called here?');
            break;
          //  look for TextField.onEditingComplete() for end of entry... but it happens too often!
        }
      }

      logger.d('chordTextController: "${_editTextController.text}"');
    });
  }

  @override
  void dispose() {
    _editTextController.dispose();
    _editTextFieldFocusNode?.dispose();
    for (var focusNode in _disposeList) {
      focusNode.dispose();
    }
    super.dispose();
    logger.d('edit dispose()');
  }

  @override
  Widget build(BuildContext context) {
    logger.i('edit build: "${_editTextController.text.toString()}"');

    ScreenInfo screenInfo = ScreenInfo(context);
    final double _screenWidth = screenInfo.widthInLogicalPixels;

    _chordFontSize = _defaultChordFontSize * _screenWidth / 800;
    _chordFontSize = min(_defaultChordFontSize, max(12, _chordFontSize));
    _appendFontSize = _chordFontSize * 0.75;
    //double lyricsScaleFactor = max(1, 0.75 * chordScaleFactor);

    _chordBoldTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: _chordFontSize,
    );
    _chordTextStyle = TextStyle(
      fontSize: _appendFontSize,
      color: Colors.black87,
    );

    _chordBadTextStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: _chordFontSize, color: Colors.red);

    //  build the chords display based on the song chord section grid
    Table? _chordTable;
    _tableKeyId = 0;
    int maxCols = 0;
    {
      logger.d('size: ' + MediaQuery.of(context).size.toString());

      //  build the table from the song chord section grid
      Grid<ChordSectionLocation> grid = _song.getChordSectionLocationGrid();
      Grid<_EditDataPoint> editDataPoints = Grid();

      if (grid.isNotEmpty) {
        List<TableRow> rows = [];
        List<Widget> children = [];
        sectionColor = GuiColors.getColorForSection(_defaultSection);

        //  compute transposition offset from base key
        _transpositionOffset = 0; //_key.getHalfStep() - _song.getKey().getHalfStep();

        //  compute the maximum number of columns to even out the table rows

        {
          for (int r = 0; r < grid.getRowCount(); r++) {
            List<ChordSectionLocation?>? row = grid.getRow(r);
            maxCols = max(maxCols, row?.length ?? 0);

            // //  test for no end of row
            // if (row != null && row.isNotEmpty) {
            //   for (int c = 0; c < row.length; c++) {
            //     ChordSectionLocation? loc = row[c];
            //     // ChordSectionLocation? loc = row.last;
            //     logger.i('   missing endOfRow: $loc');
            //
            //     MeasureNode? mn = _song.findMeasureNodeByGrid(GridCoordinate(r, c));
            //     logger.i('   ($r, $c): $loc: ${mn?.getMeasureNodeType()}  ${mn?.toString()}');
            //     Measure? m = _song.findMeasureByChordSectionLocation(loc);
            //     if (m != null //&& m.endOfRow != true
            //     ) {
            //       logger.i('   missing endOfRow: $loc: ${m.getMeasureNodeType()} $m');
            //     }
            //   }
            // }
          }
        }

        //  keep track of the section
        SectionVersion? lastSectionVersion;

        //  map the song chord section grid to a flutter table, one row at a time
        for (int r = 0; r < grid.getRowCount(); r++) {
          List<ChordSectionLocation?>? row = grid.getRow(r);
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
            for (final ChordSectionLocation? loc in row)
              if (loc == null)
                continue;
              else {
                firstChordSectionLocation = loc;
                break;
              }
            if (firstChordSectionLocation == null) continue;

            SectionVersion? sectionVersion = firstChordSectionLocation.sectionVersion;

            if (sectionVersion != lastSectionVersion) {
              //  add a plus for appending a new row to the section
              _addSectionVersionEndToTable(rows, lastSectionVersion, 2 * maxCols /*col+add markers*/);

              //  add the section heading
              //           columnFiller = sectionVersion.toString();
              sectionColor = GuiColors.getColorForSection(sectionVersion?.section);
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
                padding: textPadding,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green[100],
                ),
                child: _editTooltip(
                    'add new section here',
                    InkWell(
                      onTap: () {
                        setState(() {
                          _song.setCurrentChordSectionLocation(null);
                          _song.setCurrentMeasureEditType(MeasureEditType.append);
                          ChordSection cs = _suggestNewSection();
                          // if (_song.editMeasureNode(cs)) {
                          //   _undoStackPush();
                          //   _clearMeasureEntry();
                          _selectedEditDataPoint = _EditDataPoint.byMeasureNode(_song, cs);
                          logger.d('${_song.toMarkup()} + $_selectedEditDataPoint');
                          // }
                        });
                      },
                      child: Icon(
                        Icons.add,
                        size: _chordFontSize,
                      ),
                    )));
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
          defaultColumnWidth: IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: rows,
        );

        logger.v(editDataPoints.toMultiLineString());
      }
    }

    // Table _lyricsTable = Table();
    // {
    //   List<TableRow> rows = [];
    //   List<Widget> children;
    //
    //   sectionColor = GuiColors.getColorForSection(SectionVersion.getDefault().section);
    //   for (var lyricSection in _song.lyricSections) {
    //     ChordSection? chordSection = _song.findChordSectionByLyricSection(lyricSection);
    //     SectionVersion? sectionVersion;
    //     if (chordSection != null) {
    //       sectionVersion = chordSection.sectionVersion;
    //     }
    //
    //     var gridCoordinate =  _song.getChordSectionGridCoorinateMap()[sectionVersion];
    //     var gridRow = gridCoordinate?.row ?? 0;
    //
    //     for (int rowNumber = 0; rowNumber < 200; rowNumber++) {
    //       if (rowNumber > lyricSection.lyricsLines.length) {
    //         break;
    //       }
    //       children = [];
    //       if (sectionVersion != null) {
    //         sectionColor = GuiColors.getColorForSection(sectionVersion.section);
    //         children.add(Container(
    //             margin: _marginInsets,
    //             padding: textPadding,
    //             color: sectionColor,
    //             child: _editTooltip(
    //                 'modify or delete the section',
    //                 Text(
    //                   sectionVersion.toString(),
    //                   style: _chordBoldTextStyle,
    //                 ))));
    //         sectionVersion = null;
    //       } else {
    //         children.add(_nullEditGridDisplayWidget());
    //       }
    //
    //       children.add(Text(
    //         gridRow.toString() + ' row',
    //         style: _chordBoldTextStyle,
    //       ));
    //
    //       //  fill the columns so they are all the same length
    //       while ( children.length < maxCols) {
    //         children.add(_nullEditGridDisplayWidget());
    //       }
    //
    //       if (rowNumber < lyricSection.lyricsLines.length) {
    //         children.add(Text(
    //           lyricSection.lyricsLines[rowNumber],
    //           style: _textStyle,
    //         ));
    //       } else {
    //         children.add(_nullEditGridDisplayWidget());
    //       }
    //
    //       rows.add(TableRow(key: ValueKey('table${_tableKeyId++}'), children: children));
    //       gridRow++;
    //     }
    //   }
    //
    //   _lyricsTable = Table(
    //     defaultColumnWidth: IntrinsicColumnWidth(),
    //     defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    //     children: rows,
    //   );
    // }

    {
      //  list the notes required
      List<ScaleNote> scaleNotes = [];

      //  scale notes
      for (int i = 0; i < MusicConstants.notesPerScale; i++) {
        scaleNotes.add(_key.getMajorScaleByNote(i));
      }

      //  not scale notes
      for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
        ScaleNote scaleNote = _key.getScaleNoteByHalfStep(i);
        if (!scaleNotes.contains(scaleNote)) scaleNotes.add(scaleNote);
      }

      //  make the key selection drop down list
      _keyChordDropDownMenuList = [];
      for (final ScaleNote scaleNote in scaleNotes) {
        String s = scaleNote.toMarkup();
        String label = s.padRight(2) +
            " " +
            ChordComponent.getByHalfStep(scaleNote.halfStep - _key.getHalfStep()).shortName.padLeft(2);
        DropdownMenuItem<ScaleNote> item =
            DropdownMenuItem(key: ValueKey('scaleNote' + scaleNote.toMarkup()), value: scaleNote, child: Text(label));
        _keyChordDropDownMenuList.add(item);
      }
    }

    //  push the lyrics into the song if they have changed
    if (_lyricsAreDirty) {
      String s = _songLyricsEntry();
      logger.i('new lyrics: $s');
      _song.setRawLyrics(s);
      _lyricsAreDirty = false;
    }

    _lyricsTextFields = [];

    return Scaffold(
        backgroundColor: Colors.white,
        body:
            //  deal with keyboard strokes flutter is not usually handling
            //  note that return (i.e. enter) is not a keyboard event!
            RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: _mainOnKey,
          child: GestureDetector(
            // fixme: put GestureDetector only on chord table
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Container(
                padding: EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.ltr,
                  children: <Widget>[
                    AppBar(
                      //  let the app bar scroll off the screen for more room for the song
                      title: Text(
                        'Edit',
                        style: const TextStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold),
                      ),
                      centerTitle: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          _AppContainedButton(
                            _isDirty ? 'Enter song' : 'Nothing has changed',
                            color: _isDirty ? null : _disabledColor,
                            onPressed: () {
                              //  fixme enter song
                            },
                          ),
                          Container(
                            child: Text(_errorMessageString ?? '', style: _errorTextStyle),
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                _AppContainedButton(
                                  'Clear',
                                  onPressed: () {},
                                ),
                                _AppContainedButton(
                                  'Remove',
                                  onPressed: () {},
                                ),
                                Container(
                                  child: FlatButton.icon(
                                    icon: Icon(
                                      Icons.arrow_left,
                                      size: 48,
                                    ),
                                    label: const Text(
                                      '',
                                      style: _boldTextStyle,
                                    ),
                                    onPressed: () {
                                      _errorMessage('bob: fixme: arrow_left');
                                    },
                                  ),
                                ),
                                Container(
                                  child: FlatButton.icon(
                                    icon: Icon(
                                      Icons.arrow_right,
                                      size: 48,
                                    ),
                                    label: Text(
                                      '',
                                      style: _buttonTextStyle,
                                    ),
                                    onPressed: () {
                                      _errorMessage('bob: fixme: arrow_right');
                                    },
                                  ),
                                ),
                              ]),
                        ]),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 24, bottom: 24.0),
                            child: Text(
                              'Title: ',
                              style: TextStyle(
                                fontSize: _defaultChordFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _song.title),
                              decoration: InputDecoration(
                                hintText: 'Enter the song title.',
                              ),
                              maxLength: null,
                              style: TextStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold),
                              onSubmitted: (value) {
                                _song.setTitle(value);
                                _checkSongStatus();
                              },
                            ),
                          ),
                        ]),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 24, bottom: 24.0),
                            child: Text(
                              'Artist: ',
                              style: _labelTextStyle,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _song.artist),
                              decoration: InputDecoration(hintText: 'Enter the song\'s artist.'),
                              maxLength: null,
                              style: _boldTextStyle,
                            ),
                          ),
                        ]),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 24, bottom: 24.0),
                            child: Text(
                              'Cover Artist:',
                              style: _labelTextStyle,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _song.coverArtist),
                              decoration: InputDecoration(hintText: 'Enter the song\'s cover artist.'),
                              maxLength: null,
                              style: _boldTextStyle,
                            ),
                          ),
                        ]),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 24, bottom: 24.0),
                            child: Text(
                              'Copyright:',
                              style: _labelTextStyle,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _song.copyright),
                              decoration: InputDecoration(hintText: 'Enter the song\'s copyright. Required.'),
                              maxLength: null,
                              style: _boldTextStyle,
                            ),
                          ),
                        ]),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            "Key: ",
                            style: _labelTextStyle,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(bottom: 24.0),
                          child: DropdownButton<songs.Key>(
                            items: songs.Key.values.toList().reversed.map((songs.Key value) {
                              return new DropdownMenuItem<songs.Key>(
                                key: ValueKey('half' + value.getHalfStep().toString()),
                                value: value,
                                child: new Text(
                                  '${value.toMarkup().padRight(3)} ${value.sharpsFlatsToMarkup()}',
                                  style: _boldTextStyle,
                                ),
                              );
                            }).toList(),
                            onChanged: (_value) {
                              setState(() {
                                if (_value != null) {
                                  _key = _value;
                                  _keyChordNote = _key.getKeyScaleNote();
                                }
                              });
                            },
                            value: _key,
                            style: TextStyle(
                              //  size controlled by textScaleFactor above
                              color: Colors.black87,
                              textBaseline: TextBaseline.ideographic,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            "   BPM: ",
                            style: _labelTextStyle,
                          ),
                        ),
                        Container(
                          width: 80.0,
                          child: TextField(
                            controller: TextEditingController(text: _song.getBeatsPerMinute().toString()),
                            decoration: InputDecoration(hintText: 'Enter the song\'s beats per minute.'),
                            maxLength: null,
                            style: _boldTextStyle,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            "Time: ",
                            style: _labelTextStyle,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            "${_song.beatsPerBar}/${_song.unitsPerMeasure}",
                            style: _boldTextStyle,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(left: 24, bottom: 24.0),
                          child: Text(
                            "  User: ",
                            style: _textStyle,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            _song.user.toString(),
                            style: _textStyle,
                          ),
                        ),
                      ],
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                      Flexible(
                        flex: 1,
                        child: Text(
                          "Chords:",
                          style: _labelTextStyle,
                        ),
                      ),
                      Flexible(
                        flex: 1,
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          _editTooltip(
                            _undoStack.canUndo ? 'Undo the last edit' : 'There is nothing to undo',
                            _AppOutlineButton(
                              'Undo',
                              onPressed: () {
                                _undo();
                              },
                            ),
                          ),
                          _editTooltip(
                            _undoStack.canUndo ? 'Reo the last edit undone' : 'There is no edit to redo',
                            _AppOutlineButton(
                              'Redo',
                              onPressed: () {
                                _redo();
                              },
                            ),
                          ),
                          _AppOutlineButton(
                            '4/Row',
                          ),
                          _editTooltip(
                            (_selectedEditDataPoint != null ? 'Click outside the chords to cancel editing\n' : '') +
                                (_showHints ? 'Click to hide the editing hints' : 'Click for hints about editing.'),
                            _AppOutlineButton('Hints', onPressed: () {
                              setState(() {
                                _showHints = !_showHints;
                              });
                            }),
                          ),
                        ]),
                      ),
                    ]),
                    if (_chordTable != null)
                      Container(
                        padding: EdgeInsets.all(16.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          //  pre-configured table of edit widgets
                          _chordTable,
                        ]),
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
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: '\n\n'
                                      'The sections are: ' +
                                  _listSections(),
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: '\n'
                                  'Their abbreviations are: ',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: _listSectionAbbreviations(),
                              style: _textStyle,
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
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: '''A capital X is used to indicate no chord.\n\n''',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text:
                                  '''Using a lower case b for a flat will work. A sharp sign (#) works as a sharp.\n\n''',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text:
                                  //  todo: fix the font, ♭ is not represented properly
                                  'Notice that this can get problematic around the lower case b. Should the entry "bbm7"'
                                  ' be a B♭m7 or the chord B followed by a Bm7?'
                                  ' The app will assume a B♭m7 but you can force a BBm7 by entering either "BBm7" or "bBm7".\n\n'
                                  '',
                              style: _textStyle,
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
                              style: _textStyle,
                            ),
                            TextSpan(
                              text:
                                  '''Spaces between chords indicate a new measure. Chords without spaces are within one measure.\n\n''',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'Forward slashes (/) can be used to indicate bass notes that differ from the chord.'
                                  ' For example A/G would mean a G for the bass, an A chord for the other instruments.'
                                  ' The bass note is a single note, not a chord.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text:
                                  'Periods (.) can be used to repeat chords on another beat within the same meausure. For'
                                  ' example, G..A would be three beats of G followed by one beat of A in the same measure.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: '''Sample measures to use:
      A B C G
      A# C# Bb Db
      C7 D7 Dbm Dm Em Dm7 F#m7 A#maj7 Gsus9
      DC D#Bb G#m7Gm7 Am/G G..A\n\n''',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'Commas (,) between measures can be used to indicate the end of a row of measures.'
                                  ' The maximum number of measures allowed within a single row is 8.'
                                  ' If there are no commas within a phrase of 8 or more measures, the phrase will'
                                  ' automatically be split into rows of 4 measures.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'Minus signs (-) can be used to indicate a repeated measure.'
                                  ' There must be a space before and after it.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'Row repeats are indicated by a lower case x followed by a number 2 or more.'
                                  ' Multiple rows can be repeated by placing an opening square bracket ([) in front of the'
                                  ' first measure of the first row and a closing square bracket (]) after the last'
                                  ' measure before the x and the digits.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'Comments are not allowed in the chord section.'
                                  ' Chord input not understood will be placed in parenthesis, eg. "(this is not a chord sequence)".\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'Since you can enter the return key to create a new row for your entry,'
                                  ' you must us the exit to stop editing.  Clicking outside the entry'
                                  ' box or typing escape will work as well.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'The red bar or measure highlight indicate where entry text will be entered.'
                                  ' The radio buttons control the fine position of this indicator for inserting, replacing,'
                                  ' or appending. To delete a measure, select it and click Replace. This activates the Delete button'
                                  ' to delete it. Note that the delete key will always apply to text entry.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'Double click a measure to select it for replacement or deletion.'
                                  ' Note that if you double click the section type, the entire section will be'
                                  ' available on the entry line for modification.'
                                  ' If two sections have identical content, they will appear as multiple types for the'
                                  ' single content. Define a different section content for one of the multiple sections'
                                  ' and it will be separated from the others.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text:
                                  'Control plus the arrow keys can help navigate in the chord entry once selected.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'In the lyrics section, anything else not recognized as a section identifier is'
                                  ' considered lyrics to the end of the line.'
                                  ' I suggest comments go into parenthesis.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text:
                                  'The buttons to the right of the displayed chords are active and there to minimize your typing.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text: 'A trick: Select a section similar to a new section you are about to enter.'
                                  ' Copy the text from the entery area. Delete the entry line. Enter the new section identifier'
                                  ' (I suggest the section buttons on the right).'
                                  ' Paste the old text after the new section. Make edit adjustments in the entry text'
                                  ' and press the keyboard enter button.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text:
                                  'Another trick: Write the chord section as you like in a text editor, copy the whole song\'s'
                                  ' chords and paste into the entry line... complete with newlines. All should be well.\n\n',
                              style: _textStyle,
                            ),
                            TextSpan(
                              text:
                                  'Don\'t forget the undo/redo keys! Undo will even go backwards into the previously edited song.\n\n',
                              style: _textStyle,
                            ),
                          ],
                        ),
                      ),
                    Text(
                      "Lyrics:",
                      style: _labelTextStyle,
                    ),
                    Container(
                      padding: EdgeInsets.all(16.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        //  pre-configured table of edit widgets
                        _lyricsTable.lyricsTable(_song,
                            sectionHeaderWidget: _editSectionHeaderWidget,
                            textWidget: _editTextWidget,
                            lyricEndWidget: _lyricEndWidget),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            onTap: () {
              _performMeasureEntryCancel();
            },
          ),
        ));
  }

  Widget _editSectionHeaderWidget(LyricSection lyricSection) {
    return InkWell(
        onTap: () {
          logger.i('figure how to add section here');
        },
        child: Container(
            margin: appendInsets,
            padding: textPadding,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green[100],
            ),
            child: _editTooltip(
              'add new lyric section here',
              Icon(
                Icons.add,
                size: _chordFontSize,
              ),
            )));
  }

  Widget _editTextWidget(LyricSection lyricSection, String s) {
    var ret = _LyricsTextField(
      lyricSection,
      controller: TextEditingController(text: s),
      style: _chordBoldTextStyle,
      decoration: InputDecoration(
        hintText: '(Enter ${lyricSection.sectionVersion} lyrics here.)',
      ),
      onSubmitted: (_) {
        logger.i('lyrics onSubmitted: ($_)');
      },
      onEditingComplete: () {
        logger.i('lyrics onEditingComplete()');
      },
      onChanged: (value) {
        _lyricsAreDirty = true;
      },
    );
    _lyricsTextFields.add(ret);
    return ret;
  }

  Widget _lyricEndWidget() {
    return InkWell(
        onTap: () {
          logger.i('figure how to add section at the end');
        },
        child: Container(
            margin: appendInsets,
            padding: textPadding,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green[100],
            ),
            child: _editTooltip(
              'add new lyric section here at the end',
              Icon(
                Icons.add,
                size: _chordFontSize,
              ),
            )));
  }

  /// collect all the entered song lyrics
  String _songLyricsEntry() {
    StringBuffer sb = StringBuffer();
    LyricSection? lastLyricSection;
    for (var lf in _lyricsTextFields) {
      if (!identical(lf.lyricSection, lastLyricSection)) {
        lastLyricSection = lf.lyricSection;
        sb.write('${lf.lyricSection.sectionVersion}');
      }
      sb.writeln('${lf.controller?.text ?? ''}');
    }
    return sb.toString();
  }

  ///  add a row for a plus on the bottom of the section to continue on the next row
  void _addSectionVersionEndToTable(List<TableRow> rows, SectionVersion? sectionVersion, int maxCols) {
    if (sectionVersion == null) {
      return;
    }
    ChordSection? chordSection = _song.findChordSectionBySectionVersion(sectionVersion);
    ChordSectionLocation? loc = _song.findLastChordSectionLocation(chordSection);
    if (loc != null) {
      _EditDataPoint editDataPoint = _EditDataPoint(loc, onEndOfRow: true);
      editDataPoint._measureEditType = MeasureEditType.append;
      Widget w = _plusMeasureEditGridDisplayWidget(editDataPoint,
          tooltip: 'add new measure on a new row'
              ' loc: ${loc.toString()} ${describeEnum(editDataPoint._measureEditType)}' //
          );
      List<Widget> children = [];
      children.add(_nullEditGridDisplayWidget());
      children.add(w);

      //  add children to max columns to keep the table class happy
      while (children.length < maxCols) {
        children.add(Container());
      }

      //  add row to table
      rows.add(TableRow(key: ValueKey('table${_tableKeyId++}'), children: children));
    }
  }

  /// process the raw keys flutter doesn't want to
  /// this is largely done for the desktop... since phones and tablets usually don't have keyboards
  void _mainOnKey(RawKeyEvent value) {
    if (value.runtimeType == RawKeyDownEvent) {
      RawKeyDownEvent e = value as RawKeyDownEvent;
      logger.d('main onkey: ${e.data.logicalKey}'
          ', ctl: ${e.isControlPressed}'
          ', shf: ${e.isShiftPressed}'
          ', alt: ${e.isAltPressed}');
      if (e.isControlPressed) {
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
        } else if (e.isKeyPressed(LogicalKeyboardKey.keyV) && e.isShiftPressed) {
          logger.i('shift ctl V');
        } else if (e.isKeyPressed(LogicalKeyboardKey.keyV)) {
          if (e.isShiftPressed) {
            logger.i('ctl shift V');
          } else {
            logger.i('ctl V');
          }
        } else if (e.isKeyPressed(LogicalKeyboardKey.keyZ)) {
          if (e.isShiftPressed) {
            _redo();
          } else {
            _undo();
          }
        }
      } else if (e.isKeyPressed(LogicalKeyboardKey.escape)) {
        /// clear editing with the escape key
        _performMeasureEntryCancel();
      } else if (e.isKeyPressed(LogicalKeyboardKey.enter) || e.isKeyPressed(LogicalKeyboardKey.numpadEnter)) {
        _performEdit(done: false, endOfRow: true);
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
      } else if (e.isKeyPressed(LogicalKeyboardKey.space)) {
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
    return Text(
      '',
      //' null',  //  diagnostic
    );
  }

  Widget _sectionEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode? measureNode =
        _song.findMeasureNodeByLocation(editDataPoint.location) ?? editDataPoint.measureNode; //  for new sections
    if (measureNode == null) {
      return Text('null');
    }

    if (measureNode.getMeasureNodeType() != MeasureNodeType.section) return Text('not_section');

    ChordSection? chordSection = measureNode as ChordSection?;
    if (_selectedEditDataPoint == editDataPoint) {
      //  we're editing the section
      if (_editTextField == null) {
        String entry = measureNode.toString();
        _editTextController.text = entry;
        _editTextController.selection = TextSelection(baseOffset: 0, extentOffset: entry.length);
        _editTextField = TextField(
          controller: _editTextController,
          focusNode: _editTextFieldFocusNode,
          maxLength: null,
          style: _chordBoldTextStyle,
          decoration: InputDecoration(
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
      //Color color = isValidSectionEntry ? Colors.black87 : Colors.red;
      sectionColor = GuiColors.getColorForSection(entrySectionVersion?.section ?? _sectionVersion.section);

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
              Container(margin: _marginInsets, padding: textPadding, color: sectionColor, child: _editTextField),
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
                    style: _chordTextStyle,
                  )
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  //  section delete
                  _editTooltip(
                    'Delete this section',
                    InkWell(
                      child: Icon(
                        Icons.delete,
                        size: _defaultChordFontSize,
                        color: Colors.black,
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
                        child: Icon(
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
                        child: Icon(
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
    for (var mv in matchingVersions) {
      matchingVersionsString += mv.toString();
    }

    //  the section is not selected for editing, just display
    return InkWell(
      onTap: () {
        if (chordSection != null) {
          _sectionVersion = chordSection.sectionVersion;
        } else {
          _sectionVersion = SectionVersion.getDefault();
        }
        _editTextController.text = _sectionVersion.toString();
        _setEditDataPoint(editDataPoint);
      },
      child: Container(
          margin: _marginInsets,
          padding: textPadding,
          color: sectionColor,
          child: _editTooltip(
              'modify or delete the section',
              Text(
                matchingVersionsString,
                style: _chordBoldTextStyle,
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
      return Text('null');
    }
    Measure? measure;
    if (measureNode.getMeasureNodeType() == MeasureNodeType.measure) {
      measure = measureNode as Measure;
    }

    Color color = GuiColors.getColorForSection(editDataPoint.location?.sectionVersion?.section);

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
          style: _chordBoldTextStyle,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            hintText: (_editTextController.text.isEmpty &&
                    (_selectedEditDataPoint?._measureEditType == MeasureEditType.replace))
                //  fixme: delete of last measure in section should warn about second delete
                ? 'Second delete will delete this measure'
                : 'Enter the measure.',
            contentPadding: EdgeInsets.all(_defaultFontSize / 2),
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

      Widget _majorChordButton = _editTooltip(
          'Enter the major chord.',
          _AppContainedButton(
            _keyChordNote.toString(),
            onPressed: () {
              setState(() {
                _updateChordText(_keyChordNote.toMarkup());
              });
            },
          ));
      Widget minorChordButton;
      {
        ScaleChord sc = ScaleChord(
          _keyChordNote,
          ChordDescriptor.minor,
        );
        minorChordButton = _editTooltip(
            'Enter the minor chord.',
            _AppContainedButton(
              sc.toString(),
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
            _AppContainedButton(
              sc.toString(),
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
        _otherChordDropDownMenuList.add(DropdownMenuItem<ScaleChord>(
          child: Row(
            children: <Widget>[
              Text(
                "Other chords",
              ),
            ],
          ),
        ));
        for (ChordDescriptor cd in ChordDescriptor.otherChordDescriptorsOrdered) {
          ScaleChord sc = ScaleChord(_keyChordNote, cd);
          _otherChordDropDownMenuList.add(DropdownMenuItem<ScaleChord>(
            key: ValueKey('scaleChord' + sc.toString()),
            value: sc,
            child: Row(
              children: <Widget>[
                Text(
                  sc.toMarkup(),
                  style: _textStyle,
                ),
              ],
            ),
          ));
        }
      }

      List<DropdownMenuItem<ScaleNote>> _slashNoteDropDownMenuList = [];
      {
        // other chords
        _slashNoteDropDownMenuList.add(DropdownMenuItem<ScaleNote>(
          child: Row(
            children: <Widget>[
              Text(
                "/note",
              ),
            ],
          ),
        ));
        for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
          ScaleNote sc = _key.getScaleNoteByHalfStep(i);
          _slashNoteDropDownMenuList.add(DropdownMenuItem<ScaleNote>(
            key: ValueKey('scaleNote' + sc.toString()),
            value: sc,
            child: Row(
              children: <Widget>[
                Text(
                  sc.toMarkup(),
                  style: _textStyle,
                ),
              ],
            ),
          ));
        }
      }

      return Container(
          color: color,
          width: _entryWidth,
          margin: _marginInsets,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                //  measure edit text field
                Container(
                  margin: EdgeInsets.all(2),
                  color: sectionColor,
                  child: _editTextField,
                ),
                if (_measureEntryCorrection != null)
                  Container(
                    margin: _doubleMarginInsets,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                      Text(
                        _measureEntryCorrection ?? '',
                        style: _measureEntryValid ? _chordBoldTextStyle : _chordBadTextStyle,
                      ),
                    ]),
                  ),
                //  measure edit chord selection
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
                  _editTooltip(
                    'Select other notes from the key scale.',
                    DropdownButton<ScaleNote>(
                      items: _keyChordDropDownMenuList,
                      onChanged: (value) {
                        setState(() {
                          if (value != null) {
                            _keyChordNote = value;
                          }
                        });
                      },
                      value: _keyChordNote,
                      style: _buttonTextStyle,
                    ),
                  ),
                  _majorChordButton,
                  minorChordButton,
                  dominant7ChordButton,
                  _editTooltip(
                    'Enter a silent chord.',
                    _AppContainedButton(
                      'X',
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
                      DropdownButton<ScaleChord>(
                        items: _otherChordDropDownMenuList,
                        onChanged: (_value) {
                          setState(() {
                            _updateChordText(_value?.toMarkup());
                          });
                        },
                        style: _textStyle,
                      ),
                    ),
                    _editTooltip(
                      'Select a slash note',
                      DropdownButton<ScaleNote>(
                        items: _slashNoteDropDownMenuList,
                        onChanged: (_value) {
                          setState(() {
                            _updateChordText('/' + (_value?.toMarkup() ?? ''));
                          });
                        },
                        style: _textStyle,
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
                            child: Icon(
                              Icons.delete,
                              size: _defaultChordFontSize,
                              color: Colors.black,
                            ),
                            onTap: () {
                              _performDelete();
                            },
                          ),
                        ),
                      if (_measureEntryValid)
                        _editTooltip(
                          'Accept the modification and extend the row.',
                          InkWell(
                            child: Icon(
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
                            child: Icon(
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
                            child: Icon(
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
          padding: textPadding,
          color: color,
          child: _editTooltip(
              'modify or delete the measure',
              Text(
                '${measure?.transpose(_key, _transpositionOffset) ?? ' '}',
                //measure?.transpose(_key, _transpositionOffset) ?? ' ',
                style: _chordBoldTextStyle,
              ))),
    );
  }

  Widget _repeatEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode? measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null || !measureNode.isRepeat()) {
      return Text('is not repeat: ${editDataPoint.location}: "$measureNode"');
    }
    MeasureRepeat repeat = measureNode as MeasureRepeat;

    Color color = GuiColors.getColorForSection(editDataPoint.location?.sectionVersion?.section);

    if (_selectedEditDataPoint == editDataPoint) {
      return Container(
        color: color,
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
                    style: _textStyle,
                  ),
                  _AppContainedButton(
                    'x2',
                    onPressed: () {
                      _song.setRepeat(editDataPoint.location!, 2);
                      _undoStackPush();
                      _performMeasureEntryCancel();
                    },
                    color: color,
                  ),
                  _AppContainedButton(
                    'x3',
                    onPressed: () {
                      _song.setRepeat(editDataPoint.location!, 3);
                      _undoStackPush();
                      _performMeasureEntryCancel();
                    },
                    color: color,
                  ),
                  _AppContainedButton(
                    'x4',
                    onPressed: () {
                      _song.setRepeat(editDataPoint.location!, 4);
                      _undoStackPush();
                      _performMeasureEntryCancel();
                    },
                    color: color,
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
                              child: Icon(
                                Icons.delete,
                                size: _defaultChordFontSize,
                                color: Colors.black,
                              ),
                              onTap: () {
                                throw 'fix repeat delete';
                                // _deleteMeasure();
                                // _clearChordEditing();
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

    //  not editing this measureNode
    return InkWell(
      onTap: () {
        _setEditDataPoint(editDataPoint);
      },
      child: Container(
          margin: _marginInsets,
          padding: textPadding,
          color: color,
          child: _editTooltip(
              'modify or delete the measureNode',
              Text(
                'x${repeat.repeats}',
                style: _chordBoldTextStyle,
              ))),
    );
  }

  Widget _markerEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode? measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null || !measureNode.isComment()) {
      return Text('is not comment: ${editDataPoint.location}: "$measureNode"');
    }

    Color color = GuiColors.getColorForSection(editDataPoint.location?.sectionVersion?.section);

    //  not editing this measureNode
    return InkWell(
      onTap: () {
        _setEditDataPoint(editDataPoint);
      },
      child: Container(
          margin: _marginInsets,
          padding: textPadding,
          color: color,
          child: _editTooltip(
              'modify or delete the measureNode',
              Text(
                measureNode.toString(),
                style: _chordBoldTextStyle,
              ))),
    );
  }

  void _updateChordText(final String? s) {
    logger.d('_updateChordText(${s.toString()})');

    if (s == null) return;
    String text = _editTextController.text;
    _editTextFieldFocusNode?.requestFocus();

    if (_lastEditTextSelection == null) {
      //  append the string
      _editTextController.text = text + s;
      return;
    }
    logger.d('_updateChordText: (${_lastEditTextSelection!.baseOffset.toString()},'
        '${_lastEditTextSelection!.extentOffset.toString()}): "$text"');

    if (_lastEditTextSelection!.baseOffset < 0) {
      //  append the string
      _editTextController.text = text + s;
      int len = text.length + s.length;
      _editTextController.selection = _lastEditTextSelection!.copyWith(baseOffset: len, extentOffset: len);
      return;
    } else {
      logger.d('>=0: "${text.substring(0, _lastEditTextSelection!.baseOffset)}"'
          '+"$s"'
          '+"${text.substring(_lastEditTextSelection!.extentOffset)}"');

      _editTextController.text = text.substring(0, _lastEditTextSelection!.baseOffset) +
          s +
          text.substring(_lastEditTextSelection!.extentOffset);
      int len = _lastEditTextSelection!.baseOffset + s.length;
      _editTextController.selection = _lastEditTextSelection!.copyWith(baseOffset: len, extentOffset: len);
    }
  }

  Widget _plusMeasureEditGridDisplayWidget(_EditDataPoint editDataPoint, {String? tooltip}) {
    if (_selectedEditDataPoint == editDataPoint) {
      return _measureEditGridDisplayWidget(editDataPoint); //  let it do the heavy lifting
    }

    MeasureNode? measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null) {
      return Text('null');
    }

    return InkWell(
        onTap: () {
          _setEditDataPoint(editDataPoint);
        },
        child: Container(
            margin: appendInsets,
            padding: appendPadding,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green[100],
            ),
            child: _editTooltip(
              tooltip ?? ('add new measure on this row'),
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
      //fixme: deal with selectedSectionVersion;
      DropdownMenuItem<SectionVersion> dropdownMenuItem = DropdownMenuItem<SectionVersion>(
        value: sectionVersion,
        child: Container(
          color: GuiColors.getColorForSection(sectionVersion.section),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${sectionVersion.toString()}',
                style: _chordTextStyle,
              ),
              Text(
                '${sectionVersion.section.formalName} '
                '${sectionVersion.version == 0 ? '' : sectionVersion.version.toString()}',
                style: _chordTextStyle,
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
      style: TextStyle(
        color: GuiColors.getColorForSection(selectedSectionVersion.section),
        textBaseline: TextBaseline.alphabetic,
      ),
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
    } catch (exception) {}
    return null;
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
  Widget _editTooltip(String message, Widget child) {
    // String debug = '';
    // if (Logger.level.index <= Level.debug.index && _selectedEditDataPoint != null) {
    //   debug = '  edit: ${_selectedEditDataPoint.toString()}}';
    // }
    return Tooltip(
        // message: message + debug,
        message: message,
        child: child,
        textStyle: TextStyle(
          backgroundColor: tooltipColor,
          fontSize: _defaultChordFontSize / 2,
        ),

        //  fixme: why is this broken on web?
        //waitDuration: Duration(seconds: 1, milliseconds: 200),

        verticalOffset: 50,
        decoration: BoxDecoration(
            color: tooltipColor,
            border: Border.all(),
            borderRadius: BorderRadius.all(Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.grey, offset: Offset(8, 8), blurRadius: 10)]),
        padding: EdgeInsets.all(8));
  }

  void _undo() {
    setState(() {
      if (_undoStack.canUndo) {
        _clearErrorMessage();
        _clearMeasureEntry();
        _song = _undoStack.undo()?.copySong() ?? Song.createEmptySong();
        _undoStackLog();
        _checkSongStatus();
      } else {
        _errorMessage('cannot undo any more');
      }
    });
  }

  void _redo() {
    setState(() {
      if (_undoStack.canRedo) {
        _clearErrorMessage();
        _clearMeasureEntry();
        _song = _undoStack.redo()?.copySong() ?? Song.createEmptySong();
        _undoStackLog();
        _checkSongStatus();
      } else {
        _errorMessage('cannot redo any more');
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

  void _errorMessage(String error) {
    _errorMessageString = error;
  }

  void _clearErrorMessage() {
    _errorMessageString = null;
  }

  void _performEdit({bool done: false, bool endOfRow: false}) {
    setState(() {
      _edit(done: done, endOfRow: endOfRow);
    });
  }

  /// perform the actual edit to the song
  bool _edit({bool done: false, bool endOfRow: false}) {
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
    logger.i('pre edit: prior: $priorLocation'
        ' "${_song.findMeasureByChordSectionLocation(priorLocation)}"'
        ', done: $done'
        ', endOfRow: $endOfRow'
        ', selectedEditDataPoint: $_selectedEditDataPoint');

    //  do the edit
    if (_song.editMeasureNode(_measureEntryNode)) {
      logger.i('post edit: location: ${_song.getCurrentChordSectionLocation()} '
          '"${_song.findMeasureByChordSectionLocation(_song.getCurrentChordSectionLocation())}"'
          ', prior: $priorLocation "${_song.findMeasureByChordSectionLocation(priorLocation)}"'
          ', endOfRow: $endOfRow'
          ', selectedEditDataPoint: $_selectedEditDataPoint');

      //  clean up after edit
      ChordSectionLocation? loc = _song.getCurrentChordSectionLocation();
      switch (_selectedEditDataPoint!._measureEditType) {
        case MeasureEditType.append:
          logger.i('post append: location: ${_song.getCurrentChordSectionLocation()} '
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
            loc = loc.nextMeasureIndexLocation();
            _selectedEditDataPoint = _EditDataPoint(loc);
            _selectedEditDataPoint!._measureEditType = MeasureEditType.insert;
          } else if (_lastEditDataPoint!._measureEditType == MeasureEditType.insert ||
              _lastEditDataPoint._measureEditType == MeasureEditType.append) {
            _selectedEditDataPoint = _EditDataPoint(loc, onEndOfRow: endOfRow);
            _selectedEditDataPoint!._measureEditType = MeasureEditType.append;
          } else {
            _selectedEditDataPoint = _EditDataPoint(loc, onEndOfRow: endOfRow);
          }
        }
      }
      logger.i('_selectedEditDataPoint: $_selectedEditDataPoint');

      _checkSongStatus();

      return true;
    } else {
      logger.i('_editMeasure(): failed');
      _errorMessage('edit failed: ${_song.getMessage()}');
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
      _clearErrorMessage();
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

  _checkSongStatus() {
    bool isDirty = _song != _originalSong;
    if (isDirty != _isDirty) {
      setState(() {
        _isDirty = isDirty;
      });
    }
  }

  String _listSections() {
    var sb = StringBuffer();
    var first = true;
    for (var s in Section.values) {
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
    for (var s in Section.values) {
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

  Song _song;
  Song _originalSong;
  bool _isDirty = false;
  songs.Key _key = songs.Key.getDefault();
  double _appendFontSize = 14;
  double _chordFontSize = 14;

  _EditDataPoint? _selectedEditDataPoint;

  int _transpositionOffset = 0;

  bool _measureEntryIsClear = true;
  String? _measureEntryCorrection;
  bool _measureEntryValid = false;
  String? _errorMessageString;

  MeasureNode? _measureEntryNode;

  TextStyle _chordBoldTextStyle = TextStyle();
  TextStyle _chordTextStyle = TextStyle();
  EdgeInsets _marginInsets = EdgeInsets.all(4);
  EdgeInsets _doubleMarginInsets = EdgeInsets.all(8);
  static const EdgeInsets textPadding = EdgeInsets.all(6);
  Color sectionColor = _defaultColor;
  static const EdgeInsets appendInsets = EdgeInsets.all(0);
  static const EdgeInsets appendPadding = EdgeInsets.all(0);

  TextStyle _chordBadTextStyle = TextStyle();

  TextField? _editTextField;

  TextEditingController _editTextController = TextEditingController();
  FocusNode? _editTextFieldFocusNode;
  TextSelection? _lastEditTextSelection;
  int _tableKeyId = 0;

  LyricsTable _lyricsTable = LyricsTable();
  bool _lyricsAreDirty = false;
  List<_LyricsTextField> _lyricsTextFields = [];

  bool _showHints = false;

  SectionVersion _sectionVersion = SectionVersion.getDefault();
  ScaleNote _keyChordNote = songs.Key.getDefault().getKeyScaleNote();

  List<DropdownMenuItem<ScaleNote>> _keyChordDropDownMenuList = [];

  List<ChangeNotifier> _disposeList = []; //  fixme: workaround to dispose the text controllers

  UndoStack<Song> _undoStack = UndoStack();

  static const tooltipColor = Color(0xFFE8F5E9);
}

class _LyricsTextField extends TextField {
  _LyricsTextField(
    this.lyricSection, {
    controller,
    style,
    decoration,
    onSubmitted,
    onEditingComplete,
    onChanged,
  }) : super(
            controller: controller,
            style: style,
            decoration: decoration,
            onSubmitted: onSubmitted,
            onEditingComplete: onEditingComplete,
            onChanged: onChanged);
  final LyricSection lyricSection;
}

//  internal class to hold handy data for each point in the chord section edit display
class _EditDataPoint {
  _EditDataPoint(this.location, {this.onEndOfRow: false});

  _EditDataPoint.byMeasureNode(final Song song, this.measureNode, {this.onEndOfRow: false}) {
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

    if (!(other is _EditDataPoint)) {
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
c:a b c d, d c g g
C: C G D A, E E E E

 */
