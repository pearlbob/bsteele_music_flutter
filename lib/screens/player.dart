import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:bsteele_music_flutter/Grid.dart';
import 'package:bsteele_music_flutter/Gui.dart';
import 'package:bsteele_music_flutter/songs/ChordSection.dart';
import 'package:bsteele_music_flutter/songs/Key.dart' as songs;
import 'package:bsteele_music_flutter/songs/MusicConstants.dart';
import 'package:bsteele_music_flutter/songs/Section.dart';
import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:bsteele_music_flutter/songs/SongMoment.dart';
import 'package:bsteele_music_flutter/util/OpenLink.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../appLogger.dart';

/// Display the song moments in sequential order.
class Player extends StatefulWidget {
  const Player({Key key, @required this.song}) : super(key: key);

  @override
  _Player createState() => _Player();

  final Song song;
}

class _Player extends State<Player> {
  @override
  initState() {
    super.initState();

    logger.i("_Player.initState()");

    _displaySongKey = widget.song.key;

    //  eval sizes after first render
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      //  find the song's widget sizes after first rendering pass
      _lastDy = 0;
      double firstBoxDy;
      for (int i = 0; i < _rowLocations.length; i++) {
        _RowLocation rowLocation = _rowLocations[i];
        RenderBox box = rowLocation.globalKey.currentContext.findRenderObject();

        {
          double dy = box.localToGlobal(Offset.zero).dy;
          if (firstBoxDy == null) {
            firstBoxDy = dy;
            rowLocation.dispY = 0;
          } else
            rowLocation.dispY = box.localToGlobal(Offset.zero).dy - firstBoxDy;
        }

        rowLocation.height = _lastDy != null
            ? rowLocation.dispY - _lastDy
            : box.size.height; //  placeholder
        _lastDy = rowLocation.dispY; //  for next time
        //logger.i(rowLocation.toString());
        //logger.i('    ${rowLocation.globalKey.currentContext.toString()}');
      }

      //  diagnostics only
      for (_RowLocation rowLocation in _rowLocations) {
        logger.i('${rowLocation.toString()}');
      }
    });

    _scrollController.addListener(() {
      int t = DateTime.now().millisecondsSinceEpoch;
      logger.i('scroll:'
          ' pos: ${_scrollController.offset.toStringAsFixed(1)}'
          ' posT: ${songTimeAtPosition(_scrollController.offset).toStringAsFixed(3)} s'
          ' d: ${(_scrollController.offset - _lastScrollPos).toStringAsFixed(2)}'
          ' t: ${((t - t0) / 1000).toStringAsFixed(3)} s'
          ' dt: ${(t - _lastScrollT).toStringAsFixed(3)} ms');
      _lastScrollPos = _scrollController.offset;
      _lastScrollT = t;

      if (_scrollController.hasClients) {
        if (_scrollController.offset == 0) {
          //  re-draw at top
          setState(() {});
        } else if (!_isTooNarrow &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent) {
          //  stop playing at the bottom
          _stop();
        }
      }
    });
  }

  double songTimeAtPosition(double position) {
    if (position <= 0) return 0;
    for (_RowLocation _rowLocation in _rowLocations) {
      if (position <= _rowLocation.dispY + _rowLocation.height)
        return (_rowLocation.songMoment.beatNumber +
                (position - _rowLocation.dispY) /
                    _rowLocation.height *
                    _rowLocation.beats) *
            60 /
            widget.song.getBeatsPerMinute();
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    Song song = widget.song; //  convenience only

    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    double chordScaleFactor = _screenWidth / 400;
    _isTooNarrow = _screenWidth <= 800;
    _isTooNarrow = _screenWidth <= 800;
    chordScaleFactor = min(10, max(1, chordScaleFactor));
    double lyricsScaleFactor = max(1, 0.75 * chordScaleFactor);
    logger.d("textScaleFactor: $chordScaleFactor");

    if (_table == null) {
      logger.i("size: " + MediaQuery.of(context).size.toString());

      //  build the table from the song moment grid
      Grid<SongMoment> grid = song.songMomentGrid;
      _rowLocations = null;
      if (grid.isNotEmpty) {
        {
          _rowLocations = List(grid.getRowCount());
          List<TableRow> rows = List();
          List<Widget> children = List();
          Color color =
              GuiColors.getColorForSection(Section.get(SectionEnum.chorus));

          //  compute transposition offset from base key
          int tranOffset =
              _displaySongKey.getHalfStep() - song.getKey().getHalfStep();

          //  keep track of the section
          ChordSection lastChordSection;
          int lastSectionCount;

          //  map the song moment grid to a flutter table, one row at a time
          for (int r = 0; r < grid.getRowCount(); r++) {
            List<SongMoment> row = grid.getRow(r);

            //  assume col 1 has a chord or comment in it
            if (row.length < 2) {
              continue;
            }

            //  find the first col with data
            //  should normally be col 1 (i.e. the second col)
            SongMoment firstSongMoment;
            for (SongMoment sm in row)
              if (sm == null)
                continue;
              else {
                firstSongMoment = sm;
                break;
              }
            if (firstSongMoment == null) continue;

            GlobalKey _rowKey = GlobalKey(debugLabel: r.toString());
            _rowLocations[r] =
                _RowLocation(firstSongMoment, r, _rowKey, song.rowBeats(r));

            ChordSection chordSection = firstSongMoment.getChordSection();
            int sectionCount = firstSongMoment.sectionCount;
            String columnFiller;
            EdgeInsets marginInsets = EdgeInsets.all(4 * chordScaleFactor);
            if (chordSection != lastChordSection ||
                sectionCount != lastSectionCount) {
              //  add the section heading
              columnFiller = chordSection.sectionVersion.toString();
              color = GuiColors.getColorForSection(chordSection.getSection());
            }
            lastChordSection = chordSection;
            lastSectionCount = sectionCount;

            String momentLocation;
            for (int c = 0; c < row.length; c++) {
              SongMoment sm = row[c];

              if (sm == null) {
                if (columnFiller == null)
                  //  empty cell
                  children.add(Container(
                      margin: marginInsets,
                      child: Text(
                        " ",
                      )));
                else
                  children.add(Container(
                      margin: marginInsets,
                      child: Text(
                        columnFiller,
                        style: TextStyle(backgroundColor: color),
                        textScaleFactor: chordScaleFactor,
                      )));
                columnFiller = null; //  for subsequent rows
              } else {
                //  moment found
                children.add(Container(
                    key: _rowKey,
                    margin: marginInsets,
                    child: Text(
                      sm.getMeasure().transpose(_displaySongKey, tranOffset),
                      style: TextStyle(backgroundColor: color),
                      textScaleFactor: chordScaleFactor,
                    )));
                _rowKey = null;

                //  use the first non-null location for the table value key
                if (momentLocation == null)
                  momentLocation = sm.momentNumber.toString();
              }

              //  section and lyrics only if on a cell phone
              if (_isTooNarrow) break;
            }

            if (momentLocation != null || _isTooNarrow) {
              //  lyrics
              children.add(Container(
                  margin: marginInsets,
                  child: Text(
                    firstSongMoment.lyrics,
                    style: TextStyle(backgroundColor: color),
                    textScaleFactor: lyricsScaleFactor,
                  )));

              //  add row to table
              rows.add(TableRow(key: ValueKey(r), children: children));
            }

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

//   {
//      int i = 0;
//      for (TableRow tableRow in _table.children) {
//        logger.v('rowkey:  ${tableRow.key.toString()}');
//        int j = 0;
//        for (Widget widget in tableRow.children) {
//          if (widget.key != null)
//            logger.v('\t\($i\,$j\) ${widget.key.toString()}');
//          j++;
//        }
//        i++;
//      }
//    }

    //  generate the rolled key list
    //  higher pitch on top
    //  lower pit on bottom

    if (keyDropDownMenuList == null) {
      const int steps = MusicConstants.halfStepsPerOctave;
      const int halfOctave = steps ~/ 2;
      List<songs.Key> rolledKeyList = List(steps);

      List<songs.Key> list = songs.Key.keysByHalfStepFrom(song.key); //temp loc
      for (int i = 0; i <= halfOctave; i++) {
        rolledKeyList[i] = list[halfOctave - i];
      }
      for (int i = halfOctave + 1; i < steps; i++) {
        rolledKeyList[i] = list[steps - i + halfOctave];
      }

      keyDropDownMenuList = List();
      for (int i = 0; i < steps; i++) {
        songs.Key value = rolledKeyList[i];

        int relativeOffset = halfOctave - i;

        String relativeName = relativeOffset > 0
            ? value.toStringAsSharp()
            : value.toStringAsFlat();

        String relativeString;
        if (relativeOffset > 0)
          relativeString = " +${relativeOffset.toString()}";
        else if (relativeOffset < 0)
          relativeString = " ${relativeOffset.toString()}";
        else
          relativeString = ' ';

        keyDropDownMenuList.add(
          DropdownMenuItem<songs.Key>(
            key: ValueKey(value.getHalfStep()),
            value: value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  relativeName,
                  textScaleFactor: lyricsScaleFactor, //  note well
                ),
                Text(
                  relativeString,
                  textScaleFactor: lyricsScaleFactor, //  note well
                ),
              ],
            ),
          ),
        );
      }
    }

    if (bpmDropDownMenuList == null) {
      final int bpm = song.getBeatsPerMinute();

      bpmDropDownMenuList = List();
      for (int i = -60; i < 60; i++) {
        int value = bpm + i;
        if (value < 40) continue;
        bpmDropDownMenuList.add(
          DropdownMenuItem<int>(
            key: ValueKey(value),
            value: value,
            child: Row(
              children: <Widget>[
                Text(
                  value.toString(),
                  textScaleFactor: lyricsScaleFactor, //  note well
                ),
              ],
            ),
          ),
        );
        if (i < -30 || i > 30)
          i += 10 - 1; //  in addition to increment above
        else if (i < -5 || i > 5)
          i += 5 - 1; //  in addition to increment above
      }
    }

    double boxCenter = 0.5 * _screenHeight;
    double boxHeight = 0.5 * _screenHeight;
    double boxOffset = boxHeight / 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: boxCenter - boxOffset,
            child: Container(
              constraints: BoxConstraints.loose(Size(_screenWidth, boxHeight)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white,
                    Colors.blue[300],
                    Colors.blue[300],
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.vertical,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  if (!_isPlaying)
                    Column(
                      children: <Widget>[
                        AppBar(
                          //  let the app bar scroll off the screen for more room for the song
                          title: InkWell(
                            onTap: () {
                              openLink(_titleAnchor());
                            },
                            child: Text(
                              '${song.title}',
                              style: TextStyle(
                                  fontSize: 48, fontWeight: FontWeight.bold),
                            ),
                          ),
                          centerTitle: true,
                        ),
                        InkWell(
                          onTap: () {
                            openLink(_artistAnchor());
                          },
                          child: Text(
                            ' by  ${song.artist}',
                            textScaleFactor: lyricsScaleFactor,
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            if (!_isTooNarrow)
                              Container(
                                padding:
                                    const EdgeInsets.only(left: 8, right: 32),
                                child: FlatButton.icon(
                                  color: Colors.lightBlue[300],
                                  hoverColor: Colors.red,
                                  icon: Icon(
                                    _playStopIcon,
                                    size: 24 * lyricsScaleFactor,
                                  ),
                                  label: Text(''),
                                  onPressed: () {
                                    _play();
                                  },
                                ),
                              ),
                            Text(
                              "Key: ",
                              textScaleFactor: lyricsScaleFactor,
                            ),
                            if (!_isTooNarrow)
                              DropdownButton<songs.Key>(
                                items: keyDropDownMenuList,
                                onChanged: (_value) {
                                  setState(() {
                                    _displaySongKey = _value;
                                    _table = null;
                                  });
                                },
                                value: _displaySongKey,
                                style: TextStyle(
                                  //  size controlled by textScaleFactor above
                                  color: Colors.black87,
                                  textBaseline: TextBaseline.ideographic,
                                ),
                                iconSize: lyricsScaleFactor * 16,
                                itemHeight: lyricsScaleFactor *
                                    kMinInteractiveDimension,
                              )
                            else
                              Text(_displaySongKey.toString()),
                            Text(
                              "   BPM: ",
                              textScaleFactor: lyricsScaleFactor,
                            ),
                            if (!_isTooNarrow)
                              DropdownButton<int>(
                                items: bpmDropDownMenuList,
                                onChanged: (_value) {
                                  setState(() {
                                    song.setBeatsPerMinute(_value);
                                    bpmDropDownMenuList =
                                        null; //  refresh to new value
                                    setState(() {});
                                  });
                                },
                                value: song.getBeatsPerMinute(),
                                style: TextStyle(
                                  //  size controlled by textScaleFactor above
                                  color: Colors.black87,
                                  textBaseline: TextBaseline.ideographic,
                                ),
                                iconSize: lyricsScaleFactor * 16,
                                itemHeight: lyricsScaleFactor *
                                    kMinInteractiveDimension,
                              )
                            else
                              Text(
                                song.getBeatsPerMinute().toString(),
                                textScaleFactor: lyricsScaleFactor,
                              ),
                            Text(
                              "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}",
                              textScaleFactor: lyricsScaleFactor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  if (_isPlaying)
                    SizedBox(
                      height: _screenHeight / 2,
                    ),
                  Center(child: _table),
                  Text(
                    "Copyright: ${song.getCopyright()}",
                    textScaleFactor: lyricsScaleFactor,
                  ),
                  if (_isPlaying)
                    SizedBox(
                      height: _screenHeight / 2,
                    ),
                  _KeyboardListener(this),
                ]),
          ),
        ],
      ),
      floatingActionButton: _isPlaying
          ? FloatingActionButton(
              mini: _isTooNarrow,
              onPressed: () {
                _playToggle();
              },
              tooltip: 'Stop.  Space bar will pause the play.',
              child: Icon(Icons.stop),
            )
          : (_scrollController.hasClients && _scrollController.offset > 0
              ? FloatingActionButton(
                  mini: _isTooNarrow,
                  onPressed: () {
                    _scrollController
                        .animateTo(0,
                            duration: Duration(milliseconds: 333),
                            curve: Curves.ease)
                        .then((_) {
                      logger.i('_scrollAnimationFuture complete');
                    });
                  },
                  tooltip: 'Top',
                  child: Icon(Icons.arrow_upward),
                )
              : FloatingActionButton(
                  mini: _isTooNarrow,
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  tooltip: 'Back',
                  child: Icon(Icons.arrow_back),
                )),
    );
  }

  bool _isPlaying = false;

  IconData get _playStopIcon => _isPlaying ? Icons.stop : Icons.play_arrow;

  _play() {
    _isPlaying = true;
    _scrollController.jumpTo(0);
    _playAnimation();
    logger.d('animated play');
    setState(() {});
  }

  _stop() {
    _isPlaying = true;
    _scrollController.jumpTo(_scrollController.offset);
    setState(() {});
  }

  void _playToggle() {
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _playAnimation();
      logger.d('animated scroll');
    } else {
      _scrollController.jumpTo(_scrollController.offset - _screenHeight / 2);
    }
    setState(() {});
  }

  void _playAnimation() {
    t0 = DateTime.now().millisecondsSinceEpoch;
    _scrollController
        .animateTo(_lastDy,
            duration: Duration(
                milliseconds: ((
                            //  total duration
                            widget.song.duration
                                //  minus time already consumed
                                -
                                (_isPlaying
                                    ? songTimeAtPosition(
                                        _scrollController.offset)
                                    : 0)) *
                        1000 //  ms/s
                    )
                    .toInt()),
            curve: Curves.linear)
        .then((_) {
      logger.i('_playAnimation finished'
          ', pos: ${_scrollController.offset.toStringAsFixed(1)}');
    });
  }

  String _titleAnchor() {
    return anchorUrlStart +
        Uri.encodeFull('${widget.song.title} ${widget.song.artist}');
  }

  String _artistAnchor() {
    return anchorUrlStart + Uri.encodeFull('${widget.song.artist}');
  }

  static final String anchorUrlStart =
      "https://www.youtube.com/results?search_query=";

  double _lastScrollPos = 0;
  int t0 = DateTime.now().millisecondsSinceEpoch;
  int _lastScrollT = DateTime.now().millisecondsSinceEpoch;

  bool _isTooNarrow = false;
  double _screenWidth;
  double _screenHeight;
  double _lastDy = 0;
  List<_RowLocation> _rowLocations;

  Table _table;
  songs.Key _displaySongKey = songs.Key.get(songs.KeyEnum.C);
  List<DropdownMenuItem<songs.Key>> keyDropDownMenuList;
  List<DropdownMenuItem<int>> bpmDropDownMenuList;

  ScrollController _scrollController = ScrollController();
}

class _RowLocation {
  _RowLocation(this.songMoment, this.row, this.globalKey, this._beats);

  @override
  String toString() {
    return ('${row.toString()} ${globalKey.toString()}'
        ', ${songMoment.toString()}'
        ', beats: ${beats.toString()}'
        ', dispY: ${dispY.toStringAsFixed(1)}'
        ', h: ${height.toStringAsFixed(1)}'
        ', b/h: ${pixelsPerBeat.toStringAsFixed(1)}');
  }

  void _computePixelsPerBeat() {
    if (_height != null && beats != null && beats > 0)
      _pixelsPerBeat = _height / beats;
  }

  final SongMoment songMoment;
  final GlobalKey globalKey;
  final int row;

  set beats(value) {
    _beats = value;
    _computePixelsPerBeat();
  }

  int get beats => _beats;
  int _beats;

  double dispY;

  set height(value) {
    _height = value;
    _computePixelsPerBeat();
  }

  double get height => _height;
  double _height;

  double get pixelsPerBeat => _pixelsPerBeat;
  double _pixelsPerBeat;
}

class _KeyboardListener extends StatefulWidget {
  _KeyboardListener(_Player player)
      : _keyboardListenerState = _KeyboardListenerState(player);

  @override
  _KeyboardListenerState createState() => _keyboardListenerState;

  final _KeyboardListenerState _keyboardListenerState;
}

class _KeyboardListenerState extends State<_KeyboardListener> {
  _KeyboardListenerState(this._player);

  handleKey(RawKeyEventData key) {
    //  can't get enough data from raw key
    //  so use time to discriminate pressings from repeats
    final int t = DateTime.now().millisecondsSinceEpoch;
    final int dt = t - _lastKeyTime;
    _lastKeyTime = t;
    if (dt < 350) return;

    logger.i('KeyCode: ${key.logicalKey.toString()} ${key.toString()}, t: $dt');
    if (key.logicalKey.keyLabel == LogicalKeyboardKey.space.keyLabel) {
      logger.i('space hit');
      _player._playToggle();
    } else if (_player._isPlaying &&
        (key.logicalKey.keyLabel == LogicalKeyboardKey.arrowDown.keyLabel ||
            key.logicalKey.keyLabel == LogicalKeyboardKey.arrowUp.keyLabel)) {
      //  restart the scrolling after a bit
      Timer(Duration(milliseconds: 33 * 5), () {
        _player._playAnimation();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _textFocusNode.requestFocus();

    return RawKeyboardListener(
      focusNode: _textFocusNode,
      onKey: (key) => handleKey(key.data),
      child: Visibility(
        visible: false,
        child: TextField(),
      ),
    );
  }

  final _Player _player;
  FocusNode _textFocusNode = new FocusNode();
  int _lastKeyTime = DateTime.now().millisecondsSinceEpoch;
}
