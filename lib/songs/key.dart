import 'package:bsteele_music_flutter/songs/scaleChord.dart';
import 'package:bsteele_music_flutter/songs/scaleNote.dart';

import '../util.dart';
import 'ChordDescriptor.dart';
import 'MusicConstants.dart';

enum KeyEnum { Gb, Db, Ab, Eb, Bb, F, C, G, D, A, E, B, Fs }

///
// Representation of the song key used generate the expression of the proper scales.
// <p>Six flats and six sharps are labeled differently but are otherwise the same key.
// Seven flats and seven sharps are not included.</p>
class Key {
  Key._(this._keyEnum, this._keyValue, this._halfStep)
      : _name = _keyEnumToString(_keyEnum),
        _keyScaleNote = ScaleNote.valueOf(_keyEnumToString(_keyEnum));

  static String _keyEnumToString(KeyEnum ke) {
    return ke.toString().split('.').last;
  }

  static Map<KeyEnum, Key> _keys;
  static List _initialization = [
    [KeyEnum.Gb, -6, 9],
    [KeyEnum.Db, -5, 4],
    [KeyEnum.Ab, -4, 11],
    [KeyEnum.Eb, -3, 6],
    [KeyEnum.Bb, -2, 1],
    [KeyEnum.F, -1, 8],
    [KeyEnum.C, 0, 3],
    [KeyEnum.G, 1, 10],
    [KeyEnum.D, 2, 5],
    [KeyEnum.A, 3, 0],
    [KeyEnum.E, 4, 7],
    [KeyEnum.B, 5, 2],
    [KeyEnum.Fs, 6, 9]
  ];
  static Map<String, KeyEnum> _keyEnums;

  static Map<KeyEnum, Key> _getKeys() {
    if (_keys == null) {
      _keys = Map<KeyEnum, Key>.identity();
      for (var init in _initialization) {
        KeyEnum keInit = init[0];
        _keys[keInit] = Key._(keInit, init[1], init[2]);
      }

      //  majorDiatonics needs majorScale which is initialized after the constructors
      for (Key key in _keys.values) {
        key._majorDiatonics = List<ScaleChord>();
        for (int i = 0; i < MusicConstants.notesPerScale; i++) {
          key._majorDiatonics.add(new ScaleChord(key.getMajorScaleByNote(i),
              MusicConstants.getMajorDiatonicChordModifier(i)));
        }

        key._minorDiatonics = new List<ScaleChord>();
        for (int i = 0; i < MusicConstants.notesPerScale; i++) {
          key._minorDiatonics.add(new ScaleChord(key.getMinorScaleByNote(i),
              MusicConstants.getMinorDiatonicChordModifier(i)));
        }
      }

      for (Key key in _keys.values) {
        key._keyMinorScaleNote = key.getMajorDiatonicByDegree(6 - 1).scaleNote;
      }
    }

    return _keys;
  }

  static Key get(KeyEnum ke) {
    return _getKeys()[ke];
  }

  static List<Key> get values => _getKeys().values;

  static KeyEnum _getKeyEnum(String s) {
    //  lazy eval
    if (_keyEnums == null) {
      _keyEnums = Map<String, KeyEnum>.identity();
      for (KeyEnum ke in KeyEnum.values) {
        _keyEnums[_keyEnumToString(ke)] = ke;
      }
    }
    return _keyEnums[s];
  }

  static Key parseString(String s) {
    s = s.replaceAll("♭", "b").replaceAll("[♯#]", "s");
    KeyEnum keyEnum = _getKeyEnum(s);
    return get(keyEnum);
  }

  /**
   * Return the next key that is one half step higher.
   * Of course the keys are cyclic in their relationship.
   *
   * @return the next key
   */
  Key nextKeyByHalfStep() {
    return keysByHalfStep[Util.mod(_halfStep + 1, keysByHalfStep.length)];
  }

  Key nextKeyByHalfSteps(int step) {
    return keysByHalfStep[Util.mod(_halfStep + step, keysByHalfStep.length)];
  }

  Key nextKeyByFifth() {
    return keysByHalfStep[Util.mod(_halfStep + 7, keysByHalfStep.length)];
  }

  /**
   * Return the next key that is one half step lower.
   * Of course the keys are cyclic in their relationship.
   *
   * @return the next key down
   */
  Key previousKeyByHalfStep() {
    return keysByHalfStep[Util.mod(_halfStep - 1, keysByHalfStep.length)];
  }

