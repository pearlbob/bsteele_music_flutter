import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:flutter/material.dart';

/// GUI colors for the song sections.
/// Note that they are very pastel to allow the font to always be quite visible.
class GuiColors {
  static Color getColorForSection(Section? section) {
    return getColorForSectionEnum(section?.sectionEnum ?? SectionEnum.chorus);
  }

  static Color getColorForSectionEnum(SectionEnum sectionEnum) {
    Color? ret;

    switch (sectionEnum) {
      case SectionEnum.verse:
        ret = verseColor;
        break;
      case SectionEnum.intro:
        ret = introColor;
        break;
      case SectionEnum.preChorus:
        ret = tagColor;
        break;
      case SectionEnum.chorus:
        ret = chorusColor;
        break;
      case SectionEnum.tag:
        ret = tagColor;
        break;
      case SectionEnum.a:
        ret = verseColor;
        break;
      case SectionEnum.b:
        ret = bridgeColor;
        break;
      case SectionEnum.bridge:
        ret = bridgeColor;
        break;
      case SectionEnum.coda:
        ret = introColor;
        break;
      case SectionEnum.outro:
        ret = introColor;
        break;
      default:
        ret = Colors.grey[300];
    }

    return ret ?? const Color(0xFFE0E0E0); //  safety
  }

  static const Color verseColor = Color(0xfff5e6b8);
  static const Color chorusColor = Color(0xffffffff);
  static const Color bridgeColor = Color(0xffd2f5cd);
  static const Color introColor = Color(0xFFcdf5e9);
  static const Color preChorusColor = Color(0xffe8e8e8);
  static const Color tagColor = Color(0xffcee1f5);
}
