import 'dart:math';
import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicFontParameters.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNotation.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:flutter/material.dart';

const double staffLineCount = 5;
const double staffSpace = 16;
const double staffLineThickness = EngravingDefaults.staffLineThickness / 2; //  style basis only

// For piano chords, try:  https://www.scales-chords.com/chord/piano


class SheetMusicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _canvas = canvas;

    _sheetNotations = List.generate(SheetDisplay.values.length, (index) {
      const staffHeight = (staffLineCount - 1) * staffSpace;
      const staffMarginHeight = staffMargin * staffSpace;
      SheetDisplay display = SheetDisplay.values[index];

      const double _fontSize = 15; //  fixme
      switch (display) {
        case SheetDisplay.section:
          return SheetSectionTextNotation(display, );
        case SheetDisplay.measureCount:
          return SheetMeasureCountTextNotation(display, activeHeight: _fontSize,);
        case SheetDisplay.chords:
          return SheetChordTextNotation(display);
        case SheetDisplay.lyrics:
          return SheetLyricsTextNotation(display);
        case SheetDisplay.guitarFingerings:
          return SheetTextNotation(display, activeHeight: _fontSize * 4); // fixme temp
        case SheetDisplay.pianoChords:
          return SheetChordStaffNotation(display,
              preHeight: staffMarginHeight, activeHeight: staffHeight, postHeight: staffMarginHeight);
        case SheetDisplay.pianoTreble:
          return SheetTrebleStaffNotation(display,
              preHeight: staffMarginHeight, activeHeight: staffHeight, postHeight: staffMarginHeight);
        case SheetDisplay.pianoBass: //  piano left hand
          return SheetBassStaffNotation(display,
              preHeight: staffMarginHeight, activeHeight: staffHeight, postHeight: staffMarginHeight);
        case SheetDisplay.bassNoteNumbers:
          return SheetTextNotation(display, activeHeight: _fontSize * 2);
        case SheetDisplay.bassNotes:
          return SheetTextNotation(display, activeHeight: _fontSize * 2);
        case SheetDisplay.bass8vb:
          return SheetBass8vbStaffNotation(display,
              preHeight: staffMarginHeight, activeHeight: staffHeight, postHeight: staffMarginHeight);
      }
    }, growable: false);

    _computeTheYOffsets();

    //  clear the plot
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _white);

    _reset();
    _xSpaceAll(10);

    //  fixme: brace from piano treble to bass
    // if (hasDisplay(SheetDisplay.pianoTreble) && hasDisplay(SheetDisplay.pianoBass)) {
    //   _renderSheetFixedYSymbol(SheetDisplay.pianoTreble, brace);
    //   _xSpaceAll(1.5 * staffSpace);
    // }

    _renderBarlineSingle();

    //  notations
    for (var display in SheetDisplay.values) {
      if (hasDisplay(display)) {
        _sheetNotations[display.index].render(canvas, size);
      }
    }

    _xSpaceAll(0.5 * staffSpace);

    //  display each beat
    Song song = _app.selectedSong;
    momentLoop:
    for ( var sm in song.songMoments ){
      if ( _app.selectedMomentNumber > sm.momentNumber){
        continue; //  fixme: optimization?
      }
      for ( int beat = 0; beat < sm.measure.beatCount; beat++){
        for (var display in SheetDisplay.values) {
          if (hasDisplay(display)) {
            _sheetNotations[display.index].drawBeat(sm, beat);
          }
        }

        if ( _xSpaceAll(0.5 * staffSpace) >= size.width ){
          logger.d('last moment: ${sm.momentNumber}');
          break momentLoop;
        }
      }
      _renderBarlineSingle();
    }

    // _testSong();
    // if (hasDisplay(SheetDisplay.pianoChords)) {
    //   _testChords();
    // }
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
    logger.v('shouldRepaint( ${oldDelegate.runtimeType} )');
    return true;
  }

  void _computeTheYOffsets() {
    {
      double y = 0;
      var lastDisplay = SheetDisplay.values.last; //  won't match the first time
      for (var display in SheetDisplay.values) {
        var sn = _sheetNotations[display.index];
        sn.dy = y;
        if (hasDisplay(display)) {
          y += sn.totalHeight;

          switch (display) {
            case SheetDisplay.pianoBass:
              switch (lastDisplay) {
                case SheetDisplay.pianoTreble:
                  y += staffVerticalGaps * staffSpace;
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
          case SheetDisplay.bass8vb:
            firstYOff = _sheetNotations[display.index].dy;
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
          case SheetDisplay.bass8vb:
            lastYOff = _sheetNotations[display.index].dy;
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
    black.color = Colors.black54;
    black.style = PaintingStyle.stroke;
    final width = (GlyphBBoxesBarlineSingle.bBoxNE.x - GlyphBBoxesBarlineSingle.bBoxSW.x) * staffSpace;
    black.strokeWidth = width;

    _xAlign();

    {
      var x = _sheetNotations.first.dx;
      _canvas.drawLine(Offset(x, firstYOff), Offset(x, lastYOff), black);
    }

    _xSpaceAll(width);
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

  void _reset() {
    for (var display in SheetDisplay.values) {
      var sn = _sheetNotations[display.index];
      sn.dx = 0;
    }
  }

  /// align all clefs and add a space
  double _xSpaceAll(double space) {
    double maxX = 0;
    for (var display in SheetDisplay.values) {
      maxX = max(maxX, _sheetNotations[display.index].dx);
    }
    var x = maxX + space;
    for (var display in SheetDisplay.values) {
      var sn = _sheetNotations[display.index];
      sn.dx = x;
    }
    return maxX;
  }

  /// align all clefs to the current maximum of the clefs
  void _xAlign() {
    _xSpaceAll(0);
  }

  // cache for a single measure
  late Canvas _canvas;

  late List<SheetNotation> _sheetNotations;

  final  App _app = App();
}

class SheetNoteLocation {
  SheetNoteLocation(this.sheetNote, this.location);

  SheetNote sheetNote;
  Rect location;
}

final _white = Paint()..color = Colors.white;
//final _grey = Paint()..color = Colors.grey;

//final _blackFill = Paint()
//  ..color = Colors.black
//  ..style = PaintingStyle.fill;
