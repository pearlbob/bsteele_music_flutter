import 'package:bsteele_music_flutter/songs/scaleNote.dart';

import '../util.dart';
import 'ChordComponent.dart';
import 'ChordDescriptor.dart';
import 'key.dart';

///  A chord with a scale note and an optional chord descriptor and tension.
class ScaleChord implements Comparable<ScaleChord>
{
  ScaleChord(this._scaleNote, ChordDescriptor chordDescriptor)
      : _chordDescriptor = chordDescriptor.deAlias();

  ScaleChord.fromScaleNoteEnum(ScaleNoteEnum scaleNoteEnum)
      : _scaleNote = ScaleNote.get(scaleNoteEnum),
        _chordDescriptor = ChordDescriptor.defaultChordDescriptor().deAlias();

  ScaleChord.fromScaleNoteEnumAndChordDescriptor(
      ScaleNoteEnum scaleNoteEnum, ChordDescriptor chordDescriptor)
      : _scaleNote = ScaleNote.get(scaleNoteEnum),
        _chordDescriptor = chordDescriptor.deAlias();

  ScaleChord.fromScaleNote(this._scaleNote)
      : _chordDescriptor = ChordDescriptor.defaultChordDescriptor().deAlias();

  static ScaleChord parseString(String s) {
    return parse(new MarkedString(s));
  }

  static ScaleChord parse(MarkedString markedString) {
    if (markedString == null || markedString.isEmpty())
      throw new ArgumentError("no data to parse");

    ScaleNote retScaleNote = ScaleNote.parse(markedString);
    if (retScaleNote == ScaleNote.get(ScaleNoteEnum.X)) {
      return new ScaleChord(
          retScaleNote, ChordDescriptor.major); //  by convention only
    }

    ChordDescriptor retChordDescriptor = ChordDescriptor.parse(markedString);
    return new ScaleChord(retScaleNote, retChordDescriptor);
  }

  ScaleChord transpose(Key key, int halfSteps) {
    return new ScaleChord(scaleNote.transpose(key, halfSteps), chordDescriptor);
  }

//public final ScaleNote getScaleN//public final ScaleChord transpose(Key key, int halfSteps) {
//return new ScaleChord(scaleNote.transpose(key, halfSteps), chordDescriptor);
//}

  ScaleChord getAlias() {
    ScaleNote alias = _scaleNote.alias;
    if (alias == null) return null;
    return new ScaleChord(alias, _chordDescriptor);
  }

  Set<ChordComponent> getChordComponents() {
    return chordDescriptor.chordComponents;
  }

  bool contains(ChordComponent chordComponent) {
    return chordDescriptor.chordComponents.contains(chordComponent);
  }

  bool isEasyGuitarChord() {
    return _getEasyGuitarChords().contains(this);
  }

  @override
  String toString() {
    return scaleNote.toString() +
        (chordDescriptor != null ? chordDescriptor.shortName : "");
  }

  ///**
// * Compares this object with the specified object for order.  Returns a
// * negative integer, zero, or a positive integer as this object is less
// * than, equal to, or greater than the specified object.
// *
// * @param o the object to be compared.
// * @return a negative integer, zero, or a positive integer as this object
// * is less than, equal to, or greater than the specified object.
// * @throws NullPointerException if the specified object is null
// * @throws ClassCastException   if the specified object's type prevents it
// *                              from being compared to this object.
// */
  @override
  int compareTo(ScaleChord o) {
    int ret = scaleNote.compareTo(o.scaleNote);
    if (ret != 0) return ret;
    ret = chordDescriptor.compareTo(o.chordDescriptor);
    if (ret != 0) return ret;
    return 0;
  }

  Set<ScaleChord> _easyGuitarChords;

  Set<ScaleChord> _getEasyGuitarChords() {
    if (_easyGuitarChords == null) {
      _easyGuitarChords = Set<ScaleChord>();
      _easyGuitarChords.add(ScaleChord.parseString("C"));
      _easyGuitarChords.add(ScaleChord.parseString("A"));
      _easyGuitarChords.add(ScaleChord.parseString("G"));
      _easyGuitarChords.add(ScaleChord.parseString("E"));
      _easyGuitarChords.add(ScaleChord.parseString("D"));
      _easyGuitarChords.add(ScaleChord.parseString("Am"));
      _easyGuitarChords.add(ScaleChord.parseString("Em"));
      _easyGuitarChords.add(ScaleChord.parseString("Dm"));
    }
    return _easyGuitarChords;
  }

//
//
  ScaleNote get scaleNote => _scaleNote;
  final ScaleNote _scaleNote;

  ChordDescriptor get chordDescriptor => _chordDescriptor;
  final ChordDescriptor _chordDescriptor;
}
