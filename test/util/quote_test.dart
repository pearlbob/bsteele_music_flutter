import 'package:bsteele_music_flutter/util.dart';
import "package:test/test.dart";

void main() {
  test("test quote", () {
    String s;
    String qs;

    expect(Util.quote(s), s);
    s = "";
    expect(Util.quote(s), s);
    s = " ";
    expect(Util.quote(s), '\'' + s + '\'');
    s = " nothing special, per se &nbsp;";
    expect(Util.quote(s), '\'' + s + '\'');
    s = " something special,\nhere;";
    qs = Util.quote(s);
    expect(qs, '\'' + s + '\'');
  });
}
