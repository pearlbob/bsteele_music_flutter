import 'dart:core';

import 'dart:math';

class Util {
  static int mod(int n, int modulus) {
    n = n % modulus;
    if (n < 0) n += modulus;
    return n;
  }
}

class MarkedString {
  MarkedString(String s) {
    _string = (s == null ? "" : s);
  }

  int mark() {
    _markIndex = _index;
    return _markIndex;
  }

  void setToMark(int m) {
    _markIndex = m;
    resetToMark();
  }

  int getMark() {
    return _markIndex;
  }

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
  String _string;
}
