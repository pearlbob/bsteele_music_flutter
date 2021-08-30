import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:csslib/parser.dart' as parser;
import 'package:csslib/visitor.dart' as visitor;
import 'package:flutter/material.dart';

import 'app.dart';

final App _app = App();
const double _defaultFontSize = 24; // fixme: shouldn't be fixed
Color? _defaultBackgroundColor = Colors.white;
Color? _defaultForegroundColor = Colors.black;

ThemeData _themeData = ThemeData(); //  start with the default theme

TextStyle appDropdownListItemTextStyle = //  fixme: find the right place for this!
    const TextStyle(backgroundColor: Colors.white, color: Colors.black, fontSize: _defaultFontSize);

Map<String, List<String>> _propertyLiterals = {
  'text-align': ['left', 'right', 'center', 'justify', 'initial', 'inherit'],
  'font-weight': ['normal', 'bold', 'bolder', 'lighter', 'initial', 'inherit'],
  'border-style': ['dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset', 'outset', 'none', 'hidden'],
};

enum CssSelectorEnum {
  universal, //  *
  element,
  classSelector, //  .class
  id, //  #valueKey
}

const Map<CssSelectorEnum, String> cssSelectorCharacterMap = {
  CssSelectorEnum.universal: '*',
  CssSelectorEnum.element: '',
  CssSelectorEnum.classSelector: '.',
  CssSelectorEnum.id: '#',
};

typedef CssActionFunction = void Function(CssProperty cssProperty, dynamic value);

enum CssClassEnum {
  oddTitleTextStyle,
  evenTitleTextStyle,
  sectionIntro,
  sectionVerse,
  sectionPreChorus,
  sectionChorus,
  sectionA,
  sectionB,
  sectionBridge,
  sectionCoda,
  sectionTag,
  sectionOutro,
  icon,
}

final CssProperty universalBackgroundColorProperty =
    CssProperty(CssSelectorEnum.universal, '*', 'background-color', Color, 'universal background color');
final CssProperty _universalForegroundColorProperty =
    CssProperty(CssSelectorEnum.universal, '*', 'color', Color, 'universal foreground color');
final CssProperty _universalTooltipBackgroundColorProperty = CssProperty(
    CssSelectorEnum.universal, '*', 'tooltip-background-color', Color, 'universal tool tip background color');
final _universalFontSizeProperty =
    CssProperty(CssSelectorEnum.universal, '*', 'font-size', visitor.UnitTerm, 'universal text font size');

final _appbarBackgroundColorProperty =
    CssProperty(CssSelectorEnum.element, 'appbar', 'background-color', Color, 'app bar background color');
final _appbarColorProperty = CssProperty(CssSelectorEnum.element, 'appbar', 'color', Color, 'app bar foreground color');

final _buttonFontScaleProperty =
    CssProperty(CssSelectorEnum.element, 'button', 'font-size', visitor.UnitTerm, 'button text font size');
final _oddTitleTextProperty =
    CssProperty.fromCssClass(CssClassEnum.oddTitleTextStyle, 'background-color', Color, 'odd row background color');
final _evenTitleTextProperty =
    CssProperty.fromCssClass(CssClassEnum.evenTitleTextStyle, 'background-color', Color, 'even row background color');

final _iconColorProperty = CssProperty.fromCssClass(CssClassEnum.icon, 'color', Color, 'icon foreground color');

final _sectionIntroBackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionIntro, 'background-color', Color, 'Intro section background color');
final _sectionVerseBackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionVerse, 'background-color', Color, 'Verse section background color');
final _sectionPreChorusBackgroundProperty = CssProperty.fromCssClass(
    CssClassEnum.sectionPreChorus, 'background-color', Color, 'PreChorus section background color');
final _sectionChorusBackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionChorus, 'background-color', Color, 'Chorus section background color');
final _sectionABackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionA, 'background-color', Color, 'A section background color');
final _sectionBBackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionB, 'background-color', Color, 'B section background color');
final _sectionBridgeBackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionBridge, 'background-color', Color, 'Bridge section background color');
final _sectionCodaBackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionCoda, 'background-color', Color, 'Coda section background color');
final _sectionTagBackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionTag, 'background-color', Color, 'Tag section background color');
final _sectionOutroBackgroundProperty =
    CssProperty.fromCssClass(CssClassEnum.sectionOutro, 'background-color', Color, 'Outro section background color');
