// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as webFile;
import 'dart:io';
import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:bsteele_music_flutter/util/songPick.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';

/// Display the song moments in sequential order.
class Songs extends StatefulWidget {
  const Songs({Key key}) : super(key: key);

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
          style: TextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        padding: EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              RaisedButton(
                child: Text(
                  'Read files',
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _filePick();
                },
              ),
              RaisedButton(
                child: Text(
                  'Write all',
                  style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _writeAll();
                },
              ),
              Text(
                _message ?? '',
                style: TextStyle(fontSize: fontSize),
              ),
            ]),
      ),
    );
  }

  /// write all songs to the standard location
  void _writeAll() async {
    String fileName = 'allSongs_${intl.DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.songlyrics';
    if (kIsWeb) {
      //  web stuff
      var blob = webFile.Blob([Song.listToJson(allSongs.toList())], 'text/plain', 'native');

      var anchorElement = webFile.AnchorElement(
        href: webFile.Url.createObjectUrlFromBlob(blob).toString(),
      )
        ..setAttribute("download", fileName)
        ..click();
      setState(() {
        _message = 'wrote file: $fileName to download area';
      });
    } else {
      //  not web stuff
      final directory = await getApplicationDocumentsDirectory();
      String path = directory.path;
      logger.d('path: $path');

      File file = File('$path/$fileName');
      logger.d('file: $file');
      await file.writeAsString(Song.listToJson(allSongs.toList()), flush: true);

      setState(() {
        _message = 'wrote file: ${file.path}';
      });
    }
  }

  void _filePick() async {
    await SongPick().filePick();
    Navigator.pop(context);
  }

  String _message;
}
