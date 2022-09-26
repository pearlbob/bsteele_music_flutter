import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/popupSubMenuItem.dart';
import 'package:flutter/material.dart';

class MetadataPopupMenuButton {
  static Widget button({final String? title, TextStyle? style}) {
    style = style ?? generateAppTextStyle();
    return PopupMenuButton<NameValue>(
      //initialValue: const NameValue('name0', 'value0'),
      tooltip: '', //'Parent menu',
      onSelected: (value) {
        logger.i('selected parent: $value');
      },
      itemBuilder: (BuildContext context) {
        //  find all name/values in use
        SplayTreeSet<NameValue> nameValues = SplayTreeSet();
        for (var songIdMetadata in SongMetadata.idMetadata) {
          nameValues.addAll(songIdMetadata.nameValues);
        }
        logger.v('lists.build: ${SongMetadata.idMetadata}');
        SplayTreeSet<String> names = SplayTreeSet()..addAll(nameValues.map((e) => e.name));

        List<PopupMenuEntry<NameValue>> items = [];
        var fontSize = style!.fontSize ?? appDefaultFontSize;
        var offset = Offset(fontSize * 4, fontSize / 2);
        for (var name in names) {
          items.add(PopupSubMenuItem<NameValue>(
            title: name,
            items: nameValues.where((e) => e.name == name).toList(growable: false),
            itemLabelFunction: (e) => e.value.isNotEmpty ? e.value : e.toShortString(),
            style: style,
            offset: offset,
            onSelected: (value) {
              logger.i('selected: $value');
            },
          ));
        }
        return items;
      },
      //initialValue: const NameValue('name0', 'value0'),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            title ?? 'Metadata selection',
            style: style,
          ),
          Icon(
            Icons.arrow_drop_down_sharp,
            size: (style.fontSize ?? appDefaultFontSize) * 2,
          ),
        ],
      ),
    );
  }
}
