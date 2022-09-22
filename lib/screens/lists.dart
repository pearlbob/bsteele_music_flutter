import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../app/app.dart';

//const Level _logBuild = Level.info;

/// Allow the user to manage metadata for all available songs.
/// Name and value pairs are assigned to songs identified by their song id.
/// The value portion may be empty.
///
/// Export of this file to the master release will make it the app's default set of sub-lists.
class Lists extends StatefulWidget {
  const Lists({Key? key}) : super(key: key);

  @override
  ListsState createState() => ListsState();
}

class ListsState extends State<Lists> {
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

    List<DropdownMenuItem<NameValue>> nameValueDropdownMenuItems = [];
    List<DropdownMenuItem<String>> nameDropdownMenuItems = [];
    List<DropdownMenuItem<String>> valueDropdownMenuItems = [];
    {
      //  find all name/values in use
      SplayTreeSet<NameValue> nameValues = SplayTreeSet();
      for (var songIdMetadata in SongMetadata.idMetadata) {
        nameValues.addAll(songIdMetadata.nameValues);
      }
      logger.v('lists.build: ${SongMetadata.idMetadata}');

      nameValueDropdownMenuItems = nameValues
          .map((e) => DropdownMenuItem<NameValue>(value: e, child: Text(e.toShortString(), style: metadataStyle)))
          .toList(growable: false);
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
    var selectedNameValueString =
        SongMetadata.contains(_selectedNameValue) ? _selectedNameValue.toShortString() : 'Name:Values';

    return Provider<PlayListRefresh>(create: (BuildContext context) {
      return //widget.playListRefresh ??
          PlayListRefresh(() {
        setState(() {
          logger.i('PlayList: PlayListRefresh()');
        });
      });
    }, builder: (context, child) {
      return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: appWidgetHelper.backBar(title: 'bsteele Music App Song Metadata'),
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
                                            logger.i('delete: ${_selectedNameValue.toShortString()}');
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
                            // SongMetadata.clear();
                          }
                        : null,
                  ),
                ]),
                const AppSpace(
                  verticalSpace: 20,
                ),
                Text('Set or clear metadata Name:Value pairs:',
                    style: metadataStyle.copyWith(fontWeight: FontWeight.bold)),
                const AppSpace(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<NameValue>(
                        hint: Text('Existing $selectedNameValueString', style: metadataStyle),
                        items: nameValueDropdownMenuItems,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _nameTextFieldController.text = value.name;
                              _valueTextFieldController.text = value.value;
                            });
                          }
                        }),
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
                        const AppSpace(),
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
                            const AppSpace(),
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
                        const AppSpace(),
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

                PlayList.byGroup(
                  SongListGroup([
                    SongList(
                        '',
                        app.allSongs
                            .map((song) => SongListItem.fromSong(song,
                                customWidget: _selectedNameValue != _emptySelectedNameValue &&
                                        !(SongMetadata.songIdMetadata(song)?.contains(_selectedNameValue) ?? false)
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
                                          logger.i('pressed: ${_selectedNameValue.toShortString()} to $song');
                                          SongMetadata.addSong(song, _selectedNameValue);
                                          //  re-build this screen with the new data
                                          Provider.of<PlayListRefresh>(context, listen: false).voidCallback();
                                        },
                                      )
                                    : null))
                            .toList(growable: false))
                  ]),
                  style: metadataStyle,
                  isEditing: true,
                ),
              ]),
        ),
        floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.listsBack),
      );
    });
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
          fontSize: metadataStyle.fontSize,
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

  void _saveSongMetadata() async {
    _saveMetadata('allSongs', SongMetadata.toJson());
  }

  void _saveMetadata(String prefix, String contents) async {
    String fileName = '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songmetadata';
    String message = await UtilWorkaround().writeFileContents(fileName, contents);
    logger.i('_saveMetadata message: $message');
    setState(() {
      app.infoMessage = '.songmetadata $message';
    });
  }

  void _filePick(BuildContext context) async {
    var content = await UtilWorkaround().filePickByExtension(context, '.songmetadata');

    setState(() {
      if (content.isEmpty) {
        app.infoMessage = 'No metadata read';
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

  int _compareDropdownMenuItemString(DropdownMenuItem<String> key1, DropdownMenuItem<String> key2) {
    return key1.value?.compareTo(key2.value ?? '') ?? -1;
  }

  TextStyle metadataStyle = generateAppTextStyle();

  static const NameValue _emptySelectedNameValue = NameValue('', '');
  NameValue _selectedNameValue = _emptySelectedNameValue;

  final TextEditingController _nameTextFieldController = TextEditingController();
  final TextEditingController _valueTextFieldController = TextEditingController();

  late AppWidgetHelper appWidgetHelper;
}