  Key previousKeyByFifth() {
    return keysByHalfStep[Util.mod(_halfStep - 7, keysByHalfStep.length)];
  }

  /**
   * Transpose the given scale note by the requested offset.
   *
   * @param scaleNote the scale note to be transcribed
   * @param offset    the offset for the transcription, typically between -6 and +6
   * @return the scale note the key that matches the transposition requested
   */
  ScaleNote transpose(ScaleNote scaleNote, int offset) {
    return getScaleNoteByHalfStep(scaleNote.halfStep + offset);
  }

  /**
   * Return an integer value that represents the key.
   *
   * @return an integer value that represents the key
   */
  int getKeyValue() {
    return _keyValue;
  }

  /**
   * Return the scale note of the key, i.e. the musician's label for the key.
   *
   * @return the scale note of the key
   */
  ScaleNote getKeyScaleNote() {
    return _keyScaleNote;
  }

  ScaleNote getKeyMinorScaleNote() {
    return _keyMinorScaleNote;
  }

  /**
   * Return an integer value that represents the key's number of half steps from A.
   *
   * @return the count of half steps from A
   */
  int getHalfStep() {
    return _keyScaleNote.halfStep;
  }

  /**
   * Return the key represented by the given integer value.
   *
   * @param keyValue the given integer value
   * @return the key
   */
  static Key getKeyByValue(int keyValue) {
    for (Key key in _getKeys().values)
      if (key._keyValue == keyValue) return key;
    return get(KeyEnum.C); //  not found, so use the default, expected to be C
  }

  static Key getKeyByHalfStep(int halfStep) {
    halfStep = Util.mod(halfStep, MusicConstants.halfStepsPerOctave);
    for (Key key in _getKeys().values)
      if (key._halfStep == halfStep) return key;
    return get(KeyEnum.C); //  default, expected to be C
  }

  Key getMinorKey() {
// the key's tonic
    return getKeyByHalfStep(getHalfStep() + majorScale[6 - 1]);
  }

  /**
   * Return a representation of the key in HTML.
   *
   * @return the HTML
   */
  String toHtml() {
    return _keyScaleNote.toHtml();
  }

  /**
   * Guess the key from the collection of scale notes in a given song.
   *
   * @param scaleChords the scale chords to guess from
   * @return the roughly calculated key of the given scale notes.
   */
  static Key guessKey(List<ScaleChord> scaleChords) {
    Key ret = getDefault(); //  default answer

//  minimize the chord variations and keep a count of the scale note use
    Map<ScaleNote, int> useMap = Map<ScaleNote, int>.identity();
    for (ScaleChord scaleChord in scaleChords) {
//  minimize the variation by using only the scale note
      ScaleNote scaleNote = scaleChord.scaleNote;

//  count the uses
//  fixme: account for song section repeats
      int count = useMap[scaleNote];
      useMap[scaleNote] = ((count == null) ? 1 : count + 1);
    }

//  find the key with the longest greatest parse to the major chord
    int maxScore = 0;
    int minKeyValue = 2 ^ 63 - 1;

//  find the key with the greatest parse to it's diatonic chords
    {
      int count;
      ScaleChord diatonic;
      ScaleNote diatonicScaleNote;
      for (Key key in _getKeys().values) {
//  score by weighted uses of the scale chords
        int score = 0;
        for (int i = 0; i < key._majorDiatonics.length; i++) {
          diatonic = key.getMajorDiatonicByDegree(i);
          diatonicScaleNote = diatonic.scaleNote;
          if ((count = useMap[diatonicScaleNote]) != null)
            score += count * guessWeights[i];
          else {
            if ((diatonic = diatonic.getAlias()) != null) {
              diatonicScaleNote = diatonic.scaleNote;
              if (diatonic != null &&
                  (count = useMap[diatonicScaleNote]) != null)
                score += count * guessWeights[i];
            }
          }
        }

//  find the max score with the minimum key value
        if (score > maxScore ||
            (score == maxScore && key._keyValue.abs() < minKeyValue)) {
          ret = key;
          maxScore = score;
          minKeyValue = key._keyValue.abs();
        }
      }
    }
    //GWT.log("guess: " + ret.toString() + ": score: " + maxScore);
    return ret;
  }

