import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/key.dart' as songs;
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songUpdate.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../main.dart';

/// Display the application's privacy policy
class BassWidget extends StatefulWidget {
  const BassWidget({Key? key}) : super(key: key);

  @override
  _State createState() => _State();

  static final String routeName = '/bass';
}

class _State extends State<BassWidget> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    final double fontSize = screenInfo.isTooNarrow ? 16 : 24;

    TextStyle style = TextStyle(color: Colors.black87, fontSize: fontSize);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Bass Study Tool',
          style: TextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Text(
            'bass stuff here',
            style: style,
          ),
          ElevatedButton(
            child: Text(
              'test',
              style: style,
            ),
            onPressed: _test,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        tooltip: 'Back',
        child: Icon(Icons.arrow_back),
      ),
    );
  }

  void _test() async {
    logger.i('test was here');
    var songUpdate = SongUpdate();
    songUpdate.song = Song.createSong('A', 'bobby', 'bsteele.com', songs.Key.getDefault(), 106, 4, 4, 'bob',
        'i1: D D D D v: A B C D x4', 'i1: v: bob, bob, Barbara Anne');
    songUpdate.momentNumber = 0;
    selectedSong = songUpdate.song;
    Navigator.pushNamedAndRemoveUntil(
        context, Player.routeName, (route) => route.isFirst || route.settings.name == Player.routeName);
  }
}
