import 'package:bsteele_music_flutter/app/appTextStyle.dart';
import 'package:flutter/material.dart';

import 'app.dart';

const double _defaultFontSize = 24;
final Paint _black = Paint()..color = Colors.black;
final Paint _blue = Paint()..color = Colors.lightBlue.shade200;

AppTextStyle appButtonTextStyle({double? fontSize}) {
  return AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.black);
}

/// helper class to manage a ElevatedButton
class AppElevatedButton extends ElevatedButton {
  AppElevatedButton(
    String text, {
    Key? key,
    Color? color,
    double? fontSize,
    required VoidCallback? onPressed,
  }) : super(
          key: key,
          style: ElevatedButton.styleFrom(
            primary: color ?? appDefaultColor,
            textStyle: AppTextStyle(
              color: Colors.black,
              fontSize: fontSize,
            ),
            padding: const EdgeInsets.all(12.0),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            // disabledTextColor: Colors.grey[400],
            // disabledColor: Colors.grey[200],
          ),

          // hoverColor: _hoverColor,
          child: Text(
            text,
            style: AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          onPressed: onPressed,
        );
}

ElevatedButton appButton(
  String commandName, {
  Key? key,
  Color? color,
  double? fontSize,
  required VoidCallback? onPressed,
  double height = 1.5,
}) {
  Paint background = Paint()..color = color ?? _blue.color;
  return ElevatedButton(
    child: Text(
      commandName,
      style: TextStyle(
        fontSize: fontSize ?? _defaultFontSize,
        foreground: _black,
        background: background,
        height: height,
      ),
    ),
    clipBehavior: Clip.hardEdge,
    onPressed: onPressed,
    style: ButtonStyle(
      backgroundColor: MaterialStateProperty.all(color ?? _blue.color),
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fontSize ?? 14), side: const BorderSide(color: Colors.grey))),
      elevation: MaterialStateProperty.all<double>(6),
    ),
  );
}

class AppFlexButton extends Expanded {
  AppFlexButton(
    String text, {
    Key? key,
    Color? color,
    double? fontSize,
    required VoidCallback? onPressed,
    int flex = 1,
  }) : super(
          key: key,
          flex: flex,
          child: appButton(
            text,
            color: color,
            fontSize: fontSize,
            onPressed: onPressed,
          ),
        );
}
