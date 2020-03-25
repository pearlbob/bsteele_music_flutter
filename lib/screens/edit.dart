import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/songs/chordComponent.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/chordSection.dart';
import 'package:bsteeleMusicLib/songs/chordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as songs;
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:bsteeleMusicLib/songs/measureNode.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/songs/sectionVersion.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songBase.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteele_music_flutter/gui.dart';
import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

///   screen to edit a song
class Edit extends StatefulWidget {
  const Edit({Key key, @required this.song}) : super(key: key);

  @override
  _Edit createState() => _Edit();

  final Song song;
}

const double _defaultChordFontSize = 48;
const double _defaultFontSize = _defaultChordFontSize / 2;
final TextStyle _boldTextStyle = TextStyle(
    fontSize: _defaultFontSize, fontWeight: FontWeight.bold, color: Colors.black87, backgroundColor: Colors.grey[100]);
final TextStyle _labelTextStyle = TextStyle(fontSize: _defaultFontSize, fontWeight: FontWeight.bold);
const TextStyle _buttonTextStyle = TextStyle(fontSize: _defaultFontSize, fontWeight: FontWeight.bold);
final TextStyle _textStyle = TextStyle(fontSize: _defaultFontSize, color: Colors.grey[800]);
const TextStyle _errorTextStyle = TextStyle(fontSize: _defaultFontSize, color: Colors.red);
const double _entryWidth = 750;

const Color _defaultColor = Color(0xFFB3E5FC); //Colors.lightBlue[100];


/// helper class to manage a RaisedButton
class _AppContainedButton extends RaisedButton {
  _AppContainedButton(
    String text, {
    VoidCallback onPressed,
    Color color = _defaultColor,
  }) : super(
          shape: new RoundedRectangleBorder(
            borderRadius: new BorderRadius.circular(12.0),
          ),
          color: color,
          textColor: Colors.black,
          disabledTextColor: Colors.grey[400],
          disabledColor: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            style: _buttonTextStyle,
          ),
          onPressed: onPressed,
        );
}

/// helper class to manage an OutlineButton
class AppOutlineButton extends OutlineButton {
  AppOutlineButton(
    String _text, {
    VoidCallback onPressed,
    Color color = _defaultColor,
  }) : super(
          shape: new RoundedRectangleBorder(
            borderRadius: new BorderRadius.circular(12.0),
          ),
          color: color,
          textColor: Colors.black87,
          disabledTextColor: Colors.grey[400],
          borderSide: BorderSide(width: 1.66, color: Colors.black54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: new Text(
            _text,
            style: _buttonTextStyle,
          ),
          onPressed: onPressed,
        );
}

class _Edit extends State<Edit> {
  @override
  initState() {
    super.initState();

    _key = widget.song.key;
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
        switch (_editTextController.text[_editTextController.text.length - 1]) {
          case ' ':
            //  space means move on to the next measure
            _editMeasure();
            break;
          //  look for TextField.onSubmitted() for end of entry
        }
      }

