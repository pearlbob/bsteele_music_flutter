import 'dart:collection';
import 'dart:math';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/song_metadata.dart';
import 'package:bsteeleMusicLib/songs/song_performance.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/metadataPopupMenuButton.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:string_similarity/string_similarity.dart';

import '../app/app.dart';
import '../util/play_list_search_matcher.dart';

const Level _logConstruct = Level.debug;
const Level _logInitState = Level.debug;
const Level _logBuild = Level.debug;
const Level _logPosition = Level.debug;
const Level _logJump = Level.debug;
const Level _logFilters = Level.debug;

//  persistent selection
final SplayTreeSet<NameValueMatcher> _filterNameValues = SplayTreeSet();

double _textFontSize = appDefaultFontSize;
late TextStyle _indexTitleStyle;
late TextStyle _indexTextStyle;

typedef PlayListItemAction = Function(BuildContext context, PlayListItem playListItem);

class PlayListRefreshNotifier extends ChangeNotifier {
  void refresh() {
    logger.log(_logPosition, 'PlayListRefreshNotifier: ${identityHashCode(this)}');
    notifyListeners();
  }

  void requestSearchClear() {
    positionPixels = 0.0;
    _requestSearchClear = true;
    // notifyListeners();  //  fixme: this ends up double notifying the listeners
  }

  //  return true if a search clear has been requested
  //  request is reset once queried
  bool searchClearQuery() {
    var ret = _requestSearchClear;
    _requestSearchClear = false;
    return ret;
  }

  bool _requestSearchClear = false;

  double? positionPixels;
}

/// Allow the mechanics to use either a song or a song performance
abstract class PlayListItem implements Comparable<PlayListItem> {
  @override
  int compareTo(PlayListItem other);

  Widget toWidget(BuildContext context, PlayListItemAction? playListItemAction, bool isEditing, VoidCallback? refocus);
}

class SongPlayListItem implements PlayListItem {
  SongPlayListItem.fromSong(this.song, {this.customWidget, this.firstWidget}) : songPerformance = null;

  SongPlayListItem.fromPerformance(this.songPerformance, {this.customWidget, this.firstWidget})
      : song = songPerformance!.performedSong;

  @override
  Widget toWidget(BuildContext context, PlayListItemAction? playListItemAction, bool isEditing, VoidCallback? refocus) {
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
          if (playListItemAction != null) {
            playListItemAction(context, this);
            //  expect return to play list
            refocus?.call();
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
                      // List<Widget> generatedMetadataWidgets = [const AppSpace()];

                      for (var id in SongMetadata.where(idIs: song.songId.toString())) {
                        logger.v('editing: $this: ${id.id}: md#: ${id.nameValues.length}');
                        for (var nameValue in id.nameValues) {
                          if (SongMetadataGeneratedValue.isGenerated(nameValue)) {
                            // generatedMetadataWidgets.add(Text(
                            //   '${nameValue.name}:${nameValue.value}',
                            //   style: _indexTextStyle,
                            // ));
                            continue;
                          }
                          logger.v('    value: ${id.id}:${nameValue.name}=${nameValue.value}');

                          metadataWidgets.add(
                            appIconWithLabelButton(
                              icon: appIcon(
                                Icons.clear,
                              ),
                              label: nameValue.toString(),
                              appKeyEnum: AppKeyEnum.playListMetadataRemoveFromSong,
                              value: SongIdMetadataItem(song, nameValue),
                              fontSize: _textFontSize,
                              onPressed: () {
                                SongMetadata.removeFromSong(song, nameValue);
                                playListRefreshNotifier.refresh();
                              },
                            ),
                          );
                        }
                      }
                      return AppWrap(spacing: _textFontSize, children: [
                        ...metadataWidgets,
                        // ...generatedMetadataWidgets
                      ]);
                    }),
                ]),
          ],
        ),
      ),
    );
  }

  @override
  int compareTo(PlayListItem other) {
    if (runtimeType != other.runtimeType) {
      return -1;
    }
    other = other as SongPlayListItem;
    if (songPerformance != null && other.songPerformance != null) {
      return songPerformance!.compareTo(other.songPerformance!);
    }
    return song.compareTo(other.song);
  }

  @override
  String toString() {
    return 'PlayListItem: ${song.songId.toString()}${songPerformance != null ? ', $songPerformance' : ''}';
  }

  //  data
  final Song song;
  final SongPerformance? songPerformance;

  //  widgets
  final Widget? customWidget;
  final Widget? firstWidget;
}

