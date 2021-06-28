import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chord.dart';
import 'package:bsteeleMusicLib/songs/chordAnticipationOrDelay.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as musical_key;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/pitch.dart';
import 'package:bsteeleMusicLib/songs/scaleChord.dart';
import 'package:bsteeleMusicLib/songs/scaleNote.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicFontParameters.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicPainter.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:bsteele_music_flutter/util/appTextStyle.dart';
import 'package:flutter/material.dart';

import 'bassStudyTool.dart';

const bool _debug = false; // kDebugMode false
const double _chordFontSize = 24;

abstract class SheetNotation {
  SheetNotation._(this.sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : preHeight = preHeight ?? 0,
        activeHeight = activeHeight ?? 0,
        postHeight = postHeight ?? 0 {
    totalHeight = this.preHeight + this.activeHeight + this.postHeight;
    assert(this.preHeight >= 0);
    assert(this.activeHeight > 0);
    assert(this.postHeight >= 0);
    dy = 0 + this.preHeight;
  }

  void render(Canvas canvas, Size size) {
    _canvas = canvas;
    _size = size;

    _renderText(Util.enumToString(sheetDisplay), xOff: 45);
    if (_debug) {
      {
        canvas.drawRect(Rect.fromLTWH(sheetDisplay.index * 30, dy, 10, totalHeight), _transGrey);
        canvas.drawRect(Rect.fromLTWH(sheetDisplay.index * 30 - 5, dy, 10, preHeight), _transBlue);
        canvas.drawRect(
            Rect.fromLTWH(sheetDisplay.index * 30 + 5, dy + preHeight + activeHeight, 10, postHeight), _transBlue);
      }
    }

    drawNotations();
  }

  void drawNotations() {}

  /// render text and return the pixels used
  double _renderText(String text, {Color? color, double? xOff, double? yOff, double? fontSize, FontWeight? fontWeight}) {
    //   final double w = 2 * staffSpace * text.length;
    var textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Bravura',
          color: color ?? _black.color,
          fontSize: fontSize ?? _fontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(
        // minWidth: 10,
        // maxWidth: max(w, 40),
        );
    textPainter.paint(_canvas, Offset(xOff ?? dx, yOff ?? dy));

    return textPainter.minIntrinsicWidth;
  }

  _renderBarlineSingle() {
    //  fixme
    final black = Paint();
    black.color = _lineColor;
    black.style = PaintingStyle.stroke;
    final width = (GlyphBBoxesBarlineSingle.bBoxNE.x - GlyphBBoxesBarlineSingle.bBoxSW.x) * staffSpace;
    black.strokeWidth = width;

    _canvas.drawLine(Offset(dx, dy + preHeight),
        Offset(dx, dy + preHeight + min(activeHeight, (staffLineCount - 1) * staffSpace)), black);
  }

  @override
  String toString() {
    return 'SheetNotation{$sheetDisplay'
        ', offset: ($dx, $dy), heights: $preHeight + $activeHeight + $postHeight = $totalHeight }';
  }

  double dx = 0;
  double dy = 0; //  nominal vertical position
  final double preHeight;
  final double activeHeight;
  final double postHeight;
  late final double totalHeight;

  musical_key.Key _key = musical_key.Key.get(musical_key.KeyEnum.C);

  final SheetDisplay sheetDisplay;

  late Canvas _canvas;
  late Size _size;

  static const double _fontSize = 15; //  fixme
}

class SheetTextNotation extends SheetNotation {
  SheetTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super._(sheetDisplay, preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight);

  @override
  void drawNotations() {
    dx += 200;
    _renderText('some text here:');
  }
}

class SheetChordTextNotation extends SheetTextNotation {
  SheetChordTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight ?? 2 * _chordFontSize, postHeight: postHeight);

  @override
  void drawNotations() {
    dx += 200;
    int beats = 0;
    for (var chord in _getChords()) {
      dx += _renderText(chord.scaleChord.toMarkup(), fontSize: _chordFontSize, fontWeight: FontWeight.bold);
      dx += staffSpace;
      beats += chord.beats;
      if (beats >= chord.beatsPerBar) {
        _renderBarlineSingle();
        dx += staffSpace;
        beats = 0;
      }
    }
  }
}

