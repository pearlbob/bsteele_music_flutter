import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/intl.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';

import '../app/app.dart';

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
    songPerformanceStyle = generateAppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

    List<Widget> history = [];
    {
      var lastSungDateString;
      for (var perf in allSongPerformances.allSongPerformanceHistory.toList(growable: false).reversed) {
        var song = perf.song;
        if (song == null) {
          continue;
        }

        if (lastSungDateString != perf.lastSungDateString) {
          lastSungDateString = perf.lastSungDateString;
          history.add(appSpace(verticalSpace: 20));
          history.add(Text(
            lastSungDateString,
            style: songPerformanceStyle,
          ));
          history.add(const Divider(
            thickness: 10,
            color: Colors.black,
          ));
        }

        var singer = perf.singer;
        var key = perf.key;
        var bpm = perf.bpm;
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
                style: songPerformanceStyle,
              ),
              onPressed: () {
                setState(() {
                  _navigateToPlayer(context, perf.song);
                });
              }),
        ], spacing: 10));
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Performance History'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              app.messageTextWidget(AppKeyEnum.performanceHistoryErrorMessage),
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

  _navigateToPlayer(BuildContext context, Song? song) async {
    if (song == null || song.getTitle().isEmpty) {
      return;
    }
    app.clearMessage();
    app.selectedSong = song;
    await Navigator.pushNamed(
      context,
      Player.routeName,
    );
  }

  late AppWidgetHelper appWidgetHelper;
  late TextStyle songPerformanceStyle;

  final App app = App();
  final AllSongPerformances allSongPerformances = AllSongPerformances();
}