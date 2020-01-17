import 'package:bsteele_music_flutter/songs/Key.dart' as songs;
import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Display the song moments in sequential order.
class Edit extends StatefulWidget {
  const Edit({Key key, @required this.song}) : super(key: key);

  @override
  _Edit createState() => _Edit();

  final Song song;
}

class _Edit extends State<Edit> {
  @override
  initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Song song = widget.song;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.ltr,
            children: <Widget>[
              AppBar(
                //  let the app bar scroll off the screen for more room for the song
                title: Text(
                  'Edit',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                centerTitle: true,
              ),
              Text(
                '${song.title}',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              Text(
                ' by  ${song.artist}',
              ),
              Row(
                children: <Widget>[
                  Text(
                    "Key: ",
                  ),
                  DropdownButton<songs.Key>(
                    items: songs.Key.values.toList().reversed.map((songs.Key value) {
                      return new DropdownMenuItem<songs.Key>(
                        key: ValueKey(value.getHalfStep()),
                        value: value,
                        child: new Text(
                          '${value.toString()} ${value.sharpsFlatsToString()}',
                        ),
                      );
                    }).toList(),
                    onChanged: (_value) {
                      setState(() {
                        _key = _value;
                      });
                    },
                    value: _key,
                    style: TextStyle(
                      //  size controlled by textScaleFactor above
                      color: Colors.black87,
                      textBaseline: TextBaseline.ideographic,
                    ),
                  ),
                  Text(
                    "   BPM: ${song.getBeatsPerMinute()}" +
                        "  Time: ${song.beatsPerBar}/${song.unitsPerMeasure}",
                  ),
                ],
              ),
            ]),
      ),
    );
  }

  songs.Key _key = songs.Key.get(songs.KeyEnum.C);
}

