import 'package:bsteele_music_flutter/songs/scaleNote.dart';
import "package:test/test.dart";

void main() {
  test("Scale note sharps, flats and naturals", () {
    ScaleNote sn = ScaleNote.get(ScaleNoteEnum.A);
    expect(0, sn.halfStep);
    sn = ScaleNote.get(ScaleNoteEnum.X);
    expect(0, sn.halfStep);

    final RegExp endsInB = new RegExp(r"b$");
    final RegExp endsInS = new RegExp(r"s$");
    for (final e in ScaleNoteEnum.values) {
      sn = ScaleNote.get(e);
//        print(  e.toString() + ": " + endsInB.hasMatch(e.toString()).toString());
      expect(endsInB.hasMatch(e.toString()), sn.isFlat);
      expect(endsInS.hasMatch(e.toString()), sn.isSharp);
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
  });

  test ("get By HalfStep", ()
    {
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
    }
  );

}
