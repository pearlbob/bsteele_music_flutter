import 'dart:collection';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/song_metadata.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/popupSubMenuItem.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

const Level _logLists = Level.debug;
const Level _logItems = Level.debug;
const Level _logSelected = Level.debug;

class MetadataPopupMenuButton {
  static Widget button({
    final String? title,
    TextStyle? style,
    PopupMenuItemSelected<NameValueMatcher>? onSelected,
    bool showAllValues = true,
    bool showAllFilters = false,
  }) {
    style = style ?? generateAppTextStyle();
    return PopupMenuButton<NameValueMatcher>(
      tooltip: '', //'Parent menu',
      onSelected: (value) {
        logger.i('selected parent: $value'); //fixme: not used
      },
      itemBuilder: (BuildContext context) {
        //  find all name/values in use
        SplayTreeSet<NameValue> nameValues = SplayTreeSet();
        for (var songIdMetadata in SongMetadata.idMetadata) {
          nameValues.addAll(
              songIdMetadata.nameValues.where((nv) => showAllValues || !SongMetadataGeneratedValue.isGenerated(nv)));
        }
        logger.log(_logLists, 'lists.build: ${SongMetadata.idMetadata}');
        SplayTreeSet<String> names = SplayTreeSet()..addAll(nameValues.map((e) => e.name));

        //  make entry items from the names
        List<PopupMenuEntry<NameValueMatcher>> entryItems = [];
        var fontSize = style!.fontSize ?? appDefaultFontSize;
        var offset = Offset(fontSize * 4, fontSize / 2);
        for (var name in names) {
          List<NameValueMatcher> matcherItems =
              nameValues.where((e) => e.name == name).map((e) => NameValueMatcher.value(e)).toList(growable: true);
          if (showAllFilters) {
            matcherItems.add(NameValueMatcher.anyValue(name));
            matcherItems.add(NameValueMatcher.noValue(name));
          }
          var item = PopupSubMenuItem<NameValueMatcher>(
            title: name,
            items: matcherItems,
            style: style,
            offset: offset,
            onSelected: onSelected ??
                (value) {
                  logger.log(_logSelected, 'selected: $value');
                },
          );
          logger.log(_logItems, '   items: ${item.items}');
          entryItems.add(item);
        }
        return entryItems;
      },

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
