import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/drum_measure.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/play_list_search_matcher.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../util/utilWorkaround.dart';
import '../widgets/drums.dart';

class DrumPlayListItem implements PlayListItem {
  DrumPlayListItem(this.drumParts);

  @override
  int compareTo(PlayListItem other) {
    if (identical(this, other)) {
      return 0;
    }
    if (other is DrumPlayListItem) {
      return drumParts.compareTo(other.drumParts);
    }
    return -1;
  }

  @override
  Widget toWidget(BuildContext context, PlayListItemAction? songItemAction, bool isEditing, VoidCallback? refocus) {
    var boldStyle = DefaultTextStyle.of(context).style.copyWith(fontWeight: FontWeight.bold);
    return AppInkWell(
        appKeyEnum: AppKeyEnum.drumScreenSelection,
        value: Id(drumParts.name),
        onTap: () {
          if (songItemAction != null) {
            songItemAction(context, this);
          }
        },
        child: AppWrap(children: [
          Text(
            '${drumParts.name}:',
            style: boldStyle,
          ),
          Text(' ${drumParts.beats}: ${drumParts.partsToString()}'),
        ]));
  }

  final DrumParts drumParts;
}

/// Show some data about the app and it's environment.
class DrumScreen extends StatefulWidget {
  const DrumScreen({Key? key, this.song, this.isEditing = false}) : super(key: key);

  @override
  DrumScreenState createState() => DrumScreenState();

  final Song? song;
  final bool isEditing;

  static const String routeName = 'drumScreen';
}

class DrumScreenState extends State<DrumScreen> with WidgetsBindingObserver {
  @override
  initState() {
    super.initState();

    _isEditing = widget.isEditing;

    _lastSize = WidgetsBinding.instance.window.physicalSize;
    WidgetsBinding.instance.addObserver(this);

    logger.v('song: ${widget.song?.toString()}');

    app.clearMessage();

    if (_drumPartsList.isEmpty) {
      //  fill with something meaningful if empty
      const beats = 4;
      _drumPartsList.add(DrumParts(name: 'minimum', beats: beats, parts: [
        DrumPart(DrumTypeEnum.closedHighHat, beats: beats)
          ..addBeat(DrumBeat.beat1)
          ..addBeat(DrumBeat.beat3)
      ]));
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.v('DrumScreenState build: ${_drums?.drumParts}');

    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    app.screenInfo.refresh(context);

    var style = generateAppTextStyle(color: Colors.black87, fontSize: app.screenInfo.fontSize);

    return Consumer<PlayListRefreshNotifier>(builder: (context, playListRefreshNotifier, child) {
      //  clear the entry if asked
      if (playListRefreshNotifier.searchClearQuery()) {
        _drums = null;
      }
      return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: appWidgetHelper.backBar(title: 'Drums'),
        body: DefaultTextStyle(
          style: style,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (app.message.isNotEmpty)
                AppWrapFullWidth(alignment: WrapAlignment.start, children: [
                  Text(
                    app.message,
                    style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                    key: appKeyCreate(AppKeyEnum.singersErrorMessage),
                  ),
                ]),
              AppWrapFullWidth(alignment: WrapAlignment.spaceBetween, children: [
                if (_isEditing)
                  AppTooltip(
                    message: 'Create a new drum part',
                    child: appButton(
                      'Create new drums',
                      appKeyEnum: AppKeyEnum.drumScreenNew,
                      onPressed: () {
                        setState(() {
                          app.clearMessage();
                          _drums = DrumsWidget(key: UniqueKey(), drumParts: DrumParts()..name = '');
                        });
                      },
                    ),
                  ),
                if (!_isEditing) Text('Select drums for: ${songToString(widget.song)}'),
                if (_isEditing && widget.isEditing == false)
                  AppTooltip(
                    message: 'Switch back to selection mode if finished editing.',
                    child: appButton(
                      'Return from editing to drum selection.',
                      appKeyEnum: AppKeyEnum.drumScreenBackToSelection,
                      onPressed: () {
                        setState(() {
                          app.clearMessage();
                          _isEditing = false;
                        });
                      },
                    ),
                  ),
                if (!_isEditing && widget.isEditing == false)
                  AppTooltip(
                    message: 'Edit drum parts prior to selection.',
                    child: appButton(
                      'Edit',
                      appKeyEnum: AppKeyEnum.drumScreenEditDuringSelection,
                      onPressed: () {
                        setState(() {
                          _isEditing = true;
                        });
                      },
                    ),
                  ),
                appButton('Other Actions', appKeyEnum: AppKeyEnum.singersShowOtherActions, onPressed: () {
                  setState(() {
                    app.clearMessage();
                    showOtherActions = !showOtherActions;
                  });
                }),
              ]),
              if (showOtherActions)
                AppWrapFullWidth(alignment: WrapAlignment.end, children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const AppVerticalSpace(),
                      AppTooltip(
                        message: 'Write all drum parts and their metadata to a local file.',
                        child: appButton(
                          'Save drum parts to a local file',
                          appKeyEnum: AppKeyEnum.drumScreenWrite,
                          onPressed: () {
                            setState(() {
                              logger.v('write drum file');
                              app.clearMessage();
                              _saveDrumPartsList('allDrums', _drumPartsList.toJson());
                            });
                          },
                        ),
                      ),
                      const AppVerticalSpace(),
                      AppTooltip(
                        message: 'Read all drum parts and their metadata from a local file.',
                        child: appButton(
                          'Read all drum parts from a local file',
                          appKeyEnum: AppKeyEnum.drumScreenRead,
                          onPressed: () {
                            setState(() {
                              app.clearMessage();
                              logger.v('read drum file');
                              _filePickReadDrumPartsList(context);
                              _appOptions.drumPartsListJson = _drumPartsList.toJson();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ]),
              if (_isEditing) _drums ?? NullWidget(),
              PlayList(
                itemList: PlayListItemList(
                    'DrumList', _drumPartsList.drumParts.map((e) => DrumPlayListItem(e)).toList(),
                    playListItemAction: loadDrumListItem),
                style: style,
                isFromTheTop: false,
                isOrderBy: false,
                playListSearchMatcher: DrumPlayListSearchMatcher(),
              ),
            ]),
          ),
        ),
        floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.drumScreenBack),
      );
    });
  }

