import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/app_theme.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../app/app.dart';

/// Provide a number of song related actions for the user.
/// This includes reading song files, clearing all songs from the current song list, and the like.
class Songs extends StatefulWidget {
  const Songs({Key? key}) : super(key: key);

  @override
  _Songs createState() => _Songs();
}

class _Songs extends State<Songs> {
  @override
  initState() {
    super.initState();

    app.clearMessage();
    logger.d("_Songs.initState()");
  }

  @override
  Widget build(BuildContext context) {
    appWidgetHelper = AppWidgetHelper(context);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      appBar: appWidgetHelper.backBar(title: 'bsteele Music App Song Management'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              appEnumeratedButton(
                'Read files',
                appKeyEnum: AppKeyEnum.songsReadFiles,
                onPressed: () {
                  setState(() {
                    _filePick(context);
                  });
                },
              ),
              appSpace(
                space: 20,
              ),
              appEnumeratedButton(
                'Write all songs to $fileLocation',
                appKeyEnum: AppKeyEnum.songsWriteFiles,
                onPressed: () {
                  _writeAll();
                },
              ),
              appSpace(
                space: 20,
              ),
              appTooltip(
                message: 'A reload of the application will return them all.',
                child: appEnumeratedButton(
                  'Remove all songs from the current list',
                  appKeyEnum: AppKeyEnum.songsRemoveAll,
                  onPressed: () {
                    setState(() {
                      app.removeAllSongs();
                    });
                  },
                ),
              ),
              appSpace(
                space: 20,
              ),
              app.messageTextWidget(),
              appSpace(
                space: 20,
              ),
              Text(
                'Song count:  ${app.allSongs.length}',
                style: generateAppTextStyle(),
              ),
              Text(
                'Most recent: ${_mostRecent()}',
                style: generateAppTextStyle(),
              ),
            ]),
      ),
      floatingActionButton: appWidgetHelper.floatingBack(AppKeyEnum.songsBack),
    );
  }

  String _mostRecent() {
    if (app.allSongs.isEmpty) {
      return 'empty list';
    }

    var lastModifiedTime = 0;
    for (var song in app.allSongs) {
      lastModifiedTime = max(lastModifiedTime, song.lastModifiedTime);
    }

    return intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(lastModifiedTime));
  }

  /// write all songs to the standard location
  void _writeAll() async {
    String fileName = 'allSongs_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songlyrics';
    String contents = Song.listToJson(app.allSongs.toList());
    UtilWorkaround().writeFileContents(fileName, contents);

    setState(() {
      app.infoMessage('wrote file: $fileName to $fileLocation folder');
    });
  }

  void _filePick(BuildContext context) async {
    await UtilWorkaround().songFilePick(context);
    Navigator.pop(context);
  }

  late AppWidgetHelper appWidgetHelper;

  String fileLocation = kIsWeb ? 'download folder in local drive' : 'Documents';
  final App app = App();
}
