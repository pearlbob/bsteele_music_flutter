import 'dart:collection';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordComponent.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/pitch.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/songs/timeSignature.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicPainter.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:bsteele_music_flutter/util/appTextStyle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

final _white = Paint()..color = Colors.white;
final _black = Paint()..color = Colors.black;
final _blue = Paint()..color = Colors.lightBlue.shade200;
final _blackOutline = Paint()
  ..color = Colors.black
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1;
// final _scaleBlackOutline = Paint()
//   ..color = Colors.black38
//   ..style = PaintingStyle.stroke
//   ..strokeWidth = 1;
final _stringGrey = Paint()..color = Colors.grey[400] ?? Colors.grey;
final _dotColor = Paint()..color = Colors.blue[100] ?? Colors.blue;
final _rootColor = Paint()..color = Colors.red;
final _thirdColor = Paint()..color = const Color(0xffffb390);
final _fifthColor = Paint()..color = const Color(0xffffa500);
final _seventhColor = Paint()..color = const Color(0xffffff00);
final _otherColor = Paint()..color = const Color(0x80A3FF69);
final _scaleColor = Paint()..color = const Color(0x80ffffff);
double _fontSize = 24;
Offset? _dragStart;
Offset? _dragEnd;

music_key.Key _key = music_key.Key.getDefault();
ScaleNote _chordRoot = _key.getKeyScaleNote();
ScaleChord _scaleChord = ScaleChord(_key.getKeyScaleNote(), ChordDescriptor.defaultChordDescriptor());

bool get _isShowScaleNumbers => sheetDisplayEnables[SheetDisplay.bassNoteNumbers.index];

bool get _isShowScaleNotes => sheetDisplayEnables[SheetDisplay.bassNotes.index];
bool _isSwing = true;
TimeSignature _timeSignature = TimeSignature.defaultTimeSignature;
int _bpm = 106;

/// the bass study tool
class BassWidget extends StatefulWidget {
  const BassWidget({Key? key}) : super(key: key);

  @override
  _State createState() => _State();
}

class _State extends State<BassWidget> {
  @override
  initState() {
    super.initState();

    _lyricsTextEditingController.addListener(() {
      logger.i('lyrics: <${_lyricsTextEditingController.text}>');
    });

    //  initialize at least a minimum sheet display
    {
      var hasSomeDisplay = false;
      for (var displayEnable in sheetDisplayEnables) {
        hasSomeDisplay |= displayEnable;
      }
      if (!hasSomeDisplay) {
        sheetDisplayEnables[SheetDisplay.measureCount.index] = true;
        sheetDisplayEnables[SheetDisplay.lyrics.index] = true;
        sheetDisplayEnables[SheetDisplay.chords.index] = true;
        sheetDisplayEnables[SheetDisplay.pianoChords.index] = true;
        // sheetDisplayEnables[SheetDisplay.pianoTreble.index]=true;
        // sheetDisplayEnables[SheetDisplay.pianoBass.index]=true;
        //sheetDisplayEnables[SheetDisplay.bassNoteNumbers.index] = true;
        //sheetDisplayEnables[SheetDisplay.bassNotes.index] = true;
        sheetDisplayEnables[SheetDisplay.bass8vb.index] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _fontSize = App().screenInfo.fontSize * 2 / 3;

    _style = AppTextStyle(color: Colors.black87, fontSize: _fontSize);

    _scaleChord = ScaleChord(_chordRoot, chordDescriptor);
    List<ScaleNote> scaleNoteValues = [];
    {
      var scaleNoteSet = SplayTreeSet<ScaleNote>();
      for (int i = 0; i < MusicConstants.halfStepsPerOctave; i++) {
        scaleNoteSet.add(_key.getKeyScaleNoteByHalfStep(i));
      }
      scaleNoteValues = scaleNoteSet.toList(growable: false);
    }

    _bpmTextEditingController.text = _bpm.toString();

    //  sheet display enables
    Widget _sheetDisplayEnableOptionsWidget = const SizedBox(
      height: 0,
    );
    if (_options) {
      List<Widget> children = [];
      for (var display in SheetDisplay.values) {
        var name = Util.firstToUpper(Util.camelCaseToLowercaseSpace(Util.enumToString(display)));
        children.add(Row(
          children: [
            Checkbox(
              checkColor: Colors.white,
              fillColor: MaterialStateProperty.all(_blue.color),
              value: sheetDisplayEnables[display.index],
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    sheetDisplayEnables[display.index] = value;
                    logger.i('$name: ${sheetDisplayEnables[display.index]}');
                  });
                }
              },
            ),
            TextButton(
              child: Text(
                name,
                style: _style,
              ),
              onPressed: () {
                setState(() {
                  sheetDisplayEnables[display.index] = !sheetDisplayEnables[display.index];
                  logger.i('TextButton $name: ${sheetDisplayEnables[display.index]}');
                });
              },
            ),
          ],
        ));
      }

