import 'package:bsteele_music_flutter/app/appTextStyle.dart';
import 'package:flutter/material.dart';

const double _defaultFontSize = 24;
final Paint _black = Paint()..color = Colors.black;
final Paint _blue = Paint()..color = Colors.lightBlue.shade200;
const _tooltipColor = Color(0xFFE8F5E9);

AppTextStyle appButtonTextStyle({double? fontSize}) {
  return AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.black);
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
    String? tooltip,
  }) : super(
          key: key,
          flex: flex,
          child: tooltip == null
              ? appButton(
                  text,
                  color: color,
                  fontSize: fontSize,
                  onPressed: onPressed,
                )
              : appTooltip(
                  message: tooltip,
                  child: appButton(
                    text,
                    color: color,
                    fontSize: fontSize,
                    onPressed: onPressed,
                  )),
        );
}

/// helper function to generate tool tips
Widget appTooltip({
  required String message,
  required Widget child,
  double? fontSize,
}) {
  return Tooltip(
      message: message,
      child: child,
      textStyle: AppTextStyle(fontSize: fontSize ?? _defaultFontSize),

      //  fixme: why is this broken on web?
      //waitDuration: Duration(seconds: 1, milliseconds: 200),

      verticalOffset: 50,
      decoration: BoxDecoration(
          color: _tooltipColor,
          border: Border.all(),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          boxShadow: const [BoxShadow(color: Colors.grey, offset: Offset(8, 8), blurRadius: 10)]),
      padding: const EdgeInsets.all(8));
}

Wrap appWrap(List<Widget> children, {WrapAlignment? alignment, double? spacing}) {
  return Wrap(
    children: children,
    crossAxisAlignment: WrapCrossAlignment.center,
    alignment: alignment ?? WrapAlignment.start,
    spacing: spacing ?? 0.0,
  );
}

Widget appWrapFullWidth(List<Widget> children, {WrapAlignment? alignment, double? spacing}) {
  return SizedBox(
    width: double.infinity,
    child: appWrap(children, alignment: alignment, spacing: spacing),
  );
}