      logger.d('chordTextController: "${_editTextController.text}"');
    });
  }

  @override
  void dispose() {
    _editTextController.dispose();
    _editTextFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    logger.d('edit build: ${_keyChordNote.toString()}');

    ScreenInfo screenInfo = ScreenInfo(context);
    final double _screenWidth = screenInfo.mediaWidth;

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

    _song = widget.song;

    //  build a list of section version numbers
    if (_sectionVersionDropdownMenuList == null) {
      _sectionVersionDropdownMenuList = List();
      for (int i = 0; i <= 9; i++) {
        _sectionVersionDropdownMenuList.add(
          DropdownMenuItem<int>(
            key: ValueKey('sectionVersion' + i.toString()),
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
    }

    //  build the chords display based on the song chord section grid
    {
      logger.d("size: " + MediaQuery.of(context).size.toString());

      //  build the table from the song chord section grid
      Grid<ChordSectionLocation> grid = _song.getChordSectionLocationGrid();
      Grid<_EditDataPoint> editDataPoints = Grid();

      if (grid.isNotEmpty) {
        {
          List<TableRow> rows = List();
          List<Widget> children = List();
          sectionColor = GuiColors.getColorForSection(Section.get(SectionEnum.chorus));

          //  compute transposition offset from base key
          _transpositionOffset = 0; //_key.getHalfStep() - _song.getKey().getHalfStep();

          int maxCols = 0;
          {
            for (int r = 0; r < grid.getRowCount(); r++) {
              List<ChordSectionLocation> row = grid.getRow(r);
              maxCols = max(maxCols, row.length);
            }
          }
          maxCols *= 2; //  add the plus markers

          //  keep track of the section
          SectionVersion lastSectionVersion;

          //  map the song moment grid to a flutter table, one row at a time
          for (int r = 0; r < grid.getRowCount(); r++) {
            List<ChordSectionLocation> row = grid.getRow(r);

            //  assume col 0 has at least a chord section in it
            if (row.length < 1) {
              continue;
            }

            ChordSectionLocation firstChordSectionLocation;
            //       String columnFiller;
            _marginInsets = EdgeInsets.all(_chordFontSize / 4);

            //  find the first col with data
            //  should normally be col 1 (i.e. the second col)
            //  use its section version for the row
            {
              for (ChordSectionLocation loc in row)
                if (loc == null)
                  continue;
                else {
                  firstChordSectionLocation = loc;
                  break;
                }
              if (firstChordSectionLocation == null) continue;

              SectionVersion sectionVersion = firstChordSectionLocation.sectionVersion;

              if (sectionVersion != lastSectionVersion) {
                //  add the section heading
                //           columnFiller = sectionVersion.toString();
                sectionColor = GuiColors.getColorForSection(sectionVersion.section);
                lastSectionVersion = sectionVersion;
              }
            }

            {
              //  for each column of the song grid, create the appropriate widget
              for (int c = 0; c < row.length; c++) {
                ChordSectionLocation loc = row[c];
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
                } else {
                  w = _nullEditGridDisplayWidget();
                }
                children.add(w);
                editDataPoint.widget = w;
                editDataPoints.set(r, c * 2, editDataPoint);

                //  + elements
                editDataPoint = _EditDataPoint(loc);
                editDataPoint.measureEditType = MeasureEditType.append; //  default
                if (loc == null) {
                  if (c == 0 && row.length > 1) {
                    editDataPoint.measureEditType = MeasureEditType.insert;
                    editDataPoint.location = row[1];
                    w = _plusMeasureEditGridDisplayWidget(editDataPoint);
                  } else {
                    w = _nullEditGridDisplayWidget();
                  }
                } else if (loc.isSection) {
                  if (c == 0) {
                    if (row.length > 1) {
                      editDataPoint.measureEditType = MeasureEditType.insert;
                      editDataPoint.location = row[1];
                      w = _plusMeasureEditGridDisplayWidget(editDataPoint);
                    } else {
                      editDataPoint.measureEditType = MeasureEditType.append;
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
                editDataPoint.widget = w;
                editDataPoints.set(r, c * 2 + 1, editDataPoint);
              }

              //  add children to max columns to keep the table class happy
              while (children.length < maxCols) {
                children.add(Container());
              }

              //  add row to table
              rows.add(TableRow(key: ValueKey('element' + r.toString()), children: children));

              //  get ready for the next row by clearing the row data
              children = List();
            }
          }

          //  add the append for new sections
          {
            children.add(Container(
                margin: _marginInsets,
                padding: textPadding,
                color: Colors.green[100],
                child: _EditTooltip('add new section here',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _song.setCurrentChordSectionLocation(null);
                          _song.setCurrentMeasureEditType(MeasureEditType.append);
                          ChordSection cs = _suggestNewSection();
                          if (_song.editMeasureNode(cs)) {
                            _clearChordEditing();
                            _selectedEditDataPoint = _EditDataPoint.byMeasureNode(_song, cs);
                            logger.v(_song.toMarkup());
                          }
                        });
                      },
                      child: Icon(
                        Icons.add,
                        size: _chordFontSize,
                      ),
                    ))));

            while (children.length < maxCols) {
              children.add(Container());
            }

            //  add row to table
            rows.add(TableRow(key: ValueKey('rowNewSectionAppend'), children: children));
          }

          _table = Table(
            defaultColumnWidth: IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: rows,
          );

          logger.v(editDataPoints.toMultiLineString());
        }
      }
    }

    {
      //  list the notes required
      List<ScaleNote> scaleNotes = List();

      //  scale notes
      for (int i = 0; i < MusicConstants.notesPerScale; i++) scaleNotes.add(_key.getMajorScaleByNote(i));

      //  not scale notes
      for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
        ScaleNote scaleNote = _key.getScaleNoteByHalfStep(i);
        if (!scaleNotes.contains(scaleNote)) scaleNotes.add(scaleNote);
      }

      //  make the key selection drop down list
      _keyChordDropDownMenuList = List();
      for (ScaleNote scaleNote in scaleNotes) {
        String s = scaleNote.toString();
        String label = s +
            (s.length < 2 ? "   " : " ") +
            ChordComponent.getByHalfStep(scaleNote.halfStep - _key.getHalfStep()).shortName;
        DropdownMenuItem<ScaleNote> item =
            DropdownMenuItem(key: ValueKey('scaleNote' + scaleNote.toString()), value: scaleNote, child: Text(label));
        _keyChordDropDownMenuList.add(item);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              AppBar(
                //  let the app bar scroll off the screen for more room for the song
                title: Text(
                  'Edit',
                  style: TextStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
              ),
              SizedBox(height: 10),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Text('enter song button here'),
                    Container(
                      child: Text(_errorMessage ?? '', style: _errorTextStyle),
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
                              label: Text(
                                '',
                                style: _boldTextStyle,
                              ),
                              onPressed: () {},
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
                              onPressed: () {},
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
                    Container(
                      width: 800.0,
                      child: TextField(
                        controller: TextEditingController(text: _song.title),
                        decoration: InputDecoration(
                          hintText: 'Enter the song title.',
                        ),
                        maxLength: null,
                        style: TextStyle(fontSize: _defaultChordFontSize, fontWeight: FontWeight.bold),
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
                    Container(
                      width: 800.0,
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
                    Container(
                      width: 800.0,
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
                    Container(
                      width: 800.0,
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
                            '${value.toString()} ${value.sharpsFlatsToString()}',
                            style: _boldTextStyle,
                          ),
                        );
                      }).toList(),
                      onChanged: (_value) {
                        setState(() {
                          _key = _value;
                          _keyChordNote = _key.getKeyScaleNote();
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
              Text(
                "Chords:",
                style: _labelTextStyle,
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: EdgeInsets.only(right: 24, bottom: 24.0),
                  child: Column(children: <Widget>[
                    _table,
                  ]),
                ),
              ),
              Container(
                padding: EdgeInsets.only(right: 24, bottom: 24.0),
                child: Column(children: <Widget>[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                    Text(
                      ' Recent: ',
                      style: _textStyle,
                    ),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                    Text(
                      ' Frequent: ',
                      style: _textStyle,
                    ),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                    Text(
                      ' Repeats: ',
                      style: _textStyle,
                    ),
                    AppOutlineButton(
                      'No Repeat',
                    ),
                    AppOutlineButton(
                      'Repeat x2',
                    ),
                    AppOutlineButton(
                      'Repeat x3',
                    ),
                    AppOutlineButton(
                      'Repeat x4',
                    ),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                    Text(
                      ' Extras: ',
                      style: _textStyle,
                    ),
                    AppOutlineButton(
                      'Undo',
                    ),
                    AppOutlineButton(
                      'Redo',
                    ),
                    AppOutlineButton(
                      '4/Row',
                    ),
                    AppOutlineButton('Hints', onPressed: () {
                      _showHints = !_showHints;
                      setState(() {});
                    }),
                  ]),
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
                            ' Section types can be followed with a digit to indicate a variation.\n\n',
                        style: _textStyle,
                      ),
                      TextSpan(
                        text: 'Sections with the same content will automatically be placed in the same declaration.'
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
                        text: '''Using a lower case b for a flat will work. A sharp sign (#) works as a sharp.\n\n''',
                        style: _textStyle,
                      ),
                      TextSpan(
                        text: 'Notice that this can get problematic around the lower case b. Should the entry "bbm7"'
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
                        text: 'Periods (.) can be used to repeat chords on another beat within the same meausure. For'
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
                        text: 'Since you can enter the return key to format your entry, you must us the Enter button'
                            ' to enter it into the song.\n\n',
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
                        text: 'Control plus the arrow keys can help navigate in the chord entry once selected.\n\n',
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
              TextField(
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter the song\'s lyrics by chord section. Required.',
                  //  fixme
                  hintStyle: TextStyle(
                      fontSize: _defaultFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      backgroundColor: Colors.grey[100]),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                style: _boldTextStyle,
                maxLines: 80,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nullEditGridDisplayWidget() {
    return Text(
      '',
    );
  }

  Widget _sectionEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null) {
      return Text('null');
    }

    if (measureNode.getMeasureNodeType() != MeasureNodeType.section) return Text('not_section');

    ChordSection chordSection = measureNode as ChordSection;
    if (_selectedEditDataPoint == editDataPoint) {
      //  we're editing the section
      if (_editTextField == null) {
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
            _editMeasure();
          },
        );
      }

      SectionVersion entrySectionVersion = _parsedSectionEntry(_editTextController.text);
      bool isValidSectionEntry = (entrySectionVersion != null);
      Color color = isValidSectionEntry ? Colors.black87 : Colors.red;
      sectionColor = GuiColors.getColorForSection(isValidSectionEntry ? entrySectionVersion.section : _section);

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
                  DropdownButton<Section>(
                    items: _sectionDropdownList(),
                    onChanged: (_value) {
                      setState(() {
                        _section = _value;
                        _editTextController.text =
                            _section.toString() + (_sectionVersion == 0 ? '' : _sectionVersion.toString()) + ':';
                      });
                    },
                    value: _section,
                    style: TextStyle(
                      color: color,
                      textBaseline: TextBaseline.alphabetic,
                    ),
                  ),
                  //  section version selection
                  DropdownButton<int>(
                    value: _sectionVersion,
                    items: _sectionVersionDropdownMenuList,
                    onChanged: (value) {
                      setState(() {
                        _sectionVersion = value;
                        _editTextController.text =
                            _section.toString() + (_sectionVersion == 0 ? '' : _sectionVersion.toString()) + ':';
                      });
                      logger.v('_sectionVersion = ${_sectionVersion.toString()}');
                    },
                    style: _chordTextStyle,
                  )
                ],
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    //  section delete
                    _EditTooltip(
                      'Delete this section',
                      child: InkWell(
                        child: Icon(
                          Icons.delete,
                          size: _defaultChordFontSize,
                          color: Colors.black,
                        ),
                        onTap: () {
                          _clearChordEditing();
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        //  section enter
                        if (isValidSectionEntry)
                          _EditTooltip(
                            'Accept the modification',
                            child: InkWell(
                              child: Icon(
                                Icons.check,
                                size: _defaultChordFontSize,
                              ),
                              onTap: () {
                                _editMeasure();
                              },
                            ),
                          ),
                        //  section entry cancel
                        _EditTooltip(
                          'Cancel the modification',
                          child: InkWell(
                            child: Icon(
                              Icons.cancel,
                              size: _defaultChordFontSize,
                              color: color,
                            ),
                            onTap: () {
                              _clearChordEditing();
                            },
                          ),
                        ),
                      ],
                    ),
                  ])
            ]),
      );
    }

    //  the section is not selected for editing, just display
    return InkWell(
      onTap: () {
        if (chordSection != null) {
          _section = chordSection.sectionVersion.section;
          _sectionVersion = chordSection.sectionVersion.version;
        }
        _editTextController.text = _section.toString() + (_sectionVersion == 0 ? '' : _sectionVersion.toString()) + ':';
        _setEditDataPoint(editDataPoint);
      },
      child: Container(
          margin: _marginInsets,
          padding: textPadding,
          color: sectionColor,
          child: _EditTooltip('modify or delete the section',
              child: Text(
                chordSection.sectionVersion.toString(),
                style: _chordBoldTextStyle,
              ))),
    );
  }

  Widget _measureEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null) {
      return Text('null');
    }
    Measure measure;
    if (measureNode.getMeasureNodeType() == MeasureNodeType.measure) measure = measureNode as Measure;

    Color color = GuiColors.getColorForSection(editDataPoint.location.sectionVersion.section);

    if (_selectedEditDataPoint == editDataPoint) {
      //  editing this measure
      logger.d('pre : (${_editTextController.selection.baseOffset},${_editTextController.selection.extentOffset})');
      if (_editTextField == null) {
        _editTextField = TextField(
          controller: _editTextController,
          focusNode: _editTextFieldFocusNode,
          maxLength: null,
          style: _chordBoldTextStyle,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            hintText: 'Enter the measure.',
          ),
          autofocus: true,
          enabled: true,
          onSubmitted: (_) {
            _editMeasure();
          },
        );
      }

      logger.d('post: (${_editTextController.selection.baseOffset},${_editTextController.selection.extentOffset})');

      if (_measureEntry == null) {
        _measureEntry = measure?.toMarkupWithEnd(null);
        _measureEntryValid = true; //  should always be!... at least at this moment

        _editTextController.text = _measureEntry;
        _editTextController.selection = TextSelection(baseOffset: 0, extentOffset: _measureEntry?.length??0);
        logger.d(
            'post initial fill: (${_editTextController.selection.baseOffset},${_editTextController.selection.extentOffset})');
      }

      _AppContainedButton _majorChordButton = _AppContainedButton(
        _keyChordNote.toString(),
        onPressed: () {
          setState(() {
            _updateChordText(_keyChordNote.toMarkup());
          });
        },
        color: color,
      );
      _AppContainedButton _minorChordButton;
      {
        ScaleChord sc = ScaleChord(
          _keyChordNote,
          ChordDescriptor.minor,
        );
        _minorChordButton = _AppContainedButton(
          sc.toString(),
          onPressed: () {
            setState(() {
              _updateChordText(sc.toMarkup());
            });
          },
          color: color,
        );
      }
      _AppContainedButton _dominant7ChordButton;
      {
        ScaleChord sc = ScaleChord(_keyChordNote, ChordDescriptor.dominant7);
        _dominant7ChordButton = _AppContainedButton(
          sc.toString(),
          onPressed: () {
            setState(() {
              _updateChordText(sc.toMarkup());
            });
          },
          color: color,
        );
      }

      List<DropdownMenuItem<ScaleChord>> _otherChordDropDownMenuList = List();
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
          ScaleChord sc = new ScaleChord(_keyChordNote, cd);
          _otherChordDropDownMenuList.add(DropdownMenuItem<ScaleChord>(
            key: ValueKey('scaleChord' + sc.toString()),
            value: sc,
            child: Row(
              children: <Widget>[
                Text(
                  sc.toString(),
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
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              //  measure edit text field
              Container(margin: _marginInsets, padding: textPadding, color: sectionColor, child: _editTextField),
              if (_measureEntryCorrection != null)
                Text(
                  _measureEntryCorrection,
                  style: _measureEntryValid ? _chordBoldTextStyle : _chordBadTextStyle,
                ),
              //  measure edit chord selection
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                Text(
                  'Note: ',
                  style: _textStyle,
                ),
                DropdownButton<ScaleNote>(
                  items: _keyChordDropDownMenuList,
                  onChanged: (_value) {
                    setState(() {
                      _keyChordNote = _value;
                    });
                  },
                  value: _keyChordNote,
                  style: _textStyle,
                ),
                _majorChordButton,
                _minorChordButton,
                _dominant7ChordButton,
                DropdownButton<ScaleChord>(
                  items: _otherChordDropDownMenuList,
                  onChanged: (_value) {
                    setState(() {
                      _updateChordText(_value.toMarkup());
                    });
                  },
                  style: _textStyle,
                ),
                _AppContainedButton(
                  'X',
                  onPressed: () {
                    setState(() {
                      _updateChordText('X');
                    });
                  },
                  color: color,
                ),
              ]),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        if (measure != null)
                          _EditTooltip(
                            'Delete this measure',
                            child: InkWell(
                              child: Icon(
                                Icons.delete,
                                size: _defaultChordFontSize,
                                color: Colors.black,
                              ),
                              onTap: () {
                                _deleteMeasure();
                                _clearChordEditing();
                              },
                            ),
                          ),
                      ],
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          if (_measureEntryValid)
                            _EditTooltip(
                              'Accept the modification',
                              child: InkWell(
                                child: Icon(
                                  Icons.check,
                                  size: _defaultChordFontSize,
                                ),
                                onTap: () {
                                  _editMeasure();
                                },
                              ),
                            ),
                          _EditTooltip(
                            'Cancel the modification',
                            child: InkWell(
                              child: Icon(
                                Icons.cancel,
                                size: _defaultChordFontSize,
                                color: _measureEntryValid ? Colors.black : Colors.red,
                              ),
                              onTap: () {
                                _clearChordEditing();
                              },
                            ),
                          ),
                        ]),
                  ])
            ]),
      );
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
          child: _EditTooltip('modify or delete the measure',
              child: Text(
                measure?.transpose(_key, _transpositionOffset) ?? '',
                style: _chordBoldTextStyle,
              ))),
    );
  }

