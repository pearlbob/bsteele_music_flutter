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

late AppTextStyle metadataStyle ;

class _State extends State<Lists> {
  _State() : _searchFocusNode = FocusNode();

  @override
  initState() {
    super.initState();

    logger.d("_Songs.initState()");
  }

  bool _hasSelectedMetadata(Song song) {
    if (_selectedNameValue.name.isNotEmpty &&
        SongMetadata.where(
                idIs: song.songId.toString(),
                nameIs: _selectedNameValue.name,
                valueIs: _selectedNameValue.value)
            .isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = _app.screenInfo.fontSize;
     metadataStyle = AppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );
    final metadataEntryStyle = AppTextStyle(
      color: Colors.black38,
      fontSize: fontSize,
    );
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

    logger.v('_selectedNameValue: $_selectedNameValue');

    List<Widget> _metadataWidgets = [];
    {
      //  find all name/values in use
      SplayTreeSet<NameValue> nameValues = SplayTreeSet();
      for (var songIdMetadata in SongMetadata.idMetadata) {
        for (var nameValue in songIdMetadata.nameValues) {
          nameValues.add(nameValue);
        }
      }
      {
        //  clear the selected of old values
        List<NameValue> removal = [];
        if (!nameValues.contains(_selectedNameValue)) {
          removal.add(_selectedNameValue);
        }
      }

      for (var nameValue in nameValues) {
        if (nameValue.name.isEmpty) {
          continue;
        }
        _metadataWidgets.add(appWrap(
          [
            Radio(
              value: nameValue,
              groupValue: _selectedNameValue,
              onChanged: (NameValue? value) {
                if (value != null) {
                  setState(() {
                    _selectedNameValue = nameValue;
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
                  _selectedNameValue = nameValue;
                });
              },
            ),
            const SizedBox(
              width: 10,
            ),
          ],
        ));
      }

      _metadataWidgets.add(appWrap(
        [
          const SizedBox(
            width: 20,
          ),
          Radio(
            value: NameValue(_nameTextFieldController.text, _valueTextFieldController.text),
            groupValue: _selectedNameValue,
            onChanged: (NameValue? value) {
              if (value != null) {
                setState(() {
                  _selectedNameValue = value;
                });
              }
            },
          ),
          SizedBox(
            width: 5 * _app.screenInfo.fontSize,
            //  limit text entry display length
            child: TextField(
              key: const ValueKey('nameText') /*  for testing*/,
              controller: _nameTextFieldController,
              // focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: "name...",
                hintStyle: metadataEntryStyle,
              ),
              autofocus: true,
              style: metadataStyle,
              onChanged: (text) {
                setState(() {
                  if (_nameTextFieldController.text.isNotEmpty) {
                    _selectedNameValue = NameValue(_nameTextFieldController.text, _valueTextFieldController.text);
                  }
                });
              },
            ),
          ),
          Text(
            ':',
            style: metadataStyle,
          ),
          SizedBox(
            width: 5 * _app.screenInfo.fontSize,
            //  limit text entry display length
            child: TextField(
              key: const ValueKey('valueText') /*  for testing*/,
              controller: _valueTextFieldController,
              // focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: "value...",
                hintStyle: metadataEntryStyle,
              ),
              autofocus: true,
              style: metadataStyle,
              onChanged: (text) {
                setState(() {
                  if (_nameTextFieldController.text.isNotEmpty) {
                    _selectedNameValue = NameValue(_nameTextFieldController.text, _valueTextFieldController.text);
                  }
                });
              },
            ),
          ),
        ],
      ));
    }

    List<Widget> songWidgetList = [];
    {
      SplayTreeSet<Song> _metadataSongSet = SplayTreeSet();
      var songIdMetadataSet =
          SongMetadata.where(nameIs: _selectedNameValue.name, valueIs: _selectedNameValue.value);
      for (var song in _app.allSongs) {
        for (var songIdMetadata in songIdMetadataSet) {
          if (songIdMetadata.id == song.songId.toString()) {
            _metadataSongSet.add(song);
          }
        }
      }
      List<Song> _metadataSongs = [];
      //  search songs on top
      if (_isSearchActive) {
        songWidgetList.addAll( _filteredSongs.map(mapSongToWidget).toList());
        songWidgetList.add( const Divider( thickness: 10,));
        _metadataSongs.addAll(_filteredSongs);
      }
      //  list songs later
      for (var song in _metadataSongSet) {
        //  avoid repeats
        if (!_metadataSongs.contains(song)) {
          songWidgetList.add(mapSongToWidget(song));
        }
      }
    }

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
        padding: const EdgeInsets.all(12.0),
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
                        hintText: _isSearchActive ? "enter search text" : "\u2190 activate search",
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
  
  Widget mapSongToWidget(Song song){
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
                    if (_selectedNameValue.name.isNotEmpty) {
                      SongMetadata.add(SongIdMetadata(song.songId.toString(), metadata: [_selectedNameValue]));
                    }
                  } else {
                    for (var songIdMetadata in SongMetadata.where(
                        idIs: song.songId.toString(),
                        nameIs: _selectedNameValue.name,
                        valueIs: _selectedNameValue.value)) {
                      logger.d('remove: $songIdMetadata');
                      SongMetadata.remove(songIdMetadata);
                    }
                  }
                });
              }
            }),
        const SizedBox(
          width: 12,
        ),
        TextButton(
          child: Text(
            '${song.title} by ${song.artist}'
                '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}',
            style: metadataStyle,
          ),
          onPressed: () {
            setState(() {
              if (_selectedNameValue.name.isNotEmpty) {
                SongMetadata.add(SongIdMetadata(song.songId.toString(), metadata: [_selectedNameValue]));
              }
            });
          },
        )
      ],
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

  static const NameValue _emptySelectedNameValue = NameValue('', '');
  NameValue _selectedNameValue = _emptySelectedNameValue;
  final TextEditingController _searchTextFieldController = TextEditingController();

  final TextEditingController _nameTextFieldController = TextEditingController();
  final TextEditingController _valueTextFieldController = TextEditingController();

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
  final App _app = App();
}
