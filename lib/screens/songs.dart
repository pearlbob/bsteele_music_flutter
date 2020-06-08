import 'dart:ui';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:bsteele_music_flutter/util/songPick.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
          style: TextStyle(
              color: Colors.black87,
              fontSize: fontSize,
              fontWeight: FontWeight.bold),
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
                  style: TextStyle(
                      fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _filePick();
                },
              ),
              RaisedButton(
                child: Text(
                  'Write all',
                  style: TextStyle(
                      fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                },
              ),
            ]),
      ),
    );
  }

  void _filePick() async {
    await SongPick().filePick();
    Navigator.pop(context);
  }

//AppOptions _appOptions;
}
