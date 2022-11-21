import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/drumMeasure.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteele_music_flutter/app/app.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:flutter/material.dart';

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
    return AppInkWell(
        appKeyEnum: AppKeyEnum.drumsSelection,
        value: Id(drumParts.name),
        onTap: () {
          if (songItemAction != null) {
            songItemAction(context, this);
          }
        },
        child: Text(drumParts.toString()));
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

int _beats = 4; //  fixme temp

/// Show some data about the app and it's environment.
class DrumScreen extends StatefulWidget {
  const DrumScreen({Key? key, this.song}) : super(key: key);

  @override
  DrumScreenState createState() => DrumScreenState();

  final Song? song;

  static const String routeName = 'drumScreen';
}

class DrumScreenState extends State<DrumScreen> with WidgetsBindingObserver {
  @override
  initState() {
    super.initState();

    _lastSize = WidgetsBinding.instance.window.physicalSize;
    WidgetsBinding.instance.addObserver(this);

    _drums = DrumsWidget();

    logger.i('song: ${widget.song?.toString()}');

    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    logger.i('DrumScreenState build: ${_drums.drumParts}');

    AppWidgetHelper appWidgetHelper = AppWidgetHelper(context);

    app.screenInfo.refresh(context);

    List<SongListItem> tempDrumListItems = [
      DrumListItem(DrumParts(
          name: 'test1', beats: _beats, parts: [DrumPart(DrumTypeEnum.closedHighHat, beats: _beats)..addBeat(0)])),
      DrumListItem(
          DrumParts(name: 'test2', beats: _beats, parts: [DrumPart(DrumTypeEnum.bass, beats: _beats)..addBeat(1)])),
    ];

    var style = generateAppTextStyle(color: Colors.black87, fontSize: app.screenInfo.fontSize);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'Drums'),
      body: DefaultTextStyle(
        style: style,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _drums,
          PlayList(
            songList: SongList('DrumList label', tempDrumListItems, songItemAction: loadDrumListItem),
            style: style,
            isFromTheTop: false,
          ),
        ]),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.aboutBack),
    );
  }

  loadDrumListItem(BuildContext context, SongListItem songListItem) async {
    DrumParts drumParts = (songListItem as DrumListItem).drumParts;

    setState(() {
      _drums = DrumsWidget(key: UniqueKey(), drumParts: drumParts);
    });
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

  DrumsWidget _drums = DrumsWidget();
  late Size _lastSize;
}
