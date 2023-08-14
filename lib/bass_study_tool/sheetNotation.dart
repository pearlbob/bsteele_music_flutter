import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/chord.dart';
import 'package:bsteele_music_lib/songs/chord_component.dart';
import 'package:bsteele_music_lib/songs/key.dart' as musical_key;
import 'package:bsteele_music_lib/songs/lyric_section.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/pitch.dart';
import 'package:bsteele_music_lib/songs/scale_note.dart';
import 'package:bsteele_music_lib/songs/song_moment.dart';
import 'package:bsteele_music_lib/songs/time_signature.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetMusicPainter.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:flutter/material.dart';

const bool _debug = false; // kDebugMode false
const double _chordFontSize = 24;

//  fixme:  B in bass in key of Gb doesn't have a natural, a key.transpose( , 0 ) problem
//  fixme: fretboard web strings don't vary in size
//  fixme: theory screen: scale notes are always major scale.  correct?

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

    if (_debug) {
      {
        _renderText(sheetDisplay.name, xOff: 45); //  debug name
        canvas.drawRect(Rect.fromLTWH(sheetDisplay.index * 30, dy, 10, totalHeight), _transGrey);
        canvas.drawRect(Rect.fromLTWH(sheetDisplay.index * 30 - 5, dy, 10, preHeight), _transBlue);
        canvas.drawRect(
            Rect.fromLTWH(sheetDisplay.index * 30 + 5, dy + preHeight + activeHeight, 10, postHeight), _transBlue);
      }
    }

    drawNotationStart();
  }

  void drawNotationStart() {
    sheetNoteLocations.clear();
  }

  void drawBeat(SongMoment songMoment, double beat) {}

  /// render text and return the pixels used
  double _renderText(String text,
      {Color? color, double? xOff, double? yOff, double? fontSize, FontWeight? fontWeight}) {
    //   final double w = 2 * staffSpace * text.length;
    var textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? _black.color,
          fontSize: fontSize ?? _fontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(
        minWidth: 10,
        maxWidth: 400,
      );
    // _canvas.drawRect(
    //     Rect.fromLTWH(xOff ?? dx, yOff ?? dy, textPainter.size.width, textPainter.size.height), _transGrey);
    textPainter.paint(_canvas, Offset(xOff ?? dx, yOff ?? dy));

    return textPainter.size.width;
  }

  reset() {
    dx = 0;
    _timeSignatureShown = false;
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

  final musical_key.Key _key = app.selectedSong.key;

  final SheetDisplay sheetDisplay;

  late Canvas _canvas;
  late Size _size;

  static bool _timeSignatureShown = false;
  static const double _fontSize = 15; //  fixme

  List<SheetNoteLocation> sheetNoteLocations = [];
}

class SheetTextNotation extends SheetNotation {
  SheetTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super._(sheetDisplay, preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight);
}

class SheetSectionTextNotation extends SheetTextNotation {
  SheetSectionTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight ?? 1.5 * _chordFontSize, postHeight: postHeight);

  @override
  void drawNotationStart() {
    dx += _renderText('Section:');
  }

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    LyricSection lyricSection = songMoment.lyricSection;
    if (beat == 0 &&
        (lastLyricSection == null //  first lyric section shown
            ||
            app.selectedMomentNumber == songMoment.momentNumber //  first lyric section in the display
            ||
            lastLyricSection != lyricSection //  different from last lyric section shown
        )) {
      dx += _renderText(
        lyricSection.toString(),
        fontSize: _chordFontSize,
      );
      lastLyricSection = lyricSection;
    }
  }

  LyricSection? lastLyricSection;
}

class SheetMeasureCountTextNotation extends SheetTextNotation {
  SheetMeasureCountTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight ?? 2 * _chordFontSize, postHeight: postHeight);

  @override
  void drawNotationStart() {
    dx += _renderText('Measure:');
  }

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      dx += _renderText((songMoment.momentNumber + 1).toString());
    }
  }
}