  /**
   * Return the requested diatonic chord by degree.
   * Counts from zero. For example, 0 represents the I chord, 3 represents the IV chord.
   *
   * @param note diatonic note/chord count
   * @return the diatonic scale chord
   */
  ScaleChord getMajorDiatonicByDegree(int note) {
    note = Util.mod(note, _majorDiatonics.length);
    return _majorDiatonics[note];
  }

  ScaleChord getMajorScaleChord() {
    return _majorDiatonics[0];
  }

  ScaleChord getMinorDiatonicByDegree(int note) {
    note = Util.mod(note, _minorDiatonics.length);
    return _minorDiatonics[note];
  }

  ScaleChord getMinorScaleChord() {
    return _minorDiatonics[0];
  }

  bool isDiatonic(ScaleChord scaleChord) {
    return _majorDiatonics.contains(scaleChord);
  }

  ScaleNote getMajorScaleByNote(int note) {
    note = Util.mod(note, MusicConstants.notesPerScale);
    return getKeyScaleNoteByHalfStep(majorScale[note]);
  }

  ScaleNote getMinorScaleByNote(int note) {
    return getMajorScaleByNote(note + (6 - 1));
  }

  /**
   * Counts from zero.
   *
   * @param halfStep the half step offset count
   * @return the scale note at the offset
   */
  ScaleNote getKeyScaleNoteByHalfStep(int halfStep) {
    halfStep += _keyValue * halfStepsToFifth + halfStepsFromCtoA;
    return getScaleNoteByHalfStep(halfStep);
  }

  ScaleNote getScaleNoteByHalfStep(int halfSteps) {
    halfSteps = Util.mod(halfSteps, MusicConstants.halfStepsPerOctave);
    ScaleNote ret = (_keyValue >= 0)
        ? ScaleNote.getSharpByHalfStep(halfSteps)
        : ScaleNote.getFlatByHalfStep(halfSteps);

//  deal with exceptions at +-6
    if (_keyValue == 6 && ret == ScaleNote.get(ScaleNoteEnum.F))
      return ScaleNote.get(ScaleNoteEnum.Es);
    else if (_keyValue == -6 && ret == ScaleNote.get(ScaleNoteEnum.B))
      return ScaleNote.get(ScaleNoteEnum.Cb);
    return ret;
  }

  static Key getDefault() {
    return get(KeyEnum.C);
  }

  String sharpsFlatsToString() {
    if (_keyValue < 0)
      return _keyValue.abs().toString() + MusicConstants.flatChar;
    if (_keyValue > 0) return _keyValue.toString() + MusicConstants.sharpChar;
    return "";
  }

  bool isSharp() {
    return _keyValue >= 0;
  }

  /**
   * Returns the name of this enum constant in a user friendly format,
   * i.e. as UTF-8
   *
   * @return the name of this enum constant
   */
  @override
  String toString() {
    return _keyScaleNote.toString();
  }

  //                                   1  2  3  4  5  6  7
  //                                   0  1  2  3  4  5  6
  static final List majorScale = <int>[0, 2, 4, 5, 7, 9, 11];

// static final int minorScale[] = {0, 2, 3, 5, 7, 8, 10};
  static final List diatonic7ChordModifiers = <ChordDescriptor>[
    ChordDescriptor.major, //  0 + 1 = 1
    ChordDescriptor.minor, //  1 + 1 = 2
    ChordDescriptor.minor, //  2 + 1 = 3
    ChordDescriptor.major, //  3 + 1 = 4
    ChordDescriptor.dominant7, //  4 + 1 = 5
    ChordDescriptor.minor, //  5 + 1 = 6
    ChordDescriptor.minor7b5, //  6 + 1 = 7
  ];
  static List keysByHalfStep = <KeyEnum>[
    KeyEnum.A,
    KeyEnum.Bb,
    KeyEnum.B,
    KeyEnum.C,
    KeyEnum.Db,
    KeyEnum.D,
    KeyEnum.Eb,
    KeyEnum.E,
    KeyEnum.F,
    KeyEnum.Gb,
    KeyEnum.G,
    KeyEnum.Ab
  ];

  //                                     1  2  3  4  5  6  7
  static final List guessWeights = <int>[9, 1, 1, 4, 4, 1, 3];
  static final int halfStepsToFifth = 7;
  static final int halfStepsFromCtoA = 3;

