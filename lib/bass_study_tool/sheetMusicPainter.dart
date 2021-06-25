import 'dart:math';
import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chord.dart';
import 'package:bsteeleMusicLib/songs/chordAnticipationOrDelay.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/pitch.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/bass_study_tool/bassStudyTool.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicFontParameters.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:flutter/material.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as musical_key;

const double staffLineCount = 5;
const double staffSpace = 16;

const bool _debug = false; //  true false
const double _fontSize = 15;

// For piano chords, try:  https://www.scales-chords.com/chord/piano

List<double> _sheetXOffsets = List.filled(SheetDisplay.values.length, 0);
List<double> _sheetYOffsets = List.filled(SheetDisplay.values.length, 0);

final List<double> _sheetHeights = List.generate(SheetDisplay.values.length, (index) {
  final staffHeight = (staffLineCount + 2 * staffMargin /* top and bottom */) * staffSpace;
  switch (SheetDisplay.values[index]) {
    case SheetDisplay.lyrics:
    case SheetDisplay.chords:
      return _fontSize * 2;
    case SheetDisplay.guitarFingerings:
      return staffHeight;
    case SheetDisplay.pianoChords:
    case SheetDisplay.pianoTreble:
    case SheetDisplay.pianoBass: //  piano left hand
      return staffHeight;
    case SheetDisplay.bassNoteNumbers:
    case SheetDisplay.bassNotes:
      return _fontSize * 3;
    case SheetDisplay.bass:
      return staffHeight;
    default:
      return 0;
  }
}, growable: false);

class SheetMusicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _canvas = canvas;

    _computeTheYOffsets();

    //  clear the plot
    _sheetNoteLocations.clear();
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _white);
    _reset();
    _xSpaceAll(10);

    //  debug: mark the bottom
    canvas.drawRect(Rect.fromLTWH(0, _sheetYOffsets.last + _sheetHeights.last, size.width, 4), _black);



    for (var display in SheetDisplay.values) {
      if (hasDisplay(display)) {
        _startDisplay(display);
        switch (display) {
          default:
            _renderText(Util.enumToString(display), xOff: 25);
            break;
        }
        _endDisplay();
      }
    }
    _reset();
    _xSpaceAll(10);

    if (hasDisplay(SheetDisplay.pianoTreble) && hasDisplay(SheetDisplay.pianoBass)) {
      _startDisplay(SheetDisplay.pianoTreble);
      _renderSheetFixedYSymbol(SheetDisplay.pianoTreble, brace);
      _xSpaceAll(1.5 * staffSpace);
      _endDisplay();
    }

    //  staffs
    for (var display in [
      SheetDisplay.pianoChords,
      SheetDisplay.pianoTreble,
      SheetDisplay.pianoBass,
      SheetDisplay.bass
    ]) {
      if (hasDisplay(display)) {
        _startDisplay(display);
        renderStaff(size.width - _xOff - 10, _yOff + staffMargin * staffSpace);
        _endDisplay();
      }
    }

    _renderBarlineSingle();

    _xSpaceAll(0.5 * staffSpace);

    //  treble Clefs
    for (var display in [
      SheetDisplay.pianoChords,
      SheetDisplay.pianoTreble,
    ]) {
      if (hasDisplay(display)) {
        _startDisplay(display);
        _renderSheetFixedYSymbol(display, trebleClef);
        _endDisplay();
      }
    }

    //  bass Clefs
    for (var display in [SheetDisplay.pianoBass, SheetDisplay.bass]) {
      if (hasDisplay(display)) {
        _renderSheetFixedYSymbol(display, bassClef);
      }
    }

    _xSpaceAll(1 * staffSpace);

    // _testSong();
    if (hasDisplay(SheetDisplay.pianoChords)) {
      _startDisplay(SheetDisplay.pianoChords);
      _testChords();
      _endDisplay();
    }
