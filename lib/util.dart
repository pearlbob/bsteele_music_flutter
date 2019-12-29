import 'dart:core';

import 'dart:math';

class Util {
  /// Always return a positive modulus
  static int mod(int n, int modulus) {
    n = n % modulus;
    if (n < 0) n += modulus;
    return n;
  }

  /// capitalize the first character
  static String firstToUpper(String s) => s[0].toUpperCase() + s.substring(1);
}

/// A String with a marked location to be used in parsing.
/// The current location is remembered.
/// Characters can be consumed by asking for the next character.
/// Locations in the string can be marked and returned to.
/// Typically this happens on a failed lookahead parse effort.
class MarkedString {
  MarkedString(this._string);

  /// mark the current location
  int mark() {
    _markIndex = _index;
    return _markIndex;
  }

  /// set the mark to the given location
  void setToMark(int m) {
    _markIndex = m;
    resetToMark();
  }

  /// Return the current mark
  int getMark() {
    return _markIndex;
  }

  /// Return the current location to the mark
  void resetToMark() {
    _index = _markIndex;
  }

  void resetTo(int i) {
    _index = i;
  }

  bool isEmpty() {
    return _string.length <= 0 || _index >= _string.length;
  }

  String getNextChar() {
    return _string[_index++];
  }

  int codeUnitAt(int index) {
    return _string[_index].codeUnitAt(0);
  }

  int firstUnit() {
    return _string[_index].codeUnitAt(0);
  }

  String first() {
    return _string[_index].substring(0, 1);
  }

  int indexOf(String s) {
    return _string.indexOf(s, _index);
  }

  String remainingStringLimited(int limitLength) {
    int i = _index + limitLength;
    i = min(i, _string.length);
    return _string.substring(_index, i);
  }

  ///  return character at location relative to current _index
  String charAt(int i) {
    return _string[_index + i];
  }

  void consume(int n) {
    _index += n;
  }

  int available() {
    int ret = _string.length - _index;
    return (ret < 0 ? 0 : ret);
  }

  @override
  String toString() {
    return _string.substring(_index);
  }

  int _index = 0;
  int _markIndex = 0;
  final String _string;
}
