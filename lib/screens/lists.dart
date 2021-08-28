import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../app/app.dart';

final _blue = Paint()..color = Colors.lightBlue.shade200;

int _dirtyCount = 0;

/// Allow the user to manage sub-lists from all available songs.
/// Name and value pairs are assigned to songs identified by their song id.
/// The value portion may be empty.
/// The names 'cj' and 'holiday' should remain reserved.
///
/// Note that the lists will not persist unless written to a file.
/// At the next app invocation, the file will have to read.
/// Export of this file to the master release will make it the app's default set of sub-lists.
class Lists extends StatefulWidget {
  const Lists({Key? key}) : super(key: key);

  @override
  _State createState() => _State();
}

late TextStyle metadataStyle;

class _State extends State<Lists> {
  _State() : _searchFocusNode = FocusNode();

  @override
  initState() {
    super.initState();

    _app.clearMessage();
    logger.d("_Songs.initState()");
  }

  bool _hasSelectedMetadata(Song song) {
    if (_selectedNameValue.name.isNotEmpty &&
        SongMetadata.where(
                idIs: song.songId.toString(), nameIs: _selectedNameValue.name, valueIs: _selectedNameValue.value)
            .isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    appWidget.context = context; //	required on every build

    final double fontSize = _app.screenInfo.fontSize;
    metadataStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );
    final metadataEntryStyle = generateAppTextStyle(
      color: Colors.black38,
      fontSize: fontSize,
    );
    final TextStyle searchTextStyle = generateAppTextStyle(
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      color: Colors.black38,
      textBaseline: TextBaseline.alphabetic,
    );
    final TextStyle titleTextStyle = generateAppTextStyle(
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
            appSpace(),
          ],
        ));
      }

      _metadataWidgets.add(appWrap(
        [
          appSpace(space: 20),
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
      var songIdMetadataSet = SongMetadata.where(nameIs: _selectedNameValue.name, valueIs: _selectedNameValue.value);
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
        songWidgetList.addAll(_filteredSongs.map(mapSongToWidget).toList());
        songWidgetList.add(const Divider(
          thickness: 10,
        ));
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
      appBar: appWidget.backBar(title:'bsteele Music App Song Lists'),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              appSpace(),
              Text(_app.message,
                  style: _app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                  key: const ValueKey('errorMessage')),
              const SizedBox(
                height: 10,
              ),
              appWrapFullWidth([
                appButton(
                  'Save',
                  onPressed: () {
                    _saveSongMetadata();
                  },
                  background: _dirtyCount == 0 ? appDisabledColor : null,
                ),
                if (_selectedNameValue != _emptySelectedNameValue)
                  appButton(
                    'Save ${_selectedNameValue.name}:${_selectedNameValue.value}',
                    onPressed: () {
                      _saveNameValueSongMetadata(_selectedNameValue);
                      logger.i('save selection: $_selectedNameValue');
                    },
                  ),
                appButton(
                  'Read lists from file',
                  onPressed: () {
                    setState(() {
                      _filePick(context);
                    });
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
                  appWidget.checkbox(
                      value: _isSearchActive,
                      onChanged: (bool? value) {
                        if (value != null) {
                          setState(() {
                            _isSearchActive = value;
                            _searchSongs(_searchTextFieldController.text);
                          });
                        }
                      },
                      fontSize: metadataStyle.fontSize),
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
                  appTooltip(
                    message:
                        _searchTextFieldController.text.isEmpty ? 'Scroll the list some.' : 'Clear the search text.',
                    child: IconButton(
                      key: _clearSearchKey,
                      icon: const Icon(Icons.clear),
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
                  ),
                ]),
              ], alignment: WrapAlignment.spaceBetween),
              appSpace(),
              Divider(
                thickness: 10,
                color: _blue.color,
              ),
              appSpace(),
              Expanded(
                child: ListView(
                  children: songWidgetList,
                  scrollDirection: Axis.vertical,
                ),
              ),
            ]),
      ),
      floatingActionButton: appWidget.floatingBack(),
    );
  }

  Widget mapSongToWidget(Song song) {
    return Row(
      children: [
        appWidget.checkbox(
          value: _hasSelectedMetadata(song),
          onChanged: (bool? value) {
            if (value != null) {
              setState(() {
                _dirtyCount++;
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
          },
          fontSize: metadataStyle.fontSize,
        ),
        appSpace(space: 12),
        TextButton(
          child: Text(
            '${song.title} by ${song.artist}'
            '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}',
            style: metadataStyle,
          ),
          onPressed: () {
            setState(() {
              if (_selectedNameValue.name.isNotEmpty) {
                _dirtyCount++;
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
    _dirtyCount = 0;
    _saveMetadata('allSongs', SongMetadata.toJson());
  }

  void _saveNameValueSongMetadata(NameValue nv) async {
    String contents = SongMetadata.toJson(values: SongMetadata.where(nameValue: _selectedNameValue));
    _saveMetadata('${_selectedNameValue.name}_${_selectedNameValue.value}', contents);
  }

  void _saveMetadata(String prefix, String contents) async {
    String fileName = '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songmetadata';
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    logger.i('_saveMetadata message: $message');
    setState(() {
      _app.infoMessage('.songmetadata $message');
    });
  }

  void _filePick(BuildContext context) async {
    var message = await UtilWorkaround().songMetadataFilePick(context);

    setState(() {
      if (message.isEmpty) {
        _app.infoMessage('No metatdata read');
      } else {
        _app.infoMessage(message);
      }
    });
  }

  bool _isSearchActive = false;
  SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
  final FocusNode _searchFocusNode;

  static const NameValue _emptySelectedNameValue = NameValue('', '');
  NameValue _selectedNameValue = _emptySelectedNameValue;
  final TextEditingController _searchTextFieldController = TextEditingController();

  final TextEditingController _nameTextFieldController = TextEditingController();
  final TextEditingController _valueTextFieldController = TextEditingController();

  final AppWidget appWidget = AppWidget();

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
  final App _app = App();
}
