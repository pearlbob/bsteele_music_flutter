import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_metadata.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'app.dart';

const Level _logAppKey = Level.debug;

TextStyle appDropdownListItemTextStyle = //  fixme: find the right place for this!
    const TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: 24); // fixme: shouldn't be fixed

class Id {
  Id(this.id);

  @override
  String toString() {
    return id;
  }

  static parse(String s) => Id(s);

  String id;
}

class SongIdMetadataItem {
  SongIdMetadataItem(Song song, this.nameValue) : songIdString = song.songId.toString();

  SongIdMetadataItem.byIdString(this.songIdString, this.nameValue);

  @override
  String toString() {
    return '$songIdString.${nameValue.name}:${nameValue.value}';
  }

  static SongIdMetadataItem? parse(String s) {
    var m = regexp.firstMatch(s);
    if (m != null) {
      return SongIdMetadataItem.byIdString(m.group(1)!, NameValue(m.group(2)!, m.group(3)!));
    }
    return null;
  }

  final String songIdString;
  final NameValue nameValue;
  static final regexp = RegExp(r'^([^.]+)\.(\w+):(\w+)$');
}

class AppKey extends ValueKey<String> implements Comparable<AppKey> {
  const AppKey(super.s);

  @override
  String toString() {
    return value;
  }

  @override
  int compareTo(AppKey other) {
    return value.compareTo(other.value);
  }
}

Widget appCircledIcon(IconData iconData, String toolTip,
    {Color? color, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding, double? size}) {
  return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: AppTooltip(
        message: toolTip,
        child: Icon(
          iconData,
          size: size,
        ),
      ));
}

/// Icon widget with the application look
Icon appIcon(IconData icon, {final Key? key, final Color? color, final double? size}) {
  return Icon(
    icon,
    key: key,
    color: color ?? App.iconColor,
    size: size ?? app.screenInfo.fontSize, //  let the algorithm figure the size dynamically
  );
}

class AppTheme {
  static final AppTheme _singleton = AppTheme._internal();

  factory AppTheme() {
    return _singleton;
  }

  AppTheme._internal();

  Future init() async {
    {
      // var iconTheme = IconThemeData(color: _defaultForegroundColor); fixme
      // var radioTheme = RadioThemeData(fillColor: MaterialStateProperty.all(_defaultForegroundColor)); fixme
      var elevatedButtonThemeStyle = app.themeData.elevatedButtonTheme.style ??
          ButtonStyle(
              foregroundColor: WidgetStateProperty.all(App.defaultForegroundColor),
              backgroundColor: WidgetStateProperty.all(App.defaultBackgroundColor));
      elevatedButtonThemeStyle = elevatedButtonThemeStyle.copyWith(elevation: WidgetStateProperty.all(6));

      //  hassle with mapping Color to MaterialColor
      var color = App.appbarBackgroundColor;
      Map<int, Color> colorCodes = {
        50: color.withOpacity(.1),
        100: color.withOpacity(.2),
        200: color.withOpacity(.3),
        300: color.withOpacity(.4),
        400: color.withOpacity(.5),
        500: color.withOpacity(.6),
        600: color.withOpacity(.7),
        700: color.withOpacity(.8),
        800: color.withOpacity(.9),
        900: color.withOpacity(1),
      };
      MaterialColor materialColor = MaterialColor(color.value, colorCodes);
      color = App.universalBackgroundColor;

      app.themeData = app.themeData.copyWith(
          primaryColor: color,
          disabledColor: App.disabledColor,
          elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonThemeStyle),
          colorScheme: ColorScheme.fromSwatch(
              backgroundColor: color, primarySwatch: materialColor, accentColor: App.universalAccentColor),
          segmentedButtonTheme: SegmentedButtonThemeData(style: elevatedButtonThemeStyle),
          tooltipTheme: TooltipThemeData(
              textStyle: generateTooltipTextStyle(), decoration: appTooltipBoxDecoration(App.tooltipBackgroundColor)),
          dividerTheme: const DividerThemeData(
            color: Colors.black54,
          ));
    }
  }
}

