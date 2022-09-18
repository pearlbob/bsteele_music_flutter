import 'dart:collection';

import 'package:bsteele_music_flutter/screens/player.dart';

import '../app/app.dart';
import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

//  persistent selection
final SplayTreeSet<NameValue> _filterNameValues = SplayTreeSet();

class PlayList extends StatefulWidget {
  PlayList({super.key, SplayTreeSet<Song>? songs, this.style})
      : songs = (songs ?? app.allSongs).toList(growable: false);

  @override
  State<StatefulWidget> createState() {
    return _PlayListState();
  }

  final List<Song> songs;
  final TextStyle? style;
}

class _PlayListState extends State<PlayList> {
  @override
  Widget build(BuildContext context) {
    var titleStyle = widget.style;
    var fontSize = 0.75 * (widget.style?.fontSize ?? appDefaultFontSize);
    var artistStyle = titleStyle?.copyWith(fontSize: fontSize, fontWeight: FontWeight.normal);

    final oddTitle = oddTitleTextStyle(from: titleStyle);
    final evenTitle = evenTitleTextStyle(from: titleStyle);
    final oddText = oddTitleTextStyle(from: artistStyle);
    final evenText = evenTitleTextStyle(from: artistStyle);

    //  find all the metadata values
    SplayTreeSet<NameValue> nameValues = SplayTreeSet();
    for (var id in SongMetadata.where()) {
      nameValues.addAll(id.nameValues);
    }

    //  generate list of current filters
    List<Widget> filterWidgets = [];
    for (var nv in _filterNameValues) {
      filterWidgets.add(
        appIconButton(
          icon: appIcon(
            Icons.clear,
          ),
          label: '${nv.name}: ${nv.value}',
          fontSize: fontSize,
          appKeyEnum: AppKeyEnum.playListMetadataRemove,
          value: nv,
          onPressed: () {
            setState(() {
              logger.i('remove: ${nv.name}: ${nv.value}');
              _filterNameValues.remove(nv);
            });
          },
        ),
      );
    }

    //  create drop down list of name/values not in use in the filter
    const allNameValue = NameValue('All', '');
    List<DropdownMenuItem<NameValue>> dropdownMenuItems = [];
    dropdownMenuItems.add(appDropdownMenuItem<NameValue>(
        appKeyEnum: AppKeyEnum.playListFilter,
        value: allNameValue,
        child: Text(
          'Filters:',
          style: artistStyle,
        )));
    for (var nv in nameValues) {
      logger.v('$nv');
      //  skip existing filters
      if (_filterNameValues.contains(nv)) {
        continue;
      }
      var nvString = '${nv.name}: ${nv.value}';
      dropdownMenuItems.add(appDropdownMenuItem<NameValue>(
          appKeyEnum: AppKeyEnum.playListFilter,
          value: nv,
          child: Text(
            nvString,
            style: artistStyle,
          )));
    }

    List<Song> filteredSongs = []; //  note: songs will be in order since they are feed by a sorted set
    if (_filterNameValues.isEmpty) {
      //  apply no filter
      filteredSongs.addAll(widget.songs);
    } else {
      //  filter the songs for the correct metadata
      for (var song in widget.songs) {
        var matched = true;
        var idString = song.songId.toString();
        for (var nv in _filterNameValues) {
          if (SongMetadata.where(idIs: idString, nameIs: nv.name, valueIs: nv.value).isEmpty) {
            matched = false;
            break;
          }
        }
        if (matched) {
          filteredSongs.add(song);
        }
      }
    }

    return Expanded(
      // for some reason, this is Expanded is very required,
      // otherwise the Column is unlimited and the list view fails
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppWrapFullWidth(spacing: fontSize, children: [
            DropdownButton<NameValue?>(
              value: null,
              hint: Text('Filters:', style: artistStyle),
              items: dropdownMenuItems,
              style: artistStyle,
              onChanged: (value) {
                setState(() {
                  if (value != null) {
                    setState(() {
                      logger.i('fixme: DropdownButton<NameValue?>: $value');
                      if (value == allNameValue) {
                        _filterNameValues.clear();
                      } else {
                        _filterNameValues.add(value);
                      }
                    });
                  }
                });
              },
              itemHeight: null,
            ),
            ...filterWidgets
          ]),
          const AppSpace(),
          Expanded(
            child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredSongs.length,
                itemBuilder: (BuildContext context, int index) {
                  logger.v('_PlayListState: index: $index');
                  var indexTitleStyle = (index & 1) == 1 ? oddTitle : evenTitle;
                  var indexTextStyle = (index & 1) == 1 ? oddText : evenText;
                  var song = filteredSongs[index];

                  List<Widget> metadataWidgets = [const AppSpace()];
                  if (isEditing) {
                    for (var id in SongMetadata.where(idIs: song.songId.toString())) {
                      logger.i('$index: $song: ${id.id}: md#: ${id.nameValues.length}');
                      for (var nv in id.nameValues) {
                        metadataWidgets.add(
                          appButton(
                            '${nv.name}: ${nv.value}',
                            appKeyEnum: AppKeyEnum.playListMetadata,
                            value: '${id.id}:${nv.name}=${nv.value}',
                            fontSize: fontSize,
                            onPressed: () {
                              logger.i('pressed: ${nv.name}: ${nv.value}');
                            },
                          ),
                        );
                      }
                    }
                  }

                  return AppInkWell(
                    appKeyEnum: AppKeyEnum.mainSong,
                    value: Id(song.songId.toString()),
                    onTap: () {
                      if (!isEditing) {
                        _navigateToPlayer(context, song);
                      }
                    },
                    child: Container(
                      color: indexTextStyle.backgroundColor,
                      padding: const EdgeInsets.all(5.0),
                      child: AppWrapFullWidth(
                        spacing: fontSize,
                        alignment: isEditing ? WrapAlignment.start : WrapAlignment.spaceBetween,
                        children: [
                          AppWrap(children: [
                            Text(
                              song.title,
                              style: indexTitleStyle,
                            ),
                            Text(
                              '  by ${song.artist}',
                              style: indexTextStyle,
                            ),
                            if (song.coverArtist.isNotEmpty)
                              Text(
                                ', cover by ${song.coverArtist}',
                                style: indexTextStyle,
                              ),
                          ]),
                          AppWrap(spacing: fontSize, children: [
                            if (!isEditing)
                              Text(
                                '   ${intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime))}',
                                style: indexTextStyle,
                              ),
                            if (isEditing) ...metadataWidgets
                          ]),
                        ],
                      ),
                    ),
                  );
                }),
          ),
        ]),
      ),
    );
  }

  _navigateToPlayer(BuildContext context, Song song) async {
    if (song.getTitle().isEmpty) {
      // logger.log(_mainLogScroll, 'song title is empty: $song');
      return;
    }
    app.clearMessage();
    app.selectedSong = song;
    //_lastSelectedSong = song;

    //logger.log(_mainLogScroll, '_navigateToPlayer: pushNamed: $song');
    await Navigator.pushNamed(
      context,
      Player.routeName,
    );

    _reApplySearch();
  }

  void _reApplySearch() {
    setState(() {
      // _selectSearchText(context); //  select all text on a navigation pop
    });
  }

  bool isEditing = false;
}
