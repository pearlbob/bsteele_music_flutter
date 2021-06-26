import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicPainter.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:flutter/material.dart';

class SheetNotation {
  SheetNotation(this.sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : preHeight = preHeight ?? 0,
        activeHeight = activeHeight ?? 0,
        postHeight = postHeight ?? 0 {
    totalHeight = this.preHeight + this.activeHeight + this.postHeight;
    assert(this.preHeight >= 0);
    assert(this.activeHeight > 0);
    assert(this.postHeight >= 0);
    dy = 0 + this.preHeight;
  }

  @override
  String toString() {
    return 'SheetNotation{$sheetDisplay'
        ', offset: ($dx, $dy), heights: $preHeight + $activeHeight + $postHeight = $totalHeight }';
  }

  void renderStaff(Canvas canvas, double width) {}

  void renderClef(
    Canvas canvas,
  ) {}

  double dx = 0;
  double dy = 0; //  nominal vertical position
  final double preHeight;
  final double activeHeight;
  final double postHeight;
  late final double totalHeight;

  final SheetDisplay sheetDisplay;
}

class SheetStaffNotation extends SheetNotation {
  SheetStaffNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : _clef = clef ?? trebleClef,
        super(sheetDisplay, preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight);

  @override
  void renderStaff(Canvas canvas, double width) {
    _canvas = canvas;
    final black = Paint();
    black.color = Colors.black;
    black.style = PaintingStyle.stroke;
    black.strokeWidth = staffLineThickness * staffSpace;

    var y = dy + preHeight;
    for (int line = 0; line < 5; line++) {
      canvas.drawLine(
          Offset(dx, y + line * staffSpace), Offset(dx + width, y + line * staffSpace), black);
    }
  }

  @override
  void renderClef(Canvas canvas) {
    _canvas = canvas;
    _renderSheetFixedYSymbol(_clef);
  }

  void _renderSheetFixedYSymbol(SheetNoteSymbol symbol) {
    _renderSheetNoteSymbol(symbol, symbol.fixedYOff + staffMargin, isStave: false);
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

    logger.v('${symbol.name} w: $w');

    Rect ret = Rect.fromLTRB(
        dx + symbol.bounds.left * scaledStaffSpace,
        dy + (-symbol.bounds.top + staffPosition) * scaledStaffSpace,
        dx + symbol.bounds.right * scaledStaffSpace * scale,
        dy + (-symbol.bounds.bottom + staffPosition) * scaledStaffSpace);

    // if (_debug) {
    //   _canvas.drawRect(
    //       ret,
    //       _grey);
    // }

    Offset offset = Offset(dx + symbol.bounds.left, dy + -2 * w + (staffPosition - 0.05) * staffSpace);
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

  void renderStaves(SheetNoteSymbol symbol, double staffPosition) {
    //  truncate to staff line height
    staffPosition = staffPosition.toInt().toDouble();

    if (staffPosition >= 0 && staffPosition <= staffGaps) {
      return;
    }

    final black = Paint();
    black.color = Colors.black;
    black.style = PaintingStyle.stroke;
    black.strokeWidth = staffLineThickness * staffSpace;

    while (staffPosition < 0) {
      _canvas.drawLine(Offset(dx + (symbol.bounds.left - 0.5) * staffSpace, dy + staffPosition * staffSpace),
          Offset(dx + (symbol.bounds.right + 0.5) * staffSpace, dy + staffPosition * staffSpace), black);
      staffPosition++;
    }

    while (staffPosition > staffGaps) {
      _canvas.drawLine(Offset(dx + (symbol.bounds.left - 0.5) * staffSpace, dy + staffPosition * staffSpace),
          Offset(dx + (symbol.bounds.right + 0.5) * staffSpace, dy + staffPosition * staffSpace), black);
      staffPosition--;
    }
  }

  void _xSpace(double space) {
    dx += space;
  }

  late Canvas _canvas;
  late final SheetNoteSymbol _clef;
}

final _black = Paint()..color = Colors.black;