ElevatedButton appButton(
  String commandName, {
  required final VoidCallback? onPressed,
  final Color? backgroundColor,
  final double? fontSize,
  final dynamic value,
}) {
  var voidCallback = onPressed == null
      ? null //  show as disabled   //  fixme: does this work?
      : () {
          onPressed.call();
        };
  var buttonBackgroundColor = onPressed == null ? App.disabledColor : backgroundColor;

  return ElevatedButton(
    clipBehavior: Clip.hardEdge,
    onPressed: voidCallback,
    style: app.themeData.elevatedButtonTheme.style
        ?.copyWith(backgroundColor: WidgetStateProperty.all(buttonBackgroundColor)),
    child: Text(commandName,
        style: TextStyle(fontSize: fontSize ?? app.screenInfo.fontSize, backgroundColor: buttonBackgroundColor)),
  );
}

TextStyle buttonTextStyle() {
  return TextStyle(fontSize: app.screenInfo.fontSize);
}

//  insist on an Id
TextButton appIdButton(
  String text, {
  required VoidCallback? onPressed,
  TextStyle? style,
  required Id id,
}) {
  return appTextButton(
    text,
    onPressed: onPressed,
    style: style,
    value: id,
  );
}

TextButton appTextButton(
  String text, {
  required VoidCallback? onPressed,
  TextStyle? style,
  dynamic value,
}) {
  return TextButton(
    onPressed: () {
      onPressed?.call();
    },
    style: ButtonStyle(
      textStyle: WidgetStateProperty.all(style),
      padding: WidgetStateProperty.all(EdgeInsets.all((style?.fontSize ?? 12.0) / 2)),
      minimumSize: WidgetStateProperty.all(Size.square(style?.fontSize ?? 12.0)),
    ),
    child: Text(
      text,
      style: style,
    ),
  );
}

IconButton appIconButton({
  required Widget icon,
  required VoidCallback onPressed, //  insist on action
  Color? color,
  double? iconSize,
}) {
  return IconButton(
    icon: icon,
    alignment: Alignment.bottomCenter,
    onPressed: () {
      onPressed();
    },
    color: color,
    iconSize: iconSize ?? 24.0, //  demanded by IconButton
  );
}

TextButton appIconWithLabelButton({
  required Widget icon,
  VoidCallback? onPressed,
  dynamic value,
  TextStyle? style,
  double? fontSize,
  String? label,
  Color? backgroundColor,
}) {
  if (onPressed == null) {
    backgroundColor = App.disabledColor;
  }
  style ??= TextStyle(fontSize: fontSize ?? app.screenInfo.fontSize, textBaseline: TextBaseline.alphabetic);
  return TextButton.icon(
    icon: icon,
    label: Text(label ?? '', style: style),
    onPressed: onPressed != null
        ? () {
            onPressed();
          }
        : null,
    style: app.themeData.elevatedButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.all(backgroundColor ?? App.defaultBackgroundColor),
        textStyle: WidgetStateProperty.all(style)),
  );
}

ElevatedButton appNoteButton(
  String character, // a note character is expected
  {
  required VoidCallback? onPressed,
  Color? backgroundColor,
  double? fontSize,
  double? height,
  dynamic value,
}) {
  fontSize ??= app.screenInfo.fontSize;

  fontSize = 30;

  return ElevatedButton(
    onPressed: onPressed == null
        ? null //  show as disabled
        : () {
            onPressed();
          },
    child: Baseline(
      baselineType: TextBaseline.alphabetic,
      baseline: fontSize,
      child: Text(
        character,
        style: TextStyle(
          fontFamily: noteFontFamily,
          fontSize: fontSize,
          height: height ?? 0.5,
        ),
      ),
    ),
  );
}

@immutable
class AppInkWell extends StatelessWidget {
  const AppInkWell({super.key, this.backgroundColor, this.onTap, this.child, this.value});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        onTap?.call();
      },
      child: child,
    );
  }

  final Color? backgroundColor;
  final GestureTapCallback? onTap;
  final Widget? child;
  final dynamic value;
}

