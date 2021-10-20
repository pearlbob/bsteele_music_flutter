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
import 'package:bsteele_music_flutter/screens/cssDemo.dart';
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
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock/wakelock.dart';

import 'app/app.dart';
import 'app/appOptions.dart';
import 'app/app_theme.dart';
import 'util/openLink.dart';

const _environmentDefault = 'main';
const _environment = String.fromEnvironment('environment', defaultValue: _environmentDefault);
const _testCss = String.fromEnvironment('css', defaultValue: 'app.css');
final userName = Platform.environment['USER'] ?? Platform.environment['LOGNAME'] ?? 'unknown';

void main() async {
  Logger.level = Level.info;

  //  read the css theme data prior to the first build
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme().init(css: _testCss); //  init the singleton

  //  run the app
  runApp(
    BSteeleMusicApp(),
  );
}

/*
//  fixme: title on player, always
//  fixme: edit: delete section
//  fixme: edit: measure entry should allow section header declarations
//  fixme: verify in studio:  let it be in C, cramped on HDMI on mac,
//  fixme: on mac + chrome: bold musical flat sign is way ugly
//  fixme: player chord display elevations trash on mac, b, minor, slash notes
//  fixme: util: beginner list songlist to google doc format: title, artist, original key
//  fixme: delete metadata when reading file
//  fixme: lyrics under chords, css break between chord/lyrics and next chord/lyrics
//  fixme: Gb argument vs F#   with a disclaimer!!!!
//  fixme: baseline wrong on chrome on mac
//  fixme: beta: lyrics in one block area
//  fixme: align all repeats in a single column of the edit screen
//  fixme: add phrase before first repeat in edit screen section
//  fixme: add phrase between repeats in edit screen
//  fixme: can't add repeats
//  fixme: can't add phrase after a repeat
//  fixme: edit: recent chords
//  fixme: edit lyrics entry rows should align to chord rows as they will in the player display
//  fixme: "I'll Take You There" by "Staple Singers, The": maxLength: 107
//  fixme: first leader selection not shown
//  fixme: show header if first section, even in play
//  fixme: full screen option
//  fixme: crash on edit clear
//  fixme: can't append a phrase (measure) after a repeat in edit
//  fixme: escape on main page, linux
//  fixme: edit speed issues?
//  fixme: joy to the world, sheet music, measure size error
//  fixme: edit screen: section id is inline on chords, but above in lyrics
//  fixme: after an edit change, don't allow navigator pop without admission that edits will be lost
//  fixme: song diff page
//  fixme: surrender leadership when leader song update appears
//  fixme: space in title entry jumps to lyrics Section
//  fixme: singer mode: first measure after the section

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

SplayTreeSet<Song> _filteredSongs = SplayTreeSet();

const _searchTextTooltipText = 'Enter search text here.\n Title, artist and cover artist will be searched.';

/// Song list sort types
enum MainSortType {
  byTitle,
  byArtist,
  byLastChange,
  byComplexity,
}

/// Display the list of songs to choose from.
class BSteeleMusicApp extends StatelessWidget {
  BSteeleMusicApp({Key? key}) : super(key: key) {
    Logger.level = Level.info;
    if (kIsWeb) {
      Wakelock.enable(); //  avoid device timeouts!
    }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppOptions>(
        create: (_) => AppOptions(),
        builder: (context, _) => MaterialApp(
              title: 'bsteele Music App',
              theme: app.themeData,
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
                '/edit': (context) => Edit(initialSong: app.selectedSong),
                '/privacy': (context) => const Privacy(),
                '/documentation': (context) => const Documentation(),
                '/about': (context) => const About(),
                '/cssDemo': (context) => const CssDemo(),
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
        appOptions = AppOptions();

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

    _searchTextFieldController.addListener(() {
      appTextFieldListener(AppKeyEnum.mainSearchText, _searchTextFieldController);
    });

    //logger.i('uri: ${Uri.base}, ${Uri.base.queryParameters.keys.contains('follow')}');
  }

  void _readInternalSongList() async {
    {
      String songListAsString = await loadString('lib/assets/allSongs.songlyrics');
      try {
        app.removeAllSongs();
        app.addSongs(Song.songListFromJson(songListAsString));
        try {
          app.selectedSong = _filteredSongs.first;
        } catch (e) {
          app.selectedSong = app.emptySong;
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
    if (appOptions.isInThePark()) {
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
        app.removeAllSongs();
        app.addSongs(Song.songListFromJson(allSongsAsString));
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
    logger.d('main build: ${app.selectedSong}');

    appOptions = Provider.of<AppOptions>(context);

    app.screenInfo = ScreenInfo(context); //  dynamically adjust to screen size changes  fixme: should be event driven

    final _titleBarFontSize = app.screenInfo.fontSize;

    //  figure the configuration when the values are established
    app.isEditReady = (kIsWeb
            //  if is web, Platform doesn't exist!  not evaluated here in the expression
            ||
            Platform.isLinux ||
            Platform.isMacOS ||
            Platform.isWindows) &&
        !app.screenInfo.isTooNarrow;
    logger.v('isEditReady: $app.isEditReady');

    app.isScreenBig = app.isEditReady || !app.screenInfo.isTooNarrow;
    app.isPhone = !app.isScreenBig;

    logger.v('screen: logical: (${app.screenInfo.widthInLogicalPixels},${app.screenInfo.heightInLogicalPixels})');
    logger.v('isScreenBig: $app.isScreenBig, isPhone: $app.isPhone');

    final TextStyle searchTextStyle = generateAppTextStyle(
      color: Colors.black45,
      fontWeight: FontWeight.bold,
      textBaseline: TextBaseline.alphabetic,
    );
    final TextStyle searchDropDownStyle = generateAppTextStyle(
      fontWeight: FontWeight.normal,
      textBaseline: TextBaseline.alphabetic,
    );
    final TextStyle titleTextStyle = generateAppTextStyle(
      fontWeight: FontWeight.bold,
      textBaseline: TextBaseline.alphabetic,
      color: Colors.black,
    );
    final TextStyle titleTextFieldStyle = generateAppTextFieldStyle(
      fontWeight: FontWeight.bold,
      textBaseline: TextBaseline.alphabetic,
      color: Colors.black,
    );
    final fontSize = searchTextStyle.fontSize ?? 25;
    logger.d('fontSize: $fontSize in ${app.screenInfo.widthInLogicalPixels} px');

    final TextStyle artistTextStyle = titleTextStyle.copyWith(fontWeight: FontWeight.normal);
    final TextStyle _navTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);

    //  generate the sort selection
    _sortTypesDropDownMenuList.clear();
    for (final e in MainSortType.values) {
      var s = e.toString();
      _sortTypesDropDownMenuList.add(appDropdownMenuItem<MainSortType>(
        appKeyEnum: AppKeyEnum.mainSortTypeSelection,
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
    {
      bool oddEven = true;
      final oddTitle = oddTitleText(from: titleTextStyle);
      final evenTitle = evenTitleText(from: titleTextStyle);
      final oddText = oddTitleText(from: artistTextStyle);
      final evenText = evenTitleText(from: artistTextStyle);
      logger.d('_filteredSongs.length: ${_filteredSongs.length}');

      for (final Song song in _filteredSongs) {
        oddEven = !oddEven;
        var oddEvenTitleTextStyle = oddEven ? oddTitle : evenTitle;
        var oddEvenTextStyle = oddEven ? oddText : evenText;
        logger.v('song.songId: ${song.songId}');
        listViewChildren.add(appGestureDetector(
          appKeyEnum: AppKeyEnum.mainSong,
          value: Id(song.songId.toString()),
          child: Container(
            color: oddEvenTitleTextStyle.backgroundColor,
            padding: const EdgeInsets.all(8.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              if (app.isScreenBig)
                appWrapFullWidth(
                  <Widget>[
                    appWrap(
                      <Widget>[
                        Text(
                          song.title,
                          style: oddEvenTitleTextStyle,
                        ),
                        Text(
                          '      ' + song.getArtist(),
                          style: oddEvenTextStyle,
                        ),
                      ],
                    ),
                    Text(
                      '   ' +
                          intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime)),
                      style: oddEvenTextStyle,
                    ),
                  ],
                  alignment: WrapAlignment.spaceBetween,
                ),
              if (app.isPhone)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      song.title,
                      style: oddEvenTitleTextStyle,
                    ),
                    Text(
                      '      ' + song.getArtist(),
                      style: oddEvenTextStyle,
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
          child: Text(
            '${nameValue.name}: ${nameValue.value}',
            style: searchDropDownStyle,
          ),
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

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      key: _scaffoldKey,
      appBar: AppWidgetHelper(context).appBar(
        title: widget.title,
        leading: appTooltip(
          message: MaterialLocalizations.of(context).openAppDrawerTooltip,
          child: appIconButton(
            appKeyEnum: AppKeyEnum.mainHamburger,
            onPressed: _openDrawer,
            icon: appIcon(
              Icons.menu, size: app.screenInfo.fontSize, //  fixme: why is this required?
            ),
          ),
        ),
        actions: <Widget>[
          if (!app.screenInfo.isWayTooNarrow)
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
          if (!app.screenInfo.isWayTooNarrow)
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
            appListTile(
              appKeyEnum: AppKeyEnum.mainDrawerOptions,
              title: Text(
                "Options",
                style: _navTextStyle,
              ),
              onTap: () {
                _navigateToOptions(context);
              },
            ),
            if (app.isEditReady) //  no files on phones!
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerSongs,
                title: Text(
                  "Songs",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToSongs(context);
                },
              ),
            if (app.isEditReady)
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerLists,
                title: Text(
                  "Lists",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToLists(context);
                },
              ),
            if (!app.screenInfo.isTooNarrow)
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerTheory,
                title: Text(
                  "Theory",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToTheory(context);
                },
              ),
            appListTile(
              appKeyEnum: AppKeyEnum.mainDrawerPrivacy,
              title: Text(
                "Privacy",
                style: _navTextStyle,
              ),
              //trailing: Icon(Icons.arrow_forward),
              onTap: () {
                _navigateToPrivacyPolicy(context);
              },
            ),
            appListTile(
              appKeyEnum: AppKeyEnum.mainDrawerDocs,
              title: Text(
                "Docs",
                style: _navTextStyle,
              ),
              onTap: () {
                _navigateToDocumentation(context);
              },
            ),
            if (kDebugMode)
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerCssDemo,
                title: Text(
                  "CSS Demo",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToCssDemo(context);
                },
              ),
            appListTile(
              appKeyEnum: AppKeyEnum.mainDrawerAbout,
              title: Text(
                'About',
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
        appWrapFullWidth([
          appWrap([
            appTooltip(
              message: _searchTextTooltipText,
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
              width: 14 * _titleBarFontSize,
              //  limit text entry display length
              child: TextField(
                key: appKey(AppKeyEnum.mainSearchText),
                //  for testing
                controller: _searchTextFieldController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'enter search text',
                  hintStyle: searchTextStyle,
                ),
                autofocus: true,
                style: titleTextFieldStyle,
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
                child: appEnumeratedIconButton(
                  icon: const Icon(Icons.clear),
                  appKeyEnum: AppKeyEnum.mainClearSearch,
                  iconSize: 1.5 * fontSize,
                  onPressed: (() {
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
            DropdownButton<MainSortType>(
              items: _sortTypesDropDownMenuList,
              onChanged: (value) {
                if (_selectedSortType != value) {
                  setState(() {
                    _selectedSortType = value ?? MainSortType.byTitle;
                    _searchSongs(_searchTextFieldController.text);
                  });
                }
              },
              value: _selectedSortType,
              style: searchDropDownStyle,
              alignment: Alignment.topLeft,
              elevation: 8,
              itemHeight: null,
            ),
          ]),
          if (!appOptions.holiday)
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
                itemHeight: null,
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
        child: appFloatingActionButton(
          appKeyEnum: AppKeyEnum.mainUp,
          onPressed: () {
            if (_itemScrollController.isAttached) {
              _itemScrollController.scrollTo(
                index: 0,
                curve: Curves.easeOut,
                duration: const Duration(milliseconds: 500),
              );
            }
          },
          child: appIcon(
            Icons.arrow_upward,
          ),
          mini: !app.isScreenBig,
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
      case MainSortType.byArtist:
        compare = (Song song1, Song song2) {
          var ret = song1.artist.compareTo(song2.artist);
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byLastChange:
        compare = (Song song1, Song song2) {
          var ret = -song1.lastModifiedTime.compareTo(song2.lastModifiedTime);
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byComplexity:
        compare = (Song song1, Song song2) {
          var ret = song1.getComplexity().compareTo(song2.getComplexity());
          if (ret != 0) {
            return ret;
          }
          return song1.compareTo(song2);
        };
        break;
      case MainSortType.byTitle:
      default:
        compare = (Song song1, Song song2) {
          return song1.compareTo(song2);
        };
        break;
    }

    logger.d('_selectedListNameValue: $_selectedListNameValue');

    //  apply search filter
    _filteredSongs = SplayTreeSet(compare);
    for (final Song song in app.allSongs) {
      if (search.isEmpty ||
          song.getTitle().toLowerCase().contains(search) ||
          song.getArtist().toLowerCase().contains(search)) {
        //  if holiday and song is holiday, we're good
        if (appOptions.holiday) {
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
    } else if (_filteredSongs.isNotEmpty && _selectedSortType == MainSortType.byTitle) {
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
    logger.v('_selectSearchText: ${_searchTextFieldController.selection}');
  }

  _navigateToPlayer(BuildContext context, Song song) async {
    if (song.getTitle().isEmpty) {
      return;
    }

    app.selectedSong = song;
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

  _navigateToCssDemo(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CssDemo()),
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

  final List<DropdownMenuItem<MainSortType>> _sortTypesDropDownMenuList = [];
  var _selectedSortType = MainSortType.byTitle;

  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode;
  NameValue? _selectedListNameValue;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final Duration _itemScrollDuration = const Duration(milliseconds: 500);
  int _rollIndex = -1;

  AppOptions appOptions;
  Song? _lastSelectedSong;

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
