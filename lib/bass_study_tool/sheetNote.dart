import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/chord.dart';
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/pitch.dart';
import 'package:enum_to_string/enum_to_string.dart';

import 'sheetMusicFontParameters.dart';

const double staffVerticalGaps = 4; //  always!
const double staffMargin = 3;

enum SheetDisplay {
  //  in order:
  section,
  measureCount,
  chords,
  lyrics,
  guitarFingerings,
  pianoChords,
  pianoTreble, //  + guitar
  pianoBass, //  i.e. piano left hand
  bassNoteNumbers,
  bassNotes,
  bass8vb, //  bass guitar
}

extension SheetDisplayExtension on SheetDisplay {
  String get name {
    return EnumToString.convertToString(this);
  }
}

String sheetDisplaySetEncode(Set<SheetDisplay> set) {
  StringBuffer ret = StringBuffer();
  var first = true;
  for (var sheetDisplay in set) {
    if (first) {
      first = false;
    } else {
      ret.write(', ');
    }
    ret.write(sheetDisplay.name);
  }
  return ret.toString();
}

HashSet<SheetDisplay> sheetDisplaySetDecode(String all) {
  HashSet<SheetDisplay> ret = HashSet();
  for (var name in all.split(', ')) {
    var value = EnumToString.fromString(SheetDisplay.values, name);
    if (value != null) {
      ret.add(value);
    }
  }
  return ret;
}

List<bool> sheetDisplayEnables = List.filled(SheetDisplay.values.length, false);

bool hasDisplay(SheetDisplay display) {
  return sheetDisplayEnables[display.index];
}

bool isUpNote(Clef clef, Pitch pitch) {
  var pitchUpNumber = 0;
  switch (clef) {
    case Clef.treble:
      pitchUpNumber = Pitch.get(PitchEnum.B4).number;
      break;
    case Clef.bass:
      pitchUpNumber = Pitch.get(PitchEnum.D3).number;
      break;
    case Clef.bass8vb:
      pitchUpNumber = Pitch.get(PitchEnum.D2).number;
      break;
  }
  return pitch.number < pitchUpNumber;
}

class SheetNoteSymbol {
  SheetNoteSymbol.glyphBBoxes(this._name, this._character, final Point<double> bBoxNE, final Point<double> bBoxSW,
      {double? staffPosition, this.isUp = true, double? fontSizeOnStaffs})
      : bounds = Rect.fromLTRB(bBoxSW.x, -bBoxNE.y, bBoxNE.x, -bBoxSW.y),
        staffPosition = staffPosition ?? 0,
        fontSizeOnStaffs = fontSizeOnStaffs ?? 4;

  SheetNoteSymbol.fixed(this._name, this._character, final Point<double> bBoxNE, final Point<double> bBoxSW,
      {double? staffPosition, double? fontSizeOnStaffs})
      : bounds = Rect.fromLTRB(bBoxSW.x, -bBoxNE.y, bBoxNE.x, -bBoxSW.y),
        staffPosition = staffPosition ?? 0,
        fontSizeOnStaffs = fontSizeOnStaffs ?? 4,
        isUp = false;

  String? get name => _name;
  final String? _name;

  String get character => _character;
  final String _character;

  final double fontSizeOnStaffs;

  double get width => bounds.width;

  final Rect bounds;

  final bool isUp;

  final double staffPosition; //  set when the pitch and staff are known

  double get fixedYOff => _fixedYOff;
  static const double _fixedYOff = 4;

  double get height => bounds.height;
}

//  notes
final noteWhole =
    SheetNoteSymbol.glyphBBoxes('noteWhole', '\uE1D2', GlyphBBoxesNoteWhole.bBoxNE, GlyphBBoxesNoteWhole.bBoxSW);
final noteHalfUp =
    SheetNoteSymbol.glyphBBoxes('noteHalfUp', '\uE1D3', GlyphBBoxesNoteHalfUp.bBoxNE, GlyphBBoxesNoteHalfUp.bBoxSW);