DropdownButton<T> appDropdownButton<T>(
  List<DropdownMenuItem<T>> items, {
  T? value,
  ValueChanged<T?>? onChanged,
  Widget? hint,
  TextStyle? style,
}) {
  return DropdownButton<T>(
    value: value,
    items: items,
    onChanged: (value) {
      onChanged?.call(value);
    },
    hint: hint,
    style: style,
    isDense: true,
    iconSize: app.screenInfo.fontSize,
    alignment: Alignment.centerLeft,
    elevation: 8,
    itemHeight: null,
  );
}

//  note: the call back is on the appDropdownButton that is given the value from here
DropdownMenuItem<T> appDropdownMenuItem<T>({
  required T value,
  required Widget child,
}) {
  return DropdownMenuItem<T>(value: value, enabled: true, alignment: AlignmentDirectional.centerStart, child: child);
}

FloatingActionButton appFloatingActionButton({
  required VoidCallback onPressed,
  Widget? child,
  bool mini = false,
}) {
  return FloatingActionButton(
    onPressed: () {
      onPressed();
    },
    mini: mini,
    backgroundColor: App.appBackgroundColor,
    heroTag: null,
    child: child, //  workaround in case there are more than one per route.
  );
}

void appTextFieldListener(TextEditingController controller) {
  logger.d('appLogListener( \'${controller.text}\':${controller.selection} )');
}

Drawer appDrawer({required Widget child, VoidCallback? voidCallback}) {
  logger.log(_logAppKey, 'appDrawer: ');
  return Drawer(child: child);
}

ListTile appListTile({
  required String title,
  required final GestureTapCallback? onTap,
  TextStyle? style,
  final bool enabled = true,
}) {
  style = style ?? appTextStyle;
  if (!enabled) {
    style == style.copyWith(color: App.disabledColor);
  }
  return ListTile(
    title: Text(title, style: style),
    enabled: enabled,
    onTap: () {
      onTap?.call();
    },
  );
}

Switch appSwitch({required bool value, required ValueChanged<bool> onChanged}) {
  return Switch(
    value: value,
    activeColor: App.appBackgroundColor,
    inactiveThumbColor: Colors.grey,
    inactiveTrackColor: Colors.grey.shade300,
    onChanged: (value) {
      onChanged(value);
    },
  );
}

@immutable
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    required this.onChanged,
    this.hintText,
    this.style,
    this.fontSize, //  fixme: overridden by non-null style above
    this.fontWeight,
    this.enabled,
    this.minLines,
    this.maxLines,
    this.border,
    this.width = 200,
  }) : onSubmitted = null;

  const AppTextField.onSubmitted({
    super.key,
    this.controller,
    this.focusNode,
    required this.onSubmitted,
    this.hintText,
    this.style,
    this.fontSize, //  fixme: overridden by non-null style above
    this.fontWeight,
    this.enabled,
    this.minLines,
    this.maxLines,
    this.border,
    this.width = 200,
  }) : onChanged = null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: App.textFieldColor),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: (minLines ?? 0) > 1 ? TextInputType.multiline : TextInputType.text,
          onChanged: (String value) {
            onChanged?.call(value);
          },
          onSubmitted: (String value) {
            onSubmitted?.call(value);
          },
          decoration: InputDecoration(
            border: border,
            // floatingLabelAlignment: FloatingLabelAlignment.start,
            isDense: true,
            contentPadding: const EdgeInsets.all(2.0),
            hintText: hintText,
            hintStyle: style?.copyWith(color: Colors.black54, fontWeight: FontWeight.normal),
          ),
          style: style ?? generateAppTextFieldStyle(fontSize: fontSize, fontWeight: fontWeight ?? FontWeight.normal),
          //(fontSize: fontSize, fontWeight: fontWeight ?? FontWeight.bold),
          autofocus: true,
          maxLength: null,
          minLines: minLines,
          maxLines: maxLines ?? minLines,
        ),
      ),
    );
  }

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? hintText;
  final TextStyle? style;
  final double? fontSize; //  fixme: overridden by non-null style above
  final FontWeight? fontWeight;
  final bool? enabled;
  final int? minLines;
  final int? maxLines;
  final InputBorder? border;
  final double width;
}

