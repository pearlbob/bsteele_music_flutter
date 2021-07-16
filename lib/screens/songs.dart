import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/app/appButton.dart';
import 'package:bsteele_music_flutter/app/appTextStyle.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

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

    _app.clearMessage();
    logger.d("_Songs.initState()");
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = _app.screenInfo.fontSize;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: appBackBar('bsteele Music App Song Management', context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                child: Text(
                  'Write all songs to $fileLocation',
                  style: AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _writeAll();
                },
              ),
              const SizedBox(
                height: 20,
              ),
              appTooltip(
                message: 'A reload of the application will return them all.',
                child: ElevatedButton(
                  child: Text(
                    'Remove all songs from the current list',
                    style: AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    setState(() {
                      _app.removeAllSongs();
                    });
                  },
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              _app.messageTextWidget(),
              const SizedBox(
                height: 20,
              ),
              Text(
                'Song count:  ${_app.allSongs.length}',
                style: AppTextStyle(fontSize: fontSize),
              ),
              Text(
                'Most recent: ${_mostRecent()}',
                style: AppTextStyle(fontSize: fontSize),
              ),
            ]),
      ),
      floatingActionButton: appFloatingBack(context),
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

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
  final App _app = App();
}