const Color _verseColor = Color(0xfff5e6b8);
const Color _chorusColor = Color(0xffffffff);
const Color _bridgeColor = Color(0xffd2f5cd);
const Color _introColor = Color(0xFFcdf5e9);
const Color _preChorusColor = Color(0xffe8e8e8);
const Color _tagColor = Color(0xffcee1f5);

/// used to store values, even those not transferable to a flutter theme
Map<CssProperty, dynamic> _propertyValueLookupMap = {
  //  default values only
  universalBackgroundColorProperty: Colors.white,
  _universalForegroundColorProperty: Colors.black,
  _universalTooltipBackgroundColorProperty: Colors.green[100],
  _universalFontSizeProperty: visitor.ViewportTerm(2, '2', null, parser.TokenKind.UNIT_VIEWPORT_VW),
  _oddTitleTextProperty: Colors.grey[100],
  _evenTitleTextProperty: Colors.white,
  _iconColorProperty: Colors.white,

  _sectionIntroBackgroundProperty: _introColor,
  _sectionVerseBackgroundProperty: _verseColor,
  _sectionPreChorusBackgroundProperty: _preChorusColor,
  _sectionChorusBackgroundProperty: _chorusColor,
  _sectionABackgroundProperty: _verseColor,
  _sectionBBackgroundProperty: _bridgeColor,
  _sectionBridgeBackgroundProperty: _bridgeColor,
  _sectionCodaBackgroundProperty: _introColor,
  _sectionTagBackgroundProperty: _tagColor,
  _sectionOutroBackgroundProperty: _introColor,
};

Color getColorForSection(Section? section) {
  return _getColorForSectionEnum(section?.sectionEnum ?? SectionEnum.chorus);
}

Color _getColorForSectionEnum(SectionEnum sectionEnum) {
  final Map<SectionEnum, CssProperty> sectionMap = {
    SectionEnum.intro: _sectionIntroBackgroundProperty,
    SectionEnum.verse: _sectionVerseBackgroundProperty,
    SectionEnum.preChorus: _sectionPreChorusBackgroundProperty,
    SectionEnum.chorus: _sectionChorusBackgroundProperty,
    SectionEnum.a: _sectionABackgroundProperty,
    SectionEnum.b: _sectionBBackgroundProperty,
    SectionEnum.bridge: _sectionBridgeBackgroundProperty,
    SectionEnum.coda: _sectionCodaBackgroundProperty,
    SectionEnum.tag: _sectionTagBackgroundProperty,
    SectionEnum.outro: _sectionOutroBackgroundProperty,
  };

  var ret = _propertyValueLookupMap[sectionMap[sectionEnum]];
  logger.d('_getColorForSectionEnum: $sectionEnum: $ret');
  return (ret != null && ret is Color) ? ret : Colors.white;
}

Color? _getColor(CssProperty property) {
  var ret = _propertyValueLookupMap[property];
  return (ret != null && ret is Color) ? ret : null;
}

enum AppKeyEnum {
  errorMessage,
  detailLyrics,
  editArtist,
  editCopyright,
  editCoverArtist,
  editEditKeyDropdown,
  editNewChordSection,
  editRepeatX2,
  editRepeatX3,
  editRepeatX4,
  editScaleChord,
  editScaleNote,
  editScreenDetail,
  editSingleChildScrollView,
  editTitle,
  listsClearSearch,
  listsErrorMessage,
  listsNameText,
  listsSearchText,
  listsValueText,
  mainClearSearch,
  mainHamburger,
  mainSearchText,
  optionsKeyOffset0,
  optionsKeyOffset1,
  optionsKeyOffset2,
  optionsKeyOffset3,
  optionsKeyOffset4,
  optionsKeyOffset5,
  optionsKeyOffset6,
  optionsKeyOffset7,
  optionsKeyOffset8,
  optionsKeyOffset9,
  optionsKeyOffset10,
  theoryHalf,
  theoryRoot,
}

class AppKey extends ValueKey {
  AppKey(AppKeyEnum e) : super(Util.enumToString(e)); //  has to be encoded by graphic designer
}

class CssColor extends Color {
  CssColor(int value) : super(0xFF000000 + value);