// GestureDetector appGestureDetector(  //  fixme: install!
//     {required AppKeyEnum appKeyEnum, dynamic value, Widget? child, GestureTapCallback? onTap}) {
//   var key = appKey(appKeyEnum, value: value);
//   _appKeyRegisterCallback(key,callback: onTap);
//   return GestureDetector(
//     key: key,
//     child: child,
//     onTap: () {
//       appLogKeyCallback(key);
//       onTap?.call();
//     },
//   );
// }

const appFontFamily = 'Roboto';
const noteFontFamily = 'Bravura'; // the music symbols are over sized in the vertical!
const List<String> appFontFamilyFallback = [
  appFontFamily,
  'DejaVu',
  noteFontFamily,
];

/// Creates the app's text style.
///
/// The `package` argument must be non-null if the font family is defined in a
/// package. It is combined with the `fontFamily` argument to set the
/// [fontFamily] property.

TextStyle generateAppTextStyle({
  Color? color,
  Color? backgroundColor,
  String? fontFamily,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  TextBaseline? textBaseline,
  TextDecoration? decoration,
  bool nullBackground = false,
}) {
  fontSize ??= app.screenInfo.fontSize;
  fontSize = Util.limit(fontSize, appDefaultFontSize, 150.0) as double?;
  return TextStyle(
    color: color ?? App.universalForegroundColor,
    //  watch out: backgroundColor interferes with mouse text select on textFields!
    backgroundColor: nullBackground ? null : backgroundColor ?? App.universalBackgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight ?? FontWeight.normal,
    fontStyle: fontStyle ?? App.universalFontStyle,
    textBaseline: textBaseline ?? TextBaseline.alphabetic,
    fontFamily: fontFamily ?? appFontFamily,
    fontFamilyFallback: appFontFamilyFallback,
    decoration: decoration ?? TextDecoration.none,
    overflow: TextOverflow.clip,
  );
}

TextStyle generateAppTextFieldStyle({
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  TextBaseline? textBaseline,
  TextDecoration? decoration,
}) {
  return generateAppTextStyle(
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textBaseline: textBaseline,
      decoration: decoration,
      nullBackground: true //  force a null background for mouse text selection
      );
}

TextStyle generateAppBarLinkTextStyle() {
  return generateAppTextStyle(
    fontWeight: FontWeight.bold,
    color: App.defaultForegroundColor,
    backgroundColor: Colors.transparent,
  );
}

TextStyle generateAppLinkTextStyle({
  double? fontSize,
}) {
  return generateAppTextStyle(
    color: Colors.blue, //  fixme
    decoration: TextDecoration.underline,
    fontSize: fontSize,
  );
}

TextStyle generateTooltipTextStyle({double? fontSize}) {
  return generateAppTextStyle(
    color: App.tooltipColor,
    backgroundColor: App.tooltipBackgroundColor,
    fontSize: fontSize,
  );
}

TextStyle generateChordTextStyle(
    {String? fontFamily, double? fontSize, FontWeight? fontWeight, Color? backgroundColor}) {
  return generateAppTextStyle(
    color: App.chordNoteColor,
    backgroundColor: backgroundColor ?? App.chordNoteBackgroundColor,
    fontFamily: fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight ?? App.chordNoteFontWeight,
    fontStyle: App.chordNoteFontStyle,
  );
}

TextStyle generateLyricsTextStyle({double? fontSize, Color? backgroundColor}) {
  return generateAppTextStyle(
    backgroundColor: backgroundColor ?? App.universalBackgroundColor,
    fontSize: fontSize,
  );
}

TextStyle generateChordDescriptorTextStyle({double? fontSize, FontWeight? fontWeight, Color? backgroundColor}) {
  return generateAppTextStyle(
    color: App.chordDescriptorColor,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight ?? App.chordNoteFontWeight,
    fontStyle: App.chordNoteFontStyle,
  );
}

TextStyle oddTitleTextStyle({TextStyle? from}) {
  return (from ?? generateAppTextStyle())
      .copyWith(backgroundColor: App.oddTitleTextBackgroundColor, color: App.oddTitleTextColor);
}

TextStyle evenTitleTextStyle({TextStyle? from}) {
  return (from ?? generateAppTextStyle())
      .copyWith(backgroundColor: App.evenTitleTextBackgroundColor, color: App.evenTitleTextColor);
}
