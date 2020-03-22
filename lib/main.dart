import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/Song.dart';
import 'package:bsteele_music_flutter/screens/about.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/options.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/screens/privacy.dart';
import 'package:bsteele_music_flutter/screens/songs.dart';
import 'package:bsteele_music_flutter/util/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import 'appOptions.dart';
import 'util/openLink.dart';

void main() {
  Logger.level = Level.info;

  runApp(MyApp());
}

/*
websockets/server

C's ipad: model ML0F2LL/A

flutter on linux?
what is debugPrint
 */

void addSong(Song song) {
  print('addSong( ${song.toString()} )');
  _allSongs.add(song);
  _filteredSongs = null;
  _selectedSong = song;
}

SplayTreeSet<Song> _allSongs = SplayTreeSet();
SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
Song _selectedSong;

final Color _primaryColor = Colors.lightBlue[300];

/// Display the list of songs to choose from.
class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bsteele Music App',
      theme: ThemeData(
        primaryColor: _primaryColor,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: MyHomePage(title: 'bsteele Music App'),

      // Start the app with the "/" named route. In this case, the app starts
      // on the FirstScreen widget.
      initialRoute: '/',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        //'/': (context) => MyApp(),
        // When navigating to the "/second" route, build the SecondScreen widget.
        '/player': (context) => Player(song: _selectedSong),
        '/songs': (context) => Songs(),
        '/options': (context) => Options(),
        '/edit': (context) => Edit(song: _selectedSong),
        '/privacy': (context) => Privacy(),
        '/about': (context) => About(),
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

class _MyHomePageState extends State<MyHomePage> {
  _MyHomePageState()
      : _searchTextFieldController = TextEditingController(),
        _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _appOptionsInit();
    _readExternalSongList();
  }

  /// initialize async options read from shared preferences
  void _appOptionsInit() async {
    await AppOptions().init();
  }

  void _readInternalSongList() async {
    String songListAsString = await rootBundle.loadString('lib/assets/allSongs.songlyrics');

    try {
      _allSongs = SplayTreeSet();
      _allSongs.addAll(Song.songListFromJson(songListAsString));
      _filteredSongs = _allSongs;
      _selectedSong = _filteredSongs.first;
      setState(() {});
      print("internal songList used");
    } catch (fe) {
      print("internal songList parse error: " + fe.toString());
    }
  }

  void _readExternalSongList() async {
    const String url = 'http://www.bsteele.com/bsteeleMusicApp/allSongs.songlyrics';

    String allSongsAsString;
    try {
      allSongsAsString = await fetchString(url);
    } catch (e) {
      print("read of url: '$url' failed: ${e.toString()}");
      _readInternalSongList();
      return;
    }

    try {
      _allSongs = SplayTreeSet();
      _allSongs.addAll(Song.songListFromJson(allSongsAsString));
      _filteredSongs = _allSongs;
      _selectedSong = _filteredSongs.first;
      setState(() {});
      print("external songList read from: " + url);
    } catch (fe) {
      print("external songList parse error: " + fe.toString());
      _readInternalSongList();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<StatelessWidget> listViewChildren = List();
    ScrollController _scrollController = new ScrollController();
    bool oddEven = false;

    ScreenInfo screenInfo = ScreenInfo(context);
    final double mediaWidth = screenInfo.mediaWidth;
    final bool _isTooNarrow = screenInfo.isTooNarrow;
    final double titleScaleFactor = screenInfo.titleScaleFactor;
    final double artistScaleFactor = screenInfo.artistScaleFactor;

    //  re-search filtered list on data changes
    if (_filteredSongs == null) {
      _searchTextFieldController.text = "";
      _searchSongs(_searchTextFieldController.text);
    }

    for (Song song in _filteredSongs) {
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

    const double defaultFontSize = 48;
    double fontSize = defaultFontSize / (_isTooNarrow ? 2 : 1);
    final TextStyle _navTextStyle = TextStyle(fontSize: fontSize, color: Colors.grey[800]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          new Tooltip(
            message: "Visit bsteele.com, the provider of this app.",
            child: InkWell(
              onTap: () {
                openLink('http://www.bsteele.com');
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Image(
                  image: AssetImage('lib/assets/runningMan.png'),
                  width: fontSize,
                  height: fontSize,
                  semanticLabel: "bsteele.com website",
                ),
              ),
            ),
          ),
          if (!_isTooNarrow) //  sorry CJ
            new Tooltip(
              message: "Visit Community Jams, the motivation and main user for this app.",
              child: InkWell(
                onTap: () {
                  openLink('http://communityjams.org');
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Image(
                    image: AssetImage('lib/assets/cjLogo.png'),
                    width: fontSize,
                    height: fontSize,
                    semanticLabel: "community jams",
                  ),
                ),
              ),
            ),
        ],
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.all(4.0),
          children: <Widget>[
            Container(
              height: 50,
            ), //  filler for notched phones
            ListTile(
              title: Text(
                "Songs",
                style: _navTextStyle,
              ),
              onTap: () {
                _navigateToSongs(context);
              },
            ),
            ListTile(
              title: Text(
                "Options",
                style: _navTextStyle,
              ),
              onTap: () {
                _navigateToOptions(context);
              },
            ),
            if (!_isTooNarrow) //  no edits on phones!
              ListTile(
                title: Text(
                  "Edit",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToEdit(context, _selectedSong);
                },
              ),
            ListTile(
              title: Text(
                "Privacy",
                style: _navTextStyle,
              ),
              //trailing: Icon(Icons.arrow_forward),
              onTap: () {
                _navigateToPrivacyPolicy(context);
              },
            ),
            ListTile(
              title: Text(
                "About",
                style: _navTextStyle,
              ),
              //trailing: Icon(Icons.arrow_forward),
              onTap: () {
                _navigateToAbout(context);
              },
            ),
          ],
        ),
      ),

      /// Navigate to song player when song tapped.
      body: Column(children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Row(children: <Widget>[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  width: min(mediaWidth / 2, 20 * fontSize),
                  //  limit text entry display length
                  child: TextField(
                    controller: _searchTextFieldController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: "Enter search filter string here.",
                    ),

                    autofocus: true,

                    style: new TextStyle(fontSize: titleScaleFactor * 14),
                    onChanged: (text) {
                      logger.v('search text: "$text"');
                      _searchSongs(text);
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.clear),
                  tooltip: 'Clear the search text.',
                  onPressed: (() {
                    _searchTextFieldController.clear();
                    FocusScope.of(context).requestFocus(_searchFocusNode);
                    _searchSongs(null);
                    setState(() {});
                  }),
                ),
              ]),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                children: <Widget>[
//  framework for the future
                ],
              ),
            ),
          ],
        ),
        Expanded(
            child: Scrollbar(
              controller: _scrollController,
          child: ListView(

            children: listViewChildren,
          ),
        )),
      ]),

      floatingActionButton: FloatingActionButton(
        mini: _isTooNarrow,
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

    //  apply complexity filter
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
    _filteredSongs = SplayTreeSet();
    for (Song song in _allSongs) {
      if (search.length == 0 ||
          song.getTitle().toLowerCase().contains(search) ||
          song.getArtist().toLowerCase().contains(search)) {
        _filteredSongs.add(song);
      }
    }
  }

  _navigateToSongs(BuildContext context) async {
    Song lastSelectedSong = _selectedSong;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Songs()),
    );
    Navigator.pop(context);

    //  jump the player screen if a song was read
    if (lastSelectedSong != _selectedSong) _navigateToPlayer(context, _selectedSong);
    setState(() {});
  }

  _navigateToPlayer(BuildContext context, Song song) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Player(song: song)),
    );

    //  select all text on a navigation pop
    _searchTextFieldController.selection =
        TextSelection(baseOffset: 0, extentOffset: _searchTextFieldController.text.length);
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  _navigateToOptions(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Options()),
    );
    Navigator.pop(context);
    setState(() {});
  }

  _navigateToEdit(BuildContext context, Song song) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(song: song)),
    );
    Navigator.pop(context);
    setState(() {});
  }

  _navigateToAbout(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => About()),
    );
    Navigator.pop(context);
  }

  _navigateToPrivacyPolicy(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Privacy()),
    );
    Navigator.pop(context);
  }

  TextEditingController _searchTextFieldController;
  FocusNode _searchFocusNode;
}

Future<String> fetchString(String url) async {
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return utf8.decode(response.bodyBytes);
  } else {
    // If that call was not successful, throw an error.
    throw Exception('Failed to load url: $url');
  }
}
