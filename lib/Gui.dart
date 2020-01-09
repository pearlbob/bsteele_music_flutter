import 'package:bsteele_music_flutter/songs/Section.dart';
import 'package:flutter/material.dart';

class GuiColors {
  static Color getColorForSection(Section section) {
    switch (section.sectionEnum) {
      case SectionEnum.verse:
        return Colors.lightGreen[100];
      case SectionEnum.intro:
        return Colors.orange[100];
      case SectionEnum.preChorus:
        return Colors.blue[100];
      case SectionEnum.chorus:
        return Colors.lightBlue[100];
      case SectionEnum.tag:
        return Colors.blue[200];
      default:
        return Colors.grey[200];
    }
  }
}
