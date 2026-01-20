import 'dart:collection';
import 'dart:math';

import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/metadataPopupMenuButton.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_metadata.dart';
import 'package:bsteele_music_lib/songs/song_performance.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:string_similarity/string_similarity.dart';

import '../app/app.dart';
import '../util/play_list_search_matcher.dart';

const Level _logConstruct = Level.debug;
const Level _logInitState = Level.debug;
const Level _logBuild = Level.debug;
const Level _logPosition = Level.debug;
const Level _logPlayListRefreshNotifier = Level.debug;
const Level _logFilters = Level.debug;
const Level _logKeyboard = Level.debug;

//  persistent selection
final SplayTreeSet<NameValueMatcher> _filterNameValues = SplayTreeSet();
// final Random _random = Random();

double _textFontSize = appDefaultFontSize;
late TextStyle _indexTitleStyle;
late TextStyle _indexTextStyle;
late TextStyle _indexBunchStyle;

typedef PlayListItemAction = Function(BuildContext context, PlayListItem playListItem);

class PlayListRefreshNotifier extends ChangeNotifier {
  void refresh() {
    logger.log(_logPlayListRefreshNotifier, 'PlayListRefreshNotifier: ${identityHashCode(this)}');
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

  Widget toWidget(
    final BuildContext context,
    final PlayListItemAction? playListItemAction,
    final bool isEditing,
    final VoidCallback? refocus,
    final bool bunch,
    final PlayListSortType? playListSortType,
  );

  String get title;
}

class SongPlayListItem implements PlayListItem {
  SongPlayListItem.fromSong(this.song, {this.customWidget, this.firstWidget}) : songPerformance = null;

  SongPlayListItem.fromPerformance(this.songPerformance, {this.customWidget, this.firstWidget})
    : song = songPerformance!.performedSong;

  @override
  String get title => song.title;

