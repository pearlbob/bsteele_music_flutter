import 'package:bsteele_music_flutter/util/appTextStyle.dart';
import 'package:flutter/material.dart';

import 'app.dart';

const double _defaultFontSize = 22;
const AppTextStyle appButtonTextStyle =
    AppTextStyle(fontSize: _defaultFontSize, fontWeight: FontWeight.bold, color: Colors.black);

/// helper class to manage a ElevatedButton
class AppElevatedButton extends ElevatedButton {
  AppElevatedButton(
    String text, {
    Key? key,
    Color? color,
    required VoidCallback? onPressed,
  }) : super(
          key: key,
          style: ElevatedButton.styleFrom(
            primary: color ?? appDefaultColor,
            textStyle: const AppTextStyle(
              color: Colors.black,
            ),
            padding: const EdgeInsets.all(12.0),

          shape: RoundedRectangleBorder(
            borderRadius:  BorderRadius.circular(10),
          ),
          // disabledTextColor: Colors.grey[400],
          // disabledColor: Colors.grey[200],
          ),

          // hoverColor: _hoverColor,
          child: Text(
            text,
            style: appButtonTextStyle,
          ),
          onPressed: onPressed,
        );
}
