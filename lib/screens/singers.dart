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

    // allSongPerformances.fromJsonString('{"allSongPerformances":'
    //     '[{"songId":"Song_Rock_Me_Baby_by_BB_King","singer":"Bodhi","key":10,"bpm":100}'
    //     ',{"songId":"Song_Dream_by_Everly_Brothers","singer":"Vicki","key":0,"bpm":120}'
    //     ',{"songId":"Song_Dream_by_Everly_Brothers","singer":"Bodhi","key":5,"bpm":120}'
    //     ',{"songId":"Song_Dead_Flowers_by_Rolling_Stones_The","singer":"Lee","key":3,"bpm":120}'
    //     ']}'); //  fixme: temp!!!!
    // logger.w('fixme: temp AllSongPerformances() initialization!');

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

    List<Widget> _singerWidgets = [];
    {
      //  find all singers
      var setOfSingers = SplayTreeSet<String>();
      setOfSingers.addAll(allSongPerformances.setOfSingers());
      if (_selectedSinger != unknownSinger) {
        setOfSingers.add(_selectedSinger);
      }
      for (var singer in setOfSingers) {
        _singerWidgets.add(appWrap(
          [
            Radio(
              value: singer,
              groupValue: _selectedSinger,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedSinger = singer;
                  });
                }
              },
            ),
            TextButton(
              child: Text(
                singer,
                style: songPerformanceStyle,
              ),
              onPressed: () {
                setState(() {
                  _selectedSinger = singer;
                });
              },
            ),
            appSpace(),
          ],
        ));
      }

      _singerWidgets.add(appWrap(
        [
          appSpace(space: 20),
          Radio(
            value: singerTextFieldController.text,
            groupValue: _selectedSinger,
            onChanged: (String? value) {
              if (value != null) {
                setState(() {
                  _selectedSinger = value;
                });
              }
            },
          ),
          SizedBox(
            width: 10 * app.screenInfo.fontSize,
            //  limit text entry display length
            child: appTextField(
              appKeyEnum: AppKeyEnum.singersNameEntry,
              controller: singerTextFieldController,
              hintText: "new singer's name",
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
        ],
      ));
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
          songWidgetList.add(mapSongToWidget(songPerformance.song!, key: songPerformance.key));
        }
      }

      if (_selectedSinger != unknownSinger) {
        songWidgetList.add(appSpace());
        songWidgetList.add(const Divider(
          thickness: 10,
        ));
        songWidgetList.add(Text(
          (searchTerm.isNotEmpty ? 'Other songs not matching the search "$searchTerm" and ' : 'Songs ') +
              'not for singer $_selectedSinger:',
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
                Text(app.message,
                    style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                    key: const ValueKey('errorMessage')),
              appSpace(),
              // ReorderableListView(
              //     children:
              //       singerList.map((singer)=>
              //         ListTile(
              //           key: ValueKey(singer),
              //           title: Text(singer),
              //         )).toList()
              //     ,
              //     onReorder: (oldIndex, newIndex) {
              //       logger.i('singer list reorder: ($oldIndex, $newIndex)');
              //     }),
              appWrapFullWidth([
                appEnumeratedButton(
                  'Write all singers to a local file',
                  appKeyEnum: AppKeyEnum.singersSave,
                  onPressed: () {
                    _saveSongPerformances();
                  },
                ),
                if (_selectedSinger != unknownSinger)
                  appEnumeratedButton(
                    'Write $_selectedSinger\'s song list to local file',
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
                appEnumeratedButton(
                  'Delete the singer',
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
                                appButton('Yes! Delete all of $_selectedSinger\'s song list',
                                    appKeyEnum: AppKeyEnum.singersDeleteSingerConfirmation, onPressed: () {
                                  logger.i('delete: $_selectedSinger');
                                  setState(() {
                                    allSongPerformances.removeSinger(_selectedSinger);
                                    _selectedSinger = unknownSinger;
                                    AppOptions().storeAllSongPerformances();
                                  });
                                  Navigator.of(context).pop();
                                }),
                                appSpace(space: 100),
                                appButton('Cancel', appKeyEnum: AppKeyEnum.singersCancelDeleteSinger, onPressed: () {
                                  Navigator.of(context).pop();
                                }),
                              ],
                              elevation: 24.0,
                            ));
                  },
                ),
              ], alignment: WrapAlignment.spaceBetween),
              appSpace(
                space: 20,
              ),

              appWrap(
                _singerWidgets,
                alignment: WrapAlignment.spaceEvenly,
              ),
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
                    width: 10 * app.screenInfo.fontSize,
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
                    message:
                        _searchTextFieldController.text.isEmpty ? 'Scroll the list some.' : 'Clear the search text.',
                    child: appEnumeratedIconButton(
                      appKeyEnum: AppKeyEnum.singersClearSearch,
                      icon: const Icon(Icons.clear),
                      iconSize: 1.5 * fontSize,
                      onPressed: (() {
                        _searchTextFieldController.clear();
                        setState(() {
                          FocusScope.of(context).requestFocus(_searchFocusNode);
                          _searchSongs(null);
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
      if ( playerSelectedSongKey != null ) {
        allSongPerformances
          .addSongPerformance(SongPerformance(songPerformance.songIdAsString, _selectedSinger, playerSelectedSongKey!));
      }
      AppOptions().storeAllSongPerformances();
    });
  }

  void _saveSongPerformances() async {
    _saveAllSongPerformances('allSongPerformances', allSongPerformances.toJsonString());
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
    var message = await UtilWorkaround().filePickByExtension(context, AllSongPerformances.fileExtension);

    setState(() {
      if (message.isEmpty) {
        app.infoMessage('No singers file read');
      } else {
        app.infoMessage(message);
      }
    });
  }

  List<String> singerList = [];

  late TextStyle songPerformanceStyle;

  String searchTerm = '';
  SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
  final FocusNode _searchFocusNode;

  static const String unknownSinger = 'unknown';
  String _selectedSinger = unknownSinger;
  final TextEditingController _searchTextFieldController = TextEditingController();

  AllSongPerformances allSongPerformances = AllSongPerformances();

  final TextEditingController singerTextFieldController = TextEditingController();

  late AppWidgetHelper appWidgetHelper;

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
}
