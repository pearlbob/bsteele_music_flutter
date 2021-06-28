import 'dart:io';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ScreenInfo {
  ScreenInfo(BuildContext context) : _isDefaultValue = false {
    MediaQueryData mediaQueryData = MediaQuery.of(context);

    double devicePixelRatio = mediaQueryData.devicePixelRatio;
    _widthInLogicalPixels = mediaQueryData.size.width;
    _heightInLogicalPixels = mediaQueryData.size.height;

    //  fixme: an attempt to improve the logical pixel stuff
    if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      _widthInLogicalPixels *= devicePixelRatio;
      _heightInLogicalPixels *= devicePixelRatio;
    }

    _fontSize = 2 * appDefaultFontSize * min(2.5, max(0.5, _widthInLogicalPixels / minLogicalPixels));
    _isTooNarrow = _widthInLogicalPixels <= minLogicalPixels; //  logical pixels
    _titleScaleFactor = 1.25 * max(1, _widthInLogicalPixels / minLogicalPixels);
    logger.d('ScreenInfo: ($_widthInLogicalPixels, $_heightInLogicalPixels)'
        ', narrow: $_isTooNarrow, title: $_titleScaleFactor');

    double textScaleFactor = mediaQueryData.textScaleFactor;

    logger.d('textScaleFactor: $textScaleFactor');
    logger.d('devicePixelRatio: $devicePixelRatio,'
        ' (${_widthInLogicalPixels * devicePixelRatio},${_heightInLogicalPixels * devicePixelRatio})');
  }

  ScreenInfo.defaultValue()
      : _widthInLogicalPixels = 1024,
        _heightInLogicalPixels = 800,
        _isDefaultValue = true {
    _isTooNarrow = false; //  logical pixels
    _titleScaleFactor = 1;
    _fontSize = 16;
  }

  double get fontSize => _fontSize;
  late double _fontSize;

  double get widthInLogicalPixels => _widthInLogicalPixels;
  late double _widthInLogicalPixels;

  double get heightInLogicalPixels => _heightInLogicalPixels;
  late double _heightInLogicalPixels;

  bool get isTooNarrow => _isTooNarrow;
  late bool _isTooNarrow;

  // double get titleScaleFactor => _titleScaleFactor;
  late double _titleScaleFactor;

  bool get isDefaultValue => _isDefaultValue;
  final bool _isDefaultValue;

  static const double minLogicalPixels = 1024; //  just enough for a nexus 3 XL to be "big" when horizontal
}
