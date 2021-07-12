import 'dart:collection';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteele_music_flutter/app/appTextStyle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app.dart';

final _blue = Paint()..color = Colors.lightBlue.shade200;

/// Display the song moments in sequential order.
class Lists extends StatefulWidget {
  const Lists({Key? key}) : super(key: key);

  @override
  _State createState() => _State();
}

class _State extends State<Lists> {
  @override
  initState() {
    super.initState();

    logger.d("_Songs.initState()");
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = _app.screenInfo.fontSize;
    final metadataStyle = AppTextStyle(
      color: Colors.black87,
      fontSize: fontSize,
    );

    List<Widget> _metadataWidgets = [];
    {
      SplayTreeSet<NameValue> nameValues = SplayTreeSet();
      for (var songIdMetadata in SongMetadata.idMetadata) {
        for (var nameValue in songIdMetadata.nameValues) {
          nameValues.add(nameValue);
        }
      }
      for (var nameValue in nameValues) {
        if (nameValue.name == holidayMetadataNameValue.name) {
          continue;
        }
        _metadataWidgets.add(//Text()
            Wrap(
          children: [
            Checkbox(
              checkColor: Colors.white,
              fillColor: MaterialStateProperty.all(_blue.color),
              value: _nameValues.contains(nameValue),
              onChanged: (bool? value) {
                if (value != null) {
                  setState(() {
                    if (value) {
                      _nameValues.remove(nameValue);
                    } else {
                      _nameValues.add(nameValue);
                    }
                  });
                }
              },
            ),
            TextButton(
              child: Text(
                '${nameValue.name}:${nameValue.value}',
                style: metadataStyle,
              ),
              onPressed: () {
                setState(() {
                  if (_nameValues.contains(nameValue)) {
                    _nameValues.remove(nameValue);
                  } else {
                    _nameValues.add(nameValue);
                  }
                });
              },
            ),
            const SizedBox(
              width: 10,
            ),
          ],
        ));
      }
    }

    List<Widget> songWidgetList = [];
    {
      SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
      for (var nameValue in _nameValues) {
        var songIdMetadataSet = SongMetadata.where(nameIsLike: nameValue.name, valueIsLike: nameValue.value);
        for (var song in _app.allSongs) {
          for (var songIdMetadata in songIdMetadataSet) {
            if (songIdMetadata.id == song.songId.toString()) {
              _filteredSongs.add(song);
            }
          }
        }
      }
      songWidgetList = _filteredSongs.map((song) {
        return Text(
          '${song.title} by ${song.artist}'
              '${song.coverArtist.isNotEmpty ? ' cover by ${song.coverArtist}' : ''}',
          style: metadataStyle,
        );
      }).toList(growable: false);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'bsteele Music App Lists',
          style: AppTextStyle(color: Colors.black87, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(36.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ElevatedButton(
                child: Text(
                  'Save',
                  style: AppTextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() {});
                },
              ),
              const SizedBox(
                height: 20,
              ),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: _metadataWidgets,
              ),
             // ListView(children: songWidgetList,)
            ]),
      ),
    );
  }

  final SplayTreeSet<NameValue> _nameValues = SplayTreeSet();

  String fileLocation = kIsWeb ? 'download area' : 'Documents';
  final App _app = App();
}
