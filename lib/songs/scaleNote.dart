//

import 'dart:collection';

import '../util.dart';

enum ScaleNoteEnum {
  A,
  As,
  B,
  C,
  Cs,
  D,
  Ds,
  E,
  F,
  Fs,
  G,
  Gs,
  Gb,
  Eb,
  Db,
  Bb,
  Ab,
  Cb, //  used for Gb (-6) key
  Es, //  used for Fs (+6) key
  Bs, //   for completeness of piano expression
  Fb, //   for completeness of piano expression
  X //  No scale note!  Used to avoid testing for null
}

///
class ScaleNote {
  ScaleNote(_enum) {
    this._enum = _enum;
    switch (_enum) {
      case ScaleNoteEnum.A:
      case ScaleNoteEnum.X:
        _halfStep = 0;
        break;
      case ScaleNoteEnum.As:
      case ScaleNoteEnum.Bb:
        _halfStep = 1;
        break;
      case ScaleNoteEnum.B:
      case ScaleNoteEnum.Cb:
        _halfStep = 2;
        break;
      case ScaleNoteEnum.C:
      case ScaleNoteEnum.Bs:
        _halfStep = 3;
        break;
      case ScaleNoteEnum.Cs:
      case ScaleNoteEnum.Db:
        _halfStep = 4;
        break;
      case ScaleNoteEnum.D:
        _halfStep = 5;
        break;
      case ScaleNoteEnum.Ds:
      case ScaleNoteEnum.Eb:
        _halfStep = 6;
        break;
      case ScaleNoteEnum.E:
      case ScaleNoteEnum.Fb:
        _halfStep = 7;
        break;
      case ScaleNoteEnum.F:
      case ScaleNoteEnum.Es:
        _halfStep = 8;
        break;
      case ScaleNoteEnum.Fs:
      case ScaleNoteEnum.Gb:
        _halfStep = 9;
        break;
      case ScaleNoteEnum.G:
        _halfStep = 10;
        break;
      case ScaleNoteEnum.Gs:
      case ScaleNoteEnum.Ab:
        _halfStep = 11;
        break;
    }

    String mod = "";
    String modHtml = "";

    _isSharp = false;
    _isFlat = false;
    _isNatural = false;
    _isSilent = false;

    switch (_enum) {
      case ScaleNoteEnum.A:
      case ScaleNoteEnum.B:
      case ScaleNoteEnum.C:
      case ScaleNoteEnum.D:
      case ScaleNoteEnum.E:
      case ScaleNoteEnum.F:
      case ScaleNoteEnum.G:
        mod += '\u266E';
        modHtml = "&#9838;";
        _isNatural = true;
        break;
      case ScaleNoteEnum.X:
        _isSilent = true;
        break;
      case ScaleNoteEnum.As:
      case ScaleNoteEnum.Bs:
      case ScaleNoteEnum.Cs:
      case ScaleNoteEnum.Ds:
      case ScaleNoteEnum.Es:
      case ScaleNoteEnum.Fs:
      case ScaleNoteEnum.Gs:
        mod += '\u266F';
        modHtml = "&#9839;";
        _isSharp = true;
        break;
      case ScaleNoteEnum.Ab:
      case ScaleNoteEnum.Bb:
      case ScaleNoteEnum.Cb:
      case ScaleNoteEnum.Db:
      case ScaleNoteEnum.Eb:
      case ScaleNoteEnum.Fb:
      case ScaleNoteEnum.Gb:
        mod += '\u266D';
        modHtml = "&#9837;";
        _isFlat = true;
        break;
    }
    String base = _enum.toString().split('.').last;
    base = base.substring(0, 1);
    _scaleNoteString = base + mod;
    _scaleNoteHtml = base + modHtml;
    _scaleNoteMarkup = base;

    //  find and assign the alias, if it exists
    for (ScaleNoteEnum e in ScaleNoteEnum.values) {
      ScaleNote other = get(e);
      if (this != other && this.halfStep == other.halfStep) {
        this._alias = other;
      }
    }
  }

  ScaleNoteEnum getEnum() {
    return _enum;
  }

  /// A utility to map the sharp scale notes to their half step offset.
  /// Should use the scale notes from the key under normal situations.
  ///
  /// @param step the number of half steps from A
  /// @return the sharp scale note
  static ScaleNote getSharpByHalfStep(int step) {
    return get(_sharps[Util.mod(step, halfStepsPerOctave)]);
  }