class SheetChordTextNotation extends SheetTextNotation {
  SheetChordTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight ?? 1.5 * _chordFontSize, postHeight: postHeight);

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      dx += staffSpace;
    }

    int priorBeats = 0;
    for (var chord in songMoment.measure.chords) {
      if (priorBeats == beat) {
        dx += _renderText(chord.transpose(_key, 0).toMarkup(), fontSize: _chordFontSize, fontWeight: FontWeight.bold);
        dx += staffSpace;
        break;
      }
      priorBeats += chord.beats;
    }
  }
}

class SheetLyricsTextNotation extends SheetTextNotation {
  SheetLyricsTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight ?? 1.5 * _chordFontSize, postHeight: postHeight);

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      dx += staffSpace;
      String lyrics = (songMoment.lyrics ?? '').replaceAll('\n', ' ').trim();
      double width = _renderText(lyrics, fontSize: _chordFontSize);
      dx += width;
      logger.d('"$lyrics": width: $width');
    }
  }
}

class SheetBassNoteNumbersTextNotation extends SheetTextNotation {
  SheetBassNoteNumbersTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight ?? 1.5 * _chordFontSize, postHeight: postHeight);

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      dx += staffSpace;
    }
    int priorBeats = 0;
    for (var chord in songMoment.measure.chords) {
      if (priorBeats == beat) {
        if (chord.scaleChord.scaleNote.isSilent) {
          //  do nothing
        } else {
          final sn = chord.slashScaleNote ?? chord.scaleChord.scaleNote;
          var halfStep = (sn.halfStep - chord.scaleChord.scaleNote.halfStep) % MusicConstants.halfStepsPerOctave;
          _renderText(ChordComponent.values[halfStep].toString(), fontSize: _chordFontSize);
          dx += staffSpace;
        }
        break;
      }
      priorBeats += chord.beats;
    }
  }
}