  @override
  Widget toWidget(
    final BuildContext context,
    final PlayListItemAction? playListItemAction,
    final bool isEditing,
    final VoidCallback? refocus,
    final bool bunch,
    final PlayListSortType? playListSortType,
  ) {
    AppWrap songWidget;
    if (songPerformance != null) {
      if (bunch) {
        songWidget = AppWrap(
          children: [
            Text(
              song.title,
              style: _indexBunchStyle.copyWith(decoration: TextDecoration.underline, fontWeight: .normal),
            ),
            Text('   ', style: _indexBunchStyle),
          ],
        );
      } else {
        songWidget = AppWrap(
          children: [
            Text('${songPerformance!.singer}:  ', style: _indexTextStyle),
            Text(song.title, style: _indexTitleStyle),
            Text('  by ${song.artist}', style: _indexTextStyle),
            if (song.coverArtist.isNotEmpty) Text(', cover by ${song.coverArtist}', style: _indexTextStyle),
            Text(' in ${songPerformance!.key}', style: _indexTextStyle),
          ],
        );
      }
    } else {
      //  song
      if (bunch) {
        songWidget = AppWrap(
          children: [
            Text(
              song.title,
              style: _indexBunchStyle.copyWith(decoration: TextDecoration.underline, fontWeight: .normal),
            ),
            Text('   ', style: _indexBunchStyle),
          ],
        );
      } else {
        songWidget = AppWrap(
          children: [
            Text(song.title, style: _indexTitleStyle),
            Text('  by ${song.artist}', style: _indexTextStyle),
            if (song.coverArtist.isNotEmpty) Text(', cover by ${song.coverArtist}', style: _indexTextStyle),
          ],
        );
      }
    }

    if (bunch) {
      return AppInkWell(
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
        child: songWidget,
      );
    }

    //  select the proper date to show
    String dateString;
    switch (playListSortType) {
      case .byDateCreated:
        dateString = intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.dateCreated));
        break;
      case .byYear:
        {
          int year = song.getCopyrightYear();
          dateString = year == 0 ? 'unknown' : year.toString();
        }
        break;
      case .byComplexity:
        dateString = song.getComplexity().toString();
        break;
      case .byPopularity:
        dateString = (songPopularity[song.songId] ?? 0).toString();
        break;
      default:
        dateString = songPerformance != null
            ? intl.DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(songPerformance!.lastSung))
            : intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime));
        break;
    }

    return AppInkWell(
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
        // padding: const EdgeInsets.all(5.0),  //  spacing between rows
        child: AppWrapFullWidth(
          spacing: _textFontSize,
          alignment: WrapAlignment.spaceBetween,
          children: [
            AppWrap(
              children: [
                if (firstWidget != null) firstWidget!,
                if (firstWidget != null) const AppSpace(),
                songWidget,
                const AppSpace(),
                customWidget ?? NullWidget(),
              ],
            ),
            AppWrap(
              spacing: _textFontSize,
              alignment: isEditing ? WrapAlignment.end : WrapAlignment.spaceBetween,
              children: [
                if (!isEditing) Text(dateString, style: _indexTextStyle),
                if (isEditing)
                  Consumer<PlayListRefreshNotifier>(
                    builder: (context, playListRefreshNotifier, child) {
                      List<Widget> metadataWidgets = [const AppSpace()];
                      // List<Widget> generatedMetadataWidgets = [const AppSpace()];

                      for (var id in SongMetadata.where(idIs: song.songId.toString())) {
                        logger.t('editing: $this: ${id.id}: md#: ${id.nameValues.length}');
                        for (var nameValue in id.nameValues) {
                          if (SongMetadataGeneratedValue.isGenerated(nameValue)) {
                            // generatedMetadataWidgets.add(Text(
                            //   '${nameValue.name}:${nameValue.value}',
                            //   style: _indexTextStyle,
                            // ));
                            continue;
                          }
                          logger.t('    value: ${id.id}:${nameValue.name}=${nameValue.value}');

                          metadataWidgets.add(
                            appIconWithLabelButton(
                              icon: appIcon(Icons.clear),
                              label: nameValue.toString(),
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
                      return AppWrap(
                        spacing: _textFontSize,
                        children: [
                          ...metadataWidgets,
                          // ...generatedMetadataWidgets
                        ],
                      );
                    },
                  ),
              ],
            ),
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
    return 'SongPlayListItem: ${song.songId.toString()}${songPerformance != null ? ', $songPerformance' : ''}';
  }

  //  data
  final Song song;
  final SongPerformance? songPerformance;

  //  widgets
  final Widget? customWidget;
  final Widget? firstWidget;
}

class PlayListItemList {
  const PlayListItemList(this.label, this.playListItems, {this.playListItemAction, this.color, this.bunch = false});

  int get length => 1 + (bunch ? 1 : playListItems.length);

  Widget _indexToWidget(
    BuildContext context,
    int index,
    bool isEditing,
    VoidCallback? refocus,
    PlayListSortType? playListSortType,
  ) {
    assert(index >= 0 && index - 1 < playListItems.length);

    //  index 0 is the label
    if (index == 0) {
      return label.isEmpty
          ? NullWidget()
          : Column(
              crossAxisAlignment: .start,
              children: [
                const AppSpace(verticalSpace: 20),
                Text(label, style: _indexTitleStyle.copyWith(color: color ?? _indexTitleStyle.color)),
                Divider(thickness: 10, color: color),
              ],
            );
    }

    if (bunch) {
      //  eliminate title duplicates if bunched
      SplayTreeSet<PlayListItem> playListItemSet = SplayTreeSet<PlayListItem>((item1, item2) {
        return item1.title.compareTo(item2.title);
      })..addAll(playListItems);

      return Wrap(
        children: [
          ...playListItemSet.map<Widget>((e) {
            return e.toWidget(context, playListItemAction, isEditing, refocus, bunch, playListSortType);
          }),
        ],
      );
    }

    //  other indices are the song items
    return playListItems[index - 1].toWidget(context, playListItemAction, isEditing, refocus, bunch, playListSortType);
  }

  final String label;
  final List<PlayListItem> playListItems;
  final PlayListItemAction? playListItemAction;
  final Color? color;
  final bool bunch;
}

class PlayListGroup {
  const PlayListGroup(this.group);

  int get length => group.fold<int>(0, (i, e) {
    return i + e.length;
  });

  bool get isEmpty => group.isEmpty;

  bool get isNotEmpty => group.isNotEmpty;

  Widget _indexToWidget(
    final BuildContext context,
    int index,
    final bool isEditing,
    final VoidCallback? refocus,
    final PlayListSortType? playListSortType,
  ) {
    for (var itemList in group) {
      if (index >= itemList.length) {
        index -= itemList.length;
      } else {
        return itemList._indexToWidget(context, index, isEditing, refocus, playListSortType);
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
    isFromTheTop = true,
    isOrderBy = true,
    useAllFilters = false,
    required PlayListSearchMatcher playListSearchMatcher,
    allowSongListBunching = false,
  }) : this.byGroup(
         PlayListGroup([itemList]),
         key: key,
         style: style,
         includeByLastSung: includeByLastSung,
         isEditing: isEditing,
         isFromTheTop: isFromTheTop,
         isOrderBy: isOrderBy,
         showAllFilters: useAllFilters,
         playListSearchMatcher: playListSearchMatcher,
       );

  PlayList.byGroup(
    this.group, {
    super.key,
    this.style,
    this.includeByLastSung = false,
    this.isEditing = false,
    this.isFromTheTop = true,
    this.isOrderBy = true,
    this.showAllFilters = false,
    required this.playListSearchMatcher,
    this.allowSongListBunching = false,
    this.selectedPlayListSortType,
  }) : titleStyle = (style ?? generateAppTextStyle()).copyWith(fontWeight: .bold) {
    //
    titleFontSize = style?.fontSize ?? appDefaultFontSize;
    _textFontSize = 0.75 * titleFontSize;
    artistStyle = titleStyle.copyWith(fontSize: _textFontSize, fontWeight: .normal);

    searchDropDownStyle = artistStyle;
    searchTextStyle = titleStyle;

    _indexBunchStyle = generateAppTextStyle(fontSize: app.screenInfo.fontSize * 1.25);

    logger.log(_logConstruct, 'PlayList.byGroup(): constructor: _isEditing: $isEditing');
  }

  @override
  State<StatefulWidget> createState() => PlayListState();

  final PlayListGroup group;
  final TextStyle? style;
  final bool includeByLastSung;
  final bool isEditing;
  final bool isFromTheTop;
  final bool isOrderBy;
  final bool showAllFilters;
  final bool allowSongListBunching;

  final TextStyle titleStyle;
  late final double titleFontSize;
  late final TextStyle artistStyle;
  late final TextStyle searchDropDownStyle;
  late final TextStyle searchTextStyle;

  final PlayListSortType? selectedPlayListSortType;

  late final TextStyle oddTitleStyle = oddTitleTextStyle(from: titleStyle);
  late final TextStyle evenTitleStyle = evenTitleTextStyle(from: titleStyle);
  late final TextStyle oddTextStyle = oddTitleTextStyle(from: artistStyle);
  late final TextStyle evenTextStyle = evenTitleTextStyle(from: artistStyle);
  final PlayListSearchMatcher playListSearchMatcher;
}

class PlayListState extends State<PlayList> {
  PlayListState() {
    logger.log(_logConstruct, '_PlayListState():');
  }

  @override
  void initState() {
    super.initState();

    logger.log(_logInitState, '_PlayListState.initState():');
  }

  void focus(BuildContext context) {
    if (_searchTextFieldController.text.isNotEmpty) {
      _searchTextFieldController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchTextFieldController.text.length,
      );
    }
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  List<DropdownMenuItem<PlayListSortType>> _generateSortTypesDropDownMenuList() {
    //  generate the sort selection
    List<DropdownMenuItem<PlayListSortType>> ret = [];
    for (final e in PlayListSortType.values) {
      //  fool with the drop down options
      if (!widget.includeByLastSung) {
        switch (e) {
          case .byHistory:
          case .byLastSung:
          case .bySinger:
            //  if in a song play list, these should be removed
            continue;
          case .byTitle:
          case .byArtist:
          case .byLastChange:
          case .byComplexity:
          case .byPopularity:
          case .byYear:
          case .byDateCreated:
            break;
        }
      }
      ret.add(
        appDropdownMenuItem<PlayListSortType>(
          value: e,
          child: AppTooltip(
            message: e.toolTip,
            child: Text(Util.camelCaseToLowercaseSpace(e.name), style: widget.searchDropDownStyle),
          ),
        ),
      );
    }
    return ret;
  }

  @override
  Widget build(BuildContext context) {
    // //  fixme now: debug
    // logger.i('_sortTypesDropDownMenuList');
    // for (var dropDown in _sortTypesDropDownMenuList) {
    //   logger.i('   ${dropDown.value}');
    // }

    return Consumer<PlayListRefreshNotifier>(
      builder: (context, playListRefreshNotifier, child) {
        logger.log(
          _logBuild,
          '_PlayListState.build(): _isEditing: ${widget.isEditing}'
          ', text: "${_searchTextFieldController.text}"'
          ', positionPixels: ${playListRefreshNotifier.positionPixels}',

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
            ', positionPixels: ${playListRefreshNotifier.positionPixels}',
          );
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
          switch (_selectedPlayListSortType) {
            case .byArtist:
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
            case .byDateCreated:
              compare = (PlayListItem item1, PlayListItem item2) {
                if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                  var ret = -item1.song.dateCreated.compareTo(item2.song.dateCreated);
                  if (ret != 0) {
                    return ret;
                  }
                }
                return item1.compareTo(item2);
              };
              break;
            case .byLastChange:
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
            case .byComplexity:
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
            case .byPopularity:
              compare = (PlayListItem item1, PlayListItem item2) {
                if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                  var pop1 = songPopularity[item1.song.songId] ?? 0;
                  var pop2 = songPopularity[item2.song.songId] ?? 0;
                  var ret = -pop1.compareTo(pop2);
                  if (ret != 0) {
                    return ret;
                  }
                }
                return item1.compareTo(item2);
              };
              break;
            case .byHistory:
              compare = (PlayListItem item1, PlayListItem item2) {
                if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                  if (item1.songPerformance != null && item2.songPerformance != null) {
                    return -SongPerformance.compareByLastSungSongIdAndSinger(
                      item1.songPerformance!,
                      item2.songPerformance!,
                    );
                  }
                }
                return item1.compareTo(item2);
              };
              break;
            case .byLastSung:
              compare = (PlayListItem item1, PlayListItem item2) {
                if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                  if (item1.songPerformance != null && item2.songPerformance != null) {
                    return SongPerformance.compareByLastSungSongIdAndSinger(
                      item1.songPerformance!,
                      item2.songPerformance!,
                    );
                  }
                }
                return item1.compareTo(item2);
              };
              break;
            case .bySinger:
              compare = (PlayListItem item1, PlayListItem item2) {
                if (item1 is SongPlayListItem && item2 is SongPlayListItem) {
                  if (item1.songPerformance != null && item2.songPerformance != null) {
                    return SongPerformance.compareBySinger(item1.songPerformance!, item2.songPerformance!);
                  }
                }
                return item1.compareTo(item2);
              };
              break;
            case .byYear:
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
            case .byTitle:
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
              filterWidgets.add(
                Text(
                  lastName == nameValueMatcher.name && filter.isOr(nameValueMatcher) ? 'OR' : 'AND',
                  style: _indexTextStyle,
                ),
              );
            }
            filterWidgets.add(
              appIconWithLabelButton(
                icon: appIcon(Icons.clear),
                label: nameValueMatcher.toString(),
                fontSize: _textFontSize,
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
                  if (item
                          is SongPlayListItem //  fixme:
                          &&
                      filter.testAll(SongMetadata.songIdMetadata(item.song)?.nameValues)) {
                    filteredSet.add(item);
                  }
                }
              }

              if (filteredSet.isNotEmpty) {
                filteredSongLists.add(
                  PlayListItemList(
                    songList.label,
                    filteredSet.toList(growable: false),
                    playListItemAction: songList.playListItemAction,
                    color: songList.color,
                    bunch: isBunching(),
                  ),
                );
              } else {
                bestSongItemAction ??= songList.playListItemAction;
              }
            }
          }

          //  try the closest match?
          if (filteredSongLists.isEmpty && _searchTextFieldController.text.isNotEmpty) {
            final songTitles = app.allSongs.map((e) => e.title).toList(growable: false);
            BestMatch bestMatch = StringSimilarity.findBestMatch(_searchTextFieldController.text, songTitles);
            logger.i(
              'playList: $bestMatch, len: ${widget.group.group.length}'
              ' ${widget.group.group.first.playListItemAction}',
            );
            Song song = app.allSongs.toList(growable: false)[bestMatch.bestMatchIndex];
            app.selectedSong = song;
            filteredSongLists.add(
              PlayListItemList(
                'Did you mean?',
                [SongPlayListItem.fromSong(song)],
                playListItemAction: widget.group.group.first.playListItemAction, // fixme: not a great solution
                color: App.appBackgroundColor,
              ),
            );
          }
          logger.t('playlist: filteredSongLists.length: ${filteredSongLists.length}');
          filteredGroup = PlayListGroup(filteredSongLists);
        }

        //  don't always go back to the top of the play list
        // if (_itemScrollController.isAttached &&
        //     filteredGroup.group.isNotEmpty &&
        //     filteredGroup.group.first.playListItems.isNotEmpty &&
        //     _itemPositionsListener.itemPositions.value.isNotEmpty) {
        //   int length = filteredGroup.group.first.playListItems.length;
        //
        //   _requestedIndex = !_firstBuild //  not random if not the first build
        //           ||
        //           widget.isFromTheTop //  top if asked
        //           ||
        //           _filterNameValues.isNotEmpty //  not random if filtered
        //           ||
        //           _selectedSortType != .byTitle //  not random if not by title
        //           ||
        //           (length <= 20) //   not random if too small
        //       ? 0
        //       : _random.nextInt(length);
        //   _firstBuild = false;
        //
        //   logger.i('_requestedIndex: $_requestedIndex of $length');
        //   // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   //   if (_requestedIndex != null) {
        //   //     var currentIndex = _itemPositionsListener.itemPositions.value.first.index;
        //   //     int requestedIndex = _requestedIndex!;
        //   //     _requestedIndex = null;
        //   //     logger.i('Callback: currentIndex: $currentIndex, requestedIndex: $requestedIndex');
        //   //     if (_itemScrollController.isAttached) {
        //   //       //  fixme: I don't know why jump doesnt work here
        //   //       //  fixme: the reliability of the scroll seems sensitive to the duration!
        //   //       _itemScrollController.scrollTo(index: requestedIndex, duration: const Duration(milliseconds: 200));
        //   //     }
        //   //   }
        //   // });
        // }

        return Expanded(
          // for some reason, this is Expanded is very required,
          // otherwise the Column is unlimited and the list view fails
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Focus(
              onKeyEvent: _onKeyEvent,
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  AppWrapFullWidth(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      AppWrap(
                        alignment: WrapAlignment.spaceBetween,
                        children: [
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
                            message:
                                'Enter list search terms here.\n'
                                'Regular expressions can be used.',
                            child: AppTextField(
                              controller: _searchTextFieldController,
                              focusNode: _searchFocusNode,
                              hintText: 'Search here...',
                              width: app.screenInfo.fontSize * 15,
                              onChanged: (value) {
                                setState(() {
                                  if (_searchTextFieldController.text != value) {
                                    //  programmatic text entry
                                    _searchTextFieldController.text = value;
                                  }
                                  logger.t('search text: "$value"');
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
                              iconSize: 1.25 * widget.titleFontSize,
                              onPressed: (() {
                                _searchTextFieldController.clear();
                                app.clearMessage();
                                setState(() {
                                  FocusScope.of(context).requestFocus(_searchFocusNode);
                                  //_lastSelectedSong = null;
                                });
                              }),
                            ),
                          ),

                          const AppSpace(),
                          if (widget.allowSongListBunching)
                            AppTooltip(
                              message:
                                  'Toggle the bunching of the list.\n'
                                  'This will be disabled if searching.',
                              child: appButton(
                                _bunchSongList ? 'Expand' : 'Bunch',
                                onPressed: () {
                                  setState(() {
                                    _bunchSongList = !_bunchSongList;
                                  });
                                },
                              ),
                            ),
                          const AppSpace(),

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
                                  if (value == _allNameValue) {
                                    _filterNameValues.clear();
                                  } else {
                                    _filterNameValues.add(value);
                                  }
                                });
                              },
                            ),
                          ),
                          AppWrap(spacing: _textFontSize / 2, children: filterWidgets),
                        ],
                      ),

                      //  filters and order
                      AppWrap(
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          //  filters and order
                          if (app.isScreenBig && widget.isOrderBy)
                            AppWrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                AppTooltip(
                                  message: 'Select the order of the song list.',
                                  child: Text('Order: ', style: widget.searchDropDownStyle),
                                ),
                                appDropdownButton<PlayListSortType>(
                                  _generateSortTypesDropDownMenuList(),
                                  onChanged: (value) {
                                    if (_selectedPlayListSortType != value) {
                                      setState(() {
                                        _selectedPlayListSortType = value ?? .byTitle;
                                        app.clearMessage();
                                      });
                                    }
                                  },
                                  value: _selectedPlayListSortType,
                                  style: widget.searchDropDownStyle,
                                ),
                              ],
                            ),
                          Text('(${filteredGroup.length})', style: widget.artistStyle),
                        ],
                      ),
                    ],
                  ),
                  const AppSpace(),
                  Expanded(
                    child: ScrollablePositionedList.builder(
                      itemCount: filteredGroup.length,
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      scrollDirection: Axis.vertical,
                      itemBuilder: (context, index) {
                        logger.log(
                          _logPosition,
                          '_PlayListState: index: $index, pos:'
                          ' ${playListRefreshNotifier.positionPixels}'
                          // ', id: ${identityHashCode(playListRefreshNotifier)}'
                          ', isFromTheTop: ${widget.isFromTheTop}',
                        );
                        _indexTitleStyle = (index & 1) == 1 ? widget.oddTitleStyle : widget.evenTitleStyle;
                        _indexTextStyle = (index & 1) == 1 ? widget.oddTextStyle : widget.evenTextStyle;
                        return filteredGroup._indexToWidget(context, index, widget.isEditing, () {
                          focus(context);
                        }, _selectedPlayListSortType);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool isBunching() => widget.allowSongListBunching && _bunchSongList;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (_itemScrollController.isAttached && (event is KeyDownEvent || event is KeyRepeatEvent)) {
      //  filter the indexes to those that are fully seen
      SplayTreeSet<int> itemIndexes = SplayTreeSet()
        ..addAll(
          _itemPositionsListener.itemPositions.value
              .where((e) => e.itemLeadingEdge >= 0 && e.itemTrailingEdge < 1.0)
              .map((e) => e.index),
        );

      //  react to the paging requests
      switch (event.logicalKey) {
        case .arrowDown:
        case .pageDown:
          _itemScrollController.scrollTo(
            index: max(0, itemIndexes.last),
            duration: _pageTransitionDuration,
            curve: Curves.decelerate,
          );
          return KeyEventResult.handled;
        case .arrowUp:
        case .pageUp:
          _itemScrollController.scrollTo(
            index: max(0, itemIndexes.first - itemIndexes.length + 1),
            duration: _pageTransitionDuration,
            curve: Curves.decelerate,
          );
          return KeyEventResult.handled;
      }
    }
    logger.log(_logKeyboard, 'playList._onKeyEvent(): ignored: ${event.runtimeType}: ${event.logicalKey.keyLabel}');
    return KeyEventResult.ignored;
  }

  bool searchTextFieldIsEmpty() {
    return _searchTextFieldController.text.isEmpty;
  }

  set text(final String text) {
    setState(() {
      _searchTextFieldController.text = text;
    });
  }

  @override
  void dispose() {
    _searchTextFieldController.dispose();
    _searchFocusNode.dispose();
    logger.log(_logInitState, '_PlayListState.dispose():');
    super.dispose();
  }

  static const Duration _pageTransitionDuration = Duration(milliseconds: 1200);

  static final _allNameValue = NameValue('All', '');

  late PlayListSortType _selectedPlayListSortType = widget.selectedPlayListSortType ?? .byTitle;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  final TextEditingController _searchTextFieldController = TextEditingController();
  bool _bunchSongList = false;
  final FocusNode _searchFocusNode = FocusNode();
  static const _searchTextTooltipText = 'Enter search text here\nto help select the item.';
}
