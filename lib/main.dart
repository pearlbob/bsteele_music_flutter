import 'dart:html';
import 'dart:math';

import 'package:bsteele_music_flutter/player.dart';
import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'appLogger.dart';

void main() {
  Logger.level = Level.info;
  runApp(MyApp());
}

/*
project structure

packaging
deployment
websockets/server

MVC?
file io (web, android, ios)
file io (web write)
flutter on linux?
what is debugPrint

__software documentation
____.gitignore
____unit tests
____file io (web read)
__resources
__ui tables
__json
 */

List<Song> allSongs = List();
List<Song> songList = List();
Song selectedSong;

/// Display the list of songs to choose from.
class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bsteele Music',
      theme: ThemeData(
        primaryColor: Colors.lightBlue[300],
        scaffoldBackgroundColor: Colors.white,
      ),
      home: MyHomePage(title: 'bsteele Music'),

      // Start the app with the "/" named route. In this case, the app starts
      // on the FirstScreen widget.
      initialRoute: '/',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        //'/': (context) => MyApp(),
        // When navigating to the "/second" route, build the SecondScreen widget.
        '/player': (context) => Player(song:selectedSong),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of the application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  //  Fields in a Widget subclass are always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

void _processKeyboard(KeyboardEvent ke) {
  logger.d("processKeyboard: ${ke.key}");
  switch (ke.key) {
    case 'ArrowDown':
      logger.i("processKeyboard: down");
      break;
    case 'ArrowUp':
      logger.i("processKeyboard: up");
      break;
    case 'ArrowRight':
      logger.i("processKeyboard: right");
      break;
    case 'ArrowLeft':
      logger.i("processKeyboard: left");
      break;
  }
}

class _MyHomePageState extends State<MyHomePage> {
  _MyHomePageState()
      : _searchTextFieldController = TextEditingController(),
        _searchFocusNode = FocusNode() {
    _searchTextFieldController = TextEditingController();
    _searchTextField = TextField(
      controller: _searchTextFieldController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: "Enter search filter string here.",
      ),
      autofocus: true,
      style: new TextStyle(fontSize: 24),
      onChanged: (text) {
        logger.v('search text: "$text"');
        _searchSongs(text);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _readInternalSongList();

    window.onKeyDown.listen(_processKeyboard);
  }

  void _readInternalSongList() async {
    String songListAsString =
        await rootBundle.loadString('lib/assets/allSongs.songlyrics');

    try {
      allSongs = Song.songListFromJson(songListAsString);
      songList = allSongs;
      selectedSong = songList[0];
      setState(() {});
    } catch (fe) {
      logger.w("songList parse error: " + fe.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    List<StatelessWidget> listViewChildren = List();
    ScrollController _scrollController = new ScrollController();
    bool oddEven = false;

    double titleScaleFactor = max(1, MediaQuery.of(context).size.width / 800);
    double artistScaleFactor = 0.75 * titleScaleFactor;

    for (Song song in songList) {
      oddEven = !oddEven;
      listViewChildren.add(GestureDetector(
        child: Container(
            color: oddEven ? Colors.white : Colors.grey[100],
            child: ListTile(
              title: Text(
                song.getTitle(),
                textScaleFactor: titleScaleFactor,
              ),
              subtitle: Text(
                song.getArtist(),
                textScaleFactor: artistScaleFactor,
              ),
            )),
        onTap: () {
          _navigateToPlayer(context, song);
        },
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),

      /// Navigate to song player when song tapped.
      body: Column(children: <Widget>[
        _searchTextField,
        Expanded(
            child: Scrollbar(
          child: ListView(
            controller: _scrollController,
            children: listViewChildren,
          ),
        )),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            0.0,
            curve: Curves.easeOut,
            duration: const Duration(milliseconds: 800),
          );
        },
        tooltip: 'Back to the list top',
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }

  void _searchSongs(String search) {
    if (search == null) {
      search = "";
    }
    search = search.replaceAll("[^\\w\\s']+", "");
    search = search.toLowerCase();

    //  apply complexity filster
//    TreeSet<Song> allSongsFiltered = allSongs;
//    if (complexityFilter != ComplexityFilter.all) {
//      TreeSet<Song> sortedSongs = new TreeSet<>(Song.getComparatorByType(Song.ComparatorType.complexity));
//      sortedSongs.addAll(allSongs);
//      double factor = 1.0;
//      switch (complexityFilter) {
//        case veryEasy:
//          factor = 1.0 / 4;
//          break;
//        case easy:
//          factor = 2.0 / 4;
//          break;
//        case moderate:
//          factor = 3.0 / 4;
//          break;
//      }
//      int limit = (int) (factor * sortedSongs.size());
//      Song[] allSongsFilteredList = sortedSongs.toArray(new Song[0]);
//      allSongsFiltered = new TreeSet<>();
//      for (int i = 0; i < limit; i++)
//        allSongsFiltered.add(allSongsFilteredList[i]);
//    }

    //  apply search filter
    songList = List();
    for (Song song in allSongs) {
      if (search.length == 0 ||
          song.getTitle().toLowerCase().contains(search) ||
          song.getArtist().toLowerCase().contains(search)) {
        songList.add(song);
      }
    }
    setState(() {});
  }

  _navigateToPlayer(BuildContext context, Song song) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Player(song: song)),
    );

    //  select all text on a navigation pop
    _searchTextFieldController.selection = TextSelection(
        baseOffset: 0, extentOffset: _searchTextFieldController.text.length);
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  TextField _searchTextField;
  TextEditingController _searchTextFieldController;
  FocusNode _searchFocusNode;
}