//    {
//      //  hand rendering
//      _yOff = _yOffTreble;
//      renderSheetNoteSymbol(accidentalSharp, 0);
//      _yOff = _yOffBass;
//      _xOff += renderSheetNoteSymbol(accidentalSharp, 1);
//
//      _xOff += 1 * staffSpace;
//      _yOff = _yOffBass;
//
//      double staffPosition = staffGaps;
//      renderSheetNoteSymbol(timeSig4, staffPosition - 3);
//      renderSheetNoteSymbol(timeSig4, staffPosition - 1);
//
//      _yOff = _yOffTreble;
//      renderSheetNoteSymbol(timeSigCommon, 2);
//      _yOff = _yOffBass;
//
//      _xOff += 3 * staffSpace;
//
//      double xOffBass = _xOff;
//      double xOffTreble = _xOff;
//
//      //  treble note samples
//      _yOff = _yOffTreble;
//
//      //  beat 1
//      renderSheetNoteSymbol(noteQuarterUp, 4);
//      renderSheetNoteSymbol(noteQuarterUp, 3);
//      _xOff += renderSheetNoteSymbol(noteQuarterUp, 2);
//      _xOff += 3 * staffSpace;
//
//      //  beat 2
//      {
//        double firstChordRoot = 2;
//        double secondChordRoot = 2.5;
//
//        //  barred note sample
//        double firstX = _xOff + (noteQuarterUp.bounds.right - EngravingDefaults.stemThickness) * staffSpace;
//        double secondX = _xOff + (noteQuarterUp.bounds.width + 1 + noteQuarterUp.bounds.right) * staffSpace;
//        double firstY = _yOff + (firstChordRoot - GlyphBBoxesStem.bBoxNE.y) * staffSpace;
//        double secondY = _yOff + (secondChordRoot - GlyphBBoxesStem.bBoxNE.y) * staffSpace;
//
//        Path path = Path();
//        path.moveTo(firstX, firstY);
//        path.lineTo(firstX, firstY + EngravingDefaults.beamThickness * staffSpace);
//        path.lineTo(secondX, secondY + EngravingDefaults.beamThickness * staffSpace);
//        path.lineTo(secondX, secondY);
//        path.lineTo(firstX, firstY);
//
//        canvas.drawPath(path, _blackFill);
//
//        renderSheetNoteSymbol(noteQuarterUp, firstChordRoot + 2);
//        renderSheetNoteSymbol(noteQuarterUp, firstChordRoot + 1);
//        _xOff += renderSheetNoteSymbol(noteQuarterUp, firstChordRoot);
//        _xOff += 1 * staffSpace;
//
//        renderSheetNoteSymbol(noteQuarterUp, secondChordRoot + 2);
//        renderSheetNoteSymbol(noteQuarterUp, secondChordRoot + 1);
//        _xOff += renderSheetNoteSymbol(noteQuarterUp, secondChordRoot);
//        _xOff += 3 * staffSpace;
//      }
//
//      //  beat 3
//      renderSheetNoteSymbol(noteQuarterUp, 4.5);
//      renderSheetNoteSymbol(noteQuarterUp, 3.5);
//      _xOff += renderSheetNoteSymbol(note8thUp, 2.5);
//      _xOff += 1 * staffSpace;
//
//      _xOff += renderSheetFixedYSymbol(rest8th);
//      _xOff += 3 * staffSpace;
//
//      //  beat 4
//      _xOff += renderSheetFixedYSymbol(restQuarter);
//      _xOff += 3 * staffSpace;
//
//      xOffTreble = _xOff;
//
//      //  bass note samples
//      _xOff = xOffBass;
//      _yOff = _yOffBass;
//
//      {
//        //  barred note sample
//        double minX = _xOff + (noteQuarterUp.bounds.right - EngravingDefaults.stemThickness) * staffSpace;
//        double maxX = _xOff + (noteQuarterUp.bounds.width + 1 + noteQuarterUp.bounds.right) * staffSpace;
//        double minY = _yOff + (staffPosition - GlyphBBoxesStem.bBoxNE.y - EngravingDefaults.stemThickness) * staffSpace;
//        double maxY = _yOff +
//            (staffPosition -
//                    GlyphBBoxesStem.bBoxNE.y -
//                    EngravingDefaults.stemThickness +
//                    EngravingDefaults.beamThickness) *
//                staffSpace;
//
//        Path path = Path();
//        path.moveTo(minX, minY);
//        path.lineTo(maxX, minY - 1 * staffSpace);
//        path.lineTo(maxX, maxY - 1 * staffSpace);
//        path.lineTo(minX, maxY);
//        path.lineTo(minX, minY);
//
//        canvas.drawPath(path, _blackFill);
//
//        _xOff += renderSheetNoteSymbol(noteQuarterUp, staffPosition);
//        _xOff += 1 * staffSpace;
//
//        _xOff += renderSheetNoteSymbol(noteQuarterUp, staffPosition - 1);
//        _xOff += 1 * staffSpace;
//      }
//
//      staffPosition = 0.0;
//
//      _xOff += renderSheetNoteSymbol(noteQuarterDown, staffPosition - 1.5);
//      _xOff += 1 * staffSpace;
//
//      _xOff += renderSheetNoteSymbol(noteHalfDown, staffPosition + 1);
//      _xOff += 1 * staffSpace;
//
//      _xOff = max(_xOff, xOffTreble);
//
//      _xOff += renderBarlineSingle();
//      _xOff += 1 * staffSpace;
//
//      _xOff += renderSheetNoteSymbol(noteWhole, staffPosition + 4);
//      _xOff += 1 * staffSpace;
//      _xOff += renderBarlineSingle();
//      _xOff += 1 * staffSpace;
//
//      _xOff += renderSheetNoteSymbol(noteWhole, staffPosition + 5);
//
//      _xOff += 1 * staffSpace;
//
//      _xOff += renderBarlineSingle();
//      _xOff += 1 * staffSpace;
//
//      _xOff += renderSheetNoteSymbol(noteHalfUp, staffPosition + 2.5);
//      _xOff += 1 * staffSpace;
//      _xOff += renderSheetNoteSymbol(noteQuarterUp, staffPosition + 2);
//      _xOff += 0.25 * staffSpace;
//      _xOff += renderSheetNoteSymbol(augmentationDot, staffPosition + 2);
//
//      _xOff += 1 * staffSpace;
//      _xOff += renderSheetNoteSymbol(note8thDown, staffPosition);
//      _xOff += 1 * staffSpace;
//
//      _xOff += renderBarlineSingle();
//      _xOff += 1 * staffSpace;
//
//      _xOff += renderSheetFixedYSymbol(restQuarter);
//      _xOff += 1 * staffSpace;
//
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    logger.i('shouldRepaint( ${oldDelegate.runtimeType} )');
    return true;
  }

  void _computeTheYOffsets() {
    {
      double y = 0;
      var lastDisplay = SheetDisplay.values.last; //  won't match the first time
      for (var display in SheetDisplay.values) {
        _sheetYOffsets[display.index] = y;
        if (hasDisplay(display)) {
          y += _sheetHeights[display.index];

          switch (display) {
            case SheetDisplay.pianoBass:
              switch (lastDisplay) {
                case SheetDisplay.pianoTreble:
                  y += staffGaps * staffSpace;
                  break;
                default:
                  break;
              }
              break;
            default:
              break;
          }
        }
        lastDisplay = display;
      }
    }

    for (var display in SheetDisplay.values) {
      logger.i('$display: ${hasDisplay(display)}: ${_sheetYOffsets[display.index]}'
          ', height: ${_sheetHeights[display.index]}');
    }
  }

  /// render the key symbols (sharps or flats)
  void _renderKeyStaffSymbols(SheetDisplay display) {
    if (_key == null || _key == musical_key.Key.getDefault()) {
      return;
    }

    _startDisplay(display);

    int clefYOff = 0;
    switch (display) {
      case SheetDisplay.pianoBass:
      case SheetDisplay.bass:
        clefYOff = -1; //  fixme
        break;
      default:
        break;
    }

    //  key
    List<double> locations = (_key?.isSharp ?? false ? keySharpLocations : keyFlatLocations);
    SheetNoteSymbol symbol = (_key?.isSharp ?? false ? accidentalSharp : accidentalFlat);
    int limit = _key?.getKeyValue().abs() ?? 0;
    for (int i = 1; i <= limit; i++) {
      //  compute height of sharp/flat from note
      //if (doRender)
      _renderSheetNoteSymbol(symbol, locations[i] + clefYOff);
      _xSpace(symbol.width / 2);
    }

    //  end at the end of the last character
    _xSpace(symbol.width / 2);
  }

  //  flats:                                B♭,E♭,A♭,D♭, G♭,  C♭,F♭
  //  at bass locations
  List<double> keyFlatLocations = /* */ [0, 3, 1.5, 3.5, 2, 4, 2.5, 4.5];

  //	sharps:                               F♯,C♯, G♯, D♯, A♯,  E♯,  B♯
  //  at bass locations
  List<double> keySharpLocations = /**/ [0, 1, 2.5, 0.5, 2, 3.5, 1.5, 3];

  void renderStaff(double width, double y) {
    final black = Paint();
    black.color = Colors.black;
    black.style = PaintingStyle.stroke;
    black.strokeWidth = _staffLineThickness * staffSpace;

    for (int line = 0; line < 5; line++) {
      _canvas.drawLine(Offset(_xOff, y + line * staffSpace), Offset(_xOff + width, y + line * staffSpace), black);
    }
  }

  void renderStaves(SheetNoteSymbol symbol, double staffPosition) {
    //  truncate to staff line height
    staffPosition = staffPosition.toInt().toDouble();

    if (staffPosition >= 0 && staffPosition <= staffGaps) {
      return;
    }

    final black = Paint();
    black.color = Colors.black;
    black.style = PaintingStyle.stroke;
    black.strokeWidth = _staffLineThickness * staffSpace;

    while (staffPosition < 0) {
      _canvas.drawLine(Offset(_xOff + (symbol.bounds.left - 0.5) * staffSpace, _yOff + staffPosition * staffSpace),
          Offset(_xOff + (symbol.bounds.right + 0.5) * staffSpace, _yOff + staffPosition * staffSpace), black);
      staffPosition++;
    }

    while (staffPosition > staffGaps) {
      _canvas.drawLine(Offset(_xOff + (symbol.bounds.left - 0.5) * staffSpace, _yOff + staffPosition * staffSpace),
          Offset(_xOff + (symbol.bounds.right + 0.5) * staffSpace, _yOff + staffPosition * staffSpace), black);
      staffPosition--;
    }
  }

  void _renderBarlineSingle() {
    //  find first staff
    double firstYOff = -1;
    for (var display in SheetDisplay.values) {
      if (hasDisplay(display)) {
        switch (display) {
          //  has staff
          case SheetDisplay.pianoChords:
          case SheetDisplay.pianoTreble:
          case SheetDisplay.pianoBass:
          case SheetDisplay.bass:
            firstYOff = _sheetYOffsets[display.index];
            break;
          default:
            break;
        }
      }
      if (firstYOff >= 0) {
        break;
      }
    }

    //  find last staff
    double lastYOff = firstYOff;
    for (var display in SheetDisplay.values) {
      if (hasDisplay(display)) {
        switch (display) {
          //  has staff
          case SheetDisplay.pianoChords:
          case SheetDisplay.pianoTreble:
          case SheetDisplay.pianoBass:
          case SheetDisplay.bass:
            lastYOff = _sheetYOffsets[display.index];
            break;
          default:
            break;
        }
      }
    }
    if (firstYOff < 0) {
      return;
    }

    firstYOff += staffMargin * staffSpace;
    lastYOff += (staffMargin + staffLineCount - 1) * staffSpace;

    //  bail if no staffs
    final black = Paint();

    black.color = Colors.black;

    black.style = PaintingStyle.stroke;

    final width = (GlyphBBoxesBarlineSingle.bBoxNE.x - GlyphBBoxesBarlineSingle.bBoxSW.x) * staffSpace;

    black.strokeWidth = width;

    _xAlign();

    _canvas.drawLine(Offset(_xOff, firstYOff), Offset(_xOff, lastYOff), black);

    _xSpaceAll(width);
  }

  void _renderSheetFixedY(SheetNote rest) {
    var rect = _renderSheetNoteSymbol(rest.symbol, rest.symbol.fixedYOff, isStave: false);
    _endDisplay();

    if (_debug) {
      _canvas.drawRect(rect, _transGrey);
    }
    _sheetNoteLocations.add(SheetNoteLocation(rest, rect));
  }