final noteHalfDown = SheetNoteSymbol.glyphBBoxes(
    'noteHalfDown', '\uE1D4', GlyphBBoxesNoteHalfDown.bBoxNE, GlyphBBoxesNoteHalfDown.bBoxSW,
    isUp: false);

final noteQuarterUp = SheetNoteSymbol.glyphBBoxes(
    'noteQuarterUp', '\uE1D5', GlyphBBoxesNoteQuarterUp.bBoxNE, GlyphBBoxesNoteQuarterUp.bBoxSW);
final noteQuarterDown = SheetNoteSymbol.glyphBBoxes(
    'noteQuarterDown', '\uE1D6', GlyphBBoxesNoteQuarterDown.bBoxNE, GlyphBBoxesNoteQuarterDown.bBoxSW,
    isUp: false);

final note8thUp =
    SheetNoteSymbol.glyphBBoxes('note8thUp', '\uE1D7', GlyphBBoxesNote8thUp.bBoxNE, GlyphBBoxesNote8thUp.bBoxSW);
final note8thDown = SheetNoteSymbol.glyphBBoxes(
    'note8thDown', '\uE1D8', GlyphBBoxesNote8thDown.bBoxNE, GlyphBBoxesNote8thDown.bBoxSW,
    isUp: false);

final note16thUp =
    SheetNoteSymbol.glyphBBoxes('note16thUp', '\uE1D9', GlyphBBoxesNote16thUp.bBoxNE, GlyphBBoxesNote16thUp.bBoxSW);
final note16thDown = SheetNoteSymbol.glyphBBoxes(
    'note16thDown', '\uE1DA', GlyphBBoxesNote16thDown.bBoxNE, GlyphBBoxesNote16thDown.bBoxSW,
    isUp: false);

//  rests
final restWhole = SheetNoteSymbol.fixed('restWhole', '\uE4E3', GlyphBBoxesRestWhole.bBoxNE, GlyphBBoxesRestWhole.bBoxSW,
    staffPosition: 1);
final restHalf = SheetNoteSymbol.fixed('restHalf', '\uE4E4', GlyphBBoxesRestHalf.bBoxNE, GlyphBBoxesRestHalf.bBoxSW,
    staffPosition: 2);
final restQuarter = SheetNoteSymbol.fixed(
    'restQuarter', '\uE4E5', GlyphBBoxesRestQuarter.bBoxNE, GlyphBBoxesRestQuarter.bBoxSW,
    staffPosition: 2);
final rest8th =
    SheetNoteSymbol.fixed('rest8th', '\uE4E6', GlyphBBoxesRest8th.bBoxNE, GlyphBBoxesRest8th.bBoxSW, staffPosition: 2);
final rest16th = SheetNoteSymbol.fixed('rest16th', '\uE4E7', GlyphBBoxesRest16th.bBoxNE, GlyphBBoxesRest16th.bBoxSW,
    staffPosition: 2);

//  markers
final brace = SheetNoteSymbol.fixed('brace', '\uE000', GlyphBBoxesBrace.bBoxNE, GlyphBBoxesBrace.bBoxSW,
    staffPosition: 2 * 4 + 2 * staffMargin, fontSizeOnStaffs: 2 * 4 + 2 * staffMargin);
//final barlineSingle = SheetNoteSymbol.glyphBBoxes(
//    'barlineSingle', '\uE030', GlyphBBoxesBarlineSingle.bBoxNE, GlyphBBoxesBarlineSingle.bBoxSW);
final trebleClef //  i.e. gClef
    = SheetNoteSymbol.fixed('trebleClef', '\uE050', GlyphBBoxesGClef.bBoxNE, GlyphBBoxesGClef.bBoxSW,
        staffPosition: 4 - 1);
final bassClef //  i.e. fClef
    =
    SheetNoteSymbol.fixed('bassClef', '\uE062', GlyphBBoxesFClef.bBoxNE, GlyphBBoxesFClef.bBoxSW, staffPosition: 1.25);
final bass8vbClef //  i.e. bass guitar fClef, F clef ottava bassa, fClef8vb
    = SheetNoteSymbol.fixed('bassClef', '\uE064', GlyphBBoxesFClef8vb.bBoxNE, GlyphBBoxesFClef8vb.bBoxSW,
        staffPosition: 1);