      children.add(const SizedBox(
        height: 10,
      ));
      children.add(_commandButton('Close the options', onPressed: () {
        setState(() {
          _options = false;
        });
      }));

      _sheetDisplayEnableOptionsWidget = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }

    const sheetMusicSizedBox = SizedBox(
      width: double.infinity,
      height: 1000.0,
    );

    SheetMusicPainter _sheetMusicPainter = SheetMusicPainter();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Bass Study Tool',
          style: AppTextStyle(color: Colors.black87, fontSize: _fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Wrap(
        children: <Widget>[
          Column(
            children: [
              const SizedBox(
                height: 10,
              ),
              if (hasDisplay(SheetDisplay.bass8vb))
                CustomPaint(
                  painter: _FretBoardPainter(),
                  isComplex: true,
                  willChange: false,
                  child: const SizedBox(
                    width: double.infinity,
                    height: 200.0,
                  ),
                ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // key, chords
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Key: ',
                            style: _style,
                          ),
                          DropdownButton<music_key.Key>(
                            items: music_key.Key.values.toList().reversed.map((music_key.Key value) {
                              return DropdownMenuItem<music_key.Key>(
                                key: ValueKey('half' + value.getHalfStep().toString()),
                                value: value,
                                child: Text(
                                  '${value.toMarkup().padRight(3)} ${value.sharpsFlatsToMarkup()}',
                                  style: _style,
                                ),
                              );
                            }).toList(),
                            onChanged: (_value) {
                              if (_value != null && _value != _key) {
                                setState(() {
                                  _key = _value;
                                });
                              }
                            },
                            value: _key,
                            style: const AppTextStyle(
                              //  size controlled by textScaleFactor above
                              color: Colors.black,
                              textBaseline: TextBaseline.ideographic,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Chord root: ',
                            style: _style,
                          ),
                          DropdownButton<ScaleNote>(
                            items: scaleNoteValues.map((ScaleNote value) {
                              return DropdownMenuItem<ScaleNote>(
                                key: ValueKey('root' + value.halfStep.toString()),
                                value: value,
                                child: Text(
                                  _key.inKey(value).toMarkup(),
                                  style: _style,
                                ),
                              );
                            }).toList(),
                            onChanged: (_value) {
                              if (_value != null && _value != _chordRoot) {
                                setState(() {
                                  _chordRoot = _value;
                                });
                              }
                            },
                            value: _chordRoot,
                            style: const AppTextStyle(
                              //  size controlled by textScaleFactor above
                              color: Colors.black,
                              textBaseline: TextBaseline.ideographic,
                            ),
                          ),
                        ],
                      ),
                      //  chord type
                      Row(
                        children: [
                          Text(
                            'Chord type: ',
                            style: _style,
                          ),
                          DropdownButton<ChordDescriptor>(
                            items: ChordDescriptor.values.toList().map((ChordDescriptor value) {
                              return DropdownMenuItem<ChordDescriptor>(
                                value: value,
                                child: Text(
                                  '${value.toString().padRight(3)} (${value.name})',
                                  style: _style,
                                ),
                              );
                            }).toList(),
                            onChanged: (_value) {
                              if (_value != null && _value != chordDescriptor) {
                                setState(() {
                                  chordDescriptor = _value;
                                });
                              }
                            },
                            value: chordDescriptor,
                            style: const AppTextStyle(
                              //  size controlled by textScaleFactor above
                              color: Colors.black,
                              textBaseline: TextBaseline.ideographic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 10,
                  ),
                  //  notes and rests
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _noteButton(
                            noteWhole.character,
                            onPressed: () {
                              logger.i('noteWhole pressed');
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _noteButton(
                            noteHalfUp.character,
                            onPressed: () {
                              logger.i('noteHalfUp pressed');
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _noteButton(
                            noteQuarterUp.character,
                            onPressed: () {
                              logger.i('noteQuarterUp pressed');
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _noteButton(
                            note8thUp.character,
                            onPressed: () {
                              logger.i('note8thUp pressed');
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _noteButton(
                            note16thUp.character,
                            onPressed: () {
                              logger.i('note16thUp pressed');
                            },
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          _restButton(
                            restWhole.character,
                            onPressed: () {
                              logger.i('restWhole pressed');
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _restButton(
                            restHalf.character,
                            onPressed: () {
                              logger.i('restHalf pressed');
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _restButton(
                            restQuarter.character,
                            onPressed: () {
                              logger.i('restQuarter pressed');
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _restButton(
                            rest8th.character,
                            onPressed: () {
                              logger.i('rest8th pressed');
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          _restButton(
                            rest16th.character,
                            onPressed: () {
                              logger.i('rest16th pressed');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 10,
                  ),
                  //  entry details
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            checkColor: Colors.white,
                            fillColor: MaterialStateProperty.all(_blue.color),
                            value: _isDot,
                            onChanged: (bool? value) {
                              if (value != null) {
                                setState(() {
                                  _isDot = value;
                                });
                              }
                            },
                          ),
                          TextButton(
                            child: Text(
                              '+dot',
                              style: _style,
                            ),
                            onPressed: () {
                              setState(() {
                                _isDot = !_isDot;
                              });
                            },
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Checkbox(
                              checkColor: Colors.white,
                              fillColor: MaterialStateProperty.all(_blue.color),
                              value: _isTie,
                              onChanged: (bool? value) {
                                if (value != null) {
                                  setState(() {
                                    _isTie = value;
                                    logger.i('_isTie: $_isTie');
                                  });
                                }
                              }),
                          TextButton(
                            child: Text(
                              '+tie',
                              style: _style,
                            ),
                            onPressed: () {
                              setState(() {
                                _isTie = !_isTie;
                                logger.i('_isTie: $_isTie');
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          Text(
                            'Lyrics:',
                            style: _style,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          SizedBox(
                            width: 250,
                            height: 70,
                            child: TextField(
                              //    key: const ValueKey('lyrics'),
                              controller: _lyricsTextEditingController,
                              decoration: const InputDecoration(
                                hintText: 'Enter lyrics',
                              ),
                              maxLength: null,
                              style: _style,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    width: 10,
                  ),
                  // timing
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Time:',
                            style: _style,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          DropdownButton<TimeSignature>(
                            items: knownTimeSignatures.map((TimeSignature value) {
                              return DropdownMenuItem<TimeSignature>(
                                key: ValueKey('timeSignature_${value.beatsPerBar}_${value.unitsPerMeasure}'),
                                value: value,
                                child: Text(
                                  value.toString(),
                                  style: _style,
                                ),
                              );
                            }).toList(),
                            onChanged: (_value) {
                              if (_value != null && _value != _timeSignature) {
                                setState(() {
                                  _timeSignature = _value;
                                });
                              }
                            },
                            value: _timeSignature,
                            style: const AppTextStyle(
                              //  size controlled by textScaleFactor above
                              color: Colors.black,
                              textBaseline: TextBaseline.ideographic,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            'BPM:',
                            style: _style,
                          ),
                          SizedBox(
                            width: _fontSize * 2,
                            child: TextField(
                              //    key: const ValueKey('lyrics'),
                              controller: _bpmTextEditingController,
                              decoration: const InputDecoration(
                                hintText: 'Enter BPM',
                              ),
                              maxLength: null,
                              style: _style,
                              onChanged: (value) {
                                try {
                                  var tmpBPM = int.parse(value);
                                  if (tmpBPM >= MusicConstants.minBpm && tmpBPM <= MusicConstants.maxBpm) {
                                    setState(() {
                                      _bpm = tmpBPM;
                                    });
                                  } else {
                                    logger.i('not a valid BPM: $tmpBPM');
                                  }
                                } catch (e) {
                                  logger.i('not a valid BPM: $value');
                                }
                              },
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Checkbox(
                            checkColor: Colors.white,
                            fillColor: MaterialStateProperty.all(_blue.color),
                            value: _isSwing,
                            onChanged: (bool? value) {
                              if (value != null) {
                                setState(() {
                                  _isSwing = value;
                                });
                              }
                            },
                          ),
                          TextButton(
                            child: Text(
                              'Swing',
                              style: _style,
                            ),
                            onPressed: () {
                              setState(() {
                                _isSwing = !_isSwing;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              //  run controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _commandButton('Loop 1', onPressed: () {}),
                  _commandButton('Loop 2', onPressed: () {}),
                  _commandButton('Loop 4', onPressed: () {}),
                  _commandButton('Loop selected', onPressed: () {}),
                  _commandButton('Loop', onPressed: () {}),
                  _commandButton('Play', onPressed: () {}),
                  _commandButton('Stop', onPressed: () {}),
                  _commandButton('Options', onPressed: () {
                    setState(() {
                      _options = !_options;
                    });
                  }),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              _sheetDisplayEnableOptionsWidget,
              //  sheet music
              Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    setState(() {
                      _app.selectedMomentNumber -= pointerSignal.scrollDelta.dy > 0 ? -1 : 1;
                    });
                  }
                },
                child: RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: _bassOnKey,
                  autofocus: true,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: _sheetMusicPainter,
                          isComplex: true,
                          willChange: false,
                          child: sheetMusicSizedBox,
                        ),
                      ),
                      GestureDetector(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _SheetMusicDragger(_sheetMusicPainter),
                            isComplex: true,
                            willChange: false,
                            child: sheetMusicSizedBox,
                          ),
                        ),
                        onHorizontalDragStart: (details) {
                          dragStart(details.localPosition);
                        },
                        onHorizontalDragDown: (dragDownDetails) {
                          dragUpdate(dragDownDetails.localPosition);
                        },
                        onHorizontalDragUpdate: (dragUpdateDetails) {
                          dragUpdate(dragUpdateDetails.localPosition);
                        },
                        onHorizontalDragCancel: () {
                          dragStop();
                        },
                        onHorizontalDragEnd: (details) {
                          dragStop();
                        },
                        onVerticalDragStart: (details) {
                          dragStart(details.localPosition);
                        },
                        onVerticalDragDown: (dragDownDetails) {
                          dragUpdate(dragDownDetails.localPosition);
                        },
                        onVerticalDragUpdate: (dragUpdateDetails) {
                          dragUpdate(dragUpdateDetails.localPosition);
                        },
                        onVerticalDragCancel: () {
                          dragStop();
                        },
                        onVerticalDragEnd: (details) {
                          dragStop();
                        },
                      ),

                      // Positioned(
                      //     top: 225 - (bassClef.bounds.top - bassClef.bounds.bottom)/2 * staffSpace * 5,
                      //     left: 75,
                      //     child: Text(
                      //       bassClef.character,
                      //       style: const TextStyle(
                      //         fontFamily: 'Bravura',
                      //         color: Colors.black,
                      //         fontSize: staffSpace * 5,
                      //       ),
                      //     )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        tooltip: 'Back',
        child: const Icon(Icons.arrow_back),
      ),
    );
  }

  void dragStart(Offset start) {
    _dragStart = start;
    _dragEnd = null;
    setState(() {});
  }

  void dragUpdate(Offset end) {
    _dragEnd = end;
    setState(() {});
  }

  void dragStop() {
    _dragStart = null;
    _dragEnd = null;
    setState(() {});
  }

  void _bassOnKey(RawKeyEvent value) {
    if (value.runtimeType == RawKeyDownEvent) {
      RawKeyDownEvent e = value as RawKeyDownEvent;
      //  only deal with new key down events

      if (e.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
        setState(() {
          _app.selectedMomentNumber -= 1;
        });
      } else if (e.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        setState(() {
          _app.selectedMomentNumber += 1;
        });
      }
    }
  }

  @override
  void dispose() {
    _lyricsTextEditingController.dispose();
    _bpmTextEditingController.dispose();
    super.dispose();
    logger.d('bass dispose()');
  }

  bool _options = false;

  bool _isDot = false;
  bool _isTie = false;
  final TextEditingController _lyricsTextEditingController = TextEditingController();
  final TextEditingController _bpmTextEditingController = TextEditingController();

  ChordDescriptor chordDescriptor = ChordDescriptor.major;
  AppTextStyle _style = const AppTextStyle();

  final App _app = App();
}

class _FretBoardPainter extends CustomPainter {
  @override
  void paint(Canvas aCanvas, Size size) {
    canvas = aCanvas;
    var width = size.width;
    var height = size.height;

    if (_lastWidth != width) {
      //  lazy eval
      _lastWidth = width;
      fretLocs.clear();
    }

    var margin = width * 0.1;
    bassFretX = margin;
    bassFretY = 0;
    bassFretHeight = height;
    bassScale = width - 2 * margin;

    //  clear the fretboard
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), _white);

    //  frets
    _black.strokeWidth = 2;
    {
      var fretYmin = bassFretY + bassFretHeight / 16;
      var fretYmax = bassFretY + bassFretHeight - bassFretHeight / 16;
      for (var fret = 0; fret <= 12; fret++) {
        _black.strokeWidth = fret == 0 ? 6 : 2;
        var x = fretLoc(fret);
        canvas.drawLine(Offset(x, fretYmin), Offset(x, fretYmax), _black);
      }
    }

    //  strings
    for (var s = 0; s < 4; s++) {
      _stringGrey.strokeWidth = (4 - s) * 2;

      var y = bassFretY + bassFretHeight - bassFretHeight * s / 4 - bassFretHeight / 8;
      canvas.drawLine(Offset(bassFretX, y), Offset(bassFretX + bassScale, y), _stringGrey);
    }

    //  dots on frets 3, 5, 7, 9
    {
      _dotColor.strokeWidth = 3;
      double dotRadius = 10;
      for (var i = 0; i < 4; i++) {
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset((fretLoc(2 + 2 * i) + fretLoc(2 + 2 * i + 1)) / 2, bassFretY + bassFretHeight / 2),
                width: 2 * dotRadius,
                height: 2 * dotRadius),
            0,
            2 * pi,
            true,
            _dotColor);
      }
      //  double dots on fret 12
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset((fretLoc(11) + fretLoc(12)) / 2, bassFretY + bassFretHeight / 4),
              width: 2 * dotRadius,
              height: 2 * dotRadius),
          0,
          2 * pi,
          true,
          _dotColor);
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset((fretLoc(11) + fretLoc(12)) / 2, bassFretY + bassFretHeight * 3 / 4),
              width: 2 * dotRadius,
              height: 2 * dotRadius),
          0,
          2 * pi,
          true,
          _dotColor);
    }

    //  compute scale notes
    music_key.Key rootKey = music_key.Key.getKeyByHalfStep(_chordRoot.halfStep);
    var fretBoardNotes = SplayTreeSet<ScaleNote>();
    for (int n = 0; n < MusicConstants.notesPerScale; n++) {
      fretBoardNotes.add(_key.inKey(
          _scaleChord.chordDescriptor.isMajor() ? rootKey.getMajorScaleByNote(n) : rootKey.getMinorScaleByNote(n)));
    }

    fretBoardNotes.addAll(_scaleChord.chordNotes(rootKey));

    var chordComponents = _scaleChord.getChordComponents();
    var bassHalfStepOffset = Pitch.get(PitchEnum.E1).scaleNote.halfStep;

    for (var fret = 0; fret <= 12; fret++) {
      for (var bassString = 0; bassString < 4; bassString++) {
        var halfStep = (bassString * 5 + fret) % MusicConstants.halfStepsPerOctave;
        var scaleNote =
            _key.inKey(rootKey.getKeyScaleNoteByHalfStep(bassHalfStepOffset - rootKey.getHalfStep() + halfStep));

        if (fretBoardNotes.contains(scaleNote) || fretBoardNotes.contains(scaleNote.alias)) {
          var halfStepOff = (scaleNote.halfStep - rootKey.halfStep) % MusicConstants.halfStepsPerOctave;
          var chordComponent = ChordComponent.values[halfStepOff];

          Paint paint = _scaleColor;
          if (chordComponents.contains(chordComponent)) {
            if (chordComponent == ChordComponent.root) {
              paint = _rootColor;
            } else if (chordComponent == ChordComponent.minorThird || chordComponent == ChordComponent.third) {
              paint = _thirdColor;
            } else if (chordComponent == ChordComponent.flatFifth || chordComponent == ChordComponent.fifth) {
              paint = _fifthColor;
            } else if (chordComponent == ChordComponent.minorSeventh || chordComponent == ChordComponent.seventh) {
              paint = _seventhColor;
            } else {
              //  ninth   eleventh  thirteenth
              paint = _otherColor;
            }
          }
          press(paint, bassString, fret, scaleNote.toString(), chordComponent.shortName);
        }
      }
    }
  }

  void press(Paint paint, int bassString, int fret, String? noteChar, String? scaleChar) {
    fret = max(0, min(12, fret));
    bassString = max(0, min(3, bassString));
    const double pressRadius = 20;
    var offset = Offset(fretLoc(fret) - pressRadius - 4,
        bassFretY + bassFretHeight - bassFretHeight * bassString / 4 - bassFretHeight / 8);
    canvas.drawCircle(offset, pressRadius, paint);
    canvas.drawCircle(offset, pressRadius, _blackOutline);
    if (noteChar != null && _isShowScaleNotes) {
      // To create a paragraph of text, we use ParagraphBuilder.
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textDirection: ui.TextDirection.ltr),
      )
        ..pushStyle(ui.TextStyle(
            color: Colors.black,
            fontSize: _fontSize,
            fontWeight: FontWeight.bold,
            fontFamilyFallback: appFontFamilyFallback))
        ..addText(noteChar);
      var paragraph = builder.build()..layout(ui.ParagraphConstraints(width: 4 * _fontSize));
      canvas.drawParagraph(
          paragraph, Offset(offset.dx - paragraph.maxIntrinsicWidth / 2, offset.dy - paragraph.height / 2));
    }
    if (scaleChar != null && _isShowScaleNumbers) {
      // To create a paragraph of text, we use ParagraphBuilder.
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textDirection: ui.TextDirection.ltr),
      )
        ..pushStyle(ui.TextStyle(
            color: Colors.black,
            fontSize: _fontSize,
            fontWeight: FontWeight.bold,
            fontFamilyFallback: appFontFamilyFallback))
        ..addText(scaleChar);
      var paragraph = builder.build()..layout(ui.ParagraphConstraints(width: 4 * _fontSize));
      canvas.drawParagraph(paragraph,
          Offset(offset.dx - pressRadius * 3 / 2 - paragraph.maxIntrinsicWidth, offset.dy - paragraph.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //  fixme optimize?
  }

  double fretLoc(int n) {
    n = max(0, min(12, n));

    if (fretLocs.isEmpty) {
      for (var i = 0; i <= 12; i++) {
        fretLocs.add(bassFretX + 2 * (bassScale - ((bassScale / pow(2, i / 12)))));
      }
    }
    return fretLocs[n];
  }

  double fretWidth(int n) {
    n = max(0, min(12, n));

    if (fretWidths.isEmpty) {
      fretWidths.add(fretLoc(1) - fretLoc(0)); //  at 0
      for (var i = 0; i < 12; i++) {
        fretWidths.add(fretLoc(i + 1) - fretLoc(i));
      }
    }
    return fretWidths[n];
  }

  final music_key.Key keyE = music_key.Key.get(music_key.KeyEnum.E);

  late Canvas canvas;
  final List<double> fretLocs = [];
  final List<double> fretWidths = [];
  double bassFretHeight = 200;
  double bassFretY = 0;
  double bassFretX = 63;
  double bassScale = 2000;
  double _lastWidth = 0;
}

ElevatedButton _restButton(
  String character, {
  required VoidCallback? onPressed,
}) {
  return _noteButton(
    character,
    onPressed: onPressed,
    height: 1,
  );
}

ElevatedButton _noteButton(
  String character, {
  required VoidCallback? onPressed,
  double height = 2,
}) {
  return ElevatedButton(
    child: Text(
      character,
      style: TextStyle(
        fontFamily: 'Bravura',
        fontSize: 50,
        foreground: _black,
        background: _blue,
        height: height,
        fontFeatures: const [FontFeature.stylisticAlternates()],
      ),
    ),
    clipBehavior: Clip.hardEdge,
    onPressed: onPressed,
    style: ButtonStyle(
      fixedSize: MaterialStateProperty.all(const Size(40, 60)),
      backgroundColor: MaterialStateProperty.all(_blue.color),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_fontSize / 4), side: const BorderSide(color: Colors.grey))),
      elevation: MaterialStateProperty.all<double>(6),
    ),
  );
}

ElevatedButton _commandButton(
  String commandName, {
  required VoidCallback? onPressed,
  double height = 1.5,
}) {
  return ElevatedButton(
    child: Text(
      commandName,
      style: TextStyle(
        fontSize: _fontSize,
        foreground: _black,
        background: _blue,
        height: height,
      ),
    ),
    clipBehavior: Clip.hardEdge,
    onPressed: onPressed,
    style: ButtonStyle(
      backgroundColor: MaterialStateProperty.all(_blue.color),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_fontSize), side: const BorderSide(color: Colors.grey))),
      elevation: MaterialStateProperty.all<double>(6),
    ),
  );
}

class _SheetMusicDragger extends CustomPainter {
  _SheetMusicDragger(this.sheetMusicPainter);

  @override
  void paint(Canvas canvas, Size size) {
    //  clear the plot
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _transClear);

    if (_dragStart == null) {
      return;
    }

    _dragEnd ??= _dragStart;
    Rect selectRect = Rect.fromPoints(_dragStart!, _dragEnd!);

    // for (var sheetNoteLocation in sheetMusicPainter.sheetNoteLocations) {  fixme now
    //   if (selectRect.overlaps(sheetNoteLocation.location)) {
    //     var noteRect = sheetNoteLocation.location.inflate(_selectStrokeWidth);
    //     canvas.drawRect(noteRect, _transBlueOutline);
    //     selectRect = selectRect.expandToInclude(noteRect);
    //   }
    // }

    canvas.drawRect(selectRect.inflate(2 * _selectStrokeWidth), _transBlueOutline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }

  final SheetMusicPainter sheetMusicPainter;
  static const _selectStrokeWidth = 3.0;
  final _transBlueOutline = Paint()
    ..color = Colors.lightBlueAccent.withAlpha(200)
    ..style = PaintingStyle.stroke
    ..strokeWidth = _selectStrokeWidth;

  // final _transRed = Paint()..color = Colors.redAccent.withAlpha(80);
  final _transClear = Paint()..color = Colors.white.withAlpha(0);
}