class SheetBassNotesTextNotation extends SheetTextNotation {
  SheetBassNotesTextNotation(SheetDisplay sheetDisplay,
      {double? preHeight, double? activeHeight, double? postHeight, SheetNoteSymbol? clef})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight ?? 1.5 * _chordFontSize, postHeight: postHeight);

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      dx += staffSpace;
    }
    int priorBeats = 0;
    for (var chord in songMoment.measure.chords) {
      if (priorBeats == beat) {
        if (chord.scaleChord.scaleNote.isSilent) {
          //  do nothing
        } else {
          Pitch p = Pitch.findPitch(chord.slashScaleNote ?? chord.scaleChord.scaleNote, Chord.minimumBassSlashPitch);
          p = _key.isSharp ? p.asSharp() : p.asFlat();
          _renderText(p.toString(), fontSize: _chordFontSize);
          dx += staffSpace;
        }
        break;
      }
      priorBeats += chord.beats;
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
  void drawNotationStart() {
    super.drawNotationStart();

    _clearAccidentals();

    _renderStaff();
    dx += 10; //fixme
    _renderSheetFixedYSymbol(_clefSymbol);

    dx += staffSpace;

    _renderKeyStaffSymbols();
    dx += staffSpace;

    //  fill in the time signature
    if (!SheetNotation._timeSignatureShown) {
      TimeSignature timeSignature = app.selectedSong.timeSignature;
      if (timeSignature == TimeSignature.commonTimeSignature) {
        _renderSheetFixedYSymbol(timeSigCommon);
      } else {
        _renderSheetNoteSymbol(timeSigs[timeSignature.beatsPerBar % timeSigs.length], 1, renderForward: false);
        _renderSheetNoteSymbol(timeSigs[timeSignature.unitsPerMeasure % timeSigs.length], 3);
      }
    }
    SheetNotation._timeSignatureShown = true;
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

  SheetNoteSymbol _clefSheetNoteSymbol(Clef clef) {
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
  Rect _renderSheetNote(
    SheetNote sn, {
    bool renderForward = true,
    double scale = 1.0,
    double? accidentalDx,
    double? rootDx,
  }) {
    if (sn.pitch == null) {
      throw 'pitch not found: ${sn.pitch}';
    }

    Pitch? pitch = _key.mappedPitch(sn.pitch!);
    double staffPosition = musical_key.Key.getStaffPosition(_clef, pitch);

    double myAccidentalDx = accidentalDx ?? dx;
    double theRootDx = rootDx ?? dx;

    logger.t('_measureAccidentals[$staffPosition]: ${_measureAccidentals[staffPosition]}');
    logger.t('_key.getMajorScaleByNote(${pitch.scaleNumber}): ${_key.getMajorScaleByNote(pitch.scaleNumber)}');

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

    logger.t('sn.pitch: ${sn.pitch.toString().padLeft(3)}, pitch: ${pitch.toString().padLeft(3)}'
        ', key: $_key'
        ', accidental: $accidental');
    Rect? accidentalRect;
    if (accidental != null) {
      accidentalRect = _renderSheetNoteSymbol(_accidentalSheetNoteSymbol(accidental), staffPosition,
          scale: scale, renderForward: false, x: myAccidentalDx);
      if (rootDx == null) {
        theRootDx += _accidentalStaffSpace * staffSpace * scale;
      }
      if (_debug) {
        _canvas.drawRect(accidentalRect, _transGrey);
      }

      //  remember the prior accidental for this staff position for this measure
      _measureAccidentals[staffPosition] = accidental;
    }

    logger.d('_measureAccidentals[  $staffPosition  ] = ${_measureAccidentals[staffPosition]} ');

    var rect =
        _renderSheetNoteSymbol(sn.symbol, staffPosition, renderForward: renderForward, scale: scale, x: theRootDx);
    if (accidentalRect != null) {
      rect = rect.expandToInclude(accidentalRect);
    }

    return rect;
  }

  Rect _renderSheetFixedYSymbol(SheetNoteSymbol symbol) {
    return _renderSheetNoteSymbol(symbol, symbol.staffPosition, isStave: false);
  }

  Rect _renderSheetNoteSymbol(
    SheetNoteSymbol symbol,
    double staffPosition, {
    bool isStave = true,
    bool renderForward = true,
    double scale = 1.0,
    double? x,
  }) {
    final double scaledStaffSpace = staffSpace * scale;
    final double w = symbol.fontSizeOnStaffs * scaledStaffSpace;

    double myX = x ?? dx;

    var y = dy + preHeight;
    var yOff = symbol.fixedYOff * scaledStaffSpace;
    var yPos = activeHeight - staffPosition * scaledStaffSpace;
    Rect rect = Rect.fromLTRB(
        myX + symbol.bounds.left * scaledStaffSpace,
        y + yOff - yPos + symbol.bounds.top * scaledStaffSpace,
        myX + symbol.bounds.right * scaledStaffSpace,
        y + yOff - yPos + symbol.bounds.bottom * scaledStaffSpace);

    logger.d('${symbol.name} $staffPosition = $yPos'
        ', ${symbol.bounds.top} to ${symbol.bounds.bottom}, fixedYOff: ${symbol.fixedYOff}');

    Offset offset = Offset(rect.left, y - yOff - yPos);
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

    // if (_debug) {
    //   _canvas.drawRect(ret, _transGrey);
    //   _canvas.drawRect(Rect.fromLTRB(ret.left, y + yOff - yPos - 1, ret.right, y + yOff - yPos + 1), _red);
    // }
    return rect;
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
  void _renderKeyStaffSymbols() {
    if (_key == musical_key.Key.getDefault()) {
      return;
    }

    List<double> locations;
    switch (_clef) {
      case Clef.treble:
        locations = (_key.isSharp
            //	treble sharps:  F♯,C♯,  G♯, D♯, A♯,  E♯,  B♯
            ? const <double>[0, 0, 1.5, -0.5, 1, 2.5, 0.5, 2] //  down from the top
            //  treble flats:     B♭,E♭,  A♭, D♭, G♭,C♭,  F♭
            : const <double>[0, 2, 0.5, 2.5, 1, 3, 1.5, 3.5]);
        break;
      default:
        locations = (_key.isSharp
            //	bass sharps:    F♯,C♯,  G♯, D♯, A♯,  E♯,  B♯
            ? const <double>[0, 1, 2.5, 0.5, 2, 3.5, 1.5, 3] //  down from the top
            //  bass flats:     B♭,E♭,  A♭, D♭, G♭,C♭,  F♭
            : const <double>[0, 3, 1.5, 3.5, 2, 4, 2.5, 4.5]);
        break;
    }

    SheetNoteSymbol symbol = (_key.isSharp ? accidentalSharp : accidentalFlat);
    int limit = _key.getKeyValue().abs();
    for (int i = 1; i <= limit; i++) {
      //  compute height of sharp/flat from note
      //if (doRender)
      _renderSheetNoteSymbol(symbol, locations[i]);
      _xSpace(symbol.width / 2);
    }

    //  end at the end of the last character
    _xSpace(symbol.width / 2);
  }

  void _xSpace(double space) {
    dx += space;
  }

  late final Clef _clef;
  late final SheetNoteSymbol _clefSymbol;

  void _clearAccidentals() {
    //  reset the accidental processing
    _chordMeasureAccidentals.clear();
    _measureAccidentals.clear();
  }

  final Map<double, Accidental> _measureAccidentals = {};
  final Map<double, Accidental> _chordMeasureAccidentals =
      {}; //  fixme: eliminate in favor of the above, _measureAccidentals

  static const double _accidentalStaffSpace = 1;
}

class SheetTrebleStaffNotation extends _SheetStaffNotation {
  SheetTrebleStaffNotation(SheetDisplay sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight, clef: Clef.treble);

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      _clearAccidentals();
    }

    int priorBeats = 0;
    for (var chord in songMoment.measure.chords) {
      if (priorBeats == beat) {
        dx += staffSpace;
        break;
      }
      priorBeats += chord.beats;
    }
  }

//  fixme: fill in the time signature with something other than common time
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

}

class SheetBassStaffNotation extends _SheetStaffNotation {
  SheetBassStaffNotation(SheetDisplay sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : super(sheetDisplay, preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight, clef: Clef.bass);

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      _clearAccidentals();
    }
    // fixme: SheetBassStaffNotation
  }
}

