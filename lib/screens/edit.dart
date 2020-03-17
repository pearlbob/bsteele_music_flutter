import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/grid.dart';
import 'package:bsteeleMusicLib/songs/ChordComponent.dart';
import 'package:bsteeleMusicLib/songs/ChordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/ChordSectionLocation.dart';
import 'package:bsteeleMusicLib/songs/Key.dart' as songs;
import 'package:bsteeleMusicLib/songs/Measure.dart';
import 'package:bsteeleMusicLib/songs/MeasureNode.dart';
import 'package:bsteeleMusicLib/songs/MusicConstants.dart';
import 'package:bsteeleMusicLib/songs/Section.dart';
import 'package:bsteeleMusicLib/songs/SectionVersion.dart';
import 'package:bsteeleMusicLib/songs/Song.dart';
import 'package:bsteeleMusicLib/songs/SongBase.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteele_music_flutter/gui.dart';
import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

///
class Edit extends StatefulWidget {
  const Edit({Key key, @required this.song}) : super(key: key);

  @override
  _Edit createState() => _Edit();

  final Song song;
}

final TextStyle _boldTextStyle =
    TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, backgroundColor: Colors.grey[100]);
final TextStyle _labelTextStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
final TextStyle _buttonTextStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold);
final TextStyle _textStyle = TextStyle(fontSize: 24, color: Colors.grey[800]);
const Color _defaultColor = Color(0xFFB3E5FC); //Colors.lightBlue[100];

