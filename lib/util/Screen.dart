import 'dart:math';

import 'package:flutter/material.dart';

class ScreenInfo {
  ScreenInfo(BuildContext context)
      : _mediaWidth = MediaQuery.of(context).size.width {
    _isTooNarrow = _mediaWidth <= 800;
    _titleScaleFactor = max(1, _mediaWidth / 800);
    _artistScaleFactor = 0.75 * _titleScaleFactor;
  }

  double get mediaWidth => _mediaWidth;
  final double _mediaWidth;

  bool get isTooNarrow => _isTooNarrow;
  bool _isTooNarrow;

  double get titleScaleFactor => _titleScaleFactor;
  double _titleScaleFactor;

  double get artistScaleFactor => _artistScaleFactor;
  double _artistScaleFactor;
}