//  Widget _repeatEditGridDisplayWidget(_EditDataPoint editDataPoint) {
//    Measure measure = _song.findMeasureNodeByLocation(editDataPoint.location) as Measure;
//    if (measure == null || !measure.isRepeat()) {
//      return Text('null');
//    }
//
//    MeasureRepeat repeat = measure as MeasureRepeat;
//    Color color = GuiColors.getColorForSection(editDataPoint.location.sectionVersion.section);
//
//    if (_selectedEditDataPoint == editDataPoint) {
//      return Container(
//        color: color,
//        width: _entryWidth,
//        child: Column(
//            mainAxisAlignment: MainAxisAlignment.spaceAround,
//            crossAxisAlignment: CrossAxisAlignment.start,
//            textDirection: TextDirection.ltr,
//            children: <Widget>[
//              //  repeat label
//              Text(
//                'x' + repeat.repeats.toString(),
//                style: _chordBoldTextStyle,
//              ),
//              //  measure edit chord selection
//              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
//                Text(
//                  'Repeat: ',
//                  style: _textStyle,
//                ),
//                AppContainedButton(
//                  'x2',
//                  onPressed: () {
//                    setState(() {});
//                  },
//                  color: color,
//                ),
//                AppContainedButton(
//                  'x3',
//                  onPressed: () {
//                    setState(() {});
//                  },
//                  color: color,
//                ),
//                AppContainedButton(
//                  'x4',
//                  onPressed: () {
//                    setState(() {});
//                  },
//                  color: color,
//                ),
//              ]),
//              Row(
//                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                  crossAxisAlignment: CrossAxisAlignment.center,
//                  children: <Widget>[
//                    Row(
//                      mainAxisAlignment: MainAxisAlignment.start,
//                      crossAxisAlignment: CrossAxisAlignment.end,
//                      children: <Widget>[
//                        EditTooltip(
//                          'Delete this repeat',
//                          child: InkWell(
//                            child: Icon(
//                              Icons.delete,
//                              size: _defaultChordFontSize,
//                              color: Colors.black,
//                            ),
//                            onTap: () {
//                              _deleteMeasure();
//                              _clearChordEditing();
//                            },
//                          ),
//                        ),
//                      ],
//                    ),
//                    Row(
//                        mainAxisAlignment: MainAxisAlignment.end,
//                        crossAxisAlignment: CrossAxisAlignment.end,
//                        children: <Widget>[
//                          EditTooltip(
//                            'Accept the modification',
//                            child: InkWell(
//                              child: Icon(
//                                Icons.check,
//                                size: _defaultChordFontSize,
//                              ),
//                              onTap: () {
//                                _editMeasure();
//                              },
//                            ),
//                          ),
//                          EditTooltip(
//                            'Cancel the modification',
//                            child: InkWell(
//                              child: Icon(
//                                Icons.cancel,
//                                size: _defaultChordFontSize,
//                                color: _measureEntryValid ? Colors.black : Colors.red,
//                              ),
//                              onTap: () {
//                                _clearChordEditing();
//                              },
//                            ),
//                          ),
//                        ]),
//                  ])
//            ]),
//      );
//    }
//
//    //  not editing this measure
//    return InkWell(
//      onTap: () {
//        _setEditDataPoint(editDataPoint);
//      },
//      child: Container(
//          margin: _marginInsets,
//          padding: textPadding,
//          color: color,
//          child: EditTooltip('modify or delete the measure',
//              child: Text(
//                measure.transpose(_key, _tranOffset),
//                style: _chordBoldTextStyle,
//              ))),
//    );
//  }

  void _updateChordText(final String s) {
    if (s == null) return;
    String text = _editTextController.text;
    if (text == null) {
      text = '';
    }
    if (_lastEditTextSelection == null) {
      //  append the string
      _editTextController.text = text + s;
      logger.d('<0: "$text"');
      _editTextFieldFocusNode.requestFocus();
      return;
    }
    logger.d('_updateChordText: (${_lastEditTextSelection.baseOffset.toString()},'
        '${_lastEditTextSelection.extentOffset.toString()}): "$text"');

    if (_lastEditTextSelection.baseOffset < 0) {
      //  append the string
      _editTextController.text = text + s;
      int len = text.length + s.length;
      _editTextController.selection = _lastEditTextSelection.copyWith(baseOffset: len, extentOffset: len);
      logger.d('<0: "$text"');
      return;
    } else {
      logger.d('>=0: "${text.substring(0, _lastEditTextSelection.baseOffset)}"'
          '+"$s"'
          '+"${text.substring(_lastEditTextSelection.extentOffset)}"');
      _editTextController.text = text.substring(0, _lastEditTextSelection.baseOffset) +
          s +
          text.substring(_lastEditTextSelection.extentOffset);
      int len = _lastEditTextSelection.baseOffset + s.length;
      _editTextController.selection = _lastEditTextSelection.copyWith(baseOffset: len, extentOffset: len);
    }
    _editTextFieldFocusNode.requestFocus();
  }

  Widget _plusMeasureEditGridDisplayWidget(_EditDataPoint editDataPoint) {
    MeasureNode measureNode = _song.findMeasureNodeByLocation(editDataPoint.location);
    if (measureNode == null) {
      return Text('null');
    }

    if (_selectedEditDataPoint == editDataPoint) {
      return _measureEditGridDisplayWidget(editDataPoint); //  let it do the heavy lifting
    }

    return InkWell(
        onTap: () {
          _setEditDataPoint(editDataPoint);
        },
        child: Container(
            margin: appendInsets,
            padding: appendPadding,
            color: Colors.green[100],
            child: _EditTooltip(
              'add new measure',
              child: Icon(
                Icons.add,
                size: _appendFontSize,
              ),
            )));
  }

  List<DropdownMenuItem<Section>> _sectionDropdownList() {
    List<DropdownMenuItem<Section>> ret = [];

    for (SectionEnum sectionEnum in SectionEnum.values) {
      Section section = Section.get(sectionEnum);

      ret.add(
        DropdownMenuItem<Section>(
          key: ValueKey(sectionEnum),
          value: section,
          child: Text(
            '${section.toString()}:  ${section.formalName}',
            style: _chordTextStyle,
          ),
        ),
      );
    }
    return ret;
  }

  /// validate the given measure entry string
  List<MeasureNode> validateMeasureEntry(String entry) {
    List<MeasureNode> entries = widget.song.parseChordEntry(SongBase.entryToUppercase(entry));
    _measureEntryValid =
        (entries != null && entries.length == 1 && entries[0].getMeasureNodeType() != MeasureNodeType.comment);
    _measureEntryNode = (_measureEntryValid ? entries[0] : null);
    logger.d('_measureEntryValid: $_measureEntryValid');
    return entries;
  }

  SectionVersion _parsedSectionEntry(String entry) {
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

    if (widget.song == null) {
      _measureEntryCorrection = null;
      return;
    }

    String upperEntry = MeasureNode.concatMarkup(validateMeasureEntry(entry));
    upperEntry = upperEntry.trim();
    String minEntry =
        entry.trim().replaceAll("\t", " ").replaceAll(":\n", ":").replaceAll("  ", " ").replaceAll("\n", ",");
    logger.d('entry: "$minEntry" vs "$upperEntry"');
    if (upperEntry == minEntry) {
      if (_measureEntryCorrection != null) {
        setState(() {
          _table = null;
          _measureEntryCorrection = null;
        });
      }
    } else {
      setState(() {
        _table = null;
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
    for (ChordSection cs in _song.getChordSections()) {
      songSectionVersions.add(cs.sectionVersion);
    }

    //  see if one of the suggested default section versions is missing
    for (SectionVersion sv in _suggestedSectionVersions) {
      if (songSectionVersions.contains(sv)) {
        continue;
      }
      return ChordSection(sv, null);
    }

    //  see if one of the suggested numbered section versions is missing
    for (SectionVersion sv in _suggestedSectionVersions) {
      for (int i = 1; i <= 9; i++) {
        SectionVersion svn = SectionVersion(sv.section, i);
        if (songSectionVersions.contains(svn)) {
          continue;
        }
        return ChordSection(svn, null);
      }
    }

    //  punt
    return ChordSection(SectionVersion(Section.get(SectionEnum.b), 0), null);
  }

  void _editMeasure() {
    if (!_measureEntryValid) return;
    Song song = widget.song;
    song.setCurrentChordSectionLocation(_selectedEditDataPoint.location);
    song.setCurrentMeasureEditType(_selectedEditDataPoint.measureEditType);
    if (song.editMeasureNode(_measureEntryNode)) {
      _clearChordEditing();
    }
  }

  void _deleteMeasure() {
    Song song = widget.song;
    song.setCurrentChordSectionLocation(_selectedEditDataPoint.location);
    song.setCurrentMeasureEditType(MeasureEditType.delete);
    song.editMeasureNode(_measureEntryNode);
    _clearChordEditing();
  }

  void _setEditDataPoint(_EditDataPoint _editDataPoint) {
    setState(() {
      _clearMeasureEntry();
      _selectedEditDataPoint = _editDataPoint;
    });
  }

  void _clearChordEditing() {
    setState(() {
      _clearMeasureEntry();
    });
  }

  void _clearMeasureEntry() {
    _editTextField = null;
    _table = null; //  force re-display
    _selectedEditDataPoint = null;
    _measureEntry = null;
    _measureEntryCorrection = null;
    _measureEntryValid = false;
  }

  Song _song;
  songs.Key _key;
  double _appendFontSize;
  double _chordFontSize;

  Table _table;
  _EditDataPoint _selectedEditDataPoint;

  int _transpositionOffset;

  String _measureEntry;
  String _measureEntryCorrection;
  bool _measureEntryValid;
  String _errorMessage;

  MeasureNode _measureEntryNode;

  TextStyle _chordBoldTextStyle;
  TextStyle _chordTextStyle;
  EdgeInsets _marginInsets;
  static const EdgeInsets textPadding = EdgeInsets.all(6);
  Color sectionColor;
  static const EdgeInsets appendInsets = EdgeInsets.all(0);
  static const EdgeInsets appendPadding = EdgeInsets.all(0);

  TextStyle _chordBadTextStyle;

  TextField _editTextField;
  TextEditingController _editTextController = TextEditingController();
  FocusNode _editTextFieldFocusNode = FocusNode();
  TextSelection _lastEditTextSelection;

  bool _showHints = false;

  Section _section = Section.get(SectionEnum.verse);
  int _sectionVersion = 0;
  ScaleNote _keyChordNote;

  List<DropdownMenuItem<int>> _sectionVersionDropdownMenuList;
  List<DropdownMenuItem<ScaleNote>> _keyChordDropDownMenuList;
}

/// helper class to generate tool tips
class _EditTooltip extends Tooltip {
  _EditTooltip(String message, {Widget child})
      : super(
            message: message,
            child: child,
            textStyle: TextStyle(
              backgroundColor: color,
              fontSize: _defaultChordFontSize / 2,
            ),
            waitDuration: Duration(milliseconds: 1200),
            verticalOffset: 50,
            decoration: BoxDecoration(
                color: color,
                border: Border.all(),
                borderRadius: BorderRadius.all(Radius.circular(12)),
                boxShadow: [BoxShadow(color: Colors.grey, offset: Offset(8, 8), blurRadius: 10)]),
            padding: EdgeInsets.all(8));
  static const color = Color(0xFFE8F5E9);
}


//  internal class to hold handy data for each point in the chord section edit display
class _EditDataPoint {
  _EditDataPoint(this.location);

  _EditDataPoint.byMeasureNode(final Song song, final MeasureNode measureNode)
      : this(song.findChordSectionLocation(measureNode));

  @override
  String toString() {
    return super.toString() + ', loc: ${location.toString()}, editType: ${measureEditType.toString()}';
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) {
      return true;
    }
    return runtimeType == other.runtimeType && location == other.location && measureEditType == other.measureEditType;
  }

  @override
   int get hashCode => hashValues(location, measureEditType);

  ChordSectionLocation location;
  Widget widget;
  MeasureEditType measureEditType = MeasureEditType.replace; //  default
}
