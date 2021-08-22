import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:flutter/material.dart';
import 'package:csslib/parser.dart' as parser;
import 'package:csslib/visitor.dart' as visitor;

import 'app.dart';

double _defaultFontSize = 14;
Color? _defaultBackgroundColor = Colors.white;
Color? _defaultForegroundColor = Colors.black;

ThemeData _themeData = ThemeData(); //  start with the default theme

Map<String, List<String>> _propertyLiterals = {
  'text-align': ['left', 'right', 'center', 'justify', 'initial', 'inherit'],
  'font-weight': ['normal', 'bold', 'bolder', 'lighter', 'initial', 'inherit'],
  'border-style': ['dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset', 'outset', 'none', 'hidden'],
};

class _CssColor extends Color {
  _CssColor(int value) : super(0xFF000000 + value);
}

class AppTheme {
  static final AppTheme _singleton = AppTheme._internal();

  factory AppTheme() {
    return _singleton;
  }

  ThemeData get themeData => _themeData;

  AppTheme._internal();

  Future init() async {
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
      if (treeNode is visitor.RuleSet) {
        if (treeNode.selectorGroup != null) {
          var selectorGroup = treeNode.selectorGroup;
          for (var selectors in selectorGroup!.selectors) {
            for (var selector in selectors.simpleSelectorSequences) {
              CssSelectorType cssSelector;
              switch (selector.simpleSelector.runtimeType) {
                case visitor.ClassSelector:
                  cssSelector = CssSelectorType.classSelector;
                  break;
                case visitor.ElementSelector:
                  cssSelector =
                      selector.simpleSelector.name == '*' ? CssSelectorType.universal : CssSelectorType.element;
                  break;
                case visitor.IdSelector:
                  cssSelector = CssSelectorType.id;
                  break;

                default:
                  cssSelector = CssSelectorType.element;
                  logger.e('unknown selector.simpleSelector.runtimeType: ${selector.simpleSelector.runtimeType}');
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
                        applyAction(cssSelector, selector.simpleSelector.name, property, exp);
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
                          applyAction(cssSelector, selector.simpleSelector.name, property, _CssColor(i));
                        } else if (hexColorTerm.value is int) {
                          int i = hexColorTerm.value;
                          applyAction(cssSelector, selector.simpleSelector.name, property, _CssColor(i));
                        } else {
                          logger.e('Not understood: HexColorTerm: '
                              '${hexColorTerm.runtimeType} ${hexColorTerm.value} ${hexColorTerm.toString()}');
                        }
                      } else if (exp is visitor.LiteralTerm) {
                        var literalTerm = exp;
                        if (literals != null) {
                          if (literals.contains(literalTerm.text)) {
                            applyAction(cssSelector, selector.simpleSelector.name, property, literalTerm.text);
                          } else {
                            logger.e('error: NOT valid value for'
                                ' ${cssSelectorCharacterMap[cssSelector] ?? ''}cssSelector $selector.$property:'
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

    {
      var iconTheme = IconThemeData(color: _defaultForegroundColor);
      var radioTheme = RadioThemeData(fillColor: MaterialStateProperty.all(_defaultForegroundColor));
      _themeData = _themeData.copyWith(
        backgroundColor: _defaultBackgroundColor,
        iconTheme: iconTheme,
        primaryColor: _defaultBackgroundColor,
        radioTheme: radioTheme,
      );
    }
  }

  final RegExp _threeDigitHexRegExp = RegExp(r'^[\da-fA-f]{3}$');
}

ElevatedButton appButton(
  String commandName, {
  Key? key,
  Color? background,
  double? fontSize,
  required VoidCallback? onPressed,
  double height = 1.5,
}) {
  return ElevatedButton(
    child: Text(commandName, style: _themeData.elevatedButtonTheme.style?.textStyle?.resolve({}) ?? const TextStyle()),
    clipBehavior: Clip.hardEdge,
    onPressed: onPressed,
    style: _themeData.elevatedButtonTheme.style,
  );
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

enum CssSelectorType {
  universal, //  *
  element,
  classSelector, //  .class
  id, //  #valueKey
}

final Map<CssSelectorType, String> cssSelectorCharacterMap = {
  CssSelectorType.universal: '*',
  CssSelectorType.element: '',
  CssSelectorType.classSelector: '.',
  CssSelectorType.id: '#',
};

typedef CssActionFunction = void Function(CssProperty cssProperty, dynamic value);

class CssProperty implements Comparable<CssProperty> {
  const CssProperty(this.selector, this.selectorName, this.property, this.type, this.description);

  @override
  int compareTo(CssProperty other) {
    if (identical(this, other)) {
      return 0;
    }
    var ret = selector.index - other.selector.index;
    if (ret != 0) {
      return ret;
    }
    ret = selectorName.compareTo(other.selectorName);
    if (ret != 0) {
      return ret;
    }
    ret = property.compareTo(other.property);
    if (ret != 0) {
      return ret;
    }
    ret = type.toString().compareTo(other.type.toString());
    if (ret != 0) {
      return ret;
    }
    return 0;
  }

  @override
  String toString() {
    return '${cssSelectorCharacterMap[selector] ?? ''}${selector == CssSelectorType.universal ? '' : selectorName}'
        '.$property /*($type)*/:';
  }

  final CssSelectorType selector;
  final String selectorName;
  final String property;
  final Type type;
  final String description;
}

class CssAction implements Comparable<CssAction> {
  CssAction(this.cssProperty, this.cssActionFunction);

  @override
  int compareTo(CssAction other) {
    return cssProperty.compareTo(other.cssProperty); //  fixme: deal with action function comparisons
  }

  @override
  String toString() {
    return cssProperty.toString();
  }

  CssProperty cssProperty;
  CssActionFunction cssActionFunction;
}

List<CssAction> cssActions = [
  CssAction(const CssProperty(CssSelectorType.universal, '*', 'color', Color, 'universal foreground color'), //
      (p, value) {
    assert(value is Color);
    _defaultForegroundColor = value;
  }),
  CssAction(const CssProperty(CssSelectorType.universal, '*', 'background-color', Color, 'universal background color'),
      (CssProperty p, value) {
    assert(value is Color);
    _defaultBackgroundColor = value;
  }),
  CssAction(
      const CssProperty(CssSelectorType.universal, '*', 'font-size', visitor.LengthTerm, 'universal text font size'),
      (CssProperty p, value) {
    assert(value is visitor.LengthTerm);
    //  fixme: textThemes are not complete
    //  fixme: textThemes are identical!
    var textStyle = _themeData.textTheme.bodyText1 ??
        _themeData.textTheme.bodyText2 ??
        _themeData.textTheme.button ??
        TextStyle(fontSize: value);
    var term = value as visitor.LengthTerm;
    switch (term.unit) {
      case parser.TokenKind.UNIT_LENGTH_PX:
        textStyle = textStyle.copyWith(fontSize: double.parse(term.text));
        break;
      default:
        logger.e( 'ERROR: ${p.toString()} assigned wrong unit type: ${term.unit}, see parser.TokenKind ');
        return;
    }

    var textTheme = TextTheme(
      bodyText1: textStyle,
      bodyText2: textStyle,
      button: textStyle,
    );
    _themeData = _themeData.copyWith(textTheme: textTheme);
  }),
  CssAction(
      const CssProperty(
          CssSelectorType.element, 'button', 'background-color', Color, 'universal (elevated) button background color'),
      (CssProperty p, value) {
    assert(value is Color);
    _themeData = _themeData.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: (_themeData.elevatedButtonTheme.style == null
                ? ElevatedButton.styleFrom(primary: value)
                : _themeData.elevatedButtonTheme.style!.copyWith(backgroundColor: MaterialStateProperty.all(value)))));
  }),
  CssAction(
      const CssProperty(
          CssSelectorType.element, 'button', 'color', Color, 'universal (elevated) button foreground color'),
      (CssProperty p, value) {
    assert(value is Color);
    _themeData = _themeData.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: (_themeData.elevatedButtonTheme.style == null
                ? ElevatedButton.styleFrom(onPrimary: value)
                : _themeData.elevatedButtonTheme.style!.copyWith(foregroundColor: MaterialStateProperty.all(value)))));
  }),
  CssAction(const CssProperty(CssSelectorType.element, 'appbar', 'background-color', Color, 'app bar background color'),
      (CssProperty p, value) {
    assert(value is Color);
    _themeData = _themeData.copyWith(appBarTheme: _themeData.appBarTheme.copyWith(backgroundColor: value));
  }),
  CssAction(const CssProperty(CssSelectorType.element, 'appbar', 'color', Color, 'app bar foreground color'),
      (CssProperty p, value) {
    assert(value is Color);
    _themeData = _themeData.copyWith(appBarTheme: _themeData.appBarTheme.copyWith(foregroundColor: value));
  }),
];

void applyAction(CssSelectorType selector, String selectorName, String property, dynamic value) {
  var applications = 0;
  for (var action in cssActions.where((e) =>
      selector == e.cssProperty.selector &&
      selectorName == e.cssProperty.selectorName &&
      property == e.cssProperty.property)) {
    action.cssActionFunction(action.cssProperty, value);
    logger.i('${action.toString()} $value;');
    applications++;
  }
  if (applications == 0) {
    logger.e('CSS action not found: '
        '${cssSelectorCharacterMap[selectorName] ?? ''}$selectorName.$property: $value;');
  }
}
