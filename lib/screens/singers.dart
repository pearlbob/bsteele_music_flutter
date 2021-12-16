import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../app/app.dart';

final _blue = Paint()..color = Colors.lightBlue.shade200;

final List<String> _sessionSingers = []; //  in session order, stored locally to persist over screen reentry.

/// Allow the user to manage sub-lists from all available songs.
/// Name and value pairs are assigned to songs identified by their song id.
/// The value portion may be empty.
/// The names 'cj' and 'holiday' should remain reserved.
///
/// Note that the lists will not persist unless written to a file.
/// At the next app invocation, the file will have to read.
/// Export of this file to the master release will make it the app's default set of sub-lists.
class Singers extends StatefulWidget {
  const Singers({Key? key}) : super(key: key);

  @override
  _State createState() => _State();

  static const String routeName = '/singers';
}

class _State extends State<Singers> {
  _State() : _searchFocusNode = FocusNode();

  @override
  initState() {
    super.initState();

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);

    final double fontSize = app.screenInfo.fontSize;
    songPerformanceStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

    List<Widget> sessionSingerWidgets = [];
    {
      //  find all singers
      var setOfSingers = SplayTreeSet<String>();
      setOfSingers.addAll(allSongPerformances.setOfSingers());
      if (_selectedSinger != unknownSinger) {
        setOfSingers.add(_selectedSinger);
      }
      for (var singer in setOfSingers) {
        sessionSingerWidgets.add(appWrap(
          [
            appTextButton(
              singer,
              appKeyEnum: AppKeyEnum.singersAllSingers,
              style: singer == _selectedSinger
                  ? songPerformanceStyle.copyWith(backgroundColor: _addColor)
                  : songPerformanceStyle,
              onPressed: () {
                setState(() {
                  _selectedSinger = singer;
                });
              },
            ),
            if (!_sessionSingers.contains(singer))
              appInkWell(
                appKeyEnum: AppKeyEnum.singersAddSingerToSession,
                value: singer,
                keyCallback: () {
                  setState(() {
                    _sessionSingers.add(singer);
                  });
                },
                child: appCircledIcon(
                  Icons.add,
                  'Add $singer to today\'s session.',
                  margin: appendInsets,
                  padding: appendPadding,
                  color: _addColor,
                  size: fontSize * 0.7,
                ),
              ),
            if (_sessionSingers.contains(singer))
              appInkWell(
                appKeyEnum: AppKeyEnum.singersRemoveSingerFromSession,
                // value: singer,
                keyCallback: () {
                  setState(() {
                    _sessionSingers.remove(singer);
                  });
                },
                child: appCircledIcon(
                  Icons.remove,
                  'Remove $singer from today\'s session.',
                  margin: appendInsets,
                  padding: appendPadding,
                  color: _removeColor,
                  size: fontSize * 0.7,
                ),
              ),
            appSpace(),
            appSpace(),
          ],
        ));
      }
    }

