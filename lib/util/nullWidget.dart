import 'package:flutter/cupertino.dart';

/// This should be replaced with the NullWidget class from pub.dev... but it's not nullable safe!
@immutable
class NullWidget extends Text {
  static const NullWidget _singleton = NullWidget._internal();

  //  private constructor
  const NullWidget._internal() : super('');

  factory NullWidget() => _singleton;
}