  KeyEnum get keyEnum => _keyEnum;
  final KeyEnum _keyEnum;

  String get name => _name;
  final String _name;
  final int _keyValue;
  final int _halfStep;
  final ScaleNote _keyScaleNote;

  //  have to be set after initialization of all keys
  ScaleNote _keyMinorScaleNote;
  List<ScaleChord> _majorDiatonics;
  List<ScaleChord> _minorDiatonics;
}

/*                     1  2  3  4  5  6  7                 I    II   III  IV   V    VI   VII               0  1  2  3  4  5  6  7  8  9  10 11
-6 Gb (G♭)		scale: G♭ A♭ B♭ C♭ D♭ E♭ F  	majorDiatonics: G♭   A♭m  B♭m  C♭   D♭7  E♭m  Fm7b5 	all notes: A  B♭ C♭ C  D♭ D  E♭ E  F  G♭ G  A♭
-5 Db (D♭)		scale: D♭ E♭ F  G♭ A♭ B♭ C  	majorDiatonics: D♭   E♭m  Fm   G♭   A♭7  B♭m  Cm7b5 	all notes: A  B♭ B  C  D♭ D  E♭ E  F  G♭ G  A♭
-4 Ab (A♭)		scale: A♭ B♭ C  D♭ E♭ F  G  	majorDiatonics: A♭   B♭m  Cm   D♭   E♭7  Fm   Gm7b5 	all notes: A  B♭ B  C  D♭ D  E♭ E  F  G♭ G  A♭
-3 Eb (E♭)		scale: E♭ F  G  A♭ B♭ C  D  	majorDiatonics: E♭   Fm   Gm   A♭   B♭7  Cm   Dm7b5 	all notes: A  B♭ B  C  D♭ D  E♭ E  F  G♭ G  A♭
-2 Bb (B♭)		scale: B♭ C  D  E♭ F  G  A  	majorDiatonics: B♭   Cm   Dm   E♭   F7   Gm   Am7b5 	all notes: A  B♭ B  C  D♭ D  E♭ E  F  G♭ G  A♭
-1 F (F)		scale: F  G  A  B♭ C  D  E  	majorDiatonics: F    Gm   Am   B♭   C7   Dm   Em7b5 	all notes: A  B♭ B  C  D♭ D  E♭ E  F  G♭ G  A♭
 0 C (C)		scale: C  D  E  F  G  A  B  	majorDiatonics: C    Dm   Em   F    G7   Am   Bm7b5 	all notes: A  A♯ B  C  C♯ D  D♯ E  F  F♯ G  G♯
 1 G (G)		scale: G  A  B  C  D  E  F♯ 	majorDiatonics: G    Am   Bm   C    D7   Em   F♯m7b5 	all notes: A  A♯ B  C  C♯ D  D♯ E  F  F♯ G  G♯
 2 D (D)		scale: D  E  F♯ G  A  B  C♯ 	majorDiatonics: D    Em   F♯m  G    A7   Bm   C♯m7b5 	all notes: A  A♯ B  C  C♯ D  D♯ E  F  F♯ G  G♯
 3 A (A)		scale: A  B  C♯ D  E  F♯ G♯ 	majorDiatonics: A    Bm   C♯m  D    E7   F♯m  G♯m7b5 	all notes: A  A♯ B  C  C♯ D  D♯ E  F  F♯ G  G♯
 4 E (E)		scale: E  F♯ G♯ A  B  C♯ D♯ 	majorDiatonics: E    F♯m  G♯m  A    B7   C♯m  D♯m7b5 	all notes: A  A♯ B  C  C♯ D  D♯ E  F  F♯ G  G♯
 5 B (B)		scale: B  C♯ D♯ E  F♯ G♯ A♯ 	majorDiatonics: B    C♯m  D♯m  E    F♯7  G♯m  A♯m7b5 	all notes: A  A♯ B  C  C♯ D  D♯ E  F  F♯ G  G♯
 6 Fs (F♯)		scale: F♯ G♯ A♯ B  C♯ D♯ E♯ 	majorDiatonics: F♯   G♯m  A♯m  B    C♯7  D♯m  E♯m7b5 	all notes: A  A♯ B  C  C♯ D  D♯ E  E♯ F♯ G  G♯









 */