//  accidentals
final accidentalFlat = SheetNoteSymbol.glyphBBoxes(
    'accidentalFlat', '\uE260', GlyphBBoxesAccidentalFlat.bBoxNE, GlyphBBoxesAccidentalFlat.bBoxSW);
final accidentalNatural = SheetNoteSymbol.glyphBBoxes(
    'accidentalNatural', '\uE261', GlyphBBoxesAccidentalNatural.bBoxNE, GlyphBBoxesAccidentalNatural.bBoxSW);
final accidentalSharp = SheetNoteSymbol.glyphBBoxes(
    'accidentalSharp', '\uE262', GlyphBBoxesAccidentalSharp.bBoxNE, GlyphBBoxesAccidentalSharp.bBoxSW);
final augmentationDot = SheetNoteSymbol.glyphBBoxes(
    'augmentationDot', '\uE1E7', GlyphBBoxesAugmentationDot.bBoxNE, GlyphBBoxesAugmentationDot.bBoxSW);

//  time signatures
final timeSig0 =
    SheetNoteSymbol.glyphBBoxes('timeSig0', '\uE080', GlyphBBoxesTimeSig0.bBoxNE, GlyphBBoxesTimeSig0.bBoxSW);
final timeSig1 =
    SheetNoteSymbol.glyphBBoxes('timeSig1', '\uE081', GlyphBBoxesTimeSig1.bBoxNE, GlyphBBoxesTimeSig1.bBoxSW);
final timeSig2 =
    SheetNoteSymbol.glyphBBoxes('timeSig2', '\uE082', GlyphBBoxesTimeSig2.bBoxNE, GlyphBBoxesTimeSig2.bBoxSW);
final timeSig3 =
    SheetNoteSymbol.glyphBBoxes('timeSig3', '\uE083', GlyphBBoxesTimeSig3.bBoxNE, GlyphBBoxesTimeSig3.bBoxSW);
final timeSig4 =
    SheetNoteSymbol.glyphBBoxes('timeSig4', '\uE084', GlyphBBoxesTimeSig4.bBoxNE, GlyphBBoxesTimeSig4.bBoxSW);
final timeSig5 =
    SheetNoteSymbol.glyphBBoxes('timeSig5', '\uE085', GlyphBBoxesTimeSig5.bBoxNE, GlyphBBoxesTimeSig5.bBoxSW);
final timeSig6 =
    SheetNoteSymbol.glyphBBoxes('timeSig6', '\uE086', GlyphBBoxesTimeSig6.bBoxNE, GlyphBBoxesTimeSig6.bBoxSW);
final timeSig7 =
    SheetNoteSymbol.glyphBBoxes('timeSig7', '\uE087', GlyphBBoxesTimeSig7.bBoxNE, GlyphBBoxesTimeSig7.bBoxSW);
final timeSig8 =
    SheetNoteSymbol.glyphBBoxes('timeSig8', '\uE088', GlyphBBoxesTimeSig8.bBoxNE, GlyphBBoxesTimeSig8.bBoxSW);
final timeSig9 =
    SheetNoteSymbol.glyphBBoxes('timeSig9', '\uE089', GlyphBBoxesTimeSig9.bBoxNE, GlyphBBoxesTimeSig9.bBoxSW);

final List<SheetNoteSymbol> timeSigs = [
  timeSig0,
  timeSig1,
  timeSig2,
  timeSig3,
  timeSig4,
  timeSig5,
  timeSig6,
  timeSig7,
  timeSig8,
  timeSig9,
];

final timeSigCommon = SheetNoteSymbol.fixed(
    'timeSigCommon', '\uE08A', GlyphBBoxesTimeSigCommon.bBoxNE, GlyphBBoxesTimeSigCommon.bBoxSW,
    staffPosition: 2);

