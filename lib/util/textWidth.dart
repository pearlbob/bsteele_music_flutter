import 'package:flutter/material.dart';

double textWidth(
  BuildContext context,
  TextStyle style,
  String text,
) {
  return (TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textScaleFactor: MediaQuery.of(context).textScaleFactor,
          textDirection: TextDirection.ltr)
        ..layout())
      .size
      .width;
}
