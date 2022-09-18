import 'dart:collection';

import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/screens/player.dart';

import '../app/app.dart';
import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../util/songSearchMatcher.dart';

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
  _PlayListState() : _searchFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    var titleStyle = widget.style ?? generateAppTextStyle();
    var titleFontSize = widget.style?.fontSize ?? appDefaultFontSize;
    var fontSize = 0.75 * titleFontSize;
    var artistStyle = titleStyle.copyWith(fontSize: fontSize, fontWeight: FontWeight.normal);

    final oddTitle = oddTitleTextStyle(from: titleStyle);
    final evenTitle = evenTitleTextStyle(from: titleStyle);
    final oddText = oddTitleTextStyle(from: artistStyle);
    final evenText = evenTitleTextStyle(from: artistStyle);

    final TextStyle searchDropDownStyle = artistStyle;
    final TextStyle searchTextStyle = titleStyle.copyWith(
      color: Colors.black45,
      fontWeight: FontWeight.bold,
      // textBaseline: TextBaseline.alphabetic,
    );

    //  generate the sort selection
    _sortTypesDropDownMenuList.clear();
    for (final e in MainSortType.values) {
      var s = e.toString();
      _sortTypesDropDownMenuList.add(appDropdownMenuItem<MainSortType>(
        appKeyEnum: AppKeyEnum.mainSortTypeSelection,
        value: e,
        child: Text(
          Util.camelCaseToLowercaseSpace(s.substring(s.indexOf('.') + 1)),
          style: searchDropDownStyle,
        ),
      ));
    }

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

    // select order
    int Function(Song key1, Song key2)? compare;
    switch (_selectedSortType) {
      case MainSortType.byArtist:
        compare = (Song song1, Song song2) {
          var ret = song1.artist.compareTo(song2.artist);
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byLastChange:
        compare = (Song song1, Song song2) {
          var ret = -song1.lastModifiedTime.compareTo(song2.lastModifiedTime);
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byComplexity:
        compare = (Song song1, Song song2) {
          var ret = song1.getComplexity().compareTo(song2.getComplexity());
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byYear:
        compare = (Song song1, Song song2) {
          var ret = song1.getCopyrightYear().compareTo(song2.getCopyrightYear());
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byTitle:
      default:
        compare = (Song song1, Song song2) {
          return song1.compareTo(song2);
        };
        break;
    }

    List<Song> filteredSongs = [];
    {
      //  apply search
      SplayTreeSet<Song> searchedSet = SplayTreeSet();
      var matcher = SongSearchMatcher(_searchTextFieldController.text);
      for (final Song song in app.allSongs) {
        if (matcher.matchesOrEmptySearch(song)) {
          searchedSet.add(song);
        }
      }

      //  apply filters and order
      SplayTreeSet<Song> filteredSet = SplayTreeSet(compare);
      if (_filterNameValues.isEmpty) {
        //  apply no filter
        filteredSet.addAll(searchedSet);
      } else {
        //  filter the songs for the correct metadata
        for (var song in searchedSet) {
          var matched = true;
          var idString = song.songId.toString();
          for (var nv in _filterNameValues) {
            if (SongMetadata.where(idIs: idString, nameIs: nv.name, valueIs: nv.value).isEmpty) {
              matched = false;
              break;
            }
          }
          if (matched) {
            filteredSet.add(song);
          }
        }
      }
      filteredSongs.addAll(filteredSet);
    }

    return Expanded(
      // for some reason, this is Expanded is very required,
      // otherwise the Column is unlimited and the list view fails
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppWrapFullWidth(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                AppWrap(children: [
                  //  search icon
                  AppTooltip(
                    message: _searchTextTooltipText,
                    child: IconButton(
                      icon: const Icon(Icons.search),
                      iconSize: titleFontSize,
                      onPressed: (() {
                        setState(() {
                          //fixme: _searchSongs(_searchTextFieldController.text);
                        });
                      }),
                    ),
                  ),
                  //  search text
                  SizedBox(
                    width: 12 * fontSize,
                    //  limit text entry display length
                    child: TextField(
                      key: appKey(AppKeyEnum.mainSearchText),
                      //  for testing
                      controller: _searchTextFieldController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'enter search text',
                        hintStyle: searchTextStyle,
                      ),
                      autofocus: true,
                      style: searchTextStyle,
                      onChanged: (text) {
                        setState(() {
                          logger.v('search text: "$text"');
                          //_searchSongs(_searchTextFieldController.text);
                          app.clearMessage();
                        });
                      },
                    ),
                  ),
                  //  search clear
                  AppTooltip(
                      message:
                          _searchTextFieldController.text.isEmpty ? 'Scroll the list some.' : 'Clear the search text.',
                      child: appEnumeratedIconButton(
                        icon: const Icon(Icons.clear),
                        appKeyEnum: AppKeyEnum.mainClearSearch,
                        iconSize: 1.25 * titleFontSize,
                        onPressed: (() {
                          _searchTextFieldController.clear();
                          app.clearMessage();
                          setState(() {
                            FocusScope.of(context).requestFocus(_searchFocusNode);
                            //_lastSelectedSong = null;
                          });
                        }),
                      )),
                  const AppSpace(
                    spaceFactor: 2.0,
                  ),
                  //  filters
                  AppWrap(spacing: fontSize, children: [
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
                    ...filterWidgets,
                  ]),
                ]),

                //  filters and order
                AppWrap(spacing: fontSize, alignment: WrapAlignment.spaceBetween, children: [
                  //  filters and order
                  if (app.isScreenBig)
                    AppWrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: app.screenInfo.fontSize / 2,
                      children: [
                        AppTooltip(
                          message: 'Select the order of the song list.',
                          child: Text(
                            'Order',
                            style: searchDropDownStyle,
                          ),
                        ),
                        appDropdownButton<MainSortType>(
                          AppKeyEnum.mainSortType,
                          _sortTypesDropDownMenuList,
                          onChanged: (value) {
                            if (_selectedSortType != value) {
                              setState(() {
                                _selectedSortType = value ?? MainSortType.byTitle;
                                app.clearMessage();
                              });
                            }
                          },
                          value: _selectedSortType,
                          style: searchDropDownStyle,
                        ),
                      ],
                    ),
                ]),
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

    setState(() {
      _selectSearchText(context); //  select all text on a navigation pop
    });
  }

  void _selectSearchText(BuildContext context) {
    _searchTextFieldController.selection =
        TextSelection(baseOffset: 0, extentOffset: _searchTextFieldController.text.length);
    FocusScope.of(context).requestFocus(_searchFocusNode);
    logger.i('_selectSearchText: ${_searchTextFieldController.selection}');
  }

  bool isEditing = false;

  final List<DropdownMenuItem<MainSortType>> _sortTypesDropDownMenuList = [];
  var _selectedSortType = MainSortType.byTitle;

  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode;
  static const _searchTextTooltipText = 'Enter search text here.\n Title, artist and cover artist will be searched.';
}
