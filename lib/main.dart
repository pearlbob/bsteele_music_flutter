import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:websocket/websocket.dart';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/screens/about.dart';
import 'package:bsteele_music_flutter/screens/documentation.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/options.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/screens/privacy.dart';
import 'package:bsteele_music_flutter/screens/songs.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'appOptions.dart';
import 'util/openLink.dart';

//CjRankingEnum _cjRanking;

void main() {
  Logger.level = Level.info;

  _webSocketOpen();

  runApp(MyApp());
}

/*
websockets/server

C's ipad: model ML0F2LL/A

what is debugPrint

remember keys songs were played in
remember keys songs were played in for a singer
remember songs played
roll list start when returning to song list
edit: paste from edit buffer
fix key guess
wider fade area on player
edit: slash note pulldown


linux notes:
build release:
% flutter build linux
executable (without assets) is in ./build/linux/release/bundle/${project}

 */

const double defaultFontSize = 14.0; //  borrowed from Text widget

//  parameters to be evaluated before use
ScreenInfo screenInfo = ScreenInfo.defaultValue(); //  refreshed on main build
bool isEditReady = false;
bool isScreenBig = true;
bool isPhone = false;
final Song _emptySong = Song.createEmptySong();

void addSong(Song song) {
  logger.i('addSong( ${song.toString()} )');
  _allSongs.add(song);
  _filteredSongs = SplayTreeSet();
  _selectedSong = song;
}

SplayTreeSet<Song> get allSongs => _allSongs;
SplayTreeSet<Song> _allSongs = SplayTreeSet();
SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
Song _selectedSong = Song.createEmptySong();

final Color _primaryColor = Color(0xFF4FC3F7);

