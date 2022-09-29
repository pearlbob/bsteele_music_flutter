import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/metadataPopupMenuButton.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';

const Level _logBuild = Level.debug;
const Level _logAddSong = Level.debug;
const Level _logDeleteSong = Level.debug;

/// Allow the user to manage metadata for all available songs.
/// Name and value pairs are assigned to songs identified by their song id.
/// The value portion may be empty.
///
/// Export of this file to the master release will make it the app's default set of sub-lists.
class MetadataScreen extends StatefulWidget {
  const MetadataScreen({Key? key}) : super(key: key);

  @override
  MetadataScreenState createState() => MetadataScreenState();

  static const String routeName = 'metadata';
}

class MetadataScreenState extends State<MetadataScreen> {
  @override
  initState() {
    super.initState();

    SongMetadata.isDirty = false; //  assume it is what it is
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
    app.screenInfo.refresh(context);

    logger.log(_logBuild, 'metadata build: $_selectedNameValue');

    final double fontSize = app.screenInfo.fontSize;
    metadataStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

    logger.v('_selectedNameValue: $_selectedNameValue');

    List<DropdownMenuItem<String>> nameDropdownMenuItems = [];
    List<DropdownMenuItem<String>> valueDropdownMenuItems = [];
    {
      //  find all name/values in use
      SplayTreeSet<NameValue> nameValues = SplayTreeSet();
      for (var songIdMetadata in SongMetadata.idMetadata) {
        nameValues.addAll(songIdMetadata.nameValues);
      }
      logger.v('lists.build: ${SongMetadata.idMetadata}');

      {
        //  clear the selected of old values
        List<NameValue> removal = [];
        if (!nameValues.contains(_selectedNameValue)) {
          removal.add(_selectedNameValue);
        }
      }

      {
        SplayTreeSet<DropdownMenuItem<String>> itemSet = SplayTreeSet(_compareDropdownMenuItemString);
        for (var nameValue in nameValues) {
          if (nameValue.name.isEmpty) {
            continue;
          }
          itemSet
              .add(DropdownMenuItem<String>(value: nameValue.name, child: Text(nameValue.name, style: metadataStyle)));
        }
        nameDropdownMenuItems = itemSet.toList(growable: false);

        //  values
        itemSet.clear();
        var name = _nameTextFieldController.text;
        for (var songIdMetadata in SongMetadata.where(nameIs: name)) {
          itemSet.addAll(songIdMetadata.nameValues
              .where((e) => e.name == name)
              .map((e) => DropdownMenuItem<String>(value: e.value, child: Text(e.value, style: metadataStyle))));
        }
        valueDropdownMenuItems = itemSet.toList(growable: false);
      }
    }

    _selectedNameValue = (_nameTextFieldController.text.isNotEmpty && _valueTextFieldController.text.isNotEmpty)
        ? NameValue(_nameTextFieldController.text, _valueTextFieldController.text)
        : _emptySelectedNameValue;

    return MultiProvider(
        providers: [
          //  fixme: has to be a widget level above it's use????
          ChangeNotifierProvider<PlayListRefreshNotifier>(create: (_) => PlayListRefreshNotifier()),
        ],
        child: Scaffold(
          backgroundColor: Theme.of(context).backgroundColor,
          appBar: appWidgetHelper.appBar(
            title: 'bsteeleMusicApp Song Metadata',
            leading: appWidgetHelper.back(
                canPop: _canPop,
                onPressed: () {
                  app.clearMessage();
                }),
          ),
          body: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const AppSpace(),
                    Text(app.message,
                        style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                        key: const ValueKey('errorMessage')),
                    const AppSpace(),
                    //  file stuff
                    AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
                      appEnumeratedButton(
                        'Write all metadata to file',
                        appKeyEnum: AppKeyEnum.listsSave,
                        onPressed: () {
                          _saveSongMetadata();
                        },
                      ),
                      appEnumeratedButton(
                        'Write all metadata to CSV',
                        appKeyEnum: AppKeyEnum.listsSaveCSV,
                        onPressed: () {
                          _saveSongMetadataAsCSV();
                        },
                      ),
                      appEnumeratedButton(
                        'Read metadata from file',
                        appKeyEnum: AppKeyEnum.listsReadLists,
                        onPressed: () {
                          setState(() {
                            _filePick(context);
                          });
                        },
                      ),
                      // if (_selectedNameValue != _emptySelectedNameValue)
                      //   appEnumeratedButton(
                      //     'Write ${_selectedNameValue.name}:${_selectedNameValue.value} to file',
                      //     appKeyEnum: AppKeyEnum.listsSaveSelected,
                      //     onPressed: () {
                      //       _saveNameValueSongMetadata(_selectedNameValue);
                      //       logger.i('save selection: $_selectedNameValue');
                      //     },
                      //   ),
                      appEnumeratedButton(
                        'Delete all ${nameValueIsDeletable(_selectedNameValue) ? _selectedNameValue.toShortString() : 'is disabled'}',
                        appKeyEnum: AppKeyEnum.listsClearLists,
                        onPressed: nameValueIsDeletable(_selectedNameValue)
                            ? () {
                                showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                          title: Text(
                                            'Do you really want to delete the metadata ${_selectedNameValue.toShortString()}?',
                                            style: TextStyle(fontSize: metadataStyle.fontSize),
                                          ),
                                          actions: [
                                            AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
                                              appButton('Yes! Delete all of ${_selectedNameValue.toShortString()}.',
                                                  appKeyEnum: AppKeyEnum.listsDeleteList, onPressed: () {
                                                logger.log(
                                                    _logDeleteSong, 'delete: ${_selectedNameValue.toShortString()}');
                                                setState(() {
                                                  SongMetadata.removeAll(_selectedNameValue);
                                                  _selectedNameValue = _emptySelectedNameValue;
                                                  AppOptions().storeSongMetadata();
                                                });
                                                Navigator.of(context).pop();
                                              }),
                                              const AppSpace(space: 100),
                                              appButton('Cancel', appKeyEnum: AppKeyEnum.listsCancelDeleteList,
                                                  onPressed: () {
                                                Navigator.of(context).pop();
                                              }),
                                            ])
                                          ],
                                          elevation: 24.0,
                                        ));
                              }
                            : null,
                      ),
                    ]),
                    const AppSpace(spaceFactor: 2),
                    Text('Set or clear metadata Name:Value pairs:',
                        style: metadataStyle.copyWith(fontWeight: FontWeight.bold)),
                    const AppSpace(spaceFactor: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MetadataPopupMenuButton.button(
                          title: 'Existing metadata',
                          style: metadataStyle,
                          onSelected: (value) {
                            setState(() {
                              _nameTextFieldController.text = value.name;
                              _valueTextFieldController.text = value.value;
                            });
                          },
                        ),
                        const AppSpace(spaceFactor: 4),
                        Text('New: ', style: metadataStyle),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 10 * app.screenInfo.fontSize,
                                  //  limit text entry display length
                                  child: AppTextField(
                                    appKeyEnum: AppKeyEnum.listsNameEntry,
                                    controller: _nameTextFieldController,
                                    hintText: "enter name...",
                                    //                 hintStyle: metadataStyle.copyWith(color: Colors.black54),
                                    onChanged: (text) {
                                      setState(() {});
                                    },
                                    fontSize: fontSize,
                                  ),
                                ),
                                const AppSpace(),
                                //  search clear
                                AppTooltip(
                                    message: 'Clear the name text.',
                                    child: appEnumeratedIconButton(
                                      icon: const Icon(Icons.clear),
                                      appKeyEnum: AppKeyEnum.listsNameClear,
                                      iconSize: metadataStyle.fontSize,
                                      onPressed: (() {
                                        setState(() {
                                          _nameTextFieldController.clear();
                                          app.clearMessage();
                                          // FocusScope.of(context).requestFocus(_searchFocusNode);  fixme?
                                        });
                                      }),
                                    )),
                              ],
                            ),
                            const AppSpace(spaceFactor: 1),
                            DropdownButton<String>(
                                hint: Text('Existing names', style: metadataStyle),
                                items: nameDropdownMenuItems,
                                onChanged: (value) {
                                  if (value != null && _nameTextFieldController.text != value) {
                                    setState(() {
                                      _nameTextFieldController.text = value;
                                      _valueTextFieldController.text = ''; //  suppose the value is now wrong
                                    });
                                  }
                                }),
                          ],
                        ),
                        Text(
                          '  :  ',
                          style: metadataStyle,
                        ),
                        //  value entry
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 10 * app.screenInfo.fontSize,
                                  //  limit text entry display length
                                  child: AppTextField(
                                    appKeyEnum: AppKeyEnum.listsValueEntry,
                                    controller: _valueTextFieldController,
                                    hintText: "enter value...",
                                    onChanged: (text) {
                                      setState(() {
                                        if (_nameTextFieldController.text.isNotEmpty) {
                                          _selectedNameValue =
                                              NameValue(_nameTextFieldController.text, _valueTextFieldController.text);
                                        }
                                      });
                                    },
                                    fontSize: fontSize,
                                  ),
                                ),
                                const AppSpace(spaceFactor: 2),
                                //  search clear
                                AppTooltip(
                                    message: 'Clear the value text.',
                                    child: appEnumeratedIconButton(
                                      icon: const Icon(Icons.clear),
                                      appKeyEnum: AppKeyEnum.listsValueClear,
                                      iconSize: metadataStyle.fontSize,
                                      onPressed: (() {
                                        setState(() {
                                          _valueTextFieldController.clear();
                                          app.clearMessage();
                                          // FocusScope.of(context).requestFocus(_searchFocusNode);  fixme?
                                        });
                                      }),
                                    )),
                              ],
                            ),
                            const AppSpace(spaceFactor: 2),
                            if (_nameTextFieldController.text.isNotEmpty)
                              DropdownButton<String>(
                                  hint: Text('Values of ${_nameTextFieldController.text}', style: metadataStyle),
                                  items: valueDropdownMenuItems,
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _valueTextFieldController.text = value;
                                      });
                                    }
                                  }),
                          ],
                        ),
                      ],
                    ),

                    Consumer<PlayListRefreshNotifier>(
                      builder: (context, playListRefreshNotifier, child) => PlayList.byGroup(
                        SongListGroup([
                          SongList(
                              '',
                              app.allSongs
                                  .map((song) => SongListItem.fromSong(song,
                                      customWidget: _selectedNameValue != _emptySelectedNameValue &&
                                              !(SongMetadata.songIdMetadata(song)?.contains(_selectedNameValue) ??
                                                  false)
                                          ? appIconButton(
                                              icon: appIcon(
                                                Icons.add,
                                              ),
                                              label: _selectedNameValue.toShortString(),
                                              appKeyEnum: AppKeyEnum.listsMetadataAdd,
                                              value: // '${id.id}:'  fixme
                                                  '${_selectedNameValue.name}=${_selectedNameValue.value}',
                                              fontSize: 0.75 * app.screenInfo.fontSize,
                                              backgroundColor: Colors.lightGreen,
                                              onPressed: () {
                                                logger.log(_logAddSong,
                                                    'pressed: ${_selectedNameValue.toShortString()} to $song');
                                                SongMetadata.addSong(song, _selectedNameValue);
                                                playListRefreshNotifier.refresh();
                                                logger.log(
                                                    _logAddSong,
                                                    'metadata: playListRefreshNotifier.positionPixels: '
                                                    '${playListRefreshNotifier.positionPixels}');
                                              },
                                            )
                                          : null))
                                  .toList(growable: false))
                        ]),
                        style: metadataStyle,
                        isEditing: true,
                        selectedSortType: PlayListSortType.byTitle,
                      ),
                    ),
                  ])),
          floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.listsBack),
        ));
  }

  Widget mapSongToWidget(Song song) {
    return AppWrapFullWidth(
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
          style: metadataStyle,
        ),
        const AppSpace(space: 12),
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

  /// return true if the metadata has changed
  bool _canPop() {
    if (!isDirty) {
      return true;
    }

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: Text(
                'Do you really want discard all of your metadata changes?',
                style: appWarningTextStyle,
              ),
              actions: [
                appButton('Don\'t write my changes!', appKeyEnum: AppKeyEnum.metadataDiscardAllChanges, onPressed: () {
                  app.clearMessage();
                  Navigator.of(context).pop(); //  the dialog
                  Navigator.of(context).pop(); //  the screen
                }),
                const AppSpace(),
                appButton('Write the metadata to a file and return', appKeyEnum: AppKeyEnum.metadataWriteAllChanges,
                    onPressed: () {
                  _saveSongMetadata();
                  app.clearMessage();
                  Navigator.of(context).pop(); //  the dialog
                  Navigator.of(context).pop(); //  the screen
                }),
                const AppSpace(),
                appButton('Cancel the return... I need to work some more on this.',
                    appKeyEnum: AppKeyEnum.metadataCancelTheReturn, onPressed: () {
                  Navigator.of(context).pop();
                }),
              ],
              elevation: 24.0,
            ));
    return false;
  }

  void _saveSongMetadata() async {
    _saveMetadata('allSongs', SongMetadata.toJson());
  }

  void _saveMetadata(String prefix, String contents) async {
    String fileName = '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songmetadata';
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    logger.i('_saveMetadata message: $message');
    setState(() {
      SongMetadata.isDirty = false;
      app.infoMessage = '.songmetadata $message';
    });
  }

  _saveSongMetadataAsCSV() async {
    String fileName = 'allSongsMetadata_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    var converter = const ListToCsvConverter();
    List<List> rows = [];
    rows.add(['Title', 'Artist', 'Cover Artist', 'Year', 'Jam', 'Genre', 'Subgenre', 'Status']);
    for (var song in app.allSongs) {
      var md = SongMetadata.songMetadata(song, 'year');
      var year = md.isNotEmpty ? md.first.value : '';
      md = SongMetadata.songMetadata(song, 'jam');
      var jam = md.isNotEmpty ? md.first.value : '';
      md = SongMetadata.songMetadata(song, 'genre');
      var genre = md.isNotEmpty ? md.first.value : '';
      md = SongMetadata.songMetadata(song, 'subgenre');
      var subgenre = md.isNotEmpty ? md.first.value : '';
      md = SongMetadata.songMetadata(song, 'status');
      var status = md.isNotEmpty ? md.first.value : '';
      rows.add([
        song.title,
        song.artist,
        song.coverArtist,
        year,
        jam,
        genre,
        subgenre,
        status,
      ]);
    }
    String message = await UtilWorkaround().writeFileContents(fileName, converter.convert(rows));
    logger.i('_saveMetadata message: $message');
    setState(() {
      app.infoMessage = '.csv $message';
    });
  }

  void _filePick(BuildContext context) async {
    var content = await UtilWorkaround().filePickByExtension(context, '.songmetadata');

    setState(() {
      if (content.isEmpty) {
        app.infoMessage = 'No metadata read';
      } else {
        SongMetadata.clear(); // wow!
        SongMetadata.fromJson(content);
        AppOptions().storeSongMetadata();
      }
    });
  }

  bool nameValueIsDeletable(NameValue nameValue) {
    logger.v('nameValueIsDeletable(): $nameValue');

    if (nameValue == _emptySelectedNameValue) {
      return false;
    }

    return nameValue.name.isNotEmpty;
  }

  int _compareDropdownMenuItemString(DropdownMenuItem<String> key1, DropdownMenuItem<String> key2) {
    return key1.value?.compareTo(key2.value ?? '') ?? -1;
  }

  TextStyle metadataStyle = generateAppTextStyle();

  bool get isDirty => SongMetadata.isDirty;

  static const NameValue _emptySelectedNameValue = NameValue('', '');
  NameValue _selectedNameValue = _emptySelectedNameValue;

  final TextEditingController _nameTextFieldController = TextEditingController();
  final TextEditingController _valueTextFieldController = TextEditingController();

  late AppWidgetHelper appWidgetHelper;
}
