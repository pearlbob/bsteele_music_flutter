import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:logger/logger.dart';

import '../appOptions.dart';

/// Display the song moments in sequential order.
class Options extends StatefulWidget {
  const Options({Key key}) : super(key: key);

  @override
  _Options createState() => _Options();
}

class _Options extends State<Options> {

  @override
  initState() {
    super.initState();
  }

  void onPlayerChanged(bool value) {
    _appOptions.playerDisplay = value;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ScreenInfo screenInfo = ScreenInfo(context);
    double fontSize = screenInfo.isTooNarrow ? 18 : 36;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Music App Options',
          style: TextStyle(
              color: Colors.black87,
              fontSize: fontSize,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: DefaultTextStyle(
        style: TextStyle(color: Colors.black87, fontSize: fontSize),
        child: Container(
          padding: EdgeInsets.all(8.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Radio<bool>(
                      value: true,
                      groupValue: _appOptions.playerDisplay,
                      onChanged: onPlayerChanged,
                    ),
                    Text(
                      'Player',
                    ),
                    Radio<bool>(
                      value: false,
                      groupValue: _appOptions.playerDisplay,
                      onChanged: onPlayerChanged,
                    ),
                    Text(
                      'Singer',
                    ),
                  ],
                ),
                Row(children: <Widget>[
                  Checkbox(
                    value: _appOptions.debug,
                    onChanged: (value) {
                      _appOptions.debug = value;
                      Logger.level =
                          _appOptions.debug ? Level.debug : Level.info;
                      setState(() {});
                    },
                  ),
                  Text(
                    'debug: ',
                    // textScaleFactor: textScaleFactor,
                  ),
                ]),
              ]),
        ),
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

  final AppOptions _appOptions= AppOptions();
}