class SheetLyricsTextNotation extends SheetTextNotation {
  SheetLyricsTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight ?? 1.5 * _chordFontSize, postHeight: postHeight);

  @override
  void drawNotations() {
    dx += 200;
    int beats = 0;
    for (var chord in _getChords()) {
      dx += _renderText('foo', fontSize: _chordFontSize);
      dx += staffSpace;
      beats += chord.beats;
      if (beats >= chord.beatsPerBar) {
        _renderBarlineSingle();
        dx += staffSpace;
        beats = 0;
      }
    }
  }
}

class _SheetStaffNotation extends SheetNotation {
  _SheetStaffNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, Clef? clef})
      : super._(sheetDisplay, preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight) {
    _clef = clef ?? Clef.treble;
    _clefSymbol = _clefSheetNoteSymbol(_clef);
  }

  @override
  void drawNotations() {
    _sheetNoteLocations.clear();
    _renderStaff();
    dx += 10; //fixme
    _renderSheetFixedYSymbol(_clefSymbol);
  }

  void _renderStaff() {
    final black = Paint();
    black.color = _lineColor;
    black.style = PaintingStyle.stroke;
    black.strokeWidth = staffLineThickness * staffSpace;

    var y = dy + preHeight;
    for (int line = 0; line < 5; line++) {
      _canvas.drawLine(
          Offset(dx, y + line * staffSpace), Offset(_size.width - dx /*-margin?*/, y + line * staffSpace), black);
    }
  }

  SheetNoteSymbolFixed _clefSheetNoteSymbol(Clef clef) {
    switch (clef) {
      case Clef.treble:
        return trebleClef;
      case Clef.bass:
        return bassClef;
      case Clef.bass8vb:
        return bass8vbClef;
    }
  }

  SheetNoteSymbol _accidentalSheetNoteSymbol(Accidental accidental) {
    switch (accidental) {
      case Accidental.sharp:
        return accidentalSharp;
      case Accidental.flat:
        return accidentalFlat;
      case Accidental.natural:
        return accidentalNatural;
    }
  }

  ///
  void _renderSheetNote(
    SheetNote sn, {
    bool renderForward = true,
    double scale = 1.0,
  }) {
    if (sn.pitch == null) {
      throw 'pitch not found: ${sn.pitch}';
    }
    //  accidental
    Pitch? pitch = _key.mappedPitch(sn.pitch!);
    double staffPosition = musical_key.Key.getStaffPosition(_clef, pitch);

    logger.v('_measureAccidentals[$staffPosition]: ${_measureAccidentals[staffPosition]}');
    logger.v('_key.getMajorScaleByNote(${pitch.scaleNumber}): ${_key.getMajorScaleByNote(pitch.scaleNumber)}');

    //  find if this staff position has had an accidental in this measure
    Accidental? accidental = _measureAccidentals[staffPosition]; // prior notes in the measure
    if (accidental != null) {
      //  there was a prior note at this staff position
      accidental = (pitch.accidental == accidental)
          ? null //               do/show nothing if it's the same as a prior note
          : pitch.accidental; //  insist on the pitch's accidental being shown
    } else {
      //  give the key an opportunity to call for an accidental if the pitch doesn't match the key's scale
      accidental = _key.accidental(pitch); //  this will be null on a pitch match to the key scale
    }

    logger.v('sn.pitch: ${sn.pitch.toString().padLeft(3)}, pitch: ${pitch.toString().padLeft(3)}'
        ', key: $_key'
        ', accidental: $accidental');
    Rect? accidentalRect;
    if (accidental != null) {
      accidentalRect = _renderSheetNoteSymbol(_accidentalSheetNoteSymbol(accidental), staffPosition,
          scale: scale, renderForward: false);
      _xSpace((1 + _accidentalStaffSpace) * staffSpace * scale);
      if (_debug) {
        _canvas.drawRect(accidentalRect, _transGrey);
      }

      //  remember the prior accidental for this staff position for this measure
      _measureAccidentals[staffPosition] = accidental;
    }

    logger.d('_measureAccidentals[  $staffPosition  ] = ${_measureAccidentals[staffPosition]} ');

    var rect = _renderSheetNoteSymbol(sn.symbol, staffPosition, renderForward: renderForward, scale: scale);
    if (accidentalRect != null) {
      rect = rect.expandToInclude(accidentalRect);
    }

    _sheetNoteLocations.add(SheetNoteLocation(sn, rect));
  }

  void _renderSheetFixedYSymbol(SheetNoteSymbolFixed symbol) {
    _renderSheetNoteSymbol(symbol, symbol.staffPosition, isStave: false);
  }

  Rect _renderSheetNoteSymbol(
    SheetNoteSymbol symbol,
    double staffPosition, {
    bool isStave = true,
    bool renderForward = true,
    double scale = 1.0,
  }) {
    final double scaledStaffSpace = staffSpace * scale;
    final double w = symbol.fontSizeOnStaffs * scaledStaffSpace;

    var y = dy + preHeight;
    var yOff = symbol.fixedYOff * scaledStaffSpace;
    var yPos = activeHeight - staffPosition * scaledStaffSpace;
    Rect ret = Rect.fromLTRB(
        dx + symbol.bounds.left * scaledStaffSpace,
        y + yOff - yPos + symbol.bounds.top * scaledStaffSpace,
        dx + symbol.bounds.right * scaledStaffSpace,
        y + yOff - yPos + symbol.bounds.bottom * scaledStaffSpace);

    logger.i('${symbol.name} $staffPosition = $yPos'
        ', ${symbol.bounds.top} to ${symbol.bounds.bottom}, fixedYOff: ${symbol.fixedYOff}');

    Offset offset = Offset(ret.left, y - yOff - yPos);
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
      _renderStaves(symbol, staffPosition);
    }

    if (renderForward) {
      _xSpace(symbol.bounds.width * staffSpace);
    }

    if (_debug) {
      _canvas.drawRect(ret, _transGrey);
      _canvas.drawRect(Rect.fromLTRB(ret.left, y + yOff - yPos - 1, ret.right, y + yOff - yPos + 1), _red);
    }
    return ret;
  }

  void _renderSheetFixedY(SheetNote rest) {
    var rect = _renderSheetNoteSymbol(rest.symbol, rest.symbol.fixedYOff, isStave: false);

    if (_debug) {
      _canvas.drawRect(rect, _transGrey);
    }
    _sheetNoteLocations.add(SheetNoteLocation(rest, rect));
  }

  void _renderStaves(SheetNoteSymbol symbol, double staffPosition) {
    //  truncate to staff line height
    staffPosition = staffPosition.toInt().toDouble();

    if (staffPosition >= 0 && staffPosition <= staffVerticalGaps) {
      return;
    }

    final black = Paint();
    black.color = _lineColor;
    black.style = PaintingStyle.stroke;
    black.strokeWidth = staffLineThickness * staffSpace;
    const staveOverhang = 0.6;
    final y = dy + preHeight;

    while (staffPosition < 0) {
      _canvas.drawLine(Offset(dx + (symbol.bounds.left - staveOverhang) * staffSpace, y + staffPosition * staffSpace),
          Offset(dx + (symbol.bounds.right + staveOverhang) * staffSpace, y + staffPosition * staffSpace), black);
      staffPosition++;
    }

    while (staffPosition > staffVerticalGaps) {
      _canvas.drawLine(Offset(dx + (symbol.bounds.left - staveOverhang) * staffSpace, y + staffPosition * staffSpace),
          Offset(dx + (symbol.bounds.right + staveOverhang) * staffSpace, y + staffPosition * staffSpace), black);
      staffPosition--;
    }
  }

  /// render the key symbols (sharps or flats)
  void _renderKeyStaffSymbols(SheetDisplay display) {
    if (_key == musical_key.Key.getDefault()) {
      return;
    }

    int clefYOff = 0;
    switch (display) {
      case SheetDisplay.pianoBass:
      case SheetDisplay.bass8vb:
        clefYOff = -1; //  fixme
        break;
      default:
        break;
    }

    //  key
    List<double> locations = (_key.isSharp ? keySharpLocations : keyFlatLocations);
    SheetNoteSymbol symbol = (_key.isSharp ? accidentalSharp : accidentalFlat);
    int limit = _key.getKeyValue().abs();
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

  void _xSpace(double space) {
    dx += space;
  }

  void _clearMeasureAccidentals() {
    _measureAccidentals.clear();
  }

  late final Clef _clef;
  late final SheetNoteSymbolFixed _clefSymbol;

  final List<SheetNoteLocation> _sheetNoteLocations = [];
  final Map<double, Accidental> _measureAccidentals = {};

  static const double _accidentalStaffSpace = 0.25;
}

