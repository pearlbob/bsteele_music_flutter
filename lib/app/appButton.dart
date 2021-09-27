import 'package:bsteeleMusicLib/songs/chord.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/measure.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'app_theme.dart';

TextStyle appTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, color: Colors.black);
TextStyle appWarningTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, color: Colors.blue);
TextStyle appErrorTextStyle = generateAppTextStyle(fontSize: _defaultFontSize, color: Colors.red);

const double _defaultFontSize = 24;

final App _app = App();

TextStyle appButtonTextStyle({double? fontSize}) {
  return generateAppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.black);
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

/// helper function to generate tool tips
Widget appTooltip({
  Key? key,
  required String message,
  required Widget child,
  double? fontSize,
}) {
  var textStyle = generateTooltipTextStyle();
  return Tooltip(
      key: key,
      message: message,
      child: child,
      textStyle: textStyle,
      waitDuration: const Duration(seconds: 1, milliseconds: 200),
      verticalOffset: 75,
      decoration: appTooltipBoxDecoration(textStyle.backgroundColor),
      padding: const EdgeInsets.all(8));
}

BoxDecoration appTooltipBoxDecoration(Color? color) {
  return BoxDecoration(
      color: color,
      border: Border.all(),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      boxShadow: const [BoxShadow(color: Colors.grey, offset: Offset(8, 8), blurRadius: 10)]);
}

Wrap appWrap(List<Widget> children,
    {WrapAlignment? alignment, WrapCrossAlignment? crossAxisAlignment, double? spacing}) {
  return Wrap(
    children: children,
    crossAxisAlignment: crossAxisAlignment ?? WrapCrossAlignment.end,
    alignment: alignment ?? WrapAlignment.start,
    spacing: spacing ?? 0.0,
  );
}

Widget appWrapFullWidth(List<Widget> children,
    {WrapAlignment? alignment, WrapCrossAlignment? crossAxisAlignment, double? spacing}) {
  return SizedBox(
    width: double.infinity,
    child: appWrap(children, alignment: alignment, crossAxisAlignment: crossAxisAlignment, spacing: spacing),
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
        child: appIcon(Icons.arrow_back),
      ),
    );
  }

  Widget floatingBack() {
    return appTooltip(
      message: 'Back',
      child: appFloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }

  AppBar backBar({Widget? titleWidget, String? title}) {
    return appBar(title: title, titleWidget: titleWidget, leading: back());
  }

  AppBar appBar({Key? key, String? title, Widget? titleWidget, Widget? leading, List<Widget>? actions}) {
    return AppBar(
      key: key ?? const ValueKey('appBar'),
      title: titleWidget ??
          Text(
            title ?? 'unknown',
            style: TextStyle(
              fontSize: _app.screenInfo.fontSize,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.transparent,
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
    TextStyle slashStyle = generateChordSlashNoteTextStyle(fontSize: style?.fontSize).copyWith(
      // fontFamily: 'Roboto', //  fixme
      backgroundColor: style?.backgroundColor,
    );
    TextStyle chordDescriptorStyle = generateChordDescriptorTextStyle(
      fontSize: 0.8 * (style?.fontSize ?? _defaultFontSize),
    ).copyWith(
      backgroundColor: style?.backgroundColor,
    );

    if (measure.chords.isNotEmpty) {
      List<TextSpan> children = [];
      for (Chord chord in measure.chords) {
        var transposedChord = chord.transpose(key, halfSteps);
        var isSlash = transposedChord.slashScaleNote != null;

        //  chord note
        children.add(TextSpan(
          text: transposedChord.scaleChord.scaleNote.toString(),
          style: style,
        ));
        {
          //  chord descriptor
          var name = transposedChord.scaleChord.chordDescriptor.shortName;
          if (name.isNotEmpty) {
            children.add(
              TextSpan(
                text: name,
                style: chordDescriptorStyle,
              ),
            );
          }
        }

        //  other stuff
        children.add(TextSpan(
          text: transposedChord.anticipationOrDelay.toString() + transposedChord.beatsToString(),
          style: style,
        ));
        if (isSlash) {
          var s = '/${transposedChord.slashScaleNote.toString()} '; //  notice the final space for italics
          children.add(TextSpan(
            text: s,
            style: slashStyle,
          ));
        }
      }

      return RichText(
        text: TextSpan(children: children),
        //  don't allow the rich text to wrap:
        textWidthBasis: TextWidthBasis.longestLine,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        textDirection: TextDirection.ltr,
        textScaleFactor: 1.0,
        textAlign: TextAlign.start,
        textHeightBehavior: const TextHeightBehavior(),
      );
    }

    //  no chord measures such as repeats, repeat markers and comments
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
