import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/drum_measure.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/song_performance.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/drums.dart';

class DrumListItem implements SongListItem {
  DrumListItem(this.drumParts);

  @override
  int compareTo(SongListItem other) {
    if (identical(this, other)) {
      return 0;
    }
    if (other is DrumListItem) {
      return drumParts.compareTo(other.drumParts);
    }
    return -1;
  }

  @override
  Widget toWidget(BuildContext context, SongItemAction? songItemAction, bool isEditing, VoidCallback? refocus) {
    var boldStyle = DefaultTextStyle.of(context).style.copyWith(fontWeight: FontWeight.bold);
    return AppInkWell(
        appKeyEnum: AppKeyEnum.drumsSelection,
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

  @override
  // TODO: implement customWidget
  Widget? get customWidget => const Text('DrumListItem');

  @override
  // TODO: implement firstWidget
  Widget? get firstWidget => throw UnimplementedError();

  @override
  Song get song => Song.theEmptySong;

  @override
  SongPerformance? get songPerformance => null;

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

    logger.i('song: ${widget.song?.toString()}');

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    logger.v('DrumScreenState build: ${_drums?.drumParts}');

    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    app.screenInfo.refresh(context);

    if (_drumPartsList.isEmpty) {
      //  fill with something meaningful if empty
      const beats = 4;
      _drumPartsList.add(DrumParts(name: 'minimum', beats: beats, parts: [
        DrumPart(DrumTypeEnum.closedHighHat, beats: beats)
          ..addBeat(0) //  beats here count from zero!
          ..addBeat(2)
      ]));
      _drumPartsList.add(DrumParts(name: 'snare', beats: beats, parts: [
        DrumPart(DrumTypeEnum.closedHighHat, beats: beats)
          ..addBeat(0)
          ..addBeat(2),
        DrumPart(DrumTypeEnum.snare, beats: beats)
          ..addBeat(1)
          ..addBeat(3),
      ]));
    }

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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _isEditing
                  ? (_drums ??
                      AppTooltip(
                        message: 'Create a new drum part',
                        child: appButton(
                          'Create new drums',
                          appKeyEnum: AppKeyEnum.drumScreenNew,
                          onPressed: () {
                            setState(() {
                              _drums = DrumsWidget(key: UniqueKey(), drumParts: DrumParts()..name = '');
                            });
                          },
                        ),
                      ))
                  : Text('Select drums for: ${songToString(widget.song)}'),
            ),
            PlayList(
              songList: SongList('DrumList', _drumPartsList.drumParts.map((e) => DrumListItem(e)).toList(),
                  songItemAction: loadDrumListItem),
              style: style,
              isFromTheTop: false,
              isOrderBy: false,
            ),
          ]),
        ),
        floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.aboutBack),
      );
    });
  }

  String songToString(final Song? song) {
    return song == null
        ? ''
        : '${song.title} by ${song.artist}${song.coverArtist.isEmpty ? '' : ' cover by ${song.coverArtist}'}';
  }

  loadDrumListItem(BuildContext context, SongListItem songListItem) async {
    if (_isEditing) {
      //  edit the selection
      DrumParts drumParts = (songListItem as DrumListItem).drumParts.copyWith();
      setState(() {
        _drums = DrumsWidget(key: UniqueKey(), drumParts: drumParts);
      });
    } else {
      //  complete the selection
      app.selectedDrumParts = (songListItem as DrumListItem).drumParts;
      Navigator.of(context).pop();
    }
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

  final DrumPartsList _drumPartsList = DrumPartsList();
}
