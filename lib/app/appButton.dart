import 'package:bsteeleMusicLib/songs/chord.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_theme.dart';

AppTextStyle appTextStyle = AppTextStyle(fontSize: _defaultFontSize, color: const Color(0xFF424242));
AppTextStyle appWarningTextStyle = AppTextStyle(fontSize: _defaultFontSize, color: Colors.blue);
AppTextStyle appErrorTextStyle = AppTextStyle(fontSize: _defaultFontSize, color: Colors.red);

const double _defaultFontSize = 24;
const _tooltipColor = Color(0xFFE8F5E9);

final App _app = App();

AppTextStyle appButtonTextStyle({double? fontSize}) {
  return AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.black);
}

Widget appSpace({double? space}) {
  if (space == null) {
    return const SizedBox(
      height: 10,
      width: 10,
    );
  }
  return SizedBox(
    height: space,
    width: space,
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
                  background: color,
                  fontSize: fontSize,
                  onPressed: onPressed,
                )
              : appTooltip(
                  message: tooltip,
                  child: appButton(
                    text,
                    background: color,
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

      verticalOffset: 75,
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

///  A collection of methods that generate application styled widgets.
///  It also provides a handy place to hold the build context should it be needed.
class AppWidget {
  Widget back() {
    return appTooltip(
      message: 'Back',
      child: TextButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }

  Widget floatingBack() {
    return appTooltip(
      message: 'Back',
      child: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }

  AppBar backBar(String title, {double? fontSize}) {
    return appBar(title: title, leading: back(), fontSize: fontSize);
  }

  AppBar appBar(
      {Key? key, String? title, Widget? titleWidget, Widget? leading, List<Widget>? actions, double? fontSize}) {
    return AppBar(
      key: key ?? const ValueKey('appBar'),
      title: titleWidget ??
          Text(
            title ?? 'unknown',
            style: TextStyle(
              fontSize: fontSize ?? _app.screenInfo.fontSize, fontWeight: FontWeight.bold,
            ),
          ),
      leading: leading,
      centerTitle: false,
      actions: actions,
      toolbarHeight: (_app.isScreenBig ? kToolbarHeight : kToolbarHeight * 0.6), //  trim for cell phone overrun
    );
  }

  Widget checkbox({required bool? value, ValueChanged<bool?>? onChanged, double? fontSize}) {
    ThemeData themeData = Theme.of(context);
    return Transform.scale(
      scale: 0.7 * (fontSize ?? _defaultFontSize) / Checkbox.width,
      child: Checkbox(
          checkColor: Colors.white, fillColor: themeData.checkboxTheme.fillColor, value: value, onChanged: onChanged),
    );
  }

  Widget transpose(Measure measure, music_key.Key key, int halfSteps, {TextStyle? style}) {
    TextStyle slashStyle = AppTextStyle(
      fontFamily: 'Roboto',
      fontSize: style?.fontSize,
      fontWeight: FontWeight.bold,
      fontStyle: FontStyle.italic,
      color: const Color(0xFF7D0707),
    );
    TextStyle chordDescriptorStyle = AppTextStyle(
      fontSize: 0.8 * (style?.fontSize ?? _defaultFontSize),
      fontWeight: FontWeight.normal,
    );

    if (measure.chords.isNotEmpty) {
      List<Widget> children = [];
      for (Chord chord in measure.chords) {
        var transposedChord = chord.transpose(key, halfSteps);
        var isSlash = transposedChord.slashScaleNote != null;

        //  chord note
        children.add(Text(
          transposedChord.scaleChord.scaleNote.toString(),
          style: style,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.clip,
        ));
        {
          //  chord descriptor
          var name = transposedChord.scaleChord.chordDescriptor.shortName;
          if (name.isNotEmpty) {
            children.add(Baseline(
              baseline: (style?.fontSize ?? _defaultFontSize),
              baselineType: TextBaseline.alphabetic,
              child: Text(
                name,
                style: chordDescriptorStyle,
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ));
          }
        }

        //  other stuff
        children.add(Text(
          transposedChord.anticipationOrDelay.toString() + transposedChord.beatsToString(),
          style: style,
          softWrap: false,
          maxLines: 1,
        ));
        if (isSlash) {
          var s = '/' + transposedChord.slashScaleNote.toString() + ' ';
          // final Size size = (TextPainter(
          //         text: TextSpan(text: s, style: slashStyle),
          //         maxLines: 1,
          //         textScaleFactor: MediaQuery.of(context).textScaleFactor,
          //         textDirection: TextDirection.ltr)
          //       ..layout())
          //     .size;
          // logger.i('isSlash height: ${size.height}');
          children.add(
              //   Baseline(  fixme: from "top of box" ends up pushing everything up, including the container's center
              // baseline: 2 * 1.6 * size.height,
              // baselineType: TextBaseline.alphabetic,
              // child:
              Text(
            s,
            style: slashStyle,
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.clip,
            // ),
          ));
        }
      }
      return appWrap(
        children,
      );
    }

    //  the usual, no chords
    return Text(
      measure.toString(),
      style: style,
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }

  ///  should be set on every build!
  late BuildContext context;
}
