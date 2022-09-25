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
import 'dart:convert';

import 'package:bsteeleMusicLib/appLogger.dart';
import 'package:bsteeleMusicLib/songs/song.dart';
import 'package:bsteeleMusicLib/songs/songMetadata.dart';
import 'package:bsteeleMusicLib/songs/songPerformance.dart';
import 'package:bsteele_music_flutter/screens/about.dart';
import 'package:bsteele_music_flutter/screens/communityJams.dart';
import 'package:bsteele_music_flutter/screens/cssDemo.dart';
import 'package:bsteele_music_flutter/screens/debug.dart';
import 'package:bsteele_music_flutter/screens/documentation.dart';
import 'package:bsteele_music_flutter/screens/edit.dart';
import 'package:bsteele_music_flutter/screens/metadata.dart';
import 'package:bsteele_music_flutter/screens/options.dart';
import 'package:bsteele_music_flutter/screens/performanceHistory.dart';
import 'package:bsteele_music_flutter/screens/playList.dart';
import 'package:bsteele_music_flutter/screens/player.dart';
import 'package:bsteele_music_flutter/screens/privacy.dart';
import 'package:bsteele_music_flutter/screens/singers.dart';
import 'package:bsteele_music_flutter/screens/songs.dart';
import 'package:bsteele_music_flutter/screens/theory.dart';
import 'package:bsteele_music_flutter/util/screenInfo.dart';
import 'package:bsteele_music_flutter/util/songUpdateService.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';

//import 'package:wakelock/wakelock.dart';

import 'app/app.dart';
import 'app/appOptions.dart';
import 'app/app_theme.dart';
import 'util/openLink.dart';

//  diagnostic logging enables
const Level _logBuild = Level.debug;

String host = Uri.base.host;
Uri uri = Uri.parse(Uri.base.toString().replaceFirst(RegExp(r'#.*'), ''));
bool hostIsWebsocketHost = false;
const _environmentDefault = 'main';
// --dart-define=environment=test
const _environment = String.fromEnvironment('environment', defaultValue: _environmentDefault);

//  for holiday display: in Additional run args: --dart-define=holiday=true
//  note: not much effect due to hard-wiring of colors!
const _holidayOverride = String.fromEnvironment('holiday', defaultValue: '');

//  for holiday display: in Additional run args: --dart-define=css=test.css
//  note: not much effect due to hard-wiring of colors!
const _cssFileName = String.fromEnvironment('css', defaultValue: '');

/*
linux start size and location:
in linux/my_application.cc, line 50 or so
  gtk_window_set_default_size(window, 1920, 1080);
  gtk_window_move(window, 1920/16, 1080/2);
 */

void main() async {
  Logger.level = Level.info;

  //logger.i('Uri: ${Uri.base}, path: "${Uri.base.path}", fragment: "${Uri.base.fragment}"');
  logger.i('uri: "$uri", path: "${uri.path}", fragment: "${uri.fragment}"');

  //  holiday override
  var cssFileName = _cssFileName.isNotEmpty ? _cssFileName : uri.queryParameters['css'];
  cssFileName = (cssFileName?.isEmpty ?? true) ? 'app.css' : cssFileName;
  bool holidayOverride = _holidayOverride.isNotEmpty || uri.queryParameters.containsKey('holiday');
  if (holidayOverride) {
    //  override the css as well
    cssFileName = 'holiday.css';
  }

  //  read the css theme data prior to the first build
  WidgetsFlutterBinding.ensureInitialized().scheduleWarmUpFrame();
  await AppOptions().init(holidayOverride: holidayOverride); //  initialize the options from the stored values

  //  use the webserver's host as the websocket server if appropriate
  appLogMessage('host: "$host", port: ${uri.port}');
  if (host.isEmpty //  likely a native app
          ||
          host == 'www.bsteele.com' //  websocket will never be provided by the cloud server
          ||
          (host == 'localhost' && uri.port != 8080) //  defend against the debugger
      ) {
    //  do nothing!
    hostIsWebsocketHost = false;
    appLogMessage('no websocket: $host:${uri.port}');
  } else {
    //  default to the expected websocket server
    AppOptions().websocketHost = host; //  auto-magically choose the local websocket server
    hostIsWebsocketHost = true;
    appLogMessage('auto-magic websocket: $host');
  }

  await AppTheme().init(css: cssFileName!); //  init the singleton

  //  run the app
  runApp(
    const BSteeleMusicApp(),
  );
}

