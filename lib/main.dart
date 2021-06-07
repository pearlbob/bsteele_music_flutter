import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/screens/about.dart';
import 'package:bsteele_music_flutter/screens/bass.dart';
import 'package:bsteele_music_flutter/screens/documentation.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/options.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/screens/privacy.dart';
import 'package:bsteele_music_flutter/screens/songs.dart';
import 'package:bsteele_music_flutter/screens/theory.dart';
import 'package:bsteele_music_flutter/util/appTextStyle.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'app/app.dart';
import 'app/appOptions.dart';
import 'util/openLink.dart';

void main() async {
  runApp(
    MyApp(),
  );
}

/*
//  fixme: add undo/redo to chord entry
//  fixme: after an edit change, don't allow navigator pop without admission that edits will be lost
//  fixme: song diff page
//  fixme: import lyrics
//  fixme: surrender leadership when leader song update appears
//  fixme: space in title entry jumps to lyrics Section

C's ipad: model ML0F2LL/A

what is debugPrint

remember keys songs were played in
remember keys songs were played in for a singer
remember songs played
roll list start when returning to song list
edit: paste from edit buffer
fix key guess
wider fade area on player
edit: slash note dropdown: make smarter


linux notes:
build release:
% flutter build linux
executable (without assets) is in ./build/linux/release/bundle/${project}

 */

final App _app = App();
const double defaultFontSize = 10.0; //  based on phone

SplayTreeSet<Song> _filteredSongs = SplayTreeSet();

enum _SortType {
  byTitle,
  byArtist,
  byLastChange,
  byComplexity,
}

const _environmentDefault = 'main';
const _environment = String.fromEnvironment('environment', defaultValue: _environmentDefault);