    List<Widget> songWidgetList = [];
    {
      if (_selectedSinger != unknownSinger && allSongPerformances.bySinger(_selectedSinger).isEmpty) {
        songWidgetList.add(Text(
          'Select at least one song for $_selectedSinger to remain a singer! ',
          style: songPerformanceStyle.copyWith(color: _blue.color),
        ));
      }
      if (searchTerm.isNotEmpty) {
        songWidgetList.add(Divider(
          thickness: 10,
          color: _blue.color,
        ));
        songWidgetList.add(Text(
          _filteredSongs.isNotEmpty ? 'Songs matching the search "$searchTerm":' : 'No songs match the search.',
          style: songPerformanceStyle.copyWith(color: _blue.color),
        ));
        songWidgetList.add(appSpace());
      }

      SplayTreeSet<SongPerformance> _singerSongPerformanceSet = SplayTreeSet();
      SplayTreeSet<Song> _singerSongSet = SplayTreeSet();
      allSongPerformances.loadSongs(app.allSongs.toList(growable: false));
      _singerSongPerformanceSet.addAll(allSongPerformances.bySinger(_selectedSinger));
      _singerSongSet.addAll(_singerSongPerformanceSet.map((e) => e.song ?? Song.createEmptySong()));

      //  search songs on top
      {
        if (_filteredSongs.isNotEmpty) {
          songWidgetList.addAll(_filteredSongs.map(mapSongToWidget).toList());
          songWidgetList.add(appSpace());
        }
        songWidgetList.add(const Divider(
          thickness: 10,
        ));
        if (_selectedSinger != unknownSinger) {
          songWidgetList.add(Text(
            (_filteredSongs.isNotEmpty ? 'Other songs' : 'Songs') + ' for singer $_selectedSinger:',
            style: songPerformanceStyle.copyWith(color: Colors.grey),
          ));
        }
      }

      //  list other, non-matching singer songs later
      for (var songPerformance in _singerSongPerformanceSet) {
        //  avoid repeats
        if (songPerformance.song != null && !_filteredSongs.contains(songPerformance.song)) {
          songWidgetList.add(mapSongPerformanceToWidget(songPerformance));
        }
      }

      if (_selectedSinger != unknownSinger) {
        songWidgetList.add(appSpace());
        songWidgetList.add(const Divider(
          thickness: 10,
        ));
        songWidgetList.add(Text(
          (searchTerm.isNotEmpty ? 'Other songs not matching the search "$searchTerm" and ' : 'Songs ') +
              'not yet sung by $_selectedSinger:',
          style: songPerformanceStyle.copyWith(color: Colors.grey),
        ));
      }
      for (var song in app.allSongs) {
        if (_singerSongSet.contains(song) || _filteredSongs.contains(song)) {
          continue;
        }
        songWidgetList.add(mapSongToWidget(song));
      }
    }

    if (singerList.isEmpty) {
      singerList.addAll(allSongPerformances.setOfSingers()); //  fixme: temp
    }

    var singerTextStyle = generateAppTextFieldStyle(fontSize: fontSize);

