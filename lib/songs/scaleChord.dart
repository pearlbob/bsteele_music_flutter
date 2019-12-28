import 'package:bsteele_music_flutter/songs/scaleNote.dart';

import '../util.dart';
import 'ChordDescriptor.dart';

///  A chord with a scale note and an optional chord descriptor and tension.
class ScaleChord //implements Comparable<ScaleChord>
{
  ScaleChord(this._scaleNote, ChordDescriptor chordDescriptor)
      : _chordDescriptor = chordDescriptor.deAlias();

  ScaleChord.fromScaleNote(ScaleNoteEnum scaleNoteEnum)
      : _scaleNote = ScaleNote.get(scaleNoteEnum),
        _chordDescriptor = ChordDescriptor.defaultChordDescriptor().deAlias();

  ScaleChord.fromScaleNoteAndChordDescriptor(
      ScaleNoteEnum scaleNoteEnum, ChordDescriptor chordDescriptor)
      : _scaleNote = ScaleNote.get(scaleNoteEnum),
        _chordDescriptor = chordDescriptor.deAlias();

//  public ScaleChord(@NotNull ScaleNote scaleNote) {
//    this(scaleNote, ChordDescriptor.major);
//  }

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

//public final ScaleChord transpose(Key key, int halfSteps) {
//return new ScaleChord(scaleNote.transpose(key, halfSteps), chordDescriptor);
//}
//
//public final ScaleNote getScaleNote() {
//return scaleNote;
//}
//
  ScaleChord getAlias() {
    ScaleNote alias = _scaleNote.alias;
    if (alias == null) return null;
    return new ScaleChord(alias, _chordDescriptor);
  }

//public final ChordDescriptor getChordDescriptor() {
//return chordDescriptor;
//}
//
//public final TreeSet<ChordComponent> getChordComponents() {
//return chordDescriptor.getChordComponents();
//}
//
//public final boolean contains(ChordComponent chordComponent) {
//return chordDescriptor.getChordComponents().contains(chordComponent);
//}
//
//public final boolean isEasyGuitarChord() {
//return easyGuitarChords.contains(this);
//}
//
  ///**
// * Indicates whether some other object is "equal to" this one.
// */
//@Override
//public boolean equals(Object obj) {
//  if (!(obj instanceof ScaleChord))
//    return false;
//  ScaleChord other = (ScaleChord) obj;
//  return scaleNote.equals(other.scaleNote)
//      && chordDescriptor.equals(other.chordDescriptor);
//}
//
  ///**
// * Returns a hash code value for the object. This method is
// * supported for the benefit of hash tables such as those provided by
// * {@link HashMap}.
// */
//@Override
//public int hashCode() {
//  int hash = 17;
//  hash = (71 * hash + Objects.hashCode(this.scaleNote)) % (1 << 31);
//  hash = (71 * hash + Objects.hashCode(this.chordDescriptor)) % (1 << 31);
//  return hash;
//}

@override
 String toString() {
  return scaleNote.toString()
      + (chordDescriptor != null ? chordDescriptor.shortName : "");
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
//@Override
//public int compareTo(ScaleChord o) {
//  int ret = scaleNote.compareTo(o.scaleNote);
//  if (ret != 0)
//    return ret;
//  ret = chordDescriptor.compareTo(o.chordDescriptor);
//  if (ret != 0)
//    return ret;
//  return 0;
//}
//
//private static final TreeSet<ScaleChord> easyGuitarChords = new TreeSet<ScaleChord>();
//
//
  ScaleNote get scaleNote => _scaleNote;
  final ScaleNote _scaleNote;

  ChordDescriptor get chordDescriptor => _chordDescriptor;
  final ChordDescriptor _chordDescriptor;

//static {
//try {
////C A G E D and Am Em Dm
//easyGuitarChords.add(ScaleChord.parse("C"));
//easyGuitarChords.add(ScaleChord.parse("A"));
//easyGuitarChords.add(ScaleChord.parse("G"));
//easyGuitarChords.add(ScaleChord.parse("E"));
//easyGuitarChords.add(ScaleChord.parse("D"));
//easyGuitarChords.add(ScaleChord.parse("Am"));
//easyGuitarChords.add(ScaleChord.parse("Em"));
//easyGuitarChords.add(ScaleChord.parse("Dm"));
//} catch (ParseException pex) {
//logger.info("parse exception should never happen: " + pex.getMessage());
//}
//}
}
