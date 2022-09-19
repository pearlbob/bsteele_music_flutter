import 'dart:collection';

import 'package:bsteeleMusicLib/songs/songPerformance.dart';
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

bool _isEditing = false;
double _textFontSize = appDefaultFontSize;
late TextStyle _indexTitleStyle;
late TextStyle _indexTextStyle;

typedef SongItemAction = Function(Song song);

/// Allow the mechanics to use either a song or a song performance
class _SongItem implements Comparable<_SongItem> {
  _SongItem(this.song) : songPerformance = null;

  _SongItem.fromPerformance(this.songPerformance) : song = songPerformance!.song!;

  Widget toWidget(SongItemAction songItemAction) {
    AppWrap appWrap;
    if (songPerformance != null) {
      appWrap = AppWrap(children: [
        Text(
          '${songPerformance!.singer} sang: ',
          style: _indexTextStyle,
        ),
        Text(
          song.title,
          style: _indexTitleStyle,
        ),
        Text(
          '  by ${song.artist}',
          style: _indexTextStyle,
        ),
        if (song.coverArtist.isNotEmpty)
          Text(
            ', cover by ${song.coverArtist}',
            style: _indexTextStyle,
          ),
        Text(
          ' in ${songPerformance!.key}',
          style: _indexTextStyle,
        ),
      ]);
    } else {
      //  song
      appWrap = AppWrap(children: [
        Text(
          song.title,
          style: _indexTitleStyle,
        ),
        Text(
          '  by ${song.artist}',
          style: _indexTextStyle,
        ),
        if (song.coverArtist.isNotEmpty)
          Text(
            ', cover by ${song.coverArtist}',
            style: _indexTextStyle,
          ),
      ]);
    }

    List<Widget> metadataWidgets = [const AppSpace()];
    if (_isEditing) {
      for (var id in SongMetadata.where(idIs: song.songId.toString())) {
        logger.i('$this: ${id.id}: md#: ${id.nameValues.length}');
        for (var nv in id.nameValues) {
          metadataWidgets.add(
            appButton(
              '${nv.name}: ${nv.value}',
              appKeyEnum: AppKeyEnum.playListMetadata,
              value: '${id.id}:${nv.name}=${nv.value}',
              fontSize: _textFontSize,
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
        if (!_isEditing) {
          songItemAction(song);
          //  _navigateToPlayer(context, song);
        }
      },
      child: Container(
        color: _indexTextStyle.backgroundColor,
        padding: const EdgeInsets.all(5.0),
        child: AppWrapFullWidth(
          spacing: _textFontSize,
          alignment: _isEditing ? WrapAlignment.start : WrapAlignment.spaceBetween,
          children: [
            appWrap,
            AppWrap(spacing: _textFontSize, children: [
              if (!_isEditing)
                Text(
                  '   ${intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime))}',
                  style: _indexTextStyle,
                ),
              if (_isEditing) ...metadataWidgets
            ]),
          ],
        ),
      ),
    );
  }

  @override
  int compareTo(_SongItem other) {
    if (songPerformance != null && other.songPerformance != null) {
      return songPerformance!.compareTo(other.songPerformance!);
    }
    return song.compareTo(other.song);
  }

  final Song song;
  final SongPerformance? songPerformance;
}

class PlayList extends StatefulWidget {
  PlayList({super.key, List<Song>? songs, List<SongPerformance>? songPerformances, this.style})
      : _songItems = (songPerformances != null
            ? songPerformances.map((e) => _SongItem.fromPerformance(e)).toList(growable: false)
            : (songs ?? app.allSongs).map((e) => _SongItem(e)).toList(growable: false));

  @override
  State<StatefulWidget> createState() {
    return _PlayListState();
  }

  final List<_SongItem> _songItems;
  final TextStyle? style;
}

class _PlayListState extends State<PlayList> {
  _PlayListState() : _searchFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    var titleStyle = widget.style ?? generateAppTextStyle();
    var titleFontSize = widget.style?.fontSize ?? appDefaultFontSize;
    _textFontSize = 0.75 * titleFontSize;
    var artistStyle = titleStyle.copyWith(fontSize: _textFontSize, fontWeight: FontWeight.normal);

    final oddTitle = oddTitleTextStyle(from: titleStyle);
    final evenTitle = evenTitleTextStyle(from: titleStyle);
    final oddText = oddTitleTextStyle(from: artistStyle);
    final evenText = evenTitleTextStyle(from: artistStyle);

    final TextStyle searchDropDownStyle = artistStyle;
    final TextStyle searchTextStyle = titleStyle;

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
          fontSize: _textFontSize,
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
    int Function(_SongItem key1, _SongItem key2)? compare;
    switch (_selectedSortType) {
      case MainSortType.byArtist:
        compare = (_SongItem song1, _SongItem song2) {
          var ret = song1.song.artist.compareTo(song2.song.artist);
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byLastChange:
        compare = (_SongItem song1, _SongItem song2) {
          var ret = -song1.song.lastModifiedTime.compareTo(song2.song.lastModifiedTime);
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byComplexity:
        compare = (_SongItem song1, _SongItem song2) {
          var ret = song1.song.getComplexity().compareTo(song2.song.getComplexity());
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byYear:
        compare = (_SongItem song1, _SongItem song2) {
          var ret = song1.song.getCopyrightYear().compareTo(song2.song.getCopyrightYear());
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byTitle:
      default:
        compare = (_SongItem song1, _SongItem song2) {
          return song1.compareTo(song2);
        };
        break;
    }

    List<_SongItem> filteredSongs = [];
    {
      //  apply search
      SplayTreeSet<_SongItem> searchedSet = SplayTreeSet();
      var matcher = SongSearchMatcher(_searchTextFieldController.text);
      for (final songItem in widget._songItems) {
        if (matcher.matchesOrEmptySearch(songItem.song)) {
          searchedSet.add(songItem);
        }
      }

      //  apply filters and order
      SplayTreeSet<_SongItem> filteredSet = SplayTreeSet(compare);
      if (_filterNameValues.isEmpty) {
        //  apply no filter
        filteredSet.addAll(searchedSet);
      } else {
        //  filter the songs for the correct metadata
        for (var songItem in searchedSet) {
          var matched = true;
          var idString = songItem.song.songId.toString();
          for (var nv in _filterNameValues) {
            if (SongMetadata.where(idIs: idString, nameIs: nv.name, valueIs: nv.value).isEmpty) {
              matched = false;
              break;
            }
          }
          if (matched) {
            filteredSet.add(songItem);
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
                    width: 12 * _textFontSize,
                    //  limit text entry display length
                    child: TextField(
                      key: appKey(AppKeyEnum.mainSearchText),
                      //  for testing
                      controller: _searchTextFieldController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'enter search text',
                        hintStyle: artistStyle,
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
                  AppWrap(spacing: _textFontSize, children: [
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
                AppWrap(spacing: _textFontSize, alignment: WrapAlignment.spaceBetween, children: [
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
            // this expanded is required as well
            child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredSongs.length,
                itemBuilder: (BuildContext context, int index) {
                  logger.v('_PlayListState: index: $index');
                  _indexTitleStyle = (index & 1) == 1 ? oddTitle : evenTitle;
                  _indexTextStyle = (index & 1) == 1 ? oddText : evenText;
                  var songItem = filteredSongs[index];

                  return songItem.toWidget((Song song) {
                    _navigateToPlayer(context, song);
                  });
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

  final List<DropdownMenuItem<MainSortType>> _sortTypesDropDownMenuList = [];
  var _selectedSortType = MainSortType.byTitle;

  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode;
  static const _searchTextTooltipText = 'Enter search text here.\n Title, artist and cover artist will be searched.';
}
