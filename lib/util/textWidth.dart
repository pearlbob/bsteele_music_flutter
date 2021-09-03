import 'package:flutter/material.dart';

double textWidth(
  BuildContext context,
  TextStyle style,
  String text,
) {
  return (TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr)
        ..layout())
      .size
      .width;
}

double richTextWidth(
    BuildContext context,
    RichText richText,
    ) {
  return (TextPainter(
      text: richText.text,
      maxLines: 1,
      textDirection: TextDirection.ltr)
    ..layout())
      .size
      .width;
}
