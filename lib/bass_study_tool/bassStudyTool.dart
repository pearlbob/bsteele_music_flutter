import 'dart:convert';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/chordDescriptor.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as musical_key;
import 'package:bsteeleMusicLib/songs/musicConstants.dart';
import 'package:bsteeleMusicLib/songs/pitch.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';

class BassStudyTool {
  static List<SheetNote>? parseJsonBsstVersion0_0(String s) {
    logger.v('parseJsonBsstVersion0_0: s.length=${s.length}');

    Map<String, dynamic> map = jsonDecode(s);

    String? version = map['version'];
    if (version == null) {
      logger.w('bsst file version missing!');
      return null;
    }
    List<SheetNote> sheetNotes = [];
    switch (version) {
      case '0.0':
        for (String key in map.keys) {
          logger.v('key: "$key"');
          switch (key) {
            case 'keyN':
            case 'beatsPerBar':
            case 'notesPerBar':
            case 'bpm':
            case 'isSwing8':
            case 'hiHatRhythm':
            case 'swingType':
              logger.v('   $key: "${map[key]}"');
              break;
            case 'warning':
            case 'version':
              break; //  ignore
            case 'sheetNotes':
              var jsonSheetNotes = map[key];
              if (jsonSheetNotes is List) {
                int i = 0;
                for (var item in jsonSheetNotes) {
                  logger.v('${i++}:');
                  if (item is Map) {
                    //  defaults only
                    bool isNote = true;
                    musical_key.Key key = musical_key.Key.byHalfStep();
                    int string = 0; //  bass guitar, 0 = E string... yes the numbering is backwards
                    int fret = 0;
                    ChordDescriptor chordDescriptor = ChordDescriptor.major;
                    String lyrics;
                    bool tied = false;
                    _NoteDuration _noteDuration = _noteDurations[0];

                    //  process these first
                    for (var attr in item.keys) {
                      switch (attr) {
                        case 'isNote':
                          isNote = item[attr];
                          logger.v('    $attr: ${isNote.toString()}');
                          break;
                        case 'chordN': //  encoded
                          int chordN = item[attr];
                          key = musical_key.Key.byHalfStep(offset: chordN + 7);
                          logger.v('    $attr: ${chordN.toString()} = $key');
                          break;
                      }
                    }

                    for (var attr in item.keys) {
                      switch (attr) {
                        case 'isNote':
                        case 'chordN':
                          break;
                        case 'string': //  which bass string!
                          string = item[attr];
                          logger.v('    $attr: ${string.toString()}');
                          break;
                        case 'fret':
                          fret = item[attr];
                          logger.v('    $attr: ${fret.toString()}');
                          break;
                        case 'noteDuration': //  encoded
                          _noteDuration = (isNote ? _noteDurations[item[attr]] : _restDurations[item[attr]]);
                          logger.v('    $attr: ${_noteDuration.toString()}');
                          break;
                        case 'chordModifier':
                          String chordModifier = item[attr];
                          logger.v('    $attr: $chordModifier');
                          break;
                        case 'minorMajor':
                          String minorMajor = item[attr];
                          switch (minorMajor) {
                            case 'major': // major
                              chordDescriptor = ChordDescriptor.major;
                              break;
                            case 'major7': // major 7
                              chordDescriptor = ChordDescriptor.major7;
                              break;
                            case 'pentatonic': // pentatonic
                              chordDescriptor = ChordDescriptor.major;
                              break;
                            case 'majorScale': // major scale
                              chordDescriptor = ChordDescriptor.major;
                              break;
                            case 'minor': // minor
                              chordDescriptor = ChordDescriptor.minor;
                              break;
                            case 'minor7': // minor 7
                              chordDescriptor = ChordDescriptor.minor7;
                              break;
                            case 'minorPentatonic': // minor Pentatonic
                              chordDescriptor = ChordDescriptor.minor;
                              break;
                            case 'minorScale': // minor scale
                              chordDescriptor = ChordDescriptor.minor;
                              break;
                            case 'dominant': // dominant 7
                              chordDescriptor = ChordDescriptor.dominant7;
                              break;
                            case 'power5': // power 5
                              chordDescriptor = ChordDescriptor.power5;
                              break;
                            case 'augmented': // augmented (#5)
                              chordDescriptor = ChordDescriptor.augmented;
                              break;
                            case 'augmented7': // augmented 7 (#5)
                              chordDescriptor = ChordDescriptor.augmented7;
                              break;
                            case 'blues': // minor blues
                              chordDescriptor = ChordDescriptor.minor; //  !!!!!!!!!!!!!!!!!!!!
                              break;
                            case 'jazz7': // jazz 7
                              chordDescriptor = ChordDescriptor.jazz7b9;
                              break;
                            case 'mixolydianScale': // mixolydian scale
                              chordDescriptor = ChordDescriptor.dominant7;
                              break;
                            case 'diminished': // diminished
                              chordDescriptor = ChordDescriptor.diminished;
                              break;
                            case 'diminished7': // diminished 7
                              chordDescriptor = ChordDescriptor.diminished7;
                              break;
                            case 'boogiewoogie': // boogie woogie pattern
                              chordDescriptor = ChordDescriptor.dominant7; //  !!!!!!!!!!!!!!!!!!!!
                              break;
                            case 'r5': // R 5 pattern
                              chordDescriptor = ChordDescriptor.power5;
                              break;
                            case 'r56': // R 5 6 pattern
                              chordDescriptor = ChordDescriptor.dominant7; //  !!!!!!!!!!!!!!!!!!!!
                              break;
                            case 'r5b7': // R 5 &#x266d;7 pattern
                              chordDescriptor = ChordDescriptor.dominant7; //  !!!!!!!!!!!!!!!!!!!!
                              break;
                            case 'mdi': // major diatonic I   (maj7)
                              chordDescriptor = ChordDescriptor.major7;
                              break;
                            case 'mdii': // major diatonic ii  (m7)
                              chordDescriptor = ChordDescriptor.minor7; //  !!!!!!!!!!!!!!!!!!!!
                              break;
                            case 'mdiii': // major diatonic iii (m7)
                              chordDescriptor = ChordDescriptor.minor7; //  !!!!!!!!!!!!!!!!!!!!
                              break;
                            case 'mdiv': // major diatonic IV  (maj7)
                              chordDescriptor = ChordDescriptor.major7;
                              break;
                            case 'mdv': // major diatonic V   (dom7)
                              chordDescriptor = ChordDescriptor.dominant7;
                              break;
                            case 'mdvi': // major diatonic vi  (m7)
                              chordDescriptor = ChordDescriptor.minor7;
                              break;
                            case 'mdvii': // major diatonic vii (m7b5)
                              chordDescriptor = ChordDescriptor.minor7b5;
                              break;
                            default:
                              logger.w('unknown ChordDescriptor: "$attr" = "${item[attr].toString()}"');
                              break;
                          }

                          logger.v('    $attr: ${minorMajor.toString()}');
                          break;
                        case 'minorMajorSelectIndex':
                          //  nearly no value
                          int minorMajorSelectIndex = item[attr];
                          logger.v('    $attr: ${minorMajorSelectIndex.toString()}');
                          break;
                        case 'scaleN':
                          //  nearly no value
                          int scaleN = item[attr];
                          logger.v('    $attr: ${scaleN.toString()}');
                          break;
                        case 'lyrics':
                          lyrics = item[attr];
                          logger.v('    $attr: "$lyrics"');
                          break;
                        case 'tied':
                          tied = item[attr];
                          logger.v('    $attr: ${tied.toString()}');
                          break;
                        default:
                          logger.w('unknown attribute: "$attr" = "${item[attr].toString()}"');
                          break;
                      }
                    }

                    if (isNote) {
                      Pitch? pitch = Pitch.get(PitchEnum.E1).offsetByHalfSteps(string * 5 + fret);
                      logger.v('    Pitch: $pitch  (string: $string, fret: $fret), $chordDescriptor');
                      if (pitch != null) {
                        SheetNote sn = SheetNote.note(Clef.bass8vb, pitch, _noteDuration.duration,
                            // lyrics: lyrics,
                            tied: tied, );
                        sheetNotes.add(sn);
                      }
                    } else {
                      //  rest
                      SheetNote sn = SheetNote.rest(Clef.bass8vb,
                        _noteDuration.duration,
                      );
                      sheetNotes.add(sn);
                    }
                  } else {
                    logger.w('sheetNotes item wrong type: ${item.runtimeType.toString()}: ${item.toString()}');
                  }
                }
              } else {
                logger.w('sheetNotes wrong type: ${jsonSheetNotes.runtimeType.toString()}');
              }
              break;
            default:
              logger.w('unknown bsst file key: $key = "${map[key].toString()}"');
              break;
          }
        }
        break;
      default:
        logger.w('unknown bsst file version: $version');
        return null;
    }

//  if (Logger.level.index <= Level.verbose.index) {
//    for (SheetNote sn in sheetNotes) {
//      logger.v(sn.toString());
//    }
//  }

    return sheetNotes;
  }
}

