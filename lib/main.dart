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
import 'dart:math';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteeleMusicLib/util/util.dart';
import 'package:bsteele_music_flutter/screens/about.dart';
import 'package:bsteele_music_flutter/screens/cssDemo.dart';
import 'package:bsteele_music_flutter/screens/debug.dart';
import 'package:bsteele_music_flutter/screens/documentation.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/lists.dart';
import 'package:bsteele_music_flutter/screens/options.dart';
import 'package:bsteele_music_flutter/screens/performanceHistory.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/screens/privacy.dart';
import 'package:bsteele_music_flutter/screens/singers.dart';
import 'package:bsteele_music_flutter/screens/songs.dart';
import 'package:bsteele_music_flutter/screens/theory.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/songSearchMatcher.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:universal_io/io.dart';

//import 'package:wakelock/wakelock.dart';

import 'app/app.dart';
import 'app/appOptions.dart';
import 'app/app_theme.dart';
import 'util/openLink.dart';

//  diagnostic logging enables
const Level _mainLogScroll = Level.debug;

const _environmentDefault = 'main';
// --dart-define=environment=test
const _environment = String.fromEnvironment('environment', defaultValue: _environmentDefault);
const _holidayOverride = String.fromEnvironment('holiday', defaultValue: '');
const _cssFileName = String.fromEnvironment('css', defaultValue: '');

/*
linux start size and location:
in linux/my_application.cc, line 50 or so
  gtk_window_set_default_size(window, 1920, 1080);
  gtk_window_move(window, 1920/16, 1080/2);
 */

void main() async {
  Logger.level = Level.info;

  //  holiday override
  var cssFileName = _cssFileName.isNotEmpty ? _cssFileName : Uri.base.queryParameters['css'];
  cssFileName = (cssFileName?.isEmpty ?? true) ? 'app.css' : cssFileName;
  bool holidayOverride = _holidayOverride.isNotEmpty || Uri.base.queryParameters.containsKey('holiday');
  if (holidayOverride) {
    //  override the css as well
    cssFileName = 'holiday.css';
  }

  //  read the css theme data prior to the first build
  WidgetsFlutterBinding.ensureInitialized();
  await AppOptions().init(holidayOverride: holidayOverride); //  initialize the options from the stored values
  await AppTheme().init(css: cssFileName!); //  init the singleton

  //  run the app
  runApp(
    BSteeleMusicApp(),
  );
}