class SheetChordStaffNotation extends _SheetStaffNotation {
  SheetChordStaffNotation(SheetDisplay sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : super(sheetDisplay, preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight);

  @override
  void drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      _clearAccidentals();
    }
    int priorBeats = 0;
    for (var chord in songMoment.measure.chords) {
      if (priorBeats == beat) {
        _drawChord(songMoment, chord);
        dx += staffSpace;
        break;
      }
      priorBeats += chord.beats;
    }
  }

  void _drawChord(SongMoment songMoment, Chord chord) {
    int beats = chord.beats;
    int beatsPerBar = chord.beatsPerBar;

    _xSpace(1.25 * staffSpace);

    Rect? chordRect;
    if (chord.scaleChord.scaleNote.isSilent) {
      //  render the rest
      chordRect = _renderSheetFixedYSymbol(SheetNote.rest(
        _clef,
        beats / beatsPerBar,
      ).symbol);
    } else {
      //  chord declaration over treble staff
      List<Pitch> pitches = chord.pianoChordPitches();
      List<bool> chordAccidentals = [];
      int accidentalCount = 0;
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
          accidentalCount++;
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
      double rootDx = dx + accidentalCount * _SheetStaffNotation._accidentalStaffSpace * staffSpace;
      logger.d('${chord.scaleChord}: $pitches, acc?: $accidentalCount');
      int chordPitchIndex = 0;
      int accidentalIndex = 0;

      for (var pitch in pitches) {
        logger.d('    pitch: $pitch');
        SheetNote sheetNote = SheetNote.note(
          _clef,
          pitch,
          beats / beatsPerBar,
          makeUpNote: isUpChord,
        );

        logger.d('$chord: chordPitchIndex: $chordPitchIndex, acc: ${chordAccidentals[chordPitchIndex]}'
            ', accidentalIndex: $accidentalIndex/$accidentalCount');
        double accidentalDx = originalDx + accidentalIndex * _SheetStaffNotation._accidentalStaffSpace * staffSpace;
        logger.d('   accidentalDx: $accidentalDx');
        if (chordAccidentals[chordPitchIndex]) {
          accidentalIndex++; //  for next time
        }

        Rect rect;
        if (!identical(pitch, pitches.last)) {
          rect = _renderSheetNote(
            sheetNote,
            renderForward: false,
            accidentalDx: accidentalDx,
            rootDx: rootDx,
          );
        } else {
          rect = _renderSheetNote(
            sheetNote,
            renderForward: true,
            accidentalDx: accidentalDx,
            rootDx: rootDx,
          );
        }
        chordRect = chordRect?.expandToInclude(rect) ?? rect;

        chordPitchIndex++;
      }

      if (_debug && chordRect != null) {
        _canvas.drawRect(chordRect, _transGrey);
      }

      _xSpace(1.25 * staffSpace);
    }
  }
}

