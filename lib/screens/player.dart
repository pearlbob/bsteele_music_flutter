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

    //  eval behind first render

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _lastDy = 0;

      //  find the song's widget sizes on first pass
      for (int i = 0; i < _rowLocations.length; i++) {
        _RowLocation rowLocation = _rowLocations[i];
        RenderBox box = rowLocation.globalKey.currentContext.findRenderObject();
        rowLocation.dy = box.localToGlobal(Offset.zero).dy;
        rowLocation.height = _lastDy != null
            ? rowLocation.dy - _lastDy
            : box.size.height; //  placeholder
        _lastDy = rowLocation.dy; //  for next time
        //logger.i(rowLocation.toString());
        //logger.i('    ${rowLocation.globalKey.currentContext.toString()}');
      }
    });

    scrollController.addListener(() {
      if (scrollController.hasClients) {
        if (scrollController.offset == 0) {
          setState(() {});
        } else if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent) {
          logger.i('scrollController listener: ${scrollController.offset}');
          _stop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Song song = widget.song; //  convenience only

    double w = MediaQuery.of(context).size.width;
    double h = MediaQuery.of(context).size.height;
    double chordScaleFactor = w / 400;
    bool isTooNarrow = w <= 800;
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
            _rowLocations[r] = _RowLocation(r, _rowKey, song.rowBeats(r));

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
              if (isTooNarrow) break;
            }

            if (momentLocation != null || isTooNarrow) {
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
//        logger.i('rowkey:  ${tableRow.key.toString()}');
//        int j = 0;
//        for (Widget widget in tableRow.children) {
//          if (widget.key != null)
//            logger.i('\t\($i\,$j\) ${widget.key.toString()}');
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

    double boxCenter = 0.5 * h;
    double boxHeight = 0.5 * h;
    double boxOffset = boxHeight / 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: boxCenter - boxOffset,
            child: Container(
              constraints: BoxConstraints.loose(Size(w, boxHeight)),
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
            controller: scrollController,
//            physics:(_playerSimulation._isRunning ? _playerScrollPhysics : null),
            scrollDirection: Axis.vertical,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: TextDirection.ltr,
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
                      if (!isTooNarrow)
                        Container(
                          padding: const EdgeInsets.only(left: 8, right: 32),
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
                      if (!isTooNarrow)
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
                          iconSize: lyricsScaleFactor * 24,
                          itemHeight:
                              lyricsScaleFactor * kMinInteractiveDimension,
                        )
                      else
                        Text(_displaySongKey.toString()),
                      Text(
                        "   BPM: ${song.getBeatsPerMinute()}" +
                            "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}",
                        textScaleFactor: lyricsScaleFactor,
                      ),
                    ],
                  ),
                  Center(child: _table),
                  Text(
                    "Copyright: ${song.getCopyright()}",
                    textScaleFactor: lyricsScaleFactor,
                  ),
                  _KeyboardListener(this),
                ]),
          ),
        ],
      ),
      floatingActionButton: _isPlaying
          ? FloatingActionButton(
              mini: isTooNarrow,
              onPressed: () {
                _playToggle();
              },
              tooltip: 'Stop.  Space bar will pause the play.',
              child: Icon(Icons.stop),
            )
          : (scrollController.hasClients && scrollController.offset > 0
              ? FloatingActionButton(
                  mini: isTooNarrow,
                  onPressed: () {
                    scrollController.animateTo(0,
                        duration: Duration(milliseconds: 333),
                        curve: Curves.ease);
                  },
                  tooltip: 'Top',
                  child: Icon(Icons.arrow_upward),
                )
              : FloatingActionButton(
                  mini: isTooNarrow,
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
    scrollController.jumpTo(0);
    scrollController.animateTo(_lastDy,
        duration: Duration(milliseconds: (widget.song.duration * 1000).toInt()),
        curve: Curves.ease);
    logger.i('animated play');
    setState(() {});
  }

  _stop(){
    _isPlaying = true;
    scrollController.jumpTo(scrollController.offset);
    setState(() {});
  }

  void _playToggle() {
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      scrollController.animateTo(_lastDy,
          duration: Duration(
              milliseconds: ((widget.song.duration
                      //fixme      - seconds song at the current row
                      ) *
                      1000)
                  .toInt()),
          curve: Curves.ease);
      logger.i('animated scroll');
    } else {
      scrollController.jumpTo(scrollController.offset);
      logger.i('stop me now');
    }
    setState(() {});
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

  double _lastDy = 0;
  List<_RowLocation> _rowLocations;

  Table _table;
  songs.Key _displaySongKey = songs.Key.get(songs.KeyEnum.C);
  List<DropdownMenuItem<songs.Key>> keyDropDownMenuList;
}