/*
done:

beta short list:
________Hamburger , new song, won't toggle edit mode
consistent arrow on leader and follower
share the "sung by" in the follower update
eliminate singer needs a song requirement
drums to library
drums json
drums other than 4/4
standard drum list
test drum consistency: place on it's own isolate?
test following after a local scroll
session history... to the web!
fun: key guess
larger font on player only mode
improve player: Tap to tempo
verify full validation of song before entry
Capitalization of user name
get real file name of written file for confirmation message



suggested solo notes and scales
key of F# labeled Gb
white rabbit no f sharp, no indicator
Read of files by dmg from web version


singers: purge singer without them coming back from the web site
in edit: show diff with similar song
edit "pro-mode", canvas copy paste for chords and lyrics
edit lyrics: not updated!  should be on timeout like chords?
edit lyrics: one blank row is now two?  at section end?
messages for file task completions or failures.
mac native:  desktop app couldn't get I Shall Be Released to save in the key of E

For me, key change creates a duplicate chart. And then looks like it keeps key change UNTIL you get rid of old version. Very weird.
map accented characters to lower case without accent: "Exposé" should match "expose"  fixme: dart package diacritic

research if the song id is case sensitive: e.g.: "I shall be released" vs "I Shall Be Released".   YES!

studio instructions for personal tablets
//  no auto 4 measures per row
edit mod at end of repeat row broken
css for repeat markers
______blank edit page from options page
______song enter confirmation after edit page
______repeat expand/compress on player page, non persistent
player: in pause, reposition play with up/down arrows, continue from new location with space
lyrics for a section in one vertical block
verify blank lyrics lines force position in lyric sections
expanded repeat player, no x, no repeat #

1. If we normally use Player mode to play charts, there is no reason not to freeze the row of buttons at the top when not in Player mode.
 We can scan down the song and not have to scroll back and forth/up and down to determine where there are potential problems before performing.

2. Bodhi is swinging back to wanting some of the more musically dense songs charted in 2, which makes sense for readability and therefore playability.
 In fact, it would be nice if he could mark this type of timing edit in a special way, since it comes up more than other issues.
  Is there a way to mark the 'type' of edit - as in timing change versus content change?

3. I have a feeling I may need two sets of some charts, in 2 or 4, in case we need to move in the other direction as in the past.
 Is there a way to do this programmatically?

4. Technically, I have been looking at a lot of sheet music and most of our 2-time charts are not technically in 2/2 or 2/4 (bouncy folk timing),
 so I suggest that the app should not specifically refer to "time signature" if we want to spread out the chords and make charts more jam-friendly.

It is difficult to find an alternative that does not confuse. One article I found refers to harmonic rhythm, but that is too long a term.
https://www.ars-nova.com/Theory%20Q&A/Q5.html

I believe the most appropriate term for us to use is beats per measure, rather than time signature.
Since that confuses with the common term bpm (beats per minute), perhaps we can switch our bpm to "tempo" and switch our time to "b/m"?
That would give us more freedom to chart songs with our desired simple beats per measure and not be limited by the formal
 and occasionally inaccurate use of "time signature."
 With b/m, we might even add the elusive 3-5 to the list - the 3-5 beat pattern that is not actually a real time signature but keeps coming up on songs without any reference on the chart.

I also try to keep tempo within the industry standards. Here is another reference for that:
https://songbpm.com/searches/ce40775f-0d09-496b-89c1-403d48591227

I need these types of guidelines so I am not forced to make arbitrary decisions while charting.
I am not clear how Bodhi calculates his tempo, but sometimes it is outside of these standards, so I will need to discuss this with him.

5. We cannot obtain proper "Copyright" information so I suggest we name the field properly until we can.
 I suggest that we use the term "Credit" instead, rather than mislead the audience about copyright.


//  song match takin' vs taking
//  log all song playings, summary of history

edit: change of title, artist or cover artist should trigger a comparison at song collisions
 Retain the requested songs
//
// player: Real play mode
// player: validate follower accuracy
// player: Intro and solo repeats
// player: Dynamic Tempo adjustments
// player: Metronome audio
// player: Bouncing ball, accuracy
// player: Guitar and/or piano chords audio
// sheetMusic: Read mp3 audio
// sheetMusic: Display mp3 with chords and zoom
// sheetMusic: Align drag and drop editing
// sheetMusic: N2N processing
// sheetMusic: Chord and slash suggestions
// sheetMusic: Looping playback
// sheetMusic: Variable tempo?
// sheetMusic: Drum machine
// sheetMusic: evaluate Performance
// sheetMusic: Automated song transcription

// edit: transpose song to new key

Key F# vs Gb  ie. -6 vs +6  in the display

key guess

close gap between lyrics lines on player

wikipedia page link: not that regular, can be very ambiguous: eg: Winter by Tori Amos https://en.wikipedia.org/wiki/Winter_(Tori_Amos_song)
copyright vs release owner and date

ultimate guitar   drum patterns
https://tabs.ultimate-guitar.com/ copy/paste reformatting  don't lose lyrics verses chords alignment


edit: adjust fontsize with buttons, memorized
lyrics, jump left right based on pinching the chords
vertical bars to split lyrics into measures
play screen freeze top when not in play mode
Nashville notation for leadin lyrics
not all lyrics changes get proper notification

file differences on song file read as opposed to assuming all is well
args from screens on url end keeps app from reloading
metronome just as a resource for editing screen

disable player tooltips when in follow mode

grab bar on scroll for song list
select by last change should jump to top
very old songs: dec 31, 1969     30+ songs, some have been edited

edit chords at lyrics section
space in front of lyrics in hopes of being able to select the first character from the left

https://www.apronus.com/music/onlineguitar.htm
https://www.pianochord.org/
https://www.all8.com/tools/bpm.htm
https://getsongkey.com/
https://www.musicnotes.com/  sheetmusic in pdf pro version?
https://www.all8.com/tools/bpm.htm


timing of bass sound from omnidirectional to recording vs timing from within pisound
timing delay of mic to headphones?

//  remember: debugger( when: );
// Love song Sara Bareilles in G
//  Fix "Not enough", fix "I shall be released"
//  fixme: Singer demands at least one song
//  flutter webview 3.0 has an iframe

//  fixme: feature: for ninjam: put title, chords in ninjam format for copy/paste to ninjam comment, + /bpm and /bpi
//  fixme: edit: change title: does not get a new modification date
//  fixme: If the key was changed on a song and it is saved, it displays in the previous key instead of the new original key. The behavior should display as original key.
//  fixme: main: change to last changed, sticks to last selected song
//  fixme: edit: disposing of controllers and/or focus nodes fails
//  fixme: edit: web version: enter doesn't work
//  fixme: player: time signature always in view if not 4/4
//  fixme: player: if in play, no tool tips, timeout any current tooltip
//  fixme: lists: don't select the entry name/value until it's valid
//  fixme: lists: "write all to file" can appear disabled
//  fixme: songmetadata thumbs up should eliminate the name:value from thumbs down, and vise-versa
//  fixme: songmetadata file should delete all prior metadata of same name:value from all songs
//  fixme: edit: no format errors on section add
//  fixme: edit: add a measure on a new row doesn't work, entry never appears
//  fixme: edit repeat add plus's should be in the last column, the one with the repeat count
//  fixme: repeat brackets and repeat counts should be without background so they don't get too wide based on other measures in other rows
//  fixme: lyrics "instrumental:" blows up
//  fixme: edit: big blowup if Song.createEmptySong() goes into song on a clear
//  fixme: edit join/split should only do the following measure
//  fixme: better websocket response
//  fixme: player: cancel follow... without losing websocket ip address
//  fixme: edit: delete section
//  fixme: next/previous song in list on player
//  fixme: singer lists, eg. singer:vicki, select and auto add in player
//  fixme: map song:singer to key for default key next time
//  fixme: should the leader be able to capo?
//  fixme: should the leader be able to key offset?
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

const _searchTextTooltipText = 'Enter search text here.\n Title, artist and cover artist will be searched.';

/// Song list sort types
enum MainSortType {
  byTitle,
  byArtist,
  byLastChange,
  byComplexity,
  byYear,
}

/// Display the list of songs to choose from.
class BSteeleMusicApp extends StatelessWidget {
  BSteeleMusicApp({Key? key}) : super(key: key) {
    Logger.level = Level.info;
    // if (kIsWeb) {
    //fixme:   Wakelock.enable(); //  avoid device timeouts!
    // }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    logger.v('main: build()');

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
                Options.routeName: (context) => const Options(),
                '/songs': (context) => const Songs(),
                Singers.routeName: (context) => const Singers(),
                '/lists': (context) => const Lists(),
                '/edit': (context) => Edit(initialSong: app.selectedSong),
                PerformanceHistory.routeName: (context) => const PerformanceHistory(),
                '/privacy': (context) => const Privacy(),
                '/documentation': (context) => const Documentation(),
                Debug.routeName: (context) => const Debug(),
                '/about': (context) => const About(),
                '/cssDemo': (context) => const CssDemo(),
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

    //  give the beta warning
    if (Uri.base.toString().contains('beta')) {
      WidgetsBinding.instance?.addPostFrameCallback((_) async {
        _betaWarningPopup();
      });
    }
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
        app.warningMessage = 'internal songList used, dated: ${await app.releaseUtcDate()}';
      } catch (fe) {
        logger.i("internal songList parse error: " + fe.toString());
      }
    }
    {
      String songMetadataAsString = await loadString('lib/assets/allSongs.songmetadata');

      try {
        SongMetadata.fromJson(songMetadataAsString);
        logger.i("internal song metadata used");
        setState(() {});
      } catch (fe) {
        logger.i("internal song metadata parse error: " + fe.toString());
      }
    }
    {
      String dataAsString = await loadString('lib/assets/allSongPerformances.songperformances');

      try {
        var allPerformances = AllSongPerformances();
        allPerformances.updateFromJsonString(dataAsString);
        allPerformances.loadSongs(app.allSongs);
        logger.i("internal song performances used");
        setState(() {});
      } catch (fe) {
        logger.i("internal song performance parse error: " + fe.toString());
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
        app.warningMessage = 'SongList read from: $url';
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
        SongMetadata.fromJson(metadataAsString);
        logger.i("external song metadata read from: " + url);
        setState(() {});
      } catch (fe) {
        logger.i("external song metadata parse error: " + fe.toString());
      }
    }

    {
      const String url = 'http://www.bsteele.com/bsteeleMusicApp/allSongPerformances.songperformances';

      String dataAsString;
      try {
        dataAsString = await fetchString(url);
      } catch (e) {
        logger.i("read of url: '$url' failed: ${e.toString()}");
        _readInternalSongList();
        return;
      }

      try {
        var allPerformances = AllSongPerformances();
        allPerformances.updateFromJsonString(dataAsString);
        allPerformances.loadSongs(app.allSongs);
        logger.i("external song performances read from: " + url);
        setState(() {});
      } catch (fe) {
        logger.i("external song performance parse error: " + fe.toString());
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

    logger.v('screen: logical: (${app.screenInfo.mediaWidth},${app.screenInfo.mediaHeight})');
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
    titleTextStyle = generateAppTextStyle(
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
    logger.d('fontSize: $fontSize in ${app.screenInfo.mediaWidth} px');

    artistTextStyle = titleTextStyle.copyWith(fontWeight: FontWeight.normal);
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

    listViewChildren.clear();
    addSongsToListView(_filteredSongs);
    listViewChildren.add(appSpace(
      space: 20,
    ));
    listViewChildren.add(Text(
      'Count: ${_filteredSongs.length}',
      style: artistTextStyle,
    ));

    if (_filteredSongsNotInSelectedList.isNotEmpty) {
      listViewChildren.add(const Divider(
        thickness: 10,
        color: Colors.blue,
      ));
      listViewChildren.add(appSpace(space: 40));
      listViewChildren.add(Text(
        'Songs not in ${_selectedListNameValue?.toShortString()}:',
        style: artistTextStyle,
      ));

      addSongsToListView(_filteredSongsNotInSelectedList);
      listViewChildren.add(appSpace(
        space: 20,
      ));
      listViewChildren.add(Text(
        'Count: ${_filteredSongsNotInSelectedList.length}',
        style: artistTextStyle,
      ));
    }

    // {
    //   bool oddEven = true;
    //   final oddTitle = oddTitleText(from: titleTextStyle);
    //   final evenTitle = evenTitleText(from: titleTextStyle);
    //   final oddText = oddTitleText(from: artistTextStyle);
    //   final evenText = evenTitleText(from: artistTextStyle);
    //   logger.d('_filteredSongs.length: ${_filteredSongs.length}');
    //
    //   for (final Song song in _filteredSongs) {
    //     oddEven = !oddEven;
    //     var oddEvenTitleTextStyle = oddEven ? oddTitle : evenTitle;
    //     var oddEvenTextStyle = oddEven ? oddText : evenText;
    //     logger.v('song.songId: ${song.songId}');
    //     listViewChildren.add(appGestureDetector(
    //       appKeyEnum: AppKeyEnum.mainSong,
    //       value: Id(song.songId.toString()),
    //       child: Container(
    //         color: oddEvenTitleTextStyle.backgroundColor,
    //         padding: const EdgeInsets.all(8.0),
    //         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    //           if (app.isScreenBig)
    //             appWrapFullWidth(children:
    //               <Widget>[
    //                 appWrap(
    //                   <Widget>[
    //                     Text(
    //                       song.title,
    //                       style: oddEvenTitleTextStyle,
    //                     ),
    //                     Text(
    //                       '      ' + song.getArtist(),
    //                       style: oddEvenTextStyle,
    //                     ),
    //                   ],
    //                 ),
    //                 Text(
    //                   '   ' +
    //                       intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime)),
    //                   style: oddEvenTextStyle,
    //                 ),
    //               ],
    //               alignment: WrapAlignment.spaceBetween,
    //             ),
    //           if (app.isPhone)
    //             Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               children: <Widget>[
    //                 Text(
    //                   song.title,
    //                   style: oddEvenTitleTextStyle,
    //                 ),
    //                 Text(
    //                   '      ' + song.getArtist(),
    //                   style: oddEvenTextStyle,
    //                 ),
    //               ],
    //             ),
    //         ]),
    //       ),
    //       onTap: () {
    //         _navigateToPlayer(context, song);
    //       },
    //     ));
    //   }
    // }

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
                  child: const Image(
                    image: AssetImage('lib/assets/runningMan.png'),
                    width: kToolbarHeight,
                    height: kToolbarHeight,
                    semanticLabel: "bsteele.com website",
                  ),
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    color: Colors.white,
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
                  child: const Image(
                    image: AssetImage('lib/assets/cjLogo.png'),
                    width: kToolbarHeight,
                    height: kToolbarHeight,
                    semanticLabel: "community jams",
                  ),
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    color: Colors.white,
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
            if (app.isEditReady)
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerSingers,
                title: Text(
                  "Singers",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToSingers(context);
                },
              ),
            appListTile(
              appKeyEnum: AppKeyEnum.mainDrawerPerformanceHistory,
              title: Text(
                "History",
                style: _navTextStyle,
              ),
              //trailing: Icon(Icons.arrow_forward),
              onTap: () {
                _navigateToPerformanceHistory(context);
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
            if (app.isEditReady)
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerNewSong,
                title: Text(
                  "New Song",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToEdit(context);
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
            if (app.isScreenBig)
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
            if (kDebugMode)
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerDebug,
                title: Text(
                  "Debug",
                  style: _navTextStyle,
                ),
                onTap: () {
                  _navigateToDebug(context);
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
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        if (app.message.isNotEmpty)
          Container(padding: const EdgeInsets.all(6.0), child: app.messageTextWidget(AppKeyEnum.mainErrorMessage)),
        appWrapFullWidth(children: [
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
              width: 12 * _titleBarFontSize,
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
                    app.clearMessage();
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
                    app.clearMessage();
                    setState(() {
                      FocusScope.of(context).requestFocus(_searchFocusNode);
                      _lastSelectedSong = null;
                      _searchSongs(null);
                    });
                  }),
                )),
          ]),
          if (app.isScreenBig)
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
                      app.clearMessage();
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
          if (appOptions.holiday)
            appWrap([
              appTooltip(
                message: 'Change the holiday selection in the general options (☰, Options).',
                child: Text(
                  'Happy Holidays!  ',
                  style: searchDropDownStyle.copyWith(color: Colors.green),
                ),
              ),
            ]),
          if (!appOptions.holiday && app.isScreenBig)
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
                  app.clearMessage();
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

  void _betaWarningPopup() async {
    await showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text(
                'Do you really want test the beta version of the bsteeleMusicApp?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              actions: [
                Column(
                  children: [
                    const Text(
                      'This version is only for testing application development.\n'
                      'bob can damage this version at any time, for any reason.\n'
                      'Any remembered setup will not transfer to the real version.',
                      style: TextStyle(fontSize: 22),
                    ),
                    appSpace(),
                    appButton('Send me to the real version.', appKeyEnum: AppKeyEnum.mainGoToRelease, onPressed: () {
                      var s = Uri.base.toString();
                      s = s.substring(0, s.indexOf('beta'));
                      openLink(
                        s,
                        sameTab: true,
                      );
                    }),
                    appSpace(space: 50),
                    appButton('This is exciting! I will test the beta.', appKeyEnum: AppKeyEnum.mainCancelBeta,
                        onPressed: () {
                      Navigator.of(context).pop();
                    }),
                  ],
                ),
              ],
              elevation: 24.0,
            ));
  }

  void addSongsToListView(Iterable<Song> list) {
    bool oddEven = true;
    final oddTitle = oddTitleTextStyle(from: titleTextStyle);
    final evenTitle = evenTitleTextStyle(from: titleTextStyle);
    final oddText = oddTitleTextStyle(from: artistTextStyle);
    final evenText = evenTitleTextStyle(from: artistTextStyle);

    for (final Song song in list) {
      oddEven = !oddEven;
      var oddEvenTitleTextStyle = oddEven ? oddTitle : evenTitle;
      var oddEvenTextStyle = oddEven ? oddText : evenText;
      logger.d('song.songId: ${song.songId}, key: ${appKey(AppKeyEnum.mainSong, value: Id(song.songId.toString()))}');
      listViewChildren.add(appInkWell(
        appKeyEnum: AppKeyEnum.mainSong,
        value: Id(song.songId.toString()),
        child: Container(
          color: oddEvenTitleTextStyle.backgroundColor,
          padding: const EdgeInsets.all(8.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            if (app.isScreenBig)
              appWrapFullWidth(
                children: <Widget>[
                  appWrap(
                    <Widget>[
                      if (_selectedSortType == MainSortType.byYear)
                        Text(
                          '${song.getCopyrightYearAsString()}: ',
                          style: oddEvenTitleTextStyle,
                        ),
                      Text(
                        song.title,
                        style: oddEvenTitleTextStyle,
                      ),
                      Text(
                        '    ' + song.getArtist(),
                        style: oddEvenTextStyle,
                      ),
                      if (song.coverArtist.isNotEmpty)
                        Text(
                          ', cover by ${song.coverArtist}',
                          style: oddEvenTextStyle,
                        ),
                    ],
                  ),
                  Text(
                    '   ' + intl.DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(song.lastModifiedTime)),
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

  // void _closeDrawer() {
  //   Navigator.of(context).pop();
  // }

  void _searchSongs(String? search) {
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
      case MainSortType.byYear:
        compare = (Song song1, Song song2) {
          var ret = song1.getCopyrightYear().compareTo(song2.getCopyrightYear());
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
    _filteredSongsNotInSelectedList = SplayTreeSet(compare);
    var matcher = SongSearchMatcher(search);
    for (final Song song in app.allSongs) {
      if (matcher.matchesOrEmptySearch(song, year: _selectedSortType == MainSortType.byYear)) {
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
              _filteredSongsNotInSelectedList.add(song);
              continue; //  not a match
            }
          }
        }

        //  not filtered
        _filteredSongs.add(song);
      }
    }

    //  on new search, start the list at the first location
    if (matcher.isNotEmpty) {
      _rollIndex = 0;
      if (_itemScrollController.isAttached && _filteredSongs.isNotEmpty) {
        _itemScrollController.jumpTo(index: _rollIndex);
      }
    } else if (_filteredSongs.isNotEmpty) {
      switch (_selectedSortType) {
        case MainSortType.byTitle:
          _rollUnfilteredSongs();
          break;
        case MainSortType.byLastChange:
          _rollIndex = 0;
          if (_itemScrollController.isAttached) {
            _itemScrollController.scrollTo(index: _rollIndex, duration: _itemScrollDuration);
          }
          break;
        default:
          break;
      }
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
      logger.log(_mainLogScroll, 'song title is empty: $song');
      return;
    }
    app.clearMessage();
    app.selectedSong = song;
    _lastSelectedSong = song;

    logger.log(_mainLogScroll, '_navigateToPlayer: pushNamed: $song');
    await Navigator.pushNamed(
      context,
      Player.routeName,
    );

    _reApplySearch();
  }

  _navigateToEdit(BuildContext context) async {
    app.clearMessage();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: Song.createEmptySong())),
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  _navigateToOptions(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      Options.routeName,
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  _navigateToSingers(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      Singers.routeName,
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  _navigateToPerformanceHistory(BuildContext context) async {
    await Navigator.pushNamed(
      context,
      PerformanceHistory.routeName,
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  _navigateToDebug(BuildContext context) async {
    app.clearMessage();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Debug()),
    );
    Navigator.pop(context); //  drawer
  }

  _navigateToAbout(BuildContext context) async {
    app.clearMessage();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const About()),
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  _navigateToCssDemo(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CssDemo()),
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  _navigateToDocumentation(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Documentation()),
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  _navigateToTheory(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TheoryWidget()),
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  _navigateToPrivacyPolicy(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Privacy()),
    );
    Navigator.pop(context); //  drawer
    _reApplySearch();
  }

  List<Widget> listViewChildren = [];
  TextStyle titleTextStyle = appTextStyle; //  initial place holder
  TextStyle artistTextStyle = appTextStyle; //  initial place holder

  final List<DropdownMenuItem<MainSortType>> _sortTypesDropDownMenuList = [];
  var _selectedSortType = MainSortType.byTitle;

  final TextEditingController _searchTextFieldController = TextEditingController();
  final FocusNode _searchFocusNode;
  NameValue? _selectedListNameValue;

  final ItemScrollController _itemScrollController = ItemScrollController();
  final Duration _itemScrollDuration = const Duration(milliseconds: 500);
  int _rollIndex = -1;

  AppOptions appOptions;

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

SplayTreeSet<Song> _filteredSongs = SplayTreeSet();
SplayTreeSet<Song> _filteredSongsNotInSelectedList = SplayTreeSet();
Song? _lastSelectedSong;

//  for external consumption
Song previousSongInTheList() {
  if (_filteredSongs.isEmpty) {
    return Song.createEmptySong();
  }
  if (_lastSelectedSong == null) {
    _lastSelectedSong = _filteredSongs.first;
    return _lastSelectedSong!;
  }
  var list = _filteredSongs.toList(growable: false);
  var index = list.indexOf(_lastSelectedSong!) - 1; //  will be -2 if not found
  index = index % list.length;
  _lastSelectedSong = list[index];
  return _lastSelectedSong!;
}

//  for external consumption
Song nextSongInTheList() {
  if (_filteredSongs.isEmpty) {
    return Song.createEmptySong();
  }
  if (_lastSelectedSong == null) {
    _lastSelectedSong = _filteredSongs.first;
    return _lastSelectedSong!;
  }
  var list = _filteredSongs.toList(growable: false);
  var index = list.indexOf(_lastSelectedSong!) + 1; //  will be zero if not found
  index = index % list.length;
  _lastSelectedSong = list[index];
  return _lastSelectedSong!;
}
