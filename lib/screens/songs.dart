import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
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

    _app.clearMessage();
    logger.d("_Songs.initState()");
  }

  @override
  Widget build(BuildContext context) {
    appWidget.context = context; //	required on every build

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appWidget.backBar(title:'bsteele Music App Song Management'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              appButton(
             'Read files',
                onPressed: () {
                  setState(() {
                    _filePick(context);
                  });
                },
              ),
              appSpace(
                space: 20,
              ),
             appButton(
               'Write all songs to $fileLocation',
                onPressed: () {
                  _writeAll();
                },
              ),
              appSpace(
                space: 20,
              ),
              appTooltip(
                message: 'A reload of the application will return them all.',
                child: appButton( 'Remove all songs from the current list',
                  onPressed: () {
                    setState(() {
                      _app.removeAllSongs();
                    });
                  },
                ),
              ),
              appSpace(
                space: 20,
              ),
              _app.messageTextWidget(),
              appSpace(
                space: 20,
              ),
              Text(
                'Song count:  ${_app.allSongs.length}',
                style: generateAppTextStyle(),
              ),
              Text(
                'Most recent: ${_mostRecent()}',
                style: generateAppTextStyle(),
              ),
            ]),
      ),
      floatingActionButton: appWidget.floatingBack(),
    );
  }

  String _mostRecent() {
    if (_app.allSongs.isEmpty) {
      return 'empty list';
    }

    var lastModifiedTime = 0;
    for (var song in _app.allSongs) {
      lastModifiedTime = max(lastModifiedTime, song.lastModifiedTime);
    }

    return intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(lastModifiedTime));
  }

  /// write all songs to the standard location
  void _writeAll() async {
    String fileName = 'allSongs_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songlyrics';
    String contents = Song.listToJson(_app.allSongs.toList());
    UtilWorkaround().writeFileContents(fileName, contents);

    setState(() {
      _app.infoMessage('wrote file: $fileName to $fileLocation folder');
    });
  }

  void _filePick(BuildContext context) async {
    await UtilWorkaround().songFilePick(context);
    Navigator.pop(context);
  }

  final AppWidget appWidget = AppWidget();

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
  final App _app = App();
}
