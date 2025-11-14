import 'dart:collection';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicPainter.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/chord.dart';
import 'package:bsteele_music_lib/songs/chord_anticipation_or_delay.dart';
import 'package:bsteele_music_lib/songs/chord_component.dart';
import 'package:bsteele_music_lib/songs/chord_descriptor.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/pitch.dart';
import 'package:bsteele_music_lib/songs/scale_chord.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/time_signature.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _black = Paint()..color = Colors.black;
final _blackOutline = Paint()
  ..color = Colors.black
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1;
// final _scaleBlackOutline = Paint()
//   ..color = Colors.black38
//   ..style = PaintingStyle.stroke
//   ..strokeWidth = 1;

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

bool get _isShowScaleNumbers => sheetDisplayEnables[SheetDisplay.bassNoteNumbers.index];

bool get _isShowScaleNotes => sheetDisplayEnables[SheetDisplay.bassNotes.index];
bool _isSwing = true;
TimeSignature _timeSignature = TimeSignature.defaultTimeSignature;
int _bpm = 106;

final _defaultChord = Chord(ScaleChord(ScaleNote.C, ChordDescriptor.defaultChordDescriptor()), 4, 4, null,
    ChordAnticipationOrDelay.defaultValue, false);

Chord _getChord() {
  if (app.selectedSong.songMoments.isNotEmpty) {
    var songMoment = app.selectedSong.songMoments[app.selectedMomentNumber];
    var m = songMoment.measure;
    if (m.chords.isNotEmpty) {
      return m.chords[0].transpose(_key, 0); // fixme!!!!!!!!!!!
    }
  }
  return _defaultChord;
}

/// the bass study tool
class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  DetailState createState() => DetailState();
}

class DetailState extends State<Detail> {
  @override
  initState() {
    super.initState();

    _lyricsTextEditingController.addListener(() {
      logger.i('lyrics: <${_lyricsTextEditingController.text}>');
    });

    _key = app.selectedSong.key;
    logger.d('key: $_key');

    for (var sheetDisplay in appOptions.sheetDisplays) {
      sheetDisplayEnables[sheetDisplay.index] = true;
    }

    //  initialize at least a minimum sheet display
    {
      var hasSomeDisplay = false;
      for (var displayEnable in sheetDisplayEnables) {
        hasSomeDisplay |= displayEnable;
      }

      if (!hasSomeDisplay) {
        //  initial defaults only
        sheetDisplayEnables[SheetDisplay.section.index] = true;
        sheetDisplayEnables[SheetDisplay.measureCount.index] = true;
        sheetDisplayEnables[SheetDisplay.lyrics.index] = true;
        sheetDisplayEnables[SheetDisplay.chords.index] = true;
        sheetDisplayEnables[SheetDisplay.pianoChords.index] = true;
        // sheetDisplayEnables[SheetDisplay.pianoTreble.index]=true;
        // sheetDisplayEnables[SheetDisplay.pianoBass.index]=true;
        //sheetDisplayEnables[SheetDisplay.bassNoteNumbers.index] = true;
        //sheetDisplayEnables[SheetDisplay.bassNotes.index] = true;
        sheetDisplayEnables[SheetDisplay.bass8vb.index] = true;
        storeSheetDisplayEnables();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);
    app.screenInfo.refresh(context);

    _fontSize = App().screenInfo.fontSize * 2 / 3;

    // logger.i('WidgetsBinding.instance: ${WidgetsBinding.instance?.runtimeType}');

    _style = generateAppTextStyle(color: Colors.black87, fontSize: _fontSize);

    _bpmTextEditingController.text = _bpm.toString();

    //  sheet display enables
    Widget sheetDisplayEnableOptionsWidget = const SizedBox(
      height: 0,
    );
    if (_options) {
      List<Widget> children = [];
      for (var display in SheetDisplay.values) {
        var name = Util.firstToUpper(Util.camelCaseToLowercaseSpace(display.name));
        children.add(Row(
          children: [
            appWidgetHelper.checkbox(
              value: sheetDisplayEnables[display.index],
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    sheetDisplayEnables[display.index] = value;
                    storeSheetDisplayEnables();
                    logger.i('detail: $name: ${sheetDisplayEnables[display.index]}');
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
                  storeSheetDisplayEnables();
                  logger.i('TextButton $name: ${sheetDisplayEnables[display.index]}');
                });
              },
            ),
          ],
        ));
      }

      children.add(const AppSpace());
      children.add(appButton('Close the options', onPressed: () {
        setState(() {
          _options = false;
        });
      }, fontSize: _fontSize));

