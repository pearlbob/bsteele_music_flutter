import 'dart:math';

import 'package:flutter/material.dart';

class ScreenInfo {
  ScreenInfo(BuildContext context)
      : _widthInLogicalPixels = MediaQuery.of(context).size.width,
        _heightInLogicalPixels = MediaQuery.of(context).size.height {
    _isTooNarrow = _widthInLogicalPixels < minLogicalPixels; //  logical pixels
    _titleScaleFactor = max(1, _widthInLogicalPixels / (2 * minLogicalPixels));
    _artistScaleFactor = 0.75 * _titleScaleFactor;
  }

  double get widthInLogicalPixels => _widthInLogicalPixels;
  final double _widthInLogicalPixels;

  double get heightInLogicalPixels => _heightInLogicalPixels;
  final double _heightInLogicalPixels;

  bool get isTooNarrow => _isTooNarrow;
  bool _isTooNarrow;

  double get titleScaleFactor => _titleScaleFactor;
  double _titleScaleFactor;

  double get artistScaleFactor => _artistScaleFactor;
  double _artistScaleFactor;

  static const double minLogicalPixels = 725; //  just enough for a nexus 3 XL to be "big" when horizontal
}
