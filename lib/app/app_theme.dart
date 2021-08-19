import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:flutter/material.dart';
import 'package:csslib/parser.dart' as parser;
import 'package:csslib/visitor.dart' as visitor;

import 'app.dart';

//const Color _appDefaultColor = Color(0xFF4FC3F7); //Color(0xFFB3E5FC);
double _defaultFontSize = 14;
Color _defaultBackgroundColor = Colors.white;
Color _defaultForegroundColor = Colors.black;
MaterialStateProperty<EdgeInsetsGeometry?> _defaultPadding = MaterialStateProperty.all(const EdgeInsets.all(10));
ButtonStyle _defaultButtonStyle = ButtonStyle(
  backgroundColor: MaterialStateProperty.all(_defaultBackgroundColor),
  foregroundColor: MaterialStateProperty.all(_defaultForegroundColor),
  padding: _defaultPadding,
);

Map<String, List<String>> _propertyLiterals = {
  'text-align': ['left', 'right', 'center', 'justify', 'initial', 'inherit'],
  'font-weight': ['normal', 'bold', 'bolder', 'lighter', 'initial', 'inherit'],
  'border-style': ['dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset', 'outset', 'none', 'hidden'],
};

class AppTheme {
  static final AppTheme _singleton = AppTheme._internal();

  factory AppTheme() {
    return _singleton;
  }

  AppTheme._internal();

  Future init() async {
    // _defaultFontSize = 24;
    // _defaultBackgroundColor = Colors.orange;
    // _defaultForegroundColor = Colors.purple;
    // _defaultPadding = MaterialStateProperty.all(const EdgeInsets.all(30));

    String cssAsString = await loadString('lib/assets/app.css');
    List<parser.Message> errors = [];
    var stylesheet = parser.parse(cssAsString, errors: errors);
    for (var error in errors) {
      logger.e('CSS error: ${error.level}:'
          ' (from line ${error.span?.start.line}:${error.span?.start.column}'
          ' to ${error.span?.end.line}:${error.span?.end.column})'
          ': ${error.message}');
    }
    for (var treeNode in stylesheet.topLevels) {
      // logger.i('${treeNode.toString()}: ${treeNode.runtimeType}');
      if (treeNode is visitor.RuleSet) {
        if (treeNode.selectorGroup != null) {
          var selectorGroup = treeNode.selectorGroup;
          // logger.i('  selectorGroup: ${selectorGroup.runtimeType} $selectorGroup');
          for (var selectors in selectorGroup!.selectors) {
            for (var selector in selectors.simpleSelectorSequences) {
              var selectorTypeChar = '';
              switch (selector.simpleSelector.runtimeType) {
                case visitor.ClassSelector:
                  selectorTypeChar = '.';
                  break;
                case visitor.IdSelector:
                  selectorTypeChar = '#';
                  break;
                case visitor.ElementSelector:
                  selectorTypeChar = '';
                  break;
                default:
                  selectorTypeChar = '(unknown:${selector.simpleSelector.runtimeType})';
                  break;
              }

              for (var dec in treeNode.declarationGroup.declarations) {
                if (dec is visitor.Declaration) {
                  var property = dec.property;
                  var literals = _propertyLiterals[property];
                  var expression = dec.expression;
                  if (expression is visitor.Expressions) {
                    var expressions = expression;
                    for (var exp in expressions.expressions) {
                      if (exp is visitor.LengthTerm) {
                        var term = exp;
                        logger.i('$selectorTypeChar$selector.$property:  ${term.value} ${term.unitToString()}');
                      } else if (exp is visitor.HexColorTerm) {
                        var hexColorTerm = exp;
                        if (_threeDigitHexRegExp.hasMatch(hexColorTerm.text)) {
                          var t = hexColorTerm.text.characters;
                          var s = t.characterAt(0) +
                              t.characterAt(0) +
                              t.characterAt(1) +
                              t.characterAt(1) +
                              t.characterAt(2) +
                              t.characterAt(2);
                          int i = int.parse(s.toString(), radix: 16);
                          logger.i(
                              '$selectorTypeChar$selector.$property (3 digit HexColorTerm): 0x${i.toRadixString(16)}');
                        } else if (hexColorTerm.value is int) {
                          int i = hexColorTerm.value;
                          logger.i('$selectorTypeChar$selector.$property (HexColorTerm): 0x${i.toRadixString(16)}');
                        } else {
                          logger.i('Not understood: HexColorTerm: '
                              '${hexColorTerm.runtimeType} ${hexColorTerm.value} ${hexColorTerm.toString()}');
                        }
                      } else if (exp is visitor.LiteralTerm) {
                        var literalTerm = exp;
                        if (literals != null) {
                          if (literals.contains(literalTerm.text)) {
                            logger.i('$selectorTypeChar$selector.$property: "${literalTerm.text}"');
                          } else {
                            logger.e('error: NOT valid value for $selectorTypeChar$selector.$property:'
                                ' "${literalTerm.value}"');
                          }
                        } else {
                          logger.e('error: (LiteralTerm) NOT understood: "${literalTerm.value}"');
                        }
                      } else {
                        logger.e('error: NOT understood: ${exp.runtimeType} ${exp.toString()}');
                      }
                    }
                  } else {
                    logger.e('error: expression is NOT Expressions: "$expression"');
                  }
                } else {
                  logger.e('error: NOT declaration: ${dec.runtimeType} $dec');
                }
              }
            }
          }
        }

        //final DeclarationGroup declarationGroup;
      }
    }

// {
//   var item = ThemeValue('address', Colors.red);
//   logger.i('type: ${item.value.runtimeType}');
//   switch (item.value.runtimeType) {
//     case MaterialColor:
//       {
//         var color = item.value as MaterialColor;
//         logger.i('color: $color: (${color.red},${color.green},${color.blue})');
//       }
//       break;
//   }
// }

    if ( false ) {
      var appBarTheme = AppBarTheme(backgroundColor: _defaultBackgroundColor, foregroundColor: _defaultForegroundColor);
      var iconTheme = IconThemeData(color: _defaultForegroundColor);
      var radioTheme = RadioThemeData(fillColor: MaterialStateProperty.all(_defaultForegroundColor));
      var textStyle = TextStyle(backgroundColor: _defaultBackgroundColor, color: _defaultForegroundColor);
      var textTheme = TextTheme(
        bodyText1: textStyle,
        bodyText2: textStyle,
        caption: textStyle,
        button: textStyle,
        overline: textStyle,
      );
      themeData = themeData.copyWith(
        appBarTheme: appBarTheme,
        backgroundColor: _defaultBackgroundColor,
        iconTheme: iconTheme,
        primaryColor: _defaultBackgroundColor,
        radioTheme: radioTheme,
        textTheme: textTheme,
      );
    }
  }

