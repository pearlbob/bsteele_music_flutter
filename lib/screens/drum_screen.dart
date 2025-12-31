import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/appOptions.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/util/nullWidget.dart';
import 'package:bsteele_music_flutter/util/play_list_search_matcher.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/drum_measure.dart';
import 'package:bsteele_music_lib/songs/key.dart' as music_key;
import 'package:bsteele_music_lib/songs/music_constants.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/util/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import '../songMaster.dart';
import '../util/utilWorkaround.dart';
import '../widgets/drums.dart';

const Level _logBPM = Level.debug;

/// Show some data about the app and it's environment.
class DrumScreen extends StatefulWidget {
  const DrumScreen({super.key, this.song, this.isEditing = false});

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

    _lastSize = PlatformDispatcher.instance.implicitView?.physicalSize;
    WidgetsBinding.instance.addObserver(this);

    logger.t('song: ${widget.song?.toString()}');

    app.clearMessage();

    if (_drumPartsList.isEmpty) {
      //  fill with something meaningful if empty
      const beats = 4;
      _drumPartsList.add(
        DrumParts(
          name: 'minimum',
          beats: beats,
          parts: [
            DrumPart(DrumTypeEnum.closedHighHat, beats: beats)
              ..addBeat(DrumBeat.beat1)
              ..addBeat(DrumBeat.beat3),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.t('DrumScreenState build: ${_drums?.drumParts}');

    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    app.screenInfo.refresh(context);

    var style = generateAppTextStyle(color: Colors.black87, fontSize: app.screenInfo.fontSize);

    return Consumer<PlayListRefreshNotifier>(
      builder: (context, playListRefreshNotifier, child) {
        //  clear the entry if asked
        if (playListRefreshNotifier.searchClearQuery()) {
          _drums = null;
        }
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: appWidgetHelper.backBar(
            title: 'Drums',
            onPressed: () {
              _songMaster.stop();
            },
          ),
          body: DefaultTextStyle(
            style: style,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  if (app.message.isNotEmpty)
                    AppWrapFullWidth(
                      alignment: WrapAlignment.start,
                      children: [
                        Text(
                          app.message,
                          style: app.messageType == MessageType.error ? appErrorTextStyle : appTextStyle,
                        ),
                      ],
                    ),
                  AppWrapFullWidth(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      if (_isEditing)
                        AppTooltip(
                          message: 'Create a new drum part',
                          child: appButton(
                            'Create new drums',
                            onPressed: () {
                              setState(() {
                                app.clearMessage();
                                var parts = DrumParts()..name = '';
                                _drums = DrumsWidget(key: UniqueKey(), drumParts: parts);
                                _songMaster.playDrums(widget.song ?? _drumSong, parts);
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
                            onPressed: () {
                              setState(() {
                                _songMaster.stop();
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
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                              });
                            },
                          ),
                        ),
                      appButton(
                        'Other Actions',
                        onPressed: () {
                          setState(() {
                            app.clearMessage();
                            showOtherActions = !showOtherActions;
                          });
                        },
                      ),
                    ],
                  ),
                  if (showOtherActions)
                    AppWrapFullWidth(
                      alignment: WrapAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: .end,
                          children: [
                            const AppVerticalSpace(),
                            AppTooltip(
                              message: 'Write all drum parts and their metadata to a local file.',
                              child: appButton(
                                'Save drum parts to a local file',
                                onPressed: () {
                                  setState(() {
                                    logger.t('write drum file');
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
                                onPressed: () {
                                  setState(() {
                                    app.clearMessage();
                                    logger.t('read drum file');
                                    _filePickReadDrumPartsList(context);
                                    appOptions.drumPartsListJson = _drumPartsList.toJson();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const AppVerticalSpace(),
                  if (_isEditing)
                    AppWrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Volume:', style: style),
                        SizedBox(
                          width: app.screenInfo.mediaWidth * 0.4,
                          // fixme: too fiddly
                          child: Slider(
                            value: appOptions.volume * 10,
                            onChanged: (value) {
                              setState(() {
                                appOptions.volume = value / 10;
                              });
                            },
                            min: 0,
                            max: 10.0,
                          ),
                        ),
                        if (app.isScreenBig)
                          //  tempo change
                          AppWrap(
                            children: [
                              const AppSpace(horizontalSpace: 50),
                              AppTooltip(
                                message:
                                    'Beats per minute.  Tap here or hold control and tap space\n'
                                    ' for tap to tempo.',
                                child: appButton(
                                  'BPM:',
                                  onPressed: () {
                                    tempoTap();
                                  },
                                ),
                              ),
                              const AppSpace(horizontalSpace: 20),
                              appIconWithLabelButton(
                                onPressed: () {
                                  setState(() {
                                    playerSelectedBpm = Util.intLimit(
                                      (playerSelectedBpm ?? widget.song?.beatsPerMinute ?? MusicConstants.defaultBpm) -
                                          1,
                                      MusicConstants.minBpm,
                                      MusicConstants.maxBpm,
                                    );
                                    _playDrums();
                                  });
                                },
                                icon: Icon(Icons.remove, size: style.fontSize),
                              ),
                              const AppSpace(),
                              Text((playerSelectedBpm ?? MusicConstants.defaultBpm).toString(), style: style),
                              const AppSpace(),
                              appIconWithLabelButton(
                                onPressed: () {
                                  setState(() {
                                    playerSelectedBpm = Util.intLimit(
                                      (playerSelectedBpm ?? widget.song?.beatsPerMinute ?? MusicConstants.defaultBpm) +
                                          1,
                                      MusicConstants.minBpm,
                                      MusicConstants.maxBpm,
                                    );
                                    _playDrums();
                                  });
                                },
                                icon: Icon(Icons.add, size: style.fontSize),
                              ),
                            ],
                          ),
                      ],
                    ),
                  if (_isEditing) _drums ?? NullWidget(),
                  PlayList(
                    itemList: PlayListItemList(
                      'DrumList',
                      _drumPartsList.drumParts.map((e) => DrumPlayListItem(e)).toList(),
                      playListItemAction: loadDrumListItem,
                    ),
                    style: style,
                    isOrderBy: false,
                    playListSearchMatcher: DrumPlayListSearchMatcher(),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: appWidgetHelper.floatingBack(),
        );
      },
    );
  }

  String songToString(final Song? song) {
    return song == null
        ? ''
        : '${song.title} by ${song.artist}${song.coverArtist.isEmpty ? '' : ' cover by ${song.coverArtist}'}';
  }

  void tempoTap() {
    //  tap to tempo
    final tempoTap = DateTime.now().microsecondsSinceEpoch;
    double delta = (tempoTap - _lastTempoTap) / Duration.microsecondsPerSecond;
    _lastTempoTap = tempoTap;

    if (delta < 60 / 30 && delta > 60 / 200) {
      int bpm = (_tempoRollingAverage ??= RollingAverage()).average(60 / delta).round();
      if (playerSelectedBpm != bpm) {
        setState(() {
          playerSelectedBpm = bpm;
          _playDrums();
          logger.log(_logBPM, 'tempoTap(): bpm: $playerSelectedBpm');
        });
      }
    } else {
      //  delta too small or too large
      _tempoRollingAverage = null;
      playerSelectedBpm = null; //  default to song beats per minute
      logger.log(_logBPM, 'tempoTap(): default: bpm: $playerSelectedBpm');
    }
  }

  loadDrumListItem(BuildContext context, PlayListItem playListItem) async {
    if (_isEditing) {
      //  don't step on previous changes
      if (_drumParts?.hasChanged ?? false) {
        logger.i('drumParts have changed!!!!');
      }

      //  edit the selection
      _drumParts = (playListItem as DrumPlayListItem).drumParts.copyWith();
      setState(() {
        _drums = DrumsWidget(key: UniqueKey(), drumParts: _drumParts);
        _playDrums();
      });
    } else {
      //  complete the selection
      app.selectedDrumParts = (playListItem as DrumPlayListItem).drumParts;
      _songMaster.stop();
      Navigator.of(context).pop();
    }
  }

  _playDrums() {
    _songMaster.playDrums(
      widget.song ?? _drumSong,
      _drumParts,
      bpm: playerSelectedBpm ?? widget.song?.beatsPerMinute ?? MusicConstants.defaultBpm,
    );
  }

  void _filePickReadDrumPartsList(BuildContext context) async {
    app.clearMessage();
    var content = await UtilWorkaround().filePickByExtension(context, DrumPartsList.fileExtension);

    setState(() {
      if (content.isEmpty) {
        app.infoMessage = 'No drum parts file read';
      } else {
        logger.t('read drum parts from: "$content"');
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
    String fileName =
        '${prefix}_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}'
        '${DrumPartsList.fileExtension}';
    String message = await UtilWorkaround().writeFileContents(fileName, contents); //  fixme: should be async
    logger.d('saveSingersSongList message: \'$message\'');
    app.infoMessage = message;
  }

  @override
  void didChangeMetrics() {
    //  used to keep the window size data current
    var size = PlatformDispatcher.instance.implicitView?.physicalSize;
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

  //  a simple song to drum for a long time
  static final _drumSong = Song(
    title: 'drum song',
    artist: 'bob',
    copyright: '2024 none',
    key: music_key.Key.getDefault(),
    beatsPerMinute: 120,
    beatsPerBar: 4,
    unitsPerMeasure: 4,
    chords: 'V: [A B C D E F G G#] x1000',
    rawLyrics: 'v: none',
  );

  bool _isEditing = false;
  DrumParts? _drumParts;
  DrumsWidget? _drums;
  Size? _lastSize;
  bool showOtherActions = false;

  int _lastTempoTap = DateTime.now().microsecondsSinceEpoch;
  RollingAverage? _tempoRollingAverage;

  final SongMaster _songMaster = SongMaster();

  final DrumPartsList _drumPartsList = DrumPartsList();
}

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
  String get title => drumParts.name;

  @override
  Widget toWidget(
    BuildContext context,
    PlayListItemAction? songItemAction,
    bool isEditing,
    VoidCallback? refocus,
    bool bunch,
    final PlayListSortType? playListSortType,
  ) {
    var boldStyle = DefaultTextStyle.of(context).style.copyWith(fontWeight: .bold);
    return AppInkWell(
      value: Id(drumParts.name),
      onTap: () {
        if (songItemAction != null) {
          songItemAction(context, this);
        }
      },
      child: AppWrap(
        children: [
          Text('${drumParts.name}:', style: boldStyle),
          Text('  ${drumParts.beats}: ${drumParts.partsToString()}'),
        ],
      ),
    );
  }

  final DrumParts drumParts;
}
