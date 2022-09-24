import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../util/songSearchMatcher.dart';

const Level _logBuild = Level.debug;
const Level _logConstruct = Level.info;

//  persistent selection
final SplayTreeSet<NameValue> _filterNameValues = SplayTreeSet();

double _textFontSize = appDefaultFontSize;
late TextStyle _indexTitleStyle;
late TextStyle _indexTextStyle;

typedef SongItemAction = Function(BuildContext context, SongListItem songListItem);

class PlayListRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}

/// Allow the mechanics to use either a song or a song performance
class SongListItem implements Comparable<SongListItem> {
  SongListItem.fromSong(this.song, {this.customWidget, this.firstWidget}) : songPerformance = null;

  SongListItem.fromPerformance(this.songPerformance, {this.customWidget, this.firstWidget})
      : song = songPerformance!.performedSong;

  Widget _toWidget(BuildContext context, SongItemAction? songItemAction, bool isEditing) {
    AppWrap songWidget;
    if (songPerformance != null) {
      songWidget = AppWrap(children: [
        Text(
          '${songPerformance!.singer}:  ',
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
      songWidget = AppWrap(children: [
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

    return AppInkWell(
      appKeyEnum: AppKeyEnum.mainSong,
      value: Id(song.songId.toString()),
      onTap: () {
        if (!isEditing) {
          if (songItemAction != null) {
            songItemAction(context, this);
          }
        }
      },
      child: Container(
        color: _indexTextStyle.backgroundColor,
        padding: const EdgeInsets.all(5.0),
        child: AppWrapFullWidth(
          spacing: _textFontSize,
          alignment: WrapAlignment.spaceBetween,
          children: [
            AppWrap(children: [
              if (firstWidget != null) firstWidget!,
              if (firstWidget != null) const AppSpace(spaceFactor: 1.0),
              songWidget,
              const AppSpace(),
              customWidget ?? NullWidget(),
            ]),
            AppWrap(
                spacing: _textFontSize,
                alignment: isEditing ? WrapAlignment.end : WrapAlignment.spaceBetween,
                children: [
                  if (!isEditing)
                    Text(
                      songPerformance != null
                          ? intl.DateFormat.yMMMd()
                              .add_jm()
                              .format(DateTime.fromMillisecondsSinceEpoch(songPerformance!.lastSung))
                          : intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime)),
                      style: _indexTextStyle,
                    ),
                  if (isEditing)
                    Consumer<PlayListRefreshNotifier>(builder: (context, playListRefreshNotifier, child) {
                      List<Widget> metadataWidgets = [const AppSpace()];

                      for (var id in SongMetadata.where(idIs: song.songId.toString())) {
                        logger.v('editing: $this: ${id.id}: md#: ${id.nameValues.length}');
                        for (var nameValue in id.nameValues) {
                          metadataWidgets.add(
                            appIconButton(
                              icon: appIcon(
                                Icons.clear,
                              ),
                              label: '${nameValue.name}:${nameValue.value}',
                              appKeyEnum: AppKeyEnum.playListMetadata,
                              value: '${id.id}:${nameValue.name}=${nameValue.value}',
                              fontSize: _textFontSize,
                              onPressed: () {
                                SongMetadata.removeFromSong(song, nameValue);
                                playListRefreshNotifier.refresh();
                              },
                            ),
                          );
                        }
                      }
                      return AppWrap(spacing: _textFontSize, children: metadataWidgets);
                    }),
                ]),
          ],
        ),
      ),
    );
  }

  @override
  int compareTo(SongListItem other) {
    if (songPerformance != null && other.songPerformance != null) {
      return songPerformance!.compareTo(other.songPerformance!);
    }
    return song.compareTo(other.song);
  }

  final Song song;
  final SongPerformance? songPerformance;
  final Widget? customWidget;
  final Widget? firstWidget;
}

class SongList {
  const SongList(this.label, this.songListItems, {this.songItemAction, this.color});

  int get length => 1 + songListItems.length;

  Widget _indexToWidget(BuildContext context, int index, bool isEditing) {
    assert(index >= 0 && index - 1 < songListItems.length);

    //  index 0 is the label
    if (index == 0) {
      return label.isEmpty
          ? NullWidget()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSpace(
                  verticalSpace: 20,
                ),
                Text(
                  label,
                  style: _indexTitleStyle.copyWith(color: color ?? _indexTitleStyle.color),
                ),
                Divider(
                  thickness: 10,
                  color: color,
                ),
              ],
            );
    }

    //  other indices are the song items
    return songListItems[index - 1]._toWidget(context, songItemAction, isEditing);
  }

  final String label;
  final List<SongListItem> songListItems;
  final SongItemAction? songItemAction;
  final Color? color;
}

class SongListGroup {
  const SongListGroup(this.group);

  int get length => group.fold<int>(0, (i, e) {
        return i + e.length;
      });

  Widget _indexToWidget(BuildContext context, int index, bool isEditing) {
    for (var songList in group) {
      if (index >= songList.length) {
        index -= songList.length;
      } else {
        return songList._indexToWidget(context, index, isEditing);
      }
    }
    return Text('index too long for group: $index', style: _indexTitleStyle);
  }

  final List<SongList> group;
}

class PlayList extends StatefulWidget {
  PlayList({
    super.key,
    required SongList songList,
    this.style,
    this.includeByLastSung = false,
    this.isEditing = false,
    this.selectedSortType,
  }) : group = SongListGroup([songList]) {
    logger.log(_logConstruct, 'PlayList(): construction: _isEditing: $isEditing');
  }

  PlayList.byGroup(
    this.group, {
    super.key,
    this.style,
    this.includeByLastSung = false,
    this.isEditing = false,
    this.selectedSortType,
  }) {
    logger.log(_logConstruct, 'PlayList.byGroup(): construction: _isEditing: $isEditing');
  }

  @override
  State<StatefulWidget> createState() {
    return _PlayListState();
  }

  final SongListGroup group;
  final TextStyle? style;
  final bool includeByLastSung;
  final bool isEditing;
  final PlayListSortType? selectedSortType;
}

class _PlayListState extends State<PlayList> {
  _PlayListState() : _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    if (widget.selectedSortType != null) {
      selectedSortType = widget.selectedSortType!;
    } else if (widget.includeByLastSung) {
      //  preference for last sung (performance) lists
      selectedSortType = PlayListSortType.byHistory;
    } else {
      switch (selectedSortType) {
        case PlayListSortType.byLastSung:
        case PlayListSortType.byHistory:
          //  replace invalid preference for song lists
          selectedSortType = PlayListSortType.byTitle;
          break;
        default:
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.log(
        _logBuild,
        'PlayList.build(): _isEditing: ${widget.isEditing}'
        ', text: "${_searchTextFieldController.text}"');

    var titleStyle = widget.style ?? generateAppTextStyle();
    var titleFontSize = widget.style?.fontSize ?? appDefaultFontSize;
    _textFontSize = 0.75 * titleFontSize;
    var artistStyle = titleStyle.copyWith(fontSize: _textFontSize, fontWeight: FontWeight.normal);
    titleStyle = titleStyle.copyWith(fontWeight: FontWeight.bold);

    final oddTitle = oddTitleTextStyle(from: titleStyle);
    final evenTitle = evenTitleTextStyle(from: titleStyle);
    final oddText = oddTitleTextStyle(from: artistStyle);
    final evenText = evenTitleTextStyle(from: artistStyle);

    final TextStyle searchDropDownStyle = artistStyle;
    final TextStyle searchTextStyle = titleStyle;

    //  generate the sort selection
    _sortTypesDropDownMenuList.clear();

    for (final e in PlayListSortType.values) {
      //  fool with the drop down options
      if (!widget.includeByLastSung) {
        switch (e) {
          case PlayListSortType.byHistory:
          case PlayListSortType.byLastSung:
            //  if in a song play list, by last sung and history should be removed
            continue;
          default:
        }
      }
      _sortTypesDropDownMenuList.add(appDropdownMenuItem<PlayListSortType>(
        appKeyEnum: AppKeyEnum.mainSortTypeSelection,
        value: e,
        child: Text(
          Util.camelCaseToLowercaseSpace(e.name),
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
              logger.d('remove: ${nv.name}: ${nv.value}');
              _filterNameValues.remove(nv);
            });
          },
        ),
      );
    }

    //  create drop down list of name/values not in use in the filter
    const allNameValue = NameValue('All', '');
    List<DropdownMenuItem<NameValue>> filterDropdownMenuItems = [];
    filterDropdownMenuItems.add(appDropdownMenuItem<NameValue>(
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
      filterDropdownMenuItems.add(appDropdownMenuItem<NameValue>(
          appKeyEnum: AppKeyEnum.playListFilter,
          value: nv,
          child: Text(
            nvString,
            style: artistStyle,
          )));
    }

    // select order
    int Function(SongListItem key1, SongListItem key2)? compare;
    switch (selectedSortType) {
      case PlayListSortType.byArtist:
        compare = (SongListItem item1, SongListItem item2) {
          var ret = item1.song.artist.compareTo(item2.song.artist);
          if (ret != 0) {
            return ret;
          }
          return item1.compareTo(item2);
        };
        break;
      case PlayListSortType.byLastChange:
        compare = (SongListItem item1, SongListItem item2) {
          var ret = -item1.song.lastModifiedTime.compareTo(item2.song.lastModifiedTime);
          if (ret != 0) {
            return ret;
          }
          return item1.compareTo(item2);
        };
        break;
      case PlayListSortType.byComplexity:
        compare = (SongListItem item1, SongListItem item2) {
          var ret = item1.song.getComplexity().compareTo(item2.song.getComplexity());
          if (ret != 0) {
            return ret;
          }
          return item1.compareTo(item2);
        };
        break;
      case PlayListSortType.byHistory:
        compare = (SongListItem item1, SongListItem item2) {
          if (item1.songPerformance != null && item2.songPerformance != null) {
            return -SongPerformance.compareByLastSungSongIdAndSinger(item1.songPerformance!, item2.songPerformance!);
          }
          return item1.compareTo(item2);
        };
        break;
      case PlayListSortType.byLastSung:
        compare = (SongListItem item1, SongListItem item2) {
          if (item1.songPerformance != null && item2.songPerformance != null) {
            return SongPerformance.compareByLastSungSongIdAndSinger(item1.songPerformance!, item2.songPerformance!);
          }
          return item1.compareTo(item2);
        };
        break;
      case PlayListSortType.byYear:
        compare = (SongListItem item1, SongListItem item2) {
          var ret = item1.song.getCopyrightYear().compareTo(item2.song.getCopyrightYear());
          if (ret != 0) {
            return ret;
          }
          return item1.compareTo(item2);
        };
        break;
      case PlayListSortType.byTitle:
        compare = (SongListItem item1, SongListItem item2) {
          return item1.compareTo(item2);
        };
        break;
    }

    SongListGroup filteredGroup;
    {
      //  apply search
      List<SongList> filteredSongLists = [];
      var matcher = SongSearchMatcher(_searchTextFieldController.text);
      for (final songList in widget.group.group) {
        //  find the possible items
        SplayTreeSet<SongListItem> searchedSet = SplayTreeSet();
        for (final songItem in songList.songListItems) {
          if ((songItem.songPerformance != null &&
                  matcher.performanceMatchesOrEmptySearch(songItem.songPerformance!)) ||
              matcher.matchesOrEmptySearch(songItem.song)) {
            searchedSet.add(songItem);
          }
        }

        //  apply filters and order
        SplayTreeSet<SongListItem> filteredSet = SplayTreeSet(compare);
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
        if (filteredSet.isNotEmpty) {
          filteredSongLists.add(SongList(songList.label, filteredSet.toList(growable: false),
              songItemAction: songList.songItemAction, color: songList.color));
        }
      }
      filteredGroup = SongListGroup(filteredSongLists);
    }

    //  reset an old list view
    logger.v('scrollController: $scrollController');
    if (scrollController.hasClients) {
      //  fixme: why is this delay required?
      Future.delayed(const Duration(milliseconds: 20), () {
        scrollController.jumpTo(0);
      });
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
                        hintStyle: artistStyle.copyWith(color: Colors.black54),
                      ),
                      autofocus: true,
                      style: searchTextStyle,
                      onChanged: (text) {
                        setState(() {
                          logger.v('search text: "$text"');
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
                  const AppSpace(spaceFactor: 2.0),
                  //  filters
                  AppWrap(spacing: _textFontSize, children: [
                    DropdownButton<NameValue?>(
                      value: null,
                      hint: Text('Filters:', style: artistStyle),
                      items: filterDropdownMenuItems,
                      style: artistStyle,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            if (value == allNameValue) {
                              _filterNameValues.clear();
                            } else {
                              _filterNameValues.add(value);
                            }
                          });
                        }
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
                        appDropdownButton<PlayListSortType>(
                          AppKeyEnum.mainSortType,
                          _sortTypesDropDownMenuList,
                          onChanged: (value) {
                            if (selectedSortType != value) {
                              setState(() {
                                selectedSortType = value ?? PlayListSortType.byTitle;
                                app.clearMessage();
                              });
                            }
                          },
                          value: selectedSortType,
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
              itemCount: filteredGroup.length,
              controller: scrollController,
              itemBuilder: (BuildContext context, int index) {
                logger.v('_PlayListState: index: $index');
                _indexTitleStyle = (index & 1) == 1 ? oddTitle : evenTitle;
                _indexTextStyle = (index & 1) == 1 ? oddText : evenText;
                return filteredGroup._indexToWidget(context, index, widget.isEditing);
              },
            ),
          ),
        ]),
      ),
    );
  }

  final List<DropdownMenuItem<PlayListSortType>> _sortTypesDropDownMenuList = [];
  var selectedSortType = PlayListSortType.byTitle;
  final ScrollController scrollController = ScrollController();

  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode;
  static const _searchTextTooltipText = 'Enter search text here.\n Title, artist and cover artist will be searched.';
}