  ThemeData themeData = ThemeData(
    //primaryColor: _appDefaultColor,
  );

  final RegExp _threeDigitHexRegExp = RegExp(r'^[\da-fA-f]{3}$');
}

Text _defaultElevatedButtonText = Text(
  'default',
  style: TextStyle(
    color: Colors.black,
    backgroundColor: _defaultBackgroundColor,
    fontSize: _defaultFontSize,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.normal,
  ),
);
ElevatedButton _defaultElevatedButton = ElevatedButton(
  child: _defaultElevatedButtonText,
  style: _defaultButtonStyle,
  onPressed: () {},
);

ElevatedButton appButton(
  String commandName, {
  Key? key,
  Color? background,
  double? fontSize,
  required VoidCallback? onPressed,
  double height = 1.5,
}) {
  var backgroundPaint = Paint()
    ..color = background ??
        _defaultElevatedButton.style?.backgroundColor?.resolve({}) ??
        _defaultElevatedButtonText.style?.backgroundColor ??
        _defaultBackgroundColor;
  var foreground = Paint()
    ..color =
        _defaultElevatedButton.style?.foregroundColor?.resolve({}) ??
        _defaultElevatedButtonText.style?.color ??
        _defaultForegroundColor;
  var textStyle = TextStyle(
    fontSize: fontSize ?? _defaultElevatedButtonText.style?.fontSize ?? _defaultFontSize,
    foreground: foreground,
    background: backgroundPaint,
    height: height,
  );

  return ElevatedButton(
    child: Text(commandName, style: textStyle),
    clipBehavior: Clip.hardEdge,
    onPressed: onPressed,
    style: ButtonStyle(
      textStyle: MaterialStateProperty.all(textStyle),
      backgroundColor: MaterialStateProperty.all(backgroundPaint.color),
      padding: _defaultPadding,
      shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular((fontSize ?? _defaultFontSize) / 2),
          side: const BorderSide(color: Colors.grey))),
      elevation: MaterialStateProperty.all<double>(6),
    ),
  );
}

class ThemeValue {
  ThemeValue(this.address, this._value);

  final String address;

  Object get value => _value;
  final Object _value;
}

const List<String> appFontFamilyFallback = [
  //'Roboto',
  'DejaVu'
  //'Bravura',  // music symbols are over sized in the vertical
];

/// style used to get DejaVu as a fallback family for musical sharps and flats
@immutable
class AppTextStyle extends TextStyle {
  /// Creates the app's text style.
  ///
  /// The `package` argument must be non-null if the font family is defined in a
  /// package. It is combined with the `fontFamily` argument to set the
  /// [fontFamily] property.
  AppTextStyle({
    bool inherit = true,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    TextLeadingDistribution? leadingDistribution,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    //List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
    String? fontFamily,
    List<String>? fontFamilyFallback = appFontFamilyFallback,
    String? package,
    TextOverflow? overflow,
  }) : super(
          inherit: inherit,
          color: color ?? _defaultForegroundColor,
          backgroundColor: backgroundColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
          textBaseline: textBaseline,
          height: height,
          leadingDistribution: leadingDistribution,
          locale: locale,
          foreground: foreground,
          background: background,
          shadows: shadows,
          //fontFeatures: fontFeatures,
          decoration: decoration,
          decorationColor: decorationColor,
          decorationStyle: decorationStyle,
          decorationThickness: decorationThickness,
          debugLabel: debugLabel,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          package: package,
          overflow: overflow,
        );
}