/// Display the list of songs to choose from.
class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key) {
    Logger.level = Level.info;
    AppOptions().init();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppOptions>(
        create: (_) => AppOptions(),
        builder: (context, _) => MaterialApp(
              title: 'bsteele Music App',
              theme: ThemeData(
                 primaryColor: appDefaultColor,
                // scaffoldBackgroundColor: Colors.white,
              ),
              home: const MyHomePage(title: 'bsteele Music App'),
              navigatorObservers: [playerRouteObserver],

              // Start the app with the "/" named route. In this case, the app starts
              // on the FirstScreen widget.
              initialRoute: Navigator.defaultRouteName,
              routes: {
                // When navigating to the "/" route, build the FirstScreen widget.
                //'/': (context) => MyApp(),
                // When navigating to the "/second" route, build the SecondScreen widget.
                Player.routeName: playerPageRoute.builder,
                '/songs': (context) => const Songs(),
                '/options': (context) => const Options(),
                '/edit': (context) => Edit(initialSong: _app.selectedSong),
                '/privacy': (context) => const Privacy(),
                '/documentation': (context) => const Documentation(),
                '/about': (context) => const About(),
                '/bass': (context) => const BassWidget(),
                '/theory': (context) => const TheoryWidget(),
              },
            ));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title = 'unknown'}) : super(key: key);

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

    if (_environment == _environmentDefault) {
      _readExternalSongList();
      SongUpdateService.open(context);
    } else {
      //  testing
      _readInternalSongList();
    }
    _refilterSongs();
  }

  void _readInternalSongList() async {
    {
      String songListAsString = await rootBundle.loadString('lib/assets/allSongs.songlyrics');

      try {
        _app.removeAllSongs();
        _app.addSongs(Song.songListFromJson(songListAsString));
        try {
          _app.selectedSong = _filteredSongs.first;
        } catch (e) {
          _app.selectedSong = _app.emptySong;
        }
        setState(() {
          _refilterSongs();
        });
        logger.i("internal songList used");
      } catch (fe) {
        logger.i("internal songList parse error: " + fe.toString());
      }
    }
    {
      String songMetadataAsString = await rootBundle.loadString('lib/assets/allSongs.songmetadata');

      try {
        SongMetadata.clear();
        SongMetadata.fromJson(songMetadataAsString);
        logger.i("internal song metadata used");
      } catch (fe) {
        logger.i("internal song metadata parse error: " + fe.toString());
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
        logger.i("read of url: '$url' failed: ${e.toString()}");
        _readInternalSongList();
        return;
      }

      try {
        _app.removeAllSongs();
        _app.addSongs(Song.songListFromJson(allSongsAsString));
        setState(() {
          _refilterSongs();
        });
        logger.i("external songList read from: " + url);
      } catch (fe) {
        logger.i("external songList parse error: " + fe.toString());
        _readInternalSongList();
      }
    }
    {
      const String url = 'http://www.bsteele.com/bsteeleMusicApp/allSongs.songmetadata';

      String metadataAsString;
      try {
        metadataAsString = await fetchString(url);
      } catch (e) {
        logger.i("read of url: '$url' failed: ${e.toString()}");
        _readInternalSongList();
        return;
      }

      try {
        SongMetadata.clear();
        SongMetadata.fromJson(metadataAsString);
        logger.i("external song metadata read from: " + url);
      } catch (fe) {
        logger.i("external song metadata parse error: " + fe.toString());
      }
    }
  }

  void _refilterSongs() {
    //  or at least induce the re-filtering
    _filteredSongs.clear();
  }

  @override
  Widget build(BuildContext context) {
    logger.v('main build: ${_app.selectedSong}');

    _appOptions = Provider.of<AppOptions>(context);

    bool oddEven = true;

    _app.screenInfo = ScreenInfo(context); //  dynamically adjust to screen size changes  fixme: should be event driven

    var _titleBarFontSize = defaultFontSize * min(3, max(1, _app.screenInfo.widthInLogicalPixels / 350));

    //  figure the configuration when the values are established
    _app.isEditReady = (kIsWeb
            //  if is web, Platform doesn't exist!  not evaluated here in the expression
            ||
            Platform.isLinux ||
            Platform.isMacOS ||
            Platform.isWindows) &&
        !_app.screenInfo.isTooNarrow;
    logger.v('isEditReady: $_app.isEditReady');

    _app.isScreenBig = _app.isEditReady || !_app.screenInfo.isTooNarrow;
    _app.isPhone = !_app.isScreenBig;

    logger.v('screen: logical: (${_app.screenInfo.widthInLogicalPixels},${_app.screenInfo.heightInLogicalPixels})');
    logger.v('isScreenBig: $_app.isScreenBig, isPhone: $_app.isPhone');

    final double mediaWidth = _app.screenInfo.widthInLogicalPixels;
    final double titleScaleFactor = _app.screenInfo.titleScaleFactor;
    final double artistScaleFactor = _app.screenInfo.artistScaleFactor;
    const fontSize = defaultFontSize;
    logger.d(
        'fontSize: $fontSize in ${_app.screenInfo.widthInLogicalPixels} px with ${_app.screenInfo.titleScaleFactor}');
     AppTextStyle searchTextStyle = AppTextStyle(
      fontWeight: FontWeight.normal,
      fontSize: fontSize * artistScaleFactor,
      color: Colors.black38,
      textBaseline: TextBaseline.alphabetic,
    );
    AppTextStyle searchDropDownStyle = AppTextStyle(
      fontWeight: FontWeight.normal,
      fontSize: fontSize * artistScaleFactor,
      color: Colors.black87,
      textBaseline: TextBaseline.alphabetic,
    );
    const AppTextStyle titleTextStyle = AppTextStyle(
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      color: Colors.black87,
      textBaseline: TextBaseline.alphabetic,
    );
    const AppTextStyle artistTextStyle = AppTextStyle(fontSize: fontSize);
    final AppTextStyle _navTextStyle = AppTextStyle(fontSize: fontSize, color: Colors.grey[800]);


    //  generate the sort selection
    _sortTypesDropDownMenuList.clear();
    for (final e in _SortType.values) {
      var s = e.toString();
      //print('$e: ${Util.camelCaseToLowercaseSpace(s.substring(s.indexOf('.') + 1))}');
      _sortTypesDropDownMenuList.add(DropdownMenuItem<_SortType>(
        value: e,
        child: Text(Util.camelCaseToLowercaseSpace(s.substring(s.indexOf('.') + 1)),
        style: searchDropDownStyle,),
      ));
    }

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
          padding: const EdgeInsets.all(8.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            if (_app.isScreenBig)
              Row(
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
                        style: artistTextStyle,
                      ),
                    ],
                  ),
                  Text(
                    '   ' + DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime)),
                    textScaleFactor: artistScaleFactor,
                    style: artistTextStyle,
                  ),
                ],
              ),
            if (_app.isPhone)
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
          style: AppTextStyle(fontSize: _titleBarFontSize, fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          Tooltip(
            message: "Visit bsteele.com, the provider of this app.",
            child: InkWell(
              onTap: () {
                openLink('http://www.bsteele.com');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Image(
                  image: const AssetImage('lib/assets/runningMan.png'),
                  width: _titleBarFontSize,
                  height: _titleBarFontSize,
                  semanticLabel: "bsteele.com website",
                ),
              ),
            ),
          ),
          if (_app.isScreenBig) //  sorry CJ
            Tooltip(
              message: "Visit Community Jams, the motivation and main user for this app.",
              child: InkWell(
                onTap: () {
                  openLink('http://communityjams.org');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Image(
                    image: const AssetImage('lib/assets/cjLogo.png'),
                    width: _titleBarFontSize,
                    height: _titleBarFontSize,
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
          padding: const EdgeInsets.all(4.0),
          children: <Widget>[
            Container(
              height: 50,
            ), //  filler for notched phones
            if (_app.isEditReady) //  no files on phones!
              ListTile(
                title: Text(
                  "Songs",
                  style: _navTextStyle,
                  textScaleFactor: titleScaleFactor,
                ),
                onTap: () {
                  _navigateToSongs(context);
                },
              ),
            ListTile(
              title: Text(
                "Options",
                style: _navTextStyle,
                textScaleFactor: titleScaleFactor,
              ),
              onTap: () {
                _navigateToOptions(context);
              },
            ),
            ListTile(
              title: Text(
                "Docs",
                style: _navTextStyle,
                textScaleFactor: titleScaleFactor,
              ),
              onTap: () {
                _navigateToDocumentation(context);
              },
            ),
            ListTile(
              title: Text(
                "Bass",
                style: _navTextStyle,
                textScaleFactor: titleScaleFactor,
              ),
              onTap: () {
                _navigateToBass(context);
              },
            ),
            ListTile(
              title: Text(
                "Theory",
                style: _navTextStyle,
                textScaleFactor: titleScaleFactor,
              ),
              onTap: () {
                _navigateToTheory(context);
              },
            ),
            ListTile(
              title: Text(
                "Privacy",
                style: _navTextStyle,
                textScaleFactor: titleScaleFactor,
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
                textScaleFactor: titleScaleFactor,
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                width: min(mediaWidth / 2, 10 * fontSize * artistScaleFactor),
                //  limit text entry display length
                child: TextField(
                  controller: _searchTextFieldController,
                  focusNode: _searchFocusNode,
                  decoration:  InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: "search text",
                    hintStyle: searchTextStyle,
                  ),
                  autofocus: true,
                  style: searchDropDownStyle,
                  onChanged: (text) {
                    setState(() {
                      logger.v('search text: "$text"');
                      _searchSongs(_searchTextFieldController.text);
                    });
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: _searchTextFieldController.text.isEmpty ? 'Scroll the list some.' : 'Clear the search text.',
                iconSize: titleScaleFactor * fontSize ,
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
                style: titleTextStyle,
              ),
            ]),
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
        mini: !_app.isScreenBig,
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
    int Function(Song key1, Song key2)? compare;
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
      case _SortType.byLastChange:
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
    for (final Song song in _app.allSongs) {
      if (search.isEmpty ||
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Songs()),
    );
    Navigator.pop(context);

    setState(() {
      _searchTextFieldController.selection =
          TextSelection(baseOffset: 0, extentOffset: _searchTextFieldController.text.length);
      _searchSongs(_app.selectedSong.title);
    }); //  refresh the display
  }

  _navigateToPlayer(BuildContext context, Song song) async {
    if (song.getTitle().isEmpty) {
      return;
    }

    _app.selectedSong = song;

    await Navigator.pushNamed(
      context,
      Player.routeName,
    );

    //  select all text on a navigation pop
    _searchTextFieldController.selection =
        TextSelection(baseOffset: 0, extentOffset: _searchTextFieldController.text.length);
    FocusScope.of(context).requestFocus(_searchFocusNode);
    _rollUnfilteredSongs();
  }

  _navigateToOptions(BuildContext context) async {
    Navigator.pushNamed(
      context,
      Options.routeName,
    ).then((_) {
      Navigator.pop(context);
      setState(() {
        _refilterSongs(); //  force re-filter on possible option changes
      });
    });
  }

  _navigateToAbout(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const About()),
    );
    Navigator.pop(context);
  }

  _navigateToDocumentation(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Documentation()),
    );
    Navigator.pop(context);
  }

  _navigateToBass(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BassWidget()),
    );
    Navigator.pop(context);
  }

  _navigateToTheory(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TheoryWidget()),
    );
    Navigator.pop(context);
  }

  _navigateToPrivacyPolicy(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Privacy()),
    );
    Navigator.pop(context);
  }

  final List<DropdownMenuItem<_SortType>> _sortTypesDropDownMenuList = [];
  var _selectedSortType = _SortType.byTitle;

  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final Duration _itemScrollDuration = const Duration(milliseconds: 500);
  int _rollIndex = -1;

  late AppOptions _appOptions;

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

void foo() {
  var v = 3.bitLength;
  v = v.bitLength;
}
