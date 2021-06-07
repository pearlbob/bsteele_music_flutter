import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/util/appTextStyle.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:intl/intl.dart';

import '../app/app.dart';

/// Display the song moments in sequential order.
class Songs extends StatefulWidget {
  const Songs({Key? key}) : super(key: key);

  @override
  _Songs createState() => _Songs();
}

class _Songs extends State<Songs> {
  @override
  initState() {
    super.initState();

    logger.d("_Songs.initState()");
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    final bool _isTooNarrow = screenInfo.isTooNarrow;

    const double defaultFontSize = 24;
    final double fontSize = defaultFontSize / (_isTooNarrow ? 2 : 1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Music App Songs',
          style: AppTextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(36.0),
        child: Wrap(
            direction: Axis.vertical, // make sure to set this
            spacing: 36,
            children: <Widget>[
              ElevatedButton(
                child: Text(
                  'Read files',
                  style: AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() {
                    _filePick(context);
                  });
                },
              ),
              ElevatedButton(
                child: Text(
                  'Write songs all to $fileLocation',
                  style: AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _writeAll();
                },
              ),
              ElevatedButton(
                child: Text(
                  'Remove all songs from the current list',
                  style: AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() {
                    App().removeAllSongs();
                  });
                },
              ),
              Text(
                _message ?? '',
                style: AppTextStyle(fontSize: fontSize),
              ),
              Text(
                'Song count:  ${App().allSongs.length}',
                style: AppTextStyle(fontSize: fontSize),
              ),
              Text(
                'Most recent: ${_mostRecent()}',
                style: AppTextStyle(fontSize: fontSize),
              ),
            ]),
      ),
    );
  }

  String _mostRecent() {
    App app = App();
    if (app.allSongs.isEmpty) {
      return 'empty list';
    }

    var lastModifiedTime = 0;
    for (var song in app.allSongs) {
      lastModifiedTime = max(lastModifiedTime, song.lastModifiedTime);
    }

    return DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(lastModifiedTime));
  }

  /// write all songs to the standard location
  void _writeAll() async {
    String fileName = 'allSongs_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songlyrics';
    String contents = Song.listToJson(App().allSongs.toList());
    UtilWorkaround().writeFileContents(fileName, contents);

    setState(() {
      _message = 'wrote file: $fileName to $fileLocation';
    });
  }

  void _filePick(BuildContext context) async {
    await UtilWorkaround().filePick(context);
    Navigator.pop(context);
  }

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
  String? _message;
}
