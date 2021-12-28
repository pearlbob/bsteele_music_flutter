import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:flutter/material.dart';

/// Gather information on screen size and adapt to it
class ScreenInfo {
  ScreenInfo(BuildContext context) : _isDefaultValue = false {
    MediaQueryData mediaQueryData = MediaQuery.of(context);

    double devicePixelRatio = mediaQueryData.devicePixelRatio;
    _mediaWidth = mediaQueryData.size.width;
    _mediaHeight = mediaQueryData.size.height;

    _fontSize = 2 * appDefaultFontSize * min(2.25, max(1, _mediaWidth / minLogicalPixels));
    _isTooNarrow = _mediaWidth <= minLogicalPixels; //  logical pixels
    _isWayTooNarrow = _mediaWidth <= 400;
    _titleScaleFactor = 1.25 * max(1, _mediaWidth / minLogicalPixels);
    logger.d('ScreenInfo: ($_mediaWidth, $_mediaHeight)'
        ', narrow: $_isTooNarrow, title: $_titleScaleFactor');

    logger.d('devicePixelRatio: $devicePixelRatio,'
        ' ($_mediaWidth,$_mediaHeight)');
  }

  ScreenInfo.defaultValue()
      : _isDefaultValue = true,
        // place holders only:
        _mediaWidth = 1920,
        _mediaHeight = 1080 {
    _isTooNarrow = false; //  logical pixels
    _titleScaleFactor = 1;
    _fontSize = 16;
  }

  /// Computed optimal font size.
  double get fontSize => _fontSize;
  late double _fontSize;

  double get mediaWidth => _mediaWidth;
  late double _mediaWidth;

  double get mediaHeight => _mediaHeight;
  late double _mediaHeight;

  /// Indicate the screen is too narrow for a number of functions that require a wider screen.
  /// An example is the edit screen.
  bool get isTooNarrow => _isTooNarrow;
  late bool _isTooNarrow;

  /// try to compensate for a truly small screen
  bool get isWayTooNarrow => _isWayTooNarrow;
  late bool _isWayTooNarrow;

  double get titleScaleFactor => _titleScaleFactor;
  late double _titleScaleFactor;

  bool get isDefaultValue => _isDefaultValue;
  final bool _isDefaultValue;

  /// Minimum number of pixels for a "large" or "wide" screen
  static const double minLogicalPixels = 1024; //  just enough for a nexus 3 XL to be "big" when horizontal
}
