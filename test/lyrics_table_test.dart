// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

var defaultFontSize = 24.0;

void main() async {
  Logger.level = Level.info;

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verify text length is proportional to fontsize', (WidgetTester tester) async {
    for (String s in ['foo', 'bob was here', ' asdf  sa fsad fasdf  asdf asdf asdf ']) {
      logger.i('"$s"');
      testRatio(s);
    }
  });
}

void testRatio(String s) {
  var size = sizeText(s, fontSize: defaultFontSize);
  var defaultRatio = size.width / size.height;
  for (var fontSize = defaultFontSize / 4; fontSize < defaultFontSize * 3; fontSize++) {
    size = sizeText(s, fontSize: fontSize);
    var ratio = size.width / size.height;
    logger.d('$fontSize: $size  $ratio');
    expect(ratio, defaultRatio);
  }
}

Size sizeText(String text, {double? fontSize, TextStyle? textStyle}) {
  return sizeRichText(RichText(
      text: TextSpan(
    text: text,
    style: textStyle ??
        TextStyle(
          fontSize: fontSize ?? defaultFontSize,
        ),
  )));
}

Size sizeRichText(RichText richText) {
  TextPainter textPainter = TextPainter()
    ..text = richText.text
    ..textDirection = TextDirection.ltr
    ..layout(minWidth: 0, maxWidth: double.infinity);
  return textPainter.size;
}
