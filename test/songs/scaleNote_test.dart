import 'package:bsteele_music_flutter/songs/scaleNote.dart';
import "package:test/test.dart";

void main() {
  test("Scale note", () {
    {
      ScaleNote sn = ScaleNote.get(ScaleNoteEnum.A);
      expect(0, sn.halfStep);
      sn = ScaleNote.get(ScaleNoteEnum.X);
      expect(0, sn.halfStep);

      RegExp ends_in_b = new RegExp(r"b$");
      RegExp ends_in_s = new RegExp(r"s$");
      for (final e in ScaleNoteEnum.values) {
        sn = ScaleNote.get(e);
//        print(  e.toString() + ": " + ends_in_b.hasMatch(e.toString()).toString());
        expect(ends_in_b.hasMatch(e.toString()), sn.isFlat);
        expect(ends_in_s.hasMatch(e.toString()), sn.isSharp);
        if (e != ScaleNoteEnum.X) {
          expect(sn.isFlat, !(sn.isSharp || sn.isNatural));
          expect(false, sn.isSilent);
        } else {
          expect(true, sn.isSilent);
          expect(false, sn.isFlat);
          expect(false, sn.isSharp);
          expect(false, sn.isNatural);
        }
      }
    }

    for (int i = 0; i < ScaleNote.halfStepsPerOctave * 3; i++) {
      ScaleNote sn = ScaleNote.getSharpByHalfStep(i);
      expect(false, sn.isFlat);
      expect(false, sn.isSilent);
    }
    for (int i = -3; i < ScaleNote.halfStepsPerOctave * 2; i++) {
      ScaleNote sn = ScaleNote.getFlatByHalfStep(i);
      expect(false, sn.isSharp);
      expect(false, sn.isSilent);
    }
  });
}