  /// A utility to map the flat scale notes to their half step offset.
  /// Should use the scale notes from the key under normal situations.
  ///
  /// @param step the number of half steps from A
  /// @return the sharp scale note
  static ScaleNote getFlatByHalfStep(int step) {
    return get(_flats[Util.mod(step, halfStepsPerOctave)]);
  }

//  final static ScaleNote parse(String s)
//  throws ParseException {
//  return parse(new MarkedString(s));
//}
//
//
  ///**
// * Return the ScaleNote represented by the given string.
// * Is case sensitive.
// * <p>Ultimately, the markup language will disappear.</p>
// *
// * @param markedString string buffer to be parsed
// * @return ScaleNote represented by the string.  Can be null.
// * @throws ParseException thrown if parsing fails
// */
//final static ScaleNote parse(MarkedString markedString)
//throws ParseException {
//if (markedString == null || markedString.isEmpty())
//throw new ParseException("no data to parse", 0);
//
//char c = markedString.charAt(0);
//if (c < 'A' || c > 'G') {
//if (c == 'X') {
//markedString.getNextChar();
//return ScaleNote.X;
//}
//throw new ParseException("scale note must start with A to G", 0);
//}
//
//StringBuilder scaleNoteString = new StringBuilder();
//scaleNoteString.append(c);
//markedString.getNextChar();
//
////  look for modifier
//if (!markedString.isEmpty()) {
//c = markedString.charAt(0);
//switch (c) {
//case 'b':
//case MusicConstant.flatChar:
//scaleNoteString.append('b');
//markedString.getNextChar();
//break;
//
//case '#':
//case MusicConstant.sharpChar:
//scaleNoteString.append('s');
//markedString.getNextChar();
//break;
//}
//}
//
//return ScaleNote.valueOf(scaleNoteString.toString());
//}
//
//public final ScaleNote transpose(Key key, int steps) {
//if (this == ScaleNote.X)
//return ScaleNote.X;
//return key.getScaleNoteByHalfStep(halfStep + steps);
//}
//


  ///**
// * Returns the name of this scale note in an HTML format.
// *
// * @return the scale note as HTML
// */
  String toHtml() {
    return _scaleNoteHtml;
  }

  ///**
  // * Return the scale note as markup.
  String toMarkup() {
    return _scaleNoteMarkup;
  }

  ScaleNoteEnum _enum;

  int _halfStep;

  int get halfStep => _halfStep;

  String _scaleNoteString;
  String _scaleNoteHtml;
  String _scaleNoteMarkup;

  ScaleNote _alias;

  ScaleNote get alias => _alias;

  bool _isSharp;

  bool get isSharp => _isSharp;

  bool _isFlat;

  bool get isFlat => _isFlat;

  bool _isNatural;

  bool get isNatural => _isNatural;

  bool _isSilent;

  bool get isSilent => _isSilent;

  ///
  //  Returns the name of this scale note in a user friendly text format,
  //  i.e. as UTF-8
  @override
  String toString() {
    return _scaleNoteMarkup;
  }

  static final _sharps = [
    ScaleNoteEnum.A,
    ScaleNoteEnum.As,
    ScaleNoteEnum.B,
    ScaleNoteEnum.C,
    ScaleNoteEnum.Cs,
    ScaleNoteEnum.D,
    ScaleNoteEnum.Ds,
    ScaleNoteEnum.E,
    ScaleNoteEnum.F,
    ScaleNoteEnum.Fs,
    ScaleNoteEnum.G,
    ScaleNoteEnum.Gs
  ];
  static final _flats = [
    ScaleNoteEnum.A,
    ScaleNoteEnum.Bb,
    ScaleNoteEnum.B,
    ScaleNoteEnum.C,
    ScaleNoteEnum.Db,
    ScaleNoteEnum.D,
    ScaleNoteEnum.Eb,
    ScaleNoteEnum.E,
    ScaleNoteEnum.F,
    ScaleNoteEnum.Gb,
    ScaleNoteEnum.G,
    ScaleNoteEnum.Ab
  ];

  static final int halfStepsPerOctave = 12;

  static HashMap<ScaleNoteEnum, ScaleNote> _map = HashMap();

  static ScaleNote get(ScaleNoteEnum e) {
    ScaleNote ret = _map[e];
    if (ret == null) {
      //  lazy eval of all values... eventually
      ret = ScaleNote(e);
      _map[e] = ret;
    }
    return ret;
  }
}