  String toCss() {
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}

Icon appIcon(IconData icon, {Key? key, Color? color}) {
  return Icon(icon, key: key, color: color ?? _getColor(_iconColorProperty));
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
              CssSelectorEnum cssSelector;
              switch (selector.simpleSelector.runtimeType) {
                case visitor.ClassSelector:
                  cssSelector = CssSelectorEnum.classSelector;
                  break;
                case visitor.ElementSelector:
                  cssSelector =
                      selector.simpleSelector.name == '*' ? CssSelectorEnum.universal : CssSelectorEnum.element;
                  break;
                case visitor.IdSelector:
                  cssSelector = CssSelectorEnum.id;
                  break;

                default:
                  cssSelector = CssSelectorEnum.element;
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
                          applyAction(cssSelector, selector.simpleSelector.name, property, CssColor(i),
                              rawValue: hexColorTerm.span?.text);
                        } else if (hexColorTerm.value is int) {
                          int i = hexColorTerm.value;
                          applyAction(cssSelector, selector.simpleSelector.name, property, CssColor(i),
                              rawValue: hexColorTerm.span?.text);
                        } else {
                          logger.e('Not understood: HexColorTerm: '
                              '${hexColorTerm.runtimeType} ${hexColorTerm.value} ${hexColorTerm.toString()}');
                        }
                      } else if (exp is visitor.ViewportTerm) {
                        var viewportTerm = exp;
                        applyAction(cssSelector, selector.simpleSelector.name, property, viewportTerm);
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
      }
    }

    _logActions();

    {
      var iconTheme = IconThemeData(color: _defaultForegroundColor);
      var radioTheme = RadioThemeData(fillColor: MaterialStateProperty.all(_defaultForegroundColor));
      var elevatedButtonThemeStyle = _themeData.elevatedButtonTheme.style ?? const ButtonStyle();
      elevatedButtonThemeStyle = elevatedButtonThemeStyle.copyWith(elevation: MaterialStateProperty.all(6));

      _themeData = _themeData.copyWith(
        backgroundColor: _propertyValueLookupMap[universalBackgroundColorProperty],
        iconTheme: iconTheme,
        primaryColor: _propertyValueLookupMap[universalBackgroundColorProperty],
        radioTheme: radioTheme,
        elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonThemeStyle),
      );
    }
  }

  void _logActions() {
    SplayTreeSet<CssProperty> properties = SplayTreeSet();
    for (var appliedAction in _appliedActions) {
      properties.add(appliedAction.cssAction.cssProperty);
    }
    properties.addAll(_propertyValueLookupMap.keys);

    for (var property in properties) {
      var value = _propertyValueLookupMap[property];
      if (value == null) {
        var appliedAction = _appliedActions.firstWhere((e) => identical(property, e.cssAction.cssProperty));
        logger.i('applied: ${appliedAction.cssAction.cssProperty.id}:'
            ' ${appliedAction.rawValue ?? appliedAction.value};'
            '    /* ${appliedAction.cssAction.cssProperty.type} */');
      } else {
        logger.i('lookup: $property $value;'
            '    /* ${property.type} */');
      }
    }
  }

  final RegExp _threeDigitHexRegExp = RegExp(r'^[\da-fA-f]{3}$');
}

@Deprecated('bad exposure')
Color? appbarColor() {
  // fixme: appbarColor()
  return _getColor(_appbarColorProperty);
}

Color? lookupCssClassColor(CssClassEnum e, String propertyName) {
  var propertyPath = '${cssSelectorCharacterMap[CssSelectorEnum.classSelector]}'
      '${Util.enumToString(e)}.$propertyName';
  var ret = _propertyValueLookupMap[propertyPath];
  return ret is Color ? ret : null;
}

double? _fontSizeLookup(CssProperty property) {
  var value = _propertyValueLookupMap[property];
  if (value == null) {
    return null;
  }
  switch (value.runtimeType) {
    case visitor.LengthTerm:
      var term = value as visitor.LengthTerm;
      switch (term.unit) {
        case parser.TokenKind.UNIT_LENGTH_PX:
          return term.value.toDouble();
        default:
          return null;
      }
    case visitor.ViewportTerm:
      var term = value as visitor.ViewportTerm;
      return term.value * _app.screenInfo.widthInLogicalPixels / 100; //  ie. dynamically mapped into pixels
    default:
      return null;
  }
}

