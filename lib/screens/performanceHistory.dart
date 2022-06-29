import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/songId.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app.dart';
import '../util/songSearchMatcher.dart';

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
    _songSearchMatcher = SongSearchMatcher(_searchTextFieldController.text);
    performanceHistory.addAll(searchAllPerformanceSongs());

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'Community Jams Performance History'),
      body: Container(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (app.message.isNotEmpty) app.messageTextWidget(AppKeyEnum.performanceHistoryErrorMessage),
              AppWrapFullWidth(children: [
                //  search line
                AppTooltip(
                  message: 'Search for songs',
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    iconSize: fontSize,
                    onPressed: (() {}),
                  ),
                ),
                SizedBox(
                  width: 20 * fontSize,
                  //  limit text entry display length
                  child: AppTextField(
                    appKeyEnum: AppKeyEnum.singersSearchText,
                    enabled: true,
                    controller: _searchTextFieldController,
                    hintText: 'enter song search',
                    onChanged: (text) {
                      setState(() {});
                    },
                    fontSize: fontSize,
                  ),
                ),
                AppTooltip(
                  message: 'Clear the search text',
                  child: appEnumeratedIconButton(
                    appKeyEnum: AppKeyEnum.singersClearSearch,
                    icon: const Icon(Icons.clear),
                    iconSize: 1.5 * fontSize,
                    onPressed: (() {
                      setState(() {
                        searchClear();
                        FocusScope.of(context).requestFocus(_searchFocusNode);
                      });
                    }),
                  ),
                ),
              ]),
              const AppSpace(),
              Flexible(
                child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: performanceHistory.length,
                    itemBuilder: (BuildContext context, int index) {
                      var performance = performanceHistory.elementAt(index);
                      var singer = performance.singer;
                      var song = performance.song;
                      var title = (song != null
                          ? '${song.title} by ${song.artist}'
                              '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}'
                          : '${SongId.asReadableString(performance.songIdAsString)} (missing)');
                      var key = performance.key;

                      return AppWrapFullWidth(children: [
                        if (index == 0 ||
                            (index > 0 &&
                                performance.lastSungDateString !=
                                    performanceHistory.elementAt(index - 1).lastSungDateString))
                          AppWrapFullWidth(children: [
                            const AppSpace(verticalSpace: 40),
                            Text(
                              performance.lastSungDateString,
                              style: _songPerformanceStyle.copyWith(color: appBackgroundColor()),
                            ),
                            Divider(
                              thickness: 10,
                              color: appBackgroundColor(),
                            )
                          ]),
                        TextButton(
                            style: const ButtonStyle(alignment: Alignment.topLeft),
                            child: Text(
                              //'${performance.lastSungDateString}'
                              ' ${DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(performance.lastSung))}'
                              ' $singer sang: $title'
                              ' in $key'
                              // ' at $bpm'
                              ,
                              style: _songPerformanceStyle,
                            ),
                            onPressed: () {
                              setState(() {
                                _navigateToPlayer(context, performance);
                              });
                            }),
                      ]);
                    }),
              ),
              //     ...history,
              const AppSpace(),
              Text(
                'Performance count:  ${performanceHistory.length}',
                style: generateAppTextStyle(),
              ),
            ]),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.performanceHistoryBack),
    );
  }

  void searchClear() {
    _searchTextFieldController.clear();
    _songSearchMatcher = SongSearchMatcher(_searchTextFieldController.text);
  }

  SplayTreeSet<SongPerformance> searchAllPerformanceSongs() {
    //  apply search filter
    final SplayTreeSet<SongPerformance> filteredSongPerformances =
        SplayTreeSet(SongPerformance.compareByLastSungSongIdAndSinger);
    for (final SongPerformance songPerformance in allSongPerformances.allSongPerformanceHistory) {
      if (_songSearchMatcher.performanceMatchesOrEmptySearch(songPerformance)) {
        filteredSongPerformances.add(songPerformance);
      }
    }
    return filteredSongPerformances;
  }

  _navigateToPlayer(BuildContext context, SongPerformance songPerformance) async {
    if (songPerformance.song == null) {
      return;
    }
    app.clearMessage();
    app.selectedSong = songPerformance.song!;

    logger.d('navigateToPlayer.playerSelectedBpm out: ${songPerformance.bpm}');
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Player(
                songPerformance.song!,
                //  adjust song to singer's last performance
                musicKey: songPerformance.key,
                bpm: songPerformance.bpm,
                singer: songPerformance.singer,
              )),
    );
  }

  SongSearchMatcher _songSearchMatcher = SongSearchMatcher('');
  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late AppWidgetHelper appWidgetHelper;
  late TextStyle _songPerformanceStyle;

  final App app = App();
  final AllSongPerformances allSongPerformances = AllSongPerformances();
}