class SheetBass8vbStaffNotation extends _SheetStaffNotation {
  SheetBass8vbStaffNotation(SheetDisplay sheetDisplay, {double? preHeight, double? activeHeight, double? postHeight})
      : super(sheetDisplay,
            preHeight: preHeight, activeHeight: activeHeight, postHeight: postHeight, clef: Clef.bass8vb);

  @override
  Rect? drawBeat(SongMoment songMoment, double beat) {
    if (beat == 0) {
      _clearAccidentals();
      dx += staffSpace;
    }
    int priorBeats = 0;
    Rect? beatRect;
    SheetNote? sn;
    for (var chord in songMoment.measure.chords) {
      if (priorBeats == beat) {
        if (chord.scaleChord.scaleNote.isSilent) {
          //  render the rest
          sn = SheetNote.rest(_clef, chord.beats / chord.beatsPerBar);
          Rect rect = _renderSheetFixedYSymbol(sn.symbol);
          beatRect = beatRect?.expandToInclude(rect) ?? rect;
        } else {
          sn = SheetNote.note(
              _clef,
              Pitch.findPitch(chord.slashScaleNote ?? chord.scaleChord.scaleNote, Chord.minimumBassSlashPitch),
              chord.beats / chord.beatsPerBar);
          Rect rect = _renderSheetNote(sn);
          beatRect = beatRect?.expandToInclude(rect) ?? rect;
        }
        dx += staffSpace;
        break;
      }
      priorBeats += chord.beats;
    }
    if (beatRect != null) {
      if (sn != null) {
        sheetNoteLocations.add(SheetNoteLocation(songMoment, beat, sn, beatRect));
      }
      if (_debug) {
        _canvas.drawRect(beatRect, _transGrey);
      }
    }
    return beatRect;
  }
}

class SheetNoteLocation {
  SheetNoteLocation(this.songMoment, this.beat, this.sheetNote, this.location);

  SongMoment songMoment;
  double beat;
  SheetNote sheetNote;
  Rect location;
}

final _black = Paint()..color = Colors.black;
const _lineColor = Colors.black54;
// final _red = Paint()..color = Colors.red;
final _transGrey = Paint()..color = Colors.grey.withAlpha(80);
final _transBlue = Paint()..color = Colors.blue.withAlpha(80);
