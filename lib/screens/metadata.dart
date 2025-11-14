import 'dart:collection';

import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/metadataPopupMenuButton.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_metadata.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../app/app.dart';
import '../util/play_list_search_matcher.dart';

const Level _logBuild = Level.debug;
const Level _logAddSong = Level.debug;
const Level _logDeleteSong = Level.debug;

/// Allow the user to manage metadata for all available songs.
/// Name and value pairs are assigned to songs identified by their song id.
/// The value portion may be empty.
///
/// Export of this file to the master release will make it the app's default set of sub-lists.
class MetadataScreen extends StatefulWidget {
  const MetadataScreen({super.key});

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
    smallMetadataStyle = metadataStyle.copyWith(
      fontSize: 0.75 * fontSize,
    );

    logger.t('_selectedNameValue: $_selectedNameValue');

    List<DropdownMenuItem<String>> nameDropdownMenuItems = [];
    List<DropdownMenuItem<String>> valueDropdownMenuItems = [];
    {
      //  find all name/values in use
      SplayTreeSet<NameValue> nameValues = SplayTreeSet();
      for (var songIdMetadata in SongMetadata.idMetadata) {
        nameValues.addAll(songIdMetadata.nameValues);
      }
      logger.t('lists.build: ${SongMetadata.idMetadata}');

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
          if (nameValue.name.isEmpty || SongMetadataGeneratedValue.isGenerated(nameValue)) {
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
          backgroundColor: Theme.of(context).colorScheme.surface,
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
                  mainAxisAlignment: .start,
                  crossAxisAlignment: .start,
                  children: <Widget>[
                    const AppSpace(),
                    Text(app.message,
                        style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                        key: const ValueKey('errorMessage')),
                    const AppSpace(),
                    //  file stuff
                    AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
                      appButton(
                        'Write all metadata to file',
                        onPressed: () {
                          _saveSongMetadata();
                        },
                      ),
                      appButton(
                        'Write all metadata to CSV',
                        onPressed: () {
                          _saveSongMetadataAsCSV();
                        },
                      ),
                      appButton(
                        'Read metadata from file',
                        onPressed: () {
                          setState(() {
                            _filePick(context);
                          });
                        },
                      ),
                      // if (_selectedNameValue != _emptySelectedNameValue)
                      //   appButton(
                      //     'Write ${_selectedNameValue.name}:${_selectedNameValue.value} to file',
                      //     appKeyEnum: AppKeyEnum.listsSaveSelected,
                      //     onPressed: () {
                      //       _saveNameValueSongMetadata(_selectedNameValue);
                      //       logger.i('save selection: $_selectedNameValue');
                      //     },
                      //   ),
                      appButton(
                        'Delete all ${nameValueIsDeletable(_selectedNameValue) ? _selectedNameValue.toString() : 'is disabled'}',
                        onPressed: nameValueIsDeletable(_selectedNameValue)
                            ? () {
                                showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                          title: Text(
                                            'Do you really want to delete the metadata ${_selectedNameValue.toString()}?',
                                            style: TextStyle(fontSize: metadataStyle.fontSize),
                                          ),
                                          actions: [
                                            AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
                                              appButton('Yes! Delete all of ${_selectedNameValue.toString()}.',
                                                  onPressed: () {
                                                logger.log(_logDeleteSong, 'delete: ${_selectedNameValue.toString()}');
                                                setState(() {
                                                  SongMetadata.removeAll(_selectedNameValue);
                                                  _selectedNameValue = _emptySelectedNameValue;
                                                  AppOptions().storeSongMetadata();
                                                });
                                                Navigator.of(context).pop();
                                              }),
                                              const AppSpace(space: 100),
                                              appButton('Cancel', onPressed: () {
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
                    const AppSpace(horizontalSpace: 20),
                    Text('Set or clear metadata Name:Value pairs:',
                        style: metadataStyle.copyWith(fontWeight: .bold)),
                    const AppSpace(horizontalSpace: 20),
                    Row(
                      crossAxisAlignment: .start,
                      children: [
                        MetadataPopupMenuButton.button(
                          title: 'Existing metadata',
                          style: metadataStyle,
                          showAllValues: false,
                          onSelected: (value) {
                            setState(() {
                              _nameTextFieldController.text = value.name;
                              _valueTextFieldController.text = value.value;
                            });
                          },
                        ),
                        const AppSpace(horizontalSpace: 20),
                        Text('New: ', style: metadataStyle),
                        Column(
                          crossAxisAlignment: .start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 10 * app.screenInfo.fontSize,
                                  //  limit text entry display length
                                  child: AppTextField(
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
                                    child: appIconButton(
                                      icon: const Icon(Icons.clear),
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
                            const AppSpace(horizontalSpace: 20),
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
                          crossAxisAlignment: .start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 10 * app.screenInfo.fontSize,
                                  //  limit text entry display length
                                  child: AppTextField(
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
                                const AppSpace(horizontalSpace: 20),
                                //  search clear
                                AppTooltip(
                                    message: 'Clear the value text.',
                                    child: appIconButton(
                                      icon: const Icon(Icons.clear),
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
                            const AppSpace(horizontalSpace: 20),
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
                        PlayListGroup([
                          PlayListItemList(
                              '',
                              app.allSongs
                                  .map((song) => SongPlayListItem.fromSong(song,
                                      customWidget: _selectedNameValue != _emptySelectedNameValue &&
                                              !(SongMetadata.songIdMetadata(song)?.contains(_selectedNameValue) ??
                                                  false)
                                          ? AppTooltip(
                                              message: 'Add this $_selectedNameValue to this song',
                                              child: appIconWithLabelButton(
                                                icon: appIcon(
                                                  Icons.add,
                                                ),
                                                label: _selectedNameValue.toString(),
                                                value: SongIdMetadataItem(song, _selectedNameValue),
                                                fontSize: 0.75 * app.screenInfo.fontSize,
                                                backgroundColor: Colors.lightGreen,
                                                onPressed: () {
                                                  logger.log(_logAddSong,
                                                      'pressed: ${_selectedNameValue.toString()} to $song');
                                                  SongMetadata.addSong(song, _selectedNameValue);
                                                  playListRefreshNotifier.refresh();
                                                  logger.log(
                                                      _logAddSong,
                                                      'metadata: playListRefreshNotifier.positionPixels: '
                                                      '${playListRefreshNotifier.positionPixels}');
                                                },
                                              ),
                                            )
                                          : _selectedNameValue != _emptySelectedNameValue
                                              ? Text(
                                                  '(already set)',
                                                  style: smallMetadataStyle,
                                                )
                                              : null))
                                  .toList(growable: false))
                        ]),
                        style: metadataStyle,
                        isEditing: true,
                        selectedSortType: .byTitle,
                        isFromTheTop: false,
                        showAllFilters: true,
                        playListSearchMatcher: SongPlayListSearchMatcher(),
                      ),
                    ),
                  ])),
          floatingActionButton: appWidgetHelper.floatingBack(),
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
                '''Do you really want discard all of your metadata changes?
Your changes will not be remembered when you restart.
Writing a file will allow you to reload your changes later.''',
                style: metadataStyle,
              ),
              actions: [
                appButton('Don\'t write my changes!', onPressed: () {
                  app.clearMessage();
                  Navigator.of(context).pop(); //  the dialog
                  Navigator.of(context).pop(); //  the screen
                }),
                const AppSpace(),
                appButton('Write the metadata to a file and return', onPressed: () {
                  _saveSongMetadata();
                  app.clearMessage();
                  Navigator.of(context).pop(); //  the dialog
                  Navigator.of(context).pop(); //  the screen
                }),
                const AppSpace(),
                appButton('Cancel the return... I need to work some more on this.', onPressed: () {
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
      var md = SongMetadata.songMetadata(song, 'Year');
      var year = md.isNotEmpty ? md.first.value : '';
      md = SongMetadata.songMetadata(song, 'Jam');
      var jam = md.isNotEmpty ? md.first.value : '';
      md = SongMetadata.songMetadata(song, 'Genre');
      var genre = md.isNotEmpty ? md.first.value : '';
      md = SongMetadata.songMetadata(song, 'Subgenre');
      var subgenre = md.isNotEmpty ? md.first.value : '';
      md = SongMetadata.songMetadata(song, 'Status');
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
    logger.t('nameValueIsDeletable(): $nameValue');

    if (nameValue == _emptySelectedNameValue) {
      return false;
    }

    return nameValue.name.isNotEmpty;
  }

  int _compareDropdownMenuItemString(DropdownMenuItem<String> key1, DropdownMenuItem<String> key2) {
    return key1.value?.compareTo(key2.value ?? '') ?? -1;
  }

  TextStyle metadataStyle = generateAppTextStyle();
  TextStyle smallMetadataStyle = generateAppTextStyle();

  bool get isDirty => SongMetadata.isDirty;

  static final NameValue _emptySelectedNameValue = NameValue('', '');
  NameValue _selectedNameValue = _emptySelectedNameValue;

  final TextEditingController _nameTextFieldController = TextEditingController();
  final TextEditingController _valueTextFieldController = TextEditingController();

  late AppWidgetHelper appWidgetHelper;
}
