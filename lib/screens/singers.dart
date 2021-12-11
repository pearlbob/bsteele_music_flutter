import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as music_key;
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
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

    allSongPerformances.fromJsonString('{"allSongPerformances":'
        '[{"songId":"Song_Rock_Me_Baby_by_BB_King","singer":"bodhi","key":1,"bpm":100}'
        ',{"songId":"Song_Dream_by_Everly_Brothers","singer":"vicki","key":0,"bpm":120}'
        ',{"songId":"Song_Dream_by_Everly_Brothers","singer":"bodhi","key":9,"bpm":120}'
        ',{"songId":"Song_Dead_Flowers_by_Rolling_Stones_The","singer":"lee","key":1,"bpm":120}'
        ']}'); //  fixme: temp!!!!
    logger.w('fixme: temp AllSongPerformances() initialization!');

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);

    final double fontSize = app.screenInfo.fontSize;
    metadataStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

    List<Widget> _metadataWidgets = [];
    {
      //  find all singers
      for (var singer in allSongPerformances.setOfSingers()) {
        _metadataWidgets.add(appWrap(
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
                style: metadataStyle,
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

      _metadataWidgets.add(appWrap(
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
            width: 8 * app.screenInfo.fontSize,
            //  limit text entry display length
            child: appTextField(
              appKeyEnum: AppKeyEnum.singersNameEntry,
              controller: singerTextFieldController,
              hintText: "Singer's name",
              onChanged: (text) {
                setState(() {
                  if (singerTextFieldController.text.isNotEmpty) {
                    _selectedSinger = singerTextFieldController.text;
                  }
                });
              },
              fontSize: fontSize,
            ),
          ),
        ],
      ));
    }

    List<Widget> songWidgetList = [];
    {
      if (searchTerm.isNotEmpty) {
        songWidgetList.add(Divider(
          thickness: 10,
          color: _blue.color,
        ));
        songWidgetList.add(Text(
          _filteredSongs.isNotEmpty ? 'Songs matching the search "$searchTerm":' : 'No songs match the search.',
          style: metadataStyle.copyWith(color: _blue.color),
        ));
        songWidgetList.add(appSpace());
      }

      SplayTreeSet<SongPerformance> _singerSongPerformanceSet = SplayTreeSet();
      SplayTreeSet<Song> _singerSongSet = SplayTreeSet();
      allSongPerformances.loadSongs(app.allSongs.toList(growable: false));
      _singerSongPerformanceSet.addAll(allSongPerformances.bySinger(_selectedSinger));
      _singerSongSet.addAll(_singerSongPerformanceSet.map((e) => e.song ?? Song.createEmptySong()));

      List<Song> _singersSongs = [];

      //  search songs on top
      {
        if (_filteredSongs.isNotEmpty) {
          songWidgetList.addAll(_filteredSongs.map(mapSongToWidget).toList());
          songWidgetList.add(appSpace());
        }
        songWidgetList.add(const Divider(
          thickness: 10,
        ));
        songWidgetList.add(Text(
          (_filteredSongs.isNotEmpty ? 'Other songs' : 'Songs') + ' in the song list for $_selectedSinger:',
          style: metadataStyle.copyWith(color: Colors.grey),
        ));
        _singersSongs.addAll(_filteredSongs);
      }

      //  list other, non-matching set songs later
      for (var songPerformance in _singerSongPerformanceSet) {
        //  avoid repeats
        if (songPerformance.song != null)
          songWidgetList.add(mapSongToWidget(songPerformance.song!, key: songPerformance.key));
      }
      songWidgetList.add(appSpace());
      songWidgetList.add(const Divider(
        thickness: 10,
      ));
      songWidgetList.add(Text(
        (searchTerm.isNotEmpty ? 'Other songs not matching the search "$searchTerm" and ' : 'Songs ') +
            'not in the list for $_selectedSinger:',
        style: metadataStyle.copyWith(color: Colors.grey),
      ));
      for (var song in app.allSongs) {
        if (_singerSongSet.contains(song) || _filteredSongs.contains(song)) {
          continue;
        }
        songWidgetList.add(mapSongToWidget(song));
      }
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
              appWrapFullWidth([
                appEnumeratedButton(
                  'Write all singers to a local file',
                  appKeyEnum: AppKeyEnum.singersSave,
                  onPressed: () {
                    _saveSongMetadata();
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
                                style: TextStyle(fontSize: metadataStyle.fontSize),
                              ),
                              actions: [
                                appButton('Yes! Delete all of $_selectedSinger\'s song list',
                                    appKeyEnum: AppKeyEnum.singersDeleteSingerConfirmation, onPressed: () {
                                  logger.i('delete: $_selectedSinger');
                                  setState(() {
                                    allSongPerformances.removeSinger(_selectedSinger);
                                    _selectedSinger = unknownSinger;
                                    AppOptions().storeSongMetadata();
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
                    // SongMetadata.clear();
                  },
                ),
              ], alignment: WrapAlignment.spaceBetween),
              appSpace(
                space: 20,
              ),
              appWrap(
                _metadataWidgets,
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
                  // for (var songIdMetadata in SongMetadata.where(
                  //     idIs: song.songId.toString(), nameIs: _selectedSinger.name, valueIs: _selectedSinger.value)) {
                  //   logger.d('remove: $songIdMetadata');
                  //   SongMetadata.remove(songIdMetadata, _selectedSinger);
                  // }
                  logger.w('fixme');
                }
                AppOptions().storeAllSongPerformances();
              });
            }
          },
          fontSize: metadataStyle.fontSize,
        ),
        appSpace(space: 12),
        TextButton(
          child: Text(
            '${song.title} by ${song.artist}'
            '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}'
            '${key == null ?'':' in $key'}',
            style: metadataStyle,
          ),
          onPressed: (_selectedSinger != unknownSinger)
              ? () {
                  setState(() {
                    if (_selectedSinger != unknownSinger) {
                      allSongPerformances.addSongPerformance(
                          SongPerformance(song.songId.toString(), _selectedSinger, music_key.Key.getDefault()));
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

  void _saveSongMetadata() async {
    _saveAllSongPerformances('allSongPerformances', allSongPerformances.toJsonString());
  }

  void _saveSingersSongList(String singer) async {
    _saveAllSongPerformances('singer_$singer', allSongPerformances.toJsonStringFor(singer));
  }

  void _saveAllSongPerformances(String prefix, String contents) async {
    String fileName = '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songmetadata';
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    logger.i('_saveAllSongPerformances message: $message');
    setState(() {
      app.infoMessage('.songPerformance $message');
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

  late TextStyle metadataStyle;

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
