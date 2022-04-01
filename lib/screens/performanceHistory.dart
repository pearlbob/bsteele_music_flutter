import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
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
  _PerformanceHistory createState() => _PerformanceHistory();

  static const String routeName = '/history';
}

class _PerformanceHistory extends State<PerformanceHistory> {
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

    List<Widget> history = [];
    {
      _songSearchMatcher = SongSearchMatcher(_searchTextFieldController.text);
      String? lastSungDateString;

      for (var perf in searchAllPerformanceSongs().toList(growable: false).reversed) {
        var song = perf.song;
        if (song == null) {
          continue;
        }

        if (lastSungDateString != perf.lastSungDateString) {
          lastSungDateString = perf.lastSungDateString;
          history.add(appSpace(verticalSpace: 20));
          history.add(Text(
            lastSungDateString,
            style: _songPerformanceStyle,
          ));
          history.add(const Divider(
            thickness: 10,
            color: Colors.black,
          ));
        }

        var singer = perf.singer;
        var key = perf.key;
        // var bpm = perf.bpm;
        history.add(appWrapFullWidth(children: [
          TextButton(
              child: Text(
                DateFormat.jm().format(DateTime.fromMillisecondsSinceEpoch(perf.lastSung)) +
                    ' $singer sang: '
                        '${song.title} by ${song.artist}'
                        '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}'
                        ' in $key'
                // ' at $bpm'
                ,
                style: _songPerformanceStyle,
              ),
              onPressed: () {
                setState(() {
                  _navigateToPlayer(context, perf);
                });
              }),
        ], spacing: 10));
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'Community Jams Performance History'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (app.message.isNotEmpty) app.messageTextWidget(AppKeyEnum.performanceHistoryErrorMessage),
              appWrapFullWidth(children: [
                //  search line
                appTooltip(
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
                  child: appTextField(
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
                appTooltip(
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
              appSpace(),
              ...history,
              appSpace(),
              Text(
                'Performance count:  ${allSongPerformances.allSongPerformanceHistory.length}',
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
