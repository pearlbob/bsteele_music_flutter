import 'package:flutter/material.dart';
import 'dart:ui' as ui
    show
        // ParagraphStyle,
        // TextStyle,
        // StrutStyle,
        // lerpDouble,
        Shadow,
        FontFeature,
        //   TextHeightBehavior,
        TextLeadingDistribution;

const List<String> appFontFamilyFallback=  [
  //'Roboto',
  'DejaVu'
  //'Bravura',  // music symbols are over sized in the vertical
];

@immutable
class AppTextStyle extends TextStyle {
  /// Creates the app's text style.
  ///
  /// The `package` argument must be non-null if the font family is defined in a
  /// package. It is combined with the `fontFamily` argument to set the
  /// [fontFamily] property.
  const AppTextStyle({
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
    ui.TextLeadingDistribution? leadingDistribution,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
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
          color: color,
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
          fontFeatures: fontFeatures,
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
