import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/util/songSearchMatcher.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:reorderables/reorderables.dart';

import '../app/app.dart';

//  diagnostic logging enables
const Level _singerLogBuild = Level.debug;
const Level _singerRequester = Level.debug;

final AppOptions _appOptions = AppOptions();
final List<String> _sessionSingers =
    _appOptions.sessionSingers; //  in session order, stored locally to persist over screen reentry.

bool _isInSingingMode = false;
const String _unknownSinger = 'unknown';
String _selectedSinger = _unknownSinger;
bool _selectedSingerIsRequester = false;
String _selectedVolunteerSinger = _unknownSinger;
bool _searchForSelectedSingerOnly = true;

enum SingersSongOrder { singer, title, recentOnTop, oldestFirst }

/// Allow the session leader to manage songs for the singers currently present.
/// Remembers the last key and BPM used by a given singer to aid in the re-singing of that song by the singer.
class Singers extends StatefulWidget {
  const Singers({Key? key}) : super(key: key);

  @override
  _State createState() => _State();

  static const String routeName = '/singers';
}

class _State extends State<Singers> {
  _State()
      : _searchFocusNode = FocusNode(),
        _singerSearchFocusNode = FocusNode();

  @override
  initState() {
    super.initState();

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);

    logger.log(_singerLogBuild, 'singer build:  message: ${app.message}');

    if (_selectedSinger == _unknownSinger && _sessionSingers.isNotEmpty) {
      _setSelectedSinger(_sessionSingers.first);
    }

    _songSearchMatcher = SongSearchMatcher(searchTextFieldController.text);
    logger.d('searchTextFieldController.text: "${searchTextFieldController.text}"');

