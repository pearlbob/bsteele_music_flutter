import 'dart:math';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicFontParameters.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNotation.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:flutter/material.dart';

const double staffLineCount = 5;
const double staffSpace = 16;
const double staffLineThickness = EngravingDefaults.staffLineThickness / 2; //  style basis only

// For piano chords, try:  https://www.scales-chords.com/chord/piano

class SheetNotationList {
  static List<SheetNotation> get sheetNotations {
    _sheetNotations ??= List.generate(SheetDisplay.values.length, (index) {
      const staffHeight = (staffLineCount - 1) * staffSpace;
      const staffMarginHeight = staffMargin * staffSpace;
      SheetDisplay display = SheetDisplay.values[index];

      const double fontSize = 15; //  fixme
      switch (display) {
        case SheetDisplay.section:
          return SheetSectionTextNotation(
            display,
          );
        case SheetDisplay.measureCount:
          return SheetMeasureCountTextNotation(
            display,
            activeHeight: fontSize,
          );
        case SheetDisplay.chords:
          return SheetChordTextNotation(display);
        case SheetDisplay.lyrics:
          return SheetLyricsTextNotation(display);
        case SheetDisplay.guitarFingerings:
          return SheetTextNotation(display, activeHeight: fontSize * 4); // fixme temp
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
          return SheetBassNoteNumbersTextNotation(display, activeHeight: fontSize * 2);
        case SheetDisplay.bassNotes:
          return SheetBassNotesTextNotation(display, activeHeight: fontSize * 2);
        case SheetDisplay.bass8vb:
          return SheetBass8vbStaffNotation(display,
              preHeight: staffMarginHeight, activeHeight: staffHeight, postHeight: staffMarginHeight);
      }
    }, growable: false);

    return _sheetNotations!;
  }

  static List<SheetNoteLocation> get sheetNoteLocations {
    List<SheetNoteLocation> ret = [];
    if (hasDisplay(SheetDisplay.bass8vb)) {
      List<SheetNoteLocation> sheetNoteLocations = sheetNotations[SheetDisplay.bass8vb.index].sheetNoteLocations;
      if (sheetNoteLocations.isNotEmpty) {
        ret.addAll(sheetNoteLocations);
      }
    }
    return ret;
  }

  static List<SheetNotation>? _sheetNotations;
}

class SheetMusicPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _canvas = canvas;

    _sheetNotations = SheetNotationList.sheetNotations;

    _computeTheYOffsets();

    //  clear the plot
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = app.themeData.colorScheme.surface);

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
    Song song = app.selectedSong;
    momentLoop:
    for (var sm in song.songMoments) {
      if (app.selectedMomentNumber > sm.momentNumber) {
        continue; //  fixme: optimization?
      }
      const beatResolution = 1 / 16; //  fixme: is this the best way to do this?
      for (double beat = 0; beat < sm.measure.beatCount; beat += beatResolution) {
        for (var display in SheetDisplay.values) {
          if (hasDisplay(display)) {
            _sheetNotations[display.index].drawBeat(sm, beat);
          }
        }

        //  align all displays
        if (_xAlign() >= size.width) {
          //  don't bother if we're past the end of the window
          logger.d('last moment: ${sm.momentNumber}');
          break momentLoop;
        }
      }
      _renderBarlineSingle();
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    logger.t('shouldRepaint( ${oldDelegate.runtimeType} )');
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

  void _reset() {
    for (var display in SheetDisplay.values) {
      _sheetNotations[display.index].reset();
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
  double _xAlign() {
    return _xSpaceAll(0);
  }

  // cache for a single measure
  late Canvas _canvas;

  List<SheetNotation> _sheetNotations = [];
}