class PlayListItemList {
  const PlayListItemList(this.label, this.playListItems, {this.playListItemAction, this.color});

  int get length => 1 + playListItems.length;

  Widget _indexToWidget(BuildContext context, int index, bool isEditing, VoidCallback? refocus) {
    assert(index >= 0 && index - 1 < playListItems.length);

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
    return playListItems[index - 1].toWidget(context, playListItemAction, isEditing, refocus);
  }

  final String label;
  final List<PlayListItem> playListItems;
  final PlayListItemAction? playListItemAction;
  final Color? color;
}

class PlayListGroup {
  const PlayListGroup(this.group);

  int get length => group.fold<int>(0, (i, e) {
        return i + e.length;
      });

  bool get isEmpty => group.isEmpty;

  bool get isNotEmpty => group.isNotEmpty;

  Widget _indexToWidget(BuildContext context, int index, bool isEditing, VoidCallback? refocus) {
    for (var itemList in group) {
      if (index >= itemList.length) {
        index -= itemList.length;
      } else {
        return itemList._indexToWidget(context, index, isEditing, refocus);
      }
    }
    return Text('index too long for group: $index', style: _indexTitleStyle);
  }

  final List<PlayListItemList> group;
}

class PlayList extends StatefulWidget {
  PlayList({
    key,
    required PlayListItemList itemList,
    style,
    includeByLastSung = false,
    isEditing = false,
    selectedSortType,
    isFromTheTop = true,
    isOrderBy = true,
    useAllFilters = false,
    required PlayListSearchMatcher playListSearchMatcher,
  }) : this.byGroup(PlayListGroup([itemList]),
            key: key,
            style: style,
            includeByLastSung: includeByLastSung,
            isEditing: isEditing,
            selectedSortType: selectedSortType,
            isFromTheTop: isFromTheTop,
            isOrderBy: isOrderBy,
            showAllFilters: useAllFilters,
            playListSearchMatcher: playListSearchMatcher);

  PlayList.byGroup(
    this.group, {
    super.key,
    this.style,
    this.includeByLastSung = false,
    this.isEditing = false,
    this.selectedSortType,
    this.isFromTheTop = true,
    this.isOrderBy = true,
    this.showAllFilters = false,
    required this.playListSearchMatcher,
  }) : titleStyle = (style ?? generateAppTextStyle()).copyWith(fontWeight: FontWeight.bold) {
    //
    titleFontSize = style?.fontSize ?? appDefaultFontSize;
    _textFontSize = 0.75 * titleFontSize;
    artistStyle = titleStyle.copyWith(fontSize: _textFontSize, fontWeight: FontWeight.normal);

    searchDropDownStyle = artistStyle;
    searchTextStyle = titleStyle;

    logger.log(_logConstruct, 'PlayList: constructor: _isEditing: $isEditing');
  }

  @override
  State<StatefulWidget> createState() {
    return _PlayListState();
  }

  final PlayListGroup group;
  final TextStyle? style;
  final bool includeByLastSung;
  final bool isEditing;
  final PlayListSortType? selectedSortType;
  final bool isFromTheTop;
  final bool isOrderBy;
  final bool showAllFilters;

