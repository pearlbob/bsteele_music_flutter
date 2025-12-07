/// # The bsteeleMusicApp.
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
/// * Use of Theme vs home grown 'app' methods
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
library;

import 'dart:async';
import 'dart:convert';

import 'package:bsteele_music_flutter/screens/about.dart';

import 'package:bsteele_music_flutter/screens/debug.dart';
import 'package:bsteele_music_flutter/screens/documentation.dart';
import 'package:bsteele_music_flutter/screens/drum_screen.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/leader.dart';
import 'package:bsteele_music_flutter/screens/metadata.dart';
import 'package:bsteele_music_flutter/screens/options.dart';
import 'package:bsteele_music_flutter/screens/performanceHistory.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/screens/privacy.dart';
import 'package:bsteele_music_flutter/screens/singers.dart';
import 'package:bsteele_music_flutter/screens/songs.dart';
import 'package:bsteele_music_flutter/screens/styleDemo.dart';
import 'package:bsteele_music_flutter/screens/theory.dart';
import 'package:bsteele_music_flutter/util/play_list_search_matcher.dart';
import 'package:bsteele_music_flutter/util/song_update_service.dart';
import 'package:bsteele_music_lib/app_logger.dart';
import 'package:bsteele_music_lib/songs/drum_measure.dart';
import 'package:bsteele_music_lib/songs/song.dart';
import 'package:bsteele_music_lib/songs/song_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

import 'app/app.dart';
import 'app/appOptions.dart';
import 'app/app_theme.dart';
import 'util/openLink.dart';

/*
linux start size and location:
in linux/my_application.cc, line 50 or so
  gtk_window_set_default_size(window, 1920, 1080);
  gtk_window_move(window, 50, 350);
 */

/*
android fix:
  adb: insufficient permissions for device: missing udev rules? user is in the plugdev group

  settings, system,  Developer options,  usb debugging on
  https://developer.android.com/studio/run/device
    sudo usermod -aG plugdev $LOGNAME
    sudo apt-get install android-sdk-platform-tools-common

in bsteele_music_flutter/android/app/src/main/AndroidManifest.xml:
<manifest...>
  <uses-permission android:name="android.permission.INTERNET"/>
  ...

</manifest...>


Fix this issue by using the highest Android NDK version (they are backward compatible).
Add the following to /home/bob/github/bsteele_music_flutter/android/app/build.gradle.kts:

    android {
        ndkVersion = "27.0.12077973"
        ...
    }


gradle updates:
    edit:  bsteele_music_flutter/android/gradle/wrapper/gradle-wrapper.properties
    choose distributionUrl from:  https\://services.gradle.org/distributions
 */

/*
  flutter pub deps
  dart pub deps
 */

/*  required macos entitlements!
  macos/Runner/DebugProfile.entitlements and macos/Runner/Release.entitlements need:
  <dict> ...
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
 */

/*
macos/Runner/Base.lproj/MainMenu.xib:
<rect key="contentRect" x="30" y="30" width="1400" height="880"/>
 */

/*
apparently cocoapods is not from brew:
error cocoapods not installed or not in valid state. flutter

sudo gem install cocoapods
 */

/*
if project abused by android studio:
close intellij idea
rm -rf .idea
re-open project in idea
 */

//  diagnostic logging enables
//  global regex search:       const Level _.* = Level\.info;
//  global regex search:       logger.i\(
const Level _logBuild = Level.debug;

String host = Uri.base.host;
Uri uri = Uri.parse(Uri.base.toString().replaceFirst(RegExp(r'#.*'), ''));
final bool isBeta = uri.toString().contains('/beta/'); // only works on web
bool hostIsWebsocketHost = false;
const _environmentDefault = 'main';
// --dart-define=environment=test
const _environment = String.fromEnvironment('environment', defaultValue: _environmentDefault);
late PackageInfo packageInfo;

