import 'dart:collection';

import 'package:bsteeleMusicLib/app_logger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/song_performance.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:string_similarity/string_similarity.dart';

import '../app/app.dart';

/// Provide a number of song related actions for the user.
/// This includes reading song files, clearing all songs from the current song list, and the like.
class PerformanceHistory extends StatefulWidget {
  const PerformanceHistory({Key? key}) : super(key: key);

  @override
  PerformanceHistoryState createState() => PerformanceHistoryState();

  static const String routeName = 'history';
}

class PerformanceHistoryState extends State<PerformanceHistory> {
  @override
  initState() {
    super.initState();

    app.clearMessage();
    logger.d("_PerformanceHistory.initState()");
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);
    app.screenInfo.refresh(context);

    final double fontSize = app.screenInfo.fontSize;
    _songPerformanceStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

    SplayTreeSet<SongPerformance> performanceHistory = SplayTreeSet((SongPerformance first, SongPerformance other) {
      // reverse the date ordering
      return -SongPerformance.compareByLastSungSongIdAndSinger(first, other);
    });
    performanceHistory.addAll(allSongPerformances.allSongPerformanceHistory);
    PlayListGroup songListGroup;
    {
      List<PlayListItemList> songLists = [];
      String lastSungDateString = '';
      int lastSung = 0;
      List<PlayListItem> items = [];
      for (var performance in performanceHistory) {
        logger.v('perf: ${performance.performedSong.title}, sung: ${performance.lastSungDateString}');
        if (lastSungDateString != performance.lastSungDateString) {
          if (items.isNotEmpty) {
            songLists.add(PlayListItemList(
                DateFormat.yMd().add_EEEE().format(DateTime.fromMillisecondsSinceEpoch(lastSung)), items,
                playListItemAction: _navigateSongListToPlayer));
            items = [];
          }
          lastSungDateString = performance.lastSungDateString;
          lastSung = performance.lastSung;
        }
        items.add(SongPlayListItem.fromPerformance(
          performance,
        ));
      }
      if (items.isNotEmpty) {
        songLists.add(PlayListItemList(
            DateFormat.yMd().add_EEEE().format(DateTime.fromMillisecondsSinceEpoch(lastSung)), items,
            playListItemAction: _navigateSongListToPlayer));
      }

      // songListGroup: SongList(
      //   '', allSongPerformances.allSongPerformanceHistory.map((e) => PlayListItem.fromPerformance(e)).toList(growable: false),
      //   songItemAction: _navigateSongListToPlayer,
      // ),
      songListGroup = PlayListGroup(songLists);
    }

      return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: appWidgetHelper.backBar(title: 'Community Jams Performance History'),
        body: Container(
          padding: const EdgeInsets.all(36.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
              PlayList.byGroup(songListGroup,
                  style: _songPerformanceStyle, includeByLastSung: true, selectedSortType: PlayListSortType.byHistory),

              // const AppSpace(),
                Text(
                  'Performance count:  ${performanceHistory.length}',
                style: generateLyricsTextStyle().copyWith(fontSize: app.screenInfo.fontSize * 0.75),
              ),
              ]),
        ),
        floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.performanceHistoryBack),
      );
  }

  Song bestSongMatch(SongPerformance performance) {
    //  fixme: performance
    BestMatch bestMatch = StringSimilarity.findBestMatch(
        performance.songIdAsString, app.allSongs.map((song) => song.songId.toString()).toList(growable: false));

    logger.d('${performance.songIdAsString}:  ${bestMatch.bestMatch.target}   ${bestMatch.bestMatch.rating}');
    return app.allSongs.firstWhere((song) => song.songId.toString() == bestMatch.bestMatch.target, //
        orElse: () {
      return Song.theEmptySong;
    });
  }

  _navigateSongListToPlayer(BuildContext context, PlayListItem playListItem) async {
    app.clearMessage();

    if (playListItem is SongPlayListItem && playListItem.songPerformance != null) {
      var songPerformance = playListItem.songPerformance!;
      app.selectedSong = songPerformance.performedSong;
      logger.v('navigateToPlayer: $songPerformance');
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Player(
                  app.selectedSong,
                  //  adjust song to singer's last performance
                  musicKey: songPerformance.key,
                  bpm: songPerformance.bpm,
                  singer: songPerformance.singer,
                )),
      );
    }
  }

  late AppWidgetHelper appWidgetHelper;
  late TextStyle _songPerformanceStyle;

  final App app = App();
  final AllSongPerformances allSongPerformances = AllSongPerformances();
}