class AppContainedButton extends RaisedButton {
  AppContainedButton(
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

class AppContainedButtonBuilder {
  AppContainedButtonBuilder(this._text, this._onPressed);

  AppContainedButton build() {
    if (enabled) {
      if (_enabledButton == null)
        _enabledButton = AppContainedButton(
          _text,
          onPressed: _onPressed,
        );
      return _enabledButton;
    } else {
      if (_disabledButton == null) _disabledButton = AppContainedButton(_text);
      return _disabledButton;
    }
  }

  bool enabled = true;

  AppContainedButton _enabledButton;
  AppContainedButton _disabledButton;
  String _text;
  VoidCallback _onPressed;
}

class AppOutlineButton extends OutlineButton {
  AppOutlineButton(
    String text, {
    VoidCallback onPressed,
    Color color = _defaultColor,
  }) : super(
          shape: new RoundedRectangleBorder(
            borderRadius: new BorderRadius.circular(12.0),
          ),
          color: Colors.grey[200],
          textColor: Colors.black87,
          disabledTextColor: Colors.grey[400],
          borderSide: BorderSide(width: 1.66, color: Colors.black54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            style: _buttonTextStyle,
          ),
          onPressed: onPressed,
        );
}

class _Edit extends State<Edit> {
  @override
  initState() {
    super.initState();

    _keyChordNote = widget.song.key.getKeyScaleNote();
    _otherChordDropDownMenuList = null;

    _chordTextController.addListener(() {
      if (_selectedChordSectionLocation != null && _selectedChordSectionLocation != _lastSelectedChordSectionLocation) {
        _lastSelectedChordSectionLocation = _selectedChordSectionLocation;
        final text = _chordTextController.text;
        _chordTextController.value = _chordTextController.value.copyWith(
          text: text,
          selection: TextSelection(baseOffset: 0, extentOffset: text.length),
          composing: TextRange.empty,
        );
        return;
      }
      _preProcessMeasureEntry(_chordTextController.text);
      if (_measureEntryValid) {
        switch (_chordTextController.text[_chordTextController.text.length - 1]) {
          case ' ':
            _clearChordEditing();
            break;
          case '\n':
            _clearChordEditing();
            break;
        }
      }

      logger.d('chordTextController: "${_chordTextController.text}"');
    });
  }

  @override
  void dispose() {
    _chordTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Song song = widget.song; //  convenience only
    songs.Key _key = song.key;

    _displaySongKey = song.key;

    ScreenInfo screenInfo = ScreenInfo(context);
    final double _screenWidth = screenInfo.mediaWidth;
    const double defaultFontSize = 36;
    double chordFontSize = defaultFontSize * _screenWidth / 800;
    chordFontSize = min(defaultFontSize, max(12, chordFontSize));
    //double lyricsScaleFactor = max(1, 0.75 * chordScaleFactor);

    final TextStyle chordTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: chordFontSize,
    );
    final TextStyle chordBadTextStyle =
        TextStyle(fontWeight: FontWeight.bold, fontSize: chordFontSize, color: Colors.red);

    if (_table == null) {
      logger.d("size: " + MediaQuery.of(context).size.toString());

      //  build the table from the song moment grid
      Grid<ChordSectionLocation> grid = song.getChordSectionLocationGrid();

      if (grid.isNotEmpty) {
        {
          List<TableRow> rows = List();
          List<Widget> children = List();
          Color color = GuiColors.getColorForSection(Section.get(SectionEnum.chorus));

          //  compute transposition offset from base key
          int tranOffset = _displaySongKey.getHalfStep() - song.getKey().getHalfStep();

          int maxCols = 0;
          {
            for (int r = 0; r < grid.getRowCount(); r++) {
              List<ChordSectionLocation> row = grid.getRow(r);
              maxCols = max(maxCols, row.length);
            }
          }

          //  keep track of the section
          SectionVersion lastSectionVersion;

          //  map the song moment grid to a flutter table, one row at a time
          for (int r = 0; r < grid.getRowCount(); r++) {
            List<ChordSectionLocation> row = grid.getRow(r);

            //  assume col 1 has a chord or comment in it
            if (row.length < 2) {
              continue;
            }

            //  find the first col with data
            //  should normally be col 1 (i.e. the second col)
            ChordSectionLocation firstChordSectionLocation;
            for (ChordSectionLocation loc in row)
              if (loc == null)
                continue;
              else {
                firstChordSectionLocation = loc;
                break;
              }
            if (firstChordSectionLocation == null) continue;

            SectionVersion sectionVersion = firstChordSectionLocation.sectionVersion;

            String columnFiller;
            EdgeInsets marginInsets = EdgeInsets.all(chordFontSize / 4);
            EdgeInsets textPadding = EdgeInsets.all(6);
            if (sectionVersion != lastSectionVersion) {
              //  add the section heading
              columnFiller = sectionVersion.toString();
              color = GuiColors.getColorForSection(sectionVersion.section);
              lastSectionVersion = sectionVersion;
            }

            for (int c = 0; c < row.length; c++) {
              ChordSectionLocation loc = row[c];

              Measure measure = song.findMeasureByChordSectionLocation(loc);

              if (loc == null || measure == null) {
                if (columnFiller == null)
                  //  empty cell
                  children.add(Container(
                      margin: marginInsets,
                      child: Text(
                        " ",
                      )));
                else
                  children.add(InkWell(
                      onTap: () {
                        _setChordEditing(loc);
                      },
                      child: Container(
                          margin: marginInsets,
                          padding: textPadding,
                          color: color,
                          child: Text(
                            columnFiller,
                            style: chordTextStyle,
                          ))));
                columnFiller = null; //  for subsequent rows
              } else {
                //  measure found
                Widget widget;
                if (_selectedChordSectionLocation == loc) {
                  TextField editTextField = TextField(
                    controller: _chordTextController,
                    maxLength: null,
                    style: chordTextStyle,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      hintText: 'Enter the measure.',
                    ),
                    autofocus: true,
                    enabled: true,
                  );

                  if (_measureEntry == null) {
                    _measureEntry =
                        song.findMeasureByChordSectionLocation(_selectedChordSectionLocation).toMarkupWithEnd(null);
                    _measureEntryValid = true; //  should always be!

                    _chordTextController.text = _measureEntry;
                    _chordTextController.selection = TextSelection(baseOffset: 0, extentOffset: _measureEntry.length);
                  }
                  widget = Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: TextDirection.ltr,
                      children: <Widget>[
                        Container(margin: marginInsets, padding: textPadding, color: color, child: editTextField),
                        if (_measureEntryCorrection != null)
                          Text(
                            _measureEntryCorrection,
                            style: _measureEntryValid ? chordTextStyle : chordBadTextStyle,
                          ),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              if (_measureEntryValid)
                                InkWell(
                                  child: Icon(
                                    Icons.check,
                                    size: defaultFontSize.toDouble(),
                                  ),
                                  onTap: () {
                                    _replaceChord();
                                  },
                                ),
                              InkWell(
                                child: Icon(
                                  Icons.cancel,
                                  size: defaultFontSize.toDouble(),
                                  color: _measureEntryValid ? Colors.black : Colors.red,
                                ),
                                onTap: () {
                                  _clearChordEditing();
                                },
                              ),
                            ]),
                      ]);
                } else {
                  widget = Text(
                    measure.transpose(_displaySongKey, tranOffset),
                    style: chordTextStyle,
                  );
                }

                children.add(InkWell(
                  onTap: () {
                    _setChordEditing(loc);
                  },
                  child: Container(margin: marginInsets, padding: textPadding, color: color, child: widget),
                ));
              }
            }

            for (int c = row.length; c < maxCols; c++) {
              children.add(Container());
            }

            //  add row to table
            rows.add(TableRow(key: ValueKey('row' + r.toString()), children: children));

            //  get ready for the next row by clearing the row data
            children = List();
          }

          _table = Table(
            defaultColumnWidth: IntrinsicColumnWidth(),
            children: rows,
          );
        }
      }
    }

    if (_sectionVersionDropDownMenuList == null) {
      _sectionVersionDropDownMenuList = List();
      for (int i = 0; i <= 9; i++) {
        _sectionVersionDropDownMenuList.add(
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

    if (_keyChordDropDownMenuList == null) {
      //  list the notes required
      List<ScaleNote> scaleNotes = List();
      for (int i = 0; i < MusicConstants.notesPerScale; i++) scaleNotes.add(_key.getMajorScaleByNote(i));
      for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
        ScaleNote scaleNote = _key.getScaleNoteByHalfStep(i);
        if (!scaleNotes.contains(scaleNote)) scaleNotes.add(scaleNote);
      }

      //  make the drop down list
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

    final majorChordButton = AppOutlineButton(
      _keyChordNote.toString(),
      onPressed: () {},
    );
    ScaleChord sc = ScaleChord(
      _keyChordNote,
      ChordDescriptor.minor,
    );
    final minorChordButton = AppOutlineButton(
      sc.toString(),
      onPressed: () {},
    );
    sc = ScaleChord(_keyChordNote, ChordDescriptor.dominant7);
    final dominant7ChordButton = AppOutlineButton(
      sc.toString(),
      onPressed: () {},
    );

    if (_otherChordDropDownMenuList == null) {
      // other chords
      _otherChordDropDownMenuList = List();
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

    enterSongBuilder.enabled = true;
    insertChordsBuilder.enabled = _editType == MeasureEditType.insert;
    replaceChordsBuilder.enabled = _editType == MeasureEditType.replace;
    deleteChordsBuilder.enabled = _editType == MeasureEditType.replace;
    appendChordsBuilder.enabled = _editType == MeasureEditType.append;

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
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
              ),
              SizedBox(height: 10),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    enterSongBuilder.build(),
                    Container(
                      width: 800.0,
                      child: Text('', style: _textStyle),
                    ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          AppContainedButton(
                            'Clear',
                            onPressed: () {},
                          ),
                          AppContainedButton(
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
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      width: 800.0,
                      child: TextField(
                        controller: TextEditingController(text: song.title),
                        decoration: InputDecoration(
                          hintText: 'Enter the song title.',
                        ),
                        maxLength: null,
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
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
                        controller: TextEditingController(text: song.artist),
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
                        controller: TextEditingController(text: song.coverArtist),
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
                        controller: TextEditingController(text: song.copyright),
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
                          _keyChordDropDownMenuList = null;
                          _otherChordDropDownMenuList = null;
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
                      controller: TextEditingController(text: song.getBeatsPerMinute().toString()),
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
                      "${song.beatsPerBar}/${song.unitsPerMeasure}",
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
                      song.user.toString(),
                      style: _textStyle,
                    ),
                  ),
                ],
              ),
              Text(
                "Chords:",
                style: _labelTextStyle,
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 800.0,
                    padding: EdgeInsets.only(right: 24, bottom: 24.0),
                    child: Column(children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          insertChordsBuilder.build(),
                          replaceChordsBuilder.build(),
                          deleteChordsBuilder.build(),
                          appendChordsBuilder.build(),
                        ],
                      ),
                      _table,
                    ]),
                  ),
                  Container(
                    width: 1000.0,
                    padding: EdgeInsets.only(right: 24, bottom: 24.0),
                    child: Column(children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          AppContainedButton('Intro/Instrumental',
                              color: GuiColors.getColorForSectionEnum(SectionEnum.intro)),
                          AppContainedButton('Verse', color: GuiColors.getColorForSectionEnum(SectionEnum.verse)),
                          AppContainedButton('PreChorus',
                              color: GuiColors.getColorForSectionEnum(SectionEnum.preChorus)),
                          AppContainedButton('Bridge', color: GuiColors.getColorForSectionEnum(SectionEnum.bridge)),
                          AppContainedButton('Outro', color: GuiColors.getColorForSectionEnum(SectionEnum.outro)),
                        ],
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
                        AppContainedButton('Section A', color: GuiColors.getColorForSectionEnum(SectionEnum.a)),
                        AppContainedButton('Section B', color: GuiColors.getColorForSectionEnum(SectionEnum.b)),
                        AppContainedButton('Coda', color: GuiColors.getColorForSectionEnum(SectionEnum.coda)),
                        AppContainedButton('Tag', color: GuiColors.getColorForSectionEnum(SectionEnum.tag)),
                        Text(
                          ' Section Version: ',
                          style: _textStyle,
                        ),
                        DropdownButton<int>(
                          items: _sectionVersionDropDownMenuList,
                          onChanged: (_value) {
                            _sectionVersion = _value;
                            setState(() {});
                          },
                          value: _sectionVersion,
                          style: _textStyle,
                        ),
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                        Text(
                          ' Any Chord: ',
                          style: _textStyle,
                        ),
                        DropdownButton<ScaleNote>(
                          items: _keyChordDropDownMenuList,
                          onChanged: (_value) {
                            _keyChordNote = _value;
                            _otherChordDropDownMenuList = null;
                            setState(() {});
                          },
                          value: _keyChordNote,
                          style: _textStyle,
                        ),
                        majorChordButton,
                        minorChordButton,
                        dominant7ChordButton,
                        DropdownButton<ScaleChord>(
                          items: _otherChordDropDownMenuList,
                          onChanged: (_value) {
                            setState(() {});
                          },
                          style: _textStyle,
                        ),
                        AppOutlineButton(
                          'X',
                        ),
                      ]),
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
                ],
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
                      fontSize: 24,
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

  /// validate the given measure entry string
  List<MeasureNode> validateMeasureEntry(String entry) {
    List<MeasureNode> entries = widget.song.parseChordEntry(SongBase.entryToUppercase(entry));
    _measureEntryValid =
        (entries != null && entries.length == 1 && entries[0].getMeasureNodeType() != MeasureNodeType.comment);
    _measureEntryNode = (_measureEntryValid ? entries[0] : null);
    logger.d('_measureEntryValid: $_measureEntryValid');
    return entries;
  }

  ///  speed entry enhancement and validate the entry
  void _preProcessMeasureEntry(String entry) {
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
    entry = entry.trim().replaceAll("\t", " ").replaceAll(":\n", ":").replaceAll("  ", " ").replaceAll("\n", ",");
    logger.d('entry: "$entry" vs "$upperEntry"');
    if (upperEntry == entry) {
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

  void _replaceChord() {
    Song song = widget.song;
    song.setCurrentChordSectionLocation(_selectedChordSectionLocation);
    song.setCurrentMeasureEditType(MeasureEditType.replace);
    song.editMeasureNode(_measureEntryNode);
    _clearChordEditing();
  }

  AppContainedButtonBuilder enterSongBuilder = AppContainedButtonBuilder("Enter Song", () {
    print("finish Enter Song");
  });
  AppContainedButtonBuilder insertChordsBuilder = AppContainedButtonBuilder(
    'Insert',
    () {},
  );
  AppContainedButtonBuilder replaceChordsBuilder = AppContainedButtonBuilder(
    'Replace',
    () {},
  );
  AppContainedButtonBuilder deleteChordsBuilder = AppContainedButtonBuilder(
    'Delete',
    () {},
  );
  AppContainedButtonBuilder appendChordsBuilder = AppContainedButtonBuilder(
    'Append',
    () {},
  );

  void _setChordEditing(ChordSectionLocation loc) {
    setState(() {
      _clearMeasureEntry();
      _selectedChordSectionLocation = loc;
    });
  }

  void _clearChordEditing() {
    setState(() {
      _clearMeasureEntry();
    });
  }

  void _clearMeasureEntry() {
    _table = null;
    _selectedChordSectionLocation = null;
    _lastSelectedChordSectionLocation = null;
    _measureEntry = null;
    _measureEntryCorrection = null;
    _measureEntryValid = false;
  }

  Table _table;
  ChordSectionLocation _selectedChordSectionLocation;
  ChordSectionLocation _lastSelectedChordSectionLocation;

  String _measureEntry;
  String _measureEntryCorrection;
  bool _measureEntryValid;
  MeasureNode _measureEntryNode;

  TextEditingController _chordTextController = TextEditingController();
  songs.Key _displaySongKey = songs.Key.get(songs.KeyEnum.C);

  bool _showHints = false;
  int _sectionVersion = 0;
  ScaleNote _keyChordNote;
  MeasureEditType _editType = MeasureEditType.append;

  List<DropdownMenuItem<ScaleNote>> _keyChordDropDownMenuList;
  List<DropdownMenuItem<int>> _sectionVersionDropDownMenuList;
  List<DropdownMenuItem<ScaleChord>> _otherChordDropDownMenuList;
}