/*
beta short list:
_____re-setstate() on main after return from metadata
_____requester list change update fails to update UI
_____X for name.value name entry and value entry
_____thumbs up and down on song... now that metadata functions
_____playlist extended to singers screen
_____test Player play button size
_____slash chords always faded
_____deleting metadata on song in metadata should do a full setstate on the playlist
____singers searched for in history & singing?
____actions on song hit in singers
____force order by title on singer screen when editing requests
____change of singer => playlist scroll to zero
____fontsize too small on song lyrics?  on phones? lyrics multi-lines?  half fixed
____generate CSV for metadata updates to CJ website
finish PlayList
    requested song, no singer, click selection?  singer popup?
    fix christmas
singer requester editing not remembered
    requester list change should provide a "write file" button
    should not let user leave singing screen without warning and opportunity to write
select all of search text on return from playlist
player: Tablet change to manual play.  on menu bar tally icon?
Follower jumpy,
    Follower scroll update too brutal on section transitions.
    player key up/down move on changes 12 bar blues - minor
    follower jumps somewhere and back when adjusting the key when not on the first section
reset singer search when singer added to session

todo: test todo

OR list for multiple filters
very small screens, chord font size is too large relative to lyrics
very small screens, menu title stuff too large
PlayList:  song count on bottom?
fix history song count to show only displayed songs
Singer mode chords proportional to chord font, limit length
add playlist "or" on multiple metadata
if No song match:. Try close matches
      add closest matches if songlist is empty
Drums
    on horizontal scroll
    drums on 2/4, 3/4, 6/8
Follower display while leader choosing a song
test singer and requester on one singer/requester

generate decade metadata from year
metadata vs list vs name.value

Jumping jack flash, fix in bloom,

silly love songs spacing ,
master scroll got lost(after space? Likely after open link)
re-locate on change of display mode or repeat expansion
????? figure out the temperamental tomcat server.
escape from player to singers and no more
(the blank spacing between the section and the lyrics is a problem i know of and am working on)
re-search main list on song file read

2) Any way to allow zoom on play screen so one might read the lyrics?
3) Browsing our list is super unfriendly without sorting function
4) If the phone version cannot be user-friendly, I suggest we redirect users to a webpage like the searchable,
 sortable Beginner list generated from the spreadsheet. http://communityjams.org/index.php/beginner-jam-song-list/

  triples in the drums
  show lists to followers (main and singer)
  jump to follow location without motion from leader

re-download canvaskit on staging

button to adjust leader/follower when dis-connected

I've restarted my research to put DNS on the pi to ease the configuration. Say "park.local" instead of "192.168.1.205".


____fix song: Handlebars

F# and gb,. # override for guitar players (not persistent),
notes for song transcriptions,
 pop songs from history list,
 key guess,

 spreadsheet stuff

play tally off space bar: what?  Do I have to pay attention?....
freezing? do you mean always displaying the play button, key and beats per measure? capo is in that category. Bodhi wants to change bpm while in play.
drum: note: the default volume is zero. did you slide the volume up?i hear it on my system. I'll try the mac to see if it's a permission thing.
for the moment, the drums only work on 4 beats per measure songs. what?!!! yeah i know.
song not selected on main list after a file read and return to main list
insist on <uses-permission android:name="android.permission.INTERNET"/> in android/app/src/main/AndroidManifest.xml

consistent arrow on leader and follower
share the "sung by" in the follower update
eliminate singer needs a song requirement
drums to library
drums json
drums other than 4/4
standard drum list
test following after a local scroll
fun: key guess
larger font on player only mode
improve player: Tap to tempo
verify full validation of song before entry
Capitalization of user name
get real file name of written file for confirmation message
fixme: player scroll to top doesn't on songs with big intros and short verticals: bohemian rhapsody

fixme: first singers list doesn't showup on message section when all singers is written

 fixme: this is likely wrong:  void _readExternalSongList() async { if (appOptions.isInThePark()) ...


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
  const BSteeleMusicApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    logger.v('main: build()');

    return MultiProvider(
        providers: [
          ChangeNotifierProvider<AppOptions>(create: (_) => AppOptions()),
          //  has to be a widget level above it's use
          ChangeNotifierProvider<PlayListRefreshNotifier>(create: (_) => PlayListRefreshNotifier()),
        ],
        child: MaterialApp(
          title: 'bsteele Music App',
          theme: app.themeData,
          home: const MyHomePage(title: 'bsteele Music App'),
          navigatorObservers: [playerRouteObserver],

          // Start the app with the "/" named route. In this case, the app starts
          // on the FirstScreen widget.
          initialRoute: Navigator.defaultRouteName,
          routes: {
            // When navigating to the "/" route, build the FirstScreen widget.
            // '/': (context) => BSteeleMusicApp(),
            // When navigating to the "/second" route, build the SecondScreen widget.
            Player.routeName: playerPageRoute.builder,
            Options.routeName: (context) => const Options(),
            '/songs': (context) => const Songs(),
            Singers.routeName: (context) => const Singers(),
            MetadataScreen.routeName: (context) => const MetadataScreen(),
            '/edit': (context) => Edit(initialSong: app.selectedSong),
            PerformanceHistory.routeName: (context) => const PerformanceHistory(),
            '/privacy': (context) => const Privacy(),
            '/documentation': (context) => const Documentation(),
            Debug.routeName: (context) => const Debug(),
            '/about': (context) => const About(),
            CommunityJams.routeName: (context) => const Debug(),
            '/cssDemo': (context) => const CssDemo(),
            '/theory': (context) => const TheoryWidget(),
          },
        ));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, this.title = 'unknown'});

  // This widget is the home page of the application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  //  Fields in a Widget subclass are always marked "final".

  final String title;

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  MyHomePageState() : appOptions = AppOptions();

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

    //logger.i('uri: ${uri.base}, ${uri.base.queryParameters.keys.contains('follow')}');

    //  give the beta warning
    if (uri.toString().contains('beta')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _betaWarningPopup();
      });
    }
  }

  void _readInternalSongList() async {
    {
      var allSongsAsset = 'lib/assets/allSongs.songlyrics';
      appLogMessage('InternalSongList: $allSongsAsset');
      String songListAsString = await loadAssetString(allSongsAsset);
      try {
        app.removeAllSongs();
        app.addSongs(Song.songListFromJson(songListAsString));
        setState(() {});
        app.warningMessage = 'internal songList used, dated: ${await app.releaseUtcDate()}';
      } catch (fe) {
        logger.i("internal songList parse error: $fe");
      }
    }
    {
      String songMetadataAsString = await loadAssetString('lib/assets/allSongs.songmetadata');

      try {
        SongMetadata.fromJson(songMetadataAsString);
        logger.i("internal song metadata used");
        setState(() {});
      } catch (fe) {
        logger.i("internal song metadata parse error: $fe");
      }
    }
    {
      String dataAsString = await loadAssetString('lib/assets/allSongPerformances.songperformances');

      try {
        var allPerformances = AllSongPerformances();
        allPerformances.updateFromJsonString(dataAsString);
        allPerformances.loadSongs(app.allSongs);
        logger.i("internal song performances used");
        setState(() {});
      } catch (fe) {
        logger.i("internal song performance parse error: $fe");
      }
    }
  }

  void _readExternalSongList() async {
    var externalHost = host.isEmpty
        ? 'www.bsteele.com' //  likely a native app with web access
        : '$host:${uri.port}'; //  port for potential app server
    {
      final String url = 'http://$externalHost/bsteeleMusicApp/allSongs.songlyrics';
      appLogMessage('ExternalSongList: $url');
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
        setState(() {});
        //  don't warn on standard behavior:   app.warningMessage = 'SongList read from: $url';
      } catch (fe) {
        logger.i("external songList parse error: $fe");
        _readInternalSongList();
      }
    }
    {
      final String url = 'http://$externalHost/bsteeleMusicApp/allSongs.songmetadata';
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
        logger.i("external song metadata read from: $url");
        setState(() {});
      } catch (fe) {
        logger.i("external song metadata parse error: $fe");
      }
    }

    {
      final String url = 'http://$externalHost/bsteeleMusicApp/allSongPerformances.songperformances';
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
        logger.i("external song performances read from: $url");
        setState(() {});
      } catch (fe) {
        logger.i("external song performance parse error: $fe");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    logger.log(_logBuild, 'main build: ${app.selectedSong}');

    appOptions = Provider.of<AppOptions>(context);

    app.screenInfo = ScreenInfo(context); //  dynamically adjust to screen size changes  fixme: should be event driven

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
    titleTextStyle = generateAppTextStyle(
      fontWeight: FontWeight.bold,
      textBaseline: TextBaseline.alphabetic,
      color: Colors.black,
    );
    final fontSize = searchTextStyle.fontSize ?? 25;
    logger.d('fontSize: $fontSize in ${app.screenInfo.mediaWidth} px');

    final TextStyle navTextStyle = generateAppTextStyle(backgroundColor: Colors.transparent);

    return Scaffold(
      backgroundColor: Theme.of(context).backgroundColor,
      key: _scaffoldKey,
      appBar: AppWidgetHelper(context).appBar(
        title: widget.title,
        leading: AppTooltip(
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
              AppTooltip(
                message: "Visit bsteele.com, the provider of this app.",
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
                      semanticLabel: "bsteele.com website",
                    ),
                  ),
                ),
              ),
            if (!app.screenInfo.isWayTooNarrow)
              AppTooltip(
                message: "Visit Community Jams, the motivation and main user for this app.",
                child: InkWell(
                  onTap: () {
                    openLink('http://communityjams.org');
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      color: Colors.white,
                    ),
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

        drawer: appDrawer(
          appKeyEnum: AppKeyEnum.mainDrawer,
          voidCallback: _openDrawer,
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
                  style: navTextStyle,
                ),
                onTap: () {
                  _navigateToOptions();
                },
              ),
              if (app.isEditReady)
                appListTile(
                  appKeyEnum: AppKeyEnum.mainDrawerSingers,
                  title: Text(
                    "Singers",
                    style: navTextStyle,
                  ),
                  onTap: () {
                    _navigateToSingers();
                  },
                ),
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerPerformanceHistory,
                title: Text(
                  "History",
                  style: navTextStyle,
                ),
                //trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  _navigateToPerformanceHistory();
                },
              ),
              if (app.isEditReady) //  no files on phones!
                appListTile(
                  appKeyEnum: AppKeyEnum.mainDrawerSongs,
                  title: Text(
                    "Songs",
                    style: navTextStyle,
                  ),
                  onTap: () {
                    _navigateToSongs();
                  },
                ),

              if (app.isEditReady)
                appListTile(
                  appKeyEnum: AppKeyEnum.mainDrawerNewSong,
                  title: Text(
                    "New Song",
                    style: navTextStyle,
                  ),
                  onTap: () {
                    _navigateToEdit();
                  },
                ),
              if (!app.screenInfo.isTooNarrow)
                appListTile(
                  appKeyEnum: AppKeyEnum.mainDrawerTheory,
                  title: Text(
                    "Theory",
                    style: navTextStyle,
                  ),
                  onTap: () {
                    _navigateToTheory();
                  },
                ),
              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerPrivacy,
                title: Text(
                  "Privacy",
                  style: navTextStyle,
                ),
                //trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  _navigateToPrivacyPolicy();
                },
              ),
              if (app.isScreenBig)
                appListTile(
                  appKeyEnum: AppKeyEnum.mainDrawerDocs,
                  title: Text(
                    "Docs",
                    style: navTextStyle,
                  ),
                  onTap: () {
                    _navigateToDocumentation();
                  },
                ),
              if (kDebugMode)
                appListTile(
                  appKeyEnum: AppKeyEnum.mainDrawerCssDemo,
                  title: Text(
                    "CSS Demo",
                    style: navTextStyle,
                  ),
                  onTap: () {
                    _navigateToCssDemo();
                  },
                ),
              if (app.isEditReady)
                appListTile(
                  appKeyEnum: AppKeyEnum.mainDrawerLists,
                  title: Text(
                    "Metadata",
                    style: navTextStyle,
                  ),
                  onTap: () {
                    _navigateToMetadata();
                  },
                ),
              if (kDebugMode)
                appListTile(
                  appKeyEnum: AppKeyEnum.mainDrawerDebug,
                  title: Text(
                    "Debug",
                    style: navTextStyle,
                  ),
                  onTap: () {
                    _navigateToDebug();
                  },
                ),

              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerAbout,
                title: Text(
                  'CJ',
                  style: navTextStyle,
                ),
                //trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  _navigateToCommunityJams();
                },
              ),

              appListTile(
                appKeyEnum: AppKeyEnum.mainDrawerAbout,
                title: Text(
                  'About',
                  style: navTextStyle,
                ),
                //trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  _navigateToAbout();
                },
              ),
            ],
          ),
        ),

        /// Navigate to song player when song tapped.
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          if (app.message.isNotEmpty)
            Container(padding: const EdgeInsets.all(6.0), child: app.messageTextWidget(AppKeyEnum.mainErrorMessage)),
          // if (kDebugMode)
          //   TextButton(
          //       onPressed: () {
          //         testAppKeyCallbacks();
          //       },
          //       child: Text(
          //         'test',
          //         style: searchDropDownStyle,
          //       )),
          PlayList(
            songList: SongList('', app.allSongs.map((e) => SongListItem.fromSong(e)).toList(growable: false),
                songItemAction: _navigateToPlayerBySongItem),
            style: titleTextStyle,
          ),
        ]),

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
                      'This beta version is only for testing application development.\n'
                      'bob can damage this version at any time, for any reason.\n'
                      'Any remembered setup will not necessarily transfer to the real version.',
                      style: TextStyle(fontSize: 22),
                    ),
                    const AppSpace(),
                    appButton('Send me to the real version.', appKeyEnum: AppKeyEnum.mainGoToRelease, onPressed: () {
                      var s = uri.toString();
                      s = s.substring(0, s.indexOf('beta'));
                      openLink(
                        s,
                        sameTab: true,
                      );
                    }),
                    const AppSpace(space: 50),
                    appButton('This is exciting! I will test the beta.', appKeyEnum: AppKeyEnum.mainAcceptBeta,
                        onPressed: () {
                      Navigator.of(context).pop();
                    }),
                  ],
                ),
              ],
              elevation: 24.0,
            ));
  }

  // void _closeDrawer() {
  //   Navigator.of(context).pop();
  // }

  bool isHoliday(Song song) {
    return holidayRexExp.hasMatch(song.title) ||
        holidayRexExp.hasMatch(song.artist) ||
        holidayRexExp.hasMatch(song.coverArtist);
  }

  _navigateToPlayerBySongItem(BuildContext context, SongListItem songListItem) async {
    if (songListItem.song.getTitle().isEmpty) {
      // logger.log(_mainLogScroll, 'song title is empty: $song');
      return;
    }
    app.clearMessage();
    app.selectedSong = songListItem.song;
    //_lastSelectedSong = song;

    //logger.log(_mainLogScroll, '_navigateToPlayer: pushNamed: $song');
    await Navigator.pushNamed(
      context,
      Player.routeName,
    );

    setState(() {});
  }

  void _navigateToSongs() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Songs()),
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _navigateToMetadata() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MetadataScreen()),
    );

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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Edit(initialSong: Song.createEmptySong())),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToOptions() async {
    await Navigator.pushNamed(
      context,
      Options.routeName,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToSingers() async {
    await Navigator.pushNamed(
      context,
      Singers.routeName,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToPerformanceHistory() async {
    await Navigator.pushNamed(
      context,
      PerformanceHistory.routeName,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToDebug() async {
    app.clearMessage();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Debug()),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToAbout() async {
    app.clearMessage();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const About()),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToCommunityJams() async {
    app.clearMessage();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CommunityJams()),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToCssDemo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CssDemo()),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToDocumentation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Documentation()),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToTheory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TheoryWidget()),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  _navigateToPrivacyPolicy() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Privacy()),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(); //  drawer
  }

  List<Widget> listViewChildren = [];
  TextStyle titleTextStyle = appTextStyle; //  initial place holder
  TextStyle artistTextStyle = appTextStyle; //  initial place holder

  AppOptions appOptions;

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
