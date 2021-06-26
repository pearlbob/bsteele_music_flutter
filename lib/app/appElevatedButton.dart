import 'package:bsteele_music_flutter/util/appTextStyle.dart';
import 'package:flutter/material.dart';

import 'app.dart';

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
          child: AppElevatedButton(
            text,
            color: color,
            fontSize: fontSize,
            onPressed: onPressed,
          ),
        );
}