void main() async {
  Logger.level = kDebugMode ? Level.info : Level.warning;

  if (kDebugMode) {
    debugProfileBuildsEnabled = true;
    debugProfileBuildsEnabledUserWidgets = true;
    // debugProfilePaintsEnabled= false;
    // debugProfileLayoutsEnabled = false;
  }

  //  prior to the first build
  WidgetsFlutterBinding.ensureInitialized().scheduleWarmUpFrame();
  await appOptions.init(); //  initialize the options from the stored values

  //  use the webserver's host as the websocket server if appropriate
  if (host
          .isEmpty //  likely a native app
          ||
      host ==
          'www.bsteele.com' //  websocket will never be provided by the cloud server
          ||
      (host == 'localhost' && uri.port != 8080) //  defend against the debugger
      ) {
    //  do nothing!
    hostIsWebsocketHost = false;
  } else {
    //  default to the expected websocket server
    appOptions.websocketHost = host; //  auto-magically choose the local websocket server
    hostIsWebsocketHost = true;
  }

  //  read the local drum parts list
  DrumPartsList drumPartsList = DrumPartsList();
  drumPartsList.fromJson(appOptions.drumPartsListJson);
  drumPartsList.addDefaults();

  await AppTheme().init(); //  init the singleton
  packageInfo = await PackageInfo.fromPlatform();

  //  run the app
  runApp(const BSteeleMusicApp());
}

/*
C's ipad: model ML0F2LL/A

what is debugPrint

linux notes:
build release:
% flutter build linux
executable (without assets) is in ./build/linux/release/bundle/${project}


song
  title, artist, cover-artist, key, bpm, time signature
  chords
  lyrics
  display grid
    user type: pro, player, player singer, singer
    grid
      grid item
        item type: (measure node?) section, empty, measure, measure marker, lyric
        moment number, nullable
        lyric section
        lyric section number
        lyrics
          lines
            moment number
            chord row first moment
          by beat
          syllables
        grid coordinates (r,c), identical to widget grid
    moments
      moment
        moment number
        measure
          chords
            chord, beat count
              scale note, chord descriptor, slash note, anticipation
        section moment number (first measure)
        chord section
        phrase index
        measure index
        accompaniments
          accompaniment
            type
            sheet notes
        time from start in seconds
        duration
    widget grid
      widget
        grid coordinates (r,c), identical to grid
        widget coordinates (x,y)
        grid item

map time to moment
map moment to grid

 */

/// Display the master list of songs to choose from.
class BSteeleMusicApp extends StatelessWidget {
  const BSteeleMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    logger.i('main: build()');

    const mainList = 'mainList';