class _RowLocation {
  _RowLocation(this.row, this.globalKey, this._beats);

  @override
  String toString() {
    return ('${row.toString()} ${globalKey.toString()}'
        ', beats: ${beats.toString()}'
        ', dy: ${dy.toStringAsFixed(1)}'
        ', h: ${height.toStringAsFixed(1)}'
        ', b/h: ${pixelsPerBeat.toStringAsFixed(1)}');
  }

  void _computePixelsPerBeat() {
    if (_height != null && beats != null && beats > 0)
      _pixelsPerBeat = _height / beats;
  }

  final GlobalKey globalKey;
  final int row;

  set beats(value) {
    _beats = value;
    _computePixelsPerBeat();
  }

  int get beats => _beats;
  int _beats;

  double dy;

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

    logger.d('KeyCode: ${key.logicalKey.toString()} ${key.toString()}, t: $dt');
    if (key.logicalKey.keyLabel == LogicalKeyboardKey.space.keyLabel) {
      logger.i('space hit');
      _player._playToggle();
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

//class _PlayerSimulation extends Simulation {
//  final double _initialPosition;
//  double _x;
//  final double _velocity = 0.05;
//  int t0;
//  int _t;
//
//  _PlayerSimulation(this._initialPosition, velocity) : _x = _initialPosition;
//
//  @override
//  double dx(double time) {
//    if (!_isRunning) return 0;
//    return _velocity;
//  }
//
//  @override
//  double x(double time) {
//    if (_isRunning) {
//      _x = _initialPosition;
//      if (t0 == null)
//        t0 = DateTime.now().millisecondsSinceEpoch;
//      else {
//        _x += _velocity * (DateTime.now().millisecondsSinceEpoch - t0);
//        _x = max(0, _x);
//        logger.v('_x: ${_x.toString()}, t: $time');
//      }
//    }
//    return _x;
//  }
//
//  @override
//  bool isDone(double time) {
//    return true;
//  }
//
//  void stop() {
//    //  prepare for the next run
//    if (t0 != null)
//      _t = DateTime.now().millisecondsSinceEpoch - t0;
//    else
//      _t = null;
//    _isRunning = false;
//  }
//
//  void run() {
//    //  restart time where we left off by updating t0
//    if (_t != null) {
//      t0 = DateTime.now().millisecondsSinceEpoch - _t;
//      _t = null;
//    }
//
//    //  x and velocity can remain as is
//
//    _isRunning = true;
//  }
//
//  void resetAndRun() {
//    _x = _initialPosition;
//    t0 = DateTime.now().millisecondsSinceEpoch;
//    _isRunning = true;
//  }
//
//  void resetAndStop() {
//    _isRunning = false;
//    _x = _initialPosition;
//    t0 = null;
//    _t = null;
//  }
//
//  bool _isRunning = false;
//}
//
//class _PlayerScrollPhysics extends ScrollPhysics {
//  @override
//  ScrollPhysics applyTo(ScrollPhysics ancestor) {
//    return _PlayerScrollPhysics();
//  }
//
//  @override
//  Simulation createBallisticSimulation(
//      ScrollMetrics position, double velocity) {
//    return _playerSimulation;
//  }
//}

ScrollController scrollController = ScrollController();

//_PlayerSimulation _playerSimulation = _PlayerSimulation(0, 0);
//_PlayerScrollPhysics _playerScrollPhysics = _PlayerScrollPhysics();
