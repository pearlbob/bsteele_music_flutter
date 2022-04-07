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
              fontSize: fontSize,
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
      {
        if (_filteredSongs.isNotEmpty) {
          songWidgetList.addAll(_filteredSongs.map(mapSongToWidget).toList());
          songWidgetList.add(appSpace());
        }
        songWidgetList.add(const Divider(
          thickness: 10,
        ));
        songWidgetList.add(Text(
          (_filteredSongs.isNotEmpty ? 'Other songs' : 'Songs') +
              ' in the list "${_selectedNameValue.toShortString()}":',
          style: metadataStyle.copyWith(color: Colors.grey),
        ));
        _metadataSongs.addAll(_filteredSongs);
      }
      //  list other, non-matching set songs later
      for (var song in _metadataSongSet) {
        //  avoid repeats
        if (!_metadataSongs.contains(song)) {
          songWidgetList.add(mapSongToWidget(song));
        }
      }
      songWidgetList.add(appSpace());
      songWidgetList.add(const Divider(
        thickness: 10,
      ));
      songWidgetList.add(Text(
        (searchTerm.isNotEmpty ? 'Other songs not matching the search "$searchTerm" and ' : 'Songs ') +
            'not in the list "${_selectedNameValue.toShortString()}":',
        style: metadataStyle.copyWith(color: Colors.grey),
      ));
      for (var song in app.allSongs) {
        if (_metadataSongSet.contains(song) || _filteredSongs.contains(song)) {
          continue;
        }
        songWidgetList.add(mapSongToWidget(song));
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
              appWrapFullWidth(children: [
                appEnumeratedButton(
                  'Write all to file',
                  appKeyEnum: AppKeyEnum.listsSave,
                  onPressed: () {
                    _saveSongMetadata();
                  },
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
                                      appButton('Yes! Delete all of ${_selectedNameValue.toShortString()}.',
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
              appWrapFullWidth(children: [
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
                      appKeyEnum: AppKeyEnum.listsSearchText,
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
      children: [
        appWidgetHelper.checkbox(
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
                SongMetadata.add(SongIdMetadata(song.songId.toString(), metadata: [_selectedNameValue]));
              }
            });
          },
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
    _saveMetadata('allSongs', SongMetadata.toJson());
  }

  void _saveNameValueSongMetadata(NameValue nameValue) async {
    String contents = SongMetadata.toJsonAt(nameValue: nameValue);
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
    var content = await UtilWorkaround().filePickByExtension(context, '.songmetadata');

    setState(() {
      if (content.isEmpty) {
        app.infoMessage('No metadata read');
      } else {
        SongMetadata.fromJson(content);
        AppOptions().storeSongMetadata();
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

  String searchTerm = '';
  SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
  final FocusNode _searchFocusNode;

  static const NameValue _emptySelectedNameValue = NameValue('', '');
  NameValue _selectedNameValue = _emptySelectedNameValue;
  final TextEditingController _searchTextFieldController = TextEditingController();

  final TextEditingController _nameTextFieldController = TextEditingController();
  final TextEditingController _valueTextFieldController = TextEditingController();

  late AppWidgetHelper appWidgetHelper;
}