    return MultiProvider(
      providers: [
        //  has to be a widget level above it's use
        ChangeNotifierProvider<PlayListRefreshNotifier>(create: (_) => PlayListRefreshNotifier()),
      ],
      builder: (context, child) {
        return MaterialApp(
          title: 'bsteeleMusicApp',
          theme: app.themeData,
          navigatorObservers: [playerRouteObserver],

          // Start the app with the '/' named route. In this case, the app starts
          // on the FirstScreen widget.
          initialRoute: mainList,
          routes: {
            // When navigating to the '/' route, build the FirstScreen widget.
            // '/': (context) => BSteeleMusicApp(),
            // When navigating to the '/second' route, build the SecondScreen widget.
            mainList: (context) => const MyHomePage(title: 'bsteeleMusicApp'),
            Player.routeName: playerPageRoute.builder,
            Leader.routeName: leaderPageRoute.builder,
            Options.routeName: (context) => const Options(),
            Songs.routeName: (context) => const Songs(),
            Singers.routeName: (context) => const Singers(),
            MetadataScreen.routeName: (context) => const MetadataScreen(),
            Edit.routeName: (context) => Edit(initialSong: app.selectedSong),
            PerformanceHistory.routeName: (context) => const PerformanceHistory(),
            Privacy.routeName: (context) => const Privacy(),
            Documentation.routeName: (context) => const Documentation(),
            Debug.routeName: (context) => const Debug(),
            About.routeName: (context) => const About(),
            StyleDemo.routeName: (context) => const StyleDemo(),
            TheoryWidget.routeName: (context) => const TheoryWidget(),
            DrumScreen.routeName: (context) => DrumScreen(song: app.selectedSong, isEditing: true),
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, this.title = 'unknown'});

  // This widget is the home page of the application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  //  Fields in a Widget subclass are always marked 'final'.

  final String title;

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _awaitReadSongList();

    logger.i('Uri.base: "${Uri.base}", "${Uri.base.query}"');
    logger.t('Uri.base.queryParameters.keys.length: ${Uri.base.queryParameters.keys.length}');
    for (var key in Uri.base.queryParameters.keys) {
      logger.i('    key: "$key", value: "${Uri.base.queryParameters[key]}"');
    }
  }

  void _awaitReadSongList() async {
    await _readSongList();
    setState(() {});
  }

  Future<void> _readSongList() async {
    //  normally read external (web) song list and setup the websocket
    if (_environment == _environmentDefault) {
      AppSongUpdateService.open(context);
      await _readExternalSongList();
    } else {
      //  testing:  read the internal list
      await _readInternalSongList();
    }

    //  give the beta warning
    if (isBeta && Uri.base.queryParameters.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _betaWarningPopup();
      });
    }
  }

  Future<void> _readInternalSongList() async {
    {
      setState(() {
        app.infoMessage = 'Loading internal song list';
      });

      var allSongsAsset = 'lib/assets/allSongs.songlyrics';
      String songListAsString = await loadAssetString(allSongsAsset);
      try {
        app.removeAllSongs();
        app.addSongs(Song.songListFromJson(songListAsString));
        app.warningMessage = 'internal songList used, dated: ${await app.releaseUtcDate()}';
      } catch (fe) {
        logger.i('internal songList parse error: $fe');
      }
    }
    {
      String songMetadataAsString = await loadAssetString('lib/assets/allSongs.songmetadata');

      try {
        SongMetadata.fromJson(songMetadataAsString);
        logger.i('internal song metadata used');
      } catch (fe) {
        logger.i('internal song metadata parse error: $fe');
      }
    }
    {
      String dataAsString = await loadAssetString('lib/assets/allSongPerformances.songperformances');

      try {
        var allSongPerformances = appOptions.allSongPerformances;
        allSongPerformances.updateFromJsonString(dataAsString);
        allSongPerformances.loadSongs(app.allSongs);
        logger.i('internal song performances used');
      } catch (fe) {
        logger.i('internal song performance parse error: $fe');
      }
    }
  }

  Future<void> _readExternalSongList() async {
    var externalHost =
        '${host.isEmpty //
            ? 'www.bsteele.com' //  likely a native app with web access
              : '$host:${uri.port}' //  port for potential app server
              }/bsteeleMusicApp';

    {
      final String urlString = 'http://$externalHost/allSongs.songlyrics';
      // setState(() {
      //   app.infoMessage = 'Loading song list from cloud';
      // });
      String allSongsAsString;
      try {
        allSongsAsString = await fetchString(urlString);
      } catch (e) {
        logger.i("read of url: '$urlString' failed: ${e.toString()}");
        await _readInternalSongList();
        return;
      }

      try {
        app.removeAllSongs();
        app.addSongs(Song.songListFromJson(allSongsAsString));
        //  don't warn on standard behavior:   app.warningMessage = 'SongList read from: $url';
      } catch (fe) {
        logger.i('external songList parse error: $fe');
        await _readInternalSongList();
      }
    }
    {
      final String url = 'http://$externalHost/allSongs.songmetadata';
      String metadataAsString;
      // setState(() {
      //   app.infoMessage = 'Loading metadata';
      // });
      try {
        metadataAsString = await fetchString(url);
      } catch (e) {
        logger.i("read of url: '$url' failed: ${e.toString()}");
        await _readInternalSongList();
        return;
      }

      try {
        SongMetadata.fromJson(metadataAsString);
        logger.i('external song metadata read from: $url');
      } catch (fe) {
        logger.i('external song metadata parse error: $fe');
      }
    }

    {
      final String url = 'http://$externalHost/allSongPerformances.songperformances';
      // setState(() {
      //   app.infoMessage = 'Loading history';
      // });

      String dataAsString;
      try {
        dataAsString = await fetchString(url);
      } catch (e) {
        app.warningMessage = 'read of url: "$url" failed: ${e.toString()}';
        await _readInternalSongList();
        return;
      }

      try {
        appOptions.allSongPerformances.updateFromJsonString(dataAsString);
        var allSongs = app.allSongs;
        var corrections = appOptions.allSongPerformances.loadSongs(allSongs);
        logger.i('external song performances read from: $url, corrections: $corrections');

        //  it's very important to store corrected performances/history/requests locally
        //  so they are not corrected at every reload
        appOptions.storeAllSongPerformances();
      } catch (fe) {
        app.warningMessage = 'Loading of history failed.';
        logger.i('external song performance parse error: $fe');
      }
    }
    app.clearMessage();
  }

  @override
  Widget build(BuildContext context) {
    app.screenInfo.refresh(context);

    logger.log(
      _logBuild,
      'main build: ${app.selectedSong}'
      ', ModalRoute: ${ModalRoute.of(context)?.settings.name}',
    );

    //  figure the configuration when the values are established
    app.isEditReady =
        (kIsWeb
            //  if is web, Platform doesn't exist!  not evaluated here in the expression
            ||
            Platform.isLinux ||
            Platform.isMacOS ||
            Platform.isWindows) &&
        !app.screenInfo.isTooNarrow;
    logger.t('isEditReady: $app.isEditReady');

    app.isScreenBig = app.isEditReady || !app.screenInfo.isTooNarrow;
    app.isPhone = !app.isScreenBig;

    logger.t('screen: logical: (${app.screenInfo.mediaWidth},${app.screenInfo.mediaHeight})');
    logger.t('isScreenBig: $app.isScreenBig, isPhone: $app.isPhone');

    final TextStyle searchTextStyle = generateAppTextStyle(
      color: Colors.black45,
      fontWeight: .bold,
      textBaseline: TextBaseline.alphabetic,
    );
    _titleTextStyle = generateAppTextStyle(
      fontWeight: .bold,
      textBaseline: TextBaseline.alphabetic,
      color: Colors.black,
    );
    final fontSize = searchTextStyle.fontSize ?? 25;
    logger.d('fontSize: $fontSize in ${app.screenInfo.mediaWidth} px');

    final TextStyle navTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      key: _scaffoldKey,
      appBar: AppWidgetHelper(context).appBar(
        title: widget.title,
        leading: appIconButton(onPressed: _openDrawer, icon: appIcon(Icons.menu)),
        actions: <Widget>[
          if (!app.screenInfo.isWayTooNarrow)
            AppTooltip(
              message: 'Visit bsteele.com, the provider of this app.',
              child: InkWell(
                onTap: () {
                  openLink('http://www.bsteele.com');
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    color: Colors.white,
                  ),
                  child: const Image(
                    image: AssetImage('lib/assets/runningMan.png'),
                    width: kToolbarHeight,
                    height: kToolbarHeight,
                    semanticLabel: 'bsteele.com website',
                  ),
                ),
              ),
            ),
        ],
      ),

      drawer: appDrawer(
        voidCallback: _openDrawer,
        child: ListView(
          children: <Widget>[
            Container(height: 50), //  filler for notched phones
            appListTile(
              title: 'Options',
              style: navTextStyle,
              onTap: () {
                _navigateToOptions();
              },
            ),
            appListTile(
              title: 'Singers',
              style: navTextStyle,
              enabled: app.isEditReady,
              //  no files on phones!
              onTap: () {
                _navigateToSingers();
              },
            ),
            appListTile(
              title: 'History',
              style: navTextStyle,
              //trailing: Icon(Icons.arrow_forward),
              onTap: () {
                _navigateToPerformanceHistory();
              },
            ),
            //     if (app.isEditReady)
            appListTile(
              title: 'Songs',
              style: navTextStyle,
              enabled: app.isEditReady,
              //  no files on phones!
              onTap: () {
                _navigateToSongs();
              },
            ),

            appListTile(
              title: 'New Song',
              style: navTextStyle,
              enabled: app.isEditReady,
              //  no files on phones!
              onTap: () {
                _navigateToEdit();
              },
            ),
            appListTile(
              title: 'Drums',
              style: navTextStyle,
              enabled: app.isEditReady,
              onTap: () {
                _navigateToDrums();
              },
            ),
            appListTile(
              title: 'Theory',
              style: navTextStyle,
              enabled: !app.screenInfo.isTooNarrow,
              onTap: () {
                _navigateToTheory();
              },
            ),
            appListTile(
              title: 'Privacy',
              style: navTextStyle,
              //trailing: Icon(Icons.arrow_forward),
              onTap: () {
                _navigateToPrivacyPolicy();
              },
            ),
            // if (app.isScreenBig)
            appListTile(
              title: 'Docs',
              style: navTextStyle,
              enabled: app.isScreenBig,
              onTap: () {
                _navigateToDocumentation();
              },
            ),
            if (kDebugMode)
              appListTile(
                title: 'Style Demo',
                style: navTextStyle,
                onTap: () {
                  _navigateToStyleDemo();
                },
              ),
            appListTile(
              title: 'Metadata',
              style: navTextStyle,
              enabled: app.isEditReady,
              onTap: () {
                _navigateToMetadata();
              },
            ),

            // if (kDebugMode)
            //   appListTile(
            //     appKeyEnum: AppKeyEnum.mainDrawerDebug,
            //     title: 'Debug',
            //     style: navTextStyle,
            //     onTap: () {
            //       _navigateToDebug();
            //     },
            //   ),
            appListTile(
              title: 'Tutorial',
              style: navTextStyle,
              onTap: () {
                openLink('http://www.bsteele.com/bsteele_music_tutorial/index.html');
                Navigator.of(context).pop(); //  drawer
              },
            ),

            appListTile(
              title: 'Leader',
              style: navTextStyle,
              onTap: () {
                _navigateToAboutLeader();
              },
            ),

            appListTile(
              title: 'About',
              style: navTextStyle,
              //trailing: Icon(Icons.arrow_forward),
              onTap: () {
                _navigateToAbout();
              },
            ),
          ],
        ),
      ),

      /// Navigate to song player when song tapped.
      body: Column(
        crossAxisAlignment: .start,
        children: <Widget>[
          // if (kDebugMode)
          //   Container(
          //       padding: const EdgeInsets.all(6.0),
          //       child: AppWrap(
          //         spacing: 10,
          //         children: [
          //           appButton(
          //             'Test',
          //             appKeyEnum: AppKeyEnum.mainTest,
          //             onPressed: () {
          //               testAppKeyCallbacks();
          //             },
          //           ),
          //           appButton(
          //             'Stop',
          //             appKeyEnum: AppKeyEnum.mainTestStop,
          //             onPressed: () {
          //               logger.i('stop');
          //               testAppKeyCallbacksStop();
          //             },
          //           ),
          //         ],
          //       )),
          if (app.message.isNotEmpty) Container(padding: const EdgeInsets.all(6.0), child: app.messageTextWidget()),
          PlayList(
            itemList: PlayListItemList(
              '',
              app.allSongs.map((e) => SongPlayListItem.fromSong(e)).toList(growable: false),
              playListItemAction: _navigateToPlayerBySongItem,
            ),
            style: _titleTextStyle,
            isFromTheTop: false,
            playListSearchMatcher: SongPlayListSearchMatcher(),
          ),
        ],
      ),

      // floatingActionButton: AppTooltip(    //  fixme: move to playList?
      //   message: 'Back to the list top',
      //   child: appFloatingActionButton(
      //     appKeyEnum: AppKeyEnum.mainUp,
      //     onPressed: () {
      //       if (_itemScrollController.isAttached) {
      //         _itemScrollController.scrollTo(
      //           index: 0,
      //           curve: Curves.easeOut,
      //           duration: const Duration(milliseconds: 500),
      //         );
      //       }
      //     },
      //     child: appIcon(
      //       Icons.arrow_upward,
      //     ),
      //     mini: !app.isScreenBig,
      //   ),
      // ),
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  Future<void> _betaWarningPopup() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Do you really want test the beta version of the bsteeleMusicApp?',
          style: TextStyle(fontSize: 22, fontWeight: .bold),
        ),
        actions: [
          Column(
            children: [
              const Text(
                'This beta version is only for testing application development.\n'
                'bob can damage this version at any time, for any reason.\n'
                'Any remembered setup will not necessarily transfer to the real version.',
                style: TextStyle(fontSize: 22),
              ),
              const AppSpace(),
              appButton(
                'Send me to the release version.',
                onPressed: () {
                  var s = uri.toString();
                  s = s.substring(0, s.indexOf('beta'));
                  openLink(s);
                },
              ),
              const AppSpace(space: 50),
              appButton(
                'This is exciting! I will test the beta.',
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
        elevation: 24.0,
      ),
    );
  }

  // void _closeDrawer() {
  //   Navigator.of(context).pop();
  // }

  _navigateToPlayerBySongItem(BuildContext context, PlayListItem playListItem) async {
    if (playListItem is SongPlayListItem) {
      if (playListItem.song.title.isEmpty) {
        // logger.log(_mainLogScroll, 'song title is empty: $song');
        return;
      }
      app.clearMessage();
      app.selectedSong = playListItem.song;
      //_lastSelectedSong = song;

      //logger.log(_mainLogScroll, '_navigateToPlayer: pushNamed: $song');
      await Navigator.pushNamed(context, Player.routeName);

      setState(() {});
    }
  }

  void _navigateToSongs() async {
    await Navigator.pushNamed(context, Songs.routeName);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _navigateToMetadata() async {
    await Navigator.pushNamed(context, MetadataScreen.routeName);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();

    setState(() {
      //  read any metadata changes into the list
    });
  }

  _navigateToEdit() async {
    app.clearMessage();
    await Navigator.push(context, MaterialPageRoute(builder: (context) => Edit(initialSong: Song.createEmptySong())));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToOptions() async {
    await Navigator.pushNamed(context, Options.routeName);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
    app.clearMessage();
  }

  _navigateToSingers() async {
    await Navigator.pushNamed(context, Singers.routeName);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToPerformanceHistory() async {
    await Navigator.pushNamed(context, PerformanceHistory.routeName);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  // _navigateToDebug() async {
  //   app.clearMessage();
  //   await Navigator.push(
  //     context,
  //     MaterialPageRoute(builder: (context) => const Debug()),
  //   );
  //   if (!mounted) {
  //     return;
  //   }
  //   Navigator.of(context).pop(); //  drawer
  // }

  _navigateToAboutLeader() async {
    app.clearMessage();
    await Navigator.push(context, MaterialPageRoute(builder: (context) => Leader()));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToAbout() async {
    app.clearMessage();
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const About()));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToStyleDemo() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const StyleDemo()));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToDocumentation() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const Documentation()));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToDrums() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const DrumScreen(isEditing: true)));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToTheory() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const TheoryWidget()));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToPrivacyPolicy() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => const Privacy()));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  TextStyle _titleTextStyle = appTextStyle; //  initial place holder
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
