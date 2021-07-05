import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/bass_study_tool/sheetNote.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';



void main() {
  Logger.level = Level.info;

  test('sheet display encode/decode', () {
    {
      HashSet<SheetDisplay> set = HashSet();
      set.add(SheetDisplay.chords);
      set.addAll([SheetDisplay.chords, SheetDisplay.lyrics]);
      var s = sheetDisplaySetEncode(set);
      logger.i('"$s"');
      var set2 = sheetDisplaySetDecode(s);
      logger.i('decode: $set2');
      expect(set.contains(SheetDisplay.chords), isTrue);
      expect(set.contains(SheetDisplay.lyrics), isTrue);
      expect(set.contains(SheetDisplay.bassNotes), isFalse);
      expect(set2, set);
      expect(set2.contains(SheetDisplay.chords), isTrue);
      expect(set2.contains(SheetDisplay.lyrics), isTrue);
      expect(set2.contains(SheetDisplay.bassNotes), isFalse);
    }

    {
      HashSet<SheetDisplay> set = HashSet();
      var s = sheetDisplaySetEncode(set);
      var set2 = sheetDisplaySetDecode(s);
      logger.i('decode: $set2');
      expect(set2.contains(SheetDisplay.bassNotes), isFalse);
    }
  });


}