class SheetTrebleStaffNotation extends _SheetStaffNotation {
  SheetTrebleStaffNotation(SheetDisplay sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight, clef: Clef.treble);

  @override
  void drawNotations() {
    super.drawNotations();
    _testSong();
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

    _key = musical_key.Key.get(musical_key.KeyEnum.A);

    //  fixme: fill in the key accidentals
    //  hand rendering
    _renderKeyStaffSymbols(SheetDisplay.pianoTreble);
    _xSpace(1 * staffSpace);

    //  fill in the time signature
    _renderSheetNoteSymbol(timeSigCommon, timeSigCommon.staffPosition,
        isStave: false); //  fixme: fill in the time signature with something other than common time
    _xSpace(1 * staffSpace);

    double duration = 0;
    _clearMeasureAccidentals();
    for (SheetNote sn in sheetNotes) {
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
        //  fixme: multiple accidentals on one chord
        sn = SheetNote.note(
            _clef, sn.pitch?.offsetByHalfSteps(3 * MusicConstants.halfStepsPerOctave) ?? sn.pitch, sn.noteDuration);
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
}

class SheetBassStaffNotation extends _SheetStaffNotation {
  SheetBassStaffNotation(SheetDisplay sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : super(sheetDisplay, preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight, clef: Clef.bass);
}

class SheetChordStaffNotation extends _SheetStaffNotation {
  SheetChordStaffNotation(SheetDisplay sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : super(sheetDisplay, preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight);

  @override
  void drawNotations() {
    super.drawNotations();
    _testChords();
  }

  /// only test chords
  void _testChords() {
    const int beats = 1;
    const int beatsPerBar = 4;

    _key = musical_key.Key.get(musical_key.KeyEnum.C);

    // _renderKeyStaffSymbols(Clef.treble); fixme
    // _renderKeyStaffSymbols(Clef.bass);
    _xSpace(1 * staffSpace);

    //  fill in the time signature
    _renderSheetFixedYSymbol(timeSigCommon); //  fixme: fill in the time signature with something other than common time

    List<Chord> chords = _getChords();
    {
      double duration = 0;
      final Map<double, Accidental> _chordMeasureAccidentals = {};
      _xSpace(1.25 * staffSpace);

      //  chord declaration over treble staff
      for (var chord in chords) {
        List<Pitch> pitches = chord.pianoChordPitches();
        List<bool> chordAccidentals = [];
        logger.i('   new chordAccidentals');
        bool hasAccidentals = false;
        int upCount = 0;
        int downCount = 0;
        for (var pitch in pitches) {
          //  find if this staff position has had an accidental in this measure
          double staffPosition = musical_key.Key.getStaffPosition(_clef, pitch);
          Accidental? accidental = _chordMeasureAccidentals[staffPosition]; // prior notes in the measure
          if (accidental != null) {
            //  there was a prior note at this staff position
            accidental = (pitch.accidental == accidental)
                ? null //               do/show nothing if it's the same as a prior note
                : pitch.accidental; //  insist on the pitch's accidental being shown
          } else {
            //  give the key an opportunity to call for an accidental if the pitch doesn't match the key's scale
            accidental = _key.accidental(pitch); //  this will be null on a pitch match to the key scale
          }
          if (accidental != null) {
            //  remember the prior accidental for this staff position for this measure
            _chordMeasureAccidentals[staffPosition] = accidental;
            hasAccidentals = true;
          }
          chordAccidentals.add((accidental != null));

          //  vote for up/down direction
          if (isUpNote(_clef, pitch)) {
            upCount++;
          } else {
            downCount++;
          }
        }
        bool isUpChord = (upCount > downCount);
        double originalDx = dx;
        double rootDx = dx + (hasAccidentals ? (1 + _SheetStaffNotation._accidentalStaffSpace) * staffSpace : 0);
        logger.i('${chord.scaleChord}: $pitches, acc?: $hasAccidentals');
        int chordPitchIndex = 0;
        for (var pitch in pitches) {
          logger.d('    pitch: $pitch');
          SheetNote sheetNote = SheetNote.note(
            _clef,
            pitch,
            beats / beatsPerBar,
            makeUpNote: isUpChord,
          );
          dx = chordAccidentals[chordPitchIndex] ? originalDx : rootDx;
          if (!identical(pitch, pitches.last)) {
            _renderSheetNote(
              sheetNote,
              renderForward: false,
            );
          } else {
            _renderSheetNote(sheetNote, renderForward: true);
            duration += sheetNote.noteDuration ?? 0;
          }

          if (duration >= 1) {
            _xSpace(1.25 * staffSpace);
            _renderBarlineSingle();
            duration = 0;
            _xSpace(1.25 * staffSpace);
            //  start afresh on new measure
            _chordMeasureAccidentals.clear();
            _measureAccidentals.clear();
            logger.i('measure cleared');
          }

          chordPitchIndex++;
        }

        _xSpace(1.25 * staffSpace);
      }
    }
  }
}

class SheetBass8vbStaffNotation extends _SheetStaffNotation {
  SheetBass8vbStaffNotation(SheetDisplay sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight, clef: Clef.bass8vb);

  @override
  void drawNotations() {
    super.drawNotations();
    _testBassNotes();
  }

  /// only test chords
  void _testBassNotes() {
    const int beats = 1;
    const int beatsPerBar = 4;

    _key = musical_key.Key.get(musical_key.KeyEnum.C);

    // _renderKeyStaffSymbols(Clef.treble); fixme
    // _renderKeyStaffSymbols(Clef.bass);
    _xSpace(1 * staffSpace);

    {
      double duration = 0;
      _clearMeasureAccidentals();
      _xSpace(1.25 * staffSpace);
      for (var pitch in _bassPitches) {
        logger.i('    _bassPitch: $pitch');
        SheetNote sheetNote = SheetNote.note(
          _clef,
          pitch,
          beats / beatsPerBar,
        );
        _renderSheetNote(sheetNote);
        duration += sheetNote.noteDuration ?? 0;

        if (duration >= 1) {
          _xSpace(1.25 * staffSpace);
          _renderBarlineSingle();
          duration = 0;
          _xSpace(1.25 * staffSpace);
          _clearMeasureAccidentals();
        } else {
          _xSpace(1.25 * staffSpace);
        }
      }

      _xSpace(1.25 * staffSpace);
    }

    _renderSheetFixedYSymbol(restWhole);
    _xSpace(1.25 * staffSpace);
    _renderSheetFixedYSymbol(restHalf);
    _xSpace(1.25 * staffSpace);
    _renderSheetFixedYSymbol(restQuarter);
    _xSpace(1.25 * staffSpace);
    _renderSheetFixedYSymbol(rest8th);
    _xSpace(1.25 * staffSpace);
    _renderSheetFixedYSymbol(rest16th);
  }

  final List<Pitch> _bassPitches = [
    Pitch.get(PitchEnum.E1),
    Pitch.get(PitchEnum.E1),
    Pitch.get(PitchEnum.E1),
    Pitch.get(PitchEnum.F1),
    Pitch.get(PitchEnum.G1),
    Pitch.get(PitchEnum.A1),
    Pitch.get(PitchEnum.B1),
    Pitch.get(PitchEnum.C2),
    Pitch.get(PitchEnum.C2),
    Pitch.get(PitchEnum.C2),
  ];
}

List<Chord> _chords = [];

List<Chord> _getChords() {
  if (_chords.isEmpty) {
    const beats = 1;
    const beatsPerBar = 4;
    const List<ScaleNoteEnum> scaleNoteEnums = [
      ScaleNoteEnum.C,
      ScaleNoteEnum.D,
      ScaleNoteEnum.E,
      ScaleNoteEnum.F,
      ScaleNoteEnum.G,
      ScaleNoteEnum.A,
      ScaleNoteEnum.Bb,
      ScaleNoteEnum.C,
    ];
    for (var scaleNoteEnum in scaleNoteEnums) {
      ScaleChord scaleChord = ScaleChord(ScaleNote.get(scaleNoteEnum), ChordDescriptor.major);
      _chords.add(Chord(scaleChord, beats, beatsPerBar, null, ChordAnticipationOrDelay.defaultValue, false));
    }
  }
  return _chords;
}

final _black = Paint()..color = Colors.black;
const _lineColor = Colors.black54;
final _red = Paint()..color = Colors.red;
final _transGrey = Paint()..color = Colors.grey.withAlpha(80);
final _transBlue = Paint()..color = Colors.blue.withAlpha(80);