class _NoteDuration {
  _NoteDuration(this.duration, this.dotted, this.name);

  @override
  String toString() {
    return '${duration.toStringAsFixed(4)} ${dotted ? ' dotted' : ''} $name';
  }

  String name;
  double duration;
  bool dotted = false;
}

/// map from json bsst values to note durations
List<_NoteDuration> _noteDurations = [
  //  un-dotted
  _NoteDuration(1, false, 'whole'),
  _NoteDuration(1 / 2, false, 'half'),
  _NoteDuration(1 / 4, false, 'quarter'),
  _NoteDuration(1 / 8, false, 'eighth'),
  _NoteDuration(1 / 16, false, 'sixteenth'),
  //  dotted
  _NoteDuration(1, true, 'whole'), //  placeholder
  _NoteDuration(3 / 4, true, 'half'),
  _NoteDuration(3 / 8, true, 'quarter'),
  _NoteDuration(3 / 16, true, 'eighth'),
  _NoteDuration(3 / 32, true, 'sixteenth'),
];

/// map from json bsst values to rest durations
List<_NoteDuration> _restDurations = [
  _NoteDuration(1, false, 'whole rest'),
  _NoteDuration(1 / 2, false, 'half rest'),
  _NoteDuration(1 / 4, false, 'quarter rest'),
  _NoteDuration(1 / 8, false, 'eighth rest'),
  _NoteDuration(1 / 16, false, 'sixteenth rest'),
];