enum _SortType {
  byTitle,
  byArtist,
  byLastModification,
  byComplexity,
}

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
        '/edit': (context) => Edit(initialSong: _selectedSong),
        '/privacy': (context) => Privacy(),
        '/documentation': (context) => Documentation(),
        '/about': (context) => About(),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title: 'unknown'}) : super(key: key);

  // This widget is the home page of the application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  //  Fields in a Widget subclass are always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  _MyHomePageState() : _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _appOptionsInit();
    _readExternalSongList();

    //  generate the sort selection
    for (var e in _SortType.values) {
      var s = e.toString();
      //print('$e: ${Util.camelCaseToLowercaseSpace(s.substring(s.indexOf('.') + 1))}');
      _sortTypesDropDownMenuList.add(DropdownMenuItem<_SortType>(
        value: e,
        child: Text(Util.camelCaseToLowercaseSpace(s.substring(s.indexOf('.') + 1))),
      ));
    }
  }

  /// initialize async options read from shared preferences
  void _appOptionsInit() async {
    await AppOptions().init();
  }

  void _readInternalSongList() async {
    {
      String songListAsString = await rootBundle.loadString('lib/assets/allSongs.songlyrics');

      try {
        _allSongs = SplayTreeSet();
        _allSongs.addAll(Song.songListFromJson(songListAsString));
        _filteredSongs = _allSongs;
        try {
          _selectedSong = _filteredSongs.first;
        } catch (e) {
          _selectedSong = _emptySong;
        }
        setState(() {});
        print("internal songList used");
      } catch (fe) {
        print("internal songList parse error: " + fe.toString());
      }
    }
    {
      String songMetadataAsString = await rootBundle.loadString('lib/assets/allSongs.songmetadata');

      try {
        SongMetadata.clear();
        SongMetadata.fromJson(songMetadataAsString);
        print("internal song metadata used");
      } catch (fe) {
        print("internal song metadata parse error: " + fe.toString());
      }
    }
  }

  void _readExternalSongList() async {
    {
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
        setState(() {
          _filteredSongs = _allSongs;
          try {
            _selectedSong = _filteredSongs.first;
          } catch (e) {
            _selectedSong = _emptySong;
          }
        });
        print("external songList read from: " + url);
      } catch (fe) {
        print("external songList parse error: " + fe.toString());
        _readInternalSongList();
      }
    }
    {
      const String url = 'http://www.bsteele.com/bsteeleMusicApp/allSongs.songmetadata';

      String metadataAsString;
      try {
        metadataAsString = await fetchString(url);
      } catch (e) {
        print("read of url: '$url' failed: ${e.toString()}");
        _readInternalSongList();
        return;
      }

      try {
        SongMetadata.clear();
        SongMetadata.fromJson(metadataAsString);
        print("external song metadata read from: " + url);
      } catch (fe) {
        print("external song metadata parse error: " + fe.toString());
      }
    }
  }

  void _refilterSongs() {
    //  or at least induce the re-filtering
    _filteredSongs = SplayTreeSet();
  }

  @override
  Widget build(BuildContext context) {
    bool oddEven = true;

    screenInfo = ScreenInfo(context); //  dynamically adjust to screen size changes  fixme: should be event driven

    var _titleBarFontSize = defaultFontSize * min(3, max(1, screenInfo.widthInLogicalPixels /350));

    //  figure the configuration when the values are established
    isEditReady = (kIsWeb
            //  if is web, Platform doesn't exist!  not evaluated here in the expression
            ||
            Platform.isLinux ||
            Platform.isMacOS ||
            Platform.isWindows) &&
        !screenInfo.isTooNarrow;
    logger.v('isEditReady: $isEditReady');

    isScreenBig = isEditReady || !screenInfo.isTooNarrow;
    isPhone = !isScreenBig;

    logger.v('screen: logical: (${screenInfo.widthInLogicalPixels},${screenInfo.heightInLogicalPixels})');
    logger.v('isScreenBig: $isScreenBig, isPhone: $isPhone');

    final double mediaWidth = screenInfo.widthInLogicalPixels;
    final double titleScaleFactor = screenInfo.titleScaleFactor;
    final double artistScaleFactor = screenInfo.artistScaleFactor;
    final TextStyle titleTextStyle = TextStyle(fontWeight: FontWeight.bold);

    //  re-search filtered list on data changes
    if (_filteredSongs.isEmpty) {
      _searchSongs(_searchTextFieldController.text);
    }

    List<StatelessWidget> listViewChildren = [];
    for (final Song song in (_filteredSongs)) {
      oddEven = !oddEven;
      listViewChildren.add(GestureDetector(
        child: Container(
          color: oddEven ? Colors.white : Colors.grey[100],
          padding: EdgeInsets.all(8.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            if (isScreenBig)
              Container(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          song.getTitle(),
                          textScaleFactor: titleScaleFactor,
                          style: titleTextStyle,
                        ),
                        Text(
                          '      ' + song.getArtist(),
                          textScaleFactor: artistScaleFactor,
                        ),
                      ],
                    ),
                    Text(
                      '   ' + DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime)),
                      textScaleFactor: artistScaleFactor,
                    ),
                  ],
                ),
              ),
            if (isPhone)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    song.getTitle(),
                    textScaleFactor: titleScaleFactor,
                    style: titleTextStyle,
                  ),
                  Text(
                    '      ' + song.getArtist(),
                    textScaleFactor: artistScaleFactor,
                  ),
                ],
              ),
          ]),
        ),
        onTap: () {
          _navigateToPlayer(context, song);
        },
      ));
    }

    double fontSize = defaultFontSize * max(1, screenInfo.titleScaleFactor);
    final TextStyle _navTextStyle = TextStyle(fontSize: fontSize, color: Colors.grey[800]);

    // if (metadataDropDownMenuList == null) {
    //   metadataDropDownMenuList = [
    //     DropdownMenuItem<SongIdMetadata>(
    //       value: SongIdMetadata('CJ Ranking: best'),
    //       child: Text('CJ Ranking: best'),
    //       onTap: () {
    //         logger.d('choose best');
    //         setState(() {
    //           _cjRanking = CjRankingEnum.best;
    //           _refilterSongs();
    //         });
    //       },
    //     ),
    //     DropdownMenuItem<SongIdMetadata>(
    //       value: SongIdMetadata('CJ Ranking: good'),
    //       child: Text('CJ Ranking: good'),
    //       onTap: () {
    //         logger.d('choose good');
    //         setState(() {
    //           _cjRanking = CjRankingEnum.good;
    //           _refilterSongs();
    //         });
    //       },
    //     ),
    //     DropdownMenuItem<SongIdMetadata>(
    //       value: SongIdMetadata('CJ Ranking: all'),
    //       child: Text('CJ Ranking: all'),
    //       onTap: () {
    //         logger.d('choose all');
    //         setState(() {
    //           _cjRanking = null;
    //           _refilterSongs();
    //         });
    //       },
    //     ),
    //   ];
    // }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(fontSize: _titleBarFontSize, fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          Tooltip(
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
          if (isScreenBig) //  sorry CJ
            Tooltip(
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
        toolbarHeight: kToolbarHeight * 0.9, //  trim for cell phone overrun
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.all(4.0),
          children: <Widget>[
            Container(
              height: 50,
            ), //  filler for notched phones
            if (isEditReady) //  no files on phones!
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
            ListTile(
              title: Text(
                "Docs",
                style: _navTextStyle,
              ),
              onTap: () {
                _navigateToDocumentation(context);
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
            Flex(direction: Axis.horizontal, children: <Widget>[
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
                  style: TextStyle(fontSize: fontSize),
                  onChanged: (text) {
                    setState(() {
                      logger.v('search text: "$text"');
                      _searchSongs(_searchTextFieldController.text);
                    });
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.clear),
                tooltip: _searchTextFieldController.text.isEmpty ? 'Scroll the list some.' : 'Clear the search text.',
                onPressed: (() {
                  _searchTextFieldController.clear();
                  setState(() {
                    FocusScope.of(context).requestFocus(_searchFocusNode);
                    _searchSongs(null);
                  });
                }),
              ),
              DropdownButton<_SortType>(
                items: _sortTypesDropDownMenuList,
                onChanged: (value) {
                  if (_selectedSortType != value) {
                    setState(() {
                      _selectedSortType = value ?? _SortType.byTitle;
                      _searchSongs(_searchTextFieldController.text);
                    });
                  }
                },
                value: _selectedSortType,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.black87,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
            ]),

            // Spacer(),
            // if (_appOptions.holiday)
            //   RaisedButton(
            //     child: Text(
            //       'holiday',
            //       textScaleFactor: artistScaleFactor,
            //     ),
            //     onPressed: () {
            //       _setHoliday(null);
            //     },
            //   ),
            // if (!_appOptions.holiday)
            //   RaisedButton(
            //     child: Text(
            //       'not holiday',
            //       textScaleFactor: artistScaleFactor,
            //     ),
            //     onPressed: () {
            //       _setHoliday(null);
            //     },
            //   ),
            // Spacer(),
            // if (_cjRanking != null)
            //   RaisedButton(
            //     child: Text(
            //       'CJ Ranking: ${_cjRanking.toString().split('.').last}',
            //       textScaleFactor: artistScaleFactor,
            //     ),
            //     onPressed: () {
            //       setState(() {
            //         _cjRanking = null;
            //         _refilterSongs();
            //       });
            //     },
            //   ),
            // Spacer(flex: 10),
            // DropdownButton<SongIdMetadata>(
            //   hint: Text(
            //     'Filters',
            //     textScaleFactor: artistScaleFactor,
            //     style: TextStyle(backgroundColor: Colors.lightBlue[300], color: Colors.black),
            //   ),
            //   items: metadataDropDownMenuList,
            //   onChanged: (songIdMetadata) {},
            // )
          ],
        ),
        if (listViewChildren.isNotEmpty) //  ScrollablePositionedList messes up otherwise
          Expanded(
              child: ScrollablePositionedList.builder(
            itemCount: listViewChildren.length,
            itemScrollController: _itemScrollController,
            itemBuilder: (context, index) {
              return listViewChildren[Util.limit(index, 0, listViewChildren.length) as int];
            },
          )),
        // Expanded(
        //   child: Scrollbar(
        //     child: ListView(
        //       controller: _scrollController,
        //       children: listViewChildren,
        //     ),
        //   ),
        // ),
      ]),

      floatingActionButton: FloatingActionButton(
        mini: !isScreenBig,
        onPressed: () {
          if (_itemScrollController.isAttached) {
            _itemScrollController.scrollTo(
              index: 0,
              curve: Curves.easeOut,
              duration: const Duration(milliseconds: 500),
            );
          }
        },
        tooltip: 'Back to the list top',
        child: const Icon(
          Icons.arrow_upward,
        ),
      ),
    );
  }

  void _searchSongs(String? search) {
    search ??= '';
    search = search.trim();

    search = search.replaceAll("[^\\w\\s']+", '');
    search = search.toLowerCase();

    //  apply complexity filter
//    TreeSet<Song> allSongsFiltered = allSongs;
//    if (complexityFilter != ComplexityFilter.all) {
//      TreeSet<Song> sortedSongs =  TreeSet<>(Song.getComparatorByType(Song.ComparatorType.complexity));
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
//      Song[] allSongsFilteredList = sortedSongs.toArray( Song[0]);
//      allSongsFiltered =  TreeSet<>();
//      for (int i = 0; i < limit; i++)
//        allSongsFiltered.add(allSongsFilteredList[i]);
//    }

    // select order
    var compare;
    switch (_selectedSortType) {
      case _SortType.byArtist:
        compare = (Song song1, Song song2) {
          var ret = song1.artist.compareTo(song2.artist);
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case _SortType.byLastModification:
        compare = (Song song1, Song song2) {
          var ret = -song1.lastModifiedTime.compareTo(song2.lastModifiedTime);
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case _SortType.byComplexity:
        compare = (Song song1, Song song2) {
          var ret = song1.getComplexity().compareTo(song2.getComplexity());
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case _SortType.byTitle:
      default:
        compare = (Song song1, Song song2) {
          return song1.compareTo(song2);
        };
        break;
    }

    //  apply search filter
    _filteredSongs = SplayTreeSet(compare);
    for (final Song song in _allSongs) {
      if (search.length == 0 ||
          song.getTitle().toLowerCase().contains(search) ||
          song.getArtist().toLowerCase().contains(search)) {
        //  if holiday and song is holiday, we're good
        if (_appOptions.holiday) {
          if (SongMetadata.songMetadataAt(song.songId.songId, 'christmas') != null) {
            _filteredSongs.add(song);
          }
          continue; //  toss the others
        } else
        //  if song is holiday and we're not, nope
        if (SongMetadata.songMetadataAt(song.songId.songId, 'christmas') != null) {
          continue;
        }

        // //  otherwise try some other qualification
        // if (_cjRanking != null) {
        //   //  insist on a cj ranking
        //   NameValue nv = SongMetadata.songMetadataAt(song.songId.songId, 'cj');
        //   if (nv == null) {
        //     //  toss if not found
        //     continue;
        //   }
        //   CjRankingEnum ranking = nv.value.toCjRankingEnum();
        //   if (ranking != null && ranking.index >= _cjRanking.index)
        //     //  ranking is good
        //     _filteredSongs.add(song);
        //
        //   //  toss if not good enough for cj
        //   continue;
        // }

        //  not filtered
        _filteredSongs.add(song);
      }
    }

    //  on new search, start the list at the first location
    if (search.isNotEmpty) {
      _rollIndex = 0;
      if (_itemScrollController.isAttached && _filteredSongs.isNotEmpty) {
        _itemScrollController.jumpTo(index: _rollIndex);
      }
    } else if (_filteredSongs.isNotEmpty && _selectedSortType == _SortType.byTitle) {
      _rollUnfilteredSongs();
    }
  }

  void _rollUnfilteredSongs() {
    const int rollStep = 15;

    //  skip if searching for something
    if (_searchTextFieldController.text.isNotEmpty || _filteredSongs.isEmpty) {
      return;
    }

    List<Song> list = _filteredSongs.toList();

    if (_rollIndex < 0) {
      //  start with a random location
      _rollIndex = _random.nextInt(list.length);
    }
    _rollIndex = _rollIndex + rollStep;
    if (_rollIndex >= list.length) {
      _rollIndex = 0;
    }

    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(index: _rollIndex, duration: _itemScrollDuration);
    }
  }

  _navigateToSongs(BuildContext context) async {
    if (_selectedSong.getTitle().isNotEmpty) {
      Song lastSelectedSong = _selectedSong;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Songs()),
      );
      Navigator.pop(context);

      setState(() {
        //  jump the player screen if a song was read
        if (lastSelectedSong != _selectedSong) {
          _navigateToPlayer(context, _selectedSong);
        }
      });
    }
  }

  _navigateToPlayer(BuildContext context, Song song) async {
    if (song.getTitle().isEmpty) return;

    _selectedSong = song;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Player(song: song)),
    );

    //  select all text on a navigation pop
    _searchTextFieldController.selection =
        TextSelection(baseOffset: 0, extentOffset: _searchTextFieldController.text.length);
    FocusScope.of(context).requestFocus(_searchFocusNode);
    _rollUnfilteredSongs();
  }

  _navigateToOptions(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Options()),
    );
    Navigator.pop(context);
    setState(() {
      _refilterSongs(); //  force re-filter on possible option changes
    });
  }

  _navigateToAbout(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => About()),
    );
    Navigator.pop(context);
  }

  _navigateToDocumentation(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Documentation()),
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

  List<DropdownMenuItem<_SortType>> _sortTypesDropDownMenuList = [];
  var _selectedSortType = _SortType.byTitle;

  final TextEditingController _searchTextFieldController = TextEditingController();
  FocusNode _searchFocusNode;

  //ScrollController _scrollController =  ScrollController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final Duration _itemScrollDuration = Duration(milliseconds: 500);
  int _rollIndex = -1;

  //static const double floatingActionSize = 50; //  inside the prescribed 56 pixel size
  final AppOptions _appOptions = AppOptions();
  final _random = Random();
}

Future<String> fetchString(String uriString) async {
  final response = await http.get(Uri.parse(uriString));

  if (response.statusCode == 200) {
    return utf8.decode(response.bodyBytes);
  } else {
    // If that call was not successful, throw an error.
    throw Exception('Failed to load url: $uriString');
  }
}

void _webSocketOpen() async {
  try {
    var url = 'ws://192.168.0.200:8080/bsteeleMusicApp/bsteeleMusic'; //  fixme
    if (kIsWeb) {
      logger.i('kIsWeb');
    }
    WebSocket _webSocket = await WebSocket.connect(url);
    var stream = _webSocket.stream;

    await for (var value in stream) {
      var s = value.toString();

      logger.i('message: $s');
    }
  } catch (e) {
    logger.w('websocket exception: $e');
  }
}
