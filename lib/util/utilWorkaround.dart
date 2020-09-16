import 'dart:core';

import 'dart:math';

import 'package:bsteele_music_flutter/util/utilStub.dart'
// ignore: uri_does_not_exist
if (dart.library.io) 'package:bsteele_music_flutter/util/utilLinux.dart'
// ignore: uri_does_not_exist
if (dart.library.html) 'package:bsteele_music_flutter/util/utilWeb.dart';

abstract class UtilWorkaround {
  /// add quotes to a string so it can be used as a dart constant
  static String quote(String s) {
    if (s == null) return null;
    if (s.length == 0) return "";
    s = s.replaceAll("'", "\'").replaceAll("\n", "\\n'\n'");
    return "'$s'";
  }

  /// capitalize the first character
  static String firstToUpper(String s) => s[0].toUpperCase() + s.substring(1);

  /// Workaround to implement functionality that is not generic across all platforms at this point.
  void writeFileContents(String fileName, String contents);

  /// factory constructor to return the correct implementation.
  factory UtilWorkaround() => getUtilWorkaround();
}

