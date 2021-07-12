import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/app/appTextStyle.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../app/app.dart';

final _blue = Paint()..color = Colors.lightBlue.shade200;

/// Display the song moments in sequential order.
class Lists extends StatefulWidget {
  const Lists({Key? key}) : super(key: key);

  @override
  _State createState() => _State();
}

class _State extends State<Lists> {
  _State() : _searchFocusNode = FocusNode();

  @override
  initState() {
    super.initState();

    logger.d("_Songs.initState()");
  }

  bool _hasSelectedMetadata(Song song) {
    for (var nameValue in _selectedNameValues) {
      if (SongMetadata.where(idIsLike: song.songId.toString(), nameIsLike: nameValue.name, valueIsLike: nameValue.value)
          .isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = _app.screenInfo.fontSize;
    final metadataStyle = AppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

    List<Widget> _metadataWidgets = [];
    {
      SplayTreeSet<NameValue> nameValues = SplayTreeSet();
      for (var songIdMetadata in SongMetadata.idMetadata) {
        for (var nameValue in songIdMetadata.nameValues) {
          nameValues.add(nameValue);
        }
      }
      {
        //  clear the selected of old values
        List<NameValue> removal = [];
        for (var nameValue in _selectedNameValues) {
          if (!nameValues.contains(nameValue)) {
            removal.add(nameValue);
          }
        }
        _selectedNameValues.removeAll(removal);
      }

      for (var nameValue in nameValues) {
        _metadataWidgets.add(//Text()
            appWrap(
          [
            Checkbox(
              checkColor: Colors.white,
              fillColor: MaterialStateProperty.all(_blue.color),
              value: _selectedNameValues.contains(nameValue),
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    if (value) {
                      _selectedNameValues.add(nameValue);
                    } else {
                      _selectedNameValues.remove(nameValue);
                    }
                  });
                }
              },
            ),
            TextButton(
              child: Text(
                '${nameValue.name}:${nameValue.value}',
                style: metadataStyle,
              ),
              onPressed: () {
                setState(() {
                  if (_selectedNameValues.contains(nameValue)) {
                    _selectedNameValues.remove(nameValue);
                  } else {
                    _selectedNameValues.add(nameValue);
                  }
                });
              },
            ),
            const SizedBox(
              width: 10,
            ),
          ],
        ));
      }
    }

    List<Widget> songWidgetList = [];
    {
      SplayTreeSet<Song> _metadataSongs = SplayTreeSet();
      for (var nameValue in _selectedNameValues) {
        var songIdMetadataSet = SongMetadata.where(nameIsLike: nameValue.name, valueIsLike: nameValue.value);
        for (var song in _app.allSongs) {
          for (var songIdMetadata in songIdMetadataSet) {
            if (songIdMetadata.id == song.songId.toString()) {
              _metadataSongs.add(song);
            }
          }
        }
      }
      if (_isSearchActive) {
        _metadataSongs.addAll(_filteredSongs);
      }
      songWidgetList = _metadataSongs.map((song) {
        return Row(
          children: [
            Checkbox(
                checkColor: Colors.white,
                fillColor: MaterialStateProperty.all(_blue.color),
                value: _hasSelectedMetadata(song),
                onChanged: (bool? value) {
                  if (value != null) {
                    setState(() {
                      if (value) {
                        SongMetadata.add(SongIdMetadata(song.songId.toString(),
                            metadata: _selectedNameValues.toList(growable: false)));
                      } else {
                        for (var nameValue in _selectedNameValues) {
                          for (var songIdMetadata in SongMetadata.where(
                              idIsLike: song.songId.toString(),
                              nameIsLike: nameValue.name,
                              valueIsLike: nameValue.value)) {
                            logger.i('remove: $songIdMetadata');
                            SongMetadata.remove(songIdMetadata);
                          }
                        }
                      }
                    });
                  }
                }),
            Text(
              '${song.title} by ${song.artist}'
              '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}',
              style: metadataStyle,
            )
          ],
        );
      }).toList(growable: false);
    }

    final AppTextStyle searchTextStyle = AppTextStyle(
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      color: Colors.black38,
      textBaseline: TextBaseline.alphabetic,
    );
    final AppTextStyle titleTextStyle = AppTextStyle(
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      color: Colors.black87,
      textBaseline: TextBaseline.alphabetic,
    );
    var _clearSearchKey = const ValueKey<String>('clearSearch');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Music App Lists',
          style: AppTextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(
                height: 10,
              ),
              appWrapFullWidth([
                appButton(
                  'Save',
                  onPressed: () {
                    _saveSongMetadata();
                  },
                ),
                appButton(
                  'Read files',
                  onPressed: () {
                    setState(() {
                      _filePick(context);
                    });
                  },
                ),
              ], alignment: WrapAlignment.spaceBetween),
              appWrapFullWidth([
                appWrap([
                  Checkbox(
                      checkColor: Colors.white,
                      fillColor: MaterialStateProperty.all(_blue.color),
                      value: _isSearchActive,
                      onChanged: (bool? value) {
                        if (value != null) {
                          setState(() {
                            _isSearchActive = value;
                          });
                        }
                      }),
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'search',
                    iconSize: fontSize,
                    onPressed: (() {
                      setState(() {
                        _searchSongs(_searchTextFieldController.text);
                      });
                    }),
                  ),
                  SizedBox(
                    width: 10 * _app.screenInfo.fontSize,
                    //  limit text entry display length
                    child: TextField(
                      key: const ValueKey('searchText') /*  for testing*/,
                      enabled: _isSearchActive,
                      controller: _searchTextFieldController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: "enter search text",
                        hintStyle: searchTextStyle,
                      ),
                      autofocus: true,
                      style: titleTextStyle,
                      onChanged: (text) {
                        setState(() {
                          logger.v('search text: "$text"');
                          _searchSongs(_searchTextFieldController.text);
                        });
                      },
                    ),
                  ),
                  IconButton(
                    key: _clearSearchKey,
                    icon: const Icon(Icons.clear),
                    tooltip:
                        _searchTextFieldController.text.isEmpty ? 'Scroll the list some.' : 'Clear the search text.',
                    iconSize: 1.5 * fontSize,
                    onPressed: (() {
                      WidgetLog.tap(_clearSearchKey);
                      _searchTextFieldController.clear();
                      setState(() {
                        FocusScope.of(context).requestFocus(_searchFocusNode);
                        _searchSongs(null);
                      });
                    }),
                  ),
                ]),
              ], alignment: WrapAlignment.spaceBetween),
              const SizedBox(
                height: 20,
              ),
              appWrap(
                _metadataWidgets,
                alignment: WrapAlignment.spaceEvenly,
              ),
              const SizedBox(
                height: 10,
              ),
              Expanded(
                child: ListView(
                  children: songWidgetList,
                  scrollDirection: Axis.vertical,
                ),
              ),
            ]),
      ),
    );
  }

  void _searchSongs(String? search) {
    if (!_isSearchActive) {
      _filteredSongs.clear();
      return;
    }

    search ??= '';
    search = search.trim();

    search = search.replaceAll("[^\\w\\s']+", '');
    search = search.toLowerCase();

    // select order
    int Function(Song key1, Song key2) compare;
    compare = (Song song1, Song song2) {
      return song1.compareTo(song2);
    };

    //  apply search filter
    _filteredSongs = SplayTreeSet(compare);
    for (final Song song in _app.allSongs) {
      if (search.isEmpty ||
          song.getTitle().toLowerCase().contains(search) ||
          song.getArtist().toLowerCase().contains(search)) {
        //  not filtered
        _filteredSongs.add(song);
      }
    }
  }

  void _saveSongMetadata() async {
    String fileName =
        'allSongs_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songmetadata'; //  fixme: cover artist?
    String contents = SongMetadata.toJson();
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    logger.i('_saveSongMetadata message: $message');
  }

  void _filePick(BuildContext context) async {
    await UtilWorkaround().songMetadataFilePick(context);
    setState(() {});
  }

  bool _isSearchActive = false;
  SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
  final FocusNode _searchFocusNode;

  final SplayTreeSet<NameValue> _selectedNameValues = SplayTreeSet();
  final TextEditingController _searchTextFieldController = TextEditingController();

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
  final App _app = App();
}
