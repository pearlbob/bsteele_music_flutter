/// # The bSteele Music App.
///
/// ## The primary functions for the app:
///
/// * Provide a readable HDMI image (1920x1080) application to allow multiple musicians
/// to see chords and lyrics on a shared large screen while playing live music together.
/// * Provide a reasonable tablet experience that mimics the HDMI image experience
/// and allows for shared song choice and current play location.
/// * Allow users to input songs and store them locally.
/// * Allow user entered songs to migrate to the master list on the web.
///
/// ## Metrics for the application
///
/// * Ease of use
/// * Clarity of the musical presentation
/// * Performance
/// * Reliability
/// * Platform agnostics
/// * Maintainability
/// * Documentation
///
/// ## Secondary features for the app:
///
/// * Musical key transposition
/// * Minimize overhead on the musical leader
/// * Reasonable operation on smart phones
/// * Enforce musical rules on song entry
/// * Ease the import of song lyrics from other sources
/// * Application customization
/// * Sub-lists (named subsets of the master song list)
/// * Guitar capo use calculations
/// * Sheet music presentation with export to the MuseScore musicxml format.
/// * iRealPro like practice modes
/// * Noise to Notes
///
/// ## App attributes
///
/// * Release at http://www.bsteele.com/bsteeleMusicApp/index.html
/// * Release app is written in GWT. See http://www.gwtproject.org. Open source at https://github.com/pearlbob/bsteeleMusicApp
/// * Beta at http://www.bsteele.com/bsteeleMusicApp/beta/index.html
/// * Beta written in Google's flutter/dart. See: https://flutter.dev/ and https://dart.dev/
/// * Beta is currently closed source.  Expect to open source it eventually.
/// * Beta backend is a separate dart project.
/// * Both apps are heavy clients from static pages downloaded from the cloud.
/// * Both apps use web sockets when on local servers for tablet communication.
///
/// ## Specific Beta UI problems to fix
///
/// * Overall look
/// * Graphics on player page in play mode
/// * Pastel colors for section backgrounds
/// * Sublist management page
/// * Complexity of song editing
/// * Dynamic font sizing
/// * Use of Theme vs home grown "app" methods
///
/// ## Personal notes:
///
/// * Retired software developer
/// * Do this project just for the fun of it... and the use of the app while playing music.
/// * Fair exposure to HTML/CSS/JavaScript but no customer facing projects during my career.
/// See http://www.bsteele.com/bass/index.html.
/// * Big fan of strongly typed languages.
/// * I've always preferred the backend.  Never was excited about the front end.
/// * Believe I have artistic talent... it just never extends to a GUI.
///
library main;

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
import 'package:bsteele_music_flutter/screens/documentation.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lists.dart';
import 'package:bsteele_music_flutter/screens/options.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/screens/privacy.dart';
import 'package:bsteele_music_flutter/screens/songs.dart';
import 'package:bsteele_music_flutter/screens/theory.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'app/app.dart';
import 'app/appButton.dart';
import 'app/appOptions.dart';
import 'app/app_theme.dart';
import 'util/openLink.dart';

void main() async {
  Logger.level = Level.info;

  //  read the css theme data prior to the first build
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme().init(); //  init the singleton

  //  run the app
  runApp(
    BSteeleMusicApp(),
  );
}