// SheetNoteSymbol.fixed sheetNoteRest(double _noteDuration) {
//   SheetNoteSymbol.fixed symbol = restWhole; //  fixme!
// //  find rest symbol by value, in units of measure
//   if (_noteDuration == 1) {
//     symbol = restWhole;
//   } else if (_noteDuration == 1 / 2) {
//     symbol = restHalf;
//   } else if (_noteDuration == 1 / 4) {
//     symbol = restQuarter;
//   } else if (_noteDuration == 1 / 8) {
//     symbol = rest8th;
//   } else if (_noteDuration == 1 / 16) {
//     symbol = rest16th;
//   } else {
//     symbol = restWhole; //  fixme!
//     logger.w('rest duration is not legal: $_noteDuration');
//   }
//   return symbol;
// }

class SheetNote {
  SheetNote.note(this._clef, this._pitch, this._noteDuration,
      {bool? dotted, bool? tied, Chord? chord, String? lyrics, bool? makeUpNote})
      : _isNote = true,
        _lyrics = lyrics,
        _dotted = dotted ?? false,
        _chord = chord,
        _tied = tied {
    //  find note symbol by value, in units of measure
    bool upNote = makeUpNote ?? isUpNote(_clef, _pitch!);
    if (_noteDuration == 1) {
      _symbol = noteWhole;
    } else if (_noteDuration == 1 / 2 + 1 / 4) {
      _symbol = upNote ? noteHalfUp : noteHalfDown;
      _dotted = true;
    } else if (_noteDuration == 1 / 2) {
      _symbol = upNote ? noteHalfUp : noteHalfDown;
    } else if (_noteDuration == 1 / 4 + 1 / 8) {
      _symbol = upNote ? noteQuarterUp : noteQuarterDown;
      _dotted = true;
    } else if (_noteDuration == 1 / 4) {
      _symbol = upNote ? noteQuarterUp : noteQuarterDown;
    } else if (_noteDuration == 1 / 8 + 1 / 16) {
      _symbol = upNote ? note8thUp : note8thDown;
      _dotted = true;
    } else if (_noteDuration == 1 / 8) {
      _symbol = upNote ? note8thUp : note8thDown;
    } else if (_noteDuration == 1 / 16) {
      _symbol = upNote ? note16thUp : note16thDown;
    } else {
      _symbol = restWhole; //  fixme!
      logger.w('note duration is not legal: $_noteDuration');
    }
  }

  SheetNote.rest(this._clef, this._noteDuration, {String? lyrics})
      : _isNote = false,
        _lyrics = lyrics {
    //  find rest symbol by value, in units of measure
    if (_noteDuration == 1) {
      _symbol = restWhole;
    } else if (_noteDuration == 1 / 2) {
      _symbol = restHalf;
    } else if (_noteDuration == 1 / 4) {
      _symbol = restQuarter;
    } else if (_noteDuration == 1 / 8) {
      _symbol = rest8th;
    } else if (_noteDuration == 1 / 16) {
      _symbol = rest16th;
    } else {
      _symbol = restWhole; //  fixme!
      logger.w('rest duration is not legal: $_noteDuration');
    }
  }

  @override
  String toString() {
    if (_isNote) {
      return 'note: $pitch for ${(_noteDuration ?? 0).toStringAsFixed(4)}'
          ' ${_symbol._name ?? '?'} on $clef';
    }
    //  is rest
    return 'rest: for ${(_noteDuration ?? 0).toStringAsFixed(4)} m'
        ' ${_symbol._name ?? '?'} on $clef';
  }

  bool get isNote => _isNote;
  final bool _isNote; //  otherwise a rest
  bool get isRest => !isNote;

  Clef get clef => _clef;
  final Clef _clef;

  Pitch? get pitch => _pitch;
  Pitch? _pitch;

  double? get noteDuration => _noteDuration;
  final double? _noteDuration;

  bool get dotted => _dotted;
  late bool _dotted = false;

  bool? get tied => _tied;
  bool? _tied = false;

  Chord? get chord => _chord;
  Chord? _chord; //  member of

  String? get lyrics => _lyrics;
  final String? _lyrics;

  int? line;
  int? measure; //  ????

  SheetNoteSymbol get symbol => _symbol;
  late SheetNoteSymbol _symbol;
}