ElevatedButton appButton(
  String commandName, {
  Key? key,
  Color? backgroundColor,
  double? fontSize,
  required VoidCallback? onPressed,
}) {
  fontSize ??= _fontSizeLookup(_buttonFontScaleProperty) ?? _fontSizeLookup(_universalFontSizeProperty);
  return ElevatedButton(
    key: key,
    child: Text(commandName,
        style: _themeData.elevatedButtonTheme.style?.textStyle?.resolve({}) ?? TextStyle(fontSize: fontSize)),
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
/// Creates the app's text style.
///
/// The `package` argument must be non-null if the font family is defined in a
/// package. It is combined with the `fontFamily` argument to set the
/// [fontFamily] property.

TextStyle generateAppTextStyle({
  Color? color,
  Color? backgroundColor,
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  TextBaseline? textBaseline,
  String? fontFamily,
}) {
  fontSize ??= _fontSizeLookup(_universalFontSizeProperty) ?? _themeData.textTheme.bodyText2?.fontSize;
  return TextStyle(
    color: color ?? _themeData.textTheme.bodyText2?.color ?? _defaultForegroundColor,
    backgroundColor: backgroundColor ?? _themeData.textTheme.bodyText2?.backgroundColor ?? _defaultBackgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    textBaseline: textBaseline,
    fontFamily: fontFamily,
  );
}

TextStyle oddTitleTextStyle({TextStyle? from}) {
  return (from ?? generateAppTextStyle()).copyWith(backgroundColor: _propertyValueLookupMap[_oddTitleTextProperty]);
}

TextStyle evenTitleTextStyle({TextStyle? from}) {
  return (from ?? generateAppTextStyle()).copyWith(backgroundColor: _propertyValueLookupMap[_evenTitleTextProperty]);
}

@immutable
class CssProperty implements Comparable<CssProperty> {
  CssProperty(this.selector, this.selectorName, this.property, this.type, this.description)
      : _id = '${cssSelectorCharacterMap[selector] ?? ''}${selector == CssSelectorEnum.universal ? '' : selectorName}'
            '.$property';

  CssProperty.fromCssClass(CssClassEnum cssClass, this.property, this.type, this.description)
      : selector = CssSelectorEnum.classSelector,
        selectorName = Util.enumToString(cssClass),
        _id = '${cssSelectorCharacterMap[cssSelectorCharacterMap[CssSelectorEnum.classSelector]] ?? ''}'
            '${Util.enumToString(cssClass)}.$property';

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
    return '$id:';
  }

  final CssSelectorEnum selector;
  final String selectorName;
  final String property;
  final Type type;
  final String description;

  String get id => _id;
  final String _id;
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

@immutable
class _AppliedAction {
  const _AppliedAction(this.cssAction, this.value, {this.rawValue});

  @override
  String toString() {
    return '$cssAction ${rawValue ?? value};';
  }

  final CssAction cssAction;
  final dynamic value;
  final String? rawValue;
}

void generateCssDocumentation() {
  logger.i('CssToCssFile:');

  var sb = StringBuffer('''
/*
  bsteele Music App CSS style commands documentation
  
  Commands are listed in increasing priority order.
*/

''');
  CssSelectorEnum lastSelector = CssSelectorEnum.id;
  String lastSelectorName = '';
  SplayTreeSet<CssAction> sortedActions = SplayTreeSet();
  sortedActions.addAll(cssActions);
  for (var cssAction in sortedActions) {
    if (cssAction.cssProperty.selector != lastSelector || cssAction.cssProperty.selectorName != lastSelectorName) {
      if (lastSelectorName.isNotEmpty) {
        sb.writeln('}\n');
      }
      lastSelector = cssAction.cssProperty.selector;
      lastSelectorName = cssAction.cssProperty.selectorName;
      sb.writeln('${cssAction.cssProperty.selectorName} {');
    }
    var property = cssAction.cssProperty;
    var value = _propertyValueLookupMap[property] ?? 'unknown value';
    String valueString = value.toString();
    switch (value.runtimeType) {
      case CssColor:
        valueString = value.toCss();
        break;
    }
    sb.writeln('  ${property.property}: $valueString;'
        '\t\t\t/* type is ${property.type}, ${property.description} */');

    switch (value.runtimeType) {
      case visitor.LengthTerm:
        sb.writeln('  /* NOTE: the use of non-reactive font sizes is strongly discouraged\n'
            '     due to the many screen sizes required of the application.\n'
            '     Try using viewport (vw) instead.  E.g.: 2.2vw  */');
        break;
    }
  }
  if (lastSelectorName.isNotEmpty) {
    sb.writeln('}\n');
  }
  logger.i(sb.toString());
}

List<_AppliedAction> _appliedActions = [];

TextStyle? _textStyleActionStyle(CssProperty p, dynamic value, TextStyle? defaultTextStyle) {
  TextStyle? textStyle;
  switch (value.runtimeType) {
    case visitor.LengthTerm:
      textStyle = defaultTextStyle ?? TextStyle(fontSize: value);
      var term = value as visitor.LengthTerm;
      switch (term.unit) {
        case parser.TokenKind.UNIT_LENGTH_PX:
          textStyle = textStyle.copyWith(fontSize: double.parse(term.text));
          break;
        default:
          logger.e('ERROR: ${p.toString()} assigned wrong unit type: ${term.unit}, see parser.TokenKind ');
          return textStyle;
      }
      break;
    case visitor.ViewportTerm:
      _propertyValueLookupMap[p] = value;
      return const TextStyle(
          fontSize: 18.0, color: Colors.black); //  make the theme based widgets happy, i.e. flutter markdown
    default:
      logger.e('ERROR: ${p.toString()} assigned wrong value type: ${value.runtimeType}');
      return null;
  }
  return textStyle;
}

List<CssAction> cssActions = [
  //  universal
  CssAction(universalBackgroundColorProperty, (p, value) {
    assert(value is Color);
    _defaultBackgroundColor = value; //fixme:
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_universalForegroundColorProperty, (p, value) {
    assert(value is Color);
    _defaultForegroundColor = value; //fixme:
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_universalTooltipBackgroundColorProperty, (p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_universalFontSizeProperty, (p, value) {
    //  fixme: textThemes are not complete
    //  fixme: textThemes are identical!
    TextStyle? textStyle =
        _textStyleActionStyle(p, value, _themeData.textTheme.bodyText1 ?? _themeData.textTheme.bodyText2);
    var textTheme = TextTheme(
      bodyText1: textStyle,
      bodyText2: textStyle,
      button: _themeData.textTheme.button,
    );
    _themeData = _themeData.copyWith(textTheme: textTheme);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(
      CssProperty(
          CssSelectorEnum.element, 'button', 'background-color', Color, 'universal (elevated) button background color'),
      (CssProperty p, value) {
    assert(value is Color);
    _themeData = _themeData.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: (_themeData.elevatedButtonTheme.style == null
                ? ElevatedButton.styleFrom(primary: value)
                : _themeData.elevatedButtonTheme.style!.copyWith(backgroundColor: MaterialStateProperty.all(value)))));
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(
      CssProperty(CssSelectorEnum.element, 'button', 'color', Color, 'universal (elevated) button foreground color'),
      (CssProperty p, value) {
    assert(value is Color);
    _themeData = _themeData.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: (_themeData.elevatedButtonTheme.style == null
                ? ElevatedButton.styleFrom(onPrimary: value)
                : _themeData.elevatedButtonTheme.style!.copyWith(foregroundColor: MaterialStateProperty.all(value)))));
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_buttonFontScaleProperty, (CssProperty p, value) {
    //  fixme: textThemes are not complete
    //  fixme: textThemes are identical!
    TextStyle? textStyle = _textStyleActionStyle(p, value, _themeData.textTheme.button);
    var textTheme = TextTheme(
      bodyText1: _themeData.textTheme.bodyText1,
      bodyText2: _themeData.textTheme.bodyText2,
      button: textStyle,
    );
    _themeData = _themeData.copyWith(textTheme: textTheme);
    _propertyValueLookupMap[p] = value;
  }),

  CssAction(_appbarBackgroundColorProperty, (CssProperty p, value) {
    assert(value is Color);
    _themeData = _themeData.copyWith(appBarTheme: _themeData.appBarTheme.copyWith(backgroundColor: value));
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_appbarColorProperty, (CssProperty p, value) {
    assert(value is Color);
    _themeData = _themeData.copyWith(appBarTheme: _themeData.appBarTheme.copyWith(foregroundColor: value));
    _propertyValueLookupMap[p] = value;
  }),

  CssAction(_oddTitleTextProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_evenTitleTextProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionIntroBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionIntroBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionVerseBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionPreChorusBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionChorusBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionABackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionBBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionBridgeBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionCodaBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionTagBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_sectionOutroBackgroundProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
  CssAction(_iconColorProperty, (CssProperty p, value) {
    assert(value is Color);
    _propertyValueLookupMap[p] = value;
  }),
];

void applyAction(
  CssSelectorEnum selector,
  String selectorName,
  String property,
  dynamic value, {
  String? rawValue,
}) {
  var applications = 0;
  for (var action in cssActions.where((e) =>
      selector == e.cssProperty.selector &&
      selectorName == e.cssProperty.selectorName &&
      property == e.cssProperty.property)) {
    action.cssActionFunction(action.cssProperty, value);
    _appliedActions.add(_AppliedAction(action, value, rawValue: rawValue));
    logger.v('${action.toString()} /*${value.runtimeType}*/ $value;');
    applications++;
  }
  if (applications == 0) {
    logger.e('CSS action not found: '
        '${cssSelectorCharacterMap[selector] ?? ''}$selectorName.$property: $value;');
  }
}