  final TextStyle titleStyle;
  late final double titleFontSize;
  late final TextStyle artistStyle;
  late final TextStyle searchDropDownStyle;
  late final TextStyle searchTextStyle;

  late final TextStyle oddTitle = oddTitleTextStyle(from: titleStyle);
  late final TextStyle evenTitle = evenTitleTextStyle(from: titleStyle);
  late final TextStyle oddText = oddTitleTextStyle(from: artistStyle);
  late final TextStyle evenText = evenTitleTextStyle(from: artistStyle);
  final PlayListSearchMatcher playListSearchMatcher;
}

class _PlayListState extends State<PlayList> {
  @override
  void initState() {
    super.initState();

    logger.log(_logInitState, 'PlayList.initState():');

    _generateSortTypesDropDownMenuList();
  }

  void focus(BuildContext context) {
    if (_searchTextFieldController.text.isNotEmpty) {
      _searchTextFieldController.selection =
          TextSelection(baseOffset: 0, extentOffset: _searchTextFieldController.text.length);
    }
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  _generateSortTypesDropDownMenuList() {
    if (widget.selectedSortType != null) {
      selectedSortType = widget.selectedSortType!;
    } else if (widget.includeByLastSung) {
      //  preference for last sung (performance) lists
      selectedSortType = PlayListSortType.byHistory;
    } else {
      switch (selectedSortType) {
        case PlayListSortType.byLastSung:
        case PlayListSortType.byHistory:
        case PlayListSortType.bySinger:
          //  replace invalid preference for song lists
          selectedSortType = PlayListSortType.byTitle;
          break;
        case PlayListSortType.byTitle:
        case PlayListSortType.byArtist:
        case PlayListSortType.byLastChange:
        case PlayListSortType.byComplexity:
        case PlayListSortType.byYear:
          break;
      }
    }

    //  generate the sort selection
    _sortTypesDropDownMenuList.clear();
    if (widget.isOrderBy) {
      for (final e in PlayListSortType.values) {
        //  fool with the drop down options
        if (!widget.includeByLastSung) {
          switch (e) {
            case PlayListSortType.byHistory:
            case PlayListSortType.byLastSung:
            case PlayListSortType.bySinger:
              //  if in a song play list, these should be removed
              continue;
            case PlayListSortType.byTitle:
            case PlayListSortType.byArtist:
            case PlayListSortType.byLastChange:
            case PlayListSortType.byComplexity:
            case PlayListSortType.byYear:
              break;
          }
        }
        _sortTypesDropDownMenuList.add(appDropdownMenuItem<PlayListSortType>(
          appKeyEnum: AppKeyEnum.mainSortTypeSelection,
          value: e,
          child: AppTooltip(
            message: e.toolTip,
            child: Text(
              Util.camelCaseToLowercaseSpace(e.name),
              style: widget.searchDropDownStyle,
            ),
          ),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayListRefreshNotifier>(builder: (context, playListRefreshNotifier, child) {
      logger.log(
          _logBuild,
          'PlayList.build(): _isEditing: ${widget.isEditing}'
          ', text: "${_searchTextFieldController.text}"'
          ', positionPixels: ${playListRefreshNotifier.positionPixels}'
          //   ', _searchTextFieldController: ${identityHashCode(_searchTextFieldController)}'
          //    ' (${_searchTextFieldController.selection.base.offset}'
          //    ',${_searchTextFieldController.selection.extent.offset})'
          // ', ModalRoute: ${ModalRoute.of(context)?.settings.name}'
          );

      //  clear the search if asked
      if (playListRefreshNotifier.searchClearQuery()) {
        _searchTextFieldController.text = '';
        playListRefreshNotifier.positionPixels = 0.0;
        logger.log(
            _logBuild,
            '_PlayListState: playListRefreshNotifier.searchClearQuery()'
            ', positionPixels: ${playListRefreshNotifier.positionPixels}');
        focus(context);
      }

      //  find all the metadata values
      SplayTreeSet<NameValue> nameValues = SplayTreeSet();
      for (var id in SongMetadata.where()) {
        nameValues.addAll(id.nameValues);
      }

      // select order
      int Function(PlayListItem key1, PlayListItem key2)? compare;
      if (widget.isOrderBy) {
        switch (selectedSortType) {
          case PlayListSortType.byArtist:
            compare = (PlayListItem item1, PlayListItem item2) {
              if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                var ret = item1.song.artist.compareTo(item2.song.artist);
                if (ret != 0) {
                  return ret;
                }
              }
              return item1.compareTo(item2);
            };
            break;
          case PlayListSortType.byLastChange:
            compare = (PlayListItem item1, PlayListItem item2) {
              if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                var ret = -item1.song.lastModifiedTime.compareTo(item2.song.lastModifiedTime);
                if (ret != 0) {
                  return ret;
                }
              }
              return item1.compareTo(item2);
            };
            break;
          case PlayListSortType.byComplexity:
            compare = (PlayListItem item1, PlayListItem item2) {
              if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                var ret = item1.song.getComplexity().compareTo(item2.song.getComplexity());
                if (ret != 0) {
                  return ret;
                }
              }
              return item1.compareTo(item2);
            };
            break;
          case PlayListSortType.byHistory:
            compare = (PlayListItem item1, PlayListItem item2) {
              if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                if (item1.songPerformance != null && item2.songPerformance != null) {
                  return -SongPerformance.compareByLastSungSongIdAndSinger(
                      item1.songPerformance!, item2.songPerformance!);
                }
              }
              return item1.compareTo(item2);
            };
            break;
          case PlayListSortType.byLastSung:
            compare = (PlayListItem item1, PlayListItem item2) {
              if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                if (item1.songPerformance != null && item2.songPerformance != null) {
                  return SongPerformance.compareByLastSungSongIdAndSinger(
                      item1.songPerformance!, item2.songPerformance!);
                }
              }
              return item1.compareTo(item2);
            };
            break;
          case PlayListSortType.bySinger:
            compare = (PlayListItem item1, PlayListItem item2) {
              if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                if (item1.songPerformance != null && item2.songPerformance != null) {
                  return SongPerformance.compareBySinger(item1.songPerformance!, item2.songPerformance!);
                }
              }
              return item1.compareTo(item2);
            };
            break;
          case PlayListSortType.byYear:
            compare = (PlayListItem item1, PlayListItem item2) {
              if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                var ret = item1.song.getCopyrightYear().compareTo(item2.song.getCopyrightYear());
                if (ret != 0) {
                  return ret;
                }
              }
              return item1.compareTo(item2);
            };
            break;
          case PlayListSortType.byTitle:
            compare = (PlayListItem item1, PlayListItem item2) {
              return item1.compareTo(item2);
            };
            break;
        }
      }

      //  generate display list of current filters
      List<Widget> filterWidgets = [];
      var filter = NameValueFilter(_filterNameValues);
      logger.log(_logFilters, '_filterNameValues: $_filterNameValues');
      {
        String lastName = '';
        for (var nameValueMatcher in filter.matchers()) {
          if (lastName.isNotEmpty) {
            filterWidgets.add(Text(
              lastName == nameValueMatcher.name && filter.isOr(nameValueMatcher) ? 'OR' : 'AND',
              style: _indexTextStyle,
            ));
          }
          filterWidgets.add(
            appIconWithLabelButton(
              icon: appIcon(
                Icons.clear,
              ),
              label: nameValueMatcher.toString(),
              fontSize: _textFontSize,
              appKeyEnum: AppKeyEnum.playListMetadataRemoveFromFilter,
              value: nameValueMatcher,
              backgroundColor: filter.isOr(nameValueMatcher) ? Colors.lightGreen : null,
              onPressed: () {
                setState(() {
                  logger.d('remove: ${nameValueMatcher.name}: ${nameValueMatcher.value}');
                  _filterNameValues.remove(nameValueMatcher);
                });
              },
            ),
          );
          lastName = nameValueMatcher.name;
        }
      }

      PlayListGroup filteredGroup;
      {
        //  apply search
        List<PlayListItemList> filteredSongLists = [];
        widget.playListSearchMatcher.search = _searchTextFieldController.text;
        {
          PlayListItemAction? bestSongItemAction; //  fixme: this can't be the best way to find an action!
          for (final songList in widget.group.group) {
            //  find the possible items
            SplayTreeSet<PlayListItem> searchedSet = SplayTreeSet();
            for (final songItem in songList.playListItems) {
              if (widget.playListSearchMatcher.matches(songItem)) {
                searchedSet.add(songItem);
              }
            }

            //  apply filters and order
            SplayTreeSet<PlayListItem> filteredSet = SplayTreeSet(compare);
            if (_filterNameValues.isEmpty) {
              //  apply no filter
              filteredSet.addAll(searchedSet);
            } else {
              //  filter the songs for the correct metadata
              for (var item in searchedSet) {
                if (item is SongPlayListItem //  fixme:
                    &&
                    filter.testAll(SongMetadata.songIdMetadata(item.song)?.nameValues)) {
                  filteredSet.add(item);
                }
              }
            }
            if (filteredSet.isNotEmpty) {
              filteredSongLists.add(PlayListItemList(songList.label, filteredSet.toList(growable: false),
                  playListItemAction: songList.playListItemAction, color: songList.color));
            } else {
              bestSongItemAction ??= songList.playListItemAction;
            }
          }
        }
        //  try the closest match?
        if (filteredSongLists.isEmpty && _searchTextFieldController.text.isNotEmpty) {
          final songTitles = app.allSongs.map((e) => e.title).toList(growable: false);
          BestMatch bestMatch = StringSimilarity.findBestMatch(_searchTextFieldController.text, songTitles);
          logger.i('playList: $bestMatch, len: ${widget.group.group.length}'
              ' ${widget.group.group.first.playListItemAction}');
          Song song = app.allSongs.toList(growable: false)[bestMatch.bestMatchIndex];
          app.selectedSong = song;
          filteredSongLists.add(PlayListItemList(
            'Did you mean?',
            [SongPlayListItem.fromSong(song)],
            playListItemAction: widget.group.group.first.playListItemAction, // fixme: not a great solution
            color: App.appBackgroundColor,
          ));
        }
        logger.v('playlist: filteredSongLists.length: ${filteredSongLists.length}');
        filteredGroup = PlayListGroup(filteredSongLists);
      }

      //  jump to proper location for the initial position
      if (scrollController.hasClients
          // && playListRefreshNotifier.positionPixels != null
          ) {
        double pixels = widget.isFromTheTop ? 0 : playListRefreshNotifier.positionPixels ?? 0;
        playListRefreshNotifier.positionPixels = null;
        pixels = Util.doubleLimit(pixels, 0, scrollController.position.maxScrollExtent);

        logger.log(_logJump, 'pixels: $pixels');
        if (scrollController.position.pixels != pixels) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            logger.log(_logJump, 'pixels: jumpTo($pixels)  ${identityHashCode(playListRefreshNotifier)}');
            scrollController.jumpTo(pixels);
          });
        }
      } else {
        logger.log(_logPosition, 'pixels: no clients');
      }

      return Expanded(
        // for some reason, this is Expanded is very required,
        // otherwise the Column is unlimited and the list view fails
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                        iconSize: widget.titleFontSize,
                        onPressed: (() {
                          setState(() {
                            //fixme: _searchSongs(_searchTextFieldController.text);
                          });
                        }),
                      ),
                    ),
                    //  search text
                    AppTooltip(
                      message: 'Enter list search terms here.\n'
                          'Regular expressions can be used.',
                      child: AppTextField(
                        appKeyEnum: AppKeyEnum.playListSearch,
                        controller: _searchTextFieldController,
                        focusNode: _searchFocusNode,
                        hintText: 'Search here...',
                        width: min(appDefaultFontSize * 40, app.screenInfo.mediaWidth / 2),
                        onChanged: (value) {
                          setState(() {
                            if (_searchTextFieldController.text != value) {
                              //  programmatic text entry
                              _searchTextFieldController.text = value;
                            }
                            logger.v('search text: "$value"');
                            app.clearMessage();
                          });
                        },
                      ),
                    ),
                    //  search clear
                    AppTooltip(
                        message: _searchTextFieldController.text.isEmpty
                            ? 'Scroll the list some.'
                            : 'Clear the search text.',
                        child: appIconButton(
                          icon: const Icon(Icons.clear),
                          appKeyEnum: AppKeyEnum.playListClearSearch,
                          iconSize: 1.25 * widget.titleFontSize,
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
                    AppTooltip(
                        message: '''Filter the list by the selected metadata.
Selections with the same name will be OR'd together.
Selections with different names will be AND'd.''',
                        child: MetadataPopupMenuButton.button(
                          title: 'Filters',
                          style: widget.artistStyle,
                          showAllFilters: widget.showAllFilters,
                          onSelected: (value) {
                            setState(() {
                              if (value == allNameValue) {
                                _filterNameValues.clear();
                              } else {
                                _filterNameValues.add(value);
                              }
                            });
                          },
                        )),
                    AppWrap(
                      spacing: _textFontSize / 2,
                      children: filterWidgets,
                    ),
                  ]),

                  //  filters and order
                  AppWrap(spacing: _textFontSize, alignment: WrapAlignment.spaceBetween, children: [
                    //  filters and order
                    if (app.isScreenBig && widget.isOrderBy)
                      AppWrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: app.screenInfo.fontSize / 2,
                        children: [
                          AppTooltip(
                            message: 'Select the order of the song list.',
                            child: Text(
                              'Order',
                              style: widget.searchDropDownStyle,
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
                            style: widget.searchDropDownStyle,
                          ),
                          Text(
                            '(${filteredGroup.length})',
                            style: widget.artistStyle,
                          ),
                        ],
                      ),
                  ]),
                ]),
            const AppSpace(),

            // this expanded is required as well
            Expanded(
              child: Scrollbar(
                thickness: max(16.0, 0.0125 * app.screenInfo.mediaWidth),
                controller: scrollController,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredGroup.length,
                  controller: scrollController,
                  itemBuilder: (BuildContext context, int index) {
                    //  keep track of scroll position
                    if (!widget.isFromTheTop) {
                      playListRefreshNotifier.positionPixels = scrollController.position.pixels;
                    }
                    logger.log(
                        _logPosition,
                        '_PlayListState: index: $index, pos:'
                        ' ${playListRefreshNotifier.positionPixels}'
                        ', id:F ${identityHashCode(playListRefreshNotifier)}'
                        ', isFromTheTop: ${widget.isFromTheTop}');
                    _indexTitleStyle = (index & 1) == 1 ? widget.oddTitle : widget.evenTitle;
                    _indexTextStyle = (index & 1) == 1 ? widget.oddText : widget.evenText;
                    return filteredGroup._indexToWidget(context, index, widget.isEditing, () {
                      focus(context);
                    });
                  },
                ),
              ),
            ),
          ]),
        ),
      );
    });
  }

  static final allNameValue = NameValue('All', '');

  final List<DropdownMenuItem<PlayListSortType>> _sortTypesDropDownMenuList = [];
  var selectedSortType = PlayListSortType.byTitle;
  final ScrollController scrollController = ScrollController();

  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  static const _searchTextTooltipText = 'Enter search text here\nto help select the item.';
}
