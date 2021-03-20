import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:flutter/material.dart';

class ScreenInfo {
  ScreenInfo(BuildContext context)
      : _widthInLogicalPixels = MediaQuery.of(context).size.width,
        _heightInLogicalPixels = MediaQuery.of(context).size.height,
        _isDefaultValue = false {
    _isTooNarrow = _widthInLogicalPixels < minLogicalPixels; //  logical pixels
    _titleScaleFactor = max(1, _widthInLogicalPixels / (1.5 * minLogicalPixels));
    _artistScaleFactor = 0.75 * _titleScaleFactor;
    logger.v('ScreenInfo: ($_widthInLogicalPixels, $_heightInLogicalPixels)'
        ', narrow: $_isTooNarrow, title: $_titleScaleFactor');
  }

  ScreenInfo.defaultValue()
      : _widthInLogicalPixels = 1024,
        _heightInLogicalPixels = 800,
        _isDefaultValue = true {
    _isTooNarrow = false; //  logical pixels
    _titleScaleFactor = 1;
    _artistScaleFactor = 0.75;
  }

  double get widthInLogicalPixels => _widthInLogicalPixels;
  final double _widthInLogicalPixels;

  double get heightInLogicalPixels => _heightInLogicalPixels;
  final double _heightInLogicalPixels;

  bool get isTooNarrow => _isTooNarrow;
  late bool _isTooNarrow;

  double get titleScaleFactor => _titleScaleFactor;
  late double _titleScaleFactor;

  double get artistScaleFactor => _artistScaleFactor;
  late double _artistScaleFactor;

  bool get isDefaultValue => _isDefaultValue;
  final bool _isDefaultValue;

  static const double minLogicalPixels = 725; //  just enough for a nexus 3 XL to be "big" when horizontal
}
