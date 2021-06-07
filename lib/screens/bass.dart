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
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicPainter.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:bsteele_music_flutter/util/appTextStyle.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
final _grey = Paint()..color = Colors.grey;
final _dotColor = Paint()..color = Colors.blue[100] ?? Colors.blue;
final _rootColor = Paint()..color = Colors.red;
final _thirdColor = Paint()..color = const Color(0xffffb390);
final _fifthColor = Paint()..color = const Color(0xffffa500);
final _seventhColor = Paint()..color = const Color(0xffffff00);
final _otherColor = Paint()..color = const Color(0x80A3FF69);
final _scaleColor = Paint()..color = const Color(0x80ffffff);
double _fontSize = 24;

music_key.Key _key = music_key.Key.getDefault();
ScaleNote _chordRoot = _key.getKeyScaleNote();
ScaleChord _scaleChord = ScaleChord(_key.getKeyScaleNote(), ChordDescriptor.defaultChordDescriptor());

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
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    _fontSize = screenInfo.isTooNarrow ? 16 : max(24, screenInfo.widthInLogicalPixels / 100);

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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Bass Study Tool',
          style: AppTextStyle(color: Colors.black87, fontSize: _fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(
            height: 10,
          ),
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
                              logger.i('isDot: $_isDot');
                            });
                          }
                        },
                      ),
                      Text(
                        '+dot',
                        style: _style,
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
                      Text(
                        '+tie',
                        style: _style,
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
                        width:250,
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
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Stack(
            fit: StackFit.passthrough,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: SheetMusicPainter(),
                  isComplex: true,
                  willChange: false,
                  child: const SizedBox(
                    width: double.infinity,
                    height: 400.0,
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

  @override
  void dispose() {
    _lyricsTextEditingController.dispose();
    super.dispose();
    logger.d('bass dispose()');
  }

  bool _isDot = false;
  bool _isTie = false;
  final TextEditingController _lyricsTextEditingController = TextEditingController();
  ChordDescriptor chordDescriptor = ChordDescriptor.major;
  AppTextStyle _style = const AppTextStyle();
}

class _FretBoardPainter extends CustomPainter {
  @override
  void paint(Canvas aCanvas, Size size) {
    canvas = aCanvas;
    var width = size.width;
    var height = size.height;

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
      _grey.strokeWidth = (4 - s) * 2;

      var y = bassFretY + bassFretHeight - bassFretHeight * s / 4 - bassFretHeight / 8;
      canvas.drawLine(Offset(bassFretX, y), Offset(bassFretX + bassScale, y), _grey);
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
    if (noteChar != null) {
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
    if (scaleChar != null) {
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
    ),
  );
}
