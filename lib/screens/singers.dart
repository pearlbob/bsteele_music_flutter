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
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/intl.dart';
import 'package:reorderables/reorderables.dart';

import '../app/app.dart';

final _blue = Paint()..color = Colors.lightBlue.shade200;

final List<String> _sessionSingers = []; //  in session order, stored locally to persist over screen reentry.

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
      : searchFocusNode = FocusNode(),
        singerSearchFocusNode = FocusNode();

  @override
  initState() {
    super.initState();

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);

    songSearchMatcher = SongSearchMatcher(searchTextFieldController.text);

    final double fontSize = app.screenInfo.fontSize;
    songPerformanceStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

    List<Widget> sessionSingerWidgets = [];
    {
      //  add  singer search
      sessionSingerWidgets.add(appWrap([
        appTooltip(
          message: 'search',
          child: IconButton(
            icon: const Icon(Icons.search),
            iconSize: fontSize,
            onPressed: (() {}),
          ),
        ),
        SizedBox(
          width: 14 * app.screenInfo.fontSize,
          //  limit text entry display length
          child: appTextField(
            appKeyEnum: AppKeyEnum.singersSingerSearchText,
            enabled: true,
            controller: singerSearchTextFieldController,
            hintText: "enter singer search",
            onChanged: (text) {
              setState(() {
                //  code will respond to change of singer search text
              });
            },
            fontSize: fontSize,
          ),
        ),
        appTooltip(
          message: 'Clear the singer search text.',
          child: appEnumeratedIconButton(
            appKeyEnum: AppKeyEnum.singersSingerClearSearch,
            icon: const Icon(Icons.clear),
            iconSize: 1.5 * fontSize,
            onPressed: (() {
              setState(() {
                singerSearchTextFieldController.text = '';
                FocusScope.of(context).requestFocus(singerSearchFocusNode);
              });
            }),
          ),
        ),
      ], alignment: WrapAlignment.spaceBetween));

      //  find all singers
      var setOfSingers = SplayTreeSet<String>();
      setOfSingers.addAll(allSongPerformances.setOfSingers());
      if (selectedSinger != unknownSinger) {
        setOfSingers.add(selectedSinger);
      }

      var singerSearch = singerSearchTextFieldController.text.toLowerCase();
      for (var singer in setOfSingers) {
        if (singerSearch.isEmpty || singer.toLowerCase().contains(singerSearch)) {
          sessionSingerWidgets.add(appWrap(
            [
              appTextButton(
                singer,
                appKeyEnum: AppKeyEnum.singersAllSingers,
                style: singer == selectedSinger
                    ? songPerformanceStyle.copyWith(backgroundColor: addColor)
                    : songPerformanceStyle,
                onPressed: () {
                  setState(() {
                    selectedSinger = singer;
                    searchForSelectedSingerOnly = true;
                  });
                },
              ),
              if (!_sessionSingers.contains(singer))
                appInkWell(
                  appKeyEnum: AppKeyEnum.singersAddSingerToSession,
                  value: singer,
                  onTap: () {
                    setState(() {
                      _sessionSingers.add(singer);
                      selectedSinger = singer;
                      searchForSelectedSingerOnly = true;
                    });
                  },
                  child: appCircledIcon(
                    Icons.add,
                    'Add $singer to today\'s session.',
                    margin: appendInsets,
                    padding: appendPadding,
                    color: addColor,
                    size: fontSize * 0.7,
                  ),
                ),
              if (_sessionSingers.contains(singer))
                appInkWell(
                  appKeyEnum: AppKeyEnum.singersRemoveSingerFromSession,
                  // value: singer,
                  onTap: () {
                    setState(() {
                      _sessionSingers.remove(singer);
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
              appSpace(verticalSpace: 20),
            ],
          ));
        }
      }
    }

    if (searchForSelectedSingerOnly) {
      searchSelectedSingerSongs();
    } else {
      searchAllPerformanceSongs();
    }

    List<Widget> songWidgetList = [];
    {
      if (selectedSinger != unknownSinger && allSongPerformances.bySinger(selectedSinger).isEmpty) {
        songWidgetList.add(Text(
          'Select at least one song for $selectedSinger to remain a singer! ',
          style: songPerformanceStyle.copyWith(color: _blue.color),
        ));
      }
      if (requestedSongPerformances.isNotEmpty) {
        songWidgetList.add(Divider(
          thickness: 10,
          color: _blue.color,
        ));
        songWidgetList.add(Text(
          'Matching songs sung by any singer:',
          style: songPerformanceStyle.copyWith(color: _blue.color),
        ));
        songWidgetList.add(appSpace());
        songWidgetList.add(songPerformanceListView(requestedSongPerformances.toList(growable: false)));
        songWidgetList.add(appSpace());
      }

      if (selectedSongPerformances.isNotEmpty) {
        songWidgetList.add(Divider(
          thickness: 10,
          color: _blue.color,
        ));
        songWidgetList.add(Text(
          'Sung by $selectedSinger:',
          style: songPerformanceStyle.copyWith(color: _blue.color),
        ));
        songWidgetList.add(appSpace());
        songWidgetList.add(songPerformanceListView(selectedSongPerformances.toList(growable: false)));
        songWidgetList.add(appSpace());
      }

      SplayTreeSet<SongPerformance> _singerSongPerformanceSet = SplayTreeSet();
      SplayTreeSet<Song> _singerSongSet = SplayTreeSet();
      allSongPerformances.loadSongs(app.allSongs.toList(growable: false));
      _singerSongPerformanceSet.addAll(allSongPerformances.bySinger(selectedSinger));
      _singerSongSet.addAll(_singerSongPerformanceSet.map((e) => e.song ?? Song.createEmptySong()));

      //  search songs on top
      if (filteredSongs.isNotEmpty) {
        if (songSearchMatcher.isNotEmpty) {
          songWidgetList.add(Divider(
            thickness: 10,
            color: _blue.color,
          ));
          songWidgetList.add(Text(
            'Songs matching the search "${songSearchMatcher.pattern}":',
            style: songPerformanceStyle.copyWith(color: _blue.color),
          ));
        } else {
          songWidgetList.add(const Divider(
            thickness: 10,
          ));
          songWidgetList.add(Text(
            'All songs:',
            style: songPerformanceStyle,
          ));
        }
        songWidgetList.add(appSpace());
        songWidgetList.add(songListView(filteredSongs.toList(growable: false)));
        songWidgetList.add(appSpace());
      }

      songWidgetList.add(const Divider(
        thickness: 10,
      ));
      if (selectedSinger != unknownSinger) {
        songWidgetList.add(Text(
          (filteredSongs.isNotEmpty ? 'Other songs' : 'Songs') + ' for singer $selectedSinger:',
          style: songPerformanceStyle.copyWith(color: Colors.grey),
        ));
      }

      //  list other, non-matching singer songs later
      for (var songPerformance in _singerSongPerformanceSet) {
        //  avoid repeats
        if (songPerformance.song != null && !filteredSongs.contains(songPerformance.song)) {
          songWidgetList.add(mapSongPerformanceToWidget(songPerformance));
        }
      }

      if (selectedSinger != unknownSinger) {
        songWidgetList.add(appSpace());
        songWidgetList.add(const Divider(
          thickness: 10,
        ));
        songWidgetList.add(Text(
          (songSearchMatcher.isNotEmpty
                  ? 'Other songs not matching the search "${songSearchMatcher.pattern}" and '
                  : 'Songs ') +
              'not yet sung by $selectedSinger:',
          style: songPerformanceStyle.copyWith(color: Colors.grey),
        ));
      }
      {
        List<Song> songs = [];
        for (var song in app.allSongs) {
          if (_singerSongSet.contains(song) || filteredSongs.contains(song)) {
            continue;
          }
          songs.add(song);
        }
        songWidgetList.add(songListView(songs));
      }
    }

    if (singerList.isEmpty) {
      singerList.addAll(allSongPerformances.setOfSingers()); //  fixme: temp
    }

    var singerTextStyle = generateAppTextFieldStyle(fontSize: fontSize);

    void _onReorder(int oldIndex, int newIndex) {
      setState(() {
        logger.i('_onReorder($oldIndex, $newIndex)');
        var singer = _sessionSingers.removeAt(oldIndex);
        _sessionSingers.insert(newIndex, singer);
      });
    }

    var todaysReorderableSingersWidgetWrap = _sessionSingers.isEmpty
        ? Text(
            '(none)',
            style: singerTextStyle,
          )
        : Container(
            child: appWrapFullWidth([
              ReorderableWrap(
                  children: _sessionSingers.map((singer) {
                    return appWrap([
                      Container(
                        child: appTextButton(
                          singer,
                          appKeyEnum: AppKeyEnum.singersSessionSingerSelect,
                          onPressed: () {
                            setState(() {
                              selectedSinger = singer;
                              searchForSelectedSingerOnly = true;
                            });
                          },
                          style: singer == selectedSinger
                              ? singerTextStyle.copyWith(backgroundColor: addColor)
                              : singerTextStyle,
                        ),
                      ),
                      if (!isInSingingMode)
                        appInkWell(
                          appKeyEnum: AppKeyEnum.singersRemoveSingerFromSession,
                          // value: singer,
                          onTap: () {
                            setState(() {
                              _sessionSingers.remove(singer);
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
                color: _blue.color,
                width: 2,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
          );

    var allSingersWidgetWrap = Container(
      child: appWrapFullWidth(sessionSingerWidgets, alignment: WrapAlignment.start, spacing: 10),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey,
          width: 2,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Singers'),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (app.message.isNotEmpty)
                Text(
                  app.message,
                  style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                  key: appKey(AppKeyEnum.singersErrorMessage),
                ),
              appSpace(),
              appWrapFullWidth([
                appWrap([
                  appTooltip(
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
                  appTooltip(
                    message: singingTooltipText,
                    child: appSwitch(
                      appKeyEnum: AppKeyEnum.singersSinging,
                      onChanged: (value) {
                        setState(() {
                          toggleSingingMode();
                        });
                      },
                      value: isInSingingMode,
                    ),
                  ),
                  if (!isInSingingMode)
                    Text(
                      '       Make adjustments:',
                      style: singerTextStyle,
                      softWrap: false,
                    ),
                ]),
                if (!isInSingingMode)
                  appButton('Other Actions', appKeyEnum: AppKeyEnum.singersShowOtherActions, onPressed: () {
                    setState(() {
                      showOtherActions = !showOtherActions;
                    });
                  }),
              ], alignment: WrapAlignment.spaceBetween),
              if (!isInSingingMode && showOtherActions)
                appWrapFullWidth([
                  Column(
                    children: [
                      appSpace(),
                      if (allSongPerformances.isNotEmpty)
                        appTooltip(
                            message: 'For safety reasons you cannot remove all singers\n'
                                'without first having written them all.',
                            child: appEnumeratedButton(
                              'Write all singer songs to a local file',
                              appKeyEnum: AppKeyEnum.singersSave,
                              onPressed: () {
                                setState(() {
                                  saveSongPerformances();
                                });
                              },
                            )),
                      appSpace(),
                      if (selectedSinger != unknownSinger)
                        appEnumeratedButton(
                          'Write singer $selectedSinger\'s songs to a local file',
                          appKeyEnum: AppKeyEnum.singersSaveSelected,
                          onPressed: () {
                            saveSingersSongList(selectedSinger);
                            logger.i('save selection: $selectedSinger');
                          },
                        ),
                      appSpace(),
                      appTooltip(
                        message: 'If the singer matches an existing singer,\n'
                            'the songs will be added to the singer.',
                        child: appEnumeratedButton(
                          'Read a single singer from a local file',
                          appKeyEnum: AppKeyEnum.singersReadASingleSinger,
                          onPressed: () {
                            setState(() {
                              filePickSingle(context);
                            });
                          },
                        ),
                      ),
                      appSpace(verticalSpace: 25),
                      if (selectedSinger != unknownSinger)
                        appEnumeratedButton(
                          'Delete the singer $selectedSinger',
                          appKeyEnum: AppKeyEnum.singersDeleteSinger,
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                      title: Text(
                                        'Do you really want to delete the singer $selectedSinger?',
                                        style: TextStyle(fontSize: songPerformanceStyle.fontSize),
                                      ),
                                      actions: [
                                        appButton('Yes! Delete all of $selectedSinger\'s song performances.',
                                            appKeyEnum: AppKeyEnum.singersDeleteSingerConfirmation, onPressed: () {
                                          logger.i('delete: $selectedSinger');
                                          setState(() {
                                            allSongPerformances.removeSinger(selectedSinger);
                                            _sessionSingers.remove(selectedSinger);
                                            selectedSinger = unknownSinger;
                                            AppOptions().storeAllSongPerformances();
                                            allHaveBeenWritten = false;
                                          });
                                          Navigator.of(context).pop();
                                        }),
                                        appSpace(space: 100),
                                        appButton('Cancel, leave $selectedSinger\'s song performances as is.',
                                            appKeyEnum: AppKeyEnum.singersCancelDeleteSinger, onPressed: () {
                                          Navigator.of(context).pop();
                                        }),
                                      ],
                                      elevation: 24.0,
                                    ));
                          },
                        ),
                      appSpace(),
                      appTooltip(
                        message: 'Warning: This will delete all singers\n'
                            'and replace them with singers from the read file.',
                        child: appEnumeratedButton(
                          'Read all singers from a local file',
                          appKeyEnum: AppKeyEnum.singersReadSingers,
                          onPressed: () {
                            setState(() {
                              filePickAll(context);
                            });
                          },
                        ),
                      ),
                      appSpace(),
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
                              allSongPerformances.clear();
                              allHaveBeenWritten = false;
                            });
                          },
                        ),
                    ],
                    crossAxisAlignment: CrossAxisAlignment.end,
                  ),
                ], alignment: WrapAlignment.end),
              if (!isInSingingMode)
                appSpace(
                  space: 20,
                ),
              if (!isInSingingMode)
                appWrap([
                  Text(
                    'Today\'s Singers:',
                    style: singerTextStyle,
                  ),
                  Text(
                    'to reorder: click, hold, and drag.',
                    style: singerTextStyle.copyWith(color: Colors.grey),
                  ),
                ], spacing: 30),
              appSpace(),
              todaysReorderableSingersWidgetWrap,
              appSpace(),
              if (!isInSingingMode)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'All Singers:',
                    style: singerTextStyle,
                  ),

                  appSpace(),
                  allSingersWidgetWrap,
                  appSpace(),

                  //  new singer stuff
                  appWrapFullWidth([
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
                              selectedSinger = Util.firstToUpper(singerTextFieldController.text);
                              searchForSelectedSingerOnly = true;
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
              appWrapFullWidth([
                //  search line
                appWrap([
                  appTooltip(
                    message: 'Search for songs for $selectedSinger',
                    child: IconButton(
                      icon: const Icon(Icons.search),
                      iconSize: fontSize,
                      onPressed: (() {}),
                    ),
                  ),
                  SizedBox(
                    width: 20 * app.screenInfo.fontSize,
                    //  limit text entry display length
                    child: appTextField(
                      appKeyEnum: AppKeyEnum.singersSearchText,
                      enabled: true,
                      controller: searchTextFieldController,
                      hintText: 'enter song search${selectedSinger != unknownSinger ? ' for $selectedSinger' : ''}',
                      onChanged: (text) {
                        setState(() {});
                      },
                      fontSize: fontSize,
                    ),
                  ),
                  appTooltip(
                    message: 'Clear the search text for Singer $selectedSinger.',
                    child: appEnumeratedIconButton(
                      appKeyEnum: AppKeyEnum.singersClearSearch,
                      icon: const Icon(Icons.clear),
                      iconSize: 1.5 * fontSize,
                      onPressed: (() {
                        setState(() {
                          FocusScope.of(context).requestFocus(searchFocusNode);
                        });
                      }),
                    ),
                  ),
                ]),
                appWrap([
                  Text(
                    'Search for:',
                    style: singerTextStyle,
                  ),
                  if (selectedSinger != unknownSinger)
                    appRadio<bool>('just $selectedSinger',
                        appKeyEnum: AppKeyEnum.optionsNinJam,
                        value: true,
                        groupValue: searchForSelectedSingerOnly, onPressed: () {
                      setState(() {
                        searchForSelectedSingerOnly = true;
                      });
                    }, style: singerTextStyle),
                  appRadio<bool>('any singer',
                      appKeyEnum: AppKeyEnum.optionsNinJam,
                      value: false,
                      groupValue: searchForSelectedSingerOnly, onPressed: () {
                    setState(() {
                      searchForSelectedSingerOnly = false;
                    });
                  }, style: singerTextStyle),
                ], spacing: 10, alignment: WrapAlignment.spaceBetween),
              ], spacing: 10, alignment: WrapAlignment.spaceBetween),
              ListView.builder(
                primary: false,
                shrinkWrap: true,
                scrollDirection: Axis.vertical,
                itemCount: songWidgetList.length,
                itemBuilder: (BuildContext context, int index) {
                  return songWidgetList[index];
                },
                cacheExtent: 200,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.singersBack),
    );
  }

  void toggleSingingMode() {
    isInSingingMode = !isInSingingMode;
    if (!_sessionSingers.contains(selectedSinger) && _sessionSingers.isNotEmpty) {
      selectedSinger = _sessionSingers.first;
      searchForSelectedSingerOnly = true;
    }
    if (isInSingingMode) {
      app.clearMessage();
    }
  }

  Widget mapSongToWidget(final Song song, {final music_key.Key? key}) {
    return appWrapFullWidth(
      [
        appWrapSong(song, key: key ?? song.key),
      ],
    );
  }

  Widget mapSongPerformanceToSingerWidget(SongPerformance songPerformance) {
    return mapSongPerformanceToWidget(songPerformance, withSinger: true);
  }

  Widget mapSongPerformanceToWidget(SongPerformance songPerformance, {withSinger = false}) {
    return appWrapFullWidth(
      [
        appWrapSong(songPerformance.song, key: songPerformance.key, singer: songPerformance.singer),
        Text(
          songPerformance.lastSungDateString + (kDebugMode ? ' ${hms(songPerformance.lastSung)}' : ''),
          style: songPerformanceStyle,
        ),
      ],
      alignment: WrapAlignment.spaceBetween,
    );
  }

  Wrap appWrapSong(final Song? song, {final music_key.Key? key, String? singer}) {
    if (song == null) {
      return appWrap([]);
    }
    return appWrap(
      [
        appWidgetHelper.checkbox(
          value: allSongPerformances.isSongInSingersList(selectedSinger, song),
          onChanged: (bool? value) {
            if (value != null) {
              singer ??= selectedSinger;
              if (singer != null) {
                setState(() {
                  if (value) {
                    if (singer != unknownSinger) {
                      allSongPerformances.addSongPerformance(
                          SongPerformance(song.songId.toString(), singer!, key ?? music_key.Key.getDefault()));
                    }
                  } else {
                    allSongPerformances.removeSingerSong(singer!, song.songId.toString());
                  }
                  AppOptions().storeAllSongPerformances();
                });
              }
            }
          },
          fontSize: songPerformanceStyle.fontSize,
        ),
        appSpace(space: 12),
        TextButton(
          child: Text(
            '${singer != null ? '$singer sings: ' : ''}'
            '${song.title} by ${song.artist}'
            '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}'
            '${key == null ? '' : ' in $key'}',
            style: songPerformanceStyle,
          ),
          onPressed: (singer != null || selectedSinger != unknownSinger)
              ? () {
                  setState(() {
                    if (singer != null) {
                      selectedSinger = singer!;
                      searchForSelectedSingerOnly = true;
                    }
                    var songPerformance =
                        SongPerformance(song.songId.toString(), selectedSinger, key ?? music_key.Key.getDefault());
                    if (selectedSinger != unknownSinger) {
                      allSongPerformances.addSongPerformance(songPerformance);
                      navigateToPlayer(context, songPerformance);
                    }
                  });
                }
              : null,
        )
      ],
    );
  }

  void searchClear() {
    searchTextFieldController.clear();
    songSearchMatcher = SongSearchMatcher(searchTextFieldController.text);
    searchAllPerformanceSongs();
  }

  void searchSelectedSingerSongs() {
    //  apply search filter
    selectedSongPerformances.clear();
    requestedSongPerformances.clear();
    filteredSongs.clear();

    //  don't look for a singer not present
    if (!_sessionSingers.contains(selectedSinger)) {
      return;
    }

    //  select songs from the selected singer
    if (songSearchMatcher.isNotEmpty) {
      for (final SongPerformance songPerformance in allSongPerformances.toList()) {
        if (songPerformance.song != null &&
            songPerformance.singer == selectedSinger &&
            songSearchMatcher.matches(songPerformance.song!)) {
          //  matches
          selectedSongPerformances.add(songPerformance);
        }
      }

      for (final Song song in app.allSongs) {
        if (songSearchMatcher.matches(song)) {
          if (selectedSongPerformances.where((value) => value.song == song).isEmpty) {
            filteredSongs.add(song);
          }
        }
      }
    }
  }

  void searchAllPerformanceSongs() {
    //  apply search filter
    selectedSongPerformances.clear();
    requestedSongPerformances.clear();
    filteredSongs.clear();
    var requestsFound = SplayTreeSet<Song>();

    if (songSearchMatcher.isNotEmpty) {
      for (final SongPerformance songPerformance in allSongPerformances.toList()) {
        if (songPerformance.song != null &&
            _sessionSingers.contains(songPerformance.singer) &&
            songSearchMatcher.matches(songPerformance.song!)) {
          //  matches
          requestedSongPerformances.add(songPerformance);
          requestsFound.add(songPerformance.song!);
        }
      }
    }

    for (final Song song in app.allSongs) {
      if (songSearchMatcher.matches(song)) {
        if (requestedSongPerformances.where((value) => value.song == song).isEmpty) {
          filteredSongs.add(song);
        }
      }
    }
  }

  void navigateToPlayer(BuildContext context, SongPerformance songPerformance) async {
    if (songPerformance.song == null) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Player(songPerformance.song!, musicKey: songPerformance.key)),
    );
    setState(() {
      //  fixme: song may have been edited in the player screen!!!!
      //  update the last sung date and the key if it has been changed
      allSongPerformances.addSongPerformance(songPerformance.update(key: playerSelectedSongKey));
      AppOptions().storeAllSongPerformances();
      allHaveBeenWritten = false;

      if (_sessionSingers.isNotEmpty) {
        //  increment the selected singer now that we're done singing a song
        var index = _sessionSingers.indexOf(selectedSinger) + 1;
        selectedSinger = _sessionSingers[index >= _sessionSingers.length ? 0 : index];
        searchForSelectedSingerOnly = true;
      }

      searchClear();
    });
  }

  String hms(int ms) {
    if (ms == 0) return '';
    return DateFormat.Hms().format(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  void saveSongPerformances() async {
    saveAllSongPerformances('allSongPerformances', allSongPerformances.toJsonString());
    allHaveBeenWritten = true;
  }

  void saveSingersSongList(String singer) async {
    saveAllSongPerformances('singer_$singer', allSongPerformances.toJsonStringFor(singer));
  }

  void saveAllSongPerformances(String prefix, String contents) async {
    String fileName =
        '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}${AllSongPerformances.fileExtension}';
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    logger.i('_saveAllSongPerformances message: $message');
    setState(() {
      app.infoMessage('${AllSongPerformances.fileExtension} $message');
    });
  }

  void filePickAll(BuildContext context) async {
    app.clearMessage();
    var content = await UtilWorkaround().filePickByExtension(context, AllSongPerformances.fileExtension);

    setState(() {
      if (content.isEmpty) {
        app.infoMessage('No singers file read');
      } else {
        allSongPerformances.fromJsonString(content);
        AppOptions().storeAllSongPerformances();
      }
    });
  }

  void filePickSingle(BuildContext context) async {
    app.clearMessage();
    var content = await UtilWorkaround().filePickByExtension(context, AllSongPerformances.fileExtension);

    setState(() {
      if (content.isEmpty) {
        app.infoMessage('No singer file read');
      } else {
        logger.i('_filePickSingle: $context');
        allSongPerformances.addFromJsonString(content);
        AppOptions().storeAllSongPerformances();
        allHaveBeenWritten = false;
      }
    });
  }

  ListView songListView(final List<Song> songs) {
    return ListView.builder(
      primary: false,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      itemCount: songs.length,
      itemBuilder: (context, index) {
        return mapSongToWidget(songs[index]);
      },
      cacheExtent: 200,
    );
  }

  ListView songPerformanceListView(final List<SongPerformance> songPerformances) {
    return ListView.builder(
      primary: false,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      itemCount: songPerformances.length,
      itemBuilder: (context, index) {
        return mapSongPerformanceToSingerWidget(songPerformances[index]);
      },
      cacheExtent: 200,
    );
  }

  static const singingTooltipText = 'Switch to singing mode, otherwise make adjustments.';

  bool isInSingingMode = false;
  bool showOtherActions = false;
  List<String> singerList = [];

  late TextStyle songPerformanceStyle;

  SongSearchMatcher songSearchMatcher = SongSearchMatcher('');
  var selectedSongPerformances = SplayTreeSet<SongPerformance>();
  var requestedSongPerformances = SplayTreeSet<SongPerformance>();

  final SplayTreeSet<Song> filteredSongs = SplayTreeSet();
  final FocusNode searchFocusNode;

  static const String unknownSinger = 'unknown';
  String selectedSinger = unknownSinger;
  final TextEditingController searchTextFieldController = TextEditingController();
  bool _searchForSelectedSingerOnly = false;

  bool get searchForSelectedSingerOnly => _searchForSelectedSingerOnly;

  set searchForSelectedSingerOnly(bool searchForSelectedSingerOnly) {
    _searchForSelectedSingerOnly = selectedSinger == unknownSinger ? false : searchForSelectedSingerOnly;
  }

  final FocusNode singerSearchFocusNode;
  final TextEditingController singerSearchTextFieldController = TextEditingController();

  AllSongPerformances allSongPerformances = AllSongPerformances();
  bool allHaveBeenWritten = false;

  final TextEditingController singerTextFieldController = TextEditingController();

  late AppWidgetHelper appWidgetHelper;

  String fileLocation = kIsWeb ? 'download area' : 'Documents';

  static const addColor = Color(0xFFC8E6C9); //var c = Colors.green[100];
  static const removeColor = Color(0xFFE57373); //var c = Colors.red[300]: Color(0xFFE57373),
  static const EdgeInsets appendInsets = EdgeInsets.all(3);
  static const EdgeInsets appendPadding = EdgeInsets.all(3);
}
