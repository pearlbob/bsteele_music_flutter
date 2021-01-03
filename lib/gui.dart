import 'package:bsteeleMusicLib/songs/section.dart';
import 'package:flutter/material.dart';

class GuiColors {
  static Color getColorForSection(Section? section) {
    return getColorForSectionEnum(section?.sectionEnum ?? SectionEnum.chorus);
  }

  static Color getColorForSectionEnum(SectionEnum sectionEnum) {
    Color? ret;

    switch (sectionEnum) {
      case SectionEnum.verse:
        ret = Colors.grey[300];
        break;
      case SectionEnum.intro:
        ret = Colors.orange[100];
        break;
      case SectionEnum.preChorus:
        ret = Colors.blue[100];
        break;
      case SectionEnum.chorus:
        ret = Colors.grey[100];
        break;
      case SectionEnum.tag:
        ret = Colors.blue[100];
        break;
      case SectionEnum.a:
        ret = Colors.purple[100];
        break;
      case SectionEnum.b:
        ret = Colors.teal[100];
        break;
      case SectionEnum.bridge:
        ret = Colors.green[100];
        break;
      case SectionEnum.coda:
        ret = Colors.yellow[100];
        break;
      case SectionEnum.outro:
        ret = Colors.lightBlue[100];
        break;
      default:
        ret = Colors.grey[300];
    }

    return ret ?? Color(0xFFE0E0E0); //  safety
  }
}