// Accidental _accidentalFromPitch(Pitch pitch) {
//   if (pitch.isSharp) {
//     return Accidental.sharp;
//   }
//   if (pitch.isFlat) {
//     return Accidental.flat;
//   }
//   return Accidental.natural;
// }

  ///
  void _renderSheetNote(
    SheetNote sn, {
    bool renderForward = true,
    double scale = 1.0,
  }) {
    if (sn.pitch == null) {
      throw 'pitch not found: ${sn.pitch}';
    }
    Pitch? pitch = _key?.mappedPitch(sn.pitch!);
    if (pitch == null) {
      throw 'pitch not found: $sn';
    }
    double staffPosition = musical_key.Key.getStaffPosition(_clef, pitch);

    logger.v('_measureAccidentals[$staffPosition]: ${_measureAccidentals[staffPosition]}');
    logger.v('_key.getMajorScaleByNote(${pitch.scaleNumber}): ${_key?.getMajorScaleByNote(pitch.scaleNumber)}');

    //  find if this staff position has had an accidental in this measure
    Accidental? accidental = _measureAccidentals[staffPosition]; // prior notes in the measure
    if (accidental != null) {
      //  there was a prior note at this staff position
      accidental = (pitch.accidental == accidental)
          ? null //               do/show nothing if it's the same as a prior note
          : pitch.accidental; //  insist on the pitch's accidental being shown
    } else {
      //  give the key an opportunity to call for an accidental if the pitch doesn't match the key's scale
      accidental = _key?.accidental(pitch); //  this will be null on a pitch match to the key scale
    }

    logger.v('sn.pitch: ${sn.pitch.toString().padLeft(3)}, pitch: ${pitch.toString().padLeft(3)}'
        ', key: $_key'
        ', accidental: $accidental');
    Rect? accidentalRect;
    if (accidental != null) {
      switch (accidental) {
        case Accidental.sharp:
          accidentalRect = _renderSheetNoteSymbol(accidentalSharp, staffPosition, scale: scale);
          _xSpace(_accidentalStaffSpace * staffSpace);
          break;
        case Accidental.flat:
          accidentalRect = _renderSheetNoteSymbol(accidentalFlat, staffPosition, scale: scale);
          _xSpace(_accidentalStaffSpace * staffSpace);
          break;
        case Accidental.natural:
          accidentalRect = _renderSheetNoteSymbol(accidentalNatural, staffPosition, scale: scale);
          _xSpace(_accidentalStaffSpace * staffSpace);
          break;
      }

      //  remember the prior accidental for this staff position for this measure
      _measureAccidentals[staffPosition] = accidental;
    }

    logger.d('_measureAccidentals[  $staffPosition  ] = ${_measureAccidentals[staffPosition]} ');

    var rect = _renderSheetNoteSymbol(sn.symbol, staffPosition, renderForward: renderForward);
    if (accidentalRect != null) {
      rect = rect.expandToInclude(accidentalRect);
    }

    if (_debug) {
      _canvas.drawRect(rect, _transGrey);
    }

    if (renderForward) {
      _sheetNoteLocations.add(SheetNoteLocation(sn, rect));
    }
  }

  void _startDisplay(SheetDisplay display) {
    if (display == _display) {
      return;
    }

    //  remember the other stuff
    _endDisplay();

    //  select the current
    _display = display;
    _xOff = _xOffDisplay;
    _yOff = _getYOffDisplay(display);
  }

  void _endDisplay() {
    _setXOffDisplay(_display, _xOff);
  }

  void _renderText(String text, {Color? color, double? xOff, double? yOff}) {
    final double w = 2 * staffSpace * text.length;
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Bravura',
          color: color ?? _black.color,
          fontSize: _fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout(
        minWidth: 10,
        maxWidth: max(w, 40),
      )
      ..paint(_canvas, Offset(xOff ?? _xOff, yOff ?? _yOff));
  }

  void _renderSheetFixedYSymbol(SheetDisplay display, SheetNoteSymbol symbol) {
    _startDisplay(display);
    _renderSheetNoteSymbol(symbol, symbol.fixedYOff + staffMargin, isStave: false);
    _endDisplay();
  }

  Rect _renderSheetNoteSymbol(
    SheetNoteSymbol symbol,
    double staffPosition, {
    bool isStave = true,
    bool renderForward = true,
    double scale = 1.0,
  }) {
    final double scaledStaffSpace = staffSpace * scale;
    final double w = symbol.fontSizeStaffs * scaledStaffSpace;

    logger.w( '${symbol.name} w: $w');

    Rect ret = Rect.fromLTRB(
        _xOff + symbol.bounds.left * scaledStaffSpace,
        _yOff + (-symbol.bounds.top + staffPosition) * scaledStaffSpace,
        _xOff + symbol.bounds.right * scaledStaffSpace * scale,
        _yOff + (-symbol.bounds.bottom + staffPosition) * scaledStaffSpace);

    // if (_debug) {
    //   _canvas.drawRect(
    //       ret,
    //       _grey);
    // }

    Offset offset = Offset(_xOff + symbol.bounds.left, _yOff + -2 * w + (staffPosition - 0.05) * staffSpace);
    TextPainter(
      text: TextSpan(
        text: symbol.character,
        style: TextStyle(
          fontFamily: 'Bravura',
          color: _black.color,
          fontSize: w,
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout(
        minWidth: 0,
        maxWidth: w,
      )
      ..paint(_canvas, offset);

    if (isStave) {
      renderStaves(symbol, staffPosition);
    }

    if (renderForward) {
      _xSpace(symbol.bounds.width * staffSpace);
    }
    return ret;
  }

//
  void _reset() {
    _clef = Clef.treble;
    _xOff = 0;
    _yOff = 0;
    for (var display in SheetDisplay.values) {
      _sheetXOffsets[display.index] = 0;
    }
  }

  /// align all clefs and add a space
  void _xSpaceAll(double space) {
    _endDisplay();
    double maxX = 0;
    for (var display in SheetDisplay.values) {
      maxX = max(maxX, _sheetXOffsets[display.index]);
    }
    _xOff += space;
    for (var display in SheetDisplay.values) {
      _sheetXOffsets[display.index] = _xOff;
    }
  }

  ///  add spacing to the current clef
  void _xSpace(double space) {
    _xOff += space;
  }

  /// align all clefs to the current maximum of the clefs
  void _xAlign() {
    _xSpaceAll(0);
  }

  /// only test chords
  void _testChords() {
    const int beats = 1;
    const int beatsPerBar = 4;

    _key = musical_key.Key.get(musical_key.KeyEnum.C);

    _xAlign();

    // _renderKeyStaffSymbols(Clef.treble); fixme
    // _renderKeyStaffSymbols(Clef.bass);
    _xSpaceAll(1 * staffSpace);

    //  fill in the time signature
    _xAlign();
    _startDisplay(SheetDisplay.pianoChords);
    _renderSheetNoteSymbol(
        timeSigCommon, 2); //  fixme: fill in the time signature with something other than common time
    _endDisplay();
    _xAlign();

    List<ScaleNoteEnum> scaleNoteEnums = [
      ScaleNoteEnum.D,
      ScaleNoteEnum.C,
      ScaleNoteEnum.G,
      ScaleNoteEnum.G,
    ];

    for (var display in SheetDisplay.values) {
      if (!hasDisplay(display)) {
        continue;
      }
      _startDisplay(display);
      switch (display) {
        case SheetDisplay.chords:
          double duration = 0;
          _clearMeasureAccidentals();
          _xSpace(1.25 * staffSpace);
          for (var scaleNoteEnum in scaleNoteEnums) {
            ScaleChord scaleChord = ScaleChord(ScaleNote.get(scaleNoteEnum), ChordDescriptor.major);
            Chord chord = Chord(scaleChord, beats, beatsPerBar, null, ChordAnticipationOrDelay.defaultValue, false);

            //  chord declaration over treble staff

            List<Pitch> pitches = chord.pianoChordPitches();
            logger.d('${chord.scaleChord}: $pitches');
            for (var pitch in pitches) {
              logger.d('    pitch: $pitch');
              SheetNote sheetNote = SheetNote.note(
                pitch,
                beats / beatsPerBar,
              );
              // _startDisplay(sheetNote.clef);// fixme?????
              if (!identical(pitch, pitches.last)) {
                _renderSheetNote(sheetNote, renderForward: false, scale: 0.75);
              } else {
                _renderSheetNote(sheetNote, renderForward: true);
                duration += sheetNote.noteDuration ?? 0;
              }

              if (duration >= 1) {
                _xSpace(1.25 * staffSpace);
                _renderBarlineSingle();
                duration = 0;
                _xSpace(1.25 * staffSpace);
                _clearMeasureAccidentals();
              }
            }

            _xSpace(1.25 * staffSpace);
          }
          break;
        default:
          break;
      }
      _endDisplay();
    }
  }

  /// only a test song
  void _testSong() {
    //  sample song.... temp!
    String songAsJsonString = """
{"warning":"File generated by Robert Steele's Bass Study Tool.  Any modifications by hand are likely to be wrong.","version":"0.0","keyN":0,"beatsPerBar":4,"notesPerBar":4,"bpm":80,"isSwing8":false,"hiHatRhythm":"X   x x   x X   x x   x","swingType":3,"sheetNotes":[
{"isNote":true,"string":0,"fret":5,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"verse","tied":false},
{"isNote":true,"string":0,"fret":7,"noteDuration":4,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-2,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":7,"noteDuration":4,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-2,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":4,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":3,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":5,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":false,"noteDuration":1},
{"isNote":true,"string":1,"fret":5,"noteDuration":3,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":7,"noteDuration":4,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-2,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":7,"noteDuration":4,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-2,"lyrics":"","tied":false},
{"isNote":true,"string":2,"fret":4,"noteDuration":3,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":3,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":5,"noteDuration":3,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":false,"noteDuration":1},
{"isNote":true,"string":0,"fret":5,"noteDuration":2,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"chorus","tied":false},
{"isNote":true,"string":1,"fret":4,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":3,"lyrics":"","tied":false},
{"isNote":false,"noteDuration":4},
{"isNote":true,"string":1,"fret":4,"noteDuration":4,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":3,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":5,"noteDuration":2,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-4,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":4,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":3,"lyrics":"","tied":false},
{"isNote":false,"noteDuration":4},
{"isNote":true,"string":1,"fret":4,"noteDuration":4,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-7,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":5,"noteDuration":3,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-4,"lyrics":"","tied":false},
{"isNote":true,"string":2,"fret":4,"noteDuration":3,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":3,"lyrics":"","tied":false},
{"isNote":true,"string":2,"fret":7,"noteDuration":3,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":5,"lyrics":"","tied":false},
{"isNote":false,"noteDuration":4},
{"isNote":true,"string":1,"fret":5,"noteDuration":4,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":7,"noteDuration":3,"chordN":0,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":2,"fret":6,"noteDuration":3,"chordN":0,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":3,"lyrics":"","tied":false},
{"isNote":true,"string":3,"fret":4,"noteDuration":3,"chordN":0,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":5,"lyrics":"","tied":false},
{"isNote":false,"noteDuration":3},
{"isNote":true,"string":1,"fret":0,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":1,"noteDuration":3,"chordN":6,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":2,"noteDuration":3,"chordN":7,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":3,"noteDuration":3,"chordN":8,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":4,"noteDuration":3,"chordN":9,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":5,"noteDuration":3,"chordN":10,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":6,"noteDuration":3,"chordN":11,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":7,"noteDuration":3,"chordN":12,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":0,"noteDuration":3,"chordN":0,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":1,"noteDuration":3,"chordN":1,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":2,"noteDuration":3,"chordN":1,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":3,"noteDuration":3,"chordN":1,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-2,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":4,"noteDuration":3,"chordN":4,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":5,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":6,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":0,"fret":7,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-2,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":3,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":4,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":3,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":5,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-4,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":6,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":1,"fret":7,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":5,"lyrics":"","tied":false},
{"isNote":true,"string":2,"fret":3,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":2,"fret":4,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-6,"lyrics":"","tied":false},
{"isNote":true,"string":3,"fret":0,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":2,"fret":6,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-7,"lyrics":"","tied":false},
{"isNote":true,"string":2,"fret":7,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":1,"lyrics":"","tied":false},
{"isNote":true,"string":3,"fret":3,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":3,"fret":4,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-2,"lyrics":"","tied":false},
{"isNote":true,"string":3,"fret":5,"noteDuration":3,"chordN":5,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":3,"fret":6,"noteDuration":3,"chordN":8,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":0,"lyrics":"","tied":false},
{"isNote":true,"string":3,"fret":7,"noteDuration":3,"chordN":8,"chordModifier":"","minorMajor":"major","minorMajorSelectIndex":0,"scaleN":-2,"lyrics":"","tied":false},
{"isNote":false,"noteDuration":3}]}
    """;
    logger.d('debugging:');
    List<SheetNote>? sheetNotes = BassStudyTool.parseJsonBsstVersion0_0(songAsJsonString);
    if (sheetNotes == null) {
      throw 'missing sheetNotes';
    }

    //temp!!!!!!!!!!!!
    sheetDisplayEnables[SheetDisplay.pianoTreble.index] = true;
    sheetDisplayEnables[SheetDisplay.pianoBass.index] = true;

    _key = musical_key.Key.get(musical_key.KeyEnum.A);

    //  fixme: fill in the key accidentals
    //  hand rendering
    _xAlign();
    _renderKeyStaffSymbols(SheetDisplay.pianoTreble);
    _renderKeyStaffSymbols(SheetDisplay.pianoBass);
    _xSpaceAll(1 * staffSpace);

    //  fill in the time signature
    _xAlign();
    _startDisplay(SheetDisplay.pianoTreble);
    _renderSheetNoteSymbol(
        timeSigCommon, 2); //  fixme: fill in the time signature with something other than common time
    _endDisplay();
    _xAlign();

    double duration = 0;
    _clearMeasureAccidentals();
    for (SheetNote sn in sheetNotes) {
      _startDisplay(sn.clef == Clef.treble ? SheetDisplay.pianoTreble : SheetDisplay.pianoBass);
      if (sn.isNote) {
        //  fixme: pitch to trebleClef location
        //  fixme: dotted
        //  fixme: tied
        //  fixme: beamed
        //  fixme: align treble and bass measures
        //  fixme: even measure widths
        //  fixme: align notes with their durations
        //  fixme: control line overflow
        //  fixme: staff selection (e.g. bass only, treble + bass, etc)
        _renderSheetNote(sn);
      } else {
        _renderSheetFixedY(sn);
      }

      _xSpace(1.25 * staffSpace);

      duration += sn.noteDuration ?? 0;
      if (duration >= 1) {
        _renderBarlineSingle();
        duration = 0;
        _xSpace(2 * staffSpace);
        _clearMeasureAccidentals();
      }
    }
  }

  void _clearMeasureAccidentals() {
    _measureAccidentals.clear();
  }

  double get _xOffDisplay => _getXOffDisplay(_display);

  double get _yOffDisplay => _getYOffDisplay(_display);

  double _getXOffDisplay(SheetDisplay display) {
    return _sheetXOffsets[display.index];
  }

  double _getYOffDisplay(SheetDisplay display) {
    return _sheetYOffsets[display.index];
  }

  void _setXOffDisplay(SheetDisplay display, double value) {
    _sheetXOffsets[display.index] = value;
  }

// void _setYOffDisplay(SheetDisplay display, double value) {
//   _sheetYOffsets[display.index] = value;
// }

  List<SheetNoteLocation> get sheetNoteLocations => _sheetNoteLocations;
  final List<SheetNoteLocation> _sheetNoteLocations = [];
  final Map<double, Accidental> _measureAccidentals = {}; // cache for a single measure
  late Canvas _canvas;
  static const double _staffLineThickness = EngravingDefaults.staffLineThickness / 2; //  style basis only
  static const double _accidentalStaffSpace = 0.25;
  musical_key.Key? _key = musical_key.Key.get(musical_key.KeyEnum.C);
  Clef _clef = Clef.treble; //  current clef
  SheetDisplay _display = SheetDisplay.values.first; //  current display
  double _xOff = 0;
  double _yOff = 0;
}

class SheetNoteLocation {
  SheetNoteLocation(this.sheetNote, this.location);

  SheetNote sheetNote;
  Rect location;
}

final _white = Paint()..color = Colors.white;
//final _grey = Paint()..color = Colors.grey;
final _transGrey = Paint()..color = Colors.grey.withAlpha(80);
final _black = Paint()..color = Colors.black;
//final _blackFill = Paint()
//  ..color = Colors.black
//  ..style = PaintingStyle.fill;
