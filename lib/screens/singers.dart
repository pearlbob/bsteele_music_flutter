import 'dart:collection';

import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_performance.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:reorderables/reorderables.dart';

import '../app/app.dart';
import '../util/play_list_search_matcher.dart';

//  diagnostic logging enables
const Level _singerLogBuild = Level.debug;
const Level _singerRequester = Level.debug;
const Level _logSongList = Level.debug;
const Level _singerLogHistory = Level.debug;
const Level _logSongUpdate = Level.debug;

final List<String> _sessionSingers =
    AppOptions().sessionSingers; //  in session order, stored locally to persist over screen reentry.

bool _isInSingingMode = false;
const String _unknownSinger = 'unknown';
String _selectedSinger = _unknownSinger;
bool _selectedSingerIsRequester = false;
String _selectedVolunteerSinger = _unknownSinger;
bool _searchForSelectedSingerOnly = false;
Map<String, bool> _singerIsRequesterMap = {};

enum SingersSongOrder { singer, title, recentOnTop, oldestFirst }

/// Allow the session leader to manage songs for the singers currently present.
/// Remembers the last key and BPM used by a given singer to aid in the re-singing of that song by the singer.
class Singers extends StatefulWidget {
  const Singers({super.key});

  @override
  SingersState createState() => SingersState();

  static const String routeName = 'singers';
}

class SingersState extends State<Singers> {
  SingersState() : _singerSearchFocusNode = FocusNode();