  String songToString(final Song? song) {
    return song == null
        ? ''
        : '${song.title} by ${song.artist}${song.coverArtist.isEmpty ? '' : ' cover by ${song.coverArtist}'}';
  }

  loadDrumListItem(BuildContext context, PlayListItem playListItem) async {
    if (_isEditing) {
      //  edit the selection
      DrumParts drumParts = (playListItem as DrumPlayListItem).drumParts.copyWith();
      setState(() {
        _drums = DrumsWidget(key: UniqueKey(), drumParts: drumParts);
      });
    } else {
      //  complete the selection
      app.selectedDrumParts = (playListItem as DrumPlayListItem).drumParts;
      Navigator.of(context).pop();
    }
  }

  void _filePickReadDrumPartsList(BuildContext context) async {
    app.clearMessage();
    var content = await UtilWorkaround().filePickByExtension(context, DrumPartsList.fileExtension);

    setState(() {
      if (content.isEmpty) {
        app.infoMessage = 'No drum parts file read';
      } else {
        logger.v('read drum parts from: "$content"');
        try {
          _drumPartsList.fromJson(content);
          app.infoMessage = 'All drum parts and matching songs read.';
        } catch (e) {
          app.error = 'Error during drum file read: $e.';
        }
      }
    });
  }

  Future<void> _saveDrumPartsList(String prefix, String contents) async {
    String fileName = '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}'
        '${DrumPartsList.fileExtension}';
    String message = await UtilWorkaround().writeFileContents(fileName, contents); //  fixme: should be async
    logger.d('saveSingersSongList message: \'$message\'');
    app.infoMessage = message;
  }

  @override
  void didChangeMetrics() {
    //  used to keep the window size data current
    Size size = WidgetsBinding.instance.window.physicalSize;
    if (size != _lastSize) {
      setState(() {
        _lastSize = size;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _isEditing = false;
  DrumsWidget? _drums;
  late Size _lastSize;
  bool showOtherActions = false;

  final DrumPartsList _drumPartsList = DrumPartsList();
  final _appOptions = AppOptions();
}
