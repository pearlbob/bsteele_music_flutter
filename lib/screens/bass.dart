import 'dart:math';

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

final _white = Paint()..color = Colors.white;
final _black = Paint()..color = Colors.black;
final _grey = Paint()..color = Colors.grey;
final _blue = Paint()..color = Colors.blue[200] ?? Colors.blue;

/// the bass study tool
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
          SizedBox(height: 10,),
          CustomPaint(
            painter: _FretBoardPainter(),
            isComplex: true,
            willChange: false,
            child: SizedBox(
              width: double.infinity,
              height: 200.0,
            ),
          ),
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

class _FretBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var width = size.width;
    var height = size.height;

    var margin = width * 0.1;
    bassFretX = margin;
    bassFretY = 0;
    bassFretHeight = height;
    bassScale = width - 2 * margin;

    //  clear the fretboard
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), _white);

    //  frets
    _black.strokeWidth = 2;
    {
      var fretYmin = bassFretY + bassFretHeight / 16;
      var fretYmax = bassFretY + bassFretHeight - bassFretHeight / 16;
      for (var fret = 0; fret <= 12; fret++) {
        _black.strokeWidth = fret == 0 ? 6 : 2;
        var x = fretLoc(fret);
        canvas.drawLine(Offset(x, fretYmin), Offset(x, fretYmax), _black);
      }
    }

    //  strings
    for (var s = 0; s < 4; s++) {
      _grey.strokeWidth = (4 - s) * 2;

      var y = bassFretY + bassFretHeight - bassFretHeight * s / 4 - bassFretHeight / 8;
      canvas.drawLine(Offset(bassFretX, y), Offset(bassFretX + bassScale, y), _grey);
    }

    //  markers
    _blue.strokeWidth = 3;
    double radius = 10;
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset((fretLoc(2 + 2 * i) + fretLoc(2 + 2 * i + 1)) / 2, bassFretY + bassFretHeight / 2),
              width: 2 * radius,
              height: 2 * radius),
          0,
          2 * pi,
          true,
          _blue);
    }
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset((fretLoc(11) + fretLoc(12)) / 2, bassFretY + bassFretHeight / 4),
            width: 2 * radius,
            height: 2 * radius),
        0,
        2 * pi,
        true,
        _blue);
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset((fretLoc(11) + fretLoc(12)) / 2, bassFretY + bassFretHeight * 3 / 4),
            width: 2 * radius,
            height: 2 * radius),
        0,
        2 * pi,
        true,
        _blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; //  fixme optimize?
  }

  double fretLoc(n) {
    if (n < 0) {
      n = 0;
    }
    return bassFretX + 2 * (bassScale - ((bassScale / pow(2, n / 12))));
  }

  double bassFretHeight = 200;
   double bassFretY = 0;
  double bassFretX = 63;
  double bassScale = 2000;
}