  @override
  initState() {
    super.initState();

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    app.screenInfo.refresh(context);
    return Consumer<PlayListRefreshNotifier>(builder: (context, playListRefreshNotifier, child) {
      appWidgetHelper = AppWidgetHelper(context);

      logger.log(_singerLogBuild, 'singer build: _selectedSinger: $_selectedSinger,  message: ${app.message}');

      if (_selectedSinger == _unknownSinger && _sessionSingers.isNotEmpty) {
        _setSelectedSinger(_sessionSingers.first);
      }

      final double fontSize = app.screenInfo.fontSize * 1.3;
      songPerformanceStyle = generateAppTextStyle(
        color: Colors.black87,
        fontSize: fontSize,
      );
      disabledSongPerformanceStyle = songPerformanceStyle.copyWith(color: App.disabledColor);
      buttonTextStyle = songPerformanceStyle.copyWith(backgroundColor: inactiveBackgroundColor);
      inactiveRequesterButtonTextStyle = songPerformanceStyle.copyWith(backgroundColor: inactiveRequesterColor);
      selectedButtonTextStyle = songPerformanceStyle.copyWith(backgroundColor: addColor);
      final singerTextStyle = generateAppTextFieldStyle(fontSize: fontSize, backgroundColor: inactiveBackgroundColor);

      List<Widget> sessionSingerWidgets = [];
      songLists = [];

      //  sorted and stored
      var requesters = _allSongPerformances.setOfRequesters();
      var songRequests = SplayTreeSet<Song>();
      SplayTreeSet<SongPerformance> performancesFromSinger = SplayTreeSet();
      SplayTreeSet<SongPerformance> performancesFromSessionSingers = SplayTreeSet();
      SplayTreeSet<Song> otherSongs = SplayTreeSet();
      if (_selectedSingerIsRequester) {
        SplayTreeSet<SongRequest> songRequestsFromRequester = SplayTreeSet<SongRequest>()
          ..addAll(_allSongPerformances.allSongPerformanceRequests.where((e) => e.requester == _selectedSinger));
        logger.log(_singerRequester, 'requests: $songRequestsFromRequester');

        if (searchForSelectedSingerOnly) {
          songRequests.addAll(_allSongPerformances.allSongPerformanceRequests
              .where((e) => e.requester == _selectedSinger && e.song != null)
              .map((e) => e.song)
              .whereType<Song>());
          logger.log(_singerRequester, 'songRequests.length: ${songRequests.length}');
        } else {
          // find all the requested songs that match the current session singers
          songRequests = SplayTreeSet<Song>()
            ..addAll(songRequestsFromRequester
                .where((e) => e.requester == _selectedSinger && e.song != null)
                .map<Song>((e) => e.song!));
          logger.log(_singerRequester, 'requests: $songRequests');
          for (var singer in _sessionSingers) {
            if (singer != _selectedSinger) {
              for (var performance in _allSongPerformances.bySinger(singer)) {
                if (performance.song != null) {
                  performancesFromSessionSingers.add(performance);
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
            songsSungBySingers.add(performance.song!);
          }
        }

        //  songs sung by other session singers
        if (!_selectedSingerIsRequester) {
          for (var singer in _sessionSingers) {
            if (!searchForSelectedSingerOnly || singer != _selectedSinger) {
              for (var performance in _allSongPerformances.bySinger(singer)) {
                if (performance.song != null) {
                  performancesFromSessionSingers.add(performance);
                }
              }
            }
          }
        }
        for (var song in app.allSongs) {
          if (!songsSungBySingers.contains(song) && !songRequests.contains(song)) {
            otherSongs.add(song);
          }
        }
      }

      logger.d('performances:  searchForSelectedSingerOnly: $_searchForSelectedSingerOnly');
      if (_isInSingingMode) {
        if (_selectedSinger != _unknownSinger) {
          // 		search text empty
          if (_selectedSingerIsRequester) {
            if (searchForSelectedSingerOnly) {
              //  edit the requester's request list
              addSongItems('Songs $_selectedSinger would like to request:', songRequests,
                  color: App.appBackgroundColor, inRequesterList: true);
              addSongItems(
                  'Other songs $_selectedSinger might request:', app.allSongs.where((e) => !songRequests.contains(e)),
                  color: App.appBackgroundColor, inRequesterList: false);

              //   - all other matching songs
              addPerformanceItems('Other matching songs:', performancesFromSessionSingers);
            } else {
              //  requester matches
              if (_selectedVolunteerSinger == _unknownSinger) {
                addPerformanceItems('$_selectedSinger would like to hear:',
                    performancesFromSessionSingers.where((e) => songRequests.contains(e.song)),
                    color: App.appBackgroundColor);
              }

              if (_selectedVolunteerSinger != _unknownSinger) {
                var volunteerPerformances = performancesFromSessionSingers
                    .where((e) => songRequests.contains(e.song) && e.singer == _selectedVolunteerSinger);
                addPerformanceItems(
                    '$_selectedSinger would like to hear $_selectedVolunteerSinger sing:', volunteerPerformances,
                    color: App.appBackgroundColor);
                var volunteerSongs = volunteerPerformances.map((performance) => performance.performedSong);
                addSongItems('Other songs $_selectedVolunteerSinger might sing for $_selectedSinger:',
                    songRequests.where((song) => !volunteerSongs.contains(song)),
                    color: App.appBackgroundColor, songItemAction: _navigateSelectedVolunteerToPlayer);
              }
            }
          } else {
            // 				matching performances from the selected singer
            addPerformanceItems('$_selectedSinger sings:', performancesFromSinger, color: App.appBackgroundColor);

            //  all other songs
            //  note that the filtering is done by the play list
            addSongItems('Songs $_selectedSinger might sing:', otherSongs,
                color: App.appBackgroundColor, songItemAction: _navigateSelectedSingerToPlayer);
          }
        } else {
          //   selected singer NOT known
          // 			search all session singers
          // 				- performances from session singers that match
          addPerformanceItems('Today\'s session singers sing:', performancesFromSessionSingers,
              color: App.appBackgroundColor);
        }
      }

      logger.d('all songs: '
          '${(performancesFromSinger.length + performancesFromSessionSingers.length + otherSongs.length)}/${app.allSongs.length}');
      logger.d('performancesFromSinger: ${performancesFromSinger.length}'
          ', performancesFromSessionSingers:${performancesFromSessionSingers.length}'
          ', otherSongs:${otherSongs.length}');
      logger.d(
          '${(performancesFromSinger.length + performancesFromSessionSingers.length + otherSongs.length)}/${app.allSongs.length}');
      assert((performancesFromSinger.length +
              performancesFromSessionSingers.length +
              otherSongs.length +
              songRequests.length) >=
          app.allSongs.length);

      {
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
                  style: songPerformanceStyle.copyWith(color: App.appBackgroundColor),
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
                          appOptions.sessionSingers = _sessionSingers;
                          _setSelectedSinger(performer);
                          singerSearchTextFieldController.text = '';
                          FocusScope.of(context).requestFocus(_singerSearchFocusNode);
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
                          appOptions.sessionSingers = _sessionSingers;
                          singerSearchTextFieldController.text = '';
                          FocusScope.of(context).requestFocus(_singerSearchFocusNode);
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
                  const AppSpace(horizontalSpace: 20),
                  //  list singers horizontally
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

      if (singerList.isEmpty) {
        singerList.addAll(_allSongPerformances.setOfSingers()); //  fixme: temp
      }

      void onReorder(int oldIndex, int newIndex) {
        setState(() {
          logger.d('_onReorder($oldIndex, $newIndex)');
          var singer = _sessionSingers.removeAt(oldIndex);
          _sessionSingers.insert(newIndex, singer);
          appOptions.sessionSingers = _sessionSingers;
        });
      }

      var todaysReorderableSingersWidgetWrap = _sessionSingers.isEmpty
          ? Text(
              '(none)',
              style: singerTextStyle,
            )
          : Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: App.appBackgroundColor,
                  width: 2,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: AppWrapFullWidth(children: [
                ReorderableWrap(
                    onReorder: onReorder,
                    padding: const EdgeInsets.all(10),
                    spacing: 20,
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
                                appOptions.sessionSingers = _sessionSingers;
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
                    }).toList(growable: false)),
              ]),
            );

      var allSingersWidgetWrap = Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey,
            width: 2,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: AppWrapFullWidth(alignment: WrapAlignment.start, spacing: 10, children: sessionSingerWidgets),
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

      final songListGroup = PlayListGroup(songLists);
      logger.log(_logSongList, 'singers: songListGroup.length: ${songListGroup.length}');

      return Scaffold(
        backgroundColor: App.screenBackgroundColor,
        appBar: appWidgetHelper.backBar(title: 'bsteeleMusicApp Singers'),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (app.message.isNotEmpty)
                Text(
                  app.message,
                  style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                  key: appKeyCreate(AppKeyEnum.singersErrorMessage),
                ),

              //  singing / setup
              AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
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
                  const AppSpace(horizontalSpace: 30),
                  if (!_isInSingingMode)
                    Text(
                      '       Singer setup:',
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
                // if (_isInSingingMode && _dirtyCount > 0)
                //    //  no longer necessary!  History is from the web server logs
                //   appButton('Save $_dirtyCount', appKeyEnum: AppKeyEnum.singersShowOtherActions, onPressed: () {
                //     setState(() {
                //       _saveAllSongPerformances().then((response) {
                //         setState(() {
                //           allHaveBeenWritten = true;
                //           _dirtyCount = 0;
                //         });
                //       }).onError((error, stackTrace) {
                //         allHaveBeenWritten = false; //  fixme: on failure?
                //         app.errorMessage(error.toString());
                //       });
                //     });
                //   }),
                if (_isInSingingMode && app.fullscreenEnabled && !app.isFullScreen)
                  appButton('Fullscreen', appKeyEnum: AppKeyEnum.singersFullScreen, onPressed: () {
                    app.requestFullscreen();
                  }),
              ]),
              // setup
              if (!_isInSingingMode && showOtherActions)
                AppWrapFullWidth(alignment: WrapAlignment.end, children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppVerticalSpace(),
                      if (_allSongPerformances.isNotEmpty)
                        AppTooltip(
                            message: 'For safety reasons you cannot remove all singers\n'
                                'without first having written them all.',
                            child: appButton(
                              'Write all singer songs to a local file',
                              appKeyEnum: AppKeyEnum.singersSave,
                              onPressed: () {
                                _saveAllSongPerformances().then((response) {
                                  setState(() {
                                    allHaveBeenWritten = true;
                                  });
                                }).onError((error, stackTrace) {
                                  allHaveBeenWritten = false; //  fixme: on failure?
                                  app.errorMessage(error.toString());
                                });
                              },
                            )),
                      const AppVerticalSpace(),
                      if (_selectedSinger != _unknownSinger)
                        appButton(
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
                        child: appButton(
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
                        child: appButton(
                          'Clear the current session singers',
                          appKeyEnum: AppKeyEnum.singersReadASingleSinger,
                          onPressed: () {
                            setState(() {
                              _sessionSingers.clear();
                              appOptions.sessionSingers = _sessionSingers;
                            });
                          },
                        ),
                      ),
                      const AppVerticalSpace(space: 25),
                      if (_selectedSinger != _unknownSinger)
                        appButton(
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
                                            appOptions.sessionSingers = _sessionSingers;
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
                        appButton(
                          'Remove all singers',
                          appKeyEnum: AppKeyEnum.singersRemoveAllSingers,
                          onPressed: () {
                            setState(() {
                              _allSongPerformances.clear();
                              AppOptions().storeAllSongPerformances();
                              allHaveBeenWritten = false;
                            });
                          },
                        ),
                    ],
                  ),
                ]),
              if (_songUpdateService.isFollowing) const AppVerticalSpace(space: 20),
              //  leader warning
              if (_songUpdateService.isFollowing)
                AppWrapFullWidth(children: [
                  Text(
                    'Warning: you are not a leader!',
                    style: singerTextStyle,
                  ),
                  const AppSpace(),
                  if (_songUpdateService.isConnected)
                    appButton(
                      '${_songUpdateService.isLeader ? 'Abdicate my leadership' : 'Make me the leader'} of ${_songUpdateService.host}',
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
                AppWrapFullWidth(spacing: 30, children: [
                  Text(
                    'Today\'s Session Singers:',
                    style: singerTextStyle,
                  ),
                  Text(
                    'to reorder: click, hold, and drag.',
                    style: singerTextStyle.copyWith(color: Colors.grey),
                  ),
                ]),
              const AppVerticalSpace(),
              todaysReorderableSingersWidgetWrap,
              const AppVerticalSpace(),
              if (_isInSingingMode)
                AppWrapFullWidth(spacing: 10, alignment: WrapAlignment.spaceBetween, children: [
                  AppWrap(spacing: 10, children: [
                    appWidgetHelper.checkbox(
                      value: _selectedSingerIsRequester,
                      onChanged: (bool? value) {
                        if (value != null) {
                          setState(() {
                            _selectedSingerIsRequester = value;
                            _singerIsRequesterMap[_selectedSinger] = _selectedSingerIsRequester;
                            logger.d('_selectedSingerIsRequester: $_selectedSingerIsRequester');
                          });
                        }
                      },
                      style: songPerformanceStyle,
                    ),
                    //  requester enable
                    AppTooltip(
                        message: 'Check here to make this individual a requester\n'
                            'of songs from the singers list above\n'
                            'or to edit their request list.\n'
                            'Uncheck to see the songs the singer has sung.',
                        child: TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedSingerIsRequester = !_selectedSingerIsRequester;
                                _singerIsRequesterMap[_selectedSinger] = _selectedSingerIsRequester;
                                _searchForSelectedSingerOnly = false;
                                logger.d('_selectedSingerIsRequester: $_selectedSingerIsRequester');
                              });
                            },
                            child: Text('As requester:', style: songPerformanceStyle))),
                    if (_selectedSingerIsRequester)
                      AppWrap(spacing: 10, alignment: WrapAlignment.spaceBetween, children: [
                        AppTooltip(
                          message: 'Click to see the songs the other singers sing\n'
                              'that have been requested by this requester',
                          child: AppRadio<bool>(
                              text: 'from the active singers above',
                              appKeyEnum: AppKeyEnum.singersActiveSingers,
                              value: false,
                              groupValue: searchForSelectedSingerOnly,
                              onPressed: () {
                                setState(() {
                                  searchForSelectedSingerOnly = false;
                                });
                              },
                              style: singerTextStyle),
                        ),
                        if (_selectedSinger != _unknownSinger)
                          AppTooltip(
                            message: 'Click to edit the songs requested by this requester',
                            child: AppRadio<bool>(
                                text: 'edit $_selectedSinger requests',
                                appKeyEnum: AppKeyEnum.optionsNinJam,
                                value: true,
                                groupValue: searchForSelectedSingerOnly,
                                onPressed: () {
                                  setState(() {
                                    searchForSelectedSingerOnly = true;
                                  });
                                },
                                style: singerTextStyle),
                          ),
                      ]),
                  ]),
                ]),
              if (!_isInSingingMode)
                //  singers
                AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
                  Text(
                    'All Singers:',
                    style: singerTextStyle,
                  ),
                  AppWrap(children: [
                    AppTooltip(
                      message: 'search',
                      child: IconButton(
                        icon: const Icon(Icons.search),
                        iconSize: fontSize,
                        onPressed: null,
                      ),
                    ),
                    SizedBox(
                      width: 15 * fontSize,
                      //  limit text entry display length
                      child: AppTextField(
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
                      child: appIconButton(
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
                  ]),
                  SizedBox(
                    //  new singer stuff
                    width: 25 * app.screenInfo.fontSize,
                    //  limit text entry display length
                    child: AppTextField.onSubmitted(
                      appKeyEnum: AppKeyEnum.singersNameEntry,
                      controller: singerTextFieldController,
                      hintText: "enter a new singer's name",
                      onSubmitted: (value) {
                        setState(() {
                          if (singerTextFieldController.text != value) {
                            //  when programmatically entered
                            singerTextFieldController.text = value;
                          }
                          if (singerTextFieldController.text.isNotEmpty) {
                            var performer = Util.firstToUpper(singerTextFieldController.text);
                            // add to current singers
                            _sessionSingers.add(performer);
                            appOptions.sessionSingers = _sessionSingers;
                            _setSelectedSinger(performer);
                            singerTextFieldController.text = '';
                            FocusScope.of(context).requestFocus(_singerSearchFocusNode);
                          }
                        });
                      },
                      fontSize: fontSize,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ]),
              const AppSpace(),
              if (!_isInSingingMode)
                Expanded(
                    child: ListView(controller: ScrollController(), children: [
                  allSingersWidgetWrap,
                ])),
              if (_isInSingingMode && songListGroup.isEmpty)
                Text(
                  'The requester $_selectedSinger has an empty request list.  Edit the requests!',
                  style: singerTextStyle.copyWith(color: Colors.red),
                ),
              if (_isInSingingMode && songListGroup.isNotEmpty) _volunteersWidget(),
              if (_isInSingingMode && songListGroup.isNotEmpty)
                PlayList.byGroup(
                  songListGroup,
                  style: singerTextStyle,
                  includeByLastSung: true,
                  isFromTheTop: false,
                  selectedSortType: PlayListSortType.byTitle,
                  playListSearchMatcher: SongPlayListSearchMatcher(),
                ),
            ],
          ),
        ),
        floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.singersBack),
      );
    });
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

  void addPerformanceItems(String text, Iterable<SongPerformance> performances, {Color? color = Colors.black}) {
    if (performances.isNotEmpty) {
      List<PlayListItem> songListItems = [];

      for (var performance in performances) {
        songListItems.add(SongPlayListItem.fromPerformance(performance));
      }

      songLists.add(PlayListItemList(text, songListItems, color: color, playListItemAction: _navigateSongListToPlayer));
    }
  }

  void addSongItems(String text, Iterable<Song> songs,
      {Color? color = Colors.black, bool? inRequesterList, Widget? customWidget, PlayListItemAction? songItemAction}) {
    List<PlayListItem> songListItems = [];
    if (songs.isNotEmpty) {
      for (var song in songs) {
        songListItems.add(SongPlayListItem.fromSong(song,
            firstWidget: (inRequesterList != null ? requesterListEditCustomWidget(song, inRequesterList) : null),
            customWidget: customWidget));
      }

      songLists.add(PlayListItemList(text, songListItems, color: color, playListItemAction: songItemAction));
    }
  }

  requesterListEditCustomWidget(Song song, bool checked) {
    return Consumer<PlayListRefreshNotifier>(builder: (context, playListRefreshNotifier, child) {
      return appWidgetHelper.checkbox(
          value: checked,
          label: 'for $_selectedSinger',
          style: appTextStyle,
          onChanged: (value) {
            if (value != null) {
              if (value) {
                _allSongPerformances.addSongRequest(SongRequest(song.songId.toString(), _selectedSinger));
              } else {
                _allSongPerformances.removeSongRequest(SongRequest(song.songId.toString(), _selectedSinger));
              }
              playListRefreshNotifier.refresh();
            }
          });
    });
  }

  Widget mapSongPerformanceToSingerWidget(SongPerformance songPerformance, {final whenPressed = true}) {
    if (songPerformance.song == null) {
      return Text('null song for ${songPerformance.songIdAsString}');
    }
    Song song = songPerformance.song!;
    var singer = songPerformance.singer;
    return AppWrapFullWidth(
      alignment: WrapAlignment.spaceBetween,
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
            style: songPerformanceStyle,
          ),
        if (onChanged != null) const AppSpace(space: 12),
        TextButton(
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
                        _navigateToPlayer(context, songPerformance.copyWith());
                      }
                    });
                  }
                : null,
            child: Text(
              '$musician'
              '${song.title} by ${song.artist}'
              '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}'
              '${key == null ? '' : ' in $key'}'
              '${bpm == null && bpm != song.beatsPerMinute ? '' : ' at $bpm'}',
              style: enable ? songPerformanceStyle : disabledSongPerformanceStyle,
            ) //
            ),
      ],
    );
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
      if (songPerformance.song != null && songPerformance.singer == _selectedSinger) {
        //  matches
        selectedSongPerformances.add(songPerformance);
      }
    }

    logger.d('selectedSinger: $_selectedSinger, selectedSongPerformances.length: ${selectedSongPerformances.length}');

    for (final Song song in app.allSongs) {
      if (selectedSongPerformances.where((value) => value.song == song).isEmpty) {
        _filteredSongs.add(song);
      }
    }
  }

  void searchAllPerformanceSongs() {
    //  apply search filter
    selectedSongPerformances.clear();
    requestedSongPerformances.clear();
    _filteredSongs.clear();
    var requestsFound = SplayTreeSet<Song>();

    for (final SongPerformance songPerformance in _allSongPerformances.allSongPerformances) {
      if (songPerformance.song != null && _sessionSingers.contains(songPerformance.singer)) {
        //  matches
        requestedSongPerformances.add(songPerformance);
        requestsFound.add(songPerformance.song!);
      }
    }

    for (final Song song in app.allSongs) {
      if (requestedSongPerformances.where((value) => value.song == song).isEmpty) {
        _filteredSongs.add(song);
      }
    }
  }

  void _navigateToPlayer(BuildContext context, SongPerformance songPerformance) async {
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
    _nextSinger(songPerformance);
  }

  Widget _volunteersWidget() {
    if (!_isInSingingMode || !_selectedSingerIsRequester || searchForSelectedSingerOnly) {
      return NullWidget();
    }
    return AppWrapFullWidth(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Volunteer Singer:',
          style: songPerformanceStyle,
        ),
        const AppSpace(),
        ..._potentialVolunteers().map(
              (singer) => appIdButton(
            singer,
            appKeyEnum: AppKeyEnum.singersVolunteerSingerSelect,
            id: Id(singer),
            onPressed: () {
              setState(() {
                _selectedVolunteerSinger = singer;
              });
            },
            style: _selectedVolunteerSinger == singer ? selectedButtonTextStyle : buttonTextStyle,
          ),
        ),
        AppTooltip(
          message: 'Clear the volunteer selection.',
          child: appIconButton(
            appKeyEnum: AppKeyEnum.singersVolunteerSingerSelectClear,
            icon: const Icon(Icons.clear),
            iconSize: 1.5 * app.screenInfo.fontSize,
            onPressed: (() {
              setState(() {
                _selectedVolunteerSinger = _unknownSinger;
              });
            }),
          ),
        ),
      ],
    );
  }

  List<String> _potentialVolunteers() {
    SplayTreeSet<String> volunteers = SplayTreeSet();

    for (var singer in _sessionSingers) {
      if (singer != _selectedSinger && _allSongPerformances.bySinger(singer).isNotEmpty) {
        volunteers.add(singer);
      }
    }
    return volunteers.toList(growable: false);
  }

  // _volunteerSingerPopup(BuildContext context, PlayListItem playListItem) {
  //   logger.t('temp: _volunteerSingerPopup($context,  $playListItem)');
  //   List<Widget> singerSelections = [];
  //   for (var singer in _sessionSingers) {
  //     if (singer == _selectedSinger) {
  //       continue;
  //     }
  //     singerSelections.add(
  //       appTextButton(
  //         singer,
  //         appKeyEnum: AppKeyEnum.singersVolunteerSingerSelect,
  //         onPressed: () async {
  //           logger.t('volunteer: $singer');
  //           var performance = SongPerformance.fromSong(playListItem.song, singer);
  //           await _navigatePerformanceToPlayer(context, performance);
  //           if (mounted) {
  //             Navigator.of(context).pop();
  //           }
  //         },
  //         style: buttonTextStyle,
  //       ),
  //     );
  //   }
  //
  //   showDialog(
  //       context: context,
  //       builder: (_) => AlertDialog(
  //             title: Text(
  //               'Select a volunteer singer from:',
  //               style: songPerformanceStyle,
  //             ),
  //             actions: [
  //               AppWrapFullWidth(alignment: WrapAlignment.spaceAround, children: singerSelections),
  //               const AppSpace(space: 100),
  //               appButton('Cancel', appKeyEnum: AppKeyEnum.listsCancelDeleteList, onPressed: () {
  //                 Navigator.of(context).pop();
  //               }),
  //             ],
  //             elevation: 24.0,
  //           ));
  // }

  _navigateSelectedSingerToPlayer(BuildContext context, PlayListItem playListItem) async {
    if (playListItem is SongPlayListItem) {
      _navigatePerformanceToPlayer(context, SongPerformance.fromSong(playListItem.song, _selectedSinger));
    }
  }

  _navigateSelectedVolunteerToPlayer(BuildContext context, PlayListItem playListItem) async {
    if (playListItem is SongPlayListItem) {
      _navigatePerformanceToPlayer(context, SongPerformance.fromSong(playListItem.song, _selectedVolunteerSinger));
    }
  }

  _navigateSongListToPlayer(BuildContext context, PlayListItem playListItem) async {
    if (playListItem is SongPlayListItem) {
      if (playListItem.songPerformance != null) {
        _navigatePerformanceToPlayer(context, playListItem.songPerformance!);
      } else {
        //  make a new performance since we don't have one
        var song = playListItem.song;
        _navigatePerformanceToPlayer(
            context,
            SongPerformance(song.songId.toString(), _selectedSinger,
                key: song.key, bpm: song.beatsPerMinute, song: song));
      }
    }
  }

  _navigatePerformanceToPlayer(BuildContext context, SongPerformance performance) async {
    app.clearMessage();

    app.selectedSong = performance.performedSong;
    logger.t('_navigatePerformanceToPlayer: $performance');
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Player(
                app.selectedSong,
                //  adjust song to singer's last performance
                musicKey: performance.key,
                bpm: performance.bpm,
                singer: performance.singer,
              )),
    );
    _nextSinger(performance);
  }

  _nextSinger(SongPerformance songPerformance) {
    setState(() {
      //  fixme: song may have been edited in the player screen!!!!
      //  update the last sung date and the key if it has been changed
      var updatedPerformance = songPerformance.copyWith(
          key: playerSelectedSongKey, bpm: playerSelectedBpm ?? songPerformance.song!.beatsPerMinute);
      _allSongPerformances.addSongPerformance(updatedPerformance);
      logger.log(_singerLogHistory, 'updatedPerformance: $updatedPerformance');
      logger.d('navigateToPlayer.playerSelectedBpm back: $playerSelectedBpm');
      AppOptions().storeAllSongPerformances();
      allHaveBeenWritten = false;

      //  push the selected singer forward in the list
      if (_sessionSingers.isNotEmpty) {
        logger.log(_singerRequester, 'old _selectedSinger: $_selectedSinger');
        //  increment the selected singer or requester now that we're done singing a song
        var index = _sessionSingers.indexOf(_selectedSinger) + 1;
        _setSelectedSinger(_sessionSingers[index >= _sessionSingers.length ? 0 : index]);
      }
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
    if (content.isEmpty) {
      app.infoMessage = 'No singer file read';
    } else {
      int count = _allSongPerformances.updateFromJsonString(content);
      app.infoMessage = 'Performances updated: $count';
      logger.d('filePickUpdate: $count');
      _allSongPerformances.loadSongs(app.allSongs);
      if (count > 0) {
        AppOptions().storeAllSongPerformances();
        allHaveBeenWritten = false;
      }
    }

    setState(() {});
  }

  void _songUpdateServiceCallback() {
    logger.log(_logSongUpdate, '_songUpdateServiceCallback()');
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

  TextStyle songPerformanceStyle = const TextStyle();
  TextStyle disabledSongPerformanceStyle = const TextStyle();
  TextStyle buttonTextStyle = const TextStyle();
  TextStyle inactiveRequesterButtonTextStyle = const TextStyle();
  TextStyle selectedButtonTextStyle = const TextStyle();

  var selectedSongPerformances = SplayTreeSet<SongPerformance>();
  var requestedSongPerformances = SplayTreeSet<SongPerformance>();

  List<PlayListItemList> songLists = [];

  final SplayTreeSet<Song> _filteredSongs = SplayTreeSet();

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

      //  find last requester choice or default to singer if there are songs to sing
      bool isRequester = _singerIsRequesterMap[_selectedSinger] ?? false;

      _selectedSingerIsRequester = isRequester;
      _searchForSelectedSingerOnly = _selectedSingerIsRequester;
      _selectedVolunteerSinger = _unknownSinger;

      //  reset the singer's list
      Provider.of<PlayListRefreshNotifier>(context, listen: false).requestSearchClear();

      logger.t('_setSelectedSinger(): $singer, isRequester: $isRequester');
    }
  }

  // bool _hasSongsToSing(String singer) {
  //   return _allSongPerformances.bySinger(singer).isNotEmpty;
  // }

  final AllSongPerformances _allSongPerformances = AllSongPerformances();

  static const inactiveBackgroundColor = Color(0xFFe0e0e0);
  static const inactiveRequesterColor = Color(0xFFceecf0);
  static const addColor = Color(0xFFa0eaa3);
  static const removeColor = Color(0xFFE57373); //var c = Colors.red[300]: Color(0xFFE57373),
  static const EdgeInsets appendInsets = EdgeInsets.all(3);
  static const EdgeInsets appendPadding = EdgeInsets.all(3);

  final appOptions = AppOptions();
}