    var todaysSingersWidgetWrap = _sessionSingers.isEmpty
        ? Text(
            '(none)',
            style: singerTextStyle,
          )
        : appWrapFullWidth(
        [
            for (var e in _sessionSingers)
              appWrap([
                if (!isInSingingMode &&
                    _selectedSinger == e &&
                    _sessionSingers.length > 1 &&
                    _sessionSingers.indexOf(e) > 0)
                  appInkWell(
                    appKeyEnum: AppKeyEnum.singersMoveSingerEarlierInSession,
                    // value: singer,
                    keyCallback: () {
                      setState(() {
                        var index = _sessionSingers.indexOf(e);
                        _sessionSingers.remove(e);
                        _sessionSingers.insert(index - 1, e);
                      });
                    },
                    child: appCircledIcon(
                      Icons.arrow_back,
                      'Move the singer earlier in today\'s list',
                      margin: appendInsets,
                      padding: appendPadding,
                      color: _addColor,
                      size: fontSize * 0.7,
                    ),
                  ),
                appTextButton(
                  e,
                  appKeyEnum: AppKeyEnum.singersSessionSingerSelect,
                  onPressed: () {
                    setState(() {
                      _selectedSinger = e;
                    });
                  },
                  style: e == _selectedSinger ? singerTextStyle.copyWith(backgroundColor: _addColor) : singerTextStyle,
                ),
                // if (!isInSingingMode && _selectedSinger == e)
                //   appInkWell(
                //     appKeyEnum: AppKeyEnum.singersRemoveThisSingerFromSession,
                //     // value: singer,
                //     keyCallback: () {
                //       setState(() {
                //         _sessionSingers.remove(e);
                //       });
                //     },
                //     child: appCircledIcon(
                //       Icons.remove,
                //       'Remove $e from today\'s session.',
                //       margin: appendInsets,
                //       padding: appendPadding,
                //       color: _removeColor,
                //       size: fontSize * 0.7,
                //     ),
                //   ),
                if (!isInSingingMode &&
                    _selectedSinger == e &&
                    _sessionSingers.length > 1 &&
                    _sessionSingers.indexOf(e) < _sessionSingers.length - 1)
                  appInkWell(
                    appKeyEnum: AppKeyEnum.singersMoveSingerLaterInSession,
                    // value: singer,
                    keyCallback: () {
                      setState(() {
                        var index = _sessionSingers.indexOf(e);
                        _sessionSingers.remove(e);
                        _sessionSingers.insert(index + 1, e);
                      });
                    },
                    child: appCircledIcon(
                      Icons.arrow_forward,
                      'Move the singer to later in today\'s list',
                      margin: appendInsets,
                      padding: appendPadding,
                      color: _addColor,
                      size: fontSize * 0.7,
                    ),
                  ),
              ]),
          ], spacing: 25);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Singers'),
      body: Padding(
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
              appWrap([
                appTooltip(
                  message: singingTooltipText,
                  child: Text(
                    'Singing',
                    style: singerTextStyle,
                    softWrap: false,
                  ),
                ),
                appTooltip(
                  message: singingTooltipText,
                  child: appSwitch(
                    appKeyEnum: AppKeyEnum.singersSinging,
                    onChanged: (value) {
                      setState(() {
                        isInSingingMode = !isInSingingMode;
                        if (!_sessionSingers.contains(_selectedSinger) && _sessionSingers.isNotEmpty) {
                          _selectedSinger = _sessionSingers.first;
                        }
                        if (isInSingingMode) {
                          app.clearMessage();
                          _searchClear();
                        }
                      });
                    },
                    value: isInSingingMode,
                  ),
                ),
                if (!isInSingingMode)
                  Text(
                    '  Make adjustments:',
                    style: singerTextStyle,
                    softWrap: false,
                  ),
              ]),
              if (!isInSingingMode)
                appWrapFullWidth([
                  appEnumeratedButton(
                    'Write all singer songs to a local file',
                    appKeyEnum: AppKeyEnum.singersSave,
                    onPressed: () {
                      setState(() {
                        _saveSongPerformances();
                      });
                    },
                  ),
                  if (_selectedSinger != unknownSinger)
                    appEnumeratedButton(
                      'Write singer $_selectedSinger\'s songs to a local file',
                      appKeyEnum: AppKeyEnum.singersSaveSelected,
                      onPressed: () {
                        _saveSingersSongList(_selectedSinger);
                        logger.i('save selection: $_selectedSinger');
                      },
                    ),
                  appEnumeratedButton(
                    'Read all singers from a local file',
                    appKeyEnum: AppKeyEnum.singersReadSingers,
                    onPressed: () {
                      setState(() {
                        _filePick(context);
                      });
                    },
                  ),
                  if (allHaveBeenWritten)
                    appEnumeratedButton(
                      'Remove all singers',
                      appKeyEnum: AppKeyEnum.singersRemoveAllSingers,
                      onPressed: () {
                        setState(() {
                          allSongPerformances.clear();
                        });
                      },
                    ),
                ], alignment: WrapAlignment.end, spacing: 20),
              if (!isInSingingMode)
                appSpace(
                  space: 20,
                ),
              if (!isInSingingMode)
                Text(
                  'Today\'s Singers:',
                  style: singerTextStyle,
                ),
              todaysSingersWidgetWrap,
              appSpace(),
              if (!isInSingingMode)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'All Singers:',
                    style: singerTextStyle,
                  ),

