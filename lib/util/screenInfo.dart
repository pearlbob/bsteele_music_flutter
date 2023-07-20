import 'dart:math';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

//  diagnostic logging enables
const Level _screenInfoLogFontsize = Level.debug;

/// Gather information on screen size and adapt to it
class ScreenInfo {
  ScreenInfo(BuildContext context) : _isDefaultValue = false {
    refresh(context);
  }

  void refresh(BuildContext context) {
    MediaQueryData mediaQueryData = MediaQuery.of(context);

    double devicePixelRatio = mediaQueryData.devicePixelRatio;
    _mediaWidth = mediaQueryData.size.width;
    _mediaHeight = mediaQueryData.size.height;

    _fontSize = 2 * appDefaultFontSize * min(2.25, max(0.5, _mediaWidth / minLogicalPixels));
    _isTooNarrow = _mediaWidth <= minLogicalPixels; //  logical pixels
    _isWayTooNarrow = _mediaWidth <= 425;
    _titleScaleFactor = 1.25 * max(1, _mediaWidth / minLogicalPixels);
    logger.log(
        _screenInfoLogFontsize,
        'ScreenInfo: ($_mediaWidth, $_mediaHeight) => fontSize: $fontSize'
        ', narrow: $_isTooNarrow, title: $_titleScaleFactor');

    logger.log(
        _screenInfoLogFontsize,
        'devicePixelRatio: $devicePixelRatio,'
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

  @override
  String toString() {
    return 'ScreenInfo{_fontSize: $_fontSize, _mediaWidth: $_mediaWidth'
        ', _mediaHeight: $_mediaHeight, _isTooNarrow: $_isTooNarrow'
        ', _isWayTooNarrow: $_isWayTooNarrow, _titleScaleFactor: $_titleScaleFactor}';
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