/*
//  fixme: after an edit change, don't allow navigator pop without admission that edits will be lost
//  fixme: song diff page
//  fixme: surrender leadership when leader song update appears
//  fixme: space in title entry jumps to lyrics Section

session stuff:
//  fixme: in the park: no web list read
//  fixme: lyrics should correlate to compressed repeats

Shari UI stuff:
// fixme: easy move from player to singer
// fixme: the listed key disappears once you are in play mode
// fixme: the back button doesn't take you to where you just were in the list ( mostly fixed )
// fixme: When one clicks a play button at the top left and then suddenly doesn't see a stop button next to it
//  fixme: two back buttons
//  fixme: buttons too close

//  fixme: scroll to chord line on scroll
//
//  fixme: aim a little low on a large section 	ie. always show next section first row (approximate)
//
//  fixme: more on follower display when leader is not playing a song
//
//  fixme: poor, poor pitiful me:   font too large  (approximate)
//
//
//  fixme: log of songs played

fixme: I continue to have intermittent trouble if I have to scroll back up during the play mode. Here is the sequence:
1. First enter play mode, then use space bar to advance
2. After 1-3 space bar advances, manually scroll up, but not all the way to the top. It doesn't ever glitch if I go all the way back up.
3. Once I force it to scroll up to the top and play again, it doesn't seem to glitch again until I load another song.
4. This may take 2-4 attempts to break, not dependent on complexity.
5. It requires the scroll-up to break - never breaks if I simply play it straight through with the space bar.


metadata:
	fixme: metadata remove old
	read only from list?
  write a list from lists menu by musicians
  fixme: on main: checkbox for lists to show (from diff musicians)

  fixme: metadata save and save all

  fixme: list copy to another list

  personal list from individuals

  fixme: by individuals from emailed lists to jam leader

	fixme: allow the app to override player&singer mode, be aggressive about minimum fontSize
  fixme:  beta on fullscreen web version


min fontSize 25  singer mode?
max fontSize 36

fixme: singer display no wrapping
fixme: player or play/singer can wrap


fixme: singer mode africa:  font size bounces


fixme: singer mode: section title, first 3 measures then ...
fixme: singer mode: no capo!


// Bb trumpet: -2 half steps, that is: D on instrument is an actual C
// baritone guitar (perfect fourth): -5, that is: F on instrument is an actual C
//
// soprano sax:  Eb, +3,   that is: A played on instrument is an actual C
// alto sax: Eb, +3,   that is: A played on instrument is an actual C
// tenor sax: Bb, -2 half steps, that is: D on instrument is an actual C
// clarinet: Bb, -2 half steps, that is: D on instrument is an actual C
// baritone sax: Eb, +3,   that is: A played on instrument is an actual C
// bass sax: Bb, -2 half steps, that is: Bb on instrument is an actual C
//
// ukulele: soprano, concert, and tenor:  key of C
// ukulele: baritone:  key of D, -5, that is: F on instrument is a C



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

SplayTreeSet<Song> _filteredSongs = SplayTreeSet();

/// Song list sort types
enum _SortType {
  byTitle,
  byArtist,
  byLastChange,
  byComplexity,
}

const _environmentDefault = 'main';
const _environment = String.fromEnvironment('environment', defaultValue: _environmentDefault);

/// Display the list of songs to choose from.
class BSteeleMusicApp extends StatelessWidget {
  BSteeleMusicApp({Key? key}) : super(key: key) {
    Logger.level = Level.info;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppOptions>(
        create: (_) => AppOptions(),
        builder: (context, _) => MaterialApp(
              title: 'bsteele Music App',
              theme: AppTheme().themeData,
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
                '/options': (context) => const Options(),
                '/songs': (context) => const Songs(),
                '/lists': (context) => const Lists(),
                '/edit': (context) => Edit(initialSong: _app.selectedSong),
                '/privacy': (context) => const Privacy(),
                '/documentation': (context) => const Documentation(),
                '/about': (context) => const About(),
                // '/bass': (context) => const BassWidget(),
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
  _MyHomePageState()
      : _searchFocusNode = FocusNode(),
        _appOptions = AppOptions();

  @override
  void initState() {
    super.initState();

    //  normally read external (web) songlist and setup the websocket
    if (_environment == _environmentDefault) {
      _readExternalSongList();
      SongUpdateService.open(context);
    } else {
      //  testing:  read the internal list
      _readInternalSongList();
    }
    _refilterSongs();

    //logger.i('uri: ${Uri.base}, ${Uri.base.queryParameters.keys.contains('follow')}');
  }

  void _readInternalSongList() async {
    {
      String songListAsString = await loadString('lib/assets/allSongs.songlyrics');
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
      String songMetadataAsString = await loadString('lib/assets/allSongs.songmetadata');

      try {
        SongMetadata.clear();
        SongMetadata.fromJson(songMetadataAsString);
        logger.i("internal song metadata used");
        setState(() {});
      } catch (fe) {
        logger.i("internal song metadata parse error: " + fe.toString());
      }
    }
  }

  void _readExternalSongList() async {
    if (_appOptions.isInThePark()) {
      logger.i('internal songList only in the park');
      _readInternalSongList();
      return;
    }
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
        setState(() {});
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
    logger.d('main build: ${_app.selectedSong}');

    _appOptions = Provider.of<AppOptions>(context);

    bool oddEven = true;

    _app.screenInfo = ScreenInfo(context); //  dynamically adjust to screen size changes  fixme: should be event driven

    final _titleBarFontSize = _app.screenInfo.fontSize;

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

    final fontSize = _app.screenInfo.fontSize;
    logger.d('fontSize: $fontSize in ${_app.screenInfo.widthInLogicalPixels} px');
    final AppTextStyle searchTextStyle = AppTextStyle(
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      textBaseline: TextBaseline.alphabetic,
    );
    final AppTextStyle searchDropDownStyle = AppTextStyle(
      fontWeight: FontWeight.normal,
      fontSize: fontSize,
      textBaseline: TextBaseline.alphabetic,
    );
    final AppTextStyle titleTextStyle = AppTextStyle(
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
      textBaseline: TextBaseline.alphabetic,
    );

    final AppTextStyle artistTextStyle = AppTextStyle(fontSize: fontSize);
    final AppTextStyle _navTextStyle = AppTextStyle(fontSize: fontSize);

    //  generate the sort selection
    _sortTypesDropDownMenuList.clear();
    for (final e in _SortType.values) {
      var s = e.toString();
      //logger.i('$e: ${Util.camelCaseToLowercaseSpace(s.substring(s.indexOf('.') + 1))}');
      _sortTypesDropDownMenuList.add(DropdownMenuItem<_SortType>(
        value: e,
        child: Text(
          Util.camelCaseToLowercaseSpace(s.substring(s.indexOf('.') + 1)),
          style: searchDropDownStyle,
        ),
      ));
    }

    //  re-search filtered list on data changes
    if (_filteredSongs.isEmpty) {
      _searchSongs(_searchTextFieldController.text);
    }

    List<Widget> listViewChildren = [];
    logger.d('_filteredSongs.length: ${_filteredSongs.length}');
    for (final Song song in _filteredSongs) {
      oddEven = !oddEven;
      var key = ValueKey<String>(song.songId.toString());
      logger.v('song.songId: ${song.songId}');
      listViewChildren.add(GestureDetector(
        key: key,
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
                        style: titleTextStyle,
                      ),
                      Text(
                        '      ' + song.getArtist(),
                        style: artistTextStyle,
                      ),
                    ],
                  ),
                  Text(
                    '   ' + intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime)),
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
                    style: titleTextStyle,
                  ),
                  Text(
                    '      ' + song.getArtist(),
                    style: artistTextStyle,
                  ),
                ],
              ),
          ]),
        ),
        onTap: () {
          WidgetLog.tap(key);
          _navigateToPlayer(context, song);
        },
      ));
    }
    listViewChildren.add(appSpace(
      space: 20,
    ));
    listViewChildren.add(Text(
      'Count: ${_filteredSongs.length}',
      style: artistTextStyle,
    ));

    List<DropdownMenuItem<NameValue>> _metadataDropDownMenuList = [];
    {
      SplayTreeSet<NameValue> nameValues = SplayTreeSet();
      nameValues.add(allSongsMetadataNameValue); // default all value
      for (var songIdMetadata in SongMetadata.idMetadata) {
        for (var nameValue in songIdMetadata.nameValues) {
          nameValues.add(nameValue);
        }
      }
      for (var nameValue in nameValues) {
        if (nameValue.name == holidayMetadataNameValue.name) {
          continue;
        }
        _metadataDropDownMenuList.add(DropdownMenuItem<NameValue>(
          value: nameValue,
          child: Text('${nameValue.name}: ${nameValue.value}'),
          onTap: () {
            setState(() {
              _selectedListNameValue = nameValue;
              _refilterSongs();
            });
          },
        ));
      }
    }

    //  find the last selected song
    if (_filteredSongs.contains(_lastSelectedSong)) {
      var index = _filteredSongs.toList(growable: false).indexOf(_lastSelectedSong!);
      _itemScrollController.jumpTo(index: index);
      _rollIndex = index;
      logger.d('index $index: $_lastSelectedSong');
    } else {
      _lastSelectedSong = null;
    }

    var _aboutKey = const ValueKey<String>('About');
    var _clearSearchKey = const ValueKey<String>('clearSearch');

    return Scaffold(
      key: _scaffoldKey,
      appBar: appWidget.appBar(
        title: widget.title,
        key: const ValueKey('hamburger'),
        leading: appTooltip(
          message: MaterialLocalizations.of(context).openAppDrawerTooltip,
          child: TextButton(
              onPressed: () {
                _openDrawer();
              },
              child: const Icon(Icons.menu, color: Colors.white)),
        ),
        actions: <Widget>[
          appTooltip(
            message: "Visit bsteele.com, the provider of this app.",
            child: InkWell(
              onTap: () {
                openLink('http://www.bsteele.com');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: const Image(
                  image: AssetImage('lib/assets/runningMan.png'),
                  width: kToolbarHeight,
                  height: kToolbarHeight,
                  semanticLabel: "bsteele.com website",
                ),
              ),
            ),
          ),
          appTooltip(
            message: "Visit Community Jams, the motivation and main user for this app.",
            child: InkWell(
              onTap: () {
                openLink('http://communityjams.org');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: const Image(
                  image: AssetImage('lib/assets/cjLogo.png'),
                  width: kToolbarHeight,
                  height: kToolbarHeight,
                  semanticLabel: "community jams",
                ),
              ),
            ),
          ),
        ],
      ),

      drawer: Drawer(
        child: ListView(
          padding: const EdgeInsets.all(4.0),
          children: <Widget>[
            Container(
              height: 50,
            ), //  filler for notched phones
            ListTile(
              title: Text(
                "Options",
                style: _navTextStyle,
              ),
              onTap: () {
                _navigateToOptions(context);
              },
            ),
            if (_app.isEditReady) //  no files on phones!
              ListTile(
                title: Text(
                  "Songs",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToSongs(context);
                },
              ),
            if (_app.isEditReady)
              ListTile(
                title: Text(
                  "Lists",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToLists(context);
                },
              ),
            if (!_app.screenInfo.isTooNarrow)
              ListTile(
                title: Text(
                  "Theory",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToTheory(context);
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
                "Docs",
                style: _navTextStyle,
              ),
              onTap: () {
                _navigateToDocumentation(context);
              },
            ),
            ListTile(
              key: _aboutKey,
              title: Text(
                _aboutKey.value,
                style: _navTextStyle,
              ),
              //trailing: Icon(Icons.arrow_forward),
              onTap: () {
                WidgetLog.tap(_aboutKey);
                _navigateToAbout(context);
              },
            ),
          ],
        ),
      ),

      /// Navigate to song player when song tapped.
      body: Column(children: <Widget>[
        appWrapFullWidth([
          appWrap([
            appTooltip(
              message: 'Enter search text here.\n Title, artist and cover artist will be searched.',
              child: IconButton(
                icon: const Icon(Icons.search),
                iconSize: fontSize,
                onPressed: (() {
                  setState(() {
                    _searchSongs(_searchTextFieldController.text);
                  });
                }),
              ),
            ),
            SizedBox(
              width: 10 * _titleBarFontSize,
              //  limit text entry display length
              child: TextField(
                key: const ValueKey('searchText'),
                //  for testing
                controller: _searchTextFieldController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: "enter search text",
                  hintStyle: searchTextStyle,
                ),
                autofocus: true,
                style: titleTextStyle,
                onChanged: (text) {
                  setState(() {
                    logger.v('search text: "$text"');
                    _searchSongs(_searchTextFieldController.text);
                  });
                },
              ),
            ),
            appTooltip(
                message: _searchTextFieldController.text.isEmpty ? 'Scroll the list some.' : 'Clear the search text.',
                child: IconButton(
                  key: _clearSearchKey,
                  icon: const Icon(Icons.clear),
                  iconSize: 1.5 * fontSize,
                  onPressed: (() {
                    WidgetLog.tap(_clearSearchKey);
                    _searchTextFieldController.clear();
                    setState(() {
                      FocusScope.of(context).requestFocus(_searchFocusNode);
                      _lastSelectedSong = null;
                      _searchSongs(null);
                    });
                  }),
                )),
          ]),
          appWrap([
            appTooltip(
              message: 'Select the order of the song list.',
              child: Text(
                'Order',
                style: searchDropDownStyle,
              ),
            ),
            appSpace(),
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
              alignment: Alignment.topLeft,
              elevation: 8,
            ),
          ]),
          if (!_appOptions.holiday)
            appWrap([
              appTooltip(
                message: 'Select which song list to show.',
                child: Text(
                  'List',
                  style: searchDropDownStyle,
                ),
              ),
              appSpace(),
              DropdownButton<NameValue>(
                items: _metadataDropDownMenuList,
                onChanged: (value) {
                  logger.v('metadataDropDownMenuList selection: $value');
                },
                value: _selectedListNameValue ?? allSongsMetadataNameValue,
                style: searchDropDownStyle,
                elevation: 8,
              ),
            ]),
        ], alignment: WrapAlignment.spaceBetween),
        if (listViewChildren.isNotEmpty) //  ScrollablePositionedList messes up otherwise
          Expanded(
              child: ScrollablePositionedList.builder(
            itemCount: listViewChildren.length,
            itemScrollController: _itemScrollController,
            itemBuilder: (context, index) {
              return listViewChildren[Util.limit(index, 0, listViewChildren.length) as int];
            },
          )),
      ]),

      floatingActionButton: appTooltip(
        message: 'Back to the list top',
        child: FloatingActionButton(
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
          child: const Icon(
            Icons.arrow_upward,
          ),
        ),
      ),
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  // void _closeDrawer() {
  //   Navigator.of(context).pop();
  // }

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

    logger.d('_selectedListNameValue: $_selectedListNameValue');

    //  apply search filter
    _filteredSongs = SplayTreeSet(compare);
    for (final Song song in _app.allSongs) {
      if (search.isEmpty ||
          song.getTitle().toLowerCase().contains(search) ||
          song.getArtist().toLowerCase().contains(search)) {
        //  if holiday and song is holiday, we're good
        if (_appOptions.holiday) {
          if (isHoliday(song)) {
            _filteredSongs.add(song);
          }
          continue; //  toss the others
        } else
        //  if song is holiday and we're not, nope
        if (isHoliday(song)) {
          continue;
        }

        //  otherwise try some other qualification
        if (_selectedListNameValue != null && _selectedListNameValue != allSongsMetadataNameValue) {
          {
            var found = SongMetadata.where(idIs: song.songId.songId, nameValue: _selectedListNameValue);
            if (found.isNotEmpty) {
              logger.d('found: ${song.songId.songId}: $found');
            }
            if (found.isEmpty) {
              continue; //  not a match
            }
          }
        }

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

  bool isHoliday(Song song) {
    return holidayRexExp.hasMatch(song.title) ||
        holidayRexExp.hasMatch(song.artist) ||
        holidayRexExp.hasMatch(song.coverArtist);
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

  void _navigateToSongs(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Songs()),
    );

    Navigator.pop(context);
    _reApplySearch();
  }

  void _navigateToLists(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Lists()),
    );

    Navigator.pop(context);
    _reApplySearch();
  }

  void _reApplySearch() {
    setState(() {
      _selectSearchText(context); //  select all text on a navigation pop
      _refilterSongs();
    });
  }

  void _selectSearchText(BuildContext context) {
    _searchTextFieldController.selection =
        TextSelection(baseOffset: 0, extentOffset: _searchTextFieldController.text.length);
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  _navigateToPlayer(BuildContext context, Song song) async {
    if (song.getTitle().isEmpty) {
      return;
    }

    _app.selectedSong = song;
    _lastSelectedSong = song;

    await Navigator.pushNamed(
      context,
      Player.routeName,
    );

    _reApplySearch();
  }

  _navigateToOptions(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      Options.routeName,
    );
    Navigator.pop(context);
    _reApplySearch();
  }

  _navigateToAbout(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const About()),
    );
    Navigator.pop(context);
    _reApplySearch();
  }

  _navigateToDocumentation(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Documentation()),
    );
    Navigator.pop(context);
    _reApplySearch();
  }

  _navigateToTheory(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TheoryWidget()),
    );
    Navigator.pop(context);
    _reApplySearch();
  }

  _navigateToPrivacyPolicy(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Privacy()),
    );
    Navigator.pop(context);
    _reApplySearch();
  }

  final List<DropdownMenuItem<_SortType>> _sortTypesDropDownMenuList = [];
  var _selectedSortType = _SortType.byTitle;

  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode;
  NameValue? _selectedListNameValue;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final Duration _itemScrollDuration = const Duration(milliseconds: 500);
  int _rollIndex = -1;

  AppOptions _appOptions;
  Song? _lastSelectedSong;

  final AppWidget appWidget = AppWidget();

  final _random = Random();
  static final RegExp holidayRexExp = RegExp(holidayMetadataNameValue.name, caseSensitive: false);
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