    final double fontSize = app.screenInfo.fontSize * 0.85;
    songPerformanceStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );
    disabledSongPerformanceStyle = songPerformanceStyle.copyWith(color: disabledColor);
    final buttonTextStyle = songPerformanceStyle.copyWith(backgroundColor: inactiveBackgroundColor);
    final inactiveRequesterButtonTextStyle = songPerformanceStyle.copyWith(backgroundColor: inactiveRequesterColor);
    final selectedButtonTextStyle = songPerformanceStyle.copyWith(backgroundColor: addColor);
    final singerTextStyle = generateAppTextFieldStyle(fontSize: fontSize, backgroundColor: inactiveBackgroundColor);

    List<Widget> sessionSingerWidgets = [];
    List<Widget> songWidgetList = [];

    //  order the performances by one of title, singer, date last sung, date last sung reversed
    Comparator<SongPerformance> songPerformanceComparator;
    switch (songOrder) {
      case SingersSongOrder.singer:
        songPerformanceComparator = (a, b) {
          int ret = a.singer.compareTo(b.singer);
          if (ret != 0) {
            return ret;
          }
          ret = a.songIdAsString.compareTo(b.songIdAsString);
          if (ret != 0) {
            return ret;
          }
          ret = a.lastSung.compareTo(b.lastSung);
          if (ret != 0) {
            return ret;
          }
          return 0;
        };
        break;
      case SingersSongOrder.recentOnTop:
        songPerformanceComparator = (a, b) {
          int ret = a.lastSung.compareTo(b.lastSung);
          if (ret != 0) {
            return -ret; //  last first!
          }
          //  not likely!
          ret = a.songIdAsString.compareTo(b.songIdAsString);
          if (ret != 0) {
            return ret;
          }
          ret = a.singer.compareTo(b.singer);
          if (ret != 0) {
            return ret;
          }
          return 0;
        };
        break;
      case SingersSongOrder.oldestFirst:
        songPerformanceComparator = (a, b) {
          int ret = a.lastSung.compareTo(b.lastSung);
          if (ret != 0) {
            return ret;
          }
          //  not likely!
          ret = a.songIdAsString.compareTo(b.songIdAsString);
          if (ret != 0) {
            return ret;
          }
          ret = a.singer.compareTo(b.singer);
          if (ret != 0) {
            return ret;
          }
          return 0;
        };
        break;
      case SingersSongOrder.title:
      default:
        songPerformanceComparator = (a, b) {
          int ret = a.songIdAsString.compareTo(b.songIdAsString);
          if (ret != 0) {
            return ret;
          }
          ret = a.singer.compareTo(b.singer);
          if (ret != 0) {
            return ret;
          }
          ret = a.lastSung.compareTo(b.lastSung);
          if (ret != 0) {
            return ret;
          }
          return 0;
        };
        break;
    }

    //  sorted and stored
    var requesters = _allSongPerformances.setOfRequesters();
    var songRequests = SplayTreeSet<Song>();
    SplayTreeSet<SongPerformance> performancesFromSinger = SplayTreeSet(songPerformanceComparator);
    SplayTreeSet<SongPerformance> performancesFromSingerMatching = SplayTreeSet(songPerformanceComparator);
    SplayTreeSet<SongPerformance> performancesFromSingerNotMatching = SplayTreeSet(songPerformanceComparator);
    SplayTreeSet<SongPerformance> performancesFromSessionSingers = SplayTreeSet(songPerformanceComparator);
    SplayTreeSet<Song> otherMatchingSongs = SplayTreeSet();
    SplayTreeSet<Song> otherSongs = SplayTreeSet();
    if (_selectedSingerIsRequester) {
      SplayTreeSet<SongRequest> songRequestsFromRequester = SplayTreeSet<SongRequest>()
        ..addAll(_allSongPerformances.allSongPerformanceRequests.where((e) => e.requester == _selectedSinger));
      logger.log(_singerRequester, 'requests: $songRequestsFromRequester');

      if (searchForSelectedSingerOnly) {
        songRequests.addAll(_allSongPerformances.allSongPerformanceRequests
            .where((e) =>
                e.requester == _selectedSinger && e.song != null && _songSearchMatcher.matchesOrEmptySearch(e.song!))
            .map((e) => e.song)
            .whereType<Song>());
        logger.log(_singerRequester, 'songRequests.length: ${songRequests.length}');
      } else {
        // find all the requested songs that match the current session singers
        songRequests = SplayTreeSet<Song>()
          ..addAll(songRequestsFromRequester
              .where((e) => e.requester == _selectedSinger && e.song != null)
              .map<Song>((e) => e.song!));
        logger.log(_singerRequester, 'requests: $songRequestsFromRequester');
        for (var singer in _sessionSingers) {
          if (singer != _selectedSinger) {
            for (var performance in _allSongPerformances.bySinger(singer)) {
              if (performance.song != null) {
                var song = performance.song!;
                if (_songSearchMatcher.matchesOrEmptySearch(song) && songRequests.contains(song)) {
                  performancesFromSessionSingers.add(performance);
                }
              }
            }
          }
        }
      }
    }

    //  fill the stores
    {
      SplayTreeSet<Song> songsSungBySingers = SplayTreeSet();

      //  songs sung by selected singer
      performancesFromSinger.addAll(_allSongPerformances.bySinger(_selectedSinger));
      for (var performance in performancesFromSinger) {
        if (performance.song != null) {
          var song = performance.song!;
          if (_songSearchMatcher.matches(song) /*	note: empty search means no match!  */) {
            performancesFromSingerMatching.add(performance);
          } else {
            performancesFromSingerNotMatching.add(performance);
          }
          songsSungBySingers.add(song);
        }
      }

      //  songs sung by other session singers
      if (!_selectedSingerIsRequester) {
        for (var singer in _sessionSingers) {
          if (!searchForSelectedSingerOnly || singer != _selectedSinger) {
            for (var performance in _allSongPerformances.bySinger(singer)) {
              if (performance.song != null) {
                var song = performance.song!;
                if (_songSearchMatcher.matchesOrEmptySearch(song)) {
                  performancesFromSessionSingers.add(performance);
                }
              }
            }
          }
        }
      }
      for (var song in app.allSongs) {
        if (!songsSungBySingers.contains(song) && !songRequests.contains(song)) {
          if (_songSearchMatcher.matches(song)) {
            otherMatchingSongs.add(song);
          } else {
            otherSongs.add(song);
          }
        }
      }
    }

    logger.d('performances:  searchForSelectedSingerOnly: $_searchForSelectedSingerOnly'
        ', search: ${_songSearchMatcher.isNotEmpty}');
    if (_selectedSinger != _unknownSinger) {
      // 		search text empty
      if (_selectedSingerIsRequester) {
        if (searchForSelectedSingerOnly) {
          addSongWidgets(songWidgetList, 'Songs $_selectedSinger would like to request:', songRequests,
              whenPressed: false, color: appBackgroundColor());

          //   - all other matching songs
          addPerformanceWidgets(songWidgetList, 'Other matching songs:', performancesFromSessionSingers);
        } else {
          //  requester matches
          addPerformanceWidgets(songWidgetList, '$_selectedSinger would like to hear:', performancesFromSessionSingers,
              color: appBackgroundColor());

          //  requester volunteers
          //  add a diver line
          songWidgetList.add(Divider(
            thickness: 10,
            color: appBackgroundColor(),
          ));
          songWidgetList.add(Text('Songs $_selectedSinger would like a singer volunteer:',
              style: songPerformanceStyle.copyWith(color: appBackgroundColor())));
          songWidgetList.add(const AppSpace());
          {
            List<Widget> list = [];
            for (var singer in _sessionSingers) {
              if (!requesters.contains(singer)) {
                list.add(appTextButton(singer,
                    appKeyEnum: AppKeyEnum.singersRequestVolunteer,
                    style: _selectedVolunteerSinger == singer ? selectedButtonTextStyle : buttonTextStyle,
                    onPressed: () {
                  setState(() {
                    _selectedVolunteerSinger = singer;
                  });
                }));
              }
            }
            songWidgetList.add(AppWrapFullWidth(
              children: list,
              spacing: 20,
            ));
          }
          songWidgetList.add(const AppSpace());
          addSongWidgets(
            songWidgetList,
            'for these favorites:',
            songRequests,
            enable: _selectedVolunteerSinger != _unknownSinger,
            color: appBackgroundColor(),
            divider: false,
            checkbox: false,
            whenPressed: _selectedVolunteerSinger != _unknownSinger,
          );
          addSongWidgets(songWidgetList, 'Other matching songs:', otherMatchingSongs);
        }
      } else if (searchForSelectedSingerOnly) {
        // 			search single singer selected
        // 			search for single singer selected
        // 				- performances from singer that match search
        addPerformanceWidgets(
            songWidgetList, 'Matching songs sung by $_selectedSinger:', performancesFromSingerMatching,
            color: appBackgroundColor());
        if (_songSearchMatcher.isNotEmpty) {
          //   - all other matching songs
          addSongWidgets(songWidgetList, 'Other matching songs:', otherMatchingSongs);
        }
        // 				- non matching performances from singer
        addPerformanceWidgets(
            songWidgetList,
            '$_selectedSinger '
            '${performancesFromSingerMatching.isNotEmpty ? 'also ' : ''}'
            'sings:',
            performancesFromSingerNotMatching,
            color: appBackgroundColor());
        if (_songSearchMatcher.isEmpty) {
          //   - all other matching songs
          addSongWidgets(songWidgetList, 'Other matching songs:', otherMatchingSongs);
        }
      } else {
        // 			search all singers selected
        // 				- performances from session singers
        addPerformanceWidgets(songWidgetList, 'Today\'s singers sing:', performancesFromSessionSingers,
            color: appBackgroundColor());
      }
    } else {
      //   selected singer NOT known
      // 			search all session singers
      // 				- performances from session singers that match
      addPerformanceWidgets(songWidgetList, 'Today\'s session singers sing:', performancesFromSessionSingers,
          color: appBackgroundColor());
      //   - all other matching songs
      addSongWidgets(songWidgetList, 'Other matching songs:', otherMatchingSongs);
    }

    //   - all the other songs not otherwise listed
    if (_songSearchMatcher.isEmpty) {
      if (_selectedSingerIsRequester) {
        if (searchForSelectedSingerOnly) {
          addSongWidgets(songWidgetList, 'Songs $_selectedSinger might request:', otherSongs, whenPressed: false);
        }
      } else {
        addSongWidgets(songWidgetList, 'Other songs:', otherSongs);
      }
    } else {
      if (_selectedSingerIsRequester) {
        if (searchForSelectedSingerOnly) {
          addSongWidgets(songWidgetList, 'Songs $_selectedSinger might request:', otherMatchingSongs,
              whenPressed: false);
        }
      } else {
        addSongWidgets(songWidgetList, 'Other matching songs:', otherMatchingSongs);
      }
    }

    logger.d(
        'all songs: ${(performancesFromSinger.length + performancesFromSingerMatching.length + performancesFromSingerNotMatching.length + performancesFromSessionSingers.length + otherMatchingSongs.length + otherSongs.length)}/${app.allSongs.length}');
    logger.d('performancesFromSinger: ${performancesFromSinger.length}'
        ', performancesFromSingerMatching:${performancesFromSingerMatching.length}'
        ', performancesFromSingerNotMatching:${performancesFromSingerNotMatching.length}'
        ', performancesFromSessionSingers:${performancesFromSessionSingers.length}'
        ', otherMatchingSongs:${otherMatchingSongs.length}'
        ', otherSongs:${otherSongs.length}');
    logger.d(
        '${(performancesFromSinger.length + performancesFromSingerMatching.length + performancesFromSingerNotMatching.length + performancesFromSessionSingers.length + otherSongs.length)}       /${app.allSongs.length}');
    assert((performancesFromSinger.length +
            performancesFromSingerMatching.length +
            performancesFromSingerNotMatching.length +
            performancesFromSessionSingers.length +
            otherMatchingSongs.length +
            otherSongs.length +
            songRequests.length) >=
        app.allSongs.length);

    {
      //  add  singer search
      sessionSingerWidgets.add(AppWrap(children: [
        AppTooltip(
          message: 'search',
          child: IconButton(
            icon: const Icon(Icons.search),
            iconSize: fontSize,
            onPressed: null,
          ),
        ),
        SizedBox(
          width: 10 * app.screenInfo.fontSize,
          //  limit text entry display length
          child: appTextField(
            appKeyEnum: AppKeyEnum.singersSingerSearchText,
            enabled: true,
            controller: singerSearchTextFieldController,
            focusNode: _singerSearchFocusNode,
            hintText: "enter singer search",
            onChanged: (text) {
              setState(() {
                //  code will respond to change of singer search text
              });
            },
            fontSize: fontSize,
          ),
        ),
        AppTooltip(
          message: 'Clear the singer search text.',
          child: appEnumeratedIconButton(
            appKeyEnum: AppKeyEnum.singersSingerClearSearch,
            icon: const Icon(Icons.clear),
            iconSize: 1.5 * fontSize,
            onPressed: (() {
              setState(() {
                singerSearchTextFieldController.text = '';
                FocusScope.of(context).requestFocus(_singerSearchFocusNode);
              });
            }),
          ),
        ),
      ], alignment: WrapAlignment.spaceBetween));

      //  find all singers
      var setOfPerformers = SplayTreeSet<String>();
      setOfPerformers.addAll(_allSongPerformances.setOfSingers());
      setOfPerformers.addAll(_allSongPerformances.setOfRequesters());
      if (_selectedSinger != _unknownSinger) {
        setOfPerformers.add(_selectedSinger);
      }

      var singerSearch = singerSearchTextFieldController.text.toLowerCase();
      {
        var lastFirstInitial = '';
        for (var performer in setOfPerformers) {
          if (singerSearch.isEmpty || performer.toLowerCase().contains(singerSearch)) {
            var firstInitial = performer.characters.first.toUpperCase();
            if (firstInitial != lastFirstInitial) {
              lastFirstInitial = firstInitial;
              sessionSingerWidgets.add(const AppSpaceViewportWidth(horizontalSpace: 100));
              sessionSingerWidgets.add(Text(
                '$firstInitial:',
                style: songPerformanceStyle.copyWith(color: appBackgroundColor()),
              ));
              sessionSingerWidgets.add(const AppSpace(horizontalSpace: 40));
            }
            sessionSingerWidgets.add(AppWrap(
              children: [
                appTextButton(
                  performer,
                  appKeyEnum: AppKeyEnum.singersAllSingers,
                  style: performer == _selectedSinger
                      ? songPerformanceStyle.copyWith(backgroundColor: addColor)
                      : songPerformanceStyle,
                  onPressed: () {
                    setState(() {
                      _setSelectedSinger(performer);
                    });
                  },
                ),
                if (!_sessionSingers.contains(performer))
                  AppInkWell(
                    appKeyEnum: AppKeyEnum.singersAddSingerToSession,
                    value: performer,
                    onTap: () {
                      setState(() {
                        _sessionSingers.add(performer);
                        _appOptions.sessionSingers = _sessionSingers;
                        _setSelectedSinger(performer);
                      });
                    },
                    child: appCircledIcon(
                      Icons.add,
                      'Add $performer to today\'s session.',
                      margin: appendInsets,
                      padding: appendPadding,
                      color: addColor,
                      size: fontSize * 0.7,
                    ),
                  ),
                if (_sessionSingers.contains(performer))
                  AppInkWell(
                    appKeyEnum: AppKeyEnum.singersRemoveSingerFromSession,
                    // value: singer,
                    onTap: () {
                      setState(() {
                        _sessionSingers.remove(performer);
                        _appOptions.sessionSingers = _sessionSingers;
                      });
                    },
                    child: appCircledIcon(
                      Icons.remove,
                      'Remove $performer from today\'s session.',
                      margin: appendInsets,
                      padding: appendPadding,
                      color: removeColor,
                      size: fontSize * 0.7,
                    ),
                  ),
                const AppSpace(horizontalSpace: 20), //  list singers horizontally
              ],
            ));
          }
        }
      }
    }

    if (searchForSelectedSingerOnly) {
      searchSelectedSingerSongs();
    } else {
      searchAllPerformanceSongs();
    }

    {
      songWidgetList.add(const AppVerticalSpace());
      songWidgetList.add(const Divider(
        thickness: 10,
      ));
      songWidgetList.add(Text(
        'Performance count: ${_allSongPerformances.length} ',
        style: songPerformanceStyle.copyWith(color: Colors.grey),
      ));
    }

    if (singerList.isEmpty) {
      singerList.addAll(_allSongPerformances.setOfSingers()); //  fixme: temp
    }

    void _onReorder(int oldIndex, int newIndex) {
      setState(() {
        logger.d('_onReorder($oldIndex, $newIndex)');
        var singer = _sessionSingers.removeAt(oldIndex);
        _sessionSingers.insert(newIndex, singer);
        _appOptions.sessionSingers = _sessionSingers;
      });
    }

    var todaysReorderableSingersWidgetWrap = _sessionSingers.isEmpty
        ? Text(
            '(none)',
            style: singerTextStyle,
          )
        : Container(
      child: AppWrapFullWidth(children: [
              ReorderableWrap(
                  children: _sessionSingers.map((singer) {
                    return AppWrap(children: [
                      Container(
                        child: appTextButton(
                          singer,
                          appKeyEnum: AppKeyEnum.singersSessionSingerSelect,
                          onPressed: () {
                            setState(() {
                              _setSelectedSinger(singer);
                            });
                          },
                          style: singer == _selectedSinger
                              ? selectedButtonTextStyle
                              : (requesters.contains(singer) ? inactiveRequesterButtonTextStyle : buttonTextStyle),
                        ),
                      ),
                      if (!_isInSingingMode)
                        AppInkWell(
                          appKeyEnum: AppKeyEnum.singersRemoveSingerFromSession,
                          // value: singer,
                          onTap: () {
                            setState(() {
                              _sessionSingers.remove(singer);
                              _appOptions.sessionSingers = _sessionSingers;
                            });
                          },
                          child: appCircledIcon(
                            Icons.remove,
                            'Remove $singer from today\'s session.',
                            margin: appendInsets,
                            padding: appendPadding,
                            color: removeColor,
                            size: fontSize * 0.7,
                          ),
                        ),
                    ]);
                  }).toList(growable: false),
                  onReorder: _onReorder,
                  padding: const EdgeInsets.all(10),
                  spacing: 20),
            ]),
            //   padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: appBackgroundColor(),
                width: 2,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
          );

    var allSingersWidgetWrap = Container(
      child: AppWrapFullWidth(children: sessionSingerWidgets, alignment: WrapAlignment.start, spacing: 10),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey,
          width: 2,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
    );

    //  generate the sort selection
    _sortOrderDropDownMenuList.clear();
    for (final e in SingersSongOrder.values) {
      var s = e.toString();
      _sortOrderDropDownMenuList.add(appDropdownMenuItem<SingersSongOrder>(
        appKeyEnum: AppKeyEnum.singersSortTypeSelection,
        value: e,
        child: Text(
          Util.camelCaseToLowercaseSpace(s.substring(s.indexOf('.') + 1)),
          style: singerTextStyle,
        ),
      ));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Singers'),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView(controller: scrollController, children: [
          AppWrapFullWidth(
            children: [
              if (app.message.isNotEmpty)
                Text(
                  app.message,
                  style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                  key: appKey(AppKeyEnum.singersErrorMessage),
                ),
              const AppVerticalSpace(),
              AppWrapFullWidth(children: [
                AppWrap(children: [
                  AppTooltip(
                    message: singingTooltipText,
                    child: appButton(
                      'Singing',
                      appKeyEnum: AppKeyEnum.singersSingingTextButton,
                      onPressed: () {
                        setState(() {
                          toggleSingingMode();
                        });
                      },
                      // softWrap: false,
                    ),
                  ),
                  AppTooltip(
                    message: singingTooltipText,
                    child: appSwitch(
                      appKeyEnum: AppKeyEnum.singersSinging,
                      onChanged: (value) {
                        setState(() {
                          toggleSingingMode();
                        });
                      },
                      value: _isInSingingMode,
                    ),
                  ),
                  if (!_isInSingingMode)
                    Text(
                      '       Make adjustments:',
                      style: singerTextStyle,
                      softWrap: false,
                    ),
                ]),
                if (!_isInSingingMode)
                  appButton('Other Actions', appKeyEnum: AppKeyEnum.singersShowOtherActions, onPressed: () {
                    setState(() {
                      showOtherActions = !showOtherActions;
                    });
                  }),
              ], alignment: WrapAlignment.spaceBetween),
              if (!_isInSingingMode && showOtherActions)
                AppWrapFullWidth(children: [
                  Column(
                    children: [
                      const AppVerticalSpace(),
                      if (_allSongPerformances.isNotEmpty)
                        AppTooltip(
                            message: 'For safety reasons you cannot remove all singers\n'
                                'without first having written them all.',
                            child: appEnumeratedButton(
                              'Write all singer songs to a local file',
                              appKeyEnum: AppKeyEnum.singersSave,
                              onPressed: () {
                                _saveAllSongPerformances().then((response) {
                                  setState(() {
                                    allHaveBeenWritten = true; //  fixme: on failure?
                                  });
                                });
                              },
                            )),
                      const AppVerticalSpace(),
                      if (_selectedSinger != _unknownSinger)
                        appEnumeratedButton(
                          'Write singer $_selectedSinger\'s songs to a local file',
                          appKeyEnum: AppKeyEnum.singersSaveSelected,
                          onPressed: () {
                            app.songPerformanceDaemon.saveSingersSongList(_selectedSinger);
                            logger.d('save selection: $_selectedSinger');
                          },
                        ),
                      const AppVerticalSpace(space: 25),
                      AppTooltip(
                        message: 'Singer performance updates read from a local file\n'
                            'will be added to the singers.',
                        child: appEnumeratedButton(
                          'Read singer performance updates from a local file',
                          appKeyEnum: AppKeyEnum.singersReadASingleSinger,
                          onPressed: () {
                            setState(() {
                              filePickUpdate(context);
                            });
                          },
                        ),
                      ),
                      const AppVerticalSpace(),
                      AppTooltip(
                        message: 'Convenience operation to clear all the singers from today\'s session.',
                        child: appEnumeratedButton(
                          'Clear the current session singers',
                          appKeyEnum: AppKeyEnum.singersReadASingleSinger,
                          onPressed: () {
                            setState(() {
                              _sessionSingers.clear();
                              _appOptions.sessionSingers = _sessionSingers;
                            });
                          },
                        ),
                      ),
                      const AppVerticalSpace(space: 25),
                      if (_selectedSinger != _unknownSinger)
                        appEnumeratedButton(
                          'Delete the singer $_selectedSinger',
                          appKeyEnum: AppKeyEnum.singersDeleteSinger,
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                      title: Text(
                                        'Do you really want to delete the singer $_selectedSinger?',
                                        style: TextStyle(fontSize: songPerformanceStyle.fontSize),
                                      ),
                                      actions: [
                                        appButton('Yes! Delete all of $_selectedSinger\'s song performances.',
                                            appKeyEnum: AppKeyEnum.singersDeleteSingerConfirmation, onPressed: () {
                                          logger.d('delete: $_selectedSinger');
                                          setState(() {
                                            _allSongPerformances.removeSinger(_selectedSinger);
                                            _sessionSingers.remove(_selectedSinger);
                                            _appOptions.sessionSingers = _sessionSingers;
                                            _setSelectedSinger(_unknownSinger);
                                            AppOptions().storeAllSongPerformances();
                                            allHaveBeenWritten = false;
                                          });
                                          Navigator.of(context).pop();
                                        }),
                                        const AppSpace(space: 100),
                                        appButton('Cancel, leave $_selectedSinger\'s song performances as is.',
                                            appKeyEnum: AppKeyEnum.singersCancelDeleteSinger, onPressed: () {
                                          Navigator.of(context).pop();
                                        }),
                                      ],
                                      elevation: 24.0,
                                    ));
                          },
                        ),
                      const AppVerticalSpace(),
                      if (!allHaveBeenWritten)
                        Text(
                          'Hint: Write all singer songs to enable all singer removal.',
                          style: singerTextStyle,
                        ),
                      if (allHaveBeenWritten)
                        appEnumeratedButton(
                          'Remove all singers',
                          appKeyEnum: AppKeyEnum.singersRemoveAllSingers,
                          onPressed: () {
                            setState(() {
                              _allSongPerformances.clear();
                              allHaveBeenWritten = false;
                            });
                          },
                        ),
                    ],
                    crossAxisAlignment: CrossAxisAlignment.end,
                  ),
                ], alignment: WrapAlignment.end),
              if (_songUpdateService.isFollowing)
                const AppVerticalSpace(
                  space: 20,
                ),
              if (_songUpdateService.isFollowing)
                AppWrapFullWidth(children: [
                  Text(
                    'Warning: you are not a leader!',
                    style: singerTextStyle,
                  ),
                  const AppVerticalSpace(),
                  if (_songUpdateService.isConnected)
                    appEnumeratedButton(
                      (_songUpdateService.isLeader ? 'Abdicate my leadership' : 'Make me the leader') +
                          ' of ${_songUpdateService.authority}',
                      appKeyEnum: AppKeyEnum.optionsLeadership,
                      onPressed: () {
                        setState(() {
                          if (_songUpdateService.isConnected) {
                            _songUpdateService.isLeader = !_songUpdateService.isLeader;
                          }
                        });
                      },
                    ),
                ]),
              if (!_isInSingingMode) const AppVerticalSpace(),
              if (!_isInSingingMode)
                AppWrapFullWidth(children: [
                  Text(
                    'Today\'s Session Singers:',
                    style: singerTextStyle,
                  ),
                  Text(
                    'to reorder: click, hold, and drag.',
                    style: singerTextStyle.copyWith(color: Colors.grey),
                  ),
                ], spacing: 30),
              const AppVerticalSpace(),
              todaysReorderableSingersWidgetWrap,
              const AppVerticalSpace(),
              if (!_isInSingingMode)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'All Singers:',
                    style: singerTextStyle,
                  ),

                  const AppVerticalSpace(),
                  allSingersWidgetWrap,
                  const AppVerticalSpace(),

                  //  new singer stuff
                  AppWrapFullWidth(children: [
                    SizedBox(
                      width: 16 * app.screenInfo.fontSize,
                      //  limit text entry display length
                      child: appTextField(
                        appKeyEnum: AppKeyEnum.singersNameEntry,
                        controller: singerTextFieldController,
                        hintText: "enter a new singer's name",
                        onSubmitted: (value) {
                          setState(() {
                            if (singerTextFieldController.text.isNotEmpty) {
                              _setSelectedSinger(Util.firstToUpper(singerTextFieldController.text));
                              singerTextFieldController.text = '';
                            }
                          });
                        },
                        fontSize: fontSize,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ], alignment: WrapAlignment.end, spacing: 30),
                ]),
              AppWrapFullWidth(children: [
                //  search line
                AppTooltip(
                  message: 'Search for songs for $_selectedSinger',
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    iconSize: fontSize,
                    onPressed: (() {}),
                  ),
                ),
                SizedBox(
                  width: 16 * app.screenInfo.fontSize,
                  //  limit text entry display length
                  child: appTextField(
                    appKeyEnum: AppKeyEnum.singersSearchText,
                    enabled: true,
                    controller: searchTextFieldController,
                    focusNode: _searchFocusNode,
                    hintText: 'enter song search${_selectedSinger != _unknownSinger ? ' for $_selectedSinger' : ''}',
                    onChanged: (text) {
                      setState(() {});
                    },
                    fontSize: fontSize,
                  ),
                ),
                AppTooltip(
                  message: 'Clear the search text for Singer $_selectedSinger.',
                  child: appEnumeratedIconButton(
                    appKeyEnum: AppKeyEnum.singersClearSearch,
                    icon: const Icon(Icons.clear),
                    iconSize: 1.5 * fontSize,
                    onPressed: (() {
                      setState(() {
                        searchClear();
                        FocusScope.of(context).requestFocus(_searchFocusNode);
                      });
                    }),
                  ),
                ),
              ], spacing: 10, alignment: WrapAlignment.start),
              const AppSpace(),
              AppWrapFullWidth(children: [
                AppWrap(children: [
                  Text(
                    'Search for:',
                    style: singerTextStyle,
                  ),
                  if (_selectedSinger != _unknownSinger)
                    AppRadio<bool>(
                        text: 'just $_selectedSinger',
                        appKeyEnum: AppKeyEnum.optionsNinJam,
                        value: true,
                        groupValue: searchForSelectedSingerOnly,
                        onPressed: () {
                          setState(() {
                            searchForSelectedSingerOnly = true;
                          });
                        },
                        style: singerTextStyle),
                  AppRadio<bool>(
                      text: 'any singer',
                      appKeyEnum: AppKeyEnum.optionsNinJam,
                      value: false,
                      groupValue: searchForSelectedSingerOnly,
                      onPressed: () {
                        setState(() {
                          searchForSelectedSingerOnly = false;
                        });
                      },
                      style: singerTextStyle),
                ], spacing: 10, alignment: WrapAlignment.spaceBetween),
                AppWrap(children: [
                  appWidgetHelper.checkbox(
                    value: _selectedSingerIsRequester,
                    onChanged: (bool? value) {
                      if (value != null) {
                        setState(() {
                          _selectedSingerIsRequester = value;
                        });
                      }
                    },
                    fontSize: songPerformanceStyle.fontSize,
                  ),
                  const AppSpace(),
                  Text('as requester', style: songPerformanceStyle),
                ]),
                AppWrap(children: [
                  AppTooltip(
                    message: 'Select the order of the song performance list.',
                    child: Text(
                      'Order by:',
                      style: singerTextStyle,
                    ),
                  ),
                  DropdownButton<SingersSongOrder>(
                    items: _sortOrderDropDownMenuList,
                    onChanged: (value) {
                      if (songOrder != value) {
                        setState(() {
                          songOrder = value ?? SingersSongOrder.singer;
                        });
                      }
                    },
                    value: songOrder,
                    style: singerTextStyle,
                    alignment: Alignment.topLeft,
                    elevation: 8,
                    itemHeight: null,
                  ),
                ]),
              ], spacing: 10, alignment: WrapAlignment.spaceBetween),
            ],
          ),
          ...songWidgetList //  add the computed widget list of lists
        ]),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.singersBack),
    );
  }

  void toggleSingingMode() {
    _isInSingingMode = !_isInSingingMode;
    if (!_sessionSingers.contains(_selectedSinger) && _sessionSingers.isNotEmpty) {
      _setSelectedSinger(_sessionSingers.first);
    }
    if (_isInSingingMode) {
      app.clearMessage();
    }
  }

  void addPerformanceWidgets(List<Widget> widgetList, String text, Iterable<SongPerformance> performances,
      {Color? color = Colors.black}) {
    if (performances.isNotEmpty) {
      //  add a diver line
      widgetList.add(Divider(
        thickness: 10,
        color: color,
      ));
      widgetList.add(Text(
        text,
        style: songPerformanceStyle.copyWith(color: color),
      ));

      widgetList.add(const AppVerticalSpace());
      for (var performance in performances) {
        widgetList.add(mapSongPerformanceToSingerWidget(performance));
      }

      widgetList.add(const AppVerticalSpace());
    }
  }

  void addSongWidgets(List<Widget> widgetList, String text, Iterable<Song> songs,
      {Color? color = Colors.black, divider = true, enable = true, final checkbox = true, final whenPressed = true}) {
    if (songs.isNotEmpty) {
      if (divider) {
        widgetList.add(Divider(
          thickness: 10,
          color: color,
        ));
      }
      widgetList.add(Text(
        text,
        style: songPerformanceStyle.copyWith(color: color),
      ));
      widgetList.add(const AppVerticalSpace());
      for (var song in songs) {
        widgetList.add(mapSongToWidget(song, enable: enable, checkbox: checkbox, whenPressed: whenPressed));
      }

      widgetList.add(const AppVerticalSpace());
    }
  }

  Widget mapSongToWidget(final Song song, {final enable = true, final checkbox = true, final whenPressed = true}) {
    return AppWrapFullWidth(
      children: [
        appWrapSongExplicit(
          song,
          enable: enable,
          onChanged: enable && checkbox
              ? (bool? value) {
                  if (value != null) {
                    setState(() {
                      if (_selectedSingerIsRequester) {
                        if (value) {
                          _allSongPerformances.addSongRequest(SongRequest(song.songId.toString(), _selectedSinger));
                        } else {
                          _allSongPerformances.removeSongRequest(SongRequest(song.songId.toString(), _selectedSinger));
                        }
                      } else if (_selectedSinger != _unknownSinger) {
                        //  not a requester
                        if (value) {
                          _allSongPerformances.addSongPerformance(SongPerformance.fromSong(song, _selectedSinger));
                        } else {
                          _allSongPerformances.removeSingerSong(_selectedSinger, song.songId.toString());
                        }
                      }
                      AppOptions().storeAllSongPerformances();
                    });
                  }
                }
              : null,
          whenPressed: whenPressed,
        ),
      ],
    );
  }

  Widget mapSongPerformanceToSingerWidget(SongPerformance songPerformance, {final whenPressed = true}) {
    if (songPerformance.song == null) {
      return Text('null song for ${songPerformance.songIdAsString}');
    }
    Song song = songPerformance.song!;
    var singer = songPerformance.singer;
    return AppWrapFullWidth(
      children: [
        appWrapSongExplicit(
          songPerformance.song,
          performer: songPerformance.singer,
          key: songPerformance.key,
          bpm: songPerformance.bpm,
          onChanged: (singer == _selectedSinger && searchForSelectedSingerOnly
              ? (bool? value) {
                  if (value != null) {
                    setState(() {
                      if (_selectedSingerIsRequester) {
                        if (value) {
                          _allSongPerformances.addSongRequest(SongRequest(song.songId.toString(), _selectedSinger));
                        } else {
                          _allSongPerformances.removeSongRequest(SongRequest(song.songId.toString(), _selectedSinger));
                        }
                      } else if (singer != _unknownSinger) {
                        //  not a requester
                        if (value) {
                          if (singer != _unknownSinger) {
                            _allSongPerformances.addSongPerformance(
                                SongPerformance(song.songId.toString(), singer, key: songPerformance.key));
                          }
                        } else {
                          _allSongPerformances.removeSingerSong(singer, song.songId.toString());
                        }
                      }
                      AppOptions().storeAllSongPerformances();
                    });
                  }
                }
              : null),
          whenPressed: whenPressed,
        ),
        Text(
          songPerformance.lastSungDateString + (kDebugMode ? ' ${hms(songPerformance.lastSung)}' : ''),
          style: songPerformanceStyle,
        ),
      ],
      alignment: WrapAlignment.spaceBetween,
    );
  }

  AppWrap appWrapSongExplicit(final Song? song,
      {final music_key.Key? key,
      final int? bpm,
      final String? performer,
      final bool enable = true,
      final ValueChanged<bool?>? onChanged,
      final whenPressed = true}) {
    if (song == null) {
      return const AppWrap(children: []);
    }

    var musician = performer != null ? (_selectedSingerIsRequester ? '$performer sing: ' : '$performer sings ') : '';
    var checkboxValue = _selectedSingerIsRequester
        ? _allSongPerformances.isSongInRequestersList(_selectedSinger, song)
        : _allSongPerformances.isSongInSingersList(_selectedSinger, song);
    return AppWrap(
      children: [
        if (onChanged != null)
          appWidgetHelper.checkbox(
            value: checkboxValue,
            onChanged: onChanged,
            fontSize: songPerformanceStyle.fontSize,
          ),
        if (onChanged != null) const AppSpace(space: 12),
        TextButton(
            child: Text(
              '$musician'
              '${song.title} by ${song.artist}'
              '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}'
              '${key == null ? '' : ' in $key'}'
              '${bpm == null && bpm != song.beatsPerMinute ? '' : ' at $bpm'}',
              style: enable ? songPerformanceStyle : disabledSongPerformanceStyle,
            ),
            onPressed: enable && whenPressed
                ? () {
                    //  play the song
                    var singer = performer ?? (_selectedSingerIsRequester ? _selectedVolunteerSinger : _selectedSinger);
                    logger.d('onPressed: singer: $singer, songId: ${song.songId}');
                    var songPerformance =
                        _allSongPerformances.find(singer: singer, song: song) ?? SongPerformance.fromSong(song, singer);

                    setState(() {
                      if (!_selectedSingerIsRequester) {
                        _setSelectedSinger(songPerformance.singer);
                      }
                      if (_selectedSinger != _unknownSinger) {
                        navigateToPlayer(context, songPerformance.copy());
                      }
                    });
                  }
                : null //
            ),
      ],
    );
  }

  void searchClear() {
    searchTextFieldController.clear();
    _songSearchMatcher = SongSearchMatcher(searchTextFieldController.text);
    searchAllPerformanceSongs();
  }

  void searchSelectedSingerSongs() {
    //  apply search filter
    selectedSongPerformances.clear();
    requestedSongPerformances.clear();
    _filteredSongs.clear();

    //  don't look for a singer not present
    if (!_sessionSingers.contains(_selectedSinger)) {
      return;
    }

    logger.d('allSongPerformances.length: ${_allSongPerformances.length}');

    //  select songs from the selected singer
    for (final SongPerformance songPerformance in _allSongPerformances.allSongPerformances) {
      if (songPerformance.song != null &&
          songPerformance.singer == _selectedSinger &&
          _songSearchMatcher.matchesOrEmptySearch(songPerformance.song!)) {
        //  matches
        selectedSongPerformances.add(songPerformance);
      }
    }

    logger.d('selectedSinger: $_selectedSinger, selectedSongPerformances.length: ${selectedSongPerformances.length}');

    for (final Song song in app.allSongs) {
      if (_songSearchMatcher.matchesOrEmptySearch(song)) {
        if (selectedSongPerformances.where((value) => value.song == song).isEmpty) {
          _filteredSongs.add(song);
        }
      }
    }
  }

  void searchAllPerformanceSongs() {
    //  apply search filter
    selectedSongPerformances.clear();
    requestedSongPerformances.clear();
    _filteredSongs.clear();
    var requestsFound = SplayTreeSet<Song>();

    if (_songSearchMatcher.isNotEmpty) {
      for (final SongPerformance songPerformance in _allSongPerformances.allSongPerformances) {
        if (songPerformance.song != null &&
            _sessionSingers.contains(songPerformance.singer) &&
            _songSearchMatcher.matchesOrEmptySearch(songPerformance.song!)) {
          //  matches
          requestedSongPerformances.add(songPerformance);
          requestsFound.add(songPerformance.song!);
        }
      }
    }

    for (final Song song in app.allSongs) {
      if (_songSearchMatcher.matchesOrEmptySearch(song)) {
        if (requestedSongPerformances.where((value) => value.song == song).isEmpty) {
          _filteredSongs.add(song);
        }
      }
    }
  }

  void navigateToPlayer(BuildContext context, SongPerformance songPerformance) async {
    if (songPerformance.song == null) {
      return;
    }
    logger.d('navigateToPlayer.playerSelectedBpm out: ${songPerformance.bpm}');
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Player(
            songPerformance.song!,
                //  adjust song to singer's last performance
                musicKey: songPerformance.key,
                bpm: songPerformance.bpm,
                singer: songPerformance.singer,
              )),
    );
    setState(() {
      //  fixme: song may have been edited in the player screen!!!!
      //  update the last sung date and the key if it has been changed
      _allSongPerformances.addSongPerformance(songPerformance.update(
          key: playerSelectedSongKey, bpm: playerSelectedBpm ?? songPerformance.song!.beatsPerMinute));
      logger.d('navigateToPlayer.playerSelectedBpm back: $playerSelectedBpm');
      AppOptions().storeAllSongPerformances();
      allHaveBeenWritten = false;

      if (_sessionSingers.isNotEmpty) {
        logger.log(_singerRequester, 'old _selectedSinger: $_selectedSinger');
        //  increment the selected singer or requester now that we're done singing a song
        var index = _sessionSingers.indexOf(_selectedSinger) + 1;
        _setSelectedSinger(_sessionSingers[index >= _sessionSingers.length ? 0 : index]);
      }

      searchClear();
      FocusScope.of(context).requestFocus(_searchFocusNode);
      scrollController.jumpTo(0);
    });
  }

  Future<void> _saveAllSongPerformances() async {
    return app.songPerformanceDaemon.saveAllSongPerformances();
  }

  String hms(int ms) {
    if (ms == 0) return '';
    return intl.DateFormat.Hms().format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  void filePickUpdate(BuildContext context) async {
    app.clearMessage();
    var content = await UtilWorkaround().filePickByExtension(context, AllSongPerformances.fileExtension);

    setState(() {
      if (content.isEmpty) {
        app.infoMessage('No singer file read');
      } else {
        int count = _allSongPerformances.updateFromJsonString(content);
        app.infoMessage('Performances updated: $count');
        logger.d('filePickUpdate: $count');
        _allSongPerformances.loadSongs(app.allSongs);
        if (count > 0) {
          AppOptions().storeAllSongPerformances();
          allHaveBeenWritten = false;
        }
      }
    });
  }

  void _songUpdateServiceCallback() {
    setState(() {});
  }

  @override
  void dispose() {
    _songUpdateService.removeListener(_songUpdateServiceCallback);
    super.dispose();
  }

  static const singingTooltipText = 'Switch to singing mode, otherwise make adjustments.';

  bool showOtherActions = false;
  List<String> singerList = [];
  SingersSongOrder songOrder = SingersSongOrder.title;

  TextStyle songPerformanceStyle = const TextStyle();
  TextStyle disabledSongPerformanceStyle = const TextStyle();

  SongSearchMatcher _songSearchMatcher = SongSearchMatcher('');
  var selectedSongPerformances = SplayTreeSet<SongPerformance>();
  var requestedSongPerformances = SplayTreeSet<SongPerformance>();

  final SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
  final FocusNode _searchFocusNode;

  final TextEditingController searchTextFieldController = TextEditingController();

  final FocusNode _singerSearchFocusNode;
  final TextEditingController singerSearchTextFieldController = TextEditingController();

  final List<DropdownMenuItem<SingersSongOrder>> _sortOrderDropDownMenuList = [];

  bool allHaveBeenWritten = false;

  final TextEditingController singerTextFieldController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  late AppWidgetHelper appWidgetHelper;

  final SongUpdateService _songUpdateService = SongUpdateService();

  set searchForSelectedSingerOnly(bool selection) {
    _searchForSelectedSingerOnly = _selectedSinger == _unknownSinger ? false : selection;
  }

  bool get searchForSelectedSingerOnly => _searchForSelectedSingerOnly;

  void _setSelectedSinger(String? singer) {
    if (singer != _selectedSinger) {
      _selectedSinger = singer ?? _unknownSinger;
      _selectedSingerIsRequester = _hasRequests(_selectedSinger);
      _searchForSelectedSingerOnly = !_selectedSingerIsRequester;
      _selectedVolunteerSinger = _unknownSinger;
      searchClear();
    }
  }

  final AllSongPerformances _allSongPerformances = AllSongPerformances();

  bool _hasRequests(String participant) {
    try {
      _allSongPerformances.allSongPerformanceRequests.firstWhere((element) => element.requester == participant);
      return true;
    } catch (e) {
      return false;
    }
  }

  static const inactiveBackgroundColor = Color(0xFFe0e0e0);
  static const disabledColor = Color(0xFFa0a0a0);
  static const inactiveRequesterColor = Color(0xFFceecf0);
  static const addColor = Color(0xFFa0eaa3);
  static const removeColor = Color(0xFFE57373); //var c = Colors.red[300]: Color(0xFFE57373),
  static const EdgeInsets appendInsets = EdgeInsets.all(3);
  static const EdgeInsets appendPadding = EdgeInsets.all(3);
}