      sheetDisplayEnableOptionsWidget = Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: children,
        ),
      );
    }

    const sheetMusicSizedBox = SizedBox(
      width: .infinity,
      height: 1000.0,
    );

    SheetMusicPainter sheetMusicPainter = SheetMusicPainter();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appWidgetHelper.backBar(
          title: '${app.selectedSong}'
              ' (sheet music)'),
      body: Wrap(
        children: <Widget>[
          Column(
            children: [
              const AppSpace(),
              if (hasDisplay(.bass8vb))
                CustomPaint(
                  painter: _FretBoardPainter(),
                  isComplex: true,
                  willChange: false,
                  child: const SizedBox(
                    width: double.infinity,
                    height: 200.0,
                  ),
                ),
              const AppSpace(),
              Row(
                mainAxisAlignment: .center,
                crossAxisAlignment: .center,
                children: [
                  // key, chords
                  Column(
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Key: $_key',
                            style: _style,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 12 * _fontSize,
                            child: Text(
                              'Chord: ${_getChord()}',
                              style: _style,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const AppSpace(),
                  //  notes and rests
                  Column(
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        children: [
                          appNoteButton(
                            noteWhole.character,
                            onPressed: () {
                              logger.i('noteWhole pressed');
                            },
                          ),
                          const AppSpace(),
                          appNoteButton(
                            noteHalfUp.character,
                            onPressed: () {
                              logger.i('noteHalfUp pressed');
                            },
                          ),
                          const AppSpace(),
                          appNoteButton(
                            noteQuarterUp.character,
                            onPressed: () {
                              logger.i('noteQuarterUp pressed');
                            },
                          ),
                          const AppSpace(),
                          appNoteButton(
                            note8thUp.character,
                            onPressed: () {
                              logger.i('note8thUp pressed');
                            },
                          ),
                          const AppSpace(),
                          appNoteButton(
                            note16thUp.character,
                            onPressed: () {
                              logger.i('note16thUp pressed');
                            },
                          ),
                        ],
                      ),
                      const AppSpace(),
                      Row(
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          _restButton(
                            restWhole.character,
                            onPressed: () {
                              logger.i('restWhole pressed');
                            },
                          ),
                          const AppSpace(),
                          _restButton(
                            restHalf.character,
                            onPressed: () {
                              logger.i('restHalf pressed');
                            },
                          ),
                          const AppSpace(),
                          _restButton(
                            restQuarter.character,
                            onPressed: () {
                              logger.i('restQuarter pressed');
                            },
                          ),
                          const AppSpace(),
                          _restButton(
                            rest8th.character,
                            onPressed: () {
                              logger.i('rest8th pressed');
                            },
                          ),
                          const AppSpace(),
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
                  const AppSpace(),
                  //  entry details
                  Column(
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        children: [
                          appWidgetHelper.checkbox(
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
                          const AppSpace(),
                          appWidgetHelper.checkbox(
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
                      const AppSpace(),
                      Row(
                        children: [
                          Text(
                            'Lyrics:',
                            style: _style,
                          ),
                          const AppSpace(),
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
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Time:',
                            style: _style,
                          ),
                          const AppSpace(),
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
                            onChanged: (value) {
                              if (value != null && value != _timeSignature) {
                                setState(() {
                                  _timeSignature = value;
                                });
                              }
                            },
                            value: _timeSignature,
                            style: generateAppTextStyle(
                              textBaseline: TextBaseline.ideographic, //  fixme: what is this and why?
                            ),
                            itemHeight: null,
                          ),
                        ],
                      ),
                      Row(
                        children: [
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
                        ],
                      ),
                      Row(
                        children: [
                          appWidgetHelper.checkbox(
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
              const AppSpace(),
              //  run controls
              Row(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  appButton('Loop 1', onPressed: () {}, fontSize: _fontSize),
                  appButton('Loop 2', onPressed: () {}, fontSize: _fontSize),
                  appButton('Loop 4', onPressed: () {}, fontSize: _fontSize),
                  appButton('Loop selected', onPressed: () {}, fontSize: _fontSize),
                  appButton('Loop', onPressed: () {}, fontSize: _fontSize),
                  appButton('Play', onPressed: () {}, fontSize: _fontSize),
                  appButton('Stop', onPressed: () {}, fontSize: _fontSize),
                  appButton('Options', onPressed: () {
                    setState(() {
                      _options = !_options;
                    });
                  }, fontSize: _fontSize),
                ],
              ),
              const AppSpace(),
              sheetDisplayEnableOptionsWidget,
              //  sheet music
              Focus(
                focusNode: FocusNode(),
                onKeyEvent: _detailOnKey,
                autofocus: true,
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      setState(() {
                        bumpMeasureSelection(pointerSignal.scrollDelta.dy > 0 ? 1 : -1);
                      });
                    }
                  },
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: sheetMusicPainter,
                          isComplex: true,
                          willChange: false,
                          child: sheetMusicSizedBox,
                        ),
                      ),
                      GestureDetector(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _SheetMusicDragger(sheetMusicPainter),
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
      floatingActionButton: appWidgetHelper.floatingBack(),
    );
  }

  void bumpMeasureSelection(int bump) {
    app.selectedMomentNumber += bump;
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

  KeyEventResult _detailOnKey(FocusNode node, KeyEvent e) {
    //  only deal with new key down or repeat events
    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      logger.i('_detailOnKey(${e.logicalKey.keyLabel})');

      if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() {
          bumpMeasureSelection(-1);
        });
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() {
          bumpMeasureSelection(1);
        });
        return KeyEventResult.handled;
      } else if (e.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  ElevatedButton _restButton(
    String character, {
    required VoidCallback? onPressed,
  }) {
    return appNoteButton(
      character,
      onPressed: onPressed,
      height: 1,
    );
  }

  @override
  void dispose() {
    _lyricsTextEditingController.dispose();
    _bpmTextEditingController.dispose();
    super.dispose();
    logger.d('bass dispose()');
  }

  void storeSheetDisplayEnables() {
    HashSet<SheetDisplay> store = HashSet();
    for (var sheetDisplay in SheetDisplay.values) {
      if (sheetDisplayEnables[sheetDisplay.index]) {
        store.add(sheetDisplay);
      }
    }
    appOptions.sheetDisplays = store;
  }

  bool _options = false;

  bool _isDot = false;
  bool _isTie = false;
  final TextEditingController _lyricsTextEditingController = TextEditingController();
  final TextEditingController _bpmTextEditingController = TextEditingController();

  TextStyle _style = generateAppTextStyle();
  final AppOptions appOptions = AppOptions();
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
      fretLocations.clear();
    }

    var margin = width * 0.1;
    bassFretX = margin;
    bassFretY = 0;
    bassFretHeight = height;
    bassScale = width - 2 * margin;

    //  clear the fretboard
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = app.themeData.colorScheme.surface);

    //  frets
    _black.strokeWidth = 2;
    {
      var fretYMin = bassFretY + bassFretHeight / 16;
      var fretYMax = bassFretY + bassFretHeight - bassFretHeight / 16;
      for (var fret = 0; fret <= 12; fret++) {
        _black.strokeWidth = fret == 0 ? 6.0 : 2.0;
        var x = fretLoc(fret);
        canvas.drawLine(Offset(x, fretYMin), Offset(x, fretYMax), _black);
      }
    }

    //  strings
    final stringGrey = Paint()..color = App.disabledColor;
    for (var s = 0; s < 4; s++) {
      stringGrey.strokeWidth = (4.0 - s) * 3.0;

      var y = bassFretY + bassFretHeight - bassFretHeight * s / 4 - bassFretHeight / 8;
      canvas.drawLine(Offset(bassFretX, y), Offset(bassFretX + 1.05 * bassScale /* over-run */, y), stringGrey);
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
    Chord chord = _getChord(); //  fixme!!!!!!!!!!!!!!!!!!!
    ScaleChord scaleChord = chord.scaleChord;
    music_key.Key rootKey = music_key.Key.getKeyByHalfStep(chord.scaleChord.scaleNote.halfStep);
    final fretBoardNotes = SplayTreeSet<ScaleNote>();
    for (int n = 0; n < MusicConstants.notesPerScale; n++) {
      fretBoardNotes.add(_key.inKey(
          scaleChord.chordDescriptor.isMajor() ? rootKey.getMajorScaleByNote(n) : rootKey.getMinorScaleByNote(n)));
    }

    fretBoardNotes.addAll(scaleChord.chordNotes(rootKey));

    var chordComponents = scaleChord.getChordComponents();
    var bassHalfStepOffset = Pitch.get(.E1).scaleNote.halfStep;

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
      // create a paragraph of text using ParagraphBuilder.
      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textDirection: ui.TextDirection.ltr),
      )
        ..pushStyle(ui.TextStyle(
            color: Colors.black,
            fontSize: _fontSize,
            fontWeight: .bold,
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
            fontWeight: .bold,
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

    if (fretLocations.isEmpty) {
      for (var i = 0; i <= 12; i++) {
        fretLocations.add(bassFretX + 2 * (bassScale - ((bassScale / pow(2, i / 12)))));
      }
    }
    return fretLocations[n];
  }

  // double _fretWidth(int n) {
  //   n = max(0, min(12, n));
  //
  //   if (fretWidths.isEmpty) {
  //     fretWidths.add(fretLoc(1) - fretLoc(0)); //  at 0
  //     for (var i = 0; i < 12; i++) {
  //       fretWidths.add(fretLoc(i + 1) - fretLoc(i));
  //     }
  //   }
  //   return fretWidths[n];
  // }

  final music_key.Key keyE = music_key.Key.E;

  late Canvas canvas;
  final List<double> fretLocations = [];
  final List<double> fretWidths = [];
  double bassFretHeight = 200;
  double bassFretY = 0;
  double bassFretX = 63;
  double bassScale = 2000;
  double _lastWidth = 0;
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

    for (var sheetNoteLocation in SheetNotationList.sheetNoteLocations) {
      if (selectRect.overlaps(sheetNoteLocation.location)) {
        var noteRect = sheetNoteLocation.location.inflate(_selectStrokeWidth);
        canvas.drawRect(noteRect, _transBlueOutline);
        selectRect = selectRect.expandToInclude(noteRect);
      }
    }

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
