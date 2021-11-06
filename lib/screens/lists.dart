import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
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

class _State extends State<Lists> {
  _State() : _searchFocusNode = FocusNode();

  @override
  initState() {
    super.initState();

    app.clearMessage();
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
    appWidgetHelper = AppWidgetHelper(context);

    final double fontSize = app.screenInfo.fontSize;
    metadataStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

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
      logger.v('lists.build: ${SongMetadata.idMetadata}');
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
            width: 5 * app.screenInfo.fontSize,
            //  limit text entry display length
            child: appTextField(
              appKeyEnum: AppKeyEnum.listsNameEntry,
              controller: _nameTextFieldController,
              hintText: "name...",
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
            width: 5 * app.screenInfo.fontSize,
            //  limit text entry display length
            child: appTextField(
              appKeyEnum: AppKeyEnum.listsValueEntry,
              controller: _valueTextFieldController,
              hintText: "value...",
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
      for (var song in app.allSongs) {
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
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Song Lists'),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              appSpace(),
              Text(app.message,
                  style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                  key: const ValueKey('errorMessage')),
              const SizedBox(
                height: 10,
              ),
              appWrapFullWidth([
                appEnumeratedButton(
                  'Write all to file',
                  appKeyEnum: AppKeyEnum.listsSave,
                  onPressed: () {
                    _saveSongMetadata();
                  },
                  backgroundColor: _dirtyCount == 0 ? appDisabledColor : null,
                ),
                if (_selectedNameValue != _emptySelectedNameValue)
                  appEnumeratedButton(
                    'Write ${_selectedNameValue.name}:${_selectedNameValue.value} to file',
                    appKeyEnum: AppKeyEnum.listsSaveSelected,
                    onPressed: () {
                      _saveNameValueSongMetadata(_selectedNameValue);
                      logger.i('save selection: $_selectedNameValue');
                    },
                  ),
                appEnumeratedButton(
                  'Read lists from file',
                  appKeyEnum: AppKeyEnum.listsReadLists,
                  onPressed: () {
                    setState(() {
                      _filePick(context);
                    });
                  },
                ),
                appEnumeratedButton(
                  'Delete the list',
                  appKeyEnum: AppKeyEnum.listsClearLists,
                  onPressed: nameValueIsDeletable(_selectedNameValue)
                      ? () {
                          showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                    title: Text(
                                      'Do you really want to delete the list?',
                                      style: TextStyle(fontSize: metadataStyle.fontSize),
                                    ),
                                    actions: [
                                      appButton('Yes! Delete all of ${_selectedNameValue.toShortString()}',
                                          appKeyEnum: AppKeyEnum.listsDeleteList, onPressed: () {
                                        logger.i('delete: ${_selectedNameValue.toShortString()}');
                                        setState(() {
                                          SongMetadata.removeAll(_selectedNameValue);
                                          _selectedNameValue = _emptySelectedNameValue;
                                          AppOptions().storeSongMetadata();
                                        });
                                        Navigator.of(context).pop();
                                      }),
                                      appSpace(space: 100),
                                      appButton('Cancel', appKeyEnum: AppKeyEnum.listsCancelDeleteList, onPressed: () {
                                        Navigator.of(context).pop();
                                      }),
                                    ],
                                    elevation: 24.0,
                                  ));
                          // SongMetadata.clear();
                        }
                      : null,
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
                  appWidgetHelper.checkbox(
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
                    width: 10 * app.screenInfo.fontSize,
                    //  limit text entry display length
                    child: appTextField(
                      appKeyEnum: AppKeyEnum.listsSearchText,
                      enabled: _isSearchActive,
                      controller: _searchTextFieldController,
                      hintText: _isSearchActive ? "enter search text" : "\u2190 activate search",
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
                    child: appEnumeratedIconButton(
                      appKeyEnum: AppKeyEnum.listsClearSearch,
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
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.listsBack),
    );
  }

  Widget mapSongToWidget(Song song) {
    return appWrapFullWidth(
      [
        appWidgetHelper.checkbox(
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
                    SongMetadata.remove(songIdMetadata, _selectedNameValue);
                  }
                }
                AppOptions().storeSongMetadata();
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

    final RegExp searchRegex = RegExp(search, caseSensitive: false);

    // select order
    int Function(Song key1, Song key2) compare;
    compare = (Song song1, Song song2) {
      return song1.compareTo(song2);
    };

    //  apply search filter
    _filteredSongs = SplayTreeSet(compare);
    for (final Song song in app.allSongs) {
      if (searchRegex.hasMatch(song.getTitle()) || searchRegex.hasMatch(song.getArtist())) {
        //  matches
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
      app.infoMessage('.songmetadata $message');
    });
  }

  void _filePick(BuildContext context) async {
    var message = await UtilWorkaround().songMetadataFilePick(context);

    setState(() {
      if (message.isEmpty) {
        app.infoMessage('No metatdata read');
      } else {
        app.infoMessage(message);
      }
    });
  }

  bool nameValueIsDeletable(NameValue nameValue) {
    logger.d('selectionIsDeletable(): $nameValue');

    if (nameValue == _emptySelectedNameValue) {
      return false;
    }

    switch (nameValue.name) {
      case '':
      case 'christmas':
        return false;
      case 'cj':
        return kDebugMode;
      default:
        return true;
    }
  }

  late TextStyle metadataStyle;

  bool _isSearchActive = false;
  SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
  final FocusNode _searchFocusNode;

  static const NameValue _emptySelectedNameValue = NameValue('', '');
  NameValue _selectedNameValue = _emptySelectedNameValue;
  final TextEditingController _searchTextFieldController = TextEditingController();

  final TextEditingController _nameTextFieldController = TextEditingController();
  final TextEditingController _valueTextFieldController = TextEditingController();

  late AppWidgetHelper appWidgetHelper;

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
}
