import 'package:bsteele_music_flutter/songs/Section.dart';
import 'package:flutter/material.dart';

class GuiColors {
  static Color getColorForSection(Section section) {
    switch (section.sectionEnum) {
      case SectionEnum.verse:
        return Colors.grey[300];
      case SectionEnum.intro:
        return Colors.orange[100];
      case SectionEnum.preChorus:
        return Colors.blue[100];
      case SectionEnum.chorus:
        return Colors.white;
      case SectionEnum.tag:
        return Colors.blue[200];
      case SectionEnum.a:
        return Colors.purple[100];
      case SectionEnum.b:
        return Colors.teal[100];
      case SectionEnum.bridge:
        return Colors.green[100];
      case SectionEnum.coda:
        return Colors.yellow[100];
      case SectionEnum.outro:
        return Colors.lightBlue[100];
      default:
        return Colors.grey[200];
    }
  }
}


