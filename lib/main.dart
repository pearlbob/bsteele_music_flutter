import 'package:bsteele_music_flutter/player.dart';
import 'package:bsteele_music_flutter/songs/Song.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(MyApp());

/*
project structure
__json
packaging
deployment
websockets/server
__resources
ui tables
MVC?
file io (web, android)
flutter on linux?
what is debugPrint
__software documentation
____.gitignore
____unit tests
 */

List<Song> songList = List();
Song selectedSong;

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bsteele Music',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'bsteele Music'),

      // Start the app with the "/" named route. In this case, the app starts
      // on the FirstScreen widget.
      initialRoute: '/',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        //'/': (context) => MyApp(),
        // When navigating to the "/second" route, build the SecondScreen widget.
        '/player': (context) => Player(selectedSong),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _readInternalSongList();
  }

  void _readInternalSongList() async {
    String songListAsString =
        await rootBundle.loadString('lib/assets/allSongs.songlyrics');

    try {
      songList = Song.songListFromJson(songListAsString);
      selectedSong = songList[0];
      print(selectedSong.toString());
      setState(() {});
    } catch (fe) {
      print("songList parse error: " + fe.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    List<StatelessWidget> listViewChildren = List();
    bool oddEven = false;
    for (Song song in songList) {
      oddEven = !oddEven;
      listViewChildren.add(GestureDetector(
        child: ListTile(
          title: Text(
            song.getTitle(),
            style: TextStyle(
                backgroundColor: oddEven ? Colors.white : Colors.grey[200]),
          ),
          subtitle: Text(
            song.getArtist(),
            style: TextStyle(
                backgroundColor: oddEven ? Colors.white : Colors.grey[200]),
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Player(song)),
          );
        },
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      // Navigate to second route when tapped.
      body: Scrollbar(
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: 0),
          children: listViewChildren,
        ),
      ),
//      floatingActionButton: FloatingActionButton(
//        onPressed: null,
//        tooltip: 'Increment',
//        child: Icon(Icons.add),
//      ),
    );
  }
}