                  appWrap(sessionSingerWidgets, alignment: WrapAlignment.start, spacing: 10),
                  //  new singer stuff
                  appWrapFullWidth([
                    if (_selectedSinger != unknownSinger)
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
                                        logger.i('delete: $_selectedSinger');
                                        setState(() {
                                          allSongPerformances.removeSinger(_selectedSinger);
                                          _sessionSingers.remove(_selectedSinger);
                                          _selectedSinger = unknownSinger;
                                          AppOptions().storeAllSongPerformances();
                                        });
                                        Navigator.of(context).pop();
                                      }),
                                      appSpace(space: 100),
                                      appButton('Cancel, leave $_selectedSinger\'s song performances as is.',
                                          appKeyEnum: AppKeyEnum.singersCancelDeleteSinger, onPressed: () {
                                        Navigator.of(context).pop();
                                      }),
                                    ],
                                    elevation: 24.0,
                                  ));
                        },
                      ),
                    SizedBox(
                      width: 20 * app.screenInfo.fontSize,
                      //  limit text entry display length
                      child: appTextField(
                        appKeyEnum: AppKeyEnum.singersNameEntry,
                        controller: singerTextFieldController,
                        hintText: "a new singer's name",
                        onSubmitted: (value) {
                          setState(() {
                            if (singerTextFieldController.text.isNotEmpty) {
                              _selectedSinger = Util.firstToUpper(singerTextFieldController.text);
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
                    message: 'search',
                    child: IconButton(
                      icon: const Icon(Icons.search),
                      iconSize: fontSize,
                      onPressed: (() {
                        setState(() {
                          _searchSongs(_searchTextFieldController.text);
                        });
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 20 * app.screenInfo.fontSize,
                    //  limit text entry display length
                    child: appTextField(
                      appKeyEnum: AppKeyEnum.singersSearchText,
                      enabled: true,
                      controller: _searchTextFieldController,
                      hintText: "enter search text",
                      onChanged: (text) {
                        setState(() {
                          logger.v('search text: "$text"');
                          _searchSongs(_searchTextFieldController.text);
                        });
                      },
                      fontSize: fontSize,
                    ),
                  ),
                  appTooltip(
                    message: 'Clear the search text.',
                    child: appEnumeratedIconButton(
                      appKeyEnum: AppKeyEnum.singersClearSearch,
                      icon: const Icon(Icons.clear),
                      iconSize: 1.5 * fontSize,
                      onPressed: (() {
                        setState(() {
                          _searchClear();
                          FocusScope.of(context).requestFocus(_searchFocusNode);
                        });
                      }),
                    ),
                  ),
                ]),
              ], alignment: WrapAlignment.spaceBetween),
              appSpace(),
              Expanded(
                child: ListView(
                  children: songWidgetList,
                  scrollDirection: Axis.vertical,
                ),
              ),
            ]),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.singersBack),
    );
  }

  Widget mapSongToWidget(Song song, {music_key.Key? key}) {
    return appWrapFullWidth(
      [
        appWrapSong(song, key: key),
      ],
    );
  }

  Widget mapSongPerformanceToWidget(SongPerformance songPerformance) {
    return appWrapFullWidth(
      [
        appWrapSong(songPerformance.song, key: songPerformance.key),
        Text(
          songPerformance.dateString,
          style: songPerformanceStyle,
        ),
      ],
      alignment: WrapAlignment.spaceBetween,
    );
  }

  Wrap appWrapSong(Song? song, {music_key.Key? key}) {
    if (song == null) {
      return appWrap([]);
    }
    return appWrap(
      [
        appWidgetHelper.checkbox(
          value: allSongPerformances.isSongInSingersList(_selectedSinger, song),
          onChanged: (bool? value) {
            if (value != null) {
              setState(() {
                if (value) {
                  if (_selectedSinger != unknownSinger) {
                    allSongPerformances.addSongPerformance(
                        SongPerformance(song.songId.toString(), _selectedSinger, music_key.Key.getDefault()));
                  }
                } else {
                  allSongPerformances.removeSingerSong(_selectedSinger, song.songId.toString());
                }
                AppOptions().storeAllSongPerformances();
              });
            }
          },
          fontSize: songPerformanceStyle.fontSize,
        ),
        appSpace(space: 12),
        TextButton(
          child: Text(
            '${song.title} by ${song.artist}'
            '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}'
            '${key == null ? '' : ' in $key'}',
            style: songPerformanceStyle,
          ),
          onPressed: (_selectedSinger != unknownSinger)
              ? () {
                  setState(() {
                    var songPerformance =
                        SongPerformance(song.songId.toString(), _selectedSinger, key ?? music_key.Key.getDefault());
                    if (_selectedSinger != unknownSinger) {
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

  void _searchClear() {
    _searchTextFieldController.clear();
    _searchSongs(null);
  }

  void _searchSongs(String? search) {
    search ??= '';
    search = search.trim();
    searchTerm = search.replaceAll("[^\\w\\s']+", '');

    //  apply search filter
    _filteredSongs.clear();
    if (searchTerm.isNotEmpty) {
      // select order
      int Function(Song key1, Song key2) compare;
      compare = (Song song1, Song song2) {
        return song1.compareTo(song2);
      };

      _filteredSongs = SplayTreeSet(compare);
      final RegExp searchRegex = RegExp(searchTerm, caseSensitive: false);

      for (final Song song in app.allSongs) {
        if (searchRegex.hasMatch(song.getTitle()) || searchRegex.hasMatch(song.getArtist())) {
          //  matches
          _filteredSongs.add(song);
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
      //  fixme: song may have changed in the player screen!!!!
      //  update the key
      if (playerSelectedSongKey != null) {
        allSongPerformances.addSongPerformance(
            SongPerformance(songPerformance.songIdAsString, _selectedSinger, playerSelectedSongKey!));
      }
      AppOptions().storeAllSongPerformances();

      if (_sessionSingers.isNotEmpty) {
        //  increment the selected singer now that we're done singing a song
        var index = _sessionSingers.indexOf(_selectedSinger) + 1;
        _selectedSinger = _sessionSingers[index >= _sessionSingers.length ? 0 : index];
      }

      _searchClear();
    });
  }

  void _saveSongPerformances() async {
    _saveAllSongPerformances('allSongPerformances', allSongPerformances.toJsonString());
    allHaveBeenWritten = true;
  }

  void _saveSingersSongList(String singer) async {
    _saveAllSongPerformances('singer_$singer', allSongPerformances.toJsonStringFor(singer));
  }

  void _saveAllSongPerformances(String prefix, String contents) async {
    String fileName =
        '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}${AllSongPerformances.fileExtension}';
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    logger.i('_saveAllSongPerformances message: $message');
    setState(() {
      app.infoMessage('${AllSongPerformances.fileExtension} $message');
    });
  }

  void _filePick(BuildContext context) async {
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

  static const singingTooltipText = 'Switch to singing mode, otherwise make adjustments.';

  bool isInSingingMode = false;
  List<String> singerList = [];

  late TextStyle songPerformanceStyle;

  String searchTerm = '';
  SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
  final FocusNode _searchFocusNode;

  static const String unknownSinger = 'unknown';
  String _selectedSinger = unknownSinger;
  final TextEditingController _searchTextFieldController = TextEditingController();

  AllSongPerformances allSongPerformances = AllSongPerformances();
  bool allHaveBeenWritten = false;

  final TextEditingController singerTextFieldController = TextEditingController();

  late AppWidgetHelper appWidgetHelper;

  String fileLocation = kIsWeb ? 'download area' : 'Documents';

  static const _addColor = Color(0xFFC8E6C9); //var c = Colors.green[100];
  static const _removeColor = Color(0xFFE57373); //var c = Colors.red[300]: Color(0xFFE57373),
  static const EdgeInsets appendInsets = EdgeInsets.all(3);
  static const EdgeInsets appendPadding = EdgeInsets.all(3);
}
