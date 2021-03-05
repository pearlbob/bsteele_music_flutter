
import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteele_music_flutter/main.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/utilWorkaround.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

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
          style: TextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Container(
        padding: EdgeInsets.all(36.0),
        child: Wrap(
            direction: Axis.vertical, // make sure to set this
            spacing: 36,
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
                  'Write songs all to $fileLocation',
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
    String contents = Song.listToJson(allSongs.toList());
    UtilWorkaround().writeFileContents(fileName, contents);

    setState(() {
      _message = 'wrote file: $fileName to $fileLocation';
    });
  }

  void _filePick() async {
    await UtilWorkaround().filePick();
    Navigator.pop(context);
  }

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
  String? _message;
}
