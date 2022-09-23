import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:string_similarity/string_similarity.dart';

import '../app/app.dart';

/// Provide a number of song related actions for the user.
/// This includes reading song files, clearing all songs from the current song list, and the like.
class PerformanceHistory extends StatefulWidget {
  const PerformanceHistory({Key? key}) : super(key: key);

  @override
  PerformanceHistoryState createState() => PerformanceHistoryState();

  static const String routeName = '/history';
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
    SongListGroup songListGroup;
    {
      List<SongList> songLists = [];
      String lastSungDateString = '';
      int lastSung = 0;
      List<SongListItem> items = [];
      for (var performance in performanceHistory) {
        logger.v('perf: ${performance.performedSong.title}, sung: ${performance.lastSungDateString}');
        if (lastSungDateString != performance.lastSungDateString) {
          if (items.isNotEmpty) {
            songLists.add(SongList(
                DateFormat.yMd().add_EEEE().format(DateTime.fromMillisecondsSinceEpoch(lastSung)), items,
                songItemAction: _navigateSongListToPlayer));
            items = [];
          }
          lastSungDateString = performance.lastSungDateString;
          lastSung = performance.lastSung;
        }
        items.add(SongListItem.fromPerformance(
          performance,
        ));
      }
      if (items.isNotEmpty) {
        songLists.add(SongList(DateFormat.yMd().add_EEEE().format(DateTime.fromMillisecondsSinceEpoch(lastSung)), items,
            songItemAction: _navigateSongListToPlayer));
      }

      // songListGroup: SongList(
      //   '', allSongPerformances.allSongPerformanceHistory.map((e) => SongListItem.fromPerformance(e)).toList(growable: false),
      //   songItemAction: _navigateSongListToPlayer,
      // ),
      songListGroup = SongListGroup(songLists);
    }

    return Provider<PlayListRefresh>(create: (BuildContext context) {
      return PlayListRefresh(() {
        setState(() {
          logger.v('PerformanceHistory PlayList: PlayListRefresh()');
        });
      });
    }, builder: (context, child) {
      return Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: appWidgetHelper.backBar(title: 'Community Jams Performance History'),
        body: Container(
          padding: const EdgeInsets.all(36.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PlayList.byGroup(songListGroup, style: _songPerformanceStyle, includeByLastSung: true),
                // if (app.message.isNotEmpty) app.messageTextWidget(AppKeyEnum.performanceHistoryErrorMessage),
                // AppWrapFullWidth(children: [
                //   //  search line
                //   AppTooltip(
                //     message: 'Search for songs',
                //     child: IconButton(
                //       icon: const Icon(Icons.search),
                //       iconSize: fontSize,
                //       onPressed: (() {}),
                //     ),
                //   ),
                //   SizedBox(
                //     width: 20 * fontSize,
                //     //  limit text entry display length
                //     child: AppTextField(
                //       appKeyEnum: AppKeyEnum.singersSearchText,
                //       enabled: true,
                //       controller: _searchTextFieldController,
                //       hintText: 'enter song search',
                //       onChanged: (text) {
                //         setState(() {});
                //       },
                //       fontSize: fontSize,
                //     ),
                //   ),
                //   AppTooltip(
                //     message: 'Clear the search text',
                //     child: appEnumeratedIconButton(
                //       appKeyEnum: AppKeyEnum.singersClearSearch,
                //       icon: const Icon(Icons.clear),
                //       iconSize: 1.5 * fontSize,
                //       onPressed: (() {
                //         setState(() {
                //           searchClear();
                //           FocusScope.of(context).requestFocus(_searchFocusNode);
                //         });
                //       }),
                //     ),
                //   ),
                // ]),
                // const AppSpace(),
                // Flexible(
                //   child: ListView.builder(
                //       scrollDirection: Axis.vertical,
                //       shrinkWrap: true,
                //       padding: const EdgeInsets.all(8),
                //       itemCount: performanceHistory.length,
                //       itemBuilder: (BuildContext context, int index) {
                //         var performance = performanceHistory.elementAt(index);
                //         var singer = performance.singer;
                //         bool missing = performance.song == null;
                //         var song = performance.song ?? bestSongMatch(performance);
                //         var title = '${song.title} by ${song.artist}'
                //             '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}'
                //             '${missing ? ' (a match?)' : ''}';
                //         var key = performance.key;
                //
                //         return AppWrapFullWidth(children: [
                //           if (index == 0 ||
                //               (index > 0 &&
                //                   performance.lastSungDateString !=
                //                       performanceHistory.elementAt(index - 1).lastSungDateString))
                //             AppWrapFullWidth(children: [
                //               const AppSpace(verticalSpace: 40),
                //               Text(
                //                 DateFormat.yMd()
                //                     .add_EEEE()
                //                     .format(DateTime.fromMillisecondsSinceEpoch(performance.lastSung)),
                //                 style: _songPerformanceStyle.copyWith(color: appBackgroundColor()),
                //               ),
                //               Divider(
                //                 thickness: 10,
                //                 color: appBackgroundColor(),
                //               )
                //             ]),
                //           TextButton(
                //               style: const ButtonStyle(alignment: Alignment.topLeft),
                //               child: Text(
                //                 //'${performance.lastSungDateString}'
                //                 ' ${DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(performance.lastSung))}'
                //                 ' $singer sang: $title'
                //                 ' in $key'
                //                 // ' at $bpm'
                //                 ,
                //                 style: _songPerformanceStyle,
                //               ),
                //               onPressed: () {
                //                 setState(() {
                //                   _navigateToPlayer(context, performance, matchingSong: song);
                //                 });
                //               }),
                //         ]);
                //       }),
                // ),
                // //     ...history,
                // const AppSpace(),
                Text(
                  'Performance count:  ${performanceHistory.length}',
                  style: generateAppTextStyle(),
                ),
              ]),
        ),
        floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.performanceHistoryBack),
      );
    });
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

  _navigateSongListToPlayer(BuildContext context, SongListItem songListItem) async {
    app.clearMessage();

    if (songListItem.songPerformance != null) {
      var songPerformance = songListItem.songPerformance!;
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